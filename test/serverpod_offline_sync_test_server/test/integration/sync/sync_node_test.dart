import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  final syncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];

  late CrdtSync crdtSync;
  late CrdtDatabaseSession crdtSession;

  setUp(() async {
    crdtSession = CrdtDatabaseSession.wraps(testSession, syncTables: syncTables);
    await crdtSession.db.initialize();

    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
    crdtSync = CrdtSync.instance;
  });

  test(
    'Given a mismatching sync tables hash when syncNodeForUser is called then the merge is rejected.',
    () async {
      await expectLater(
        crdtSync
            .syncNodeForUser(
              testSession,
              userId: testCrdtUserId,
              syncTablesHash: 'wrong-hash',
              lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
              changes: Stream<CrdtMergeChange?>.value(null),
            )
            .drain<void>(),
        throwsA(
          isA<SyncTablesHashMismatchException>()
              .having((e) => e.received, 'received', 'wrong-hash')
              .having(
                (e) => e.expected,
                'expected',
                CrdtSync.computeSyncTablesHash(syncTables),
              ),
        ),
      );
    },
  );

  test(
    'Given a typed row insert when syncNodeForUser is called then the merge insert data roundtrips with its original field types.',
    () async {
      final insertedRow = await crdtSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return client.Types.db.insertRow(
          crdtSession,
          _typesRow(
            id: const Uuid().v7obj(),
            aDateTime: DateTime.utc(2026, 5, 8, 12, 34, 56),
            optionalUuid: const Uuid().v7obj(),
            anInt64: BigInt.parse('9007199254740993'),
            aBlob: _bytesToBlob([1, 2, 3, 4]),
            anEnum: client.TypesEnum.gamma,
          ),
          transaction: tx,
        );
      });

      final events = await crdtSync
          .syncNodeForUser(
            testSession,
            userId: testCrdtUserId,
            syncTablesHash: CrdtSync.computeSyncTablesHash(syncTables),
            lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
            changes: Stream<CrdtMergeChange?>.value(null),
          )
          .toList();

      expect(events.last, isNull);

      final insert = events.whereType<CrdtMergeInsert>().single;
      final streamedRow = insert.data as client.Types;

      expect(insert.uuidRowId, insertedRow.id);
      expect(streamedRow.aDateTime, insertedRow.aDateTime);
      expect(streamedRow.optionalUuid, insertedRow.optionalUuid);
      expect(streamedRow.anInt64, insertedRow.anInt64);
      expect(streamedRow.anEnum, client.TypesEnum.gamma);
      expect(_blobToBytes(streamedRow.aBlob), _blobToBytes(insertedRow.aBlob));
    },
  );

  test(
    'Given typed field updates when syncNodeForUser is called then the merge update values roundtrip with their original field types.',
    () async {
      final row = await crdtSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return client.Types.db.insertRow(
          crdtSession,
          _typesRow(id: const Uuid().v7obj()),
          transaction: tx,
        );
      });

      final rowMetadata = await CrdtDataRow.db.findFirstRow(
        testSession,
        where: (t) => t.uuidRowId.equals(row.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      );
      final lastSyncHlc = rowMetadata!.hlc;

      final updatedRow = row.copyWith(
        aDateTime: DateTime.utc(2027, 1, 2, 3, 4, 5),
        optionalUuid: const Uuid().v7obj(),
        anInt64: BigInt.parse('12345678901234567890'),
        aBlob: _bytesToBlob([7, 8, 9]),
        anEnum: client.TypesEnum.beta,
      );

      await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        await client.Types.db.updateRow(
          crdtSession,
          updatedRow,
          columns: (t) => [
            t.aDateTime,
            t.optionalUuid,
            t.anInt64,
            t.aBlob,
            t.anEnum,
          ],
          transaction: tx,
        );
      });

      final events = await crdtSync
          .syncNodeForUser(
            testSession,
            userId: testCrdtUserId,
            syncTablesHash: CrdtSync.computeSyncTablesHash(syncTables),
            lastSyncHlc: lastSyncHlc,
            changes: Stream<CrdtMergeChange?>.value(null),
          )
          .toList();

      final updates = {
        for (final update in events.whereType<CrdtMergeUpdate>())
          update.columnName: update,
      };

      expect(
        updates[client.Types.t.aDateTime.columnName]!.value,
        updatedRow.aDateTime,
      );
      expect(
        updates[client.Types.t.optionalUuid.columnName]!.value,
        updatedRow.optionalUuid,
      );
      expect(
        updates[client.Types.t.anInt64.columnName]!.value,
        updatedRow.anInt64,
      );
      expect(
        updates[client.Types.t.anEnum.columnName]!.value,
        client.TypesEnum.beta,
      );
      expect(
        _blobToBytes(updates[client.Types.t.aBlob.columnName]!.value as ByteData),
        _blobToBytes(updatedRow.aBlob),
      );
    },
  );

  test(
    'Given pending changes on both nodes when syncNodeForUser is called then server changes are streamed and client changes are merged.',
    () async {
      final serverPerson = await crdtSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return client.Person.db.insertRow(
          crdtSession,
          client.Person(id: const Uuid().v7obj(), name: 'server-person'),
          transaction: tx,
        );
      });

      final remoteNodeId = const Uuid().v7obj();
      final clientPerson = client.Person(
        id: const Uuid().v7obj(),
        name: 'client-person',
      );
      final clientInsert = CrdtMergeInsert(
        tableName: client.Person.t.tableName,
        uuidRowId: clientPerson.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: DateTime.utc(2026, 5, 8, 10),
        hlcCounter: 0,
        data: clientPerson,
      );

      final events = await crdtSync
          .syncNodeForUser(
            testSession,
            userId: testCrdtUserId,
            syncTablesHash: CrdtSync.computeSyncTablesHash(syncTables),
            lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
            changes: Stream<CrdtMergeChange?>.fromIterable([clientInsert, null]),
          )
          .toList();

      expect(events.last, isNull);

      final streamedInsert = events.whereType<CrdtMergeInsert>().singleWhere(
        (change) => change.uuidRowId == serverPerson.id,
      );
      expect((streamedInsert.data as client.Person).name, serverPerson.name);

      final mergedClientPerson = await client.Person.db.findById(
        testSession,
        clientPerson.id!,
      );
      expect(mergedClientPerson, isNotNull);
      expect(mergedClientPerson!.name, clientPerson.name);
    },
  );

  test(
    'Given two nodes with pending local changes when syncNodeForUser runs on both sides continuously then they converge to the same end state.',
    () async {
      final peerDirectory = await Directory.systemTemp.createTemp(
        'offline_first_peer_',
      );
      final peerSession = await client.Client(
        'http://localhost:8081/',
      ).createSession('${peerDirectory.path}/peer.db', isDebugMode: true);
      final peerCrdtSession = CrdtDatabaseSession.wraps(
        peerSession,
        syncTables: syncTables,
      );
      await peerCrdtSession.db.initialize();

      addTearDown(() async {
        await peerSession.close();
        if (peerDirectory.existsSync()) {
          await peerDirectory.delete(recursive: true);
        }
      });

      final syncTablesHash = CrdtSync.computeSyncTablesHash(syncTables);
      final sharedPersonId = const Uuid().v7obj();

      await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        await client.Person.db.insertRow(
          crdtSession,
          client.Person(
            id: sharedPersonId,
            name: 'base-name',
            surname: 'base-surname',
          ),
          transaction: tx,
        );
      });

      final initialServerChanges = await crdtSync
          .syncNodeForUser(
            testSession,
            userId: testCrdtUserId,
            syncTablesHash: syncTablesHash,
            lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
            changes: Stream<CrdtMergeChange?>.value(null),
          )
          .toList();

      await crdtSync
          .syncNodeForUser(
            peerSession,
            userId: testCrdtUserId,
            syncTablesHash: syncTablesHash,
            lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
            changes: Stream<CrdtMergeChange?>.fromIterable(initialServerChanges),
          )
          .drain<void>();

      final primarySharedPerson = await client.Person.db.findById(
        testSession,
        sharedPersonId,
      );
      final peerSharedPerson = await client.Person.db.findById(
        peerSession,
        sharedPersonId,
      );

      await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        await client.Person.db.updateRow(
          crdtSession,
          primarySharedPerson!.copyWith(name: 'server-name'),
          columns: (t) => [t.name],
          transaction: tx,
        );
        await client.Person.db.insertRow(
          crdtSession,
          client.Person(id: const Uuid().v7obj(), name: 'server-only'),
          transaction: tx,
        );
      });

      await peerCrdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        await client.Person.db.updateRow(
          peerCrdtSession,
          peerSharedPerson!.copyWith(surname: 'client-surname'),
          columns: (t) => [t.surname],
          transaction: tx,
        );
        await client.Person.db.insertRow(
          peerCrdtSession,
          client.Person(id: const Uuid().v7obj(), name: 'client-only'),
          transaction: tx,
        );
      });

      final primaryInbound = StreamController<CrdtMergeChange?>();
      final peerInbound = StreamController<CrdtMergeChange?>();

      Future<void> forwardChanges(
        Stream<CrdtMergeChange?> outbound,
        StreamController<CrdtMergeChange?> inbound,
      ) async {
        await outbound.forEach(inbound.add);
        await inbound.close();
      }

      final primarySync = crdtSync.syncNodeForUser(
        testSession,
        userId: testCrdtUserId,
        syncTablesHash: syncTablesHash,
        lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
        changes: primaryInbound.stream,
      );
      final peerSync = crdtSync.syncNodeForUser(
        peerSession,
        userId: testCrdtUserId,
        syncTablesHash: syncTablesHash,
        lastSyncHlc: Hlc.zero(const Uuid().v7obj()),
        changes: peerInbound.stream,
      );

      await Future.wait([
        forwardChanges(primarySync, peerInbound),
        forwardChanges(peerSync, primaryInbound),
      ]);

      final primaryState = await _personState(
        () => client.Person.db.find(testSession, orderBy: (t) => t.id),
      );
      final peerState = await _personState(
        () => client.Person.db.find(peerSession, orderBy: (t) => t.id),
      );

      expect(primaryState, peerState);
      expect(
        primaryState,
        containsAll([
          '$sharedPersonId:server-name:client-surname',
          isA<String>().having(
            (value) => value.contains(':server-only:'),
            'server-only row',
            isTrue,
          ),
          isA<String>().having(
            (value) => value.contains(':client-only:'),
            'client-only row',
            isTrue,
          ),
        ]),
      );
    },
  );
}

client.Types _typesRow({
  required UuidValue id,
  DateTime? aDateTime,
  UuidValue? optionalUuid,
  BigInt? anInt64,
  ByteData? aBlob,
  client.TypesEnum? anEnum,
}) {
  return client.Types(
    id: id,
    aBool: true,
    aDateTime: aDateTime ?? DateTime.utc(2026, 1, 1),
    aText: 'text',
    anInt: 42,
    anInt64: anInt64 ?? BigInt.from(99),
    aReal: 3.14,
    aBlob: aBlob ?? _bytesToBlob([0, 1, 2]),
    anEnum: anEnum ?? client.TypesEnum.alpha,
    optionalText: 'optional',
    optionalUuid: optionalUuid,
  );
}

ByteData _bytesToBlob(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

List<int> _blobToBytes(ByteData value) => value.buffer.asUint8List();

Future<List<String>> _personState(
  Future<List<client.Person>> Function() loadRows,
) async {
  final rows = await loadRows();
  return [
    for (final row in rows) '${row.id}:${row.name}:${row.surname ?? ''}',
  ];
}
