import 'package:serverpod/serverpod.dart' show ClientDatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import '../integration/test_tools/sync_topology.dart';

typedef _Replica = ({
  ClientDatabaseSession raw,
  OfflineSyncDatabaseSession session,
  OfflineSyncEngine sync,
});

void main() {
  initTestClientSession(createSessionPerTest: false);

  Future<_Replica> replica(UuidValue space) async {
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

  Future<Map<String, Object?>> claims(ClientDatabaseSession raw) async {
    final records = await CrdtDataAttemptedValue.db.find(
      raw,
      include: CrdtDataAttemptedValue.include(
        field: CrdtDataField.include(
          row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
          column: CrdtSchemaColumn.include(),
        ),
      ),
    );
    return {
      for (final record in records)
        '${record.field!.row!.tbl!.name}/${record.field!.row!.uuidRowId}'
                '.${record.field!.column!.name}':
            record.value,
    };
  }

  Future<int?> valueOf(OfflineSyncDatabaseSession session, UuidValue id) async =>
      (await UniqueNullable.db.findById(session, id))!.value;

  Future<void> upsertValue(_Replica node, UuidValue space, UuidValue id, int value) =>
      node.session.db.transactionForUser(
        space,
        (tx) => node.session.db.upsertRow(
          UniqueNullable(id: id, value: value),
          conflictColumns: [UniqueNullable.t.id],
          transaction: tx,
        ),
      );

  Future<(UuidValue winner, UuidValue loser)> twoClaimants(
    _Replica node,
    UuidValue space, {
    required int value,
  }) async {
    final winner = const Uuid().v7obj();
    final loser = const Uuid().v7obj();
    await node.session.db.transactionForUser(
      space,
      (tx) => UniqueNullable.db.insertRow(
        node.session,
        UniqueNullable(id: winner, value: value),
        transaction: tx,
      ),
    );
    await mergeIndependentInsert(
      node.session,
      UniqueNullable(id: loser, value: value),
      space: space,
      tables: [UniqueNullable.t],
    );
    return (winner, loser);
  }

  test(
    'Given two rows claiming the same nullable unique value, '
    'when an independently authored later claim is merged, '
    'then the loser stays visible with a released column and a preserved claim.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);

      final (winner, loser) = await twoClaimants(node, space, value: 0);

      final rows = {
        for (final row in await UniqueNullable.db.find(node.session))
          row.id!: row.value,
      };
      expect(rows, {winner: 0, loser: null});
      expect(await claims(node.raw), {'unique_nullable/$loser.value': 0});
    },
  );

  test(
    'Given a visible projected loser preserving the claim 0, '
    'when it is upserted to the free value 1, '
    'then the row holds 1 and no preserved claim remains.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final (winner, loser) = await twoClaimants(node, space, value: 0);

      await upsertValue(node, space, loser, 1);

      expect(await valueOf(node.session, loser), 1);
      expect(await valueOf(node.session, winner), 0);
      expect(await claims(node.raw), isEmpty);
    },
  );

  test(
    'Given a visible projected loser preserving the claim 0, '
    'when a full-row update writes the free value 1, '
    'then the row holds 1 and no preserved claim remains.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final (winner, loser) = await twoClaimants(node, space, value: 0);

      await node.session.db.transactionForUser(
        space,
        (tx) => UniqueNullable.db.updateRow(
          node.session,
          UniqueNullable(id: loser, value: 1),
          transaction: tx,
        ),
      );

      expect(await valueOf(node.session, loser), 1);
      expect(await valueOf(node.session, winner), 0);
      expect(await claims(node.raw), isEmpty);
    },
  );

  test(
    'Given a visible projected loser preserving the claim 0, '
    'when a narrowed update writes the free value 1 to that column, '
    'then the row holds 1 and no preserved claim remains.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final (winner, loser) = await twoClaimants(node, space, value: 0);

      await node.session.db.transactionForUser(
        space,
        (tx) => UniqueNullable.db.updateRow(
          node.session,
          UniqueNullable(id: loser, value: 1),
          columns: (t) => [t.value],
          transaction: tx,
        ),
      );

      expect(await valueOf(node.session, loser), 1);
      expect(await valueOf(node.session, winner), 0);
      expect(await claims(node.raw), isEmpty);
    },
  );

  test(
    'Given a visible projected loser upserted twice to free values, '
    'when the contesting row is deleted and its claim becomes free, '
    'then the loser holds the most recent value its author wrote.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final (winner, loser) = await twoClaimants(node, space, value: 0);
      await upsertValue(node, space, loser, 1);
      await upsertValue(node, space, loser, 2);

      await node.session.db.transactionForUser(
        space,
        (tx) => UniqueNullable.db.deleteRow(
          node.session,
          UniqueNullable(id: winner, value: 0),
          transaction: tx,
        ),
      );

      expect(await valueOf(node.session, loser), 2);
    },
  );

  test(
    'Given a visible projected loser upserted to the free value 1, '
    'when an empty peer bootstraps from the complete export, '
    'then the peer materialises the value the author wrote.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final mirror = await replica(space);
      final (_, loser) = await twoClaimants(node, space, value: 0);
      await upsertValue(node, space, loser, 1);

      final changes = await node.sync
          .collectPendingChanges(
            node.raw,
            checkpointsBySpaceUuid: {space: 0},
          )
          .toList();
      await mirror.session.db.mergeChanges(changes, userId: space);

      expect(
        await valueOf(mirror.session, loser),
        await valueOf(node.session, loser),
        reason: 'author and peer must agree',
      );
      expect(await valueOf(mirror.session, loser), 1);
    },
  );

  test(
    'Given a visible row with no preserved claim on its unique column, '
    'when it is upserted to a free value, '
    'then the row holds the value its author wrote.',
    () async {
      final space = const Uuid().v7obj();
      final node = await replica(space);
      final uncontested = const Uuid().v7obj();
      await node.session.db.transactionForUser(
        space,
        (tx) => UniqueNullable.db.insertRow(
          node.session,
          UniqueNullable(id: uncontested, value: 0),
          transaction: tx,
        ),
      );

      await upsertValue(node, space, uncontested, 1);

      expect(await valueOf(node.session, uncontested), 1);
      expect(await claims(node.raw), isEmpty);
    },
  );
}
