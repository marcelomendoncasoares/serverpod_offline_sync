import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

/// When two rows claim the same per-scope unique value, the later claim is
/// released by rewriting its own column so the visible unique index holds and
/// the conflict surfaces to the user.
///
/// Whether a node performs that release depends on what it had merged at the
/// time, and whether it later reverses it depends on what it merges afterwards.
/// Both decisions are derived state, so they must reach the same fixed point on
/// every node holding the same facts — the requirement foreign-key projection
/// already carries (`docs/foreign-key-invariants.md`).
///
/// The topology here is strictly hub and spoke: clients exchange changes only
/// with the server, never with each other, which is how a deployed Serverpod
/// application syncs.
void main() {
  initTestClientSession();

  final syncTables = [Unique.t];

  Future<Unique> claim(SyncNode owner, String name) async {
    final row = Unique(id: const Uuid().v7obj(), name: name);
    await owner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
      await Unique.db.insertRow(owner.crdt, row, transaction: tx);
    });
    return row;
  }

  /// Every row with its visibility, ordered by id so nodes compare directly.
  Future<String> render(SyncNode node) async {
    final rows = await Unique.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {for (final row in await Unique.db.find(node.crdt)) row.id};
    rows.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    return [
      for (final row in rows)
        '${visible.contains(row.id) ? 'visible' : 'hidden'} ${row.name}',
    ].join(' | ');
  }

  group(
    'Given a client that synced a unique value before any competing claim reached the server,',
    () {
      late SyncNode server;
      late SyncNode winnerClient;
      late SyncNode loserClient;
      late SyncNode bystander;
      late Unique winner;

      setUp(() async {
        server = await syncNode(testSession, syncTables);
        winnerClient = await syncNode(await createAdditionalTestSession(), syncTables);
        loserClient = await syncNode(await createAdditionalTestSession(), syncTables);
        bystander = await syncNode(await createAdditionalTestSession(), syncTables);

        // The winning claim is authored first, so it holds the earlier HLC,
        // but it stays offline while the losing claim reaches the server.
        winner = await claim(winnerClient, 'contested');
        await claim(loserClient, 'contested');

        await syncWithServer(loserClient, server);
        await syncWithServer(bystander, server);

        // Only now does the competing claim arrive and force a release.
        await syncWithServer(winnerClient, server);
        await syncWithServer(bystander, server);
      });

      group('when the competing claim is deleted and every client syncs again,', () {
        setUp(() async {
          await winnerClient.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.deleteRow(
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

        test('then all nodes agree on the released row.', () async {
          final expected = await render(server);

          expect(await render(winnerClient), expected);
          expect(await render(loserClient), expected);
          expect(await render(bystander), expected);
        });
      });
    },
  );
}
