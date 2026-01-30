import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../hlc/normalized.dart';
import 'base.dart';

/// A CRDT implementation for offline-first synchronization.
class OfflineSyncCrdt extends CrdtBase {
  /// Creates a new instance of [OfflineSyncCrdt].
  ///
  /// The [nodeId] must be unique across the system.
  OfflineSyncCrdt(this._db, {required super.userId, required super.nodeId});

  final CrdtDatabase _db;

  @override
  // TODO: Remove this method lately if it is not needed - as it seems it will.
  Future<Hlc?> getLastModified({String? onlyNodeId, String? exceptNodeId}) async {
    if (onlyNodeId != null && exceptNodeId != null) {
      throw ArgumentError('Only one of onlyNodeId or exceptNodeId can be provided.');
    }

    // Query the maximum HLC using tuple ordering on normalized components
    final query = _db.select(_db.crdtDataTable).join([
      innerJoin(
        _db.crdtNodesTable,
        _db.crdtNodesTable.id.equalsExp(_db.crdtDataTable.hlcNodeId),
      ),
    ]);

    if (onlyNodeId != null) {
      query.where(_db.crdtNodesTable.nodeId.equals(onlyNodeId));
    }
    if (exceptNodeId != null) {
      query.where(_db.crdtNodesTable.nodeId.equals(exceptNodeId).not());
    }

    query
      ..orderBy([
        OrderingTerm.desc(_db.crdtDataTable.hlcDatetime),
        OrderingTerm.desc(_db.crdtDataTable.hlcCounter),
        OrderingTerm.desc(_db.crdtDataTable.hlcNodeId),
      ])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    final entry = result.readTable(_db.crdtDataTable);
    final node = result.readTable(_db.crdtNodesTable);

    return NormalizedHlc.reconstruct(
      datetime: entry.hlcDatetime,
      counter: entry.hlcCounter,
      nodeId: node.nodeId,
    );
  }

  @override
  Future<Iterable<CrdtDataEntry>> getChangeset({
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedAfter,
  }) async {
    assert(onlyNodeId == null || exceptNodeId == null);

    // Modified times use the local node id
    modifiedAfter = modifiedAfter?.apply(nodeId: nodeId);

    final query = _db.select(_db.crdtDataTable).join([
      innerJoin(
        _db.crdtNodesTable,
        _db.crdtNodesTable.id.equalsExp(_db.crdtDataTable.hlcNodeId),
      ),
    ]);

    if (onlyNodeId != null) {
      query.where(_db.crdtNodesTable.nodeId.equals(onlyNodeId));
    }
    if (exceptNodeId != null) {
      query.where(_db.crdtNodesTable.nodeId.equals(exceptNodeId).not());
    }
    if (modifiedAfter != null) {
      final datetime = NormalizedHlc.extractDatetime(modifiedAfter);
      final counter = NormalizedHlc.extractCounter(modifiedAfter);
      // Tuple comparison for HLC
      query.where(
        (_db.crdtDataTable.hlcDatetime.isBiggerThanValue(datetime)) |
            ((_db.crdtDataTable.hlcDatetime.equals(datetime)) &
                (_db.crdtDataTable.hlcCounter.isBiggerThanValue(counter))),
      );
    }

    final results = await query.get();
    return results.map((r) => r.readTable(_db.crdtDataTable));
  }

  @override
  Future<void> saveChangeset(
    Iterable<CrdtDataEntry> changeset,
    Iterable<Hlc> receivedHlcs,
  ) async {
    await _db.transaction(() async {
      await _saveChangeset(changeset);
      await _applyCompensationRules();
      await _saveMergedHlcs(receivedHlcs);
    });
  }

  /// Save the [changeset] to the database.
  ///
  /// Should be called within a transaction. Must ensure that only newer values
  /// are saved to the database.
  Future<void> _saveChangeset(Iterable<CrdtDataEntry> changeset) async {
    return _db.managers.crdtDataTable.bulkCreate(
      (_) => changeset.map((e) => e.toCompanion(false)),
      mode: InsertMode.insertOrReplace,
      onConflict: DoUpdate.withExcluded(
        (old, excluded) => CrdtDataTableCompanion.custom(
          rawValue: excluded.rawValue,
          hlcDatetime: excluded.hlcDatetime,
          hlcCounter: excluded.hlcCounter,
          hlcNodeId: excluded.hlcNodeId,
        ),
        where: (old, excluded) =>
            // Tuple comparison: old HLC < excluded HLC
            (old.hlcDatetime.isSmallerThan(excluded.hlcDatetime)) |
            ((old.hlcDatetime.equals(excluded.hlcDatetime)) &
                (old.hlcCounter.isSmallerThan(excluded.hlcCounter))) |
            ((old.hlcDatetime.equals(excluded.hlcDatetime)) &
                (old.hlcCounter.equals(excluded.hlcCounter)) &
                (old.hlcNodeId.isSmallerThan(excluded.hlcNodeId))),
      ),
    );
  }

  /// Applies compensation rules to the CRDT data table to preserve invariants.
  ///
  /// If the any invariant fails to be preserved, a flag will be set on the
  /// control table to prevent further merges until the issue is resolved by
  /// the server and a repair merge is pushed to this node.
  Future<void> _applyCompensationRules() async {
    // TODO: Implement this.
  }

  @override
  Future<void> merge(Iterable<CrdtDataEntry> changeset, CrdtDatabase db) async {
    // Override to pass our database instance
    await super.merge(changeset, _db);
  }

  /// Save the [mergedHlcs] to the database.
  ///
  /// Should be called within a transaction after the changeset has been saved
  /// and properly compensated.
  Future<void> _saveMergedHlcs(Iterable<Hlc> mergedHlcs) async {
    return _db.managers.crdtMergeHlcTable.bulkCreate(
      (t) => mergedHlcs.map(
        (e) => t(
          userId: userId,
          nodeId: e.nodeId,
          lastReceivedHlc: e,
        ),
      ),
      mode: InsertMode.insertOrReplace,
      onConflict: DoUpdate.withExcluded(
        (old, excluded) => CrdtMergeHlcTableCompanion.custom(
          lastReceivedHlc: excluded.lastReceivedHlc,
        ),
        where: (old, excluded) =>
            old.lastReceivedHlc.isSmallerThan(excluded.lastReceivedHlc),
      ),
    );
  }
}
