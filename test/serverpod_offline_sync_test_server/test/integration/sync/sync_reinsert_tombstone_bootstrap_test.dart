import 'package:clock/clock.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  group(
    'Given a newer reinsertion hidden by an older higher-generation deletion,',
    () {
      late SyncNode peer;
      late Unique row;
      late Hlc reinsertHlc;
      late CrdtMergeDelete deletion;

      setUp(() async {
        final author = await syncNode(await createAdditionalTestSession(), [Unique.t]);
        peer = await syncNode(await createAdditionalTestSession(), [Unique.t]);
        row = Unique(id: const Uuid().v7obj(), name: 'original');
        final start = DateTime.now().toUtc();
        await withClock(Clock.fixed(start), () async {
          await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(author.offlineSync, row, transaction: tx);
            await Unique.db.deleteRow(author.offlineSync, row, transaction: tx);
          });
          await pushChanges(author, peer);
        });
        await withClock(Clock.fixed(start.add(const Duration(seconds: 1))), () async {
          await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(author.offlineSync, row, transaction: tx);
            await Unique.db.deleteRow(author.offlineSync, row, transaction: tx);
          });
        });
        await withClock(Clock.fixed(start.add(const Duration(seconds: 2))), () async {
          row = row.copyWith(name: 'peer reinsertion');
          await peer.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insertRow(peer.offlineSync, row, transaction: tx),
          );
          reinsertHlc = await rowHlc(row.id!, databaseSession: peer.offlineSync);
          await pushChanges(author, peer);
        });
        final changes = await peer.sync
            .collectPendingChanges(
              peer.raw,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();
        deletion = changes.deletes.single;
        expect(deletion.clFlag, 4);
        expect(deletion.hlc.compareTo(reinsertHlc), isNegative);
        expect(await Unique.db.findById(peer.offlineSync, row.id!), isNull);
      });

      group('when an empty replica merges its complete export,', () {
        late SyncNode mirror;

        setUp(() async {
          mirror = await syncNode(await createAdditionalTestSession(), [Unique.t]);
          await pushChanges(peer, mirror);
        });

        test('then the higher-generation tombstone and hidden row survive.', () async {
          expect(await Unique.db.findById(mirror.offlineSync, row.id!), isNull);
          final copied = await Unique.db.findById(mirror.raw, row.id!);
          expect(copied!.name, 'peer reinsertion__hidden__${row.id!.uuid}');
          final changes = await mirror.sync
              .collectPendingChanges(
                mirror.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();
          expect(changes.deletes.single.toJson(), deletion.toJson());
        });

        test('then the newer authored name and insertion clock survive.', () async {
          final changes = await mirror.sync
              .collectPendingChanges(
                mirror.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();
          expect((changes.inserts.single.data as Unique).name, 'peer reinsertion');
          expect(changes.inserts.single.hlc, reinsertHlc);
          final attempted = await attemptedValue(
            rowId: row.id!,
            columnName: 'name',
            databaseSession: mirror.offlineSync,
          );
          expect(attempted!.value, 'peer reinsertion');
          expect(attempted.projectionReason, CrdtProjectionReason.hiddenUniqueRelease);
        });
      });
    },
  );
}
