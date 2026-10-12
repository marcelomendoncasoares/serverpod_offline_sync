import 'package:serverpod/serverpod.dart' show ClientDatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  test(
    'Given one replica holding a UUID-shaped unique text value, '
    'when an empty peer bootstraps from its complete export, '
    'then the peer retains the original text value.',
    () async {
      final space = const Uuid().v7obj();
      final source = await _replica(space);
      final target = await _replica(space);
      final row = Unique(
        id: const Uuid().v7obj(),
        name: '550e8400-e29b-41d4-a716-446655440111',
      );
      await source.session.db.transactionForUser(
        space,
        (tx) => Unique.db.insertRow(source.session, row, transaction: tx),
      );

      final changes = await source.sync
          .collectPendingChanges(
            source.raw,
            checkpointsBySpaceUuid: {space: const []},
          )
          .toList();
      await target.session.db.mergeChanges(changes, userId: space);

      expect((await Unique.db.findById(target.session, row.id!))!.name, row.name);
    },
  );

  test(
    'Given a UUID-shaped unique text claim and an unrelated row, '
    'when a local update authors the uppercase text on the other row, '
    'then both distinct text claims remain unchanged.',
    () async {
      final space = const Uuid().v7obj();
      final replica = await _replica(space);
      final lower = Unique(
        id: const Uuid().v7obj(),
        name: '550e8400-e29b-41d4-a716-446655440111',
      );
      final other = Unique(id: const Uuid().v7obj(), name: 'placeholder');
      const upper = '550E8400-E29B-41D4-A716-446655440111';
      await replica.session.db.transactionForUser(
        space,
        (tx) => Unique.db.insert(replica.session, [lower, other], transaction: tx),
      );

      await replica.session.db.transactionForUser(
        space,
        (tx) => Unique.db.updateRow(
          replica.session,
          other.copyWith(name: upper),
          columns: (t) => [t.name],
          transaction: tx,
        ),
      );

      expect(
        {for (final row in await Unique.db.find(replica.session)) row.id: row.name},
        {lower.id: lower.name, other.id: upper},
      );
      expect(await CrdtDataAttemptedValue.db.find(replica.raw), isEmpty);
    },
  );

  test(
    'Given two replicas authoring UUID-shaped text in different letter cases, '
    'when their complete exports are exchanged, '
    'then both replicas retain the two distinct text claims.',
    () async {
      final space = const Uuid().v7obj();
      final left = await _replica(space);
      final right = await _replica(space);
      final lower = Unique(
        id: const Uuid().v7obj(),
        name: '550e8400-e29b-41d4-a716-446655440111',
      );
      final upper = Unique(
        id: const Uuid().v7obj(),
        name: '550E8400-E29B-41D4-A716-446655440111',
      );
      await left.session.db.transactionForUser(
        space,
        (tx) => Unique.db.insertRow(left.session, lower, transaction: tx),
      );
      await right.session.db.transactionForUser(
        space,
        (tx) => Unique.db.insertRow(right.session, upper, transaction: tx),
      );

      final fromLeft = await left.sync
          .collectPendingChanges(
            left.raw,
            checkpointsBySpaceUuid: {space: const []},
          )
          .toList();
      final fromRight = await right.sync
          .collectPendingChanges(
            right.raw,
            checkpointsBySpaceUuid: {space: const []},
          )
          .toList();
      await right.session.db.mergeChanges(fromLeft, userId: space);
      await left.session.db.mergeChanges(fromRight, userId: space);

      for (final replica in [left, right]) {
        expect(
          {for (final row in await Unique.db.find(replica.session)) row.id: row.name},
          {lower.id: lower.name, upper.id: upper.name},
        );
        expect(await CrdtDataAttemptedValue.db.find(replica.raw), isEmpty);
      }
    },
  );
}

/// Independent public ORM/collector/merge control: no DST generator, refusal
/// classifier, or expected-fact oracle participates in these expectations.
Future<
  ({
    ClientDatabaseSession raw,
    OfflineSyncDatabaseSession session,
    OfflineSyncEngine sync,
  })
>
_replica(UuidValue space) async {
  final raw = await createAdditionalTestSession();
  final session = OfflineSyncDatabaseSession.wraps(raw, syncTables: syncTables);
  await session.db.initialize();
  await session.db.transactionForUser(space, (_) async {});
  return (
    raw: raw,
    session: session,
    sync: OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: raw.db.serializationManager,
    ),
  );
}
