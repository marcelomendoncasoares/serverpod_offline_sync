import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_authored.dart';
import 'framework/dst_random.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  test(
    'Given two accepted unique rows claiming the same name, '
    'when the preserved losing claim is removed from storage, '
    'then the independent authoring evidence and portable comparison detect the loss.',
    () async {
      final ids = DstIds(DstRandom(22));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final first = Unique(id: ids.next(), name: 'shared');
      final second = Unique(id: ids.next(), name: 'shared');
      final evidence = DstWriteEvidence(await DstSnapshot.capture(replica))
        ..write('unique', first.toJson())
        ..write('unique', second.toJson());
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => Unique.db.insert(replica.session, [first, second], transaction: tx),
        ),
      );
      final accepted = await DstSnapshot.capture(replica);
      expect(evidence.validate(accepted), isEmpty);
      final oracle = DstAuthoredOracle()..accept(accepted);
      expect(oracle.validate(accepted, space), isEmpty);
      final attempts = await CrdtDataAttemptedValue.db.find(replica.rawSession);
      expect(attempts, hasLength(1));

      // Deliberate oracle mutation after a real supported write: this is a
      // detector regression, not an allegation that production deletes it.
      await CrdtDataAttemptedValue.db.delete(replica.rawSession, attempts);
      final damaged = await DstSnapshot.capture(replica);

      expect(
        evidence.validate(damaged).map((v) => v.property),
        contains('acceptedWrite'),
      );
      expect(
        oracle.validate(damaged, space).map((v) => v.property),
        contains('authoredRetention'),
      );
      expect(damaged.renderSpace(space), isNot(accepted.renderSpace(space)));
    },
  );

  test(
    'Given a live city with no authored deletion or outbound references, '
    'when an oracle input falsely hides that city, '
    'then the independent visibility rule rejects the snapshot.',
    () async {
      final ids = DstIds(DstRandom(23));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'live');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final before = await DstSnapshot.capture(replica);
      final row = before.rows['city']![city.id]!;

      final damaged = _copy(
        before,
        rows: {
          ...before.rows,
          'city': {city.id!: (spaceUuid: space, columns: row.columns, visible: false)},
        },
      );

      expect(DstOracle.invariants(before), isEmpty);
      expect(DstOracle.invariants(damaged).map((v) => v.property), [
        'legitimateVisibility',
      ]);
    },
  );

  test(
    'Given an acknowledged city and a later corrupted field clock, '
    'when an unrelated unique insert is acknowledged, '
    'then the oracle still rejects the preexisting corruption.',
    () async {
      final ids = DstIds(DstRandom(26));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'accepted');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final accepted = await DstSnapshot.capture(replica);
      final oracle = DstAuthoredOracle()..accept(accepted);
      final key = ('city', city.id!, 'name');
      final fabricatedClock = accepted.fieldHlc(key)!.increment();
      final beforeUnrelated = _copy(accepted, fieldHlcs: {key: fabricatedClock});
      final unique = Unique(id: ids.next(), name: 'unrelated');

      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => Unique.db.insertRow(replica.session, unique, transaction: tx),
        ),
      );
      final afterUnrelated = _copy(
        await DstSnapshot.capture(replica),
        fieldHlcs: {key: fabricatedClock},
      );
      oracle.accept(afterUnrelated, before: beforeUnrelated);

      expect(oracle.validate(afterUnrelated, space).map((v) => v.property), [
        'authoredRetention',
      ]);
    },
  );

  test(
    'Given a nullable FK with a persisted database default, '
    'when the raw ORM inserts an omitted value and explicitly updates it to null, '
    'then insertion uses the declared default and the narrowed update retains null.',
    () async {
      final ids = DstIds(DstRandom(27));
      final space = ids.next();
      final replica = await _replica(ids, space);
      await replica.seedDefaultTown(space);
      final child = UniqueSetDefaultChild(id: ids.next(), name: 'defaulted');
      final inserted = await UniqueSetDefaultChild.db.insertRow(
        replica.rawSession,
        child,
      );

      await UniqueSetDefaultChild.db.updateRow(
        replica.rawSession,
        inserted.copyWith(parentId: null),
        columns: (t) => [t.parentId],
      );

      expect(inserted.parentId, dstDefaultTownId);
      expect(
        (await UniqueSetDefaultChild.db.findById(
          replica.rawSession,
          child.id!,
        ))!.parentId,
        isNull,
      );
    },
  );

  test(
    'Given a CRDT child inserted using its persisted FK default, '
    'when an explicit narrowed update clears its reference, '
    'then independent evidence records the default followed by authored null.',
    () async {
      final ids = DstIds(DstRandom(28));
      final space = ids.next();
      final replica = await _replica(ids, space);
      await replica.seedDefaultTown(space);
      final child = UniqueSetDefaultChild(id: ids.next(), name: 'defaulted');
      final insertion = DstWriteEvidence(await DstSnapshot.capture(replica))
        ..write('unique_set_default_child', child.toJson(), insertDefaults: true);
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => UniqueSetDefaultChild.db.insertRow(
            replica.session,
            child,
            transaction: tx,
          ),
        ),
      );
      final beforeUpdate = await DstSnapshot.capture(replica);
      final update = DstWriteEvidence(beforeUpdate)
        ..write(
          'unique_set_default_child',
          child.copyWith(parentId: null).toJson(),
          columns: {'parentId'},
        );

      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => UniqueSetDefaultChild.db.updateRow(
            replica.session,
            child.copyWith(parentId: null),
            columns: (t) => [t.parentId],
            transaction: tx,
          ),
        ),
      );
      final after = await DstSnapshot.capture(replica);

      expect(insertion.validate(beforeUpdate), isEmpty);
      expect(update.validate(after), isEmpty);
      expect(
        after.authoredValue(('unique_set_default_child', child.id!, 'parentId')),
        isNull,
      );
    },
  );

  for (final action in ['restore', 'hidden upsert', 'visible upsert']) {
    test(
      'Given a nullable defaulted FK explicitly cleared before $action, '
      'when that existing identity is written with a null model value, '
      'then authoring evidence follows the existing-row default contract.',
      () async {
        final ids = DstIds(DstRandom(29));
        final space = ids.next();
        final replica = await _replica(ids, space);
        await replica.seedDefaultTown(space);
        final child = UniqueSetDefaultChild(id: ids.next(), name: 'defaulted');
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(space, (tx) async {
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
            if (action != 'visible upsert') {
              await UniqueSetDefaultChild.db.deleteRow(
                replica.session,
                child,
                transaction: tx,
              );
            }
          }),
        );
        final before = await DstSnapshot.capture(replica);
        final evidence = DstWriteEvidence(before)
          ..write(
            'unique_set_default_child',
            child.toJson(),
            insertDefaults: action == 'visible upsert',
          );

        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(space, (tx) async {
            if (action == 'restore') {
              await UniqueSetDefaultChild.db.insertRow(
                replica.session,
                child,
                transaction: tx,
              );
            } else {
              await replica.session.db.upsertRow(
                child,
                conflictColumns: [UniqueSetDefaultChild.t.id],
                transaction: tx,
              );
            }
          }),
        );
        final after = await DstSnapshot.capture(replica);

        expect(evidence.validate(after), isEmpty);
        expect(
          after.authoredValue(('unique_set_default_child', child.id!, 'parentId')),
          action == 'visible upsert' ? dstDefaultTownId.toString() : null,
        );
      },
    );
  }

  test(
    'Given a city restored after its original insertion reached another replica, '
    'when the restored facts reach that replica and an empty bootstrap, '
    'then different raw row anchors preserve identical canonical fields and tombstones.',
    () async {
      final ids = DstIds(DstRandom(30));
      final space = ids.next();
      final source = await _replica(ids, space);
      final receiver = await _replica(ids, space);
      final mirror = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'original');
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(source.session, city, transaction: tx),
        ),
      );
      await receiver.merge(await source.collect(space), space);
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.deleteRow(source.session, city, transaction: tx),
        ),
      );
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(
            source.session,
            city.copyWith(name: 'restored'),
            transaction: tx,
          ),
        ),
      );
      final accepted = await DstSnapshot.capture(source);
      final oracle = DstAuthoredOracle()..accept(accepted);

      await receiver.merge(await source.collect(space), space);
      await mirror.merge(await receiver.collect(space), space);
      final received = await DstSnapshot.capture(receiver);
      final bootstrapped = await DstSnapshot.capture(mirror);
      final key = 'city/${city.id}';

      expect(received.rowHlcs[key], isNot(accepted.rowHlcs[key]));
      expect(received.renderRawMetadata(), isNot(accepted.renderRawMetadata()));
      expect(received.tombstones[key], accepted.tombstones[key]);
      expect(received.tombstones[key]!.clFlag, 3);
      expect(received.renderSpace(space), accepted.renderSpace(space));
      expect(bootstrapped.renderSpace(space), accepted.renderSpace(space));
      expect(oracle.validate(received, space), isEmpty);
      expect(oracle.validate(bootstrapped, space), isEmpty);
    },
  );

  test(
    'Given independently upserted visible cities sharing one identity, '
    'when the newer insertion reaches an existing replica and an empty bootstrap, '
    'then its redundant generation-one insertion marker has the same canonical facts.',
    () async {
      final ids = DstIds(DstRandom(31));
      final space = ids.next();
      final clock = DstClock();
      final receiver = await DstReplica.create(
        name: 'receiver',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      final source = await DstReplica.create(
        name: 'source',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      final mirror = await DstReplica.create(
        name: 'mirror',
        spaceUuids: [space],
        nodeUuid: ids.next(),
        clock: clock.clock,
      );
      final city = City(id: ids.next(), name: 'original');
      await receiver.withReplicaClock(
        () => receiver.session.db.transactionForUser(
          space,
          (tx) => receiver.session.db.upsertRow(
            city,
            conflictColumns: [City.t.id],
            transaction: tx,
          ),
        ),
      );
      clock.advance(const Duration(milliseconds: 1));
      await source.withReplicaClock(
        () => source.session.db.transactionForUser(
          space,
          (tx) => source.session.db.upsertRow(
            city.copyWith(name: 'newer'),
            conflictColumns: [City.t.id],
            transaction: tx,
          ),
        ),
      );
      final accepted = await DstSnapshot.capture(source);
      final oracle = DstAuthoredOracle()..accept(accepted);

      await receiver.merge(await source.collect(space), space);
      await mirror.merge(await receiver.collect(space), space);
      final received = await DstSnapshot.capture(receiver);
      final bootstrapped = await DstSnapshot.capture(mirror);
      final key = 'city/${city.id}';

      expect(accepted.tombstones[key], isNull);
      expect(received.tombstones[key]!.clFlag, 1);
      expect(received.tombstones[key]!.reason, CrdtDataDeletedReason.userInsert);
      expect(received.rowHlcs[key], isNot(accepted.rowHlcs[key]));
      expect(received.renderRawMetadata(), isNot(accepted.renderRawMetadata()));
      expect(received.renderSpace(space), accepted.renderSpace(space));
      expect(bootstrapped.renderSpace(space), accepted.renderSpace(space));
      expect(oracle.validate(received, space), isEmpty);
      expect(oracle.validate(bootstrapped, space), isEmpty);
    },
  );

  test(
    'Given an accepted live city without a delete event, '
    'when a fabricated delete tombstone appears in the oracle input, '
    'then the oracle rejects the unacknowledged visibility change.',
    () async {
      final ids = DstIds(DstRandom(32));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'live');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final accepted = await DstSnapshot.capture(replica);
      final oracle = DstAuthoredOracle()..accept(accepted);
      final key = 'city/${city.id}';

      final damaged = _copy(
        accepted,
        tombstones: {
          key: (
            hlc: accepted.rowHlcs[key]!.increment(),
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        },
      );

      expect(oracle.validate(damaged, space).map((v) => v.property), [
        'authoredRetention',
      ]);
    },
  );

  test(
    'Given an accepted live city without a newer insertion event, '
    'when an insertion marker newer than every field clock appears in the oracle input, '
    'then the oracle rejects the unacknowledged insertion marker.',
    () async {
      final ids = DstIds(DstRandom(32));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'live');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final accepted = await DstSnapshot.capture(replica);
      final oracle = DstAuthoredOracle()..accept(accepted);
      final key = 'city/${city.id}';

      final damaged = _copy(
        accepted,
        tombstones: {
          key: (
            hlc: accepted.rowHlcs[key]!.increment(),
            clFlag: 1,
            reason: CrdtDataDeletedReason.userInsert,
          ),
        },
      );

      expect(oracle.validate(damaged, space).map((v) => v.property), [
        'authoredRetention',
      ]);
    },
  );

  for (final metadata in [
    'field clock',
    'inherited field clock',
    'tombstone clock',
    'tombstone reason',
    'projection reason',
  ]) {
    test(
      'Given equal-looking snapshots of a deleted unique row, '
      'when only its $metadata diverges, '
      'then the portable comparison detects the different metadata.',
      () async {
        final ids = DstIds(DstRandom(24));
        final space = ids.next();
        final replica = await _replica(ids, space);
        final row = Unique(id: ids.next(), name: 'retained');
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(
            space,
            (tx) => Unique.db.insertRow(replica.session, row, transaction: tx),
          ),
        );
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(
            space,
            (tx) => Unique.db.deleteRow(replica.session, row, transaction: tx),
          ),
        );
        final before = await DstSnapshot.capture(replica);
        final key = ('unique', row.id!, 'name');
        final rowKey = 'unique/${row.id}';
        final tombstone = before.tombstones[rowKey]!;
        final projection = before.projections[key]!;

        final damaged = _copy(
          before,
          fieldHlcs: metadata == 'field clock'
              ? {...before.fieldHlcs, key: before.fieldHlc(key)!.increment()}
              : metadata == 'inherited field clock'
              ? (Map.of(before.fieldHlcs)..remove(key))
              : null,
          rowHlcs: metadata == 'inherited field clock'
              ? {...before.rowHlcs, rowKey: before.rowHlcs[rowKey]!.increment()}
              : null,
          tombstones: metadata.startsWith('tombstone')
              ? {
                  ...before.tombstones,
                  rowKey: (
                    hlc: metadata == 'tombstone clock'
                        ? tombstone.hlc.increment()
                        : tombstone.hlc,
                    clFlag: tombstone.clFlag,
                    reason: metadata == 'tombstone reason'
                        ? CrdtDataDeletedReason.userCascadeDelete
                        : tombstone.reason,
                  ),
                }
              : null,
          projections: metadata == 'projection reason'
              ? {
                  ...before.projections,
                  key: (
                    attemptedValue: projection.attemptedValue,
                    projectionReason: CrdtProjectionReason.uniqueConflict,
                  ),
                }
              : null,
        );

        expect(damaged.rows, before.rows);
        expect(damaged.renderSpace(space), isNot(before.renderSpace(space)));
      },
    );
  }

  test(
    'Given a field inheriting its insertion clock, '
    'when an equal explicit field clock is added to the snapshot, '
    'then portable equality accepts the equivalent sparse representation.',
    () async {
      final ids = DstIds(DstRandom(25));
      final space = ids.next();
      final replica = await _replica(ids, space);
      final city = City(id: ids.next(), name: 'live');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final before = await DstSnapshot.capture(replica);
      final key = ('city', city.id!, 'name');

      final equivalent = _copy(
        before,
        fieldHlcs: {...before.fieldHlcs, key: before.fieldHlc(key)!},
      );

      expect(equivalent.renderSpace(space), before.renderSpace(space));
    },
  );
}

Future<DstReplica> _replica(DstIds ids, UuidValue space) => DstReplica.create(
  name: 'replica',
  spaceUuids: [space],
  nodeUuid: ids.next(),
  clock: DstClock().clock,
);

DstSnapshot _copy(
  DstSnapshot source, {
  Map<String, Map<UuidValue, DstRow>>? rows,
  Map<String, Hlc>? rowHlcs,
  Map<DstFieldKey, Hlc>? fieldHlcs,
  Map<String, DstTombstone>? tombstones,
  Map<DstFieldKey, DstProjection>? projections,
}) => DstSnapshot(
  rows: rows ?? source.rows,
  projections: projections ?? source.projections,
  causalLengths: source.causalLengths,
  rowHlcs: rowHlcs ?? source.rowHlcs,
  fieldHlcs: fieldHlcs ?? source.fieldHlcs,
  tombstones: tombstones ?? source.tombstones,
);
