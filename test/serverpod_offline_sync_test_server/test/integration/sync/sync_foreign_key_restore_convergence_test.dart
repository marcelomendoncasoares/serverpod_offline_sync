import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  final syncTables = [Address.t, City.t, Person.t, Town.t];

  Future<String> render(SyncNode node) async {
    final persons = await Person.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visiblePersons = {
      for (final person in await Person.db.find(node.crdt)) person.id,
    };
    persons.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));

    final towns = await Town.db.find(
      node.crdt,
      where: (t) => t.includeHiddenRows,
    );
    final visibleTowns = {
      for (final town in await Town.db.find(node.crdt)) town.id,
    };
    towns.sort((left, right) => left.id!.uuid.compareTo(right.id!.uuid));

    final renderedPersons = persons.map((person) {
      final visibility = visiblePersons.contains(person.id) ? 'visible' : 'hidden';
      return 'person $visibility';
    });
    final renderedTowns = towns.map((town) {
      final visibility = visibleTowns.contains(town.id) ? 'visible' : 'hidden';
      return 'town $visibility mayorId=${town.mayorId}';
    });
    return [...renderedPersons, ...renderedTowns].join(' | ');
  }

  group(
    'Given a deleted person restored by a restrict reference after a hidden town had its set-null reference to it repaired,',
    () {
      late SyncNode server;
      late SyncNode author;
      late SyncNode deleter;

      setUp(() async {
        server = await syncNode(testSession, syncTables);
        author = await syncNode(await createAdditionalTestSession(), syncTables);
        deleter = await syncNode(await createAdditionalTestSession(), syncTables);

        // A person every node knows.
        final mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(author.crdt, mayor, transaction: tx);
        });
        await syncWithServer(author, server);
        await syncWithServer(deleter, server);

        // One client deletes the person - the server and that client hide it.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(deleter.crdt, mayor, transaction: tx);
        });
        await syncWithServer(deleter, server);

        // Unaware of the delete, the authoring client references the person
        // from a set-null edge. Merging that insert repairs the reference to
        // null, because the person is hidden. The push is one-way so the
        // author stays unaware and can keep referencing the person.
        final town = Town(
          id: const Uuid().v7obj(),
          name: 'town',
          mayorId: mayor.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(author.crdt, town, transaction: tx);
        });
        await pushChanges(author, server);
        await syncWithServer(deleter, server);

        // The town is deleted before the restore below arrives, freezing its
        // repaired reference in a hidden row.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(deleter.crdt, town, transaction: tx);
        });
        await syncWithServer(deleter, server);

        // Still unaware, the author references the person from a restrict
        // edge. Merging it makes the person's delete lose, restoring the
        // person to visibility.
        final address = Address(
          id: const Uuid().v7obj(),
          street: 'street',
          inhabitantId: mayor.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Address.db.insertRow(author.crdt, address, transaction: tx);
        });
        await pushChanges(author, server);
      });

      group('when every client has synced with the server,', () {
        setUp(() async {
          for (var round = 0; round < 3; round++) {
            await syncWithServer(author, server);
            await syncWithServer(deleter, server);
          }
        });

        test('then all nodes agree on the referencing column.', () async {
          final expected = await render(server);

          expect(await render(author), expected);
          expect(await render(deleter), expected);
        });
      });
    },
  );
}
