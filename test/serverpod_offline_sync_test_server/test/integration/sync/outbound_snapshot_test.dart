import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an author with one pending person insert,', () {
    late SyncNode author;
    late SyncNode peer;
    late Person b;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      peer = await syncNode(await createAdditionalTestSession(), [Person.t]);
      b = Person(id: const Uuid().v7obj(), name: 'B0');
      await author.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(author.offlineSync, b, transaction: tx),
      );
    });

    group(
      'when an insert-update-insert transaction commits after collection first yields and delivery resumes,',
      () {
        late List<String> collectedInserts;
        late List<String> authoredNames;
        late List<String> receivedNames;
        late List<String> recoveredNames;

        setUpAll(() async {
          final firstPass = <CrdtMergeChange>[];
          var committed = false;
          await for (final change in author.sync.collectPendingChanges(
            author.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: const []},
          )) {
            firstPass.add(change);
            if (committed) continue;
            committed = true;

            await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
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
            });
          }

          await peer.sync.mergeInboundBatch(
            peer.raw,
            spaceId: testCrdtUserId,
            mergeSet: firstPass,
          );
          final secondPass = await _deliverPending(author, peer);
          final thirdPass = await _deliverPending(author, peer);
          collectedInserts = [
            for (final change in [...firstPass, ...secondPass, ...thirdPass])
              if (change is CrdtMergeInsert) (change.data as Person).name,
          ];
          authoredNames = await _personNames(author);
          receivedNames = await _personNames(peer);

          await pushChanges(author, peer);
          recoveredNames = await _personNames(peer);
        });

        test('then every committed insert is collected across the passes.', () {
          expect(collectedInserts, unorderedEquals(['B0', 'A', 'C']));
        });

        test('then the peer has every committed person after checkpoint delivery.', () {
          expect(authoredNames, ['A', 'B1', 'C']);
          expect(receivedNames, authoredNames);
        });

        test('then a full-history resend restores all committed people.', () {
          expect(recoveredNames, authoredNames);
        });
      },
    );
  });

  group('Given two synchronized people and one pending name update,', () {
    late SyncNode author;
    late SyncNode peer;
    late Person b;
    late Person deleted;
    late List<Hlc> checkpoints;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      peer = await syncNode(await createAdditionalTestSession(), [Person.t]);
      b = Person(id: const Uuid().v7obj(), name: 'B0');
      deleted = Person(id: const Uuid().v7obj(), name: 'deleted');
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(author.offlineSync, b, transaction: tx);
        await Person.db.insertRow(author.offlineSync, deleted, transaction: tx);
      });
      await pushChanges(author, peer);
      checkpoints = (await peer.sync.createSyncSinceHlc(
        peer.raw,
        spaceId: testCrdtUserId,
      )).nodeCheckpoints;

      await author.offlineSync.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.updateRow(
          author.offlineSync,
          b.copyWith(name: 'B1'),
          columns: (t) => [t.name],
          transaction: tx,
        ),
      );
    });

    group(
      'when an update-delete transaction commits after collection first yields and delivery resumes,',
      () {
        late List<String> authoredNames;
        late List<String> receivedNames;
        late List<String> recoveredNames;

        setUpAll(() async {
          final firstPass = <CrdtMergeChange>[];
          var committed = false;
          await for (final change in author.sync.collectPendingChanges(
            author.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: checkpoints},
          )) {
            firstPass.add(change);
            if (committed) continue;
            committed = true;

            await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await Person.db.updateRow(
                author.offlineSync,
                b.copyWith(name: 'B2'),
                columns: (t) => [t.name],
                transaction: tx,
              );
              await Person.db.deleteRow(author.offlineSync, deleted, transaction: tx);
            });
          }

          await peer.sync.mergeInboundBatch(
            peer.raw,
            spaceId: testCrdtUserId,
            mergeSet: firstPass,
          );
          await _deliverPending(author, peer);
          authoredNames = await _personNames(author);
          receivedNames = await _personNames(peer);

          await pushChanges(author, peer);
          recoveredNames = await _personNames(peer);
        });

        test('then the peer retains the latest committed name.', () {
          expect(authoredNames, ['B2']);
          expect(receivedNames, authoredNames);
        });

        test('then a full-history resend restores the latest committed name.', () {
          expect(recoveredNames, authoredNames);
        });
      },
    );
  });

  group('Given pending people collected through a fresh sync wrapper,', () {
    late SyncNode author;
    late OfflineSyncDatabaseSession collector;

    setUpAll(() async {
      author = await syncNode(await createAdditionalTestSession(), [Person.t]);
      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(
          author.offlineSync,
          Person(id: const Uuid().v7obj(), name: 'A'),
          transaction: tx,
        );
        await Person.db.insertRow(
          author.offlineSync,
          Person(id: const Uuid().v7obj(), name: 'B'),
          transaction: tx,
        );
      });
      collector = OfflineSyncDatabaseSession.wraps(author.raw, syncTables: [Person.t]);
    });

    group('when the consumer cancels after one change and writes another person,', () {
      late List<String> names;

      setUpAll(() async {
        await author.sync
            .collectPendingChanges(
              collector,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .first;
        await author.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            author.offlineSync,
            Person(id: const Uuid().v7obj(), name: 'C'),
            transaction: tx,
          ),
        );
        final changes = await author.sync
            .collectPendingChanges(
              collector,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();
        names =
            changes
                .whereType<CrdtMergeInsert>()
                .map((change) => (change.data as Person).name)
                .toList()
              ..sort();
      });

      test(
        'then the write and next collection complete without a retained transaction.',
        () {
          expect(names, ['A', 'B', 'C']);
        },
      );
    });
  });
}

Future<List<CrdtMergeChange>> _deliverPending(SyncNode author, SyncNode peer) async {
  final since = await peer.sync.createSyncSinceHlc(
    peer.raw,
    spaceId: testCrdtUserId,
  );
  final changes = await author.sync
      .collectPendingChanges(
        author.raw,
        checkpointsBySpaceUuid: {testCrdtUserId: since.nodeCheckpoints},
      )
      .toList();
  await peer.sync.mergeInboundBatch(
    peer.raw,
    spaceId: testCrdtUserId,
    mergeSet: changes,
  );
  return changes;
}

Future<List<String>> _personNames(SyncNode node) async {
  final rows = await Person.db.find(node.offlineSync);
  return rows.map((row) => row.name).toList()..sort();
}
