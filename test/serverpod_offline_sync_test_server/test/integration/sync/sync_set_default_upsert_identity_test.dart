import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a child displaying the column default for its hidden parent,', () {
    late SyncNode node;
    late Town parent;
    late UniqueSetDefaultChild child;
    late Hlc originalClock;
    late UniqueSetDefaultChild? before;
    late CrdtDataAttemptedValue? originalAttempt;

    const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

    setUp(() async {
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
      originalClock = await _parentIdHlc(node, child.id!);
      await node.offlineSync.db.mergeChanges([
        CrdtMergeDelete(
          uuidSpaceId: testCrdtUserId,
          tableName: Town.t.tableName,
          uuidRowId: parent.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: originalClock.datetime.add(const Duration(milliseconds: 1)),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        ),
      ], spaceId: testCrdtUserId);
      before = await UniqueSetDefaultChild.db.findById(node.offlineSync, child.id!);
      originalAttempt = await attemptedValue(
        rowId: child.id!,
        columnName: 'parentId',
        databaseSession: node.offlineSync,
      );
    });

    group(
      'when an upsert supplies null and matches its unique name without an ID,',
      () {
        late UniqueSetDefaultChild? saved;
        late UniqueSetDefaultChild? restored;
        late UniqueSetDefaultChild? peerChild;
        late CrdtDataAttemptedValue? attempt;
        late CrdtDataAttemptedValue? peerAttempt;
        late Hlc updatedClock;

        setUp(() async {
          saved = await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => UniqueSetDefaultChild.db.upsertRow(
              node.offlineSync,
              UniqueSetDefaultChild(name: child.name),
              conflictColumns: (t) => [t.spaceId, t.name],
              transaction: tx,
            ),
          );
          attempt = await attemptedValue(
            rowId: child.id!,
            columnName: 'parentId',
            databaseSession: node.offlineSync,
          );
          updatedClock = await _parentIdHlc(node, child.id!);

          final peer = await syncNode(
            await createAdditionalTestSession(),
            testSyncTables,
          );
          await pushChanges(node, peer);
          peerChild = await UniqueSetDefaultChild.db.findById(
            peer.offlineSync,
            child.id!,
          );
          peerAttempt = await attemptedValue(
            rowId: child.id!,
            columnName: 'parentId',
            databaseSession: peer.offlineSync,
          );

          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.insertRow(node.offlineSync, parent, transaction: tx),
          );
          restored = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            child.id!,
          );
        });

        test(
          'then it replaces the hidden claim on the existing row with the default.',
          () {
            expect(before!.parentId, defaultTownId);
            expect(originalAttempt?.value.toString(), parent.id.toString());
            expect(
              originalAttempt?.projectionReason,
              CrdtProjectionReason.foreignKeySetDefault,
            );
            expect(saved!.id, child.id);
            expect(saved!.parentId, defaultTownId);
            expect(attempt, isNull);
          },
        );

        test('then the authored foreign-key clock advances.', () {
          expect(updatedClock, greaterThan(originalClock));
        });

        test('then an empty peer receives the authored default.', () {
          expect(peerChild!.parentId, defaultTownId);
          expect(peerAttempt, isNull);
        });

        test('then restoring the old parent leaves the authored default.', () {
          expect(restored!.parentId, defaultTownId);
        });
      },
    );

    group('when an upsert matches its name and echoes the displayed default,', () {
      late CrdtDataAttemptedValue? attempt;
      late Hlc updatedClock;
      late UniqueSetDefaultChild? restored;

      setUp(() async {
        await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueSetDefaultChild.db.upsertRow(
            node.offlineSync,
            UniqueSetDefaultChild(name: child.name, parentId: defaultTownId),
            conflictColumns: (t) => [t.spaceId, t.name],
            transaction: tx,
          ),
        );
        attempt = await attemptedValue(
          rowId: child.id!,
          columnName: 'parentId',
          databaseSession: node.offlineSync,
        );
        updatedClock = await _parentIdHlc(node, child.id!);
        await node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(node.offlineSync, parent, transaction: tx),
        );
        restored = await UniqueSetDefaultChild.db.findById(node.offlineSync, child.id!);
      });

      test(
        'then the original authored parent and its clock survive the passthrough.',
        () {
          expect(attempt?.value.toString(), parent.id.toString());
          expect(updatedClock, originalClock);
          expect(restored!.parentId, parent.id);
        },
      );
    });

    group(
      'when an upsert supplies null for the foreign key used only as its conflict key,',
      () {
        late CrdtDataAttemptedValue? attempt;
        late Hlc updatedClock;
        late UniqueSetDefaultChild? restored;

        setUp(() async {
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => UniqueSetDefaultChild.db.upsertRow(
              node.offlineSync,
              UniqueSetDefaultChild(id: child.id, name: 'edited'),
              conflictColumns: (t) => [t.parentId],
              transaction: tx,
            ),
          );
          attempt = await attemptedValue(
            rowId: child.id!,
            columnName: 'parentId',
            databaseSession: node.offlineSync,
          );
          updatedClock = await _parentIdHlc(node, child.id!);
          await node.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.insertRow(node.offlineSync, parent, transaction: tx),
          );
          restored = await UniqueSetDefaultChild.db.findById(
            node.offlineSync,
            child.id!,
          );
        });

        test('then the foreign key is not authored by the name-only update.', () {
          expect(attempt?.value.toString(), parent.id.toString());
          expect(updatedClock, originalClock);
          expect(restored!.name, 'edited');
          expect(restored!.parentId, parent.id);
        });
      },
    );

    group('and another child has an available parent,', () {
      late Town otherParent;
      late Town insertParent;
      late UniqueSetDefaultChild skipped;
      late Hlc skippedClock;
      late UuidValue inputId;

      setUp(() async {
        otherParent = Town(id: const Uuid().v7obj(), name: 'other');
        insertParent = Town(id: const Uuid().v7obj(), name: 'insert parent');
        skipped = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'skipped',
          parentId: otherParent.id,
        );
        inputId = const Uuid().v7obj();
        await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insert(node.offlineSync, [
            otherParent,
            insertParent,
          ], transaction: tx);
          await UniqueSetDefaultChild.db.insertRow(
            node.offlineSync,
            skipped,
            transaction: tx,
          );
        });
        skippedClock = await _parentIdHlc(node, skipped.id!);
      });

      group(
        'when a batch skips one input, updates by name with a different ID, and inserts another,',
        () {
          late List<UniqueSetDefaultChild> saved;
          late CrdtDataAttemptedValue? attempt;
          late UniqueSetDefaultChild? stored;
          late UniqueSetDefaultChild? unchanged;
          late Hlc updatedClock;
          late Hlc unchangedClock;

          setUp(() async {
            saved = await node.offlineSync.db.transactionForUser(
              testCrdtUserId,
              (tx) => UniqueSetDefaultChild.db.upsert(
                node.offlineSync,
                [
                  UniqueSetDefaultChild(name: skipped.name, parentId: otherParent.id),
                  UniqueSetDefaultChild(id: inputId, name: child.name),
                  UniqueSetDefaultChild(name: 'inserted', parentId: insertParent.id),
                ],
                conflictColumns: (t) => [t.spaceId, t.name],
                updateWhere: (t) => t.name.equals(child.name),
                transaction: tx,
              ),
            );
            attempt = await attemptedValue(
              rowId: child.id!,
              columnName: 'parentId',
              databaseSession: node.offlineSync,
            );
            stored = await UniqueSetDefaultChild.db.findById(
              node.offlineSync,
              child.id!,
            );
            unchanged = await UniqueSetDefaultChild.db.findById(
              node.offlineSync,
              skipped.id!,
            );
            updatedClock = await _parentIdHlc(node, child.id!);
            unchangedClock = await _parentIdHlc(node, skipped.id!);
          });

          test(
            'then the accepted existing row authors the default under its stored ID.',
            () {
              expect(
                saved.map((row) => row.name),
                unorderedEquals([child.name, 'inserted']),
              );
              expect(saved.singleWhere((row) => row.name == child.name).id, child.id);
              expect(saved.map((row) => row.id), isNot(contains(inputId)));
              expect(stored!.parentId, defaultTownId);
              expect(attempt, isNull);
              expect(updatedClock, greaterThan(originalClock));
            },
          );

          test(
            'then the rejected input leaves its row and authored clock unchanged.',
            () {
              expect(unchanged!.parentId, otherParent.id);
              expect(unchangedClock, skippedClock);
            },
          );
        },
      );
    });
  });
}

Future<Hlc> _parentIdHlc(SyncNode node, UuidValue childId) async {
  final field = await CrdtDataField.db.findFirstRow(
    node.offlineSync,
    where: (t) => t.row.uuidRowId.equals(childId) & t.column.name.equals('parentId'),
    include: CrdtDataField.include(node: CrdtNode.include()),
  );
  return field?.hlc ?? await rowHlc(childId, databaseSession: node.offlineSync);
}
