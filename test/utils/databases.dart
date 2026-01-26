// TODO: Remove this file in favor of the database.dart file.

import 'package:drift/drift.dart';

import 'tables.dart';

part 'databases.g.dart';

@DriftDatabase(tables: [TodosTable])
class FirstDb extends _$FirstDb {
  FirstDb(super.e);

  bool created = false;
  bool didUpgrade = false;
  bool onBeforeOpen = false;

  @override
  int schemaVersion = 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      created = true;
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        didUpgrade = true;
      }
    },
    beforeOpen: (m) async {
      onBeforeOpen = true;
    },
  );
}

@DriftDatabase(tables: [Users])
class SecondDb extends _$SecondDb {
  SecondDb(super.e);

  bool created = false;
  bool didUpgrade = false;
  bool onBeforeOpen = false;

  @override
  int schemaVersion = 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      created = true;
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        didUpgrade = true;
      }
    },
    beforeOpen: (m) async {
      onBeforeOpen = true;
    },
  );
}
