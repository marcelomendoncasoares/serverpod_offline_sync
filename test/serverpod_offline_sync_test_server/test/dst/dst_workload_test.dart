import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_workload.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  for (final hasDefault in [true, false]) {
    test(
      'Given an empty space ${hasDefault ? 'with' : 'without'} the fixed default town, '
      'when a width-two populated workload authors its graph and transitions, '
      'then every declared FK edge and the required semantic paths are observed.',
      () async {
        final random = DstRandom(61);
        final ids = DstIds(random);
        final space = ids.next();
        final replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        if (hasDefault) await replica.seedDefaultTown(space);
        final operations = DstOperations(random, ids);
        operations.oracle.accept(await DstSnapshot.capture(replica));

        await populateDstSpace(
          replica: replica,
          space: space,
          operations: operations,
          ids: ids,
          width: 2,
        );
        final snapshot = await DstSnapshot.capture(replica);

        expect(operations.coverage.tables, hasLength(DstTable.values.length));
        expect(operations.coverage.foreignKeys, hasLength(dstForeignKeys.length));
        for (final transition in [
          'authoredCycle',
          'restore',
          'redelete',
          'fkRetarget',
          'fkDetach',
          'uniqueConflict',
          'uniqueSwap',
          'constrainedRejection',
        ]) {
          expect(
            operations.coverage.transitions[transition],
            greaterThan(0),
            reason: transition,
          );
        }
        expect(
          operations.attempted,
          operations.committed + operations.rejections.length + operations.skipped,
        );
        expect(operations.skipped, 0);
        expect(operations.rejections, hasLength(1));
        expect(DstOracle.invariants(snapshot), isEmpty);
        expect(operations.oracle.validate(snapshot, space), isEmpty);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }

  test(
    'Given two nullable unique rows with identical null tuples, '
    'when the DST submits a tuple swap, '
    'then metrics count the commit without claiming a semantic exchange.',
    () async {
      final random = DstRandom(63);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => UniqueNullable.db.insert(replica.session, [
            UniqueNullable(id: ids.next()),
            UniqueNullable(id: ids.next()),
          ], transaction: tx),
        ),
      );
      final operations = DstOperations(random, ids);

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.uniqueNullable,
        action: DstAction.swapUnique,
      );

      expect(outcome, DstOperationOutcome.applied);
      expect(operations.committed, 1);
      expect(operations.coverage.transitions['uniqueSwap'] ?? 0, 0);
    },
  );

  test(
    'Given a real city insert with deliberately incorrect authoring evidence, '
    'when the transaction commits but its oracle check fails, '
    'then metrics retain the committed attempt and the validation failure.',
    () async {
      final random = DstRandom(64);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final city = City(id: ids.next(), name: 'actual');
      final operations = DstOperations(random, ids);

      final result = operations.perform(
        replica,
        space,
        table: DstTable.city,
        action: DstAction.insert,
        body: (tx, evidence, refusal) async {
          evidence.write(
            'city',
            city.copyWith(name: 'deliberate detector mutation').toJson(),
          );
          await City.db.insertRow(replica.session, city, transaction: tx);
          return DstOperationOutcome.applied;
        },
      );

      await expectLater(result, throwsStateError);
      expect(operations.attempted, 1);
      expect(operations.committed, 1);
      expect(operations.validationFailures, 1);
      expect(operations.unexpected, 0);
      expect(operations.rejections, isEmpty);
      expect(operations.skipped, 0);
    },
  );

  test(
    'Given two isolated width-two populated workloads with the same seed, '
    'when each independently authors the graph and transitions, '
    'then portable facts and semantic coverage replay exactly.',
    () async {
      final snapshots = <String>[];
      final observations = <Map<String, Object>>[];
      for (var run = 0; run < 2; run++) {
        final random = DstRandom(62);
        final ids = DstIds(random);
        final space = ids.next();
        final replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        await replica.seedDefaultTown(space);
        final operations = DstOperations(random, ids);

        await populateDstSpace(
          replica: replica,
          space: space,
          operations: operations,
          ids: ids,
          width: 2,
        );
        snapshots.add((await DstSnapshot.capture(replica)).renderSpace(space));
        observations.add(operations.coverage.toJson());
      }

      expect(snapshots.last, snapshots.first);
      expect(observations.last, observations.first);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Given two isolated width-three populated workloads with the same seed, '
    'when each independently authors the graph and transitions, '
    'then portable facts and semantic coverage replay exactly.',
    () async {
      final snapshots = <String>[];
      final observations = <Map<String, Object>>[];
      for (var run = 0; run < 2; run++) {
        final random = DstRandom(62);
        final ids = DstIds(random);
        final space = ids.next();
        final replica = await DstReplica.create(
          name: 'replica',
          spaceUuids: [space],
          nodeUuid: ids.next(),
          clock: DstClock().clock,
        );
        await replica.seedDefaultTown(space);
        final operations = DstOperations(random, ids);

        await populateDstSpace(
          replica: replica,
          space: space,
          operations: operations,
          ids: ids,
          width: 3,
        );
        snapshots.add((await DstSnapshot.capture(replica)).renderSpace(space));
        observations.add(operations.coverage.toJson());
      }

      expect(snapshots.last, snapshots.first);
      expect(observations.last, observations.first);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
