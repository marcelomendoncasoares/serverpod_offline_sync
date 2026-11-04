import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a stored unique claim newer than an incoming claimant,', () {
    late SyncNode node;
    late UniqueNullable stored;
    late UniqueNullable incoming;
    late Hlc storedClock;
    late Hlc incomingClock;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      stored = UniqueNullable(id: const Uuid().v7obj(), value: 7);
      incoming = UniqueNullable(id: const Uuid().v7obj(), value: 7);
      storedClock = Hlc(DateTime.utc(2026, 9, 2), 0, const Uuid().v7obj());
      incomingClock = Hlc(DateTime.utc(2026, 9, 1), 0, const Uuid().v7obj());
      await node.offlineSync.db.mergeChanges([
        _insert(stored, storedClock),
      ], userId: testCrdtUserId);
    });

    group('when one merge inserts the older claimant and moves it to another value,', () {
      late UniqueNullable? original;
      late UniqueNullable? newcomer;
      late CrdtDataAttemptedValue? remainingAttempt;
      late Hlc originalClock;

      setUpAll(() async {
        await node.offlineSync.db.mergeChanges([
          _insert(incoming, incomingClock),
          CrdtMergeUpdate(
            uuidSpaceId: testCrdtUserId,
            tableName: UniqueNullable.t.tableName,
            uuidRowId: incoming.id!,
            uuidNodeId: incomingClock.nodeId,
            hlcDatetime: storedClock.datetime.add(const Duration(days: 1)),
            hlcCounter: 0,
            columnName: 'value',
            value: 8,
          ),
        ], userId: testCrdtUserId);

        original = await UniqueNullable.db.findById(node.offlineSync, stored.id!);
        newcomer = await UniqueNullable.db.findById(node.offlineSync, incoming.id!);
        remainingAttempt = await attemptedValue(
          rowId: stored.id!,
          columnName: 'value',
          databaseSession: node.offlineSync,
        );
        originalClock = await rowHlc(stored.id!, databaseSession: node.offlineSync);
      });

      test('then the original row regains the value released before insertion.', () {
        expect(original?.value, 7);
        expect(newcomer?.value, 8);
      });

      test(
        'then repairing the original claim preserves its clock and clears its attempt.',
        () {
          expect(originalClock, storedClock);
          expect(remainingAttempt, isNull);
        },
      );
    });
  });

  group('Given a city with an existing cascading town,', () {
    late SyncNode node;
    late City city;
    late Town existing;
    late Town incoming;
    late Hlc clock;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      city = City(id: const Uuid().v7obj(), name: 'city');
      existing = Town(id: const Uuid().v7obj(), name: 'existing', cityId: city.id);
      incoming = Town(id: const Uuid().v7obj(), name: 'incoming', cityId: city.id);
      clock = Hlc(DateTime.utc(2026, 9, 1), 0, const Uuid().v7obj());
      await node.offlineSync.db.mergeChanges([
        _insert(city, clock),
        _insert(existing, Hlc(clock.datetime, 1, clock.nodeId)),
      ], userId: testCrdtUserId);
    });

    group('when one merge adds a second town and deletes their city,', () {
      late City? visibleCity;
      late List<Town> visibleTowns;
      late List<Town> retainedTowns;

      setUpAll(() async {
        await node.offlineSync.db.mergeChanges([
          _insert(incoming, Hlc(clock.datetime, 2, clock.nodeId)),
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: City.t.tableName,
            uuidRowId: city.id!,
            uuidNodeId: clock.nodeId,
            hlcDatetime: clock.datetime,
            hlcCounter: 3,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ], userId: testCrdtUserId);

        visibleCity = await City.db.findById(node.offlineSync, city.id!);
        visibleTowns = await Town.db.find(node.offlineSync);
        retainedTowns = await Town.db.find(
          node.offlineSync,
          where: (t) => t.includeHiddenRows,
        );
      });

      test('then both the existing and newly inserted towns become hidden.', () {
        expect(visibleCity, isNull);
        expect(visibleTowns, isEmpty);
      });

      test('then both hidden towns retain their authored parent reference.', () {
        expect(
          {for (final town in retainedTowns) town.id: town.cityId},
          {
            existing.id: city.id,
            incoming.id: city.id,
          },
        );
      });
    });
  });
}

CrdtMergeInsert _insert(TableRow<UuidValue?> row, Hlc clock) => CrdtMergeInsert(
  uuidSpaceId: testCrdtUserId,
  tableName: row.table.tableName,
  uuidRowId: row.id!,
  uuidNodeId: clock.nodeId,
  hlcDatetime: clock.datetime,
  hlcCounter: clock.counter,
  data: row as SerializableModel,
);
