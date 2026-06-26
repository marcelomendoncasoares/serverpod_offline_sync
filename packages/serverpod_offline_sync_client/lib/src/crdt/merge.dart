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
  /// Each batch is zero or more [CrdtSyncMergeChunk] events followed by
  /// [CrdtSyncEndOfBatch]. If the stream is idle before a batch starts, an
  /// empty batch is returned.
  ///
  /// When [allowCloseBeforeBatch] is true, returns `null` if the stream closes
  /// before the next batch starts. Otherwise, closing before a batch starts is
  /// treated as a [CrdtSyncStreamClosedException].
  ///
  /// If the stream closes after a merge change was already received, the
  /// partial batch is still treated as an error.
  Future<CrdtMergeSet?> collectNextBatch({
    bool allowCloseBeforeBatch = false,
    UuidValue? expectedScopeId,
  }) async {
    final mergeSet = <CrdtMergeChange>[];

    while (await moveNext()) {
      switch (current) {
        case CrdtSyncMergeChunk(uuidScopeId: final uuidScopeId, changes: final changes):
          if (expectedScopeId != null && uuidScopeId != expectedScopeId) {
            throw CrdtSyncScopeMismatchException(
              frameName: 'CrdtSyncMergeChunk',
              receivedScopeId: uuidScopeId,
              expectedScopeId: expectedScopeId,
            );
          }
          mergeSet.addAll(changes);
        case CrdtSyncIdleTimeout():
          if (mergeSet.isEmpty) return mergeSet;
        case CrdtSyncEndOfBatch():
          return mergeSet;
        default:
          throw CrdtSyncUnexpectedEventException(
            expected: '"CrdtSyncMergeChunk" or "CrdtSyncEndOfBatch"',
            received: current,
          );
      }
    }

    if (mergeSet.isEmpty && allowCloseBeforeBatch) return null;
    throw const CrdtSyncStreamClosedException(phase: 'end-of-batch');
  }

  /// Moves the iterator to the next event and throws if the stream is closed or
  /// the next event is not of type [T].
  Future<T> moveAndThrowIfNot<T extends CrdtSyncStreamEvent>() async {
    while (await moveNext()) {
      if (current is CrdtSyncIdleTimeout) continue;
      if (current is T) return current as T;
      throw CrdtSyncUnexpectedEventException(
        expected: '"$T"',
        received: current,
      );
    }
    throw CrdtSyncStreamClosedException(phase: '"$T"');
  }

  /// Moves to the next event of type [T], returning `null` if the stream closes.
  ///
  /// This is used by continuous sync sessions where peer-side cancellation is a
  /// normal shutdown path. Unexpected event types still fail the session.
  Future<T?> moveOrNullIfClosed<T extends CrdtSyncStreamEvent>() async {
    try {
      return await moveAndThrowIfNot<T>();
    } on CrdtSyncStreamClosedException catch (_) {
      return null;
    }
  }

  /// Reads the next event of type [T], dispatching on [throwIfClosed]: a `once`
  /// round treats a peer that closes mid-handshake as an error, continuous sync
  /// as a clean shutdown that returns `null`.
  Future<T?> nextFrame<T extends CrdtSyncStreamEvent>({
    required bool throwIfClosed,
  }) => throwIfClosed ? moveAndThrowIfNot<T>() : moveOrNullIfClosed<T>();

  /// Collects one sync cycle's inbound frames until the terminating
  /// [CrdtSyncEndOfBatch] or an idle timeout, demultiplexed by type and scope.
  ///
  /// Returns the collected [CrdtSyncCycleBatch], an empty batch when the peer
  /// was idle (it sent nothing this cycle, only honored if [allowIdleReturn]),
  /// or `null` when the inbound stream closed.
  ///
  /// An idle timeout only ends an *empty* cycle: once any frame has been
  /// collected the timeout is ignored and collection waits for the explicit
  /// terminator, so a peer's frames can never leak across cycle boundaries. With
  /// [allowIdleReturn] false (the `once` round, where the peer always sends a
  /// terminator) idle timeouts are ignored entirely and collection blocks for
  /// the terminator.
  Future<CrdtSyncCycleBatch?> collectCycleBatch({
    required bool allowIdleReturn,
  }) async {
    final batch = CrdtSyncCycleBatch();
    while (await moveNext()) {
      switch (current) {
        case final CrdtSyncScopeSet event:
          batch.scopeSet = event;
        case final CrdtSyncSinceHlc event:
          batch.sinceHlcs[event.uuidScopeId] = event;
        case CrdtSyncMergeChunk(:final uuidScopeId, :final changes):
          batch.groups.putIfAbsent(uuidScopeId, () => []).addAll(changes);
        case CrdtSyncEndOfBatch():
          return batch;
        case CrdtSyncIdleTimeout():
          if (allowIdleReturn && batch.isEmpty) return batch;
        case CrdtSyncClose():
          return null;
        case final event:
          throw CrdtSyncUnexpectedEventException(
            expected: 'a sync cycle frame',
            received: event,
          );
      }
    }
    return null;
  }
}

/// One sync cycle's inbound frames, demultiplexed by type and scope.
class CrdtSyncCycleBatch {
  /// The peer's scope announcement for this cycle, if it sent one.
  CrdtSyncScopeSet? scopeSet;

  /// The peer's resume vectors, keyed by scope.
  final Map<UuidValue, CrdtSyncSinceHlc> sinceHlcs = {};

  /// The peer's merge changes for this cycle, grouped by scope.
  final Map<UuidValue, List<CrdtMergeChange>> groups = {};

  /// Whether the peer sent nothing this cycle (it was idle).
  bool get isEmpty => scopeSet == null && sinceHlcs.isEmpty && groups.isEmpty;
}

/// Helpers for grouping merge changes into stream payload batches.
extension CrdtMergeChangeStreamExtension on Stream<CrdtMergeChange> {
  /// Emits lists with at most [batchSize] changes from this stream.
  Stream<CrdtMergeSet> chunked(int batchSize) async* {
    var batch = <CrdtMergeChange>[];
    await for (final change in this) {
      batch.add(change);
      if (batch.length < batchSize) continue;
      yield batch;
      batch = <CrdtMergeChange>[];
    }
    if (batch.isNotEmpty) yield batch;
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
