import 'dart:io';

import 'package:drift/drift.dart';

import 'baseline_database.dart' as baseline;
import 'crdt_database.dart' as crdt;

abstract class InsertBenchmark {
  Future<void> setup();
  Future<void> run();
  Future<void> teardown();
}

abstract class StorageBenchmark {
  Future<void> setup();
  int measure();
  Future<void> teardown();
}

class BaselineInsertBenchmark implements InsertBenchmark {
  late baseline.BaselineDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  @override
  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_baseline.db';
    db = baseline.createBaselineDatabase(dbPath);
  }

  @override
  Future<void> run() async {
    final baseTimestamp = DateTime.now();
    for (var i = 0; i < rowCount; i++) {
      await db
          .into(db.tableWithEveryColumnType)
          .insert(
            baseline.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(baseTimestamp.add(Duration(seconds: i))),
              aText: Value('Text $i'),
              anInt: Value(i),
              anInt64: Value(BigInt.from(i)),
              aReal: Value(i.toDouble()),
              aBlob: Value(Uint8List.fromList([i % 256])),
              anIntEnum: const Value(null),
              aTextWithConverter: const Value(null),
              aUuid: const Value(null),
            ),
          );
    }
  }

  @override
  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class CrdtInsertBenchmark implements InsertBenchmark {
  late crdt.CrdtEnabledDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  @override
  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_crdt.db';
    db = crdt.createCrdtDatabase(dbPath);
  }

  @override
  Future<void> run() async {
    final baseTimestamp = DateTime.now();
    for (var i = 0; i < rowCount; i++) {
      await db
          .into(db.tableWithEveryColumnType)
          .insert(
            crdt.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(baseTimestamp.add(Duration(seconds: i))),
              aText: Value('Text $i'),
              anInt: Value(i),
              anInt64: Value(BigInt.from(i)),
              aReal: Value(i.toDouble()),
              aBlob: Value(Uint8List.fromList([i % 256])),
              anIntEnum: const Value(null),
              aTextWithConverter: const Value(null),
              aUuid: const Value(null),
            ),
          );
    }
  }

  @override
  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class BaselineStorageBenchmark implements StorageBenchmark {
  late baseline.BaselineDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  @override
  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_baseline_storage.db';
    db = baseline.createBaselineDatabase(dbPath);

    final baseTimestamp = DateTime.now();
    for (var i = 0; i < rowCount; i++) {
      await db
          .into(db.tableWithEveryColumnType)
          .insert(
            baseline.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(baseTimestamp.add(Duration(seconds: i))),
              aText: Value('Text $i'),
              anInt: Value(i),
              anInt64: Value(BigInt.from(i)),
              aReal: Value(i.toDouble()),
              aBlob: Value(Uint8List.fromList([i % 256])),
              anIntEnum: const Value(null),
              aTextWithConverter: const Value(null),
              aUuid: const Value(null),
            ),
          );
    }
  }

  @override
  int measure() {
    return File(dbPath).lengthSync();
  }

  @override
  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class CrdtStorageBenchmark implements StorageBenchmark {
  late crdt.CrdtEnabledDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  @override
  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_crdt_storage.db';
    db = crdt.createCrdtDatabase(dbPath);

    final baseTimestamp = DateTime.now();
    for (var i = 0; i < rowCount; i++) {
      await db
          .into(db.tableWithEveryColumnType)
          .insert(
            crdt.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(baseTimestamp.add(Duration(seconds: i))),
              aText: Value('Text $i'),
              anInt: Value(i),
              anInt64: Value(BigInt.from(i)),
              aReal: Value(i.toDouble()),
              aBlob: Value(Uint8List.fromList([i % 256])),
              anIntEnum: const Value(null),
              aTextWithConverter: const Value(null),
              aUuid: const Value(null),
            ),
          );
    }
  }

  @override
  int measure() {
    return File(dbPath).lengthSync();
  }

  @override
  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}
