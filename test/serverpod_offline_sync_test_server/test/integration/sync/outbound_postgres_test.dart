import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/outbound_capture_database.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/outbound_postgres_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL outbound snapshots]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: directory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 8,
      ),
    ),
    (sessions, _) {
      late Session raw;
      late OfflineSyncDatabaseSession author;
      late OfflineSyncEngine engine;

      setUpAll(() async {
        raw = sessions.build();
        author = OfflineSyncDatabaseSession.wraps(raw, syncTables: server.syncTables);
        await author.db.initialize();
        engine = OfflineSyncEngine(
          syncTables: server.syncTables,
          serializationManager: raw.db.serializationManager,
        );
      });

      group('Given a pending PostgreSQL insertion and an independent writer,', () {
        late UuidValue space;
        late server.Person person;
        late server.Person later;
        late OfflineSyncDatabaseSession collector;
        late OutboundCaptureDatabase capture;
        late OfflineSyncDatabaseSession writer;

        setUpAll(() async {
          space = const Uuid().v7obj();
          person = server.Person(id: const Uuid().v7obj(), name: 'before');
          later = server.Person(id: const Uuid().v7obj(), name: 'later');
          await author.db.transactionForUser(
            space,
            (tx) => server.Person.db.insertRow(author, person, transaction: tx),
          );
          capture = OutboundCaptureDatabase(raw.db, syncTables: server.syncTables);
          collector = OfflineSyncDatabaseSession(
            capture,
            syncTables: server.syncTables,
          );
          await collector.db.initialize();
          writer = OfflineSyncDatabaseSession.wraps(
            sessions.build(),
            syncTables: server.syncTables,
          );
          await writer.db.initialize();
        });

        group('when the writer commits between metadata and payload reads,', () {
          late List<CrdtMergeChange> first;
          late List<CrdtMergeChange> next;
          late bool committedDuringCapture;

          setUpAll(() async {
            committedDuringCapture = false;
            final writerZone = Zone.current;
            capture.afterInsertMetadata = () => writerZone.run(() async {
              await writer.db.transactionForUser(space, (tx) async {
                await server.Person.db.updateRow(
                  writer,
                  person.copyWith(name: 'after'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
                await server.Person.db.insertRow(writer, later, transaction: tx);
              });
              committedDuringCapture = true;
            });
            first = await engine
                .collectPendingChanges(
                  collector,
                  checkpointsBySpaceUuid: {space: const []},
                )
                .toList();
            next = await engine
                .collectPendingChanges(
                  raw,
                  checkpointsBySpaceUuid: {
                    space: [first.single.hlc],
                  },
                )
                .toList();
          });

          test('then the first payload comes from the original snapshot.', () {
            expect(committedDuringCapture, isTrue);
            expect(first, hasLength(1));
            expect(
              ((first.single as CrdtMergeInsert).data as server.Person).name,
              'before',
            );
          });

          test('then the next checkpoint pass retains both later facts.', () {
            expect(next, hasLength(2));
            expect(next[0], isA<CrdtMergeInsert>());
            expect(next[0].uuidRowId, later.id);
            expect(next[1], isA<CrdtMergeUpdate>());
            expect(next[1].uuidRowId, person.id);
            expect((next[1] as CrdtMergeUpdate).value, 'after');
          });
        });
      });

      group('Given checkpointed rows followed by an insert, update and delete,', () {
        late UuidValue space;
        late server.Person inserted;
        late server.Person updated;
        late server.Person deleted;
        late List<Hlc> checkpoints;

        setUpAll(() async {
          space = const Uuid().v7obj();
          inserted = server.Person(id: const Uuid().v7obj(), name: 'new');
          updated = server.Person(id: const Uuid().v7obj(), name: 'before');
          deleted = server.Person(id: const Uuid().v7obj(), name: 'deleted');
          await author.db.transactionForUser(space, (tx) async {
            await server.Person.db.insert(author, [updated, deleted], transaction: tx);
          });
          final initial = await engine
              .collectPendingChanges(raw, checkpointsBySpaceUuid: {space: const []})
              .toList();
          checkpoints = [initial.map((c) => c.hlc).reduce((a, b) => a.maxBetween(b))];
          await author.db.transactionForUser(space, (tx) async {
            await server.Person.db.insertRow(author, inserted, transaction: tx);
            await server.Person.db.updateRow(
              author,
              updated.copyWith(name: 'after'),
              columns: (t) => [t.name],
              transaction: tx,
            );
            await server.Person.db.deleteRow(author, deleted, transaction: tx);
          });
          await author.db.transactionForUser(const Uuid().v7obj(), (tx) async {
            await server.Person.db.insertRow(
              author,
              server.Person(name: 'outside the requested space'),
              transaction: tx,
            );
          });
        });

        group('when the space delta is captured,', () {
          late List<CrdtMergeChange> changes;
          late List<CrdtMergeChange> caughtUp;

          setUpAll(() async {
            changes = await engine
                .collectPendingChanges(
                  raw,
                  checkpointsBySpaceUuid: {space: checkpoints},
                )
                .toList();
            final max = changes.map((c) => c.hlc).reduce((a, b) => a.maxBetween(b));
            caughtUp = await engine
                .collectPendingChanges(
                  raw,
                  checkpointsBySpaceUuid: {
                    space: [max],
                  },
                )
                .toList();
          });

          test(
            'then it emits only the pending facts in insert, update, delete order.',
            () {
              expect(changes, hasLength(3));
              expect(changes.map((c) => c.uuidSpaceId), everyElement(space));
              expect(changes[0], isA<CrdtMergeInsert>());
              expect(changes[0].uuidRowId, inserted.id);
              expect(changes[1], isA<CrdtMergeUpdate>());
              expect(changes[1].uuidRowId, updated.id);
              expect((changes[1] as CrdtMergeUpdate).value, 'after');
              expect(changes[2], isA<CrdtMergeDelete>());
              expect(changes[2].uuidRowId, deleted.id);
            },
          );

          test(
            'then a checkpoint covering the captured facts produces no changes.',
            () {
              expect(caughtUp, isEmpty);
            },
          );
        });
      });

      group(
        'Given an unseen insertion with a checkpointed projected reference edit,',
        () {
          late UuidValue space;
          late UuidValue missingCity;
          late server.Person person;
          late Hlc edited;

          setUpAll(() async {
            space = const Uuid().v7obj();
            missingCity = const Uuid().v7obj();
            person = server.Person(id: const Uuid().v7obj(), name: 'projected');
            final inserted = Hlc.now(const Uuid().v7obj());
            edited = Hlc(inserted.datetime, 1, const Uuid().v7obj());
            await author.db.mergeChanges([
              CrdtMergeInsert(
                uuidSpaceId: space,
                tableName: 'person',
                uuidRowId: person.id!,
                uuidNodeId: inserted.nodeId,
                hlcDatetime: inserted.datetime,
                hlcCounter: inserted.counter,
                data: person,
              ),
              CrdtMergeUpdate(
                uuidSpaceId: space,
                tableName: 'person',
                uuidRowId: person.id!,
                uuidNodeId: edited.nodeId,
                hlcDatetime: edited.datetime,
                hlcCounter: edited.counter,
                columnName: 'cityId',
                value: missingCity,
              ),
            ], userId: space);
          });

          group('when collection covers the editor but not the insertion author,', () {
            late List<CrdtMergeChange> changes;
            late server.Person? visible;

            setUpAll(() async {
              changes = await engine
                  .collectPendingChanges(
                    raw,
                    checkpointsBySpaceUuid: {
                      space: [edited],
                    },
                  )
                  .toList();
              visible = await server.Person.db.findById(raw, person.id!);
            });

            test(
              'then the insert carries the authored reference without repeating the edit.',
              () {
                expect(visible?.cityId, isNull);
                expect(changes, hasLength(1));
                final insert = changes.single as CrdtMergeInsert;
                expect(insert.uuidRowId, person.id);
                expect((insert.data as server.Person).cityId, missingCity);
              },
            );
          });
        },
      );
    },
  );
}
