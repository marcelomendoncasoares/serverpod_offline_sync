import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession();

  test(
    'Given a deleted unique claimant and a newer claimant of the same name, '
    'when the DST restores the deleted identity, '
    'then the renewed claim yields the name to its earlier peer.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final original = Unique(id: ids.next(), name: 'shared');
      final peer = Unique(id: ids.next(), name: 'shared');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Unique.db.insertRow(replica.session, original, transaction: tx);
        }),
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Unique.db.deleteRow(replica.session, original, transaction: tx);
          await Unique.db.insertRow(replica.session, peer, transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.unique,
        action: _action('restore'),
      );

      expect(outcome, DstOperationOutcome.applied);
      final restored = await Unique.db.findById(replica.session, original.id!);
      final other = await Unique.db.findById(replica.session, peer.id!);
      expect(restored?.name, 'shared__conflict__${original.id}');
      expect(other?.name, 'shared');
      final snapshot = await DstSnapshot.capture(replica);
      expect(snapshot.authoredValue(('unique', original.id!, 'name')), 'shared');
      expect(
        snapshot.fieldHlc(('unique', original.id!, 'name')),
        snapshot.rowHlcs['unique/${original.id}'],
      );
    },
  );

  test(
    'Given an empty city table, '
    'when the DST inserts a batch, '
    'then two distinct city identities are authored.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('insertBatch'),
      );

      expect(outcome, DstOperationOutcome.applied);
      final rows = await City.db.find(replica.session);
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.id).toSet(), hasLength(2));
    },
  );

  test(
    'Given two visible cities with their original names, '
    'when the DST updates a batch, '
    'then both city identities remain and have new names.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final first = City(id: ids.next(), name: 'original-first');
      final second = City(id: ids.next(), name: 'original-second');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insert(replica.session, [first, second], transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('updateBatch'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(
        (await City.db.findById(replica.session, first.id!))!.name,
        isNot(first.name),
      );
      expect(
        (await City.db.findById(replica.session, second.id!))!.name,
        isNot(second.name),
      );
      expect(await City.db.find(replica.session), hasLength(2));
    },
  );

  test(
    'Given two visible cities with their original names, '
    'when the DST updates both rows through a predicate, '
    'then both city identities remain and have new names.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final first = City(id: ids.next(), name: 'original-first');
      final second = City(id: ids.next(), name: 'original-second');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insert(replica.session, [first, second], transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('updateWhere'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(
        (await City.db.findById(replica.session, first.id!))!.name,
        isNot(first.name),
      );
      expect(
        (await City.db.findById(replica.session, second.id!))!.name,
        isNot(second.name),
      );
      expect(await City.db.find(replica.session), hasLength(2));
    },
  );

  test(
    'Given two visible cities, '
    'when the DST deletes a batch, '
    'then both cities become hidden while their physical rows remain.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final first = City(id: ids.next(), name: 'first');
      final second = City(id: ids.next(), name: 'second');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insert(replica.session, [first, second], transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('deleteBatch'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(await City.db.find(replica.session), isEmpty);
      final hidden = await City.db.find(
        replica.session,
        where: (t) => t.includeHiddenRows,
      );
      expect(hidden.map((row) => row.id).toSet(), {first.id, second.id});
    },
  );

  test(
    'Given two visible cities, '
    'when the DST deletes both rows through a predicate, '
    'then both cities become hidden while their physical rows remain.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final first = City(id: ids.next(), name: 'first');
      final second = City(id: ids.next(), name: 'second');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insert(replica.session, [first, second], transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('deleteWhere'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(await City.db.find(replica.session), isEmpty);
      final hidden = await City.db.find(
        replica.session,
        where: (t) => t.includeHiddenRows,
      );
      expect(hidden.map((row) => row.id).toSet(), {first.id, second.id});
    },
  );

  test(
    'Given two visible unique rows claiming different names, '
    'when the DST swaps their unique tuples in one update, '
    'then each identity holds the other name.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final first = Unique(id: ids.next(), name: 'alice');
      final second = Unique(id: ids.next(), name: 'bob');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Unique.db.insert(replica.session, [first, second], transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.unique,
        action: _action('swapUnique'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect((await Unique.db.findById(replica.session, first.id!))!.name, 'bob');
      expect((await Unique.db.findById(replica.session, second.id!))!.name, 'alice');
    },
  );

  test(
    'Given an existing city, '
    'when the DST upserts that identity, '
    'then its name changes without creating another row.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final city = City(id: ids.next(), name: 'original');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(replica.session, city, transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('upsert'),
      );

      expect(outcome, DstOperationOutcome.applied);
      final rows = await City.db.find(replica.session);
      expect(rows, hasLength(1));
      expect(rows.single.id, city.id);
      expect(rows.single.name, isNot(city.name));
    },
  );

  test(
    'Given an empty city table, '
    'when the DST upserts a new identity, '
    'then a visible city is authored.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('upsert'),
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(await City.db.find(replica.session), hasLength(1));
    },
  );

  test(
    'Given a deleted city, '
    'when the DST upserts its identity, '
    'then that same city becomes visible again.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final city = City(id: ids.next(), name: 'original');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(replica.session, city, transaction: tx);
        }),
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await City.db.deleteRow(replica.session, city, transaction: tx);
        }),
      );

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: _action('upsert'),
      );

      expect(outcome, DstOperationOutcome.applied);
      final rows = await City.db.find(replica.session);
      expect(rows, hasLength(1));
      expect(rows.single.id, city.id);
    },
  );

  test(
    'Given a town with a set-null projection after a remote mayor deletion, '
    'when the DST performs a full-row update of an unrelated field, '
    'then the town changes name while preserving the authored mayor in its export.',
    () async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, space);
      final operations = DstOperations(random, ids);
      final source = await _replica(ids, space);
      final mayor = Person(id: ids.next(), name: 'mayor');
      final town = Town(id: ids.next(), name: 'original-town', mayorId: mayor.id);
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Person.db.insertRow(source.session, mayor, transaction: tx);
        }),
      );
      await replica.merge(await source.collect(space), space);
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Town.db.insertRow(replica.session, town, transaction: tx);
        }),
      );
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Person.db.deleteRow(source.session, mayor, transaction: tx);
        }),
      );
      await replica.merge(await source.collect(space), space);

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.town,
        action: _action('fullRowUpdate'),
      );

      expect(outcome, DstOperationOutcome.applied);
      final visible = (await Town.db.findById(replica.session, town.id!))!;
      expect(visible.name, isNot(town.name));
      expect(visible.mayorId, isNull);
      final changes = await replica.collect(space);
      final insert = changes.whereType<CrdtMergeInsert>().singleWhere(
        (change) => change.uuidRowId == town.id,
      );
      expect((insert.data as Town).mayorId, mayor.id);
    },
  );

  for (final defaultLocation in ['missing', 'another space', 'the acting space']) {
    final defaultDescription = defaultLocation == 'missing'
        ? 'no default target'
        : 'a default target in $defaultLocation';
    test(
      'Given a detached defaulted FK with a local parent and $defaultDescription, '
      'when the DST upserts an unrelated field, '
      'then the submitted reference resolves to a visible parent in the acting space.',
      () async {
        final ids = DstIds(DstRandom(910));
        final space = ids.next();
        final otherSpace = ids.next();
        final replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space, otherSpace],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        if (defaultLocation != 'missing') {
          await replica.seedDefaultTown(
            defaultLocation == 'the acting space' ? space : otherSpace,
          );
        }
        final parent = Town(id: ids.next(), name: 'available-parent');
        final child = UniqueSetDefaultChild(
          id: ids.next(),
          name: 'original',
          parentId: parent.id,
        );
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(space, (tx) async {
            await Town.db.insertRow(replica.session, parent, transaction: tx);
            await UniqueSetDefaultChild.db.insertRow(
              replica.session,
              child,
              transaction: tx,
            );
            await UniqueSetDefaultChild.db.updateRow(
              replica.session,
              child.copyWith(parentId: null),
              columns: (t) => [t.parentId],
              transaction: tx,
            );
          }),
        );
        // This seed changes only name, leaving the full-row upsert to apply
        // the unchanged null FK's persisted default.
        final operations = DstOperations(DstRandom(5), ids);

        final outcome = await operations.apply(
          replica,
          space,
          table: DstTable.uniqueSetDefaultChild,
          action: DstAction.upsert,
        );

        expect(outcome, DstOperationOutcome.applied);
        final updated = (await UniqueSetDefaultChild.db.findById(
          replica.session,
          child.id!,
        ))!;
        expect(updated.name, isNot(child.name));
        expect(
          updated.parentId,
          defaultLocation == 'the acting space' ? dstDefaultTownId : parent.id,
        );
        expect(operations.rejections, isEmpty);
      },
    );
  }

  test(
    'Given a detached defaulted FK with no visible parent or default target, '
    'when the DST tries to upsert an unrelated field, '
    'then it skips the unavailable reference without changing authored facts.',
    () async {
      final ids = DstIds(DstRandom(910));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final parent = Town(id: ids.next(), name: 'removed-parent');
      final child = UniqueSetDefaultChild(
        id: ids.next(),
        name: 'original',
        parentId: parent.id,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Town.db.insertRow(replica.session, parent, transaction: tx);
          await UniqueSetDefaultChild.db.insertRow(
            replica.session,
            child,
            transaction: tx,
          );
          await UniqueSetDefaultChild.db.updateRow(
            replica.session,
            child.copyWith(parentId: null),
            columns: (t) => [t.parentId],
            transaction: tx,
          );
          await Town.db.deleteRow(replica.session, parent, transaction: tx);
        }),
      );
      final before = (await replica.collect(space)).map(dstChangeKey).toSet();
      final operations = DstOperations(DstRandom(5), ids);

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.uniqueSetDefaultChild,
        action: DstAction.upsert,
      );

      expect(outcome, DstOperationOutcome.skipped);
      expect((await replica.collect(space)).map(dstChangeKey).toSet(), before);
      final retained = (await UniqueSetDefaultChild.db.findById(
        replica.session,
        child.id!,
      ))!;
      expect(retained.name, child.name);
      expect(retained.parentId, isNull);
    },
  );
}

DstAction _action(String name) =>
    DstAction.values.singleWhere((action) => action.name == name);

Future<DstReplica> _replica(DstIds ids, UuidValue space) => DstReplica.create(
  name: 'replica',
  spaceUuids: [space],
  nodeUuid: ids.next(),
  clock: DstClock().clock,
);
