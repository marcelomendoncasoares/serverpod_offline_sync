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
    'Given a hidden town whose set-null reference outlived the delete of the person it points at, because a restrict reference restored it,',
    () {
      late SyncNode author;

      setUp(() async {
        author = await syncNode(testSession, syncTables);
        final deleter = await syncNode(await createAdditionalTestSession(), syncTables);

        final mayor = Person(id: const Uuid().v7obj(), name: 'mayor');
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(author.crdt, mayor, transaction: tx);
        });
        await pushChanges(author, deleter);

        // The person is deleted and the author merges that, so it holds the
        // delete as a fact and hides the person.
        await deleter.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.deleteRow(deleter.crdt, mayor, transaction: tx);
        });
        await pushChanges(deleter, author);

        // A restrict reference to the hidden person makes the delete lose,
        // restoring it.
        final address = Address(
          id: const Uuid().v7obj(),
          street: 'street',
          inhabitantId: mayor.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Address.db.insertRow(author.crdt, address, transaction: tx);
        });

        // Only now, with the person visible again, is the set-null reference
        // authored - and then frozen in a hidden row.
        final town = Town(
          id: const Uuid().v7obj(),
          name: 'town',
          mayorId: mayor.id,
        );
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.insertRow(author.crdt, town, transaction: tx);
        });
        await author.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await Town.db.deleteRow(author.crdt, town, transaction: tx);
        });
      });

      group('when a node with no prior state merges the whole scope in one batch,', () {
        late SyncNode fresh;

        setUp(() async {
          fresh = await syncNode(await createAdditionalTestSession(), syncTables);
          await pushChanges(author, fresh);
        });

        test('then it agrees with the node it bootstrapped from.', () async {
          final expected = await render(author);

          expect(await render(fresh), expected);
        });
      });
    },
  );
}
