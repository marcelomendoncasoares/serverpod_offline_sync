import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import 'crdt_base.dart';
import 'database.dart';

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

    // NOTE: Although `max` has a better performance for the general use case,
    // when the column is indexed, `order by` with `limit 1` will be just as fast.
    // The plus of using the order by approach is the native deserialization of
    // the Hlc object by Drift.
    final rowWithMaxLastSyncHlc = await _db.managers.crdtDataTable
        .filter((o) {
          if (onlyNodeId != null) {
            return o.hlcTimestamp.column.contains(onlyNodeId);
          }
          if (exceptNodeId != null) {
            return o.hlcTimestamp.column.contains(exceptNodeId).not();
          }
          return const Constant(true);
        })
        .orderBy((o) => o.hlcTimestamp.desc())
        .limit(1)
        .getSingleOrNull();

    return rowWithMaxLastSyncHlc?.hlcTimestamp;
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

    final query = _db.managers.crdtDataTable.filter((o) {
      Expression<bool> condition = const Constant(true);

      if (onlyNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(onlyNodeId);
      }
      if (exceptNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(exceptNodeId).not();
      }
      if (modifiedAfter != null) {
        condition &= o.hlcTimestamp.column.isBiggerThanValue(modifiedAfter.toString());
      }
      return condition;
    });

    return query.get();
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
          hlcTimestamp: excluded.hlcTimestamp,
        ),
        where: (old, excluded) => old.hlcTimestamp.isSmallerThan(excluded.hlcTimestamp),
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
