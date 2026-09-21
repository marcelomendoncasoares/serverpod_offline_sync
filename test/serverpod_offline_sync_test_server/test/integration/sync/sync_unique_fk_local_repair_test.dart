import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a parent deletion blocked by a restrict child and a unique SET NULL child,',
    () {
      late SyncNode node;
      late Person parent;
      late RestrictChild blocker;
      late UniqueSetNullChild child;
      late Hlc childHlc;

      setUpAll(() async {
        node = await syncNode(await createAdditionalTestSession(), testSyncTables);
        parent = Person(id: const Uuid().v7obj(), name: 'parent');
        blocker = RestrictChild(
          id: const Uuid().v7obj(),
          name: 'blocker',
          parentId: parent.id,
        );
        child = UniqueSetNullChild(
          id: const Uuid().v7obj(),
          name: 'child',
          parentId: parent.id,
        );
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(node.offlineSync, parent, transaction: tx);
          await RestrictChild.db.insertRow(node.offlineSync, blocker, transaction: tx);
          await UniqueSetNullChild.db.insertRow(
            node.offlineSync,
            child,
            transaction: tx,
          );
        });
        childHlc = await rowHlc(child.id!, databaseSession: node.offlineSync);
        await node.offlineSync.db.mergeChanges([
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: Person.t.tableName,
            uuidRowId: parent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: childHlc.datetime.add(const Duration(milliseconds: 1)),
            hlcCounter: 0,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ], spaceId: testCrdtUserId);
      });

      group('when the restrict child is detached locally,', () {
        late Person? visibleParent;
        late UniqueSetNullChild? visibleChild;
        late CrdtDataAttemptedValue? attempt;
        late CrdtMergeSet changes;

        setUpAll(() async {
          await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await RestrictChild.db.updateRow(
              node.offlineSync,
              blocker.copyWith(parentId: null),
              columns: (t) => [t.parentId],
              transaction: tx,
            );
          });
          visibleParent = await Person.db.findById(node.offlineSync, parent.id!);
          visibleChild = await UniqueSetNullChild.db.findById(
            node.offlineSync,
            child.id!,
          );
          attempt = await attemptedValue(
            rowId: child.id!,
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

        test(
          'then the visible child is repaired to null while its parent is hidden.',
          () {
            expect(visibleParent, isNull);
            expect(visibleChild, isNotNull);
            expect(visibleChild!.parentId, isNull);
            expect(attempt?.projectionReason, CrdtProjectionReason.foreignKeySetNull);
          },
        );

        test(
          'then the original reference survives without an authored repair clock.',
          () {
            expect(attempt?.value.toString(), parent.id.toString());
            final insert = changes.inserts.singleWhere(
              (change) => change.uuidRowId == child.id,
            );
            expect((insert.data as UniqueSetNullChild).parentId, parent.id);
            expect(insert.hlc, childHlc);
            expect(
              changes.updates.where((change) => change.uuidRowId == child.id),
              isEmpty,
            );
          },
        );
      });
    },
  );
}
