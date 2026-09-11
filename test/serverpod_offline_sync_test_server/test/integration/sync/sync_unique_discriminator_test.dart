import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given two rows with the same name in different categories,', () {
    late SyncNode node;
    late UniqueDiscriminator first;
    late UniqueDiscriminator second;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      first = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 1,
        name: 'shared',
      );
      second = UniqueDiscriminator(
        id: const Uuid().v7obj(),
        categoryId: 2,
        name: 'shared',
      );
      await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
        await UniqueDiscriminator.db.insert(node.crdt, [
          first,
          second,
        ], transaction: tx);
      });
    });

    group('when swapping their categories in a local batch,', () {
      late List<UniqueDiscriminator> nodeRows;

      setUpAll(() async {
        await node.crdt.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueDiscriminator.db.update(
            node.crdt,
            [first.copyWith(categoryId: 2), second.copyWith(categoryId: 1)],
            columns: (t) => [t.categoryId],
            transaction: tx,
          );
        });

        nodeRows = await UniqueDiscriminator.db.find(node.crdt);
      });

      test('then the local rows retain their names with swapped categories.', () {
        expect(
          {for (final row in nodeRows) row.id: (row.categoryId, row.name)},
          {first.id: (2, 'shared'), second.id: (1, 'shared')},
        );
      });
    });
  });

  group(
    'Given replicated rows whose categories were swapped through an unused category offline,',
    () {
      late SyncNode source;
      late SyncNode target;
      late UniqueDiscriminator first;
      late UniqueDiscriminator second;

      setUpAll(() async {
        source = await syncNode(await createAdditionalTestSession(), testSyncTables);
        target = await syncNode(await createAdditionalTestSession(), testSyncTables);
        first = UniqueDiscriminator(
          id: const Uuid().v7obj(),
          categoryId: 1,
          name: 'shared',
        );
        second = UniqueDiscriminator(
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
      });

      group('when synchronizing their latest category updates together,', () {
        late List<UniqueDiscriminator> sourceRows;
        late List<UniqueDiscriminator> targetRows;

        setUpAll(() async {
          await syncWithServer(source, target);

          sourceRows = await UniqueDiscriminator.db.find(source.crdt);
          targetRows = await UniqueDiscriminator.db.find(target.crdt);
        });

        test('then the source rows retain their names with swapped categories.', () {
          expect(
            {for (final row in sourceRows) row.id: (row.categoryId, row.name)},
            {first.id: (2, 'shared'), second.id: (1, 'shared')},
          );
        });

        test('then the target rows retain their names with swapped categories.', () {
          expect(
            {for (final row in targetRows) row.id: (row.categoryId, row.name)},
            {first.id: (2, 'shared'), second.id: (1, 'shared')},
          );
        });
      });
    },
  );
}
