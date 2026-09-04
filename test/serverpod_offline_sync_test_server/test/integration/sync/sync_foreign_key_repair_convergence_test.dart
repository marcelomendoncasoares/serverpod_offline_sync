import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

/// Deleting a row referenced by an `onDelete=SetNull` edge clears the
/// referencing column. The repair is derived state, so every node holding the
/// same facts must reach the same result — the fixed point
/// `docs/foreign-key-invariants.md` requires.
///
/// A node that authored the referencing row while unaware of the parent's
/// delete, and tombstoned that row before learning of it, never applies the
/// repair: it keeps a reference no other node has. The row is hidden on every
/// node, so nothing is visibly wrong until it is restored or inspected through
/// `includeHiddenRows`, but the replicas have permanently different data.
///
/// The topology is strictly hub and spoke: clients exchange changes only with
/// the server, never with each other, which is how a deployed Serverpod
/// application syncs.
void main() {
  initTestClientSession();

  final syncTables = [City.t, Person.t, Town.t];

  /// Every town with its visibility and reference, ordered so nodes compare
  /// directly. Hidden rows are included because a repair that is skipped on a
  /// tombstoned row is exactly what this asserts.
  Future<String> render(SyncNode node) async {
    final towns = await Town.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visible = {for (final town in await Town.db.find(node.crdt)) town.id};
    towns.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));
    return towns
        .map((town) {
          final visibility = visible.contains(town.id) ? 'visible' : 'hidden';
          return '$visibility mayorId=${town.mayorId}';
        })
        .join(' | ');
  }

  group(
    'Given a client that authored and deleted a referencing row while unaware that the referenced row had been deleted,',
    () {
      late SyncNode server;
      late SyncNode referenceOwner;
      late SyncNode townOwner;

      setUp(() async {
        server = await syncNode(testSession, syncTables);
        referenceOwner = await syncNode(
          await createAdditionalTestSession(),
          syncTables,
        );
        townOwner = await syncNode(await createAdditionalTestSession(), syncTables);

        final mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
        await referenceOwner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(
            referenceOwner.crdt,
            mayor,
            transaction: tx,
          );
        });
        await syncWithServer(referenceOwner, server);
        await syncWithServer(townOwner, server);

        // Offline, one client deletes the referenced row.
        await referenceOwner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(
            referenceOwner.crdt,
            mayor,
            transaction: tx,
          );
        });

        // Offline and unaware of that delete, the other client creates a row
        // referencing it and then deletes that row again.
        final town = Town(
          id: const Uuid().v7obj(),
          name: 'town',
          mayorId: mayor.id,
        );
        await townOwner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(townOwner.crdt, town, transaction: tx);
        });
        await townOwner.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(townOwner.crdt, town, transaction: tx);
        });
      });

      group('when every client has synced with the server,', () {
        setUp(() async {
          for (var round = 0; round < 3; round++) {
            await syncWithServer(referenceOwner, server);
            await syncWithServer(townOwner, server);
          }
        });

        test('then all nodes agree on the referencing column.', () async {
          final expected = await render(server);

          expect(await render(referenceOwner), expected);
          expect(await render(townOwner), expected);
        });
      });
    },
  );
}
