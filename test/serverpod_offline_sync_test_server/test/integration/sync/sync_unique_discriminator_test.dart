import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  test(
    'Given two rows with the same name in different categories, '
    'when their categories are swapped in a local batch, '
    'then both retain their names and acquire the opposite categories.',
    () async {
      final first = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 1,
        name: 'shared',
      );
      final second = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 2,
        name: 'shared',
      );
      await session.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.insert(session, [first, second], transaction: tx);
      });

      await session.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.update(
          session,
          [first.copyWith(categoryId: 2), second.copyWith(categoryId: 1)],
          columns: (t) => [t.categoryId],
          transaction: tx,
        );
      });

      final rows = await UniqueDiscriminator.db.find(session);
      expect(
        {for (final row in rows) row.id: (row.categoryId, row.name)},
        {
          first.id: (2, 'shared'),
          second.id: (1, 'shared'),
        },
      );
    },
  );

  test(
    'Given replicated rows whose categories were swapped through an unused category offline, '
    'when their latest category updates synchronize together, '
    'then both replicas retain the original names with the swapped categories.',
    () async {
      final source = await syncNode(testSession, testSyncTables);
      final target = await syncNode(
        await createAdditionalTestSession(),
        testSyncTables,
      );
      final first = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 1,
        name: 'shared',
      );
      final second = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 2,
        name: 'shared',
      );
      await source.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.insert(source.crdt, [
          first,
          second,
        ], transaction: tx);
      });
      await syncWithServer(source, target);
      await source.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.updateRow(
          source.crdt,
          first.copyWith(categoryId: 3),
          columns: (t) => [t.categoryId],
          transaction: tx,
        );
      });
      await source.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.updateRow(
          source.crdt,
          second.copyWith(categoryId: 1),
          columns: (t) => [t.categoryId],
          transaction: tx,
        );
      });
      await source.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.updateRow(
          source.crdt,
          first.copyWith(categoryId: 2),
          columns: (t) => [t.categoryId],
          transaction: tx,
        );
      });

      await syncWithServer(source, target);

      final sourceRows = await UniqueDiscriminator.db.find(source.crdt);
      final targetRows = await UniqueDiscriminator.db.find(target.crdt);
      expect(
        {for (final row in sourceRows) row.id: (row.categoryId, row.name)},
        {
          first.id: (2, 'shared'),
          second.id: (1, 'shared'),
        },
      );
      expect(
        {for (final row in targetRows) row.id: (row.categoryId, row.name)},
        {
          first.id: (2, 'shared'),
          second.id: (1, 'shared'),
        },
      );
    },
  );
}
