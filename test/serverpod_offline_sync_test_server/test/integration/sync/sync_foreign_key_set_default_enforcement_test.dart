import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  test(
    'Given a child holding the unique default-town reference, '
    'when another child claims it in a local insert, '
    'then both rows survive and the released claim remains authored in the export.',
    () async {
      final node = await syncNode(testSession, testSyncTables);
      final parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      final first = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'first',
        parentId: parent.id,
      );
      final second = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'second',
        parentId: parent.id,
      );
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(node.crdt, parent, transaction: tx);
        await UniqueSetDefaultChild.db.insertRow(node.crdt, first, transaction: tx);
      });

      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueSetDefaultChild.db.insertRow(node.crdt, second, transaction: tx);
      });

      final rows = await UniqueSetDefaultChild.db.find(node.crdt);
      expect(rows.map((row) => row.id).toSet(), {first.id, second.id});
      expect(rows.where((row) => row.parentId == parent.id), hasLength(1));
      expect(rows.where((row) => row.parentId == null), hasLength(1));
      final changes = await node.sync
          .collectPendingChanges(
            node.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      final claims = changes.whereType<CrdtMergeInsert>().where(
        (change) => change.tableName == 'unique_set_default_child',
      );
      expect(claims, hasLength(2));
      expect(
        claims.map((change) => (change.data as UniqueSetDefaultChild).parentId),
        everyElement(parent.id),
      );
    },
  );

  test(
    'Given a visible default town and two new children claiming its unique reference, '
    'when both children are inserted in one batch, '
    'then both rows survive and the released claim remains authored in the export.',
    () async {
      final node = await syncNode(testSession, testSyncTables);
      final parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      final first = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'first',
        parentId: parent.id,
      );
      final second = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'second',
        parentId: parent.id,
      );
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(node.crdt, parent, transaction: tx);
      });

      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueSetDefaultChild.db.insert(node.crdt, [
          first,
          second,
        ], transaction: tx);
      });

      final rows = await UniqueSetDefaultChild.db.find(node.crdt);
      expect(rows.map((row) => row.id).toSet(), {first.id, second.id});
      expect(rows.where((row) => row.parentId == parent.id), hasLength(1));
      expect(rows.where((row) => row.parentId == null), hasLength(1));
      final changes = await node.sync
          .collectPendingChanges(
            node.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      final claims = changes.whereType<CrdtMergeInsert>().where(
        (change) => change.tableName == 'unique_set_default_child',
      );
      expect(claims, hasLength(2));
      expect(
        claims.map((change) => (change.data as UniqueSetDefaultChild).parentId),
        everyElement(parent.id),
      );
    },
  );

  test(
    'Given two offline children claiming the same unique default-town reference, '
    'when their scopes synchronize, '
    'then both children survive and exactly one retains the reference.',
    () async {
      final server = await syncNode(testSession, testSyncTables);
      final client = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      final first = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'first',
        parentId: parent.id,
      );
      final second = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'second',
        parentId: parent.id,
      );
      await server.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(server.crdt, parent, transaction: tx);
      });
      await syncWithServer(client, server);
      await server.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueSetDefaultChild.db.insertRow(server.crdt, first, transaction: tx);
      });
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueSetDefaultChild.db.insertRow(client.crdt, second, transaction: tx);
      });

      await syncWithServer(client, server);

      final serverRows = await UniqueSetDefaultChild.db.find(server.crdt);
      final clientRows = await UniqueSetDefaultChild.db.find(client.crdt);
      expect(serverRows.map((row) => row.id).toSet(), {first.id, second.id});
      expect(serverRows.where((row) => row.parentId == parent.id), hasLength(1));
      expect(serverRows.where((row) => row.parentId == null), hasLength(1));
      expect(
        {for (final row in clientRows) row.id: row.parentId},
        {for (final row in serverRows) row.id: row.parentId},
      );
    },
  );

  test(
    'Given a visible default town and a new child whose parent is omitted, '
    'when the child is upserted locally, '
    'then its database default is applied and exported as the authored reference.',
    () async {
      final node = await syncNode(testSession, testSyncTables);
      final parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      final child = UniqueSetDefaultChild(id: const Uuid().v7obj(), name: 'child');
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(node.crdt, parent, transaction: tx);
      });

      final inserted = await node.crdt.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return UniqueSetDefaultChild.db.upsertRow(
          node.crdt,
          child,
          conflictColumns: (t) => [t.id],
          transaction: tx,
        );
      });

      expect(inserted!.parentId, parent.id);
      expect(
        (await UniqueSetDefaultChild.db.findById(node.crdt, child.id!))!.parentId,
        parent.id,
      );
      final changes = await node.sync
          .collectPendingChanges(
            node.raw,
            checkpointsByScopeUuid: {testCrdtUserId: const []},
          )
          .toList();
      final exported = changes.whereType<CrdtMergeInsert>().singleWhere(
        (change) => change.uuidRowId == child.id,
      );
      expect((exported.data as UniqueSetDefaultChild).parentId, parent.id);
    },
  );

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
