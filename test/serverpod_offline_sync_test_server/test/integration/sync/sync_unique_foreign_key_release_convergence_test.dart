import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  final syncTables = [Address.t, Person.t];

  Future<Address> claim(SyncNode owner, String street, Person inhabitant) async {
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

  Future<String> render(SyncNode node) async {
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
      late SyncNode server;
      late SyncNode winnerClient;
      late SyncNode loserClient;
      late SyncNode bystander;
      late Address winner;

      setUp(() async {
        server = await syncNode(testSession, syncTables);
        winnerClient = await syncNode(await createAdditionalTestSession(), syncTables);
        loserClient = await syncNode(await createAdditionalTestSession(), syncTables);
        bystander = await syncNode(await createAdditionalTestSession(), syncTables);

        // The referenced row every node knows
        final inhabitant = Person(
          id: const Uuid().v7obj(),
          name: 'inhabitant',
          surname: 'inhabitant',
        );
        await server.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(server.crdt, inhabitant, transaction: tx);
        });
        await pushChanges(server, winnerClient);
        await pushChanges(server, loserClient);
        await pushChanges(server, bystander);

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
