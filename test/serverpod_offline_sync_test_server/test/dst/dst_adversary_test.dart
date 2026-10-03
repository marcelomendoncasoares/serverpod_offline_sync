import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_adversary.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  test(
    'Given two replicas and a schedule repeatedly redelivering one city insertion, '
    'when the network drains after those duplicate deliveries, '
    'then stable authored facts converge without a false non-idempotence failure.',
    () async {
      final ids = DstIds(DstRandom(916));
      final space = ids.next();
      final clock = DstClock();
      final replicas = <DstReplica>[];
      for (var index = 0; index < 2; index++) {
        replicas.add(
          await DstReplica.create(
            name: 'r$index',
            spaceUuids: [space],
            nodeUuid: ids.next(),
            clock: clock.clock,
          ),
        );
      }
      final author = replicas.first;
      await author.withReplicaClock(
        () => author.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(
            author.session,
            City(id: ids.next(), name: 'city'),
            transaction: tx,
          ),
        ),
      );
      final expected = (await DstSnapshot.capture(author)).renderSpace(space);
      final adversary = DstAdversary(_RepeatedDeliverySchedule(), replicas);
      Future<void> check(DstReplica replica) async {
        expect(DstOracle.invariants(await DstSnapshot.capture(replica)), isEmpty);
      }

      await adversary.step(check);
      await adversary.step(check);
      expect(adversary.duplicateBatches, greaterThan(0));
      await adversary.quiesce(check);

      for (final replica in replicas) {
        expect((await DstSnapshot.capture(replica)).renderSpace(space), expected);
      }
    },
  );

  group('Given a delta receiver isolated while a parent and child are authored,', () {
    final ids = DstIds(DstRandom(917));
    final space = ids.next();
    final clock = DstClock();
    late DstReplica source;
    late DstReplica target;
    late DstAdversary adversary;
    late City parent;
    late List<String> initialCheckpoints;

    setUpAll(() async {
      source = await DstReplica.create(
        name: 'source',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      target = await DstReplica.create(
        name: 'target',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      initialCheckpoints = (await target.checkpoints(
        space,
      )).map((hlc) => hlc.toString()).toList();
      adversary = DstAdversary(_DelayedNewestFirstSchedule(), [
        source,
        target,
      ], delivery: DstDeliveryMode.delta);
      parent = City(id: ids.next(), name: 'parent');
    });

    group('when complete batches queue and the newest one arrives first,', () {
      late List<String> queuedCheckpoints;
      late String expected;
      final observed = <String>[];
      late CrdtMergeSet caughtUp;

      setUpAll(() async {
        Future<void> observe(DstReplica replica) async {
          if (identical(replica, target)) {
            observed.add((await DstSnapshot.capture(replica)).renderSpace(space));
          }
        }

        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await City.db.insertRow(source.session, parent, transaction: tx);
          }),
        );
        await adversary.step(observe);
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await Town.db.insertRow(
              source.session,
              Town(id: ids.next(), name: 'child', cityId: parent.id),
              transaction: tx,
            );
          }),
        );
        await adversary.step(observe);
        queuedCheckpoints = (await target.checkpoints(
          space,
        )).map((hlc) => hlc.toString()).toList();
        expected = (await DstSnapshot.capture(source)).renderSpace(space);
        adversary.phase = DstNetworkPhase.drain;
        await adversary.quiesce(observe);
        caughtUp = await source.collect(
          space,
          checkpoints: await target.checkpoints(space),
        );
      });

      test(
        'then queuing advances no checkpoint and every delivered snapshot retains the child.',
        () {
          expect(queuedCheckpoints, initialCheckpoints);
          expect(observed, hasLength(greaterThanOrEqualTo(3)));
          expect(observed, everyElement(expected));
          expect(caughtUp, isEmpty);
          expect(adversary.metrics['scheduled.merges'], isNull);
          expect(adversary.metrics['drain.merges'], greaterThanOrEqualTo(3));
        },
      );
    });
  });

  group(
    'Given a captured insertion batch and a delta adversary that requests replays,',
    () {
      final ids = DstIds(DstRandom(918));
      final space = ids.next();
      final clock = DstClock();
      late DstReplica source;
      late DstReplica target;
      late City row;
      late DstDelivery captured;
      late CrdtMergeSet original;
      late DstAdversary adversary;

      setUpAll(() async {
        source = await DstReplica.create(
          name: 'source',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: clock.clock,
        );
        target = await DstReplica.create(
          name: 'target',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: clock.clock,
        );
        row = City(id: ids.next(), name: 'original');
        await source.withReplicaClock(
          () => source.session.db.transactionForUser(space, (tx) async {
            await City.db.insertRow(source.session, row, transaction: tx);
          }),
        );
        original = await source.collect(space);
        captured = DstDelivery(
          source: source,
          target: target,
          spaceUuid: space,
          changes: original,
        );
        adversary = DstAdversary(_RepeatedDeliverySchedule(), [
          source,
          target,
        ], delivery: DstDeliveryMode.delta)..phase = DstNetworkPhase.setup;
        await adversary.quiesce((_) async {});
      });

      group('when the source changes and repeated partial deliveries drain,', () {
        late String actual;
        late String expected;
        late String frozenName;
        late String mutatedName;
        late int partialBeforeDrain;

        setUpAll(() async {
          (original.single as CrdtMergeInsert).data = row.copyWith(
            name: 'mutated input',
          );
          final decoded = captured.changes.single as CrdtMergeInsert
            ..data = row.copyWith(name: 'mutated decoded copy');
          mutatedName = decoded.databaseColumns['name']! as String;
          frozenName =
              (captured.changes.single as CrdtMergeInsert).databaseColumns['name']!
                  as String;
          await source.withReplicaClock(
            () => source.session.db.transactionForUser(space, (tx) async {
              await City.db.updateRow(
                source.session,
                row.copyWith(name: 'changed'),
                columns: (t) => [t.name],
                transaction: tx,
              );
            }),
          );
          adversary.phase = DstNetworkPhase.scheduled;
          await adversary.step((_) async {});
          await adversary.step((_) async {});
          partialBeforeDrain = adversary.scheduledPartialBatches;
          adversary.phase = DstNetworkPhase.drain;
          await adversary.quiesce((_) async {});
          actual = (await DstSnapshot.capture(target)).renderSpace(space);
          expected = (await DstSnapshot.capture(source)).renderSpace(space);
        });

        test(
          'then the captured payload is immutable and scheduled partial merges survive exact replays.',
          () {
            expect(mutatedName, 'mutated decoded copy');
            expect(frozenName, 'original');
            expect(actual, expected);
            expect(partialBeforeDrain, greaterThan(0));
            expect(adversary.scheduledPartialBatches, partialBeforeDrain);
            expect(adversary.metrics['explicitReplays'], greaterThan(0));
            expect(adversary.metrics['emptyCollections'], greaterThan(0));
            expect(adversary.metrics['setup.partialBatches'], isNull);
          },
        );
      });
    },
  );
}

