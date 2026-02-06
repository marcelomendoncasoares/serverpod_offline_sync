import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/extensions/entry.dart';
import '../hlc/converter.dart';
import 'base.dart';

/// A CRDT implementation for offline-first synchronization.
class OfflineSyncCrdt extends CrdtBase {
  /// Creates a new instance of [OfflineSyncCrdt].
  ///
  /// The [nodeId] must be unique across the system.
  OfflineSyncCrdt(this._db, {required super.userId, required super.nodeId});

  final CrdtDatabase _db;

  @override
  Future<Hlc> getCanonicalTime() async {
    final row = await _db.managers.crdtHlcStateTable
        .filter((o) => o.userId.equals(userId))
        .getSingleOrNull();

    return row?.toHlc(nodeId) ?? Hlc.zero(nodeId);
  }

  @override
  Future<void> mergeCanonicalTime(Hlc maxMergedHlc) async {
    await _db.managers.crdtHlcStateTable.create(
      (t) => t(
        userId: userId,
        lastTimestamp: maxMergedHlc.unixTimestamp,
        counter: maxMergedHlc.counter,
      ),
      mode: InsertMode.insertOrReplace,
      onConflict: DoUpdate.withExcluded(
        (old, excluded) => CrdtHlcStateTableCompanion.custom(
          lastTimestamp: CaseWhenExpression(
            // Combined with the `orElse`, this is the same as a max() function,
            // but it works for all databases. Otherwise, we would need to check
            // the database dialect to use either `MAX` or `GREATEST`.
            cases: [
              excluded.lastTimestamp
                  .isBiggerOrEqual(old.lastTimestamp)
                  .then(excluded.lastTimestamp),
            ],
            orElse: old.lastTimestamp,
          ),
          counter: CaseWhenExpression(
            cases: [
              // If one timestamp is greater, its counter should be persisted.
              excluded.lastTimestamp
                  .isBiggerThan(old.lastTimestamp)
                  .then(excluded.counter),
              // Otherwise, if the timestamps are equal, the counter should be
              // the greater counter.
              (excluded.lastTimestamp.equalsExp(old.lastTimestamp) &
                      excluded.counter.isBiggerThan(old.counter))
                  .then(excluded.counter),
            ],
            orElse: old.counter,
          ),
        ),
      ),
    );
  }

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
    modifiedAfter = modifiedAfter?.copyWith(nodeId: nodeId);

    final query = _db.managers.crdtDataTable.filter((o) {
      Expression<bool> condition = const Constant(true);

      if (onlyNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(onlyNodeId);
      }
      if (exceptNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(exceptNodeId).not();
      }
      if (modifiedAfter != null) {
        condition &= o.hlcTimestamp.column.isBiggerThanValue(
          hlcConverter.toSql(modifiedAfter),
        );
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

extension on Expression<bool> {
  CaseWhen<bool, T> then<T extends Object>(Expression<T> value) => CaseWhen(
    this,
    then: value,
  );
}
