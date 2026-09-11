import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a child holding the unique default-town reference,', () {
    late SyncNode node;
    late Town parent;
    late UniqueSetDefaultChild first;
    late UniqueSetDefaultChild second;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      first = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'first',
        parentId: parent.id,
      );
      second = UniqueSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'second',
        parentId: parent.id,
      );
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(node.crdt, parent, transaction: tx);
        await UniqueSetDefaultChild.db.insertRow(node.crdt, first, transaction: tx);
      });
    });

    group('when inserting another child with the same reference locally,', () {
      late List<UniqueSetDefaultChild> nodeRows;
      late CrdtMergeSet changes;

      setUpAll(() async {
        await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueSetDefaultChild.db.insertRow(node.crdt, second, transaction: tx);
        });

        nodeRows = await UniqueSetDefaultChild.db.find(node.crdt);
        changes = await node.sync
            .collectPendingChanges(
              node.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then both child rows remain visible.', () {
        expect(nodeRows.map((row) => row.id).toSet(), {first.id, second.id});
      });

      test('then exactly one child retains the unique default reference.', () {
        expect(nodeRows.where((row) => row.parentId == parent.id), hasLength(1));
        expect(nodeRows.where((row) => row.parentId == null), hasLength(1));
      });

      test('then both exported inserts retain their authored parent.', () {
        final claims = changes.whereType<CrdtMergeInsert>().where(
          (change) => change.tableName == UniqueSetDefaultChild.t.tableName,
        );
        expect(claims, hasLength(2));
        expect(
          claims.map((change) => (change.data as UniqueSetDefaultChild).parentId),
          everyElement(parent.id),
        );
      });
    });
  });

  group(
    'Given a visible default town and two new children claiming its unique reference,',
    () {
      late SyncNode node;
      late Town parent;
      late UniqueSetDefaultChild first;
      late UniqueSetDefaultChild second;

      setUpAll(() async {
        node = await syncNode(await createAdditionalTestSession(), testSyncTables);
        parent = Town(
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
          name: 'default',
        );
        first = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'first',
          parentId: parent.id,
        );
        second = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'second',
          parentId: parent.id,
        );
        await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(node.crdt, parent, transaction: tx);
        });
      });

      group('when inserting both children in one batch,', () {
        late List<UniqueSetDefaultChild> nodeRows;
        late CrdtMergeSet changes;

        setUpAll(() async {
          await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueSetDefaultChild.db.insert(node.crdt, [
              first,
              second,
            ], transaction: tx);
          });

          nodeRows = await UniqueSetDefaultChild.db.find(node.crdt);
          changes = await node.sync
              .collectPendingChanges(
                node.raw,
                checkpointsByScopeUuid: {testCrdtUserId: const []},
              )
              .toList();
        });

        test('then both child rows remain visible.', () {
          expect(nodeRows.map((row) => row.id).toSet(), {first.id, second.id});
        });

        test('then exactly one child retains the unique default reference.', () {
          expect(nodeRows.where((row) => row.parentId == parent.id), hasLength(1));
          expect(nodeRows.where((row) => row.parentId == null), hasLength(1));
        });

        test('then both exported inserts retain their authored parent.', () {
          final claims = changes.whereType<CrdtMergeInsert>().where(
            (change) => change.tableName == UniqueSetDefaultChild.t.tableName,
          );
          expect(claims, hasLength(2));
          expect(
            claims.map((change) => (change.data as UniqueSetDefaultChild).parentId),
            everyElement(parent.id),
          );
        });
      });
    },
  );
  group(
    'Given two offline children claiming the same unique default-town reference,',
    () {
      late SyncNode server;
      late SyncNode client;
      late Town parent;
      late UniqueSetDefaultChild first;
      late UniqueSetDefaultChild second;

      setUpAll(() async {
        server = await syncNode(await createAdditionalTestSession(), testSyncTables);
        client = await syncNode(await createAdditionalTestSession(), testSyncTables);
        parent = Town(
          id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
          name: 'default',
        );
        first = UniqueSetDefaultChild(
          id: const Uuid().v7obj(),
          name: 'first',
          parentId: parent.id,
        );
        second = UniqueSetDefaultChild(
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
          await UniqueSetDefaultChild.db.insertRow(
            client.crdt,
            second,
            transaction: tx,
          );
        });
      });

      group('when synchronizing their scopes,', () {
        late List<UniqueSetDefaultChild> serverRows;
        late List<UniqueSetDefaultChild> clientRows;

        setUpAll(() async {
          await syncWithServer(client, server);

          serverRows = await UniqueSetDefaultChild.db.find(server.crdt);
          clientRows = await UniqueSetDefaultChild.db.find(client.crdt);
        });

        test('then both child rows remain visible.', () {
          expect(serverRows.map((row) => row.id).toSet(), {first.id, second.id});
        });

        test('then exactly one child retains the unique default reference.', () {
          expect(serverRows.where((row) => row.parentId == parent.id), hasLength(1));
          expect(serverRows.where((row) => row.parentId == null), hasLength(1));
        });

        test('then both replicas have the same projected claims.', () {
          expect(
            {for (final row in clientRows) row.id: row.parentId},
            {for (final row in serverRows) row.id: row.parentId},
          );
        });
      });
    },
  );
  group('Given a visible default town and a new child whose parent is omitted,', () {
    late SyncNode node;
    late Town parent;
    late UniqueSetDefaultChild child;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      parent = Town(
        id: UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000'),
        name: 'default',
      );
      child = UniqueSetDefaultChild(id: const Uuid().v7obj(), name: 'child');
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(node.crdt, parent, transaction: tx);
      });
    });

    group('when upserting the child locally,', () {
      late UniqueSetDefaultChild? inserted;
      late UniqueSetDefaultChild? stored;
      late CrdtMergeSet changes;

      setUpAll(() async {
        inserted = await node.crdt.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          return UniqueSetDefaultChild.db.upsertRow(
            node.crdt,
            child,
            conflictColumns: (t) => [t.id],
            transaction: tx,
          );
        });

        stored = await UniqueSetDefaultChild.db.findById(node.crdt, child.id!);
        changes = await node.sync
            .collectPendingChanges(
              node.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then the returned child has the database default.', () {
        expect(inserted, isNotNull);
        expect(inserted!.parentId, parent.id);
      });

      test('then the stored child references the default town.', () {
        expect(stored, isNotNull);
        expect(stored!.parentId, parent.id);
      });

      test('then the exported insert authors the default reference.', () {
        final exported = changes.whereType<CrdtMergeInsert>().singleWhere(
          (change) => change.uuidRowId == child.id,
        );
        expect((exported.data as UniqueSetDefaultChild).parentId, parent.id);
      });
    });
  });

  group('Given a visible child with a nullable set-default FK and a null default,', () {
    late SyncNode server;
    late SyncNode client;
    late Person parent;
    late NullableSetDefaultChild child;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), testSyncTables);
      client = await syncNode(await createAdditionalTestSession(), testSyncTables);
      parent = Person(id: const Uuid().v7obj(), name: 'parent');
      child = NullableSetDefaultChild(
        id: const Uuid().v7obj(),
        name: 'child',
        parentId: parent.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(client.crdt, parent, transaction: tx);
        await NullableSetDefaultChild.db.insertRow(client.crdt, child, transaction: tx);
      });
      await syncWithServer(client, server);
    });

    group('when deleting its parent locally and synchronizing,', () {
      late Person? clientParent;
      late NullableSetDefaultChild? clientChild;
      late Person? serverParent;
      late NullableSetDefaultChild? serverChild;
      late CrdtMergeSet changes;

      setUpAll(() async {
        await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(client.crdt, parent, transaction: tx);
        });
        await syncWithServer(client, server);

        clientParent = await Person.db.findById(client.crdt, parent.id!);
        clientChild = await NullableSetDefaultChild.db.findById(client.crdt, child.id!);
        serverParent = await Person.db.findById(server.crdt, parent.id!);
        serverChild = await NullableSetDefaultChild.db.findById(server.crdt, child.id!);
        changes = await client.sync
            .collectPendingChanges(
              client.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then the parent is hidden on the client.', () {
        expect(clientParent, isNull);
      });

      test('then the child is visible with a null reference on the client.', () {
        expect(clientChild, isNotNull);
        expect(clientChild!.parentId, isNull);
      });

      test('then the parent is hidden on the server.', () {
        expect(serverParent, isNull);
      });

      test('then the child is visible with a null reference on the server.', () {
        expect(serverChild, isNotNull);
        expect(serverChild!.parentId, isNull);
      });

      test('then the exported child insert retains the authored null.', () {
        final insert = changes.whereType<CrdtMergeInsert>().singleWhere(
          (change) => change.uuidRowId == child.id,
        );
        expect((insert.data as NullableSetDefaultChild).parentId, isNull);
      });
    });
  });

  group(
    'Given a company referencing another town and a visible default town in its scope,',
    () {
      late SyncNode server;
      late SyncNode client;
      late Town defaultTown;
      late Town town;
      late Company company;

      setUpAll(() async {
        server = await syncNode(await createAdditionalTestSession(), testSyncTables);
        client = await syncNode(await createAdditionalTestSession(), testSyncTables);
        defaultTown = Town(id: _defaultTownId, name: 'default');
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
          id: const Uuid().v7obj(),
          name: 'company',
          townId: town.id,
        );
        await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insert(client.crdt, [defaultTown, town], transaction: tx);
          await Company.db.insertRow(client.crdt, company, transaction: tx);
        });
        await syncWithServer(client, server);
      });

      group('when deleting the referenced town locally and synchronizing,', () {
        late Town? clientTown;
        late Company? clientCompany;
        late Town? clientDefault;
        late Town? serverTown;
        late Company? serverCompany;
        late Town? serverDefault;

        setUpAll(() async {
          await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await Town.db.deleteRow(client.crdt, town, transaction: tx);
          });
          await syncWithServer(client, server);

          clientTown = await Town.db.findById(client.crdt, town.id!);
          clientCompany = await Company.db.findById(client.crdt, company.id!);
          clientDefault = await Town.db.findById(client.crdt, _defaultTownId);
          serverTown = await Town.db.findById(server.crdt, town.id!);
          serverCompany = await Company.db.findById(server.crdt, company.id!);
          serverDefault = await Town.db.findById(server.crdt, _defaultTownId);
        });

        test('then the original town is hidden on the client.', () {
          expect(clientTown, isNull);
        });

        test('then the company references the default town on the client.', () {
          expect(clientCompany, isNotNull);
          expect(clientCompany!.townId, _defaultTownId);
        });

        test('then the default town is visible on the client.', () {
          expect(clientDefault, isNotNull);
        });

        test('then the original town is hidden on the server.', () {
          expect(serverTown, isNull);
        });

        test('then the company references the default town on the server.', () {
          expect(serverCompany, isNotNull);
          expect(serverCompany!.townId, _defaultTownId);
        });

        test('then the default town is visible on the server.', () {
          expect(serverDefault, isNotNull);
        });
      });
    },
  );
  group('Given a visible company whose default town is missing,', () {
    late SyncNode server;
    late SyncNode client;
    late Town town;
    late Company company;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), testSyncTables);
      client = await syncNode(await createAdditionalTestSession(), testSyncTables);
      town = Town(id: const Uuid().v7obj(), name: 'original');
      company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(client.crdt, town, transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);
    });

    group('when attempting a local town deletion and synchronizing,', () {
      Exception? deletionError;
      late Town? clientTown;
      late Company? clientCompany;
      late Town? serverTown;
      late Company? serverCompany;
      late CrdtMergeSet changes;

      setUpAll(() async {
        try {
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        await syncWithServer(client, server);

        clientTown = await Town.db.findById(client.crdt, town.id!);
        clientCompany = await Company.db.findById(client.crdt, company.id!);
        serverTown = await Town.db.findById(server.crdt, town.id!);
        serverCompany = await Company.db.findById(server.crdt, company.id!);
        changes = await client.sync
            .collectPendingChanges(
              client.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then the deletion is rejected.', () {
        expect(deletionError, isA<Exception>());
      });

      test('then the original town is visible on the client.', () {
        expect(clientTown, isNotNull);
      });

      test('then the company references the original town on the client.', () {
        expect(clientCompany, isNotNull);
        expect(clientCompany!.townId, town.id);
      });

      test('then the original town is visible on the server.', () {
        expect(serverTown, isNotNull);
      });

      test('then the company references the original town on the server.', () {
        expect(serverCompany, isNotNull);
        expect(serverCompany!.townId, town.id);
      });

      test('then no town deletion is exported.', () {
        expect(
          changes.whereType<CrdtMergeDelete>().where(
            (change) => change.uuidRowId == town.id,
          ),
          isEmpty,
        );
      });
    });
  });

  group('Given a visible company whose default town is hidden,', () {
    late SyncNode server;
    late SyncNode client;
    late Town town;
    late Company company;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), testSyncTables);
      client = await syncNode(await createAdditionalTestSession(), testSyncTables);
      town = Town(id: const Uuid().v7obj(), name: 'original');
      company = Company(
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
    });

    group('when attempting a local town deletion and synchronizing,', () {
      Exception? deletionError;
      late Town? clientTown;
      late Company? clientCompany;
      late Town? serverTown;
      late Company? serverCompany;
      late CrdtMergeSet changes;

      setUpAll(() async {
        try {
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        await syncWithServer(client, server);

        clientTown = await Town.db.findById(client.crdt, town.id!);
        clientCompany = await Company.db.findById(client.crdt, company.id!);
        serverTown = await Town.db.findById(server.crdt, town.id!);
        serverCompany = await Company.db.findById(server.crdt, company.id!);
        changes = await client.sync
            .collectPendingChanges(
              client.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then the deletion is rejected.', () {
        expect(deletionError, isA<Exception>());
      });

      test('then the original town is visible on the client.', () {
        expect(clientTown, isNotNull);
      });

      test('then the company references the original town on the client.', () {
        expect(clientCompany, isNotNull);
        expect(clientCompany!.townId, town.id);
      });

      test('then the original town is visible on the server.', () {
        expect(serverTown, isNotNull);
      });

      test('then the company references the original town on the server.', () {
        expect(serverCompany, isNotNull);
        expect(serverCompany!.townId, town.id);
      });

      test('then no town deletion is exported.', () {
        expect(
          changes.whereType<CrdtMergeDelete>().where(
            (change) => change.uuidRowId == town.id,
          ),
          isEmpty,
        );
      });
    });
  });

  group('Given a visible company and its referenced and default towns,', () {
    late SyncNode server;
    late SyncNode client;
    late Town defaultTown;
    late Town town;
    late Company company;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), testSyncTables);
      client = await syncNode(await createAdditionalTestSession(), testSyncTables);
      defaultTown = Town(id: _defaultTownId, name: 'default');
      town = Town(id: const Uuid().v7obj(), name: 'original');
      company = Company(
        id: const Uuid().v7obj(),
        name: 'company',
        townId: town.id,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insert(client.crdt, [town, defaultTown], transaction: tx);
        await Company.db.insertRow(client.crdt, company, transaction: tx);
      });
      await syncWithServer(client, server);
    });

    group('when attempting to delete both towns in a local batch and syncing,', () {
      Exception? deletionError;
      late Town? clientTown;
      late Company? clientCompany;
      late Town? clientDefault;
      late List<Town> clientTowns;
      late Town? serverTown;
      late Company? serverCompany;
      late Town? serverDefault;
      late List<Town> serverTowns;
      late CrdtMergeSet changes;

      setUpAll(() async {
        try {
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.delete(client.crdt, [town, defaultTown], transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        await syncWithServer(client, server);

        clientTown = await Town.db.findById(client.crdt, town.id!);
        clientCompany = await Company.db.findById(client.crdt, company.id!);
        clientDefault = await Town.db.findById(client.crdt, _defaultTownId);
        clientTowns = await Town.db.find(client.crdt);
        serverTown = await Town.db.findById(server.crdt, town.id!);
        serverCompany = await Company.db.findById(server.crdt, company.id!);
        serverDefault = await Town.db.findById(server.crdt, _defaultTownId);
        serverTowns = await Town.db.find(server.crdt);
        changes = await client.sync
            .collectPendingChanges(
              client.raw,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
            )
            .toList();
      });

      test('then the deletion is rejected.', () {
        expect(deletionError, isA<Exception>());
      });

      test('then the original town is visible on the client.', () {
        expect(clientTown, isNotNull);
      });

      test('then the company references the original town on the client.', () {
        expect(clientCompany, isNotNull);
        expect(clientCompany!.townId, town.id);
      });

      test('then the default town is visible on the client.', () {
        expect(clientDefault, isNotNull);
      });

      test('then only the two original towns remain on the client.', () {
        expect(clientTowns.map((row) => row.id).toSet(), {town.id, defaultTown.id});
      });

      test('then the original town is visible on the server.', () {
        expect(serverTown, isNotNull);
      });

      test('then the company references the original town on the server.', () {
        expect(serverCompany, isNotNull);
        expect(serverCompany!.townId, town.id);
      });

      test('then the default town is visible on the server.', () {
        expect(serverDefault, isNotNull);
      });

      test('then only the two original towns remain on the server.', () {
        expect(serverTowns.map((row) => row.id).toSet(), {town.id, defaultTown.id});
      });

      test('then no deletion is exported.', () {
        expect(changes.whereType<CrdtMergeDelete>(), isEmpty);
      });

      test('then no company reference repair is exported.', () {
        expect(
          changes.whereType<CrdtMergeUpdate>().where(
            (change) => change.uuidRowId == company.id && change.columnName == 'townId',
          ),
          isEmpty,
        );
      });
    });
  });

  group('Given a deleted company and its deleted town without a default town,', () {
    late SyncNode server;
    late SyncNode client;
    late Town town;
    late Company company;
    late Company hidden;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), testSyncTables);
      client = await syncNode(await createAdditionalTestSession(), testSyncTables);
      town = Town(id: const Uuid().v7obj(), name: 'original');
      company = Company(
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
      hidden = (await Company.db.findFirstRow(
        client.crdt,
        where: (t) => t.id.equals(company.id) & t.includeHiddenRows,
      ))!;
    });

    group('when restoring the company and synchronizing,', () {
      late Town? clientTown;
      late Company? clientCompany;
      late Town? serverTown;
      late Company? serverCompany;

      setUpAll(() async {
        await client.crdt.db.transactionForUser(
          testCrdtUserId,
          (tx) => Company.db.insertRow(client.crdt, hidden, transaction: tx),
        );
        await syncWithServer(client, server);

        clientTown = await Town.db.findById(client.crdt, town.id!);
        clientCompany = await Company.db.findById(client.crdt, company.id!);
        serverTown = await Town.db.findById(server.crdt, town.id!);
        serverCompany = await Company.db.findById(server.crdt, company.id!);
      });

      test('then the original town is visible on the client.', () {
        expect(clientTown, isNotNull);
      });

      test('then the company references the original town on the client.', () {
        expect(clientCompany, isNotNull);
        expect(clientCompany!.townId, town.id);
      });

      test('then the original town is visible on the server.', () {
        expect(serverTown, isNotNull);
      });

      test('then the company references the original town on the server.', () {
        expect(serverCompany, isNotNull);
        expect(serverCompany!.townId, town.id);
      });
    });
  });

  group(
    'Given a deleted company and its deleted town with a visible default town,',
    () {
      late SyncNode server;
      late SyncNode client;
      late Town town;
      late Company company;
      late Company hidden;

      setUpAll(() async {
        server = await syncNode(await createAdditionalTestSession(), testSyncTables);
        client = await syncNode(await createAdditionalTestSession(), testSyncTables);
        town = Town(id: const Uuid().v7obj(), name: 'original');
        company = Company(
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
        hidden = (await Company.db.findFirstRow(
          client.crdt,
          where: (t) => t.id.equals(company.id) & t.includeHiddenRows,
        ))!;
      });

      group('when restoring the company and synchronizing,', () {
        late Town? clientTown;
        late Company? clientCompany;
        late Town? clientDefault;
        late Town? serverTown;
        late Company? serverCompany;
        late Town? serverDefault;

        setUpAll(() async {
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Company.db.insertRow(client.crdt, hidden, transaction: tx),
          );
          await syncWithServer(client, server);

          clientTown = await Town.db.findById(client.crdt, town.id!);
          clientCompany = await Company.db.findById(client.crdt, company.id!);
          clientDefault = await Town.db.findById(client.crdt, _defaultTownId);
          serverTown = await Town.db.findById(server.crdt, town.id!);
          serverCompany = await Company.db.findById(server.crdt, company.id!);
          serverDefault = await Town.db.findById(server.crdt, _defaultTownId);
        });

        test('then the original town is hidden on the client.', () {
          expect(clientTown, isNull);
        });

        test('then the company references the default town on the client.', () {
          expect(clientCompany, isNotNull);
          expect(clientCompany!.townId, _defaultTownId);
        });

        test('then the default town is visible on the client.', () {
          expect(clientDefault, isNotNull);
        });

        test('then the original town is hidden on the server.', () {
          expect(serverTown, isNull);
        });

        test('then the company references the default town on the server.', () {
          expect(serverCompany, isNotNull);
          expect(serverCompany!.townId, _defaultTownId);
        });

        test('then the default town is visible on the server.', () {
          expect(serverDefault, isNotNull);
        });
      });
    },
  );
  group(
    'Given a company authored offline while the server deletes its town and no default exists,',
    () {
      late SyncNode server;
      late SyncNode client;
      late Town town;
      late Company company;

      setUpAll(() async {
        server = await syncNode(await createAdditionalTestSession(), testSyncTables);
        client = await syncNode(await createAdditionalTestSession(), testSyncTables);
        town = Town(id: const Uuid().v7obj(), name: 'town');
        company = Company(
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
      });

      group('when synchronizing the client and server,', () {
        late Town? clientTown;
        late Company? clientCompany;
        late Town? serverTown;
        late Company? serverCompany;

        setUpAll(() async {
          await syncWithServer(client, server);

          clientTown = await Town.db.findById(client.crdt, town.id!);
          clientCompany = await Company.db.findById(client.crdt, company.id!);
          serverTown = await Town.db.findById(server.crdt, town.id!);
          serverCompany = await Company.db.findById(server.crdt, company.id!);
        });

        test('then the original town is visible on the client.', () {
          expect(clientTown, isNotNull);
        });

        test('then the company references the original town on the client.', () {
          expect(clientCompany, isNotNull);
          expect(clientCompany!.townId, town.id);
        });

        test('then the original town is visible on the server.', () {
          expect(serverTown, isNotNull);
        });

        test('then the company references the original town on the server.', () {
          expect(serverCompany, isNotNull);
          expect(serverCompany!.townId, town.id);
        });
      });
    },
  );
}

const _defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');
