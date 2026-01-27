import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../test/utils/tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [TableWithEveryColumnType])
class CrdtBenchmarkDatabase extends _$CrdtBenchmarkDatabase {
  CrdtBenchmarkDatabase(super.e, {required this.crdtEnabled}) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  static CrdtBenchmarkDatabase createDatabase(
    File file, {
    required bool crdtEnabled,
  }) {
    if (file.existsSync()) {
      file.deleteSync();
    }

    return CrdtBenchmarkDatabase(
      NativeDatabase.opened(
        sqlite3.open(file.path),
        setup: crdtEnabled ? registerHlcFunction : null,
      ),
      crdtEnabled: crdtEnabled,
    );
  }

  final bool crdtEnabled;

  @override
  int get schemaVersion => 1;

  @override
  Migrator createMigrator() => !crdtEnabled
      ? super.createMigrator()
      : OfflineSyncMigrator(
          this,
          userId: const Uuid().v7(),
          nodeId: const Uuid().v7(),
          synchronizedTables: [tableWithEveryColumnType],
        );

  Future<void> insertTestRow(int i, DateTime baseTimestamp) async {
    await managers.tableWithEveryColumnType.create(
      (t) => t(
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

  Future<int> testRowsCount() async {
    return managers.tableWithEveryColumnType.count();
  }
}
