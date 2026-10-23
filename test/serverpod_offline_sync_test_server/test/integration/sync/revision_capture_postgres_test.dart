import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/outbound_capture_database.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_revision_capture_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL revision capture',
    (sessionBuilder, _) {
      group('Given a pending insertion and an independent PostgreSQL writer,', () {
        late Session raw;
        late OfflineSyncDatabaseSession writer;
        late OutboundCaptureDatabase captureDatabase;
        late OfflineSyncDatabaseSession collector;
        late OfflineSyncEngine engine;
        late UuidValue user;
        late Person person;

        setUpAll(() async {
          raw = sessionBuilder.build();
          user = const Uuid().v7obj();
          writer = OfflineSyncDatabaseSession.wraps(raw, syncTables: [Person.t]);
          await writer.db.initialize();
          person = await writer.db.transactionForUser(
            user,
            (tx) => Person.db.insertRow(
              writer,
              Person(name: 'before capture'),
              transaction: tx,
            ),
          );
          captureDatabase = OutboundCaptureDatabase(raw.db, syncTables: [Person.t]);
          collector = OfflineSyncDatabaseSession(
            captureDatabase,
            syncTables: [Person.t],
          );
          await captureDatabase.initialize();
          engine = OfflineSyncEngine(
            syncTables: [Person.t],
            serializationManager: raw.db.serializationManager,
          );
        });

        group(
          'when the writer commits an insert and edit after capture reads its bound,',
          () {
            late OfflineSyncCapture first;
            late OfflineSyncCapture second;
            late bool committedBeforeFactReads;

            setUpAll(() async {
              final writerZone = Zone.current;
              committedBeforeFactReads = false;
              captureDatabase.afterSpaceBounds = () async {
                await writerZone.run(
                  () => writer.db.transactionForUser(user, (tx) async {
                    await Person.db.insertRow(
                      writer,
                      Person(name: 'later insertion'),
                      transaction: tx,
                    );
                    await Person.db.updateRow(
                      writer,
                      person.copyWith(name: 'later edit'),
                      columns: (t) => [t.name],
                      transaction: tx,
                    );
                  }),
                );
                committedBeforeFactReads = true;
              };
              first = await engine.captureChanges(
                collector,
                checkpointsBySpaceUuid: {user: 0},
              );
              second = await engine.captureChanges(
                raw,
                checkpointsBySpaceUuid: {user: first.checkpoints.single.revision},
              );
            });

            test(
              'then the first bound, metadata, and insertion payload use the same snapshot.',
              () {
                expect(committedBeforeFactReads, isTrue);
                expect(first.checkpoints.single.revision, 1);
                expect(first.changes, hasLength(1));
                expect(
                  (first.changes.single as CrdtMergeInsert).data,
                  isA<Person>().having((row) => row.name, 'name', 'before capture'),
                );
              },
            );

            test(
              'then the next range contains both committed changes at the next revision.',
              () {
                expect(second.checkpoints.single.revision, 2);
                expect(second.changes, hasLength(2));
                expect(
                  (second.changes.whereType<CrdtMergeInsert>().single.data as Person)
                      .name,
                  'later insertion',
                );
                expect(
                  second.changes.whereType<CrdtMergeUpdate>().single.value,
                  'later edit',
                );
              },
            );
          },
        );
      });

      group(
        'Given ten thousand acknowledged facts spread over two PostgreSQL spaces,',
        () {
          late Session raw;
          late UuidValue requested;
          late OutboundCaptureDatabase captureDatabase;
          late OfflineSyncDatabaseSession collector;

          setUpAll(() async {
            raw = sessionBuilder.build();
            await raw.db.unsafeExecute(
              'TRUNCATE offline_sync_spaces, crdt_nodes RESTART IDENTITY CASCADE',
            );
            requested = UuidValue.fromString('00000000-0000-4000-8000-000000000031');
            captureDatabase = OutboundCaptureDatabase(raw.db, syncTables: [Person.t]);
            collector = OfflineSyncDatabaseSession(
              captureDatabase,
              syncTables: [Person.t],
            );
            await captureDatabase.initialize();
            await raw.db.unsafeSimpleExecute('''
INSERT INTO "offline_sync_spaces" ("id", "uuidSpaceId", "syncRevision") VALUES
(31, '$requested', 1), (32, '00000000-0000-4000-8000-000000000032', 1);
INSERT INTO "crdt_nodes" ("id", "uuidNodeId") VALUES (41, '00000000-0000-4000-8000-000000000041');
INSERT INTO "crdt_data_rows" ("id", "spaceId", "tblId", "uuidRowId", "nodeId", "hlcDatetime", "hlcCounter", "visibility", "syncRevision")
SELECT g, 31 + g % 2, (SELECT "id" FROM "crdt_schema_tables" WHERE "name" = 'person'), md5(g::text)::uuid, 41, '2026-01-01', 0, 0, 1 FROM generate_series(1000, 10999) g;
INSERT INTO "crdt_data_fields" ("spaceId", "rowId", "columnId", "nodeId", "hlcDatetime", "hlcCounter", "syncRevision")
SELECT r."spaceId", r."id", (SELECT c."id" FROM "crdt_schema_columns" c JOIN "crdt_schema_tables" t ON t."id" = c."tblId" WHERE t."name" = 'person' AND c."name" = 'name'), 41, '2026-01-01', 1, 1 FROM "crdt_data_rows" r;
INSERT INTO "crdt_data_tombstone" ("spaceId", "rowId", "nodeId", "hlcDatetime", "hlcCounter", "clFlag", "reason", "syncRevision")
SELECT "spaceId", "id", 41, '2026-01-01', 2, 2, 2, 1 FROM "crdt_data_rows";
ANALYZE "crdt_data_rows";
ANALYZE "crdt_data_fields";
ANALYZE "crdt_data_tombstone";
''');
          });

          group(
            'when production capture requests only a new range from one space,',
            () {
              late OfflineSyncCapture capture;
              late String plan;

              setUpAll(() async {
                capture =
                    await OfflineSyncEngine(
                      syncTables: [Person.t],
                      serializationManager: raw.db.serializationManager,
                    ).captureChanges(
                      collector,
                      checkpointsBySpaceUuid: {requested: 1},
                      peerId: 123,
                    );
                final predicate = captureDatabase.predicates['crdt_data_rows']!;
                final result = await raw.db.unsafeQuery(
                  'EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM "crdt_data_rows" '
                  'WHERE $predicate',
                );
                plan = result.map((row) => row.single).join('\n');
                print(plan);
              });

              test(
                'then candidate discovery uses all three space revision indexes.',
                () {
                  expect(capture.changes, isEmpty);
                  for (final table in [
                    'crdt_data_rows',
                    'crdt_data_fields',
                    'crdt_data_tombstone',
                  ]) {
                    expect(
                      plan,
                      contains('${table}_space_revision_idx'),
                      reason: plan,
                    );
                  }
                  expect(plan, isNot(contains('Seq Scan')), reason: plan);
                  expect(plan, contains('"spaceId" = 31'), reason: plan);
                  expect(plan, contains('"syncRevision" > 1'), reason: plan);
                },
              );
            },
          );
        },
      );
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
