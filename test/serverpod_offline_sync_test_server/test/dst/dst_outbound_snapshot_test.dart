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

  group('Given a delta peer missing a city and a source with a pending insert,', () {
    final ids = DstIds(DstRandom(165));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica target;
    late City b;

    setUpAll(() async {
      source = await _replica('source', space, ids, clock);
      target = await _replica('target', space, ids, clock);
      b = City(id: ids.next(), name: 'B0');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(source.session, b, transaction: tx),
        ),
      );
    });

    group(
      'when a mixed write starts during metadata capture and delta delivery drains,',
      () {
        late Map<String, int> metrics;
        late String expected;
        late String received;
        late List<String> names;

        setUpAll(() async {
          final adversary = DstAdversary(
            _CaptureSchedule(),
            [source, target],
            delivery: DstDeliveryMode.delta,
            onCollecting: (replica, collectedSpace) async {
              await replica.session.db.transactionForUser(collectedSpace, (tx) async {
                await City.db.insertRow(
                  replica.session,
                  City(id: ids.next(), name: 'A'),
                  transaction: tx,
                );
                await City.db.updateRow(
                  replica.session,
                  b.copyWith(name: 'B1'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
                await City.db.insertRow(
                  replica.session,
                  City(id: ids.next(), name: 'C'),
                  transaction: tx,
                );
              });
              return 1;
            },
          );

          await adversary.step((_) async {});
          adversary.phase = DstNetworkPhase.drain;
          await adversary.quiesce((_) async {});
          metrics = adversary.metrics;
          expected = (await DstSnapshot.capture(source)).renderSpace(space);
          received = (await DstSnapshot.capture(target)).renderSpace(space);
          names = (await City.db.find(target.session)).map((row) => row.name).toList()
            ..sort();
        });

        test('then every city converges without a full-history repair.', () {
          expect(names, ['A', 'B1', 'C']);
          expect(received, expected);
        });

        test('then coverage records a committed write attempted during capture.', () {
          expect(metrics['scheduled.captureInterleavings'], 1);
          expect(metrics['scheduled.captureInterleavedCommits'], 1);
          expect(metrics['collectionInterleavings'], isNull);
          expect(metrics['drain.captureInterleavings'], isNull);
          expect(metrics['fullCollections'], isNull);
        });
      },
    );
  });

  group('Given a delta peer that has not received an authored city,', () {
    final ids = DstIds(DstRandom(163));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica target;
    late City b;

    setUpAll(() async {
      source = await _replica('source', space, ids, clock);
      target = await _replica('target', space, ids, clock);
      b = City(id: ids.next(), name: 'B0');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(source.session, b, transaction: tx),
        ),
      );
    });

    group(
      'when a mixed transaction commits at the first collector yield and delta delivery drains,',
      () {
        late Map<String, int> metrics;
        late String expected;
        late String received;
        late List<String> names;
        late CrdtMergeSet remaining;

        setUpAll(() async {
          final adversary = DstAdversary(
            _FirstYieldSchedule(),
            [source, target],
            delivery: DstDeliveryMode.delta,
            onCollecting: (replica, collectedSpace) async {
              await replica.session.db.transactionForUser(collectedSpace, (tx) async {
                await City.db.insertRow(
                  replica.session,
                  City(id: ids.next(), name: 'A'),
                  transaction: tx,
                );
                await City.db.updateRow(
                  replica.session,
                  b.copyWith(name: 'B1'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
                await City.db.insertRow(
                  replica.session,
                  City(id: ids.next(), name: 'C'),
                  transaction: tx,
                );
              });
              return 1;
            },
          );

          await adversary.step((_) async {});
          adversary.phase = DstNetworkPhase.drain;
          await adversary.quiesce((_) async {});
          metrics = adversary.metrics;
          expected = (await DstSnapshot.capture(source)).renderSpace(space);
          received = (await DstSnapshot.capture(target)).renderSpace(space);
          names = (await City.db.find(target.session)).map((row) => row.name).toList()
            ..sort();
          remaining = await source.collect(
            space,
            checkpoints: await target.checkpoints(space),
          );
        });

        test('then every inserted city converges without a full-history repair.', () {
          expect(names, ['A', 'B1', 'C']);
          expect(received, expected);
          expect(remaining, isEmpty);
        });

        test(
          'then coverage records a committed interleaving during scheduled collection.',
          () {
            expect(metrics['scheduled.collectionInterleavings'], 1);
            expect(metrics['scheduled.collectionInterleavedCommits.insert'], 1);
            expect(metrics['drain.collectionInterleavings'], isNull);
            expect(metrics['fullCollections'], isNull);
          },
        );
      },
    );
  });

  group('Given synchronized cities and one unacknowledged name update,', () {
    final ids = DstIds(DstRandom(164));
    final clock = DstClock();
    final space = ids.next();
    late DstReplica source;
    late DstReplica target;
    late City b;
    late City deleted;

    setUpAll(() async {
      source = await _replica('source', space, ids, clock);
      target = await _replica('target', space, ids, clock);
      b = City(id: ids.next(), name: 'B0');
      deleted = City(id: ids.next(), name: 'deleted');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(space, (tx) async {
          await City.db.insertRow(source.session, b, transaction: tx);
          await City.db.insertRow(source.session, deleted, transaction: tx);
        }),
      );
      await target.merge(await source.collect(space), space);
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.updateRow(
            source.session,
            b.copyWith(name: 'B1'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        ),
      );
    });

    group(
      'when an update-delete transaction commits at the first collector yield and delta delivery drains,',
      () {
        late Map<String, int> metrics;
        late String expected;
        late String received;
        late List<String> names;
        late CrdtMergeSet remaining;

        setUpAll(() async {
          final adversary = DstAdversary(
            _FirstYieldSchedule(),
            [source, target],
            delivery: DstDeliveryMode.delta,
            onCollecting: (replica, collectedSpace) async {
              await replica.session.db.transactionForUser(collectedSpace, (tx) async {
                await City.db.updateRow(
                  replica.session,
                  b.copyWith(name: 'B2'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
                await City.db.deleteRow(replica.session, deleted, transaction: tx);
              });
              return 1;
            },
          );

          await adversary.step((_) async {});
          adversary.phase = DstNetworkPhase.drain;
          await adversary.quiesce((_) async {});
          metrics = adversary.metrics;
          expected = (await DstSnapshot.capture(source)).renderSpace(space);
          received = (await DstSnapshot.capture(target)).renderSpace(space);
          names = (await City.db.find(target.session)).map((row) => row.name).toList()
            ..sort();
          remaining = await source.collect(
            space,
            checkpoints: await target.checkpoints(space),
          );
        });

        test('then the latest name converges without a full-history repair.', () {
          expect(names, ['B2']);
          expect(received, expected);
          expect(remaining, isEmpty);
        });

        test('then coverage records a committed interleaving after an update.', () {
          expect(metrics['scheduled.collectionInterleavings'], 1);
          expect(metrics['scheduled.collectionInterleavedCommits.update'], 1);
          expect(metrics['drain.collectionInterleavings'], isNull);
          expect(metrics['fullCollections'], isNull);
        });
      },
    );
  });
}

Future<DstReplica> _replica(String name, UuidValue space, DstIds ids, DstClock clock) =>
    DstReplica.create(
      name: name,
      spaceUuids: [space],
      nodeUuid: ids.next(),
      clock: clock.clock,
    );

class _FirstYieldSchedule extends DstRandom {
  _FirstYieldSchedule() : super(163);

  @override
  bool chance(double probability) =>
      probability == DstAdversary.collectionProbability ||
      probability == DstAdversary.collectionInterleavingProbability;

  @override
  int between(int min, int max) => min;

  @override
  T pick<T>(List<T> values) => values.first;
}

class _CaptureSchedule extends _FirstYieldSchedule {
  @override
  bool chance(double probability) =>
      probability == DstAdversary.captureInterleavingProbability ||
      super.chance(probability);
}
