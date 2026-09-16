import 'package:serverpod_database/serverpod_database.dart' show TableRow;
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
    'Given two visible non-FK UUID claims with the same value, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final claimId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_uuid': _visibleRows(space, [
            UniqueUuid(id: firstId, value: claimId),
            UniqueUuid(id: secondId, value: claimId),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible composite claims with the same tuple, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_composite': _visibleRows(space, [
            UniqueComposite(id: firstId, scope: 'partition', value: 'claim'),
            UniqueComposite(id: secondId, scope: 'partition', value: 'claim'),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible composite claims in distinct domain partitions, '
    'when their snapshot is checked, '
    'then the unique oracle accepts the distinct claims.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_composite': _visibleRows(space, [
            UniqueComposite(id: firstId, scope: 'first', value: 'claim'),
            UniqueComposite(id: secondId, scope: 'second', value: 'claim'),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given two visible claims sharing a fixed integer discriminator, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_discriminator': _visibleRows(space, [
            UniqueDiscriminator(id: firstId, categoryId: 7, name: 'claim'),
            UniqueDiscriminator(id: secondId, categoryId: 7, name: 'claim'),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible claims with distinct fixed integer discriminators, '
    'when their snapshot is checked, '
    'then the unique oracle accepts the distinct claims.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_discriminator': _visibleRows(space, [
            UniqueDiscriminator(id: firstId, categoryId: 7, name: 'claim'),
            UniqueDiscriminator(id: secondId, categoryId: 8, name: 'claim'),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given two visible nullable integer claims with the same non-null value, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_nullable': _visibleRows(space, [
            UniqueNullable(id: firstId, value: 7),
            UniqueNullable(id: secondId, value: 7),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible nullable integer claims holding null, '
    'when their snapshot is checked, '
    'then the unique oracle accepts the distinct claims.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_nullable': _visibleRows(space, [
            UniqueNullable(id: firstId),
            UniqueNullable(id: secondId),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given two visible overlapping-index rows colliding only on the second index, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_overlapping': _visibleRows(space, [
            UniqueOverlapping(
              id: firstId,
              first: 'one',
              second: 'shared',
              third: 'shared',
            ),
            UniqueOverlapping(
              id: secondId,
              first: 'two',
              second: 'shared',
              third: 'shared',
            ),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible FK-only composite claims sharing both parents, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final claimId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_fk_pair': _visibleRows(space, [
            UniqueFkPair(id: firstId, name: 'one', leftId: claimId, rightId: space),
            UniqueFkPair(id: secondId, name: 'two', leftId: claimId, rightId: space),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given two visible FK-only composite claims with one null component, '
    'when their snapshot is checked, '
    'then the unique oracle accepts the distinct claims.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final claimId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_fk_pair': _visibleRows(space, [
            UniqueFkPair(id: firstId, name: 'one', leftId: claimId),
            UniqueFkPair(id: secondId, name: 'two', leftId: claimId),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, isEmpty);
    },
  );

  test(
    'Given two visible space-scoped mixed FK and text claims sharing a tuple, '
    'when their snapshot is checked, '
    'then the unique oracle rejects the collision.',
    () {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final firstId = ids.next();
      final secondId = ids.next();
      final claimId = ids.next();
      final snapshot = DstSnapshot(
        rows: {
          'unique_mixed_fk': _visibleRows(space, [
            UniqueMixedFk(id: firstId, name: 'shared', parentId: claimId),
            UniqueMixedFk(id: secondId, name: 'shared', parentId: claimId),
          ]),
        },
        projections: {},
        causalLengths: {},
      );

      final violations = DstOracle.uniqueClosure(snapshot);

      expect(violations, hasLength(1));
    },
  );

  test(
    'Given a replica holding a non-FK UUID unique row, '
    'when its snapshot is captured, '
    'then the authored UUID is available to the convergence oracle.',
    () async {
      final ids = DstIds(DstRandom(2));
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final row = UniqueUuid(id: ids.next(), value: ids.next());
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await UniqueUuid.db.insertRow(replica.session, row, transaction: tx);
        }),
      );

      final snapshot = await DstSnapshot.capture(replica);

      expect(
        snapshot.rows['unique_uuid']?[row.id]?.columns['value'],
        row.value.toString(),
      );
    },
  );
  test(
    'Given an empty replica and a seeded stream of local operations, '
    'when the DST authors 400 operations, '
    'then every supported unique shape has an authored row.',
    () async {
      final random = DstRandom(2026);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await DstReplica.create(
        name: 'replica',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: DstClock().clock,
      );
      final operations = DstOperations(random, ids);

      for (var index = 0; index < 400; index++) {
        await operations.step(replica, space);
      }

      expect(
        await UniqueUuid.db.find(replica.session, where: (t) => t.includeHiddenRows),
        isNotEmpty,
      );
      expect(
        await UniqueComposite.db.find(
          replica.session,
          where: (t) => t.includeHiddenRows,
        ),
        isNotEmpty,
      );
      expect(
        await UniqueDiscriminator.db.find(
          replica.session,
          where: (t) => t.includeHiddenRows,
        ),
        isNotEmpty,
      );
      expect(
        await UniqueNullable.db.find(
          replica.session,
          where: (t) => t.includeHiddenRows,
        ),
        isNotEmpty,
      );
      expect(
        await UniqueOverlapping.db.find(
          replica.session,
          where: (t) => t.includeHiddenRows,
        ),
        isNotEmpty,
      );
      expect(
        await UniqueFkPair.db.find(replica.session, where: (t) => t.includeHiddenRows),
        isNotEmpty,
      );
      expect(
        await UniqueMixedFk.db.find(replica.session, where: (t) => t.includeHiddenRows),
        isNotEmpty,
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

// Only converts the explicitly supplied rows to the oracle's serialized input.
Map<UuidValue, DstRow> _visibleRows(UuidValue space, List<TableRow<UuidValue?>> rows) =>
    {
      for (final row in rows)
        row.id!: (spaceUuid: space, columns: row.toJson(), visible: true),
    };
