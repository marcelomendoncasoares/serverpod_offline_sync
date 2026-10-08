import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a deleted unique claimant and a newer claimant of the same name,', () {
    late UuidValue space;
    late DstReplica replica;
    late DstOperations operations;
    late Unique original;
    late Unique peer;

    setUpAll(() async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      space = ids.next();
      replica = await _replica(ids, space);
      operations = DstOperations(random, ids);
      original = Unique(id: ids.next(), name: 'shared');
      peer = Unique(id: ids.next(), name: 'shared');
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
    });

    group('when the DST restores the deleted identity,', () {
      late DstOperationOutcome outcome;
      late Unique? restored;
      late Unique? other;
      late DstSnapshot snapshot;

      setUpAll(() async {
        outcome = await operations.apply(
          replica,
          space,
          table: DstTable.unique,
          action: _action('restore'),
        );
        restored = await Unique.db.findById(replica.session, original.id!);
        other = await Unique.db.findById(replica.session, peer.id!);
        snapshot = await DstSnapshot.capture(replica);
      });

      test('then the restoration is applied.', () {
        expect(outcome, DstOperationOutcome.applied);
      });

      test('then the renewed claim yields the name to its earlier peer.', () {
        expect(restored?.name, 'shared__conflict__${original.id}');
        expect(other?.name, 'shared');
      });

      test('then the authored name is renewed at the restored row clock.', () {
        expect(snapshot.authoredValue(('unique', original.id!, 'name')), 'shared');
        expect(
          snapshot.fieldHlc(('unique', original.id!, 'name')),
          snapshot.rowHlcs['unique/${original.id}'],
        );
      });
    });
  });

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

  group('Given a town with a set-null projection after a remote mayor deletion,', () {
    late UuidValue space;
    late DstReplica replica;
    late DstOperations operations;
    late Person mayor;
    late Town town;

    setUpAll(() async {
      final random = DstRandom(4);
      final ids = DstIds(random);
      space = ids.next();
      replica = await _replica(ids, space);
      operations = DstOperations(random, ids);
      final source = await _replica(ids, space);
      mayor = Person(id: ids.next(), name: 'mayor');
      town = Town(id: ids.next(), name: 'original-town', mayorId: mayor.id);
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
    });

    group('when the DST performs a full-row update of an unrelated field,', () {
      late DstOperationOutcome outcome;
      late Town visible;
      late CrdtMergeSet changes;

      setUpAll(() async {
        outcome = await operations.apply(
          replica,
          space,
          table: DstTable.town,
          action: _action('fullRowUpdate'),
        );
        visible = (await Town.db.findById(replica.session, town.id!))!;
        changes = await replica.collect(space);
      });

      test('then the update is applied.', () {
        expect(outcome, DstOperationOutcome.applied);
      });

      test('then the town changes name and retains its projected null mayor.', () {
        expect(visible.name, isNot(town.name));
        expect(visible.mayorId, isNull);
      });

      test('then the exported insert preserves the authored mayor.', () {
        final insert = changes.whereType<CrdtMergeInsert>().singleWhere(
          (change) => change.uuidRowId == town.id,
        );
        expect((insert.data as Town).mayorId, mayor.id);
      });
    });
  });

  group('Given a detached defaulted FK with a local parent and no default target,', () {
    late UuidValue space;
    late DstReplica replica;
    late Town parent;
    late UniqueSetDefaultChild child;
    late DstOperations operations;

    setUpAll(() async {
      final ids = DstIds(DstRandom(910));
      space = ids.next();
      final otherSpace = ids.next();
      replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space, otherSpace],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      parent = Town(id: ids.next(), name: 'available-parent');
      child = UniqueSetDefaultChild(
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
      // This seed changes only the name during the full-row upsert.
      operations = DstOperations(DstRandom(5), ids);
    });

    group('when the DST upserts an unrelated field,', () {
      late DstOperationOutcome outcome;
      late UniqueSetDefaultChild updated;
      late List<String> rejections;

      setUpAll(() async {
        outcome = await operations.apply(
          replica,
          space,
          table: DstTable.uniqueSetDefaultChild,
          action: DstAction.upsert,
        );
        updated = (await UniqueSetDefaultChild.db.findById(
          replica.session,
          child.id!,
        ))!;
        rejections = List.of(operations.rejections);
      });

      test('then the upsert is applied without a rejection.', () {
        expect(outcome, DstOperationOutcome.applied);
        expect(rejections, isEmpty);
      });

      test('then the unrelated name changes.', () {
        expect(updated.name, isNot(child.name));
      });

      test('then the reference resolves to a visible parent in the acting space.', () {
        expect(updated.parentId, parent.id);
      });
    });
  });

  group(
    'Given a detached defaulted FK with a local parent and a default target in another space,',
    () {
      late UuidValue space;
      late DstReplica replica;
      late Town parent;
      late UniqueSetDefaultChild child;
      late DstOperations operations;

      setUpAll(() async {
        final ids = DstIds(DstRandom(910));
        space = ids.next();
        final otherSpace = ids.next();
        replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space, otherSpace],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        await replica.seedDefaultTown(otherSpace);
        parent = Town(id: ids.next(), name: 'available-parent');
        child = UniqueSetDefaultChild(
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
        // This seed changes only the name during the full-row upsert.
        operations = DstOperations(DstRandom(5), ids);
      });

      group('when the DST upserts an unrelated field,', () {
        late DstOperationOutcome outcome;
        late UniqueSetDefaultChild updated;
        late List<String> rejections;

        setUpAll(() async {
          outcome = await operations.apply(
            replica,
            space,
            table: DstTable.uniqueSetDefaultChild,
            action: DstAction.upsert,
          );
          updated = (await UniqueSetDefaultChild.db.findById(
            replica.session,
            child.id!,
          ))!;
          rejections = List.of(operations.rejections);
        });

        test('then the upsert is applied without a rejection.', () {
          expect(outcome, DstOperationOutcome.applied);
          expect(rejections, isEmpty);
        });

        test('then the unrelated name changes.', () {
          expect(updated.name, isNot(child.name));
        });

        test(
          'then the reference resolves to a visible parent in the acting space.',
          () {
            expect(updated.parentId, parent.id);
          },
        );
      });
    },
  );

  group(
    'Given a detached defaulted FK with a local parent and a default target in the acting space,',
    () {
      late UuidValue space;
      late DstReplica replica;
      late Town parent;
      late UniqueSetDefaultChild child;
      late DstOperations operations;

      setUpAll(() async {
        final ids = DstIds(DstRandom(910));
        space = ids.next();
        final otherSpace = ids.next();
        replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space, otherSpace],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        await replica.seedDefaultTown(space);
        parent = Town(id: ids.next(), name: 'available-parent');
        child = UniqueSetDefaultChild(
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
        // This seed changes only the name during the full-row upsert.
        operations = DstOperations(DstRandom(5), ids);
      });

      group('when the DST upserts an unrelated field,', () {
        late DstOperationOutcome outcome;
        late UniqueSetDefaultChild updated;
        late List<String> rejections;

        setUpAll(() async {
          outcome = await operations.apply(
            replica,
            space,
            table: DstTable.uniqueSetDefaultChild,
            action: DstAction.upsert,
          );
          updated = (await UniqueSetDefaultChild.db.findById(
            replica.session,
            child.id!,
          ))!;
          rejections = List.of(operations.rejections);
        });

        test('then the upsert is applied without a rejection.', () {
          expect(outcome, DstOperationOutcome.applied);
          expect(rejections, isEmpty);
        });

        test('then the unrelated name changes.', () {
          expect(updated.name, isNot(child.name));
        });

        test(
          'then the reference resolves to a visible parent in the acting space.',
          () {
            expect(updated.parentId, dstDefaultTownId);
          },
        );
      });
    },
  );

  group('Given a detached defaulted FK with no visible parent or default target,', () {
    late UuidValue space;
    late DstReplica replica;
    late UniqueSetDefaultChild child;
    late Set<String> before;
    late DstOperations operations;

    setUpAll(() async {
      final ids = DstIds(DstRandom(910));
      space = ids.next();
      replica = await _replica(ids, space);
      final parent = Town(id: ids.next(), name: 'removed-parent');
      child = UniqueSetDefaultChild(
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
      before = (await replica.collect(space)).map(dstChangeKey).toSet();
      operations = DstOperations(DstRandom(5), ids);
    });

    group('when the DST tries to upsert an unrelated field,', () {
      late DstOperationOutcome outcome;
      late Set<String> after;
      late UniqueSetDefaultChild retained;

      setUpAll(() async {
        outcome = await operations.apply(
          replica,
          space,
          table: DstTable.uniqueSetDefaultChild,
          action: DstAction.upsert,
        );
        after = (await replica.collect(space)).map(dstChangeKey).toSet();
        retained = (await UniqueSetDefaultChild.db.findById(
          replica.session,
          child.id!,
        ))!;
      });

      test('then it skips the unavailable reference.', () {
        expect(outcome, DstOperationOutcome.skipped);
      });

      test('then the authored facts remain unchanged.', () {
        expect(after, before);
      });

      test('then the child retains its name and null reference.', () {
        expect(retained.name, child.name);
        expect(retained.parentId, isNull);
      });
    });
  });
}

DstAction _action(String name) =>
    DstAction.values.singleWhere((action) => action.name == name);

Future<DstReplica> _replica(DstIds ids, UuidValue space) => DstReplica.create(
  name: 'replica',
  spaceUuids: [space],
  nodeUuid: ids.next(),
  clock: DstClock().clock,
);
