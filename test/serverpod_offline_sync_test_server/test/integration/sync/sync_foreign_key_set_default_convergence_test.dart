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
/// The local delete path rewrites unconditionally, so it authors the very
/// states the merge-time blocking policy exists to prevent — a company left
/// pointing at the hidden default town, or a company referencing a town owned
/// by another scope — and those facts then sync to every node. These
/// scenarios reproduce what the DST sweep found.
void main() {
  initTestClientSession();

  // Town references city and person, and person references organization,
  // company and city, so the subset is only closed with all five tables.
  final syncTables = [City.t, Organization.t, Person.t, Town.t, Company.t];

  /// The `company.townId` column default from `company.spy.yaml`.
  const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

  /// Every town and company with its visibility and reference, ordered so
  /// nodes compare directly. Hidden rows are included because a repair that
  /// is skipped on a tombstoned row is exactly what this asserts.
  Future<String> render(SyncNode node) async {
    final towns = await Town.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final companies = await Company.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visibleTowns = {
      for (final town in await Town.db.find(node.crdt)) town.id,
    };
    final visibleCompanies = {
      for (final company in await Company.db.find(node.crdt)) company.id,
    };
    towns.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    companies.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    return [
      for (final town in towns)
        '${visibleTowns.contains(town.id) ? 'visible' : 'hidden'} town ${town.name}',
      for (final company in companies)
        '${visibleCompanies.contains(company.id) ? 'visible' : 'hidden'} company ${company.name} townId=${company.townId}',
    ].join(' | ');
  }

  group(
    'Given a company referencing the default town,',
    () {
      late SyncNode server;
      late SyncNode client;
      late Town defaultTown;
      late Company company;

      setUp(() async {
        server = await syncNode(testSession, syncTables);
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
        late Future<Town> defaultTownDelete;

        setUp(() async {
          defaultTownDelete = client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) =>
                Town.db.deleteRow(client.crdt, defaultTown, transaction: tx),
          );
          // Settle the delete before syncing; its rejection is asserted below.
          await defaultTownDelete.catchError((_) => defaultTown);

          for (var round = 0; round < 3; round++) {
            await syncWithServer(client, server);
          }
        });

        test(
          'then the delete fails because the set-default repair target is the row being deleted.',
          () async {
            await expectLater(defaultTownDelete, throwsA(isA<Exception>()));
          },
        );

        test(
          'then all nodes agree that the company still references the default town.',
          () async {
            final expected = await render(server);

            expect(await render(client), expected);
          },
        );
      });
    },
  );

  group(
    'Given a company in a scope that does not hold the default town,',
    () {
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

      setUp(() async {
        server = await syncNode(testSession, syncTables);
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
        late Future<Town> townDelete;

        setUp(() async {
          townDelete = client.crdt.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.deleteRow(client.crdt, town, transaction: tx),
          );
          // Settle the delete before syncing; its rejection is asserted below.
          await townDelete.catchError((_) => town);

          for (var round = 0; round < 3; round++) {
            await syncBothScopes();
          }
        });

        test(
          'then the delete fails because the set-default repair cannot cross scopes.',
          () async {
            await expectLater(townDelete, throwsA(isA<Exception>()));
          },
        );

        test(
          'then the company still references the town from its own scope on every node.',
          () async {
            for (final node in [server, client]) {
              final companies = await Company.db.find(
                node.crdt,
                where: (t) => t.includeHiddenRows,
              );

              expect(companies, hasLength(1));
              expect(companies.single.townId, town.id);
            }
          },
        );
      });
    },
  );
}
