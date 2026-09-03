import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

/// One node in the topology: the raw session collection reads from, the CRDT
/// session used for reads and merges, and its own sync engine.
typedef _Node = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

/// Deleting a row releases its unique values by rewriting the column, so a
/// later row may claim them again. That release is written by the local delete
/// path alone: merge applies a tombstone without releasing, and foreign key
/// projection hides cascade children while only ever writing foreign key
/// columns.
///
/// So a row that is hidden by cascade projection rather than by a local delete
/// carries no release on any replica - nowhere in the system does one exist.
/// It keeps its unique value in the physical index while being invisible to
/// conflict resolution, which only considers visible rows. The next legitimate
/// claim on that value therefore passes resolution and then violates the
/// database index, failing the whole merge.
///
/// Nothing here is specific to references. The contested column is plain text
/// released by suffix; the cascade edge only supplies the route by which a row
/// becomes hidden without ever being deleted locally.
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

  /// Every child with its visibility and name, ordered by name so nodes compare
  /// directly. Hidden rows are included because a hidden row holding the
  /// contested value is exactly what this asserts about.
  Future<String> render(_Node node) async {
    final rows = await UniqueCascadeChild.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {
      for (final row in await UniqueCascadeChild.db.find(node.crdt)) row.id,
    };
    rows.sort((left, right) => left.name.compareTo(right.name));
    return [
      for (final row in rows)
        '${visible.contains(row.id) ? 'visible' : 'hidden'} ${row.name}',
    ].join(' | ');
  }

  group(
    'Given a child hidden by cascade projection rather than by a local delete, '
    'so no replica ever released its unique name,',
    () {
      late _Node server;
      late _Node author;
      late _Node deleter;
      late _Node claimant;
      late Person parent;
      late UniqueCascadeChild child;

      setUp(() async {
        server = await node(testSession);
        author = await node(await createAdditionalTestSession());
        deleter = await node(await createAdditionalTestSession());
        claimant = await node(await createAdditionalTestSession());

        // A person every node knows.
        parent = Person(id: const Uuid().v7obj(), name: 'parent');
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(author.crdt, parent, transaction: tx);
        });
        await syncWithServer(author, server);
        for (final peer in [deleter, claimant]) {
          await syncWithServer(peer, server);
        }

        // The person is deleted while the author is offline. It has no children
        // yet, so this delete releases nothing on any node.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(deleter.crdt, parent, transaction: tx);
        });
        await syncWithServer(deleter, server);

        // Unaware, the author adds a child of that person holding the contested
        // name. Merging the insert hides the child by cascade, because its
        // parent is already hidden - a route that never runs the local delete
        // path, and so never releases the name.
        child = UniqueCascadeChild(
          id: const Uuid().v7obj(),
          name: 'taken',
          parentId: parent.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueCascadeChild.db.insertRow(
            author.crdt,
            child,
            transaction: tx,
          );
        });
        await syncWithServer(author, server);
      });

      test('then the child is hidden on every node that saw it.', () async {
        await syncWithServer(deleter, server);

        final expected = 'hidden taken__hidden__${child.id!.uuid}';
        expect(await render(server), expected, reason: 'server');
        expect(await render(author), expected, reason: 'author');
        expect(await render(deleter), expected, reason: 'deleter');
      });

      group('when a client that never saw that child claims the name,', () {
        late Object? claimError;

        setUp(() async {
          // The claimant has not synced since before the child existed, so its
          // own database has nothing holding the name and the local write is
          // accepted.
          final reclaim = UniqueCascadeChild(
            id: const Uuid().v7obj(),
            name: 'taken',
          );
          await claimant.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
            await UniqueCascadeChild.db.insertRow(
              claimant.crdt,
              reclaim,
              transaction: tx,
            );
          });

          try {
            await syncWithServer(claimant, server);
            claimError = null;
          } on Object catch (error) {
            claimError = error;
          }
        });

        test('then the merge is resolved rather than failing the batch.', () {
          expect(claimError, isNull);
        });

        test('then all nodes agree after syncing.', () async {
          for (final peer in [author, deleter, claimant]) {
            await syncWithServer(peer, server);
          }
          final expected = await render(server);

          expect(await render(author), expected, reason: 'author');
          expect(await render(deleter), expected, reason: 'deleter');
          expect(await render(claimant), expected, reason: 'claimant');
        });
      });

      group('when a client that already holds the hidden child claims the name,', () {
        late Object? claimError;

        setUp(() async {
          await syncWithServer(claimant, server);

          final reclaim = UniqueCascadeChild(
            id: const Uuid().v7obj(),
            name: 'taken',
          );
          try {
            await claimant.crdt.db.transactionForUser(testCrdtUserId, (
              tx,
            ) async {
              await UniqueCascadeChild.db.insertRow(
                claimant.crdt,
                reclaim,
                transaction: tx,
              );
            });
            claimError = null;
          } on Object catch (error) {
            claimError = error;
          }
        });

        test('then the local write is resolved rather than rejected.', () {
          expect(claimError, isNull);
        });
      });
    },
  );
}
