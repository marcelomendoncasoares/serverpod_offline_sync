import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

/// One node in the topology: the raw session collection reads from, the CRDT
/// session used for reads and merges, and its own sync engine.
typedef _Node = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

/// Deleted rows stay in their table, so a hidden row still occupies every
/// physical index it is part of - while being invisible to unique conflict
/// resolution, which only considers visible rows.
///
/// That makes a foreign key column carrying a unique index the one place where
/// foreign key projection and unique resolution meet. Merging a set-null repair
/// frees the value; restoring the parent later makes the attempted value
/// eligible again. If projection materializes it back onto a row that is still
/// tombstoned, the value is taken in the index and unavailable to resolution,
/// so the next legitimate claim on that parent passes resolution and then
/// fails the database index - aborting the whole merge on every replica.
///
/// The topology is strictly hub and spoke: clients exchange changes only with
/// the server, never with each other, which is how a deployed Serverpod
/// application syncs.
void main() {
  initTestClientSession();

  final syncTables = testSyncTables;

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

  /// Every child with its visibility and reference, ordered by name so nodes
  /// compare directly. Hidden rows are included because a hidden row holding
  /// the contested value is exactly what this asserts about.
  Future<String> render(_Node node) async {
    final rows = await UniqueSetNullChild.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {
      for (final row in await UniqueSetNullChild.db.find(node.crdt)) row.id,
    };
    rows.sort((left, right) => left.name.compareTo(right.name));
    return rows
        .map((row) {
          final state = visible.contains(row.id) ? 'visible' : 'hidden';
          return '$state ${row.name} parentId=${row.parentId}';
        })
        .join(' | ');
  }

  group(
    'Given a tombstoned child whose unique foreign key was repaired away and '
    'whose parent was then restored,',
    () {
      late _Node server;
      late _Node author;
      late _Node deleter;
      late _Node restorer;
      late _Node claimant;
      late Person parent;
      late UniqueSetNullChild child;

      setUp(() async {
        server = await node(testSession);
        author = await node(await createAdditionalTestSession());
        deleter = await node(await createAdditionalTestSession());
        restorer = await node(await createAdditionalTestSession());
        claimant = await node(await createAdditionalTestSession());

        // A person every node knows.
        parent = Person(id: const Uuid().v7obj(), name: 'parent');
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(author.crdt, parent, transaction: tx);
        });
        await syncWithServer(author, server);
        for (final peer in [deleter, restorer, claimant]) {
          await syncWithServer(peer, server);
        }

        // The person is deleted while the author is offline.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(deleter.crdt, parent, transaction: tx);
        });
        await syncWithServer(deleter, server);

        // Unaware, the author claims the person on a unique set-null column.
        // Merging that insert repairs the reference to null, because the
        // person is hidden.
        child = UniqueSetNullChild(
          id: const Uuid().v7obj(),
          name: 'child',
          parentId: parent.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueSetNullChild.db.insertRow(
            author.crdt,
            child,
            transaction: tx,
          );
        });
        await syncWithServer(author, server);

        // The child is deleted while its reference is already null. Releasing
        // a unique value skips a column that is null, so this delete carries a
        // tombstone and no release fact.
        await syncWithServer(deleter, server);
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueSetNullChild.db.deleteRow(
            deleter.crdt,
            child,
            transaction: tx,
          );
        });
        await syncWithServer(deleter, server);
        await syncWithServer(author, server);

        // The person is restored: a client that never saw the delete
        // references it over a no-action edge, so the delete loses.
        final address = Address(
          id: const Uuid().v7obj(),
          street: 'street',
          inhabitantId: parent.id,
        );
        await restorer.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Address.db.insertRow(restorer.crdt, address, transaction: tx);
        });
        await syncWithServer(restorer, server);
        await syncWithServer(author, server);
        await syncWithServer(deleter, server);
      });

      group('when another client claims the restored person and everyone syncs,', () {
        setUp(() async {
          await syncWithServer(claimant, server);

          final reclaim = UniqueSetNullChild(
            id: const Uuid().v7obj(),
            name: 'reclaim',
            parentId: parent.id,
          );
          await claimant.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueSetNullChild.db.insertRow(
              claimant.crdt,
              reclaim,
              transaction: tx,
            );
          });

          await syncWithServer(claimant, server);
          for (final peer in [author, deleter, restorer]) {
            await syncWithServer(peer, server);
          }
        });

        test('then the merge succeeds and all nodes agree.', () async {
          final expected = await render(server);

          expect(await render(author), expected, reason: 'author');
          expect(await render(deleter), expected, reason: 'deleter');
          expect(await render(restorer), expected, reason: 'restorer');
          expect(await render(claimant), expected, reason: 'claimant');
        });

        group('and the tombstoned child is then restored,', () {
          late Object? restoreError;

          setUp(() async {
            // Reinserting a tombstoned row restores it
            // (`CrdtDataDeletedReason.userReinsert`). Its attempted reference
            // is still the parent, which another row now holds on a column
            // that is unique across the table.
            try {
              await author.crdt.db.transactionForUser(testCrdtUserId, (
                tx,
              ) async {
                await UniqueSetNullChild.db.insertRow(
                  author.crdt,
                  child,
                  transaction: tx,
                );
              });
              restoreError = null;
            } on Object catch (error) {
              restoreError = error;
            }
          });

          test('then the restore is resolved rather than failing the write.', () {
            expect(restoreError, isNull);
          });

          test('then all nodes agree after syncing.', () async {
            for (final peer in [author, deleter, restorer, claimant]) {
              await syncWithServer(peer, server);
            }
            final expected = await render(server);

            expect(await render(author), expected, reason: 'author');
            expect(await render(deleter), expected, reason: 'deleter');
            expect(await render(restorer), expected, reason: 'restorer');
            expect(await render(claimant), expected, reason: 'claimant');
          });
        });
      });
    },
  );
}
