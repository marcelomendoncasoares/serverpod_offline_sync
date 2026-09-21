import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a unique SET DEFAULT loser displaying null for its authored parent,', () {
    late SyncNode node;
    late Town parent;
    late UniqueSetDefaultChild winner;
    late UniqueSetDefaultChild loser;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      parent = Town(id: const Uuid().v7obj(), name: 'parent');
      winner = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'winner',
        parentId: parent.id,
      );
      loser = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'loser',
        parentId: parent.id,
      );
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insert(node.offlineSync, [
          parent,
          Town(
            id: const UuidValue.raw('550e8400-e29b-41d4-a716-446655440000'),
            name: 'default',
          ),
        ], transaction: tx);
        await UniqueSetDefaultChild.db.insertRow(
          node.offlineSync,
          winner,
          transaction: tx,
        );
      });
      final winnerHlc = await rowHlc(winner.id!, databaseSession: node.offlineSync);
      await node.offlineSync.db.mergeChanges([
        CrdtMergeInsert(
          uuidSpaceId: testCrdtUserId,
          tableName: UniqueSetDefaultChild.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: winnerHlc.datetime.add(const Duration(milliseconds: 1)),
          hlcCounter: 0,
          data: loser,
        ),
      ], spaceId: testCrdtUserId);
      loser = (await UniqueSetDefaultChild.db.findById(node.offlineSync, loser.id!))!;
    });

    group(
      'when a full-row upsert echoes the released null and the winner is later deleted,',
      () {
        late UniqueSetDefaultChild? stored;
        late CrdtDataAttemptedValue? attempt;
        late CrdtMergeSet changes;
        late UniqueSetDefaultChild? restored;

        setUpAll(() async {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueSetDefaultChild.db.upsertRow(
              node.offlineSync,
              loser.copyWith(name: 'edited'),
              conflictColumns: (t) => [t.id],
              transaction: tx,
            );
          });
          stored = await UniqueSetDefaultChild.db.findById(node.offlineSync, loser.id!);
          attempt = await attemptedValue(
            rowId: loser.id!,
            columnName: 'parentId',
            databaseSession: node.offlineSync,
          );
          changes = await node.sync
              .collectPendingChanges(
                node.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueSetDefaultChild.db.deleteRow(
              node.offlineSync,
              winner,
              transaction: tx,
            );
          });
          restored = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            loser.id!,
          );
        });

        test('then the authored parent survives behind the unique release.', () {
          expect(loser.parentId, isNull);
          expect(stored!.name, 'edited');
          expect(stored!.parentId, isNull);
          expect(attempt?.value.toString(), parent.id.toString());
          expect(attempt?.projectionReason, CrdtProjectionReason.uniqueConflict);
        });

        test('then outbound sync never authors the column default.', () {
          final insert = changes.inserts.singleWhere(
            (change) => change.uuidRowId == loser.id,
          );
          expect((insert.data as UniqueSetDefaultChild).parentId, parent.id);
          expect(
            changes.updates
                .where(
                  (change) =>
                      change.uuidRowId == loser.id && change.columnName == 'parentId',
                )
                .every((change) => change.value.toString() == parent.id.toString()),
            isTrue,
          );
        });

        test('then the original authored parent is reclaimed.', () {
          expect(restored!.parentId, parent.id);
        });
      },
    );
  });
}
