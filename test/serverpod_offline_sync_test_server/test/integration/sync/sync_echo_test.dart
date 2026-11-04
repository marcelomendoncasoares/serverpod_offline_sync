import 'dart:convert';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given 1000 captured Person insertions on an established stream,', () {
    late SyncNode receiver;
    late FramedSyncPeer peer;
    late List<CrdtMergeChange> changes;
    late List<String> expectedRows;

    setUpAll(() async {
      final writer = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      receiver = await syncNode(await createAdditionalTestSession(), testSyncTables);
      peer = await FramedSyncPeer.open(receiver);
      final rows = [
        for (var i = 0; i < 1000; i++)
          Person(
            id: const Uuid().v7obj(),
            name: 'x' * 128,
            surname: 'round:1/row:$i/writer:0',
          ),
      ];
      await writer.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insert(writer.offlineSync, rows, transaction: tx);
      });
      changes = await writer.sync
          .collectPendingChanges(
            writer.raw,
            checkpointsBySpaceUuid: {testCrdtUserId: 0},
          )
          .toList();
      expectedRows = (await Person.db.find(writer.raw)).map(jsonEncode).toList();
    });

    group('when one committed batch arrives in ten transport chunks,', () {
      late List<CrdtMergeChange> outbound;
      late List<String> receivedRows;

      setUpAll(() async {
        for (var start = 0; start < changes.length; start += 100) {
          peer.inbound.add(
            OfflineSyncMergeChunk(
              batchId: peer.nextBatchId,
              changes: changes.sublist(start, start + 100),
            ),
          );
        }
        await peer.endBatch();
        await peer.waitForPass(2);
        await peer.close();
        outbound = List.of(peer.outbound);
        receivedRows = (await Person.db.find(receiver.raw)).map(jsonEncode).toList();
      });

      test('then all rows converge with their exact payloads.', () {
        expect(receivedRows, unorderedEquals(expectedRows));
      });

      test('then no received rows are uploaded back to their sender.', () {
        expect(outbound.length, 0);
      });
    });
  });

  group("Given a stream that acknowledged a relayed author's newer fact,", () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late CrdtMergeInsert older;
    late CrdtMergeInsert newer;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      older = _insert('late older fact');
      newer = _insert('already acknowledged fact').copyWith(
        uuidNodeId: older.uuidNodeId,
        hlcDatetime: older.hlcDatetime.add(const Duration(seconds: 1)),
      );
      await node.offlineSync.db.mergeChanges([newer], userId: testCrdtUserId);
      peer = await FramedSyncPeer.open(node);
      await peer.waitForEvent<OfflineSyncEndOfBatch>();
      peer.outbound.clear();
    });

    group("when that author's older fact arrives through a later relay,", () {
      late Unique? persisted;
      late List<UuidValue> sentRows;

      setUpAll(() async {
        await node.offlineSync.db.mergeChanges([older], userId: testCrdtUserId);
        await peer.waitForPass(2);
        await peer.close();
        persisted = await Unique.db.findById(node.raw, older.uuidRowId);
        sentRows = peer.outbound.map((change) => change.uuidRowId).toList();
      });

      test('then the older fact is committed locally.', () {
        expect(persisted?.name, 'late older fact');
      });

      test(
        'then the peer receives the late fact without replaying the newer fact.',
        () {
          expect(sentRows, [older.uuidRowId]);
        },
      );
    });
  });

  group('Given an established stream and an older fact unknown to its peer,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late CrdtMergeInsert older;
    late CrdtMergeInsert newer;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      peer = await FramedSyncPeer.open(node);
      older = _insert('older');
      newer = _insert('newer').copyWith(
        uuidNodeId: older.uuidNodeId,
        hlcDatetime: older.hlcDatetime.add(const Duration(seconds: 1)),
      );
      await node.offlineSync.db.mergeChanges([older], userId: testCrdtUserId);
    });

    group('when the peer sends the newer fact and then reconnects,', () {
      late List<CrdtMergeChange> outbound;
      late List<CrdtMergeChange> reconnected;

      setUpAll(() async {
        outbound = await peer.sendBatch([newer]);
        await peer.close();
        final next = await FramedSyncPeer.open(node);
        reconnected = List.of(next.outbound);
        await next.close();
      });

      test('then the received fact is not echoed on the original stream.', () {
        expect(outbound.map((c) => c.uuidRowId), isNot(contains(newer.uuidRowId)));
      });

      test('then the older unseen fact is still sent.', () {
        expect(outbound.map((c) => c.uuidRowId), [older.uuidRowId]);
      });

      test('then the reconnect honors its fresh checkpoint.', () {
        expect(
          reconnected.map((c) => c.uuidRowId),
          unorderedEquals([older.uuidRowId, newer.uuidRowId]),
        );
      });
    });
  });

  group('Given an established stream and a locally edited insertion,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late CrdtMergeInsert original;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      peer = await FramedSyncPeer.open(node);
      original = _insert('original');
      await node.offlineSync.db.mergeChanges([original], userId: testCrdtUserId);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Unique.db.updateRow(
          node.offlineSync,
          Unique(id: original.uuidRowId, name: 'locally edited'),
          columns: (t) => [t.name],
          transaction: tx,
        );
      });
    });

    group('when the peer sends the original insertion payload,', () {
      late List<CrdtMergeChange> outbound;

      setUpAll(() async {
        outbound = await peer.sendBatch([original]);
        await peer.close();
      });

      test('then the changed insertion payload is sent back.', () {
        final insertion = outbound.whereType<CrdtMergeInsert>().single;
        expect((insertion.data as Unique).name, 'locally edited');
      });

      test('then the newer field edit is also sent.', () {
        final update = outbound.whereType<CrdtMergeUpdate>().single;
        expect(update.value, 'locally edited');
      });
    });
  });

  group('Given an established stream that receives an incomplete batch,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late CrdtMergeInsert insertion;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      peer = await FramedSyncPeer.open(node);
      insertion = _insert('incomplete');
      peer.inbound.add(
        OfflineSyncMergeChunk(batchId: peer.nextBatchId, changes: [insertion]),
      );
    });

    group('when the stream closes and a new stream sends the complete batch,', () {
      late Unique? afterClose;
      late Unique? afterRetry;
      late List<CrdtMergeChange> outbound;

      setUpAll(() async {
        await peer.close();
        afterClose = await Unique.db.findById(node.raw, insertion.uuidRowId);
        final next = await FramedSyncPeer.open(node);
        outbound = await next.sendBatch([insertion]);
        afterRetry = await Unique.db.findById(node.raw, insertion.uuidRowId);
        await next.close();
      });

      test('then the incomplete batch was not applied.', () {
        expect(afterClose, isNull);
      });

      test('then the complete retry is applied without an echo.', () {
        expect(afterRetry?.name, 'incomplete');
        expect(outbound, isEmpty);
      });
    });
  });
}

CrdtMergeInsert _insert(String name) {
  final id = const Uuid().v7obj();
  return CrdtMergeInsert(
    uuidSpaceId: testCrdtUserId,
    tableName: Unique.t.tableName,
    uuidRowId: id,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: DateTime.utc(2026, 1, 1),
    hlcCounter: 0,
    data: Unique(id: id, name: name),
  );
}
