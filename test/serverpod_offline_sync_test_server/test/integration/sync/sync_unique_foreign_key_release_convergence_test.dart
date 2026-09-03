import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

typedef _Node = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

void main() {
  initTestClientSession();

  final syncTables = [Address.t, Person.t];

  Future<_Node> node(DatabaseSession raw) async {
    final crdt = CrdtDatabaseSession.wraps(raw, syncTables: syncTables);
    await crdt.db.initialize();
    return (
      raw: raw,
      crdt: crdt,
      sync: CrdtSync(
        syncTables: syncTables,
        serializationManager: raw.db.serializationManager,
      ),
    );
  }

  Future<void> push(_Node from, _Node to) async {
    final changes = await from.sync
        .collectPendingChanges(
          from.raw,
          checkpointsByScopeUuid: {testCrdtUserId: const []},
        )
        .toList();
    await to.crdt.db.mergeChanges(changes, scopeId: testCrdtUserId);
  }

  Future<void> syncWithServer(_Node client, _Node server) async {
    await push(client, server);
    await push(server, client);
  }

  Future<Address> claim(_Node owner, String street, Person inhabitant) async {
    final row = Address(
      id: const Uuid().v7obj(),
      street: street,
      inhabitantId: inhabitant.id,
    );
    await owner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
      await Address.db.insertRow(owner.crdt, row, transaction: tx);
    });
    return row;
  }

  Future<String> render(_Node node) async {
    final rows = await Address.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {
      for (final row in await Address.db.find(node.crdt)) row.id,
    };
    rows.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    return [
      for (final row in rows)
        '${visible.contains(row.id) ? 'visible' : 'hidden'} ${row.street} inhabitantId=${row.inhabitantId}',
    ].join(' | ');
  }

  group(
    'Given a client that synced a foreign-key unique claim before any competing claim reached the server,',
    () {
      late _Node server;
      late _Node winnerClient;
      late _Node loserClient;
      late _Node bystander;
      late Address winner;

      setUp(() async {
        server = await node(testSession);
        winnerClient = await node(await createAdditionalTestSession());
        loserClient = await node(await createAdditionalTestSession());
        bystander = await node(await createAdditionalTestSession());

        // The referenced row every node knows
        final inhabitant = Person(
          id: const Uuid().v7obj(),
          name: 'inhabitant',
          surname: 'inhabitant',
        );
        await server.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(server.crdt, inhabitant, transaction: tx);
        });
        await push(server, winnerClient);
        await push(server, loserClient);
        await push(server, bystander);

        // The winning claim is authored first, so it holds the earlier HLC,
        // but it stays offline while the losing claim reaches the server.
        winner = await claim(winnerClient, 'winner', inhabitant);
        await claim(loserClient, 'loser', inhabitant);

        await syncWithServer(loserClient, server);
        await syncWithServer(bystander, server);

        // Only now does the competing claim arrive and force a release, which
        // nulls the losing row's reference.
        await syncWithServer(winnerClient, server);
        await syncWithServer(bystander, server);
      });

      group('when the winning claim is deleted and every client syncs again,', () {
        setUp(() async {
          await winnerClient.crdt.db.transactionForUser(testCrdtUserId, (
            tx,
          ) async {
            await Address.db.deleteRow(
              winnerClient.crdt,
              winner,
              transaction: tx,
            );
          });

          for (var round = 0; round < 3; round++) {
            await syncWithServer(winnerClient, server);
            await syncWithServer(loserClient, server);
            await syncWithServer(bystander, server);
          }
        });

        test('then all nodes agree on the released reference.', () async {
          final expected = await render(server);

          expect(await render(winnerClient), expected);
          expect(await render(loserClient), expected);
          expect(await render(bystander), expected);
        });
      });
    },
  );
}
