// Merge benchmark harness — measures the sync merge apply path.

import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'benchmark.dart';
import 'tables.dart';

enum MergeOperation { insert, update, delete, mixed }

/// The number of changes of each kind in a mixed batch of [changeCount].
({int inserts, int updates, int deletes}) mixedMergeComposition(
  int changeCount,
) {
  final updates = changeCount ~/ 3;
  final deletes = changeCount ~/ 3;
  return (
    inserts: changeCount - updates - deletes,
    updates: updates,
    deletes: deletes,
  );
}

/// Benchmarks applying remote CRDT changes to a local database through the
/// sync merge path, using the wide [Types] row like [TypesTableBenchmark].
///
/// Changes are attributed to a single simulated remote node whose HLCs always
/// advance, so every merged change is newer than the local state and is
/// effectively applied (no stale-change short circuits).
class TypesMergeBenchmark extends AsyncBenchmarkBase {
  TypesMergeBenchmark(
    super.name, {
    required this.operation,
    required this.changeCount,
  });

  /// Minimal blob column payload (shared; column stays non-null with zero bytes).
  static final ByteData _emptyBlob = ByteData(0);
  static const _warmupMillis = 100;
  static const _measurementMillis = 2000;

  static const _clientUrl = 'http://localhost:8081/';

  final MergeOperation operation;
  final int changeCount;

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  late CrdtDatabaseSession _crdtSession;
  var _hasOpenSession = false;

  final UuidValue _userId = const Uuid().v7obj();

  /// Clock of the simulated remote node the merged changes come from.
  Hlc _remoteHlc = Hlc.now(const Uuid().v7obj());

  int _valueSeq = 0;

  CrdtMergeSet _mergeSet = [];
  List<Types> _seededRows = [];

  Hlc _nextRemoteHlc() => _remoteHlc = _remoteHlc.increment();

  Types _createTypesRow(int i, DateTime baseTimestamp) {
    return Types(
      id: const Uuid().v7obj(),
      aBool: i.isEven,
      aDateTime: baseTimestamp.add(Duration(seconds: i)),
      aText: 'Text $i',
      anInt: i,
      anInt64: BigInt.from(i),
      aReal: i.toDouble(),
      aBlob: _emptyBlob,
      anEnum: null,
      optionalText: null,
      optionalUuid: const Uuid().v7obj(),
    );
  }

  List<Types> _createTypesRows(int count) {
    final baseTimestamp = DateTime.now();
    final start = _valueSeq;
    _valueSeq += count;
    return List.generate(
      count,
      (j) => _createTypesRow(start + j, baseTimestamp),
    );
  }

  CrdtMergeInsert _insertChangeFor(Types row) {
    final hlc = _nextRemoteHlc();
    return CrdtMergeInsert(
      tableName: Types.t.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      data: row,
    );
  }

  CrdtMergeUpdate _updateChangeFor(Types row) {
    final hlc = _nextRemoteHlc();
    final i = _valueSeq++;
    final (columnName, value) = switch (i % 3) {
      0 => (Types.t.aText.columnName, 'Updated $i' as Object?),
      1 => (Types.t.anInt.columnName, i as Object?),
      _ => (Types.t.aReal.columnName, i.toDouble() as Object?),
    };
    return CrdtMergeUpdate(
      tableName: Types.t.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      columnName: columnName,
      value: value,
    );
  }

  CrdtMergeDelete _deleteChangeFor(Types row) {
    final hlc = _nextRemoteHlc();
    return CrdtMergeDelete(
      tableName: Types.t.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      clFlag: 2,
      reason: CrdtDataDeletedReason.userDelete,
    );
  }

  /// Seeds [count] rows through the merge path so the rows exist locally with
  /// remote CRDT metadata, like rows previously received from the remote node.
  Future<List<Types>> _mergeInsertRows(int count) async {
    final rows = _createTypesRows(count);
    await _crdtSession.db.mergeChanges(
      [for (final row in rows) _insertChangeFor(row)],
      userId: _userId,
    );
    return rows;
  }

  @override
  Future<void> setup() async {
    _valueSeq = 0;
    _mergeSet = [];
    _seededRows = [];
    final dbPath = p.join(
      Directory.systemTemp.path,
      'offline_sync_benchmark_$name.db',
    );
    _dbFile = File(dbPath);
    deleteDatabaseFiles(_dbFile);

    _plainSession = await Client(_clientUrl).createSession(
      _dbFile.path,
      isDebugMode: true,
    );
    _hasOpenSession = true;

    await clearUserTables(_plainSession);
    _crdtSession = CrdtDatabaseSession.wraps(
      _plainSession,
      syncTables: benchmarkSyncTables,
    );
    await _crdtSession.db.initialize();

    if (operation == MergeOperation.update) {
      _seededRows = await _mergeInsertRows(changeCount);
    }
  }

  Future<void> _prepareCycle() async {
    switch (operation) {
      case MergeOperation.insert:
        _mergeSet = [
          for (final row in _createTypesRows(changeCount)) _insertChangeFor(row),
        ];
      case MergeOperation.update:
        _mergeSet = [for (final row in _seededRows) _updateChangeFor(row)];
      case MergeOperation.delete:
        final rows = await _mergeInsertRows(changeCount);
        _mergeSet = [for (final row in rows) _deleteChangeFor(row)];
      case MergeOperation.mixed:
        final composition = mixedMergeComposition(changeCount);
        final existingRows = await _mergeInsertRows(
          composition.updates + composition.deletes,
        );
        _mergeSet = [
          for (final row in _createTypesRows(composition.inserts))
            _insertChangeFor(row),
          for (final row in existingRows.take(composition.updates))
            _updateChangeFor(row),
          for (final row in existingRows.skip(composition.updates))
            _deleteChangeFor(row),
        ];
    }
  }

  @override
  Future<double> measure() async {
    await setup();
    try {
      await measurePreparedCycles(
        _warmupMillis,
        prepare: _prepareCycle,
        run: run,
      );
      return await measurePreparedCycles(
        _measurementMillis,
        prepare: _prepareCycle,
        run: run,
      );
    } finally {
      await teardown();
    }
  }

  @override
  Future<void> run() async {
    await _crdtSession.db.mergeChanges(_mergeSet, userId: _userId);
  }

  @override
  Future<void> teardown() async {
    if (!_hasOpenSession) {
      return;
    }
    await _plainSession.close();
    _hasOpenSession = false;
    deleteDatabaseFiles(_dbFile);
  }
}
