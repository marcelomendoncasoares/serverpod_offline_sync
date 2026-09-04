import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

/// One node in the topology: the raw session collection reads from, the CRDT
/// session used for reads and merges, and its own sync engine.
typedef _Node = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

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

  /// One client sync cycle: push local changes up, then merge the server's.
  Future<void> syncWithServer(_Node client, _Node server) async {
    await push(client, server);
    await push(server, client);
  }

  Future<Unique> claim(_Node owner, String name) async {
    final row = Unique(id: const Uuid().v7obj(), name: name);
    await owner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
      await Unique.db.insertRow(owner.crdt, row, transaction: tx);
    });
    return row;
  }

  /// Every row with its visibility, ordered by id so nodes compare directly.
  Future<String> render(_Node node) async {
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
      late _Node server;
      late _Node winnerClient;
      late _Node loserClient;
      late _Node bystander;
      late Unique winner;

      setUp(() async {
        server = await node(testSession);
        winnerClient = await node(await createAdditionalTestSession());
        loserClient = await node(await createAdditionalTestSession());
        bystander = await node(await createAdditionalTestSession());

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
