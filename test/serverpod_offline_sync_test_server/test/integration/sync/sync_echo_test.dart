import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

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