/// A concrete network schedule: always collect the first replica, always
/// choose resend, and never isolate delivery. Database/merge paths stay real.
class _RepeatedDeliverySchedule extends DstRandom {
  _RepeatedDeliverySchedule() : super(916);

  @override
  bool chance(double probability) => switch (probability) {
    DstAdversary.receiveIsolationProbability => false,
    DstAdversary.collectionProbability || DstAdversary.resendProbability => true,
    _ => throw StateError('Unspecified network decision with probability $probability'),
  };

  @override
  T pick<T>(List<T> items) => items.first;
}

/// Isolate the target at each step, collect from the source, and drain newest
/// batches first. Every queued collection must use committed receiver progress.
class _DelayedNewestFirstSchedule extends DstRandom {
  _DelayedNewestFirstSchedule() : super(917);

  bool _selectingPartition = false;

  @override
  bool chance(double probability) {
    if (probability == DstAdversary.receiveIsolationProbability) {
      _selectingPartition = true;
      return true;
    }
    return probability == DstAdversary.collectionProbability;
  }

  @override
  int between(int min, int max) => max;

  @override
  T pick<T>(List<T> items) {
    if (_selectingPartition) {
      _selectingPartition = false;
      return items.last;
    }
    return items.first is DstDelivery ? items.last : items.first;
  }
}
