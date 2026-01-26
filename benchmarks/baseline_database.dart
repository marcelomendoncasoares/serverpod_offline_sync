import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import '../test/utils/tables.dart';

part 'baseline_database.g.dart';

@DriftDatabase(tables: [TableWithEveryColumnType])
class BaselineDatabase extends _$BaselineDatabase {
  BaselineDatabase(super.e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;
}

BaselineDatabase createBaselineDatabase(String path) {
  final file = File(path);
  if (file.existsSync()) {
    file.deleteSync();
  }
  final sqliteDb = sqlite3.open(path);
  return BaselineDatabase(NativeDatabase.opened(sqliteDb));
}
