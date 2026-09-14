import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

/// Deleting a row referenced by an `onDelete=SetDefault` edge rewrites the
/// referencing column to the column default. That rewrite is only legal while
/// the default target is a visible parent in the child's own space
/// (`docs/foreign-key-invariants.md`, "Merge-Time Action Semantics"): when the
/// default target is the row being deleted, or lives in another space, the
/// action cannot repair the child and the delete must lose.
///
/// These scenarios keep the rejected local delete and subsequent sync in one
/// shared action, then check the rejection and replicated state independently.
void main() {
  initTestClientSession(createSessionPerTest: false);

  // Town references city and person, and person references organization,
  // company and city, so the subset is only closed with all five tables.
  final syncTables = [City.t, Organization.t, Person.t, Town.t, Company.t];

  /// The `company.townId` column default from `company.spy.yaml`.
  const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

  group('Given a company referencing the default town,', () {
    late SyncNode server;
    late SyncNode client;
    late Town defaultTown;
    late Company company;

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), syncTables);
      client = await syncNode(await createAdditionalTestSession(), syncTables);

      defaultTown = Town(id: defaultTownId, name: 'default town');
      await server.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(server.offlineSync, defaultTown, transaction: tx);
      });
      await syncWithServer(client, server);

      company = Company(
        id: const Uuid().v7obj(),
        name: 'company on the default town',
        townId: defaultTownId,
      );
      await client.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await Company.db.insertRow(client.offlineSync, company, transaction: tx);
      });
      await syncWithServer(client, server);
    });

    group('when trying to delete the default town and syncing again,', () {
      Exception? deletionError;
      late List<Town> serverTowns;
      late List<Town> serverVisibleTowns;
      late List<Company> serverCompanies;
      late List<Company> serverVisibleCompanies;
      late List<Town> clientTowns;
      late List<Town> clientVisibleTowns;
      late List<Company> clientCompanies;
      late List<Company> clientVisibleCompanies;

      setUpAll(() async {
        try {
          await client.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.offlineSync, defaultTown, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        for (var round = 0; round < 3; round++) {
          await syncWithServer(client, server);
        }
        serverTowns = await Town.db.find(
          server.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleTowns = await Town.db.find(server.offlineSync);
        serverCompanies = await Company.db.find(
          server.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleCompanies = await Company.db.find(server.offlineSync);
        clientTowns = await Town.db.find(
          client.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleTowns = await Town.db.find(client.offlineSync);
        clientCompanies = await Company.db.find(
          client.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleCompanies = await Company.db.find(client.offlineSync);
      });

      test('then the delete is rejected because the fallback is the deleted row.', () {
        expect(deletionError, isA<Exception>());
      });

      test('then the company still references the default town on the server.', () {
        expect(serverCompanies, hasLength(1));
        expect(serverCompanies.single.townId, defaultTown.id);
        expect(
          serverVisibleCompanies.map((row) => row.id),
          contains(serverCompanies.single.id),
        );
        expect(serverVisibleTowns.map((row) => row.id), contains(defaultTown.id));
      });

      test('then the company still references the default town on the client.', () {
        expect(clientCompanies, hasLength(1));
        expect(clientCompanies.single.townId, defaultTown.id);
        expect(
          clientVisibleCompanies.map((row) => row.id),
          contains(clientCompanies.single.id),
        );
        expect(clientVisibleTowns.map((row) => row.id), contains(defaultTown.id));
      });

      test('then both replicas agree on every stored town and company.', () {
        expect(
          {for (final row in clientTowns) row.id: row.name},
          {for (final row in serverTowns) row.id: row.name},
        );
        expect(
          {for (final row in clientCompanies) row.id: (row.name, row.townId)},
          {for (final row in serverCompanies) row.id: (row.name, row.townId)},
        );
      });

      test('then both replicas agree on town and company visibility.', () {
        expect(
          clientVisibleTowns.map((row) => row.id).toSet(),
          serverVisibleTowns.map((row) => row.id).toSet(),
        );
        expect(
          clientVisibleCompanies.map((row) => row.id).toSet(),
          serverVisibleCompanies.map((row) => row.id).toSet(),
        );
      });
    });
  });

  group('Given a company in a space that does not hold the default town,', () {
    late SyncNode server;
    late SyncNode client;
    late UuidValue defaultTownSpace;
    late Town town;

    Future<void> pushSpace(SyncNode from, SyncNode to, UuidValue space) async {
      final changes = await from.sync
          .collectPendingChanges(
            from.raw,
            checkpointsBySpaceUuid: {space: const []},
          )
          .toList();
      await to.offlineSync.db.mergeChanges(changes, spaceId: space);
    }

    Future<void> syncBothSpaces() async {
      for (final space in [testCrdtUserId, defaultTownSpace]) {
        await pushSpace(client, server, space);
        await pushSpace(server, client, space);
      }
    }

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), syncTables);
      client = await syncNode(await createAdditionalTestSession(), syncTables);

      // The default town exists only in this second space, which both nodes
      // hold, so the client's database physically contains the row a
      // set-default repair would rewrite to.
      defaultTownSpace = const Uuid().v7obj();
      await server.offlineSync.db.transactionForUser(defaultTownSpace, (tx) async {
        await Town.db.insertRow(
          server.offlineSync,
          Town(id: defaultTownId, name: 'default town'),
          transaction: tx,
        );
      });
      await pushSpace(server, client, defaultTownSpace);

      await client.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        town = await Town.db.insertRow(
          client.offlineSync,
          Town(id: const Uuid().v7obj(), name: 'space town'),
          transaction: tx,
        );
        await Company.db.insertRow(
          client.offlineSync,
          Company(
            id: const Uuid().v7obj(),
            name: 'company in its own space',
            townId: town.id,
          ),
          transaction: tx,
        );
      });
      await syncBothSpaces();
    });

    group('when trying to delete the referenced town and syncing again,', () {
      Exception? deletionError;
      late List<Town> serverTowns;
      late List<Town> serverVisibleTowns;
      late List<Company> serverCompanies;
      late List<Company> serverVisibleCompanies;
      late List<Town> clientTowns;
      late List<Town> clientVisibleTowns;
      late List<Company> clientCompanies;
      late List<Company> clientVisibleCompanies;

      setUpAll(() async {
        try {
          await client.offlineSync.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.offlineSync, town, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        for (var round = 0; round < 3; round++) {
          await syncBothSpaces();
        }
        serverTowns = await Town.db.find(
          server.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleTowns = await Town.db.find(server.offlineSync);
        serverCompanies = await Company.db.find(
          server.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleCompanies = await Company.db.find(server.offlineSync);
        clientTowns = await Town.db.find(
          client.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleTowns = await Town.db.find(client.offlineSync);
        clientCompanies = await Company.db.find(
          client.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleCompanies = await Company.db.find(client.offlineSync);
      });

      test(
        'then the delete is rejected because the fallback belongs to another space.',
        () {
          expect(deletionError, isA<Exception>());
        },
      );
      test(
        'then the company still references the town from its own space on the server.',
        () {
          expect(serverCompanies, hasLength(1));
          expect(serverCompanies.single.townId, town.id);
          expect(
            serverVisibleCompanies.map((row) => row.id),
            contains(serverCompanies.single.id),
          );
          expect(serverVisibleTowns.map((row) => row.id), contains(town.id));
        },
      );
      test(
        'then the company still references the town from its own space on the client.',
        () {
          expect(clientCompanies, hasLength(1));
          expect(clientCompanies.single.townId, town.id);
          expect(
            clientVisibleCompanies.map((row) => row.id),
            contains(clientCompanies.single.id),
          );
          expect(clientVisibleTowns.map((row) => row.id), contains(town.id));
        },
      );
      test('then both replicas agree on every stored town and company.', () {
        expect(
          {for (final row in clientTowns) row.id: row.name},
          {for (final row in serverTowns) row.id: row.name},
        );
        expect(
          {for (final row in clientCompanies) row.id: (row.name, row.townId)},
          {for (final row in serverCompanies) row.id: (row.name, row.townId)},
        );
      });

      test('then both replicas agree on town and company visibility.', () {
        expect(
          clientVisibleTowns.map((row) => row.id).toSet(),
          serverVisibleTowns.map((row) => row.id).toSet(),
        );
        expect(
          clientVisibleCompanies.map((row) => row.id).toSet(),
          serverVisibleCompanies.map((row) => row.id).toSet(),
        );
      });
    });
  });
}
