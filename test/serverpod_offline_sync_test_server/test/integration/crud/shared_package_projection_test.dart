import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  group('Given a shared child row and a parent ID that does not exist,', () {
    late SharedChild child;
    late UuidValue missingParentId;

    setUp(() async {
      missingParentId = const Uuid().v7obj();

      child = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => SharedChild.db.insertRow(
          session,
          SharedChild(name: 'child'),
          transaction: tx,
        ),
      );
    });

    group('when updating the child to reference that parent ID,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => SharedChild.db.updateRow(
            session,
            child.copyWith(parentId: missingParentId),
            transaction: tx,
          ),
        );
      });

      test('then the dangling reference is projected away.', () async {
        final stored = await SharedChild.db.findById(testSession, child.id!);

        expect(stored, isNotNull);
        expect(stored!.parentId, isNull);
      });
    });
  });

  group('Given a shared child row referencing an existing shared parent,', () {
    late SharedParent parent;
    late SharedChild child;

    setUp(() async {
      await session.db.transactionForUser(testCrdtUserId, (tx) async {
        parent = await SharedParent.db.insertRow(
          session,
          SharedParent(id: const Uuid().v7obj(), name: 'parent'),
          transaction: tx,
        );

        child = await SharedChild.db.insertRow(
          session,
          SharedChild(
            id: const Uuid().v7obj(),
            name: 'child',
            parentId: parent.id,
          ),
          transaction: tx,
        );
      });
    });

    group('when merging a delete of the parent,', () {
      setUp(() async {
        final parentHlc = await rowHlc(parent.id!);

        await session.db.mergeChanges([
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: SharedParent.t.tableName,
            uuidRowId: parent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: parentHlc.datetime.add(const Duration(milliseconds: 1)),
            hlcCounter: 0,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ], spaceId: testCrdtUserId);
      });

      test('then the reference is projected away.', () async {
        final stored = await SharedChild.db.findById(testSession, child.id!);

        expect(stored, isNotNull);
        expect(stored!.name, 'child');
        expect(stored.parentId, isNull);
      });
    });
  });

  group('Given a shared parent and its child pending synchronization,', () {
    late SharedParent parent;
    late SharedChild child;
    late SyncNode author;
    late SyncNode receiver;

    setUp(() async {
      final syncTables = [SharedChild.t, SharedParent.t];
      author = await syncNode(testSession, syncTables);
      receiver = await syncNode(
        await createAdditionalTestSession(),
        syncTables,
      );

      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        parent = await SharedParent.db.insertRow(
          author.offlineSync,
          SharedParent(id: const Uuid().v7obj(), name: 'parent'),
          transaction: tx,
        );

        child = await SharedChild.db.insertRow(
          author.offlineSync,
          SharedChild(
            id: const Uuid().v7obj(),
            name: 'child',
            parentId: parent.id,
          ),
          transaction: tx,
        );
      });
    });

    group('when their pending changes are collected and merged into another node,', () {
      setUp(() async {
        await pushChanges(author, receiver);
      });

      test('then the receiver holds both rows with their values.', () async {
        final storedParent = await SharedParent.db.findById(
          receiver.offlineSync,
          parent.id!,
        );
        final storedChild = await SharedChild.db.findById(
          receiver.offlineSync,
          child.id!,
        );

        expect(storedParent, isNotNull);
        expect(storedParent!.name, 'parent');
        expect(storedChild, isNotNull);
        expect(storedChild!.name, 'child');
        expect(storedChild.parentId, parent.id);
      });
    });
  });

  group('Given a shared parent and its child synchronized to another node,', () {
    late SharedChild child;
    late SyncNode author;
    late SyncNode receiver;

    setUp(() async {
      final syncTables = [SharedChild.t, SharedParent.t];
      author = await syncNode(testSession, syncTables);
      receiver = await syncNode(
        await createAdditionalTestSession(),
        syncTables,
      );

      await author.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        final parent = await SharedParent.db.insertRow(
          author.offlineSync,
          SharedParent(id: const Uuid().v7obj(), name: 'parent'),
          transaction: tx,
        );

        child = await SharedChild.db.insertRow(
          author.offlineSync,
          SharedChild(
            id: const Uuid().v7obj(),
            name: 'child',
            parentId: parent.id,
          ),
          transaction: tx,
        );
      });

      await pushChanges(author, receiver);
    });

    group('when the child flavor is updated and synchronized,', () {
      setUp(() async {
        await author.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => SharedChild.db.updateRow(
            author.offlineSync,
            child.copyWith(flavor: SharedFlavor.salted),
            columns: (t) => [t.flavor],
            transaction: tx,
          ),
        );

        await pushChanges(author, receiver);
      });

      test('then the receiver holds the updated flavor.', () async {
        final stored = await SharedChild.db.findById(receiver.offlineSync, child.id!);

        expect(stored, isNotNull);
        expect(stored!.flavor, SharedFlavor.salted);
      });
    });
  });
}
