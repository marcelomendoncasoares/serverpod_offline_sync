import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a received person with an unsent local name edit,', () {
    late SyncNode author;
    late SyncNode receiver;
    late Person person;
    late int insertionRevision;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      person = Person(id: const Uuid().v7obj(), name: 'original', surname: 'original');
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(author.offlineSync, person, transaction: tx);
      });
      await pushChanges(author, receiver);
      insertionRevision = (await CrdtDataRow.db.find(receiver.raw)).single.syncRevision;
      await receiver.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.updateRow(
          receiver.offlineSync,
          person.copyWith(name: 'local name'),
          columns: (t) => [t.name],
          transaction: tx,
        );
      });
    });

    group('when the original sender supplies a newer surname,', () {
      late OfflineSyncCapture outgoing;
      late List<CrdtDataField> fields;
      late CrdtDataRow insertion;
      late Person converged;

      setUpAll(() async {
        await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.updateRow(
            author.offlineSync,
            person.copyWith(surname: 'remote surname'),
            columns: (t) => [t.surname],
            transaction: tx,
          );
        });
        final remote = await author.sync.captureChanges(
          author.raw,
          checkpointsBySpaceUuid: {
            testCrdtUserId: await peerCheckpoint(author, receiver),
          },
        );
        await deliverCapture(author, receiver, remote);
        final sender = await receiver.sync.resolvePeer(
          receiver.raw,
          testCrdtUserId,
          await author.offlineSync.db.currentNodeId(userId: testCrdtUserId),
        );
        outgoing = await receiver.sync.captureChanges(
          receiver.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: 0},
          peerId: sender.id,
        );
        fields = await CrdtDataField.db.find(
          receiver.raw,
          include: CrdtDataField.include(column: CrdtSchemaColumn.include()),
        );
        insertion = (await CrdtDataRow.db.find(receiver.raw)).single;
        await deliverCapture(receiver, author, outgoing);
        converged = (await Person.db.findById(author.raw, person.id!))!;
      });

      test('then only the unsent name is returned to that sender.', () {
        expect(outgoing.changes, hasLength(1));
        final update = outgoing.changes.single as CrdtMergeUpdate;
        expect(update.columnName, 'name');
        expect(update.value, 'local name');
        expect(converged.name, 'local name');
        expect(converged.surname, 'remote surname');
      });

      test('then provenance and revisions belong to individual authored facts.', () {
        final name = fields.singleWhere((field) => field.column!.name == 'name');
        final surname = fields.singleWhere((field) => field.column!.name == 'surname');
        expect(name.sourcePeerId, isNull);
        expect(surname.sourcePeerId, insertion.sourcePeerId);
        expect(insertion.sourcePeerId, isNotNull);
        expect(insertion.syncRevision, insertionRevision);
        expect(name.syncRevision, greaterThan(insertionRevision));
        expect(surname.syncRevision, greaterThan(name.syncRevision));
      });
    });
  });

  group('Given an acknowledged insertion with repeated local edits to one field,', () {
    late SyncNode author;
    late SyncNode receiver;
    late Person person;
    late CrdtDataRow before;
    late int cursor;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      person = Person(id: const Uuid().v7obj(), name: 'original');
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(author.offlineSync, person, transaction: tx);
      });
      await pushChanges(author, receiver);
      cursor = await peerCheckpoint(author, receiver);
      before = (await CrdtDataRow.db.find(author.raw)).single;
      for (final name in ['first edit', 'second edit', 'final edit']) {
        await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.updateRow(
            author.offlineSync,
            person.copyWith(name: name),
            columns: (t) => [t.name],
            transaction: tx,
          );
        });
      }
    });

    group('when the next complete revision range is delivered,', () {
      late OfflineSyncCapture capture;
      late CrdtDataRow after;
      late String received;

      setUpAll(() async {
        capture = await author.sync.captureChanges(
          author.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: cursor},
        );
        await deliverCapture(author, receiver, capture);
        after = (await CrdtDataRow.db.find(author.raw)).single;
        received = (await Person.db.findById(receiver.raw, person.id!))!.name;
      });

      test('then the latest field value arrives without another insertion.', () {
        expect(capture.changes, hasLength(1));
        expect(capture.changes.single, isA<CrdtMergeUpdate>());
        expect(received, 'final edit');
        expect(capture.checkpoints.single.revision, greaterThan(cursor));
      });

      test('then the insertion fact retains its original clock and revision.', () {
        expect(after.hlcDatetime, before.hlcDatetime);
        expect(after.hlcCounter, before.hlcCounter);
        expect(after.syncRevision, before.syncRevision);
      });
    });
  });

  group('Given a received fact larger than the former stream retention limit,', () {
    late SyncNode receiver;
    late FramedSyncPeer peer;
    late OfflineSyncCapture capture;
    late List<String> expected;

    setUpAll(() async {
      final author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          author.offlineSync,
          Person(id: const Uuid().v7obj(), name: 'large payload ' * 15000),
          transaction: tx,
        );
      });
      capture = await author.sync.captureChanges(
        author.raw,
        checkpointsBySpaceUuid: {testCrdtUserId: 0},
      );
      expected = (await Person.db.find(author.raw)).map(jsonEncode).toList();
      peer = await FramedSyncPeer.open(receiver);
    });

    group('when the complete batch is committed and scanned,', () {
      late List<CrdtMergeChange> echoes;
      late List<String> actual;
      late int emptyBoundaries;

      setUpAll(() async {
        await peer.sendBatch(capture.changes);
        await peer.close();
        echoes = List.of(peer.outbound);
        actual = (await Person.db.find(receiver.raw)).map(jsonEncode).toList();
        emptyBoundaries = peer.events.whereType<OfflineSyncEndOfBatch>().length;
      });

      test('then the exact payload commits without an echo or empty return batch.', () {
        expect(actual, expected);
        expect(echoes, isEmpty);
        expect(emptyBoundaries, 0);
      });
    });
  });

  group('Given two replicas that received the same fact from a third replica,', () {
    late SyncNode first;
    late SyncNode second;
    late int before;

    setUpAll(() async {
      final original = await syncNode(await createAdditionalTestSession(), [Person.t]);
      first = await syncNode(await createAdditionalTestSession(), [Person.t]);
      second = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await original.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          original.offlineSync,
          Person(id: const Uuid().v7obj(), name: 'shared fact'),
          transaction: tx,
        );
      });
      await pushChanges(original, first);
      await pushChanges(original, second);
      before = (await OfflineSyncSpace.db.find(second.raw)).single.syncRevision;
    });

    group('when a different immediate peer replays that fact and resumes,', () {
      late int after;
      late OfflineSyncCapture pending;
      late List<OfflineSyncPeerCheckpoint> receipts;

      setUpAll(() async {
        final replay = await first.sync.captureChanges(
          first.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: 0},
        );
        await deliverCapture(first, second, replay);
        after = (await OfflineSyncSpace.db.find(second.raw)).single.syncRevision;
        receipts = await OfflineSyncPeerCheckpoint.db.find(second.raw);
        pending = await first.sync.captureChanges(
          first.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: await peerCheckpoint(first, second)},
        );
      });

      test(
        'then one safe replay commits a receipt without creating another fact revision.',
        () {
          expect(after, before);
          expect(receipts, hasLength(2));
          expect(pending.changes, isEmpty);
        },
      );
    });
  });

  group('Given a space whose peer advertises a cursor beyond this database epoch,', () {
    late SyncNode node;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (_) async {});
    });

    test(
      'when capture starts, then it rejects the cursor instead of skipping data.',
      () async {
        await expectLater(
          node.sync.captureChanges(
            node.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: 1},
          ),
          throwsStateError,
        );
      },
    );
  });

  group('Given an explicit clock persistence inside a nested space savepoint,', () {
    late SyncNode node;
    late CrdtMutationRecorder recorder;
    late Clock fixedClock;

    setUpAll(() async {
      final raw = await createAdditionalTestSession();
      final context = OfflineSyncDatabaseContext(
        syncTables: [Person.t],
        serializationManager: raw.db.serializationManager,
      );
      final wrapped = OfflineSyncDatabaseSession.wraps(
        raw,
        syncTables: [Person.t],
        context: context,
      );
      await wrapped.db.initialize();
      node = (
        raw: raw,
        offlineSync: wrapped,
        sync: OfflineSyncEngine(
          syncTables: [Person.t],
          serializationManager: raw.db.serializationManager,
        ),
      );
      recorder = CrdtMutationRecorder(raw.db, context: context, persistentUserId: null);
      fixedClock = Clock.fixed(DateTime.utc(2030));
    });

    group(
      'when the savepoint rolls back and its surrounding transaction writes successfully,',
      () {
        late List<String> names;
        late CrdtDataRow metadata;
        late CrdtNode clock;
        late OfflineSyncCapture capture;

        setUpAll(() async {
          await withClock(
            fixedClock,
            () => node.offlineSync.db.transactionForSpaces(
              testCrdtUserId,
              {testCrdtUserId},
              (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
                try {
                  await spaces.runForSpace(testCrdtUserId, (nested) async {
                    await Person.db.insertRow(
                      node.offlineSync,
                      Person(id: const Uuid().v7obj(), name: 'discarded'),
                      transaction: nested,
                    );
                    await recorder.persistUserClock(nested);
                    throw Exception('rollback');
                  });
                } on Exception {
                  // Continue the containing transaction after the nested rollback.
                }
                await Person.db.insertRow(
                  node.offlineSync,
                  Person(id: const Uuid().v7obj(), name: 'committed'),
                  transaction: tx,
                );
              }),
            ),
          );
          names = (await Person.db.find(node.raw)).map((row) => row.name).toList();
          metadata = (await CrdtDataRow.db.find(
            node.raw,
            include: CrdtDataRow.include(node: CrdtNode.include()),
          )).single;
          clock = (await CrdtNode.db.find(node.raw)).single;
          capture = await node.sync.captureChanges(
            node.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: 0},
          );
        });

        test(
          'then only the committed row is visible through the complete revision bound.',
          () {
            expect(names, ['committed']);
            expect(capture.changes.single.uuidRowId, metadata.uuidRowId);
            expect(capture.checkpoints.single.revision, metadata.syncRevision);
            expect(metadata.syncRevision, 1);
          },
        );

        test(
          'then the committed user clock is not hidden by rolled-back persistence state.',
          () {
            expect(clock.lastHlc, metadata.hlc);
          },
        );
      },
    );
  });
  group('Given twenty untouched shared spaces and one changed personal space,', () {
    late SyncNode author;
    late SyncNode receiver;
    late FramedSyncPeer sending;
    late FramedSyncPeer receiving;
    late OfflineSyncEndOfBatch boundary;
    late List<CrdtMergeChange> changes;
    var merges = 0;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      for (var index = 0; index < 20; index++) {
        final uuid = const Uuid().v7obj();
        for (final node in [author, receiver]) {
          final space = await OfflineSyncSpaceManager(node.raw).getOrCreate(uuid);
          await OfflineSyncSpaceMember.db.insertRow(
            node.raw,
            OfflineSyncSpaceMember(
              spaceId: space.id!,
              userUuid: testCrdtUserId,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );
        }
      }
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          author.offlineSync,
          Person(id: const Uuid().v7obj(), name: 'only changed space'),
          transaction: tx,
        );
      });
      sending = await FramedSyncPeer.open(author);
      boundary = await sending.waitForEvent<OfflineSyncEndOfBatch>();
      await sending.close();
      changes = List.of(sending.outbound);
      receiving = await FramedSyncPeer.open(
        receiver,
        onDiagnostic: (event) {
          if (event['name'] == 'merge.phase' &&
              (event['data'] as Map?)?['phase'] == 'prepareSpaceAndClock') {
            merges++;
          }
        },
      );
    });

    group('when the captured wire batch reaches the receiving session,', () {
      late List<String> names;
      late List<OfflineSyncPeerCheckpoint> receipts;

      setUpAll(() async {
        receiving.inbound.add(OfflineSyncMergeChunk(batchId: 1, changes: changes));
        await receiving.endBatch(checkpoints: boundary.checkpoints);
        await receiving.close();
        names = (await Person.db.find(receiver.raw)).map((row) => row.name).toList();
        receipts = await OfflineSyncPeerCheckpoint.db.find(receiver.raw);
      });

      test(
        'then one space receipt and one merge transaction cover the exact changed data.',
        () {
          expect(names, ['only changed space']);
          expect(boundary.checkpoints.map((entry) => entry.uuidSpaceId), [
            testCrdtUserId,
          ]);
          expect(receipts, hasLength(1));
          expect(merges, 1);
        },
      );
    });
  });

  group('Given a receiver with a receipt for a previous sender database epoch,', () {
    late SyncNode replacement;
    late SyncNode receiver;
    late UuidValue previousEpoch;

    setUpAll(() async {
      final original = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await original.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          original.offlineSync,
          Person(name: 'old epoch'),
          transaction: tx,
        );
      });
      await pushChanges(original, receiver);
      previousEpoch = await original.offlineSync.db.currentNodeId(
        userId: testCrdtUserId,
      );
      replacement = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await replacement.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          replacement.offlineSync,
          Person(name: 'new epoch'),
          transaction: tx,
        );
      });
    });

    group('when the recreated sender captures against the receiver receipt,', () {
      late int cursor;
      late UuidValue epoch;
      late List<String> names;

      setUpAll(() async {
        epoch = await replacement.offlineSync.db.currentNodeId(userId: testCrdtUserId);
        cursor = await peerCheckpoint(replacement, receiver);
        final capture = await replacement.sync.captureChanges(
          replacement.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: cursor},
        );
        await deliverCapture(replacement, receiver, capture);
        names = (await Person.db.find(receiver.raw)).map((row) => row.name).toList();
      });

      test('then the new epoch starts at zero and its new fact is delivered.', () {
        expect(epoch, isNot(previousEpoch));
        expect(cursor, 0);
        expect(names, unorderedEquals(['old epoch', 'new epoch']));
      });
    });
  });

  group('Given one replica epoch used by two authenticated users,', () {
    late SyncNode receiver;
    late UuidValue epoch;
    late OfflineSyncPeer firstPeer;
    late UuidValue otherUser;

    setUpAll(() async {
      final author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      receiver = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          author.offlineSync,
          Person(name: 'scoped fact'),
          transaction: tx,
        );
      });
      await pushChanges(author, receiver);
      epoch = await author.offlineSync.db.currentNodeId(userId: testCrdtUserId);
      firstPeer = await receiver.sync.resolvePeer(receiver.raw, testCrdtUserId, epoch);
      otherUser = const Uuid().v7obj();
    });

    group('when the other user connects with the same epoch,', () {
      late OfflineSyncPeer otherPeer;
      late OfflineSyncSinceRevision receipt;
      late OfflineSyncCapture capture;

      setUpAll(() async {
        otherPeer = await receiver.sync.resolvePeer(receiver.raw, otherUser, epoch);
        receipt = await receiver.sync.createSyncSinceRevision(
          receiver.raw,
          userId: otherUser,
          spaceId: testCrdtUserId,
        );
        capture = await receiver.sync.captureChanges(
          receiver.raw,
          checkpointsBySpaceUuid: {testCrdtUserId: 0},
          peerId: otherPeer.id,
        );
      });

      test(
        'then neither receipts nor immediate-source knowledge cross the user boundary.',
        () {
          expect(otherPeer.id, isNot(firstPeer.id));
          expect(receipt.nodeCheckpoints, isEmpty);
          expect(capture.changes, hasLength(1));
          expect(
            (capture.changes.single as CrdtMergeInsert).data,
            isA<Person>().having((row) => row.name, 'name', 'scoped fact'),
          );
        },
      );
    });
  });
}
