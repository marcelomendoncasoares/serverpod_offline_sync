import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

/// One node in the topology: the raw session collection reads from, the CRDT
/// session used for reads and merges, and its own sync engine.
typedef _Node = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

/// Deleting a row releases its per-scope unique value by rewriting the column,
/// so a later row may claim that value again. Deleted rows stay in their table,
/// so the release is what keeps the physical unique index free.
///
/// The release is written as an ordinary field value, which means a concurrent
/// update to the same column outranks it under last-writer-wins and restores a
/// clean value on a row that is tombstoned. Conflict resolution only considers
/// visible rows, so a later claim on that value passes resolution and then
/// violates the database index, failing the whole merge.
///
/// The topology is strictly hub and spoke: clients exchange changes only with
/// the server, never with each other, which is how a deployed Serverpod
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

  /// Every row with its visibility, ordered by id so nodes compare directly.
  Future<String> render(_Node node) async {
    final rows = await Unique.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {for (final row in await Unique.db.find(node.crdt)) row.id};
    rows.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    return rows
        .map((row) {
          final visibility = visible.contains(row.id) ? 'visible' : 'hidden';
          return '$visibility ${row.name}';
        })
        .join(' | ');
  }

  group(
    'Given a deleted row whose released unique value was overwritten by a concurrent rename,',
    () {
      late _Node server;
      late _Node deleter;
      late _Node renamer;
      late _Node newcomer;

      setUp(() async {
        server = await node(testSession);
        deleter = await node(await createAdditionalTestSession());
        renamer = await node(await createAdditionalTestSession());
        newcomer = await node(await createAdditionalTestSession());

        final row = Unique(id: const Uuid().v7obj(), name: 'original');
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.insertRow(deleter.crdt, row, transaction: tx);
        });
        await syncWithServer(deleter, server);
        await syncWithServer(renamer, server);

        // Offline, one client deletes the row, releasing its unique value.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.deleteRow(deleter.crdt, row, transaction: tx);
        });

        // Offline and unaware of the delete, another client renames the same
        // column. Its update carries the later timestamp, so it wins.
        await renamer.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.updateRow(
            renamer.crdt,
            row.copyWith(name: 'target'),
            columns: (t) => [t.name],
            transaction: tx,
          );
        });

        await syncWithServer(deleter, server);
        await syncWithServer(renamer, server);
        await syncWithServer(deleter, server);
      });

      group('when a client that never saw the row claims that value and syncs,', () {
        setUp(() async {
          final claim = Unique(id: const Uuid().v7obj(), name: 'target');
          await newcomer.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(newcomer.crdt, claim, transaction: tx);
          });

          await syncWithServer(newcomer, server);
          await syncWithServer(deleter, server);
          await syncWithServer(renamer, server);
          await syncWithServer(newcomer, server);
        });

        test('then the merge succeeds and all nodes agree.', () async {
          final expected = await render(server);

          expect(await render(deleter), expected);
          expect(await render(renamer), expected);
          expect(await render(newcomer), expected);
        });
      });
    },
  );
}
