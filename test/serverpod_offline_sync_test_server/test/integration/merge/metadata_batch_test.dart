import 'dart:convert';

import 'package:serverpod/serverpod.dart' show DatabaseQueryException;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an edited city and a town arriving with another parent,', () {
    late SyncNode node;
    late City originalParent;
    late City replacementParent;
    late Town town;
    late Hlc originalNameClock;
    late CrdtMergeUpdate finalName;
    late CrdtMergeUpdate finalParent;
    late CrdtMergeSet changes;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      originalParent = City(id: const Uuid().v7obj(), name: 'original parent');
      replacementParent = City(id: const Uuid().v7obj(), name: 'replacement parent');
      town = Town(id: const Uuid().v7obj(), name: 'town', cityId: originalParent.id);
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await City.db.insert(node.offlineSync, [
          originalParent,
          replacementParent,
        ], transaction: tx);
        await City.db.updateRow(
          node.offlineSync,
          replacementParent.copyWith(name: 'locally edited'),
          columns: (t) => [t.name],
          transaction: tx,
        );
      });
      originalNameClock = (await _fieldClock(
        node,
        'city',
        replacementParent.id!,
        'name',
      ))!;
      final remote = Hlc(
        originalNameClock.datetime.add(const Duration(seconds: 1)),
        0,
        const Uuid().v7obj(),
      );
      finalName = _update(
        'city',
        replacementParent.id!,
        'name',
        'final name',
        Hlc(remote.datetime, 1, remote.nodeId),
      );
      finalParent = _update(
        'town',
        town.id!,
        'cityId',
        replacementParent.id,
        Hlc(remote.datetime, 3, remote.nodeId),
      );
      changes = [
        _update('city', replacementParent.id!, 'name', 'intermediate name', remote),
        finalName,
        CrdtMergeInsert(
          uuidSpaceId: testCrdtUserId,
          tableName: 'town',
          uuidRowId: town.id!,
          uuidNodeId: remote.nodeId,
          hlcDatetime: remote.datetime,
          hlcCounter: remote.counter + 2,
          data: town,
        ),
        finalParent,
        CrdtMergeDelete(
          uuidSpaceId: testCrdtUserId,
          tableName: 'city',
          uuidRowId: originalParent.id!,
          uuidNodeId: remote.nodeId,
          hlcDatetime: remote.datetime,
          hlcCounter: remote.counter + 4,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        ),
      ];
    });

    group(
      'when one merge edits the city, inserts and reparents the town, and deletes its old parent,',
      () {
        late City? mergedCity;
        late City? deletedParent;
        late Town? mergedTown;
        late Hlc? nameClock;
        late Hlc? parentClock;
        late String firstExport;
        late String replayedExport;

        setUpAll(() async {
          await node.offlineSync.db.mergeChanges(changes, spaceId: testCrdtUserId);
          mergedCity = await City.db.findById(node.offlineSync, replacementParent.id!);
          deletedParent = await City.db.findById(node.offlineSync, originalParent.id!);
          mergedTown = await Town.db.findById(node.offlineSync, town.id!);
          nameClock = await _fieldClock(node, 'city', replacementParent.id!, 'name');
          parentClock = await _fieldClock(node, 'town', town.id!, 'cityId');
          firstExport = await _export(node);

          await node.offlineSync.db.mergeChanges(changes, spaceId: testCrdtUserId);
          replayedExport = await _export(node);
        });

        test(
          'then the repeated city edit retains its newest value and authored clock.',
          () {
            expect(originalNameClock < finalName.hlc, isTrue);
            expect(mergedCity?.name, 'final name');
            expect(nameClock, finalName.hlc);
          },
        );

        test(
          'then the inserted town retains its new parent and authored clock after the old parent is deleted.',
          () {
            expect(deletedParent, isNull);
            expect(mergedTown, isNotNull);
            expect(mergedTown!.cityId, replacementParent.id);
            expect(parentClock, finalParent.hlc);
          },
        );

        test('then replay leaves the exported authored history byte stable.', () {
          expect(replayedExport, firstExport);
        });
      },
    );
  });

  group('Given two cities with existing name edits,', () {
    late SyncNode node;
    late City first;
    late City second;
    late Hlc firstClock;
    late Hlc secondClock;
    late Hlc incoming;

    setUpAll(() async {
      node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      first = City(id: const Uuid().v7obj(), name: 'first');
      second = City(id: const Uuid().v7obj(), name: 'second');
      await node.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
        await City.db.insert(node.offlineSync, [first, second], transaction: tx);
        await City.db.updateRow(
          node.offlineSync,
          first.copyWith(name: 'first edited'),
          columns: (t) => [t.name],
          transaction: tx,
        );
        await City.db.updateRow(
          node.offlineSync,
          second.copyWith(name: 'second edited'),
          columns: (t) => [t.name],
          transaction: tx,
        );
      });
      firstClock = (await _fieldClock(node, 'city', first.id!, 'name'))!;
      secondClock = (await _fieldClock(node, 'city', second.id!, 'name'))!;
      incoming = Hlc(
        secondClock.datetime.add(const Duration(seconds: 1)),
        0,
        const Uuid().v7obj(),
      );
    });

    group('when a merge contains a valid edit followed by an invalid null name,', () {
      Object? failure;
      late List<String> rolledBackNames;
      late List<Hlc?> rolledBackClocks;
      late CrdtMergeUpdate recovery;
      late City? recoveredCity;
      late Hlc? recoveredClock;

      setUpAll(() async {
        try {
          await node.offlineSync.db.mergeChanges([
            _update(
              'city',
              first.id!,
              'name',
              'must roll back',
              Hlc(incoming.datetime, 2, incoming.nodeId),
            ),
            _update(
              'city',
              second.id!,
              'name',
              null,
              Hlc(incoming.datetime, 3, incoming.nodeId),
            ),
          ], spaceId: testCrdtUserId);
        } on Exception catch (error) {
          failure = error;
        }
        rolledBackNames = [
          (await City.db.findById(node.offlineSync, first.id!))!.name,
          (await City.db.findById(node.offlineSync, second.id!))!.name,
        ];
        rolledBackClocks = [
          await _fieldClock(node, 'city', first.id!, 'name'),
          await _fieldClock(node, 'city', second.id!, 'name'),
        ];

        recovery = _update('city', first.id!, 'name', 'recovered', incoming);
        await node.offlineSync.db.mergeChanges([recovery], spaceId: testCrdtUserId);
        recoveredCity = await City.db.findById(node.offlineSync, first.id!);
        recoveredClock = await _fieldClock(node, 'city', first.id!, 'name');
      });

      test('then neither row retains values or clocks from the rejected merge.', () {
        expect(failure, isA<DatabaseQueryException>());
        expect(rolledBackNames, ['first edited', 'second edited']);
        expect(rolledBackClocks, [firstClock, secondClock]);
      });

      test(
        'then a subsequent merge can accept an edit older than the rejected edits.',
        () {
          expect(recoveredCity?.name, 'recovered');
          expect(recoveredClock, recovery.hlc);
        },
      );
    });
  });
}

CrdtMergeUpdate _update(
  String table,
  UuidValue row,
  String column,
  Object? value,
  Hlc clock,
) {
  return CrdtMergeUpdate(
    uuidSpaceId: testCrdtUserId,
    tableName: table,
    uuidRowId: row,
    uuidNodeId: clock.nodeId,
    hlcDatetime: clock.datetime,
    hlcCounter: clock.counter,
    columnName: column,
    value: value,
  );
}

Future<Hlc?> _fieldClock(
  SyncNode node,
  String table,
  UuidValue row,
  String column,
) async {
  final field = await CrdtDataField.db.findFirstRow(
    node.offlineSync,
    where: (t) =>
        t.row.tbl.name.equals(table) &
        t.row.uuidRowId.equals(row) &
        t.column.name.equals(column),
    include: CrdtDataField.include(node: CrdtNode.include()),
  );
  return field?.hlc;
}

Future<String> _export(SyncNode node) async {
  final changes = await node.sync
      .collectPendingChanges(
        node.raw,
        checkpointsBySpaceUuid: {testCrdtUserId: const []},
      )
      .toList();
  return jsonEncode(changes);
}
