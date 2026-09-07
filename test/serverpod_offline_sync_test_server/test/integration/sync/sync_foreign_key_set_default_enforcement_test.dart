import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  test(
    'Given a visible child with a nullable set-default FK and a null default, '
    'when its parent is deleted locally and synchronized, '
    'then the child remains visible with an authored null reference on both nodes.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final parent = Person(id: const Uuid().v7obj(), name: 'parent');
      final child = NullableSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'child',
        parentId: parent.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(client.crdt, parent, transaction: tx);
        await NullableSetDefaultChild.db.insertRow(client.crdt, child, transaction: tx);
      });
      await syncWithServer(client, server);

      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.deleteRow(client.crdt, parent, transaction: tx);
      });
      await syncWithServer(client, server);

      for (final node in [client, server]) {
        expect(await Person.db.findById(node.crdt, parent.id!), isNull);
        final actual = await NullableSetDefaultChild.db.findById(node.crdt, child.id!);
        expect(actual, isNotNull);
        expect(actual!.parentId, isNull);
      }
      final changes = await client.sync
          .collectPendingChanges(
            client.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      final insert = changes.whereType<CrdtMergeInsert>().singleWhere(
        (change) => change.uuidRowId == child.id,
      );
      expect((insert.data as NullableSetDefaultChild).parentId, isNull);
    },
  );

  test(
    'Given a company referencing another town and a visible default town in its scope, '
    'when the referenced town is deleted locally and synchronized, '
    'then the company references the visible default on both nodes.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final defaultTown = Town(id: _defaultTownId, name: 'default');
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insert(client.crdt, [defaultTown, town], transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);

      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.deleteRow(client.crdt, town, transaction: tx);
      });
      await syncWithServer(client, server);

      for (final node in [client, server]) {
        expect(await Town.db.findById(node.crdt, town.id!), isNull);
        expect(await Town.db.findById(node.crdt, defaultTown.id!), isNotNull);
        expect(
          (await Company.db.findById(node.crdt, company.id!))!.townId,
          defaultTown.id,
        );
      }
    },
  );

  test(
    'Given a visible company whose default town is missing, '
    'when the referenced town is deleted locally, '
    'then the delete is rejected without changing the company or exporting a town tombstone.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(client.crdt, town, transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);

      final deletion = client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
      );

      await expectLater(deletion, throwsA(isA<Exception>()));
      await syncWithServer(client, server);
      for (final node in [client, server]) {
        expect(await Town.db.findById(node.crdt, town.id!), isNotNull);
        expect((await Company.db.findById(node.crdt, company.id!))!.townId, town.id);
      }
      final changes = await client.sync
          .collectPendingChanges(
            client.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      expect(
        changes.whereType<CrdtMergeDelete>().where(
          (change) => change.uuidRowId == town.id,
        ),
        isEmpty,
      );
    },
  );

  test(
    'Given a visible company whose default town is hidden, '
    'when the referenced town is deleted locally, '
    'then the delete is rejected without changing the company or exporting a town tombstone.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(
          client.crdt,
          Town(id: _defaultTownId, name: 'default'),
          transaction: tx,
        );
        await Town.db.deleteRow(
          client.crdt,
          Town(id: _defaultTownId, name: 'default'),
          transaction: tx,
        );
        await Town.db.insertRow(client.crdt, town, transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);

      final deletion = client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
      );

      await expectLater(deletion, throwsA(isA<Exception>()));
      await syncWithServer(client, server);
      for (final node in [client, server]) {
        expect(await Town.db.findById(node.crdt, town.id!), isNotNull);
        expect((await Company.db.findById(node.crdt, company.id!))!.townId, town.id);
      }
      final changes = await client.sync
          .collectPendingChanges(
            client.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      expect(
        changes.whereType<CrdtMergeDelete>().where(
          (change) => change.uuidRowId == town.id,
        ),
        isEmpty,
      );
    },
  );

  test(
    'Given a visible company and its referenced and default towns, '
    'when both towns are deleted in one local batch, '
    'then the entire deletion is rejected and no repair or tombstone survives.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final defaultTown = Town(id: _defaultTownId, name: 'default');
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insert(client.crdt, [town, defaultTown], transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);

      final deletion = client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.delete(client.crdt, [town, defaultTown], transaction: tx),
      );

      await expectLater(deletion, throwsA(isA<Exception>()));
      await syncWithServer(client, server);
      for (final node in [client, server]) {
        expect((await Town.db.find(node.crdt)).map((row) => row.id).toSet(), {
          town.id,
          defaultTown.id,
        });
        expect((await Company.db.findById(node.crdt, company.id!))!.townId, town.id);
      }
      final changes = await client.sync
          .collectPendingChanges(
            client.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      expect(changes.whereType<CrdtMergeDelete>(), isEmpty);
      expect(
        changes.whereType<CrdtMergeUpdate>().where(
          (change) => change.uuidRowId == company.id && change.columnName == 'townId',
        ),
        isEmpty,
      );
    },
  );

  test(
    'Given a deleted company and its deleted town without a default town, '
    'when the company is restored and synchronized, '
    'then both the company and its required town become visible on every node.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(client.crdt, town, transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Company.db.deleteRow(client.crdt, company, transaction: tx);
        await Town.db.deleteRow(client.crdt, town, transaction: tx);
      });
      await syncWithServer(client, server);
      final hidden = (await Company.db.findFirstRow(
        client.crdt,
        where: (t) => t.id.equals(company.id) & t.includeHiddenRows,
      ))!;

      await client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Company.db.insertRow(client.crdt, hidden, transaction: tx),
      );
      await syncWithServer(client, server);

      for (final node in [client, server]) {
        final actual = await Company.db.findById(node.crdt, company.id!);
        expect(actual, isNotNull);
        expect(actual!.townId, town.id);
        expect(await Town.db.findById(node.crdt, town.id!), isNotNull);
      }
    },
  );

  test(
    'Given a deleted company and its deleted town with a visible default town, '
    'when the company is restored and synchronized, '
    'then the company becomes visible on the default while its former town stays hidden.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final town = Town(id: const Uuid().v7obj(), name: 'original');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(
          client.crdt,
          Town(id: _defaultTownId, name: 'default'),
          transaction: tx,
        );
        await Town.db.insertRow(client.crdt, town, transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Company.db.deleteRow(client.crdt, company, transaction: tx);
        await Town.db.deleteRow(client.crdt, town, transaction: tx);
      });
      await syncWithServer(client, server);
      final hidden = (await Company.db.findFirstRow(
        client.crdt,
        where: (t) => t.id.equals(company.id) & t.includeHiddenRows,
      ))!;

      await client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Company.db.insertRow(client.crdt, hidden, transaction: tx),
      );
      await syncWithServer(client, server);

      for (final node in [client, server]) {
        final actual = await Company.db.findById(node.crdt, company.id!);
        expect(actual, isNotNull);
        expect(actual!.townId, _defaultTownId);
        expect(await Town.db.findById(node.crdt, town.id!), isNull);
        expect(await Town.db.findById(node.crdt, _defaultTownId), isNotNull);
      }
    },
  );

  test(
    'Given a company authored offline while the server deletes its town and no default exists, '
    'when the client and server synchronize, '
    'then the town deletion loses and the company references a visible town on both nodes.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final town = Town(id: const Uuid().v7obj(), name: 'town');
      final company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await server.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(server.crdt, town, transaction: tx),
      );
      await syncWithServer(client, server);
      await server.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.deleteRow(server.crdt, town, transaction: tx),
      );
      await client.crdt.db.transactionForUser(
        testCrdtUserId,
        (tx) => Company.db.insertRow(client.crdt, company, transaction: tx),
      );

      await syncWithServer(client, server);

      for (final node in [client, server]) {
        expect(await Town.db.findById(node.crdt, town.id!), isNotNull);
        expect((await Company.db.findById(node.crdt, company.id!))!.townId, town.id);
      }
    },
  );
}

const _defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
