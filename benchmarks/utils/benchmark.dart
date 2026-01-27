import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:path/path.dart' as p;

import 'database.dart';

const int rowCount = 10_000;

class CrdtBenchmark extends AsyncBenchmarkBase {
  CrdtBenchmark(super.name, {required this.crdtEnabled});

  final bool crdtEnabled;
  late final CrdtBenchmarkDatabase _db;
  late final File _dbFile;

  int _lastDatabaseSize = 0;
  int _lastRowsCount = 0;

  @override
  Future<void> setup() async {
    final dbPath = p.join(Directory.systemTemp.path, 'benchmark_$name.db');
    _dbFile = File(dbPath);
    _db = CrdtBenchmarkDatabase.createDatabase(_dbFile, crdtEnabled: crdtEnabled);
  }

  @override
  Future<void> run() async {
    final baseTimestamp = DateTime.now();
    _lastDatabaseSize = 0;
    _lastRowsCount = 0;
    for (var i = 0; i < rowCount; i++) {
      await _db.insertTestRow(i, baseTimestamp);
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
