import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import 'changeset.dart';
import 'database.dart';

/// A CRDT implementation for offline-first synchronization.
class OfflineSyncCrdt extends Crdt {
  /// Make sure you run [initialize] after instantiation.
  OfflineSyncCrdt(this._db);

  final CrdtDatabase _db;

  /// Initialize this CRDT.
  ///
  /// The [nodeId] must be unique across the system. Note that setting the node
  /// id on [initialize] only works for empty CRDTs. For non-empty CRDTs, the
  /// node id will be read from the database.
  Future<void> initialize({required String nodeId}) async {
    canonicalTime = await getLastModified(onlyNodeId: nodeId);
  }

  @override
  Future<Hlc> getLastModified({String? onlyNodeId, String? exceptNodeId}) async {
    assert(
      onlyNodeId == null || exceptNodeId == null,
      'Only one of onlyNodeId or exceptNodeId can be provided.',
    );

    // NOTE: Although `max` has a better performance for the general use case,
    // when the column is indexed, `order by` with `limit 1` will be just as fast.
    // The plus of using the order by approach is the native deserialization of
    // the Hlc object by Drift.
    final rowWithMaxLastSyncHlc = await _db.managers.crdtDataTable
        .orderBy((o) => o.hlcTimestamp.desc())
        .limit(1)
        .getSingleOrNull();

    final lastModified = rowWithMaxLastSyncHlc?.hlcTimestamp;
    return lastModified ?? Hlc.zero(nodeId);
  }

  @override
  Future<CrdtChangeset> getChangeset({
    Map<String, Query>? customQueries,
    Iterable<String>? onlyTables,
    String? onlyNodeId,
    String? exceptNodeId,
    Hlc? modifiedOn,
    Hlc? modifiedAfter,
  }) async {
    assert(onlyNodeId == null || exceptNodeId == null);
    assert(modifiedOn == null || modifiedAfter == null);

    if (customQueries != null) {
      throw UnimplementedError('Not implemented');
    }

    // Modified times use the local node id
    modifiedOn = modifiedOn?.apply(nodeId: nodeId);
    modifiedAfter = modifiedAfter?.apply(nodeId: nodeId);

    final query = _db.managers.crdtDataTable.filter((o) {
      Expression<bool> condition = const Constant(true);

      if (onlyTables != null) {
        condition &= o.tblName.isIn(onlyTables);
      }
      if (onlyNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(onlyNodeId);
      }
      if (exceptNodeId != null) {
        condition &= o.hlcTimestamp.column.contains(exceptNodeId).not();
      }
      if (modifiedOn != null) {
        condition &= o.hlcTimestamp.equals(modifiedOn);
      }
      if (modifiedAfter != null) {
        condition &= o.hlcTimestamp.column.isBiggerThanValue(modifiedAfter.toString());
      }
      return condition;
    });

    final rows = await query.get();
    return rows.toChangeset();
  }

  @override
  Future<void> merge(CrdtChangeset changeset) async {
    if (changeset.recordCount == 0) return;

    // Ignore empty records
    changeset.removeWhere((_, records) => records.isEmpty);

    // Validate changeset and get new canonical time
    final hlc = validateChangeset(changeset);

    // Merge records
    await _db.transaction(() async {
      await _db.managers.crdtDataTable.bulkCreate(
        (_) => changeset.toCrdtDataEntries().map((e) => e.toCompanion(false)),
        mode: InsertMode.insertOrReplace,
      );

      await applyCompensationRules();
      onDatasetChanged(changeset.keys, hlc);
    });
  }

  /// Applies compensation rules to the CRDT data table to preserve invariants.
  ///
  /// If the any invariant fails to be preserved, a flag will be set on the
  /// control table to prevent further merges until the issue is resolved by
  /// the server and a repair merge is pushed to this node.
  Future<void> applyCompensationRules() async {
    // TODO: Implement this.
  }
}
