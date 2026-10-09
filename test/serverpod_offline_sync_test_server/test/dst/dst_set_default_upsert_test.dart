import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import '../integration/test_tools/crdt_probes.dart';
import '../integration/test_tools/sync_topology.dart';

/// Serverpod reads a null insert value as a request for the column default, so
/// an upsert supplying null for `unique_set_default_child.parentId` writes
/// `550e8400-…`. That is an authored write of the default, not the full-row
/// passthrough of `docs/projection-model.md`, which only translates back a
/// projected value the caller echoed unchanged.
///
/// The two coincide exactly when a set-default repair is already displaying the
/// default over a hidden parent, which is the state the convergence simulation
/// reached at seed 1791399000: `unique_set_default_child.upsert … accepted
/// "550e8400-…" but retained "00000000-000b-…"`.
void main() {
  initTestClientSession(createSessionPerTest: false);

  const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

  group(
    'Given a set-default child displaying the column default for a hidden parent,',
    () {
      late SyncNode node;
      late Town parent;
      late UniqueSetDefaultChild child;

      /// The clock the column authored its value at, which is the row's
      /// insertion clock while no field record exists.
      Future<Hlc> parentIdHlc() async {
        final field = await CrdtDataField.db.findFirstRow(
          node.offlineSync,
          where: (t) =>
              t.row.uuidRowId.equals(child.id) & t.column.name.equals('parentId'),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );
        return field?.hlc ?? await rowHlc(child.id!, databaseSession: node.offlineSync);
      }

      setUpAll(() async {
        node = await syncNode(await createAdditionalTestSession(), testSyncTables);
        parent = Town(id: const Uuid().v7obj(), name: 'parent');
        child = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'child',
          parentId: parent.id,
        );

        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insert(node.offlineSync, [
            parent,
            Town(id: defaultTownId, name: 'default'),
          ], transaction: tx);
          await UniqueSetDefaultChild.db.insertRow(
            node.offlineSync,
            child,
            transaction: tx,
          );
        });

        // A peer deleted the parent after this replica authored the reference,
        // so the repair is projected rather than authored locally.
        final childHlc = await rowHlc(child.id!, databaseSession: node.offlineSync);
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

      test(
        'when reading the repaired child, '
        'then the repair displays the default over the authored parent.',
        () async {
          final repaired = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            child.id!,
          );
          final attempt = await attemptedValue(
            rowId: child.id!,
            columnName: 'parentId',
            databaseSession: node.offlineSync,
          );

          expect(repaired!.parentId, defaultTownId);
          expect(attempt?.value.toString(), parent.id.toString());
          expect(attempt?.projectionReason, CrdtProjectionReason.foreignKeySetDefault);
        },
      );

      group('when a full-row upsert supplies null for the parent,', () {
        late Hlc before;
        late Hlc after;
        late CrdtDataAttemptedValue? attempt;
        late UniqueSetDefaultChild? stored;
        late UniqueSetDefaultChild? restored;
        late CrdtMergeSet changes;

        setUpAll(() async {
          before = await parentIdHlc();
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => UniqueSetDefaultChild.db.upsertRow(
              node.offlineSync,
              UniqueSetDefaultChild(id: child.id, name: 'edited'),
              conflictColumns: (t) => [t.id],
              transaction: tx,
            ),
          );

          stored = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            child.id!,
          );

          attempt = await attemptedValue(
            rowId: child.id!,
            columnName: 'parentId',
            databaseSession: node.offlineSync,
          );

          after = await parentIdHlc();
          changes = await node.sync
              .collectPendingChanges(
                node.raw,
                checkpointsBySpaceUuid: {testCrdtUserId: const []},
              )
              .toList();

          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.insertRow(node.offlineSync, parent, transaction: tx),
          );

          restored = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            child.id!,
          );
        });

        test('then the default it wrote becomes the authored value.', () {
          expect(stored!.name, 'edited');
          expect(stored!.parentId, defaultTownId);
          expect(attempt, isNull);
        });

        test('then the write advances the authored clock of the column.', () {
          expect(after, greaterThan(before));
        });

        test('then outbound sync exports the default, not the replaced parent.', () {
          final insert = changes.inserts.singleWhere(
            (change) => change.uuidRowId == child.id,
          );
          expect((insert.data as UniqueSetDefaultChild).parentId, defaultTownId);
          expect(
            changes.updates
                .where(
                  (change) =>
                      change.uuidRowId == child.id && change.columnName == 'parentId',
                )
                .map((change) => change.value.toString()),
            everyElement(defaultTownId.toString()),
          );
        });

        test('then restoring the old parent leaves the written default.', () {
          expect(restored!.parentId, defaultTownId);
        });
      });
    },
  );
}
