import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a received insertion with a counter in the current millisecond,', () {
    late SyncNode app;
    late SyncNode peer;
    late DateTime start;
    late Unique row;
    late Hlc insertionClock;

    setUpAll(() async {
      app = await syncNode(await createAdditionalTestSession(), testSyncTables);
      peer = await syncNode(await createAdditionalTestSession(), testSyncTables);

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );

      row = Unique(id: const Uuid().v7obj(), name: 'remote within millisecond');
      final insertion = CrdtMergeInsert(
        uuidSpaceId: testCrdtUserId,
        tableName: Unique.t.tableName,
        uuidRowId: row.id!,
        uuidNodeId: const Uuid().v7obj(),
        hlcDatetime: start,
        hlcCounter: 41,
        data: row,
      );

      await withClock(Clock.fixed(start), () async {
        await app.offlineSync.db.mergeChanges([insertion], spaceId: testCrdtUserId);
        await peer.offlineSync.db.mergeChanges([insertion], spaceId: testCrdtUserId);
      });

      insertionClock = await rowHlc(row.id!, databaseSession: app.offlineSync);
    });

    group('when the same wrapper edits the row half a millisecond later,', () {
      late Hlc authoredClock;
      late Hlc persistedClock;
      late Unique? peerValue;
      late Unique? roundTripped;

      setUpAll(() async {
        await withClock(
          Clock.fixed(start.add(const Duration(microseconds: 500))),
          () async {
            await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await Unique.db.updateRow(
                app.offlineSync,
                row.copyWith(name: 'local within millisecond'),
                columns: (t) => [t.name],
                transaction: tx,
              );
            });

            authoredClock = (await CrdtDataField.db.findFirstRow(
              app.raw,
              where: (t) =>
                  t.row.uuidRowId.equals(row.id) & t.column.name.equals('name'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            ))!.hlc;
            persistedClock = (await OfflineSyncSpace.db.findFirstRow(
              app.raw,
              where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
              include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
            ))!.currentNode!.lastHlc!;

            await pushChanges(app, peer);
            peerValue = await Unique.db.findById(peer.offlineSync, row.id!);

            await pushChanges(peer, app);
            roundTripped = await Unique.db.findById(app.offlineSync, row.id!);
          },
        );
      });

      test('then the counter advances and the edit survives the peer round trip.', () {
        expect(authoredClock.compareTo(insertionClock), greaterThan(0));
        expect(authoredClock.datetime, start);
        expect(authoredClock.counter, 42);
        expect(persistedClock, authoredClock);
        expect(peerValue?.name, 'local within millisecond');
        expect(roundTripped?.name, 'local within millisecond');
      });
    });
  });
}
