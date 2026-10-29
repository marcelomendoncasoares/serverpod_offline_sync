import 'dart:io';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/migrations/migration_registry.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

void main() {
  group('Given a populated database before replica revisions were introduced,', () {
    late ClientDatabaseSession database;

    setUpAll(() async {
      database = await _populatedDatabase();
    });

    group('when the revision schema migration commits,', () {
      late bool validSchema;
      late List<Map<String, dynamic>> identities;
      late OfflineSyncCapture capture;

      setUpAll(() async {
        await _manager(MigrationRegistry.migrations).migrateToLatest(database);
        validSchema = await MigrationManager.verifyDatabaseIntegrity(database);
        identities = await _identities(database);
        capture = await OfflineSyncEngine(
          syncTables: [client.Person.t],
          serializationManager: database.db.serializationManager,
        ).captureChanges(database, checkpointsBySpaceUuid: {_space: 0});
      });

      test(
        'then every authored identity and attempted value survives with its owning space.',
        () {
          expect(validSchema, isTrue);
          expect(identities, [
            {
              'rowId': 71,
              'fieldId': 81,
              'tombstoneId': 101,
              'attemptId': 91,
              'spaceId': 31,
              'fieldSpace': 31,
              'tombstoneSpace': 31,
            },
          ]);
        },
      );

      test(
        'then a fresh cursor sees the preexisting insert, authored field, and tombstone.',
        () {
          expect(capture.checkpoints.single.revision, 1);
          expect(capture.changes, hasLength(3));
          final inserted = capture.changes.whereType<CrdtMergeInsert>().single;
          final updated = capture.changes.whereType<CrdtMergeUpdate>().single;
          final deleted = capture.changes.whereType<CrdtMergeDelete>().single;
          expect((inserted.data as client.Person).surname, 'authored surname');
          expect(updated.columnName, 'surname');
          expect(updated.value, 'authored surname');
          expect(deleted.clFlag, 2);
          expect(deleted.reason, CrdtDataDeletedReason.userDelete);
        },
      );
    });
  });

  group(
    'Given a populated database whose revision migration fails after a table swap,',
    () {
      late ClientDatabaseSession database;
      late MigrationVersionSql failing;

      setUpAll(() async {
        database = await _populatedDatabase();
        final migration = MigrationRegistry.migrations.last;
        failing = MigrationVersionSql(
          version: migration.version,
          moduleName: migration.moduleName,
          definitionSql: migration.definitionSql,
          migrationSql: migration.migrationSql.replaceFirst(
            'ALTER TABLE "new_crdt_data_fields" RENAME TO "crdt_data_fields";',
            'ALTER TABLE "new_crdt_data_fields" RENAME TO "crdt_data_fields";\n'
                'INSERT INTO "injected_missing_table" DEFAULT VALUES;',
          ),
        );
      });

      group(
        'when the failed migration rolls back and the complete migration is retried,',
        () {
          late Object error;
          late List<int> afterFailure;
          late List<Map<String, dynamic>> afterRetry;

          setUpAll(() async {
            error =
                await _manager([
                      ...MigrationRegistry.migrations.take(
                        MigrationRegistry.migrations.length - 1,
                      ),
                      failing,
                    ])
                    .migrateToLatest(database)
                    .then<Object>(
                      (_) => 'unexpected success',
                      onError: (Object failure) => failure,
                    );
            afterFailure = [
              for (final table in [
                'crdt_data_rows',
                'crdt_data_fields',
                'crdt_data_tombstone',
                'crdt_data_attempted_value',
              ])
                (await database.db.unsafeQuery(
                      'SELECT COUNT(*) AS n FROM "$table"',
                    )).single.toColumnMap()['n']
                    as int,
            ];
            await _manager(MigrationRegistry.migrations).migrateToLatest(database);
            afterRetry = await _identities(database);
          });

          test(
            'then rollback preserves all rows and the retry retains their original identities.',
            () {
              expect(error, isNot('unexpected success'));
              expect(afterFailure, [1, 1, 1, 1]);
              expect(afterRetry.single['rowId'], 71);
              expect(afterRetry.single['fieldId'], 81);
              expect(afterRetry.single['tombstoneId'], 101);
              expect(afterRetry.single['attemptId'], 91);
            },
          );
        },
      );
    },
  );
}

final _space = client.UuidValue.fromString('00000000-0000-4000-8000-000000000031');

MigrationManager _manager(List<MigrationVersionSql> migrations) =>
    MigrationManager.fromMigrations(
      migrations: migrations,
      moduleName: 'serverpod_offline_sync_test',
      runMode: 'development',
    );

/// Fixed pre-revision rows include a dependent attempted value and a tombstone.
/// Raw SQL is necessary because current generated models require the new columns.
Future<ClientDatabaseSession> _populatedDatabase() async {
  final directory = await Directory.systemTemp.createTemp('revision-upgrade-');
  final database = await ClientDatabaseSession.open(
    '${directory.path}/populated.sqlite',
    client.Protocol(),
    clientMigrations: MigrationRegistry.migrations
        .take(MigrationRegistry.migrations.length - 1)
        .toList(),
  );
  addTearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });
  await database.db.unsafeSimpleExecute('''
INSERT INTO "offline_sync_spaces" ("id", "uuidSpaceId") VALUES (31, X'00000000000040008000000000000031');
INSERT INTO "crdt_nodes" ("id", "uuidNodeId") VALUES (41, X'00000000000040008000000000000041');
INSERT INTO "crdt_schema_tables" ("id", "name") VALUES (51, 'person');
INSERT INTO "crdt_schema_columns" ("id", "tblId", "name", "columnType", "dartType", "isNullable") VALUES (61, 51, 'surname', 'text', 'String?', 1);
INSERT INTO "person" ("id", "spaceId", "name", "surname") VALUES (X'00000000000040008000000000000071', 31, 'preserved person', 'projected surname');
INSERT INTO "crdt_data_rows" ("id", "spaceId", "tblId", "uuidRowId", "nodeId", "hlcDatetime", "hlcCounter", "visibility") VALUES (71, 31, 51, X'00000000000040008000000000000071', 41, 1767225600000, 0, 0);
INSERT INTO "crdt_data_fields" ("id", "rowId", "columnId", "nodeId", "hlcDatetime", "hlcCounter") VALUES (81, 71, 61, 41, 1767225600000, 1);
INSERT INTO "crdt_data_tombstone" ("id", "rowId", "nodeId", "hlcDatetime", "hlcCounter", "clFlag", "reason") VALUES (101, 71, 41, 1767225600000, 2, 2, 2);
''');
  await CrdtDataAttemptedValue.db.insertRow(
    database,
    CrdtDataAttemptedValue(
      id: 91,
      fieldId: 81,
      value: 'authored surname',
      projectionReason: CrdtProjectionReason.uniqueConflict,
    ),
  );
  return database;
}

Future<List<Map<String, dynamic>>> _identities(DatabaseSession database) async => [
  for (final row in await database.db.unsafeQuery('''
SELECT r."id" AS "rowId", f."id" AS "fieldId", d."id" AS "tombstoneId", a."id" AS "attemptId",
       r."spaceId", f."spaceId" AS "fieldSpace", d."spaceId" AS "tombstoneSpace"
FROM "crdt_data_rows" r
JOIN "crdt_data_fields" f ON f."rowId" = r."id"
JOIN "crdt_data_tombstone" d ON d."rowId" = r."id"
JOIN "crdt_data_attempted_value" a ON a."fieldId" = f."id"
'''))
    row.toColumnMap(),
];
