import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_revision_upgrade_${const Uuid().v4()}',
  );
  late String migrationSql;

  setUpAll(() async {
    final versions = (await File(
      'migrations/migration_registry.txt',
    ).readAsLines()).where((line) => RegExp(r'^\d+$').hasMatch(line)).toList();
    await preparePostgresMigrations(
      serverDirectory,
      schemaVersion: versions[versions.length - 2],
    );
    migrationSql = (await File(
      'migrations/${versions.last}/migration.postgres.sql',
    ).readAsString()).replaceFirst('BEGIN;', '').replaceFirst('COMMIT;', '');
  });

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL revision schema',
    (sessionBuilder, _) {
      group('Given populated PostgreSQL metadata before replica revisions,', () {
        late Session session;

        setUpAll(() async {
          session = sessionBuilder.build();
          await session.db.unsafeSimpleExecute('''
INSERT INTO "offline_sync_spaces" ("id", "uuidSpaceId") VALUES (31, '00000000-0000-4000-8000-000000000031');
INSERT INTO "crdt_nodes" ("id", "uuidNodeId") VALUES (41, '00000000-0000-4000-8000-000000000041');
INSERT INTO "crdt_schema_tables" ("id", "name") VALUES (51, 'person');
INSERT INTO "crdt_schema_columns" ("id", "tblId", "name", "columnType", "dartType", "isNullable") VALUES (61, 51, 'surname', 'text', 'String?', true);
INSERT INTO "person" ("id", "spaceId", "name", "surname") VALUES ('00000000-0000-4000-8000-000000000071', 31, 'preserved person', 'projected surname');
INSERT INTO "crdt_data_rows" ("id", "spaceId", "tblId", "uuidRowId", "nodeId", "hlcDatetime", "hlcCounter", "visibility") VALUES (71, 31, 51, '00000000-0000-4000-8000-000000000071', 41, '2026-01-01', 0, 0);
INSERT INTO "crdt_data_fields" ("id", "rowId", "columnId", "nodeId", "hlcDatetime", "hlcCounter") VALUES (81, 71, 61, 41, '2026-01-01', 1);
INSERT INTO "crdt_data_tombstone" ("id", "rowId", "nodeId", "hlcDatetime", "hlcCounter", "clFlag", "reason") VALUES (101, 71, 41, '2026-01-01', 2, 2, 2);
''');
          await CrdtDataAttemptedValue.db.insertRow(
            session,
            CrdtDataAttemptedValue(
              id: 91,
              fieldId: 81,
              value: 'authored surname',
              projectionReason: CrdtProjectionReason.uniqueConflict,
            ),
          );
        });

        group('when a failed backfill rolls back and the complete upgrade is retried,', () {
          late Object error;
          late int oldFieldCount;
          late List<Map<String, dynamic>> identities;
          late List<Map<String, dynamic>> requiredColumns;
          late OfflineSyncCapture capture;

          setUpAll(() async {
            final failingSql = migrationSql.replaceFirst(
              'ALTER TABLE "crdt_data_fields" ALTER COLUMN "spaceId" SET NOT NULL;',
              'ALTER TABLE "crdt_data_fields" ALTER COLUMN "spaceId" SET NOT NULL;\n'
                  'INSERT INTO "injected_missing_table" DEFAULT VALUES;',
            );
            error = await session.db
                .transaction(
                  (tx) => session.db.unsafeSimpleExecute(failingSql, transaction: tx),
                )
                .then<Object>(
                  (_) => 'unexpected success',
                  onError: (Object failure) => failure,
                );
            oldFieldCount =
                (await session.db.unsafeQuery(
                      'SELECT count(*) FROM "crdt_data_fields"',
                    )).single.single
                    as int;
            await session.db.transaction(
              (tx) => session.db.unsafeSimpleExecute(migrationSql, transaction: tx),
            );
            identities = [
              for (final row in await session.db.unsafeQuery('''
SELECT r."id" AS "rowId", f."id" AS "fieldId", d."id" AS "tombstoneId", a."id" AS "attemptId",
       r."spaceId", f."spaceId" AS "fieldSpace", d."spaceId" AS "tombstoneSpace"
FROM "crdt_data_rows" r
JOIN "crdt_data_fields" f ON f."rowId" = r."id"
JOIN "crdt_data_tombstone" d ON d."rowId" = r."id"
JOIN "crdt_data_attempted_value" a ON a."fieldId" = f."id"
'''))
                row.toColumnMap(),
            ];
            requiredColumns = [
              for (final row in await session.db.unsafeQuery('''
SELECT table_name, is_nullable FROM information_schema.columns
WHERE table_name IN ('crdt_data_fields', 'crdt_data_tombstone') AND column_name = 'spaceId'
ORDER BY table_name
'''))
                row.toColumnMap(),
            ];
            capture =
                await OfflineSyncEngine(
                  syncTables: [Person.t],
                  serializationManager: session.db.serializationManager,
                ).captureChanges(
                  session,
                  checkpointsBySpaceUuid: {
                    UuidValue.fromString('00000000-0000-4000-8000-000000000031'): 0,
                  },
                );
          });

          test(
            'then rollback and direct ALTER preserve authored identities and required space ownership.',
            () {
              expect(error, isNot('unexpected success'));
              expect(oldFieldCount, 1);
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
              expect(requiredColumns.map((column) => column['is_nullable']), [
                'NO',
                'NO',
              ]);
            },
          );

          test(
            'then a fresh receiver captures every preexisting authored fact at revision one.',
            () {
              expect(capture.checkpoints.single.revision, 1);
              expect(capture.changes, hasLength(3));
              expect(
                (capture.changes.whereType<CrdtMergeInsert>().single.data as Person)
                    .surname,
                'authored surname',
              );
              expect(
                capture.changes.whereType<CrdtMergeUpdate>().single.value,
                'authored surname',
              );
              expect(capture.changes.whereType<CrdtMergeDelete>().single.clFlag, 2);
            },
          );
        });
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      apiServer: ServerConfig(
        port: 0,
        publicHost: 'localhost',
        publicPort: 0,
        publicScheme: 'http',
      ),
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${serverDirectory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
  );
}
