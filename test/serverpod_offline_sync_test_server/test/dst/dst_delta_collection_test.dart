import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a city already acknowledged by a receiver,', () {
    final ids = DstIds(DstRandom(420));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica target;
    late DstReplica reference;
    late City city;

    setUpAll(() async {
      source = await _replica('source', [space], ids, clock);
      target = await _replica('target', [space], ids, clock);
      reference = await _replica('reference', [space], ids, clock);
      city = City(id: ids.next(), name: 'initial');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(source.session, city, transaction: tx);
        }),
      );
      await target.merge(await source.collect(space), space);
      await reference.merge(await source.collect(space), space);
    });

    group('when its name changes and later the city is deleted,', () {
      late CrdtMergeSet update;
      late CrdtMergeSet deletion;
      late CrdtMergeSet caughtUp;
      late String updatedTarget;
      late String updatedReference;
      late String deletedTarget;
      late String deletedReference;
      late String replayedTarget;

      setUpAll(() async {
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await City.db.updateRow(
              source.session,
              city.copyWith(name: 'changed'),
              columns: (t) => [t.name],
              transaction: tx,
            );
          }),
        );
        update = await source.collect(
          space,
          checkpoints: await target.checkpoints(space),
        );
        await target.merge(update, space);
        await reference.merge(await source.collect(space), space);
        updatedTarget = (await DstSnapshot.capture(target)).renderSpace(space);
        updatedReference = (await DstSnapshot.capture(reference)).renderSpace(space);

        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await City.db.deleteRow(source.session, city, transaction: tx);
          }),
        );
        deletion = await source.collect(
          space,
          checkpoints: await target.checkpoints(space),
        );
        await target.merge(deletion, space);
        await reference.merge(await source.collect(space), space);
        deletedTarget = (await DstSnapshot.capture(target)).renderSpace(space);
        deletedReference = (await DstSnapshot.capture(reference)).renderSpace(space);
        await target.merge(update, space);
        await target.merge(deletion, space);
        replayedTarget = (await DstSnapshot.capture(target)).renderSpace(space);
        caughtUp = await source.collect(
          space,
          checkpoints: await target.checkpoints(space),
        );
      });

      test('then the update batch omits the acknowledged insertion.', () {
        expect(update, hasLength(1));
        expect(update.single, isA<CrdtMergeUpdate>());
        expect((update.single as CrdtMergeUpdate).value, 'changed');
        expect(updatedTarget, updatedReference);
      });

      test('then the deletion batch contains only the new tombstone.', () {
        expect(deletion, hasLength(1));
        expect(deletion.single, isA<CrdtMergeDelete>());
        expect(deletedTarget, deletedReference);
        expect(deletedTarget, contains('HIDDEN'));
      });

      test('then replay changes neither the final state nor the empty catch-up.', () {
        expect(replayedTarget, deletedTarget);
        expect(caughtUp, isEmpty);
      });
    });
  });

  group('Given one author writing cities in two spaces,', () {
    final ids = DstIds(DstRandom(421));
    final clock = DstClock();
    final firstSpace = ids.next();
    final secondSpace = ids.next();
    late DstReplica source;
    late DstReplica target;

    setUpAll(() async {
      source = await _replica('source', [firstSpace, secondSpace], ids, clock);
      target = await _replica('target', [firstSpace, secondSpace], ids, clock);
      for (final space in [firstSpace, secondSpace]) {
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await City.db.insertRow(
              source.session,
              City(id: ids.next(), name: space.toString()),
              transaction: tx,
            );
          }),
        );
      }
    });

    group('when only the second space is acknowledged,', () {
      late CrdtMergeSet firstPending;
      late CrdtMergeSet secondPending;

      setUpAll(() async {
        await target.merge(await source.collect(secondSpace), secondSpace);
        firstPending = await source.collect(
          firstSpace,
          checkpoints: await target.checkpoints(firstSpace),
        );
        secondPending = await source.collect(
          secondSpace,
          checkpoints: await target.checkpoints(secondSpace),
        );
      });

      test('then the earlier first-space insertion is still pending.', () {
        expect(firstPending, hasLength(1));
        expect(firstPending.single.uuidSpaceId, firstSpace);
        expect(secondPending, isEmpty);
      });
    });
  });

  group('Given a relay with a newer fact from one author,', () {
    final ids = DstIds(DstRandom(422));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica older;
    late DstReplica newer;
    late DstReplica relay;
    late DstReplica target;
    late UuidValue olderRow;

    setUpAll(() async {
      older = await _replica('older', [space], ids, clock);
      newer = await _replica('newer', [space], ids, clock);
      relay = await _replica('relay', [space], ids, clock);
      target = await _replica('target', [space], ids, clock);
      olderRow = ids.next();
      await older.withReplicaClock(
        () => older.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(
            older.session,
            City(id: olderRow, name: 'older offline fact'),
            transaction: tx,
          );
        }),
      );
      clock.advance(const Duration(seconds: 1));
      await newer.withReplicaClock(
        () => newer.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(
            newer.session,
            City(id: ids.next(), name: 'newer fact'),
            transaction: tx,
          );
        }),
      );
      await relay.merge(await newer.collect(space), space);
      await target.merge(await relay.collect(space), space);
    });

    group('when the older author reconnects through the relay,', () {
      late CrdtMergeSet pending;
      late String actual;
      late String expected;

      setUpAll(() async {
        await relay.merge(await older.collect(space), space);
        pending = await relay.collect(
          space,
          checkpoints: await target.checkpoints(space),
        );
        await target.merge(pending, space);
        actual = (await DstSnapshot.capture(target)).renderSpace(space);
        expected = (await DstSnapshot.capture(relay)).renderSpace(space);
      });

      test(
        'then the older fact crosses both hops without resending the newer fact.',
        () {
          expect(pending, hasLength(1));
          expect(pending.single.uuidRowId, olderRow);
          expect(pending.single.uuidNodeId, older.nodeUuid);
          expect(actual, expected);
        },
      );
    });
  });

  group('Given a receiver that already holds a parent city,', () {
    final ids = DstIds(DstRandom(423));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica target;
    late City parent;

    setUpAll(() async {
      source = await _replica('source', [space], ids, clock);
      target = await _replica('target', [space], ids, clock);
      parent = City(id: ids.next(), name: 'parent');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(source.session, parent, transaction: tx);
        }),
      );
      await target.merge(await source.collect(space), space);
    });

    group(
      'when a child arrives alone followed by a new parent and child together,',
      () {
        late CrdtMergeSet childOnly;
        late CrdtMergeSet together;
        late DstSnapshot actual;
        late DstSnapshot expected;

        setUpAll(() async {
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(space, (tx) async {
              await Town.db.insertRow(
                source.session,
                Town(id: ids.next(), name: 'first child', cityId: parent.id),
                transaction: tx,
              );
            }),
          );
          childOnly = await source.collect(
            space,
            checkpoints: await target.checkpoints(space),
          );
          await target.merge(childOnly, space);
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(space, (tx) async {
              final nextParent = await City.db.insertRow(
                source.session,
                City(id: ids.next(), name: 'second parent'),
                transaction: tx,
              );
              await Town.db.insertRow(
                source.session,
                Town(id: ids.next(), name: 'second child', cityId: nextParent.id),
                transaction: tx,
              );
            }),
          );
          together = await source.collect(
            space,
            checkpoints: await target.checkpoints(space),
          );
          await target.merge(together, space);
          actual = await DstSnapshot.capture(target);
          expected = await DstSnapshot.capture(source);
        });

        test('then each partial batch retains exactly the needed new facts.', () {
          expect(childOnly, hasLength(1));
          expect(childOnly.single.tableName, 'town');
          expect(together, hasLength(2));
          expect(
            together.map((change) => change.tableName),
            unorderedEquals(['city', 'town']),
          );
          expect(actual.renderSpace(space), expected.renderSpace(space));
          expect(DstOracle.invariants(actual), isEmpty);
        });
      },
    );
  });

  group('Given two disconnected replicas claiming the same unique name,', () {
    final ids = DstIds(DstRandom(424));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica other;
    late DstReplica delta;
    late DstReplica full;
    late Unique row;

    setUpAll(() async {
      source = await _replica('source', [space], ids, clock);
      other = await _replica('other', [space], ids, clock);
      delta = await _replica('delta', [space], ids, clock);
      full = await _replica('full', [space], ids, clock);
      row = Unique(id: ids.next(), name: 'claim');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await Unique.db.insertRow(source.session, row, transaction: tx);
        }),
      );
      clock.advance(const Duration(milliseconds: 1));
      await other.withReplicaClock(
        () => other.session.db.transactionForUser(space, (tx) async {
          await Unique.db.insertRow(
            other.session,
            Unique(id: ids.next(), name: 'claim'),
            transaction: tx,
          );
        }),
      );
      for (final receiver in [delta, full]) {
        await receiver.merge(await source.collect(space), space);
        await receiver.merge(await other.collect(space), space);
      }
    });

    group('when one claim is deleted, restored, and deleted again through deltas,', () {
      final batches = <CrdtMergeSet>[];
      final actual = <String>[];
      final expected = <String>[];
      late DstSnapshot finalSnapshot;

      setUpAll(() async {
        // Each transition is a real local transaction with a complete collection
        // boundary; only the delta receiver omits already acknowledged facts.
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Unique.db.deleteRow(source.session, row, transaction: tx);
          }),
        );
        Future<void> deliver() async {
          final batch = await source.collect(
            space,
            checkpoints: await delta.checkpoints(space),
          );
          batches.add(batch);
          await delta.merge(batch, space);
          await full.merge(await source.collect(space), space);
          actual.add((await DstSnapshot.capture(delta)).renderSpace(space));
          expected.add((await DstSnapshot.capture(full)).renderSpace(space));
        }

        await deliver();
        final hidden = (await DstTable.unique.model.find(
          source.session,
          includeHidden: true,
          spaceUuid: space,
        )).single;
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await source.session.db.insertRow(hidden, transaction: tx);
          }),
        );
        await deliver();
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Unique.db.deleteRow(source.session, row, transaction: tx);
          }),
        );
        await deliver();
        finalSnapshot = await DstSnapshot.capture(delta);
      });

      test('then each projection agrees with the full-history receiver.', () {
        expect(batches, hasLength(3));
        expect(batches.first.single, isA<CrdtMergeDelete>());
        expect(batches.last.single, isA<CrdtMergeDelete>());
        expect(actual, expected);
        expect(finalSnapshot.tombstones['unique/${row.id}']!.clFlag, 4);
        expect(DstOracle.invariants(finalSnapshot), isEmpty);
      });
    });
  });

  group('Given a batch that collides with a row owned by another space,', () {
    final ids = DstIds(DstRandom(425));
    final clock = DstClock();
    final owner = ids.next();
    final incoming = ids.next();
    final collisionId = ids.next();
    final innocentId = ids.next();
    late DstReplica source;
    late DstReplica target;
    late List<String> before;
    late CrdtMergeSet batch;

    setUpAll(() async {
      source = await _replica('source', [incoming], ids, clock);
      target = await _replica('target', [owner, incoming], ids, clock);
      await target.withReplicaClock(
        () => target.session.db.transactionForUser(owner, (tx) async {
          await City.db.insertRow(
            target.session,
            City(id: collisionId, name: 'owner'),
            transaction: tx,
          );
        }),
      );
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(incoming, (tx) async {
          await City.db.insertRow(
            source.session,
            City(id: innocentId, name: 'must roll back'),
            transaction: tx,
          );
          await City.db.insertRow(
            source.session,
            City(id: collisionId, name: 'collision'),
            transaction: tx,
          );
        }),
      );
      final checkpoints = await target.checkpoints(incoming);
      before = checkpoints.map((hlc) => hlc.toString()).toList();
      batch = await source.collect(incoming, checkpoints: checkpoints);
    });

    group('when the receiver rejects the complete batch,', () {
      late Object failure;
      late List<String> after;
      late CrdtMergeSet retry;
      late City? rolledBack;

      setUpAll(() async {
        failure = await target
            .merge(batch, incoming)
            .then<Object>(
              (_) => 'unexpected success',
              onError: (Object error) => error,
            );
        after = (await target.checkpoints(
          incoming,
        )).map((hlc) => hlc.toString()).toList();
        retry = await source.collect(
          incoming,
          checkpoints: await target.checkpoints(incoming),
        );
        rolledBack = await City.db.findById(target.session, innocentId);
      });

      test(
        'then no received progress or partial row survives and the entire batch remains pending.',
        () {
          expect(batch, hasLength(2));
          expect(failure, isA<OfflineSyncIntegrityViolationException>());
          expect(after, before);
          expect(rolledBack, isNull);
          expect(retry.map(dstChangeKey), batch.map(dstChangeKey));
        },
      );
    });
  });
}

Future<DstReplica> _replica(
  String name,
  List<UuidValue> spaces,
  DstIds ids,
  DstClock clock,
) => DstReplica.create(
  name: name,
  spaceUuids: spaces,
  nodeUuid: ids.next(),
  clock: clock.clock,
);
