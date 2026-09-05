import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  // Projection rebuilds a row from its serialized form, so it has to name the
  // class the way the protocol that will deserialize it does. A model owned by
  // a shared package serializes its own unprefixed name, while the host
  // protocol answers only to the package-prefixed one.
  group('Given a synchronized table owned by a shared package,', () {
    group('when updating a row to name a parent that does not exist,', () {
      late SharedChild child;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          child = await SharedChild.db.insertRow(
            session,
            SharedChild(name: 'child'),
            transaction: tx,
          );
          child = await SharedChild.db.updateRow(
            session,
            child.copyWith(parentId: const Uuid().v7obj()),
            transaction: tx,
          );
        });
      });

      test('then the dangling reference is projected away.', () async {
        final stored = await SharedChild.db.findById(testSession, child.id!);

        expect(stored, isNotNull);
        expect(stored!.parentId, isNull);
      });
    });

    group('when merging a delete of the parent a row still references,', () {
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

        await session.db.mergeChanges([
          CrdtMergeDelete(
            uuidScopeId: testCrdtUserId,
            tableName: SharedParent.t.tableName,
            uuidRowId: parent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: (await rowHlc(
              parent.id!,
            )).datetime.add(const Duration(milliseconds: 1)),
            hlcCounter: 0,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ], scopeId: testCrdtUserId);
      });

      test('then the reference is projected away.', () async {
        final stored = await SharedChild.db.findById(testSession, child.id!);

        expect(stored, isNotNull);
        expect(stored!.name, 'child');
        expect(stored.parentId, isNull);
      });
    });

    // Outbound sync reads the row back through the schema rather than from a
    // typed query, so it names the class from the table definition.
    group('when its rows are collected for another node,', () {
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

        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await SharedParent.db.insertRow(
            author.crdt,
            SharedParent(id: const Uuid().v7obj(), name: 'parent'),
            transaction: tx,
          );
          child = await SharedChild.db.insertRow(
            author.crdt,
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

      test('then a later column update reaches the receiver.', () async {
        await author.crdt.db.transactionForUser(
          testCrdtUserId,
          (tx) => SharedChild.db.updateRow(
            author.crdt,
            child.copyWith(flavor: SharedFlavor.salted),
            columns: (t) => [t.flavor],
            transaction: tx,
          ),
        );
        await pushChanges(author, receiver);

        final stored = await SharedChild.db.findById(receiver.crdt, child.id!);

        expect(stored, isNotNull);
        expect(stored!.flavor, SharedFlavor.salted);
      });

      test('then the receiver holds both rows with their values.', () async {
        final storedParent = await SharedParent.db.findById(
          receiver.crdt,
          parent.id!,
        );
        final storedChild = await SharedChild.db.findById(
          receiver.crdt,
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
}
