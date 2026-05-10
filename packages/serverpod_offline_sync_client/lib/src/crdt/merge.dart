import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

/// Merge metadata extracted from a [CrdtMergeSet].
typedef CrdtMergeMetadataLookup = ({
  Map<String, Set<UuidValue>> rowIdsByTable,
  Map<String, Set<String>> columnNamesByTable,
});

/// Adds all merge changes from [mergeSet] followed by a null sentinel.
void addMergeSetWithSentinel(
  void Function(CrdtMergeChange?) add,
  CrdtMergeSet mergeSet,
) {
  mergeSet.inserts.forEach(add);
  mergeSet.updates.forEach(add);
  mergeSet.deletes.forEach(add);
  add(null);
}

/// Builds a [CrdtMergeSet] from the provided change lists.
///
/// When [unmodifiable] is `true`, the change lists are wrapped in unmodifiable
/// views before constructing the merge set so downstream consumers cannot
/// mutate the collected batch contents. Use it for collected stream batches or
/// other handoff points where the merge set should be treated as immutable
/// after creation; leave it as `false` for local builders that still append to
/// or reuse the underlying lists before returning.
CrdtMergeSet buildMergeSet({
  required List<CrdtMergeInsert> inserts,
  required List<CrdtMergeUpdate> updates,
  required List<CrdtMergeDelete> deletes,
  bool unmodifiable = false,
}) {
  if (!unmodifiable) {
    return CrdtMergeSet(
      inserts: inserts,
      updates: updates,
      deletes: deletes,
    );
  }

  return CrdtMergeSet(
    inserts: List<CrdtMergeInsert>.unmodifiable(inserts),
    updates: List<CrdtMergeUpdate>.unmodifiable(updates),
    deletes: List<CrdtMergeDelete>.unmodifiable(deletes),
  );
}

/// Collects the next null-delimited [CrdtMergeSet] from [changes].
Future<CrdtMergeSet?> collectMergeSetFromIterator(
  StreamIterator<CrdtMergeChange?> changes,
) async {
  final inserts = <CrdtMergeInsert>[];
  final updates = <CrdtMergeUpdate>[];
  final deletes = <CrdtMergeDelete>[];
  var receivedStopSentinel = false;

  while (await changes.moveNext()) {
    final change = changes.current;
    switch (change) {
      case null:
        receivedStopSentinel = true;
      case final CrdtMergeInsert insert:
        inserts.add(insert);
      case final CrdtMergeUpdate update:
        updates.add(update);
      case final CrdtMergeDelete delete:
        deletes.add(delete);
    }
    if (change == null) break;
  }

  if (!receivedStopSentinel) return null;

  return buildMergeSet(
    inserts: inserts,
    updates: updates,
    deletes: deletes,
  );
}

/// Splits a null-delimited change stream into [CrdtMergeSet] batches.
Stream<CrdtMergeSet> collectMergeSetBatches(
  Stream<CrdtMergeChange?> changes,
) async* {
  final iterator = StreamIterator(changes);
  try {
    while (true) {
      final mergeSet = await collectMergeSetFromIterator(iterator);
      if (mergeSet == null) return;
      yield mergeSet;
    }
  } finally {
    await iterator.cancel();
  }
}

/// CRDT merge helpers built on top of the generated Serverpod models.
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// The greatest HLC represented by the changes in this merge set.
  Hlc? get maxHlc => changes.fold<Hlc?>(
    null,
    (current, change) => change.hlc.maxBetween(current),
  );

  /// All merge changes in this set.
  Iterable<CrdtMergeChange> get changes sync* {
    yield* inserts;
    yield* updates;
    yield* deletes;
  }

  /// All merge changes in this set sorted by causal order.
  List<CrdtMergeChange> get causallyOrderedChanges {
    final operations = changes.toList()
      ..sort((left, right) => left.hlc.compareTo(right.hlc));
    return operations;
  }

  /// Collects the row and column metadata needed to load merge state.
  CrdtMergeMetadataLookup collectMetadataLookup({
    required Map<String, Set<String>> columnNamesByTableName,
  }) {
    final rowIdsToLoadByTable = <String, Set<UuidValue>>{};
    final columnNamesToLoadByTable = <String, Set<String>>{};

    for (final change in changes) {
      final availableColumnNames = columnNamesByTableName[change.tableName];
      if (availableColumnNames == null) continue;

      rowIdsToLoadByTable.putIfAbsent(change.tableName, () => {}).add(change.uuidRowId);
      columnNamesToLoadByTable.putIfAbsent(change.tableName, () => {}).addAll(
        switch (change) {
          CrdtMergeInsert() => availableColumnNames.difference({'id'}),
          CrdtMergeUpdate() => [change.columnName],
          _ => [],
        },
      );
    }

    return (
      rowIdsByTable: rowIdsToLoadByTable,
      columnNamesByTable: columnNamesToLoadByTable,
    );
  }
}

/// Convenience helpers shared by every merge change.
extension CrdtMergeChangeExtension on CrdtMergeChange {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, uuidNodeId);
}

/// Convenience helpers for insert changes.
extension CrdtMergeInsertExtension on CrdtMergeInsert {
  /// The database column payload represented by this change.
  Map<String, Object?> get databaseColumns {
    final payload = switch (data) {
      final TableRow row => row.toJsonForDatabase(),
      final Map<String, dynamic> map => map,
      _ => throw StateError(
        'Unsupported merge insert payload type for $tableName: '
        '${data.runtimeType}. Expected TableRow or Map<String, dynamic>.',
      ),
    };

    return Map<String, Object?>.from(payload as Map<String, dynamic>);
  }
}
