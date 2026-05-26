import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';
import 'exceptions.dart';

/// A group of CRDT merge changes collected for one sync batch.
typedef CrdtMergeSet = List<CrdtMergeChange>;

/// Merge metadata extracted from a [CrdtMergeSet].
typedef CrdtMergeMetadataLookup = ({
  Map<String, Set<UuidValue>> rowIdsByTable,
  Map<String, Set<String>> columnNamesByTable,
});

/// Extensions for stream iterators of [CrdtSyncStreamEvent].
extension CrdtSyncStreamEventStreamExtension on StreamIterator<CrdtSyncStreamEvent> {
  /// Collects the next framed sync batch from this iterator.
  ///
  /// Each batch is zero or more [CrdtSyncMergeChange] events followed by
  /// [CrdtSyncEndOfBatch].
  Future<CrdtMergeSet> collectNextBatch() async {
    final mergeSet = <CrdtMergeChange>[];

    while (await moveNext()) {
      switch (current) {
        case CrdtSyncMergeChange(change: final change):
          mergeSet.add(change);
        case CrdtSyncEndOfBatch():
          return mergeSet;
        default:
          throw CrdtSyncUnexpectedEventException(
            expected: '"CrdtSyncMergeChange" or "CrdtSyncEndOfBatch"',
            received: current,
          );
      }
    }

    throw const CrdtSyncStreamClosedException(phase: 'end-of-batch');
  }

  /// Moves the iterator to the next event and throws if the stream is closed or
  /// the next event is not of type [T].
  Future<T> moveAndThrowIfNot<T extends CrdtSyncStreamEvent>() async {
    if (!await moveNext()) {
      throw CrdtSyncStreamClosedException(phase: '"$T"');
    }
    if (current is! T) {
      throw CrdtSyncUnexpectedEventException(
        expected: '"$T"',
        received: current,
      );
    }
    return current as T;
  }
}

/// CRDT merge helpers for [CrdtMergeSet].
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// The greatest HLC represented by the changes in this merge set.
  Hlc? get maxHlc => fold<Hlc?>(
    null,
    (current, change) => change.hlc.maxBetween(current),
  );

  /// Insert changes in this set.
  Iterable<CrdtMergeInsert> get inserts => whereType<CrdtMergeInsert>();

  /// Update changes in this set.
  Iterable<CrdtMergeUpdate> get updates => whereType<CrdtMergeUpdate>();

  /// Delete changes in this set.
  Iterable<CrdtMergeDelete> get deletes => whereType<CrdtMergeDelete>();

  /// All merge changes in this set sorted by causal order.
  List<CrdtMergeChange> get causallyOrderedChanges {
    final operations = List<CrdtMergeChange>.from(this)
      ..sort((left, right) => left.hlc.compareTo(right.hlc));
    return operations;
  }

  /// Collects the row and column metadata needed to load merge state.
  CrdtMergeMetadataLookup collectMetadataLookup({
    required Map<String, Set<String>> columnNamesByTableName,
  }) {
    final rowIdsToLoadByTable = <String, Set<UuidValue>>{};
    final columnNamesToLoadByTable = <String, Set<String>>{};

    for (final change in this) {
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
