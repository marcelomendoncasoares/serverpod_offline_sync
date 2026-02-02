import 'package:drift/drift.dart';
import 'package:drift_offline_sync/drift_offline_sync.dart';

import 'tables.dart';
import 'user.dart';

part 'migration.g.dart';

@DriftDatabase(tables: [TodosTable])
class FirstDb extends _$FirstDb {
  FirstDb(super.e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  bool created = false;
  bool didUpgrade = false;
  bool onBeforeOpen = false;

  @override
  int schemaVersion = 1;

  @override
  OfflineSyncMigrator createMigrator() => OfflineSyncMigrator(
    this,
    userId: testUserId,
    nodeId: testNodeId,
  );

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
  SecondDb(super.e) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  bool created = false;
  bool didUpgrade = false;
  bool onBeforeOpen = false;

  @override
  int schemaVersion = 2;

  @override
  OfflineSyncMigrator createMigrator() => OfflineSyncMigrator(
    this,
    userId: testUserId,
    nodeId: testNodeId,
  );

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      created = true;
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from == 1 && to == 2) {
        await m.createTable(users);
        didUpgrade = true;
      }
    },
    beforeOpen: (m) async {
      onBeforeOpen = true;
    },
  );
}
