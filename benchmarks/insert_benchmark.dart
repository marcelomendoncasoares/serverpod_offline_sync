import 'dart:io';

import 'package:drift/drift.dart';

import 'baseline_database.dart' as baseline;
import 'crdt_database.dart' as crdt;

class BaselineInsertBenchmark {
  late baseline.BaselineDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_baseline.db';
    db = baseline.createBaselineDatabase(dbPath);
  }

  Future<void> run() async {
    for (var i = 0; i < rowCount; i++) {
      await db.into(db.tableWithEveryColumnType).insert(
            baseline.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(DateTime.now()),
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

  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class CrdtInsertBenchmark {
  late crdt.CrdtEnabledDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_crdt.db';
    db = crdt.createCrdtDatabase(dbPath);
  }

  Future<void> run() async {
    for (var i = 0; i < rowCount; i++) {
      await db.into(db.tableWithEveryColumnType).insert(
            crdt.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(DateTime.now()),
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

  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class BaselineStorageBenchmark {
  late baseline.BaselineDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_baseline_storage.db';
    db = baseline.createBaselineDatabase(dbPath);

    for (var i = 0; i < rowCount; i++) {
      await db.into(db.tableWithEveryColumnType).insert(
            baseline.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(DateTime.now()),
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

  int measure() {
    return File(dbPath).lengthSync();
  }

  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}

class CrdtStorageBenchmark {
  late crdt.CrdtEnabledDatabase db;
  late String dbPath;
  static const int rowCount = 10000;

  Future<void> setup() async {
    dbPath = '${Directory.systemTemp.path}/benchmark_crdt_storage.db';
    db = crdt.createCrdtDatabase(dbPath);

    for (var i = 0; i < rowCount; i++) {
      await db.into(db.tableWithEveryColumnType).insert(
            crdt.TableWithEveryColumnTypeCompanion.insert(
              aBool: Value(i.isEven),
              aDateTime: Value(DateTime.now()),
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

  int measure() {
    return File(dbPath).lengthSync();
  }

  Future<void> teardown() async {
    await db.close();
    File(dbPath).deleteSync();
  }
}
