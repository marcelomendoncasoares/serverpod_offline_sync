import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:drift_offline_sync/src/database/triggers.dart';
import 'package:path/path.dart' as p;

import 'database.dart';

export 'package:drift_offline_sync/src/database/triggers.dart' show Operation;

class CrdtBenchmark extends AsyncBenchmarkBase {
  CrdtBenchmark(
    super.name, {
    required this.crdtEnabled,
    required this.operation,
    required this.rowCount,
  });

  final bool crdtEnabled;
  final Operation operation;
  final int rowCount;

  late final CrdtBenchmarkDatabase _db;
  late final File _dbFile;

  int _lastDatabaseSize = 0;
  int _lastRowsCount = 0;

  @override
  Future<void> setup() async {
    final dbPath = p.join(Directory.systemTemp.path, 'benchmark_$name.db');
    _dbFile = File(dbPath);
    _db = CrdtBenchmarkDatabase.createDatabase(_dbFile, crdtEnabled: crdtEnabled);

    // Force the migration to be applied during setup.
    await _db.batchInsertTestRows(1);
    await _db.deleteTestRows(1);
    await _db.managers.tableWithEveryColumnType.delete();

    if (operation != Operation.insert) {
      await _db.batchInsertTestRows(rowCount);
    }
  }

  /// The default warmup is to invoke the [run] method once, but this pollutes the
  /// results by persisting data before the run.
  @override
  Future<void> warmup() async {}

  @override
  Future<void> run() async {
    _lastDatabaseSize = 0;
    _lastRowsCount = 0;
    switch (operation) {
      case Operation.insert:
      case Operation.update:
        await _db.upsertTestRows(rowCount);
      case Operation.delete:
        await _db.deleteTestRows(rowCount);
    }
  }

  @override
  Future<(double, int)> report() async {
    final averageMicroseconds = await measure();
    return (averageMicroseconds, measureStorage());
  }

  @override
  Future<void> teardown() async {
    _lastDatabaseSize = _dbFile.lengthSync();
    _lastRowsCount = await _db.testRowsCount();
    await _db.close();
    if (_dbFile.existsSync()) {
      _dbFile.deleteSync();
    }
  }

  int measureStorage() {
    if (operation == Operation.delete) {
      return _lastDatabaseSize;
    }

    if (_lastDatabaseSize == 0) {
      throw Exception('Last database size is not set.');
    }
    if (_lastRowsCount < rowCount) {
      throw Exception('Rows count is $_lastRowsCount but expected at least $rowCount.');
    }
    // If the benchmark ran for more than one loop, it can contain a greater number
    // of rows than the expected. We need to normalize it to the expected total.
    return _lastDatabaseSize ~/ (_lastRowsCount / rowCount);
  }
}
