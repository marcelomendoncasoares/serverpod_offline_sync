import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_authored.dart';
import 'framework/dst_random.dart';
import 'framework/dst_rejection.dart';
import 'framework/dst_snapshot.dart';
import 'framework/dst_world.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  for (final action in [
    DstAction.insert,
    DstAction.insertBatch,
    DstAction.updateBatch,
  ]) {
    test(
      'Given visible unique rows occupying every generated name, '
      'when the DST performs a competing ${action.name}, '
      'then the supported write commits and preserves every authored claim.',
      () async {
        final random = DstRandom(43);
        final ids = DstIds(random);
        final space = ids.next();
        final replica = await _replica(ids, [space]);
        final operations = DstOperations(random, ids);
        await replica.withReplicaClock(
          () => replica.session.db.transactionForUser(
            space,
            (tx) => Unique.db.insert(replica.session, [
              for (var i = 0; i < 4; i++) Unique(id: ids.next(), name: 'claim-$i'),
            ], transaction: tx),
          ),
        );

        final outcome = await operations.apply(
          replica,
          space,
          table: DstTable.unique,
          action: action,
        );
        final snapshot = await DstSnapshot.capture(replica);

        expect(outcome, DstOperationOutcome.applied);
        expect(operations.rejections, isEmpty);
        expect(DstOracle.invariants(snapshot), isEmpty);
        expect(operations.oracle.validate(snapshot, space), isEmpty);
        expect(
          snapshot.rows['unique'],
          hasLength(
            action == DstAction.updateBatch
                ? 4
                : action == DstAction.insert
                ? 5
                : 6,
          ),
        );
        expect(snapshot.projections, isNotEmpty);
      },
    );
  }

  test(
    'Given a cascade chain with a visible no-action blocker, '
    'when the DST deletes the root, '
    'then the refusal is predicted from the rows and all authored state rolls back.',
    () async {
      final random = DstRandom(44);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, [space]);
      final root = FkChainRoot(id: ids.next(), name: 'root');
      final middle = FkChainCascadeMiddle(
        id: ids.next(),
        name: 'middle',
        rootId: root.id,
      );
      final blocker = FkChainRestrictBlocker(
        id: ids.next(),
        name: 'blocker',
        cascadeMiddleId: middle.id,
      );
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await FkChainRoot.db.insertRow(replica.session, root, transaction: tx);
          await FkChainCascadeMiddle.db.insertRow(
            replica.session,
            middle,
            transaction: tx,
          );
          await FkChainRestrictBlocker.db.insertRow(
            replica.session,
            blocker,
            transaction: tx,
          );
        }),
      );
      final before = await DstSnapshot.capture(replica);
      final prediction = DstRejection(before, space)
        ..delete(DstTable.fkChainRoot, [root.id!]);
      final operations = DstOperations(random, ids);

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.fkChainRoot,
        action: DstAction.delete,
      );
      final after = await DstSnapshot.capture(replica);

      expect(prediction.deleteReasons(definiteOnly: true), isNotEmpty);
      expect(outcome, DstOperationOutcome.rejected);
      expect(after.renderSpace(space), before.renderSpace(space));
      expect(operations.appliedPaths, isEmpty);
    },
  );

  test(
    'Given a company and both its town and default town, '
    'when the DST deletes both towns in one batch, '
    'then the unavailable batch default causes refusal without authored progress.',
    () async {
      final random = DstRandom(45);
      final ids = DstIds(random);
      final space = ids.next();
      final replica = await _replica(ids, [space]);
      await replica.seedDefaultTown(space);
      final town = Town(id: ids.next(), name: 'current');
      final company = Company(id: ids.next(), name: 'company', townId: town.id);
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(space, (tx) async {
          await Town.db.insertRow(replica.session, town, transaction: tx);
          await Company.db.insertRow(replica.session, company, transaction: tx);
        }),
      );
      final before = await DstSnapshot.capture(replica);
      final operations = DstOperations(random, ids);

      final outcome = await operations.apply(
        replica,
        space,
        table: DstTable.town,
        action: DstAction.deleteBatch,
      );
      final after = await DstSnapshot.capture(replica);

      expect(outcome, DstOperationOutcome.rejected);
      expect(after.renderSpace(space), before.renderSpace(space));
      expect(operations.appliedPaths, isEmpty);
    },
  );

  test(
    'Given another space containing the only person and city, '
    'when the DST updates and inserts required references in the empty acting space, '
    'then space-local selection skips both operations without touching the other space.',
    () async {
      final random = DstRandom(46);
      final ids = DstIds(random);
      final space = ids.next();
      final otherSpace = ids.next();
      final replica = await _replica(ids, [space, otherSpace]);
      final operations = DstOperations(random, ids);
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(otherSpace, (tx) async {
          await City.db.insertRow(
            replica.session,
            City(id: ids.next(), name: 'other-city'),
            transaction: tx,
          );
          await Person.db.insertRow(
            replica.session,
            Person(id: ids.next(), name: 'other-person'),
            transaction: tx,
          );
        }),
      );
      final before = await DstSnapshot.capture(replica);

      final update = await operations.apply(
        replica,
        space,
        table: DstTable.city,
        action: DstAction.update,
      );
      final insert = await operations.apply(
        replica,
        space,
        table: DstTable.requiredCascadeChild,
        action: DstAction.insert,
      );
      final after = await DstSnapshot.capture(replica);

      expect(update, DstOperationOutcome.skipped);
      expect(insert, DstOperationOutcome.skipped);
      expect(after.renderSpace(otherSpace), before.renderSpace(otherSpace));
      expect(after.renderSpace(space), before.renderSpace(space));
    },
  );

  for (final error in [
    'UNIQUE constraint failed: city.name',
    'FOREIGN KEY constraint failed',
  ]) {
    test(
      'Given a valid city insert and an injected database failure, '
      'when SQLite raises $error, '
      'then the DST surfaces the unexpected exception instead of counting a refusal.',
      () async {
        final random = DstRandom(47);
        final ids = DstIds(random);
        final space = ids.next();
        final replica = await _replica(ids, [space]);
        final operations = DstOperations(random, ids);
        // Fault injection at the actual database boundary, after normal schema
        // initialization; no mocked exception classifier or production edits.
        await replica.rawSession.db.unsafeExecute(
          "CREATE TRIGGER dst_fault BEFORE INSERT ON city BEGIN SELECT RAISE(ABORT, '$error'); END",
        );

        final result = operations.apply(
          replica,
          space,
          table: DstTable.city,
          action: DstAction.insert,
        );

        await expectLater(
          result,
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', contains(error)),
          ),
        );
        expect(operations.rejections, isEmpty);
        expect(operations.appliedPaths, isEmpty);
        expect(operations.unexpected, 1);
      },
    );
  }

  test(
    'Given an accepted city insertion and a requested delete, '
    'when a successful no-op snapshot is checked against that intent, '
    'then authoring evidence rejects the missing tombstone progress.',
    () async {
      final ids = DstIds(DstRandom(48));
      final space = ids.next();
      final replica = await _replica(ids, [space]);
      final city = City(id: ids.next(), name: 'live');
      await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          space,
          (tx) => City.db.insertRow(replica.session, city, transaction: tx),
        ),
      );
      final before = await DstSnapshot.capture(replica);
      final evidence = DstWriteEvidence(before)
        ..visibility('city', [city.id!], deleted: true);

      final violations = evidence.validate(before);

      expect(violations.map((v) => v.property), ['acceptedVisibility']);
    },
  );
}

Future<DstReplica> _replica(DstIds ids, List<UuidValue> spaces) => DstReplica.create(
  name: 'replica',
  spaceUuids: spaces,
  nodeUuid: ids.next(),
  clock: DstClock().clock,
);
