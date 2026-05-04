// Benchmark harness types — internal to the runner CLI.

import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'tables.dart';

enum Operation { insert, update, delete }

/// Benchmarks plain SQLite writes vs CRDT-wrapped writes using the wide [Types]
/// row (same shape idea as legacy Drift `TableWithEveryColumnType`).
class TypesTableBenchmark extends AsyncBenchmarkBase {
  TypesTableBenchmark(
    super.name, {
    required this.crdtEnabled,
    required this.operation,
    required this.rowCount,
  });

  /// Minimal blob column payload (shared; column stays non-null with zero bytes).
  static final ByteData _emptyBlob = ByteData(0);
  static const _warmupMillis = 100;
  static const _measurementMillis = 2000;

  final bool crdtEnabled;
  final Operation operation;
  final int rowCount;

  static const _clientUrl = 'http://localhost:8081/';

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  CrdtDatabaseSession? _crdtSession;
  var _hasOpenSession = false;

  final UuidValue _userId = const Uuid().v7obj();

  int _valueSeq = 0;

  int _lastDatabaseSize = 0;
  int _lastRowsCount = 0;

  List<Types> _seededRows = [];

  Types _createTypesRow(int i, DateTime baseTimestamp) {
    return Types(
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

  Future<List<Types>> _insertTypes(int count) async {
    final baseTimestamp = DateTime.now();
    final start = _valueSeq;
    _valueSeq += count;
    final rows = List.generate(
      count,
      (j) => _createTypesRow(start + j, baseTimestamp),
    );
    if (crdtEnabled) {
      return _crdtSession!.db.transactionForUser(_userId, (tx) async {
        return Types.db.insert(_crdtSession!, rows, transaction: tx);
      });
    }
    return Types.db.insert(_plainSession, rows);
  }

  Future<void> _deleteTypes(List<Types> rows) async {
    if (rows.isEmpty) {
      return;
    }
    if (crdtEnabled) {
      await _crdtSession!.db.transactionForUser(_userId, (tx) async {
        await Types.db.delete(_crdtSession!, rows, transaction: tx);
      });
    } else {
      await Types.db.delete(_plainSession, rows);
    }
  }

  Future<void> _updateTypesInPlace() async {
    final baseTimestamp = DateTime.now();
    final updated = _seededRows.map((row) {
      final i = _valueSeq++;
      return row.copyWith(
        aBool: i.isEven,
        aDateTime: baseTimestamp.add(Duration(seconds: i)),
        aText: 'Text $i',
        anInt: i,
        anInt64: BigInt.from(i),
        aReal: i.toDouble(),
        aBlob: _emptyBlob,
        optionalUuid: const Uuid().v7obj(),
      );
    }).toList();
    if (crdtEnabled) {
      _seededRows = await _crdtSession!.db.transactionForUser(
        _userId,
        (tx) async {
          return Types.db.update(
            _crdtSession!,
            updated,
            columns: (t) => [
              t.aBool,
              t.aDateTime,
              t.aText,
              t.anInt,
              t.anInt64,
              t.aReal,
              t.aBlob,
              t.optionalUuid,
            ],
            transaction: tx,
          );
        },
      );
    } else {
      _seededRows = await Types.db.update(
        _plainSession,
        updated,
        columns: (t) => [
          t.aBool,
          t.aDateTime,
          t.aText,
          t.anInt,
          t.anInt64,
          t.aReal,
          t.aBlob,
          t.optionalUuid,
        ],
      );
    }
  }

  Future<void> _bootstrapDatabase() async {
    await clearUserTables(_plainSession);
    CrdtUserManager.clearCache();
    HlcManager.reset();
    final wrapped = CrdtDatabaseSession.wraps(
      _plainSession,
      syncTables: benchmarkSyncTables,
    );
    await wrapped.db.initialize();
    _crdtSession = crdtEnabled ? wrapped : null;
  }

  @override
  Future<void> setup() async {
    _valueSeq = 0;
    _lastDatabaseSize = 0;
    _lastRowsCount = 0;
    final dbPath = p.join(
      Directory.systemTemp.path,
      'offline_sync_benchmark_$name.db',
    );
    _dbFile = File(dbPath);
    _deleteDatabaseFiles(_dbFile);

    _plainSession = await Client(_clientUrl).createSession(
      _dbFile.path,
      isDebugMode: true,
    );
    _hasOpenSession = true;

    await _bootstrapDatabase();
  }

  Future<void> _prepareCycle() async {
    if (_seededRows.isNotEmpty) {
      await _deleteTypes(_seededRows);
      _seededRows = [];
    }
    switch (operation) {
      case Operation.insert:
        return;
      case Operation.update:
        _seededRows = await _insertTypes(rowCount);
      case Operation.delete:
        _seededRows = await _insertTypes(rowCount);
    }
  }

  Future<double> _measurePreparedCycles(int minimumMillis) async {
    final minimumMicros = minimumMillis * 1000;
    final watch = Stopwatch()..start();
    var totalTimedMicros = 0.0;
    var timedIterations = 0;

    while (watch.elapsedMicroseconds < minimumMicros) {
      await _prepareCycle();
      final sw = Stopwatch()..start();
      await run();
      totalTimedMicros += sw.elapsedMicroseconds;
      timedIterations++;
    }

    return totalTimedMicros / timedIterations;
  }

  Future<void> _captureDatabaseSize() async {
    try {
      await _plainSession.db.unsafeExecute('PRAGMA wal_checkpoint(TRUNCATE)');
    } on Exception {
      // WAL checkpoint is best-effort (e.g. non-SQLite tests).
    }
    _lastDatabaseSize = _sqliteDbFootprintBytes(_dbFile);
  }

  Future<double> _measureAverageMicroseconds() async {
    await _measurePreparedCycles(_warmupMillis);
    return _measurePreparedCycles(_measurementMillis);
  }

  Future<void> _resetForStorageSample() async {
    _valueSeq = 0;
    _lastDatabaseSize = 0;
    _lastRowsCount = 0;
    _seededRows = [];
    await clearUserTables(_plainSession);
    await _plainSession.db.unsafeExecute('VACUUM');
    CrdtUserManager.clearCache();
    HlcManager.reset();
    final wrapped = CrdtDatabaseSession.wraps(
      _plainSession,
      syncTables: benchmarkSyncTables,
    );
    await wrapped.db.initialize();
    _crdtSession = crdtEnabled ? wrapped : null;
  }

  @override
  Future<double> measure() async {
    await setup();
    try {
      return await _measureAverageMicroseconds();
    } finally {
      await teardown();
    }
  }

  @override
  Future<(double, int)> report() async {
    await setup();
    try {
      final averageMicroseconds = await _measureAverageMicroseconds();
      await _resetForStorageSample();
      await _prepareCycle();
      await run();
      await _captureDatabaseSize();
      return (averageMicroseconds, measureStorage());
    } finally {
      await teardown();
    }
  }

  @override
  Future<void> run() async {
    switch (operation) {
      case Operation.insert:
        _seededRows = await _insertTypes(rowCount);
        _lastRowsCount = _seededRows.length;
      case Operation.update:
        await _updateTypesInPlace();
        _lastRowsCount = _seededRows.length;
      case Operation.delete:
        await _deleteTypes(_seededRows);
        _seededRows = [];
        _lastRowsCount = 0;
    }
  }

  @override
  Future<void> teardown() async {
    if (!_hasOpenSession) {
      return;
    }
    await _captureDatabaseSize();
    await _plainSession.close();
    _hasOpenSession = false;
    _deleteDatabaseFiles(_dbFile);
  }

  int measureStorage() {
    if (operation == Operation.delete) {
      return _lastDatabaseSize;
    }

    if (_lastDatabaseSize == 0) {
      throw Exception('Last database size is not set.');
    }
    if (_lastRowsCount < rowCount) {
      throw Exception(
        'Rows count is $_lastRowsCount but expected at least $rowCount.',
      );
    }
    return _lastDatabaseSize ~/ (_lastRowsCount / rowCount);
  }
}

/// Bytes used by SQLite for [mainDb], including WAL sidecars (often omitted by
/// `mainDb.lengthSync()` alone).
int _sqliteDbFootprintBytes(File mainDb) {
  var total = mainDb.existsSync() ? mainDb.lengthSync() : 0;
  final wal = File('${mainDb.path}-wal');
  final shm = File('${mainDb.path}-shm');
  if (wal.existsSync()) {
    total += wal.lengthSync();
  }
  if (shm.existsSync()) {
    total += shm.lengthSync();
  }
  return total;
}

void _deleteDatabaseFiles(File mainDb) {
  if (mainDb.existsSync()) {
    mainDb.deleteSync();
  }
  for (final companion in [
    File('${mainDb.path}-wal'),
    File('${mainDb.path}-shm'),
  ]) {
    if (companion.existsSync()) {
      companion.deleteSync();
    }
  }
}
