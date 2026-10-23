import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an idle client stream using the default sync settings,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late Unique row;

    setUpAll(() async {
      node = await _node(persistentUserId: testCrdtUserId);
      peer = await FramedSyncPeer.open(node);
      row = Unique(id: const Uuid().v7obj(), name: 'committed');
    });

    group('when an application transaction commits a local insertion,', () {
      late List<CrdtMergeChange> sent;
      late int recoveryWakeups;

      setUpAll(() async {
        await node.offlineSync.db.transaction((tx) async {
          await Unique.db.insertRow(node.offlineSync, row, transaction: tx);
        });
        await peer.waitForRow(row.id!);
        sent = List.of(peer.outbound);
        recoveryWakeups = peer.recoveryWakeups;
        await peer.close();
      });

      test('then the insertion is sent without waiting for recovery.', () {
        expect(sent.map((c) => c.uuidRowId), [row.id]);
        expect(recoveryWakeups, 0);
      });
    });
  });

  group('Given an idle client stream and a standalone ORM write,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late Unique row;

    setUpAll(() async {
      node = await _node(persistentUserId: testCrdtUserId);
      peer = await FramedSyncPeer.open(node);
      row = Unique(id: const Uuid().v7obj(), name: 'standalone');
    });

    group('when the insertion commits its own transaction,', () {
      late List<CrdtMergeChange> sent;
      late int recoveryWakeups;

      setUpAll(() async {
        await Unique.db.insertRow(node.offlineSync, row);
        await peer.waitForRow(row.id!);
        sent = List.of(peer.outbound);
        recoveryWakeups = peer.recoveryWakeups;
        await peer.close();
      });

      test('then its stream wakes without waiting for recovery.', () {
        expect(sent.map((c) => c.uuidRowId), [row.id]);
        expect(recoveryWakeups, 0);
      });
    });
  });

  group('Given two idle device streams sharing a server context and space,', () {
    late SyncNode node;
    late FramedSyncPeer sender;
    late FramedSyncPeer receiver;
    late FramedSyncPeer unrelated;
    late int unrelatedCycles;
    late CrdtMergeInsert insertion;

    setUpAll(() async {
      node = await _node();
      sender = await FramedSyncPeer.open(node);
      receiver = await FramedSyncPeer.open(node);
      unrelated = await FramedSyncPeer.open(node, userId: const Uuid().v7obj());
      unrelatedCycles = unrelated.stages.where((s) => s == 'outbound.capture').length;
      insertion = _insert('remote');
    });

    group('when the sender merges an insertion,', () {
      late List<CrdtMergeChange> sent;
      late int recoveryWakeups;
      late List<CrdtMergeChange> echoed;
      late int unrelatedCyclesAfter;

      setUpAll(() async {
        echoed = await sender.sendBatch([insertion]);
        await receiver.waitForRow(insertion.uuidRowId);
        sent = List.of(receiver.outbound);
        recoveryWakeups = sender.recoveryWakeups + receiver.recoveryWakeups;
        unrelatedCyclesAfter = unrelated.stages
            .where((s) => s == 'outbound.capture')
            .length;
        await sender.close();
        await receiver.close();
        await unrelated.close();
      });

      test('then the other device receives it without waiting for recovery.', () {
        expect(sent.map((c) => c.uuidRowId), [insertion.uuidRowId]);
        expect(recoveryWakeups, 0);
      });

      test('then the sender receives no echo.', () {
        expect(echoed, isEmpty);
      });

      test('then another user does not start an extra scan.', () {
        expect(unrelatedCyclesAfter, unrelatedCycles);
      });
    });
  });

  group('Given an idle stream and a transaction that rolls back an insertion,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late Unique rejected;
    late Unique committed;

    setUpAll(() async {
      node = await _node(persistentUserId: testCrdtUserId);
      peer = await FramedSyncPeer.open(node);
      rejected = Unique(id: const Uuid().v7obj(), name: 'rolled back');
      committed = Unique(id: const Uuid().v7obj(), name: 'survived');
      try {
        await node.offlineSync.db.transaction<void>((tx) async {
          await Unique.db.insertRow(node.offlineSync, rejected, transaction: tx);
          throw const _Rollback();
        });
      } on _Rollback {
        // The scenario deliberately aborts this transaction.
      }
    });

    group('when another insertion commits and wakes the stream,', () {
      late List<CrdtMergeChange> sent;
      late int recoveryWakeups;
      late Unique? rejectedRow;

      setUpAll(() async {
        await Unique.db.insertRow(node.offlineSync, committed);
        await peer.waitForRow(committed.id!);
        sent = List.of(peer.outbound);
        recoveryWakeups = peer.recoveryWakeups;
        rejectedRow = await Unique.db.findById(node.raw, rejected.id!);
        await peer.close();
      });

      test('then only the committed insertion is published.', () {
        expect(sent.map((c) => c.uuidRowId), [committed.id]);
        expect(recoveryWakeups, 0);
        expect(rejectedRow, isNull);
      });
    });
  });

  group('Given a stream waiting for the rest of an inbound batch,', () {
    late SyncNode node;
    late FramedSyncPeer peer;
    late CrdtMergeInsert remote;
    late Unique local;

    setUpAll(() async {
      node = await _node(persistentUserId: testCrdtUserId);
      peer = await FramedSyncPeer.open(node);
      remote = _insert('partial remote');
      local = Unique(id: const Uuid().v7obj(), name: 'local');
      peer.inbound.add(
        OfflineSyncMergeChunk(batchId: peer.nextBatchId, changes: [remote]),
      );
    });

    group('when a local commit wakes it before the peer terminates the batch,', () {
      late Unique? beforeTerminator;
      late Unique? afterTerminator;
      late List<CrdtMergeChange> sent;
      late int recoveryWakeups;

      setUpAll(() async {
        await Unique.db.insertRow(node.offlineSync, local);
        await peer.waitForRow(local.id!);
        beforeTerminator = await Unique.db.findById(node.raw, remote.uuidRowId);
        await peer.endBatch();
        afterTerminator = await Unique.db.findById(node.raw, remote.uuidRowId);
        sent = List.of(peer.outbound);
        recoveryWakeups = peer.recoveryWakeups;
        await peer.close();
      });

      test('then the partial inbound batch is not applied prematurely.', () {
        expect(beforeTerminator, isNull);
        expect(afterTerminator?.name, 'partial remote');
      });

      test('then the local change is sent before the inbound batch is complete.', () {
        expect(sent.map((c) => c.uuidRowId), [local.id]);
        expect(recoveryWakeups, 0);
      });
    });
  });
}

Future<SyncNode> _node({UuidValue? persistentUserId}) async {
  final raw = await createAdditionalTestSession();
  final context = OfflineSyncDatabaseContext(
    syncTables: testSyncTables,
    serializationManager: raw.db.serializationManager,
  );
  final offlineSync = OfflineSyncDatabaseSession.wraps(
    raw,
    syncTables: testSyncTables,
    context: context,
    persistentUserId: persistentUserId,
  );
  await offlineSync.db.initialize();
  return (
    raw: raw,
    offlineSync: offlineSync,
    sync: OfflineSyncEngine(
      syncTables: testSyncTables,
      serializationManager: raw.db.serializationManager,
      databaseContext: context,
    ),
  );
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

class _Rollback implements Exception {
  const _Rollback();
}
