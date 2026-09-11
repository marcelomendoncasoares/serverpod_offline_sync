import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

/// Deleting a row referenced by an `onDelete=SetDefault` edge rewrites the
/// referencing column to the column default. That rewrite is only legal while
/// the default target is a visible parent in the child's own scope
/// (`docs/foreign-key-invariants.md`, "Merge-Time Action Semantics"): when the
/// default target is the row being deleted, or lives in another scope, the
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
      await server.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Town.db.insertRow(server.crdt, defaultTown, transaction: tx);
      });
      await syncWithServer(client, server);

      company = Company(
        id: const Uuid().v7obj(),
        name: 'company on the default town',
        townId: defaultTownId,
      );
      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await Company.db.insertRow(client.crdt, company, transaction: tx);
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
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.crdt, defaultTown, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        for (var round = 0; round < 3; round++) {
          await syncWithServer(client, server);
        }
        serverTowns = await Town.db.find(
          server.crdt,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleTowns = await Town.db.find(server.crdt);
        serverCompanies = await Company.db.find(
          server.crdt,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleCompanies = await Company.db.find(server.crdt);
        clientTowns = await Town.db.find(
          client.crdt,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleTowns = await Town.db.find(client.crdt);
        clientCompanies = await Company.db.find(
          client.crdt,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleCompanies = await Company.db.find(client.crdt);
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

  group('Given a company in a scope that does not hold the default town,', () {
    late SyncNode server;
    late SyncNode client;
    late UuidValue defaultTownScope;
    late Town town;

    Future<void> pushScope(SyncNode from, SyncNode to, UuidValue scope) async {
      final changes = await from.sync
          .collectPendingChanges(
            from.raw,
            checkpointsByScopeUuid: {scope: const []},
          )
          .toList();
      await to.crdt.db.mergeChanges(changes, scopeId: scope);
    }

    Future<void> syncBothScopes() async {
      for (final scope in [testCrdtUserId, defaultTownScope]) {
        await pushScope(client, server, scope);
        await pushScope(server, client, scope);
      }
    }

    setUpAll(() async {
      server = await syncNode(await createAdditionalTestSession(), syncTables);
      client = await syncNode(await createAdditionalTestSession(), syncTables);

      // The default town exists only in this second scope, which both nodes
      // hold, so the client's database physically contains the row a
      // set-default repair would rewrite to.
      defaultTownScope = const Uuid().v7obj();
      await server.crdt.db.transactionForUser(defaultTownScope, (tx) async {
        await Town.db.insertRow(
          server.crdt,
          Town(id: defaultTownId, name: 'default town'),
          transaction: tx,
        );
      });
      await pushScope(server, client, defaultTownScope);

      await client.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        town = await Town.db.insertRow(
          client.crdt,
          Town(id: const Uuid().v7obj(), name: 'scope town'),
          transaction: tx,
        );
        await Company.db.insertRow(
          client.crdt,
          Company(
            id: const Uuid().v7obj(),
            name: 'company in its own scope',
            townId: town.id,
          ),
          transaction: tx,
        );
      });
      await syncBothScopes();
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
          await client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
          );
        } on Exception catch (error) {
          deletionError = error;
        }
        for (var round = 0; round < 3; round++) {
          await syncBothScopes();
        }
        serverTowns = await Town.db.find(
          server.crdt,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleTowns = await Town.db.find(server.crdt);
        serverCompanies = await Company.db.find(
          server.crdt,
          where: (t) => t.includeHiddenRows,
        );
        serverVisibleCompanies = await Company.db.find(server.crdt);
        clientTowns = await Town.db.find(
          client.crdt,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleTowns = await Town.db.find(client.crdt);
        clientCompanies = await Company.db.find(
          client.crdt,
          where: (t) => t.includeHiddenRows,
        );
        clientVisibleCompanies = await Company.db.find(client.crdt);
      });

      test(
        'then the delete is rejected because the fallback belongs to another scope.',
        () {
          expect(deletionError, isA<Exception>());
        },
      );
      test(
        'then the company still references the town from its own scope on the server.',
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
        'then the company still references the town from its own scope on the client.',
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
