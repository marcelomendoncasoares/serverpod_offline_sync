import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/outbound_capture_database.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an author with a pending person and an independent writer,', () {
    late SyncNode author;
    late SyncNode peer;
    late Person b;
    late OutboundCaptureDatabase captureDatabase;
    late OfflineSyncDatabaseSession collector;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      peer = await syncNode(await createAdditionalTestSession(), [Person.t]);
      b = Person(id: const Uuid().v7obj(), name: 'B0');
      await author.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(author.offlineSync, b, transaction: tx),
      );
      captureDatabase = OutboundCaptureDatabase(author.raw.db, syncTables: [Person.t]);
      collector = OfflineSyncDatabaseSession(captureDatabase, syncTables: [Person.t]);
      await captureDatabase.initialize();
    });

    group('when a mixed write starts between metadata and payload capture,', () {
      late List<CrdtMergeChange> firstPass;
      late List<String> receivedNames;

      setUpAll(() async {
        final writerZone = Zone.current;
        Future<void>? write;
        captureDatabase.afterInsertMetadata = () async {
          write = writerZone.run(
            () => author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await Person.db.insertRow(
                author.offlineSync,
                Person(id: const Uuid().v7obj(), name: 'A'),
                transaction: tx,
              );
              await Person.db.updateRow(
                author.offlineSync,
                b.copyWith(name: 'B1'),
                columns: (t) => [t.name],
                transaction: tx,
              );
              await Person.db.insertRow(
                author.offlineSync,
                Person(id: const Uuid().v7obj(), name: 'C'),
                transaction: tx,
              );
            }),
          );

          // Let an unprotected writer finish before payload capture resumes.
          // SQLite's snapshot transaction instead keeps this writer queued.
          await Future.any([
            write!,
            Future<void>.delayed(const Duration(milliseconds: 500)),
          ]);
        };

        firstPass = await author.sync
            .collectPendingChanges(
              collector,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();
        await write;
        await peer.sync.mergeInboundBatch(
          peer.raw,
          spaceId: testCrdtUserId,
          mergeSet: firstPass,
        );
        final since = await peer.sync.createSyncSinceHlc(
          peer.raw,
          spaceId: testCrdtUserId,
        );
        final nextPass = await author.sync
            .collectPendingChanges(
              author.raw,
              checkpointsBySpaceUuid: {testCrdtUserId: since.nodeCheckpoints},
            )
            .toList();
        await peer.sync.mergeInboundBatch(
          peer.raw,
          spaceId: testCrdtUserId,
          mergeSet: nextPass,
        );
        receivedNames = (await Person.db.find(
          peer.offlineSync,
        )).map((row) => row.name).toList()..sort();
      });

      test(
        'then the captured payload retains the value from its metadata snapshot.',
        () {
          expect(firstPass, hasLength(1));
          expect(((firstPass.single as CrdtMergeInsert).data as Person).name, 'B0');
        },
      );

      test('then checkpoint delivery preserves every person and the latest name.', () {
        expect(receivedNames, ['A', 'B1', 'C']);
      });
    });
  });

  group(
    'Given an author with a pending person to synchronize,',
    () {
      late SyncNode author;
      late OutboundCaptureDatabase captureDatabase;
      late OfflineSyncDatabaseSession collector;

      setUpAll(() async {
        author = await syncNode(await createAdditionalTestSession(), [Person.t]);
        await author.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            author.offlineSync,
            Person(id: const Uuid().v7obj(), name: 'B0'),
            transaction: tx,
          ),
        );
        captureDatabase = OutboundCaptureDatabase(
          author.raw.db,
          syncTables: [Person.t],
        );
        collector = OfflineSyncDatabaseSession(captureDatabase, syncTables: [Person.t]);
        await captureDatabase.initialize();
      });

      group(
        'when an application transaction queues behind capture and reads before inserting,',
        () {
          Object? writeError;
          late List<String> visibleNames;
          late List<String> committedNames;

          setUpAll(() async {
            final writerZone = Zone.current;
            Future<void>? write;
            visibleNames = [];
            captureDatabase.afterInsertMetadata = () async {
              write = writerZone.run(
                () => author.offlineSync.db
                    .transactionForUser(testCrdtUserId, (tx) async {
                      visibleNames = (await Person.db.find(
                        author.offlineSync,
                        transaction: tx,
                      )).map((row) => row.name).toList();
                      await Person.db.insertRow(
                        author.offlineSync,
                        Person(id: const Uuid().v7obj(), name: 'A'),
                        transaction: tx,
                      );
                    })
                    .then<void>((_) {}, onError: (Object error) => writeError = error),
              );

              await Future<void>.delayed(const Duration(milliseconds: 100));
            };

            await author.sync
                .collectPendingChanges(
                  collector,
                  checkpointsBySpaceUuid: {testCrdtUserId: const []},
                )
                .toList();
            await write;
            committedNames = (await Person.db.find(
              author.offlineSync,
            )).map((row) => row.name).toList()..sort();
          });

          test(
            'then the visible read and write commit after capture releases its lock.',
            () {
              expect(writeError, isNull);
              expect(visibleNames, ['B0']);
              expect(committedNames, ['A', 'B0']);
            },
          );
        },
      );
    },
  );
}
