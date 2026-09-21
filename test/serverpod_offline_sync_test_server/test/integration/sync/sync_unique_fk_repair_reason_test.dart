import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a SET DEFAULT repair released to null because another child owns the default,',
    () {
      late SyncNode node;
      late Town parent;
      late Town defaultTown;
      late Address address;
      late UniqueSetDefaultChild loser;
      late UniqueSetDefaultChild winner;
      late Hlc childHlc;

      setUpAll(() async {
        node = await syncNode(await createAdditionalTestSession(), testSyncTables);
        final mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
        parent = Town(id: const Uuid().v7obj(), name: 'parent', mayorId: mayor.id);
        defaultTown = Town(
          id: const UuidValue.raw('550e8400-e29b-41d4-a716-446655440000'),
          name: 'default',
        );
        address = Address(
          id: const Uuid().v7obj(),
          street: 'street',
          inhabitantId: mayor.id,
        );
        winner = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'winner',
          parentId: defaultTown.id,
        );
        loser = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'loser',
          parentId: parent.id,
        );
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(node.offlineSync, mayor, transaction: tx);
          await Town.db.insert(node.offlineSync, [
            parent,
            defaultTown,
          ], transaction: tx);
          await Address.db.insertRow(node.offlineSync, address, transaction: tx);
          await UniqueSetDefaultChild.db.insertRow(
            node.offlineSync,
            winner,
            transaction: tx,
          );
          await UniqueSetDefaultChild.db.insertRow(
            node.offlineSync,
            loser,
            transaction: tx,
          );
        });
        childHlc = await rowHlc(loser.id!, databaseSession: node.offlineSync);
        await node.offlineSync.db.mergeChanges([
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: Town.t.tableName,
            uuidRowId: parent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: childHlc.datetime.add(const Duration(milliseconds: 1)),
            hlcCounter: 0,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ], spaceId: testCrdtUserId);
      });

      group('when an address is detached from the deleted town mayor locally,', () {
        late UniqueSetDefaultChild? stored;
        late UniqueSetDefaultChild? owner;
        late Town? visibleParent;
        late Town? visibleDefault;
        late CrdtDataAttemptedValue? attempt;
        late CrdtMergeSet changes;

        setUpAll(() async {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Address.db.updateRow(
              node.offlineSync,
              address.copyWith(inhabitantId: null),
              columns: (t) => [t.inhabitantId],
              transaction: tx,
            );
          });
          stored = await UniqueSetDefaultChild.db.findById(node.offlineSync, loser.id!);
          owner = await UniqueSetDefaultChild.db.findById(node.offlineSync, winner.id!);
          visibleParent = await Town.db.findById(node.offlineSync, parent.id!);
          visibleDefault = await Town.db.findById(node.offlineSync, defaultTown.id!);
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
        });

        test('then the null release retains its terminal unique-conflict reason.', () {
          expect(visibleParent, isNull);
          expect(visibleDefault, isNotNull);
          expect(owner!.parentId, defaultTown.id);
          expect(stored, isNotNull);
          expect(stored!.parentId, isNull);
          expect(attempt?.projectionReason, CrdtProjectionReason.uniqueConflict);

          expect(attempt?.value.toString(), parent.id.toString());
          final insert = changes.inserts.singleWhere(
            (change) => change.uuidRowId == loser.id,
          );
          expect((insert.data as UniqueSetDefaultChild).parentId, parent.id);
          expect(insert.hlc, childHlc);
          expect(
            changes.updates.where((change) => change.uuidRowId == loser.id),
            isEmpty,
          );
        });
      });
    },
  );
}
