import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../test/utils/tables.dart';

part 'crdt_database.g.dart';

@DriftDatabase(tables: [TableWithEveryColumnType])
class CrdtEnabledDatabase extends _$CrdtEnabledDatabase {
  CrdtEnabledDatabase(super.e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;

  @override
  OfflineSyncMigrator createMigrator() => OfflineSyncMigrator(
        this,
        userId: const Uuid().v7(),
        nodeId: const Uuid().v7(),
        synchronizedTables: [tableWithEveryColumnType],
      );
}

CrdtEnabledDatabase createCrdtDatabase(String path) {
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }
  final sqliteDb = sqlite3.open(path);
  return CrdtEnabledDatabase(
    NativeDatabase.opened(sqliteDb, setup: registerHlcFunction),
  );
}
