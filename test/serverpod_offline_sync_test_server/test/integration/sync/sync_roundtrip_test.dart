import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  final syncTables = [
    Address.t,
    Person.t,
    Town.t,
    Types.t,
    Unique.t,
  ];

  late OfflineSyncDatabaseSession offlineSyncSession;
  late OfflineSyncEngine offlineSync;

  setUp(() async {
    offlineSyncSession = OfflineSyncDatabaseSession.wraps(
      testSession,
      syncTables: syncTables,
    );
    await offlineSyncSession.db.initialize();

    offlineSync = OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
  });

  group('Given an inserted typed CRDT row,', () {
    late Types insertedRow;

    setUp(() async {
      insertedRow = await offlineSyncSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          return Types.db.insertRow(
            offlineSyncSession,
            Types(
              id: const Uuid().v7obj(),
              aBool: true,
              aDateTime: DateTime.utc(2026, 5, 8, 12, 34, 56),
              aText: 'text',
              anInt: 42,
              anInt64: BigInt.parse('9007199254740993'),
              aReal: 3.14,
              aBlob: [1, 2, 3, 4].toBlob(),
              anEnum: TypesEnum.gamma,
              optionalText: 'optional',
              optionalUuid: const Uuid().v7obj(),
            ),
            transaction: tx,
          );
        },
      );
    });

    test(
      'when pending changes are collected, '
      'then the row payload roundtrips with its original Dart type.',
      () async {
        final mergeSet = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final insert = mergeSet.inserts.single;
        expect(insert.uuidRowId, insertedRow.id);
        expect(insert.data, isA<Types>());

        final recoveredData = insert.data as Types;
        expect(recoveredData.aDateTime, insertedRow.aDateTime);
        expect(recoveredData.optionalUuid, insertedRow.optionalUuid);
        expect(recoveredData.anInt64, insertedRow.anInt64);
        expect(recoveredData.anEnum, TypesEnum.gamma);
        expect(recoveredData.aBlob.toBytes(), insertedRow.aBlob.toBytes());
      },
    );
  });

  group('Given an updated typed CRDT row,', () {
    late Types row;
    late Types updatedRow;

    setUp(() async {
      row = await offlineSyncSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return Types.db.insertRow(
          offlineSyncSession,
          Types(
            id: const Uuid().v7obj(),
            aBool: true,
            aDateTime: DateTime.utc(2026, 1, 1),
            aText: 'text',
            anInt: 42,
            anInt64: BigInt.from(99),
            aReal: 3.14,
            aBlob: [0, 1, 2].toBlob(),
            anEnum: TypesEnum.alpha,
            optionalText: 'optional',
          ),
          transaction: tx,
        );
      });

      updatedRow = row.copyWith(
        aDateTime: DateTime.utc(2027, 1, 2, 3, 4, 5),
        optionalUuid: const Uuid().v7obj(),
        anInt64: BigInt.parse('12345678901234567890'),
        aBlob: [7, 8, 9].toBlob(),
        anEnum: TypesEnum.beta,
      );

      await offlineSyncSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          await Types.db.updateRow(
            offlineSyncSession,
            updatedRow,
            transaction: tx,
          );
        },
      );
    });

    test(
      'when pending changes are collected, '
      'then the field values roundtrip with their original Dart types.',
      () async {
        final mergeSet = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final updates = {
          for (final update in mergeSet.updates) update.columnName: update,
        };

        final aDateTime = updates[Types.t.aDateTime.columnName]!;
        final optionalUuid = updates[Types.t.optionalUuid.columnName]!;
        final anInt64 = updates[Types.t.anInt64.columnName]!;
        final anEnum = updates[Types.t.anEnum.columnName]!;
        final aBlob = updates[Types.t.aBlob.columnName]!;

        expect(aDateTime.value, updatedRow.aDateTime);
        expect(optionalUuid.value, updatedRow.optionalUuid);
        expect(anInt64.value, updatedRow.anInt64);
        expect(anEnum.value, TypesEnum.beta);
        expect((aBlob.value as ByteData).toBytes(), updatedRow.aBlob.toBytes());
      },
    );
  });

  group('Given multiple inserted CRDT rows,', () {
    setUp(() async {
      for (var i = 0; i < 3; i++) {
        await offlineSyncSession.db.transactionForUser(
          testCrdtUserId,
          (tx) async {
            await Person.db.insertRow(
              offlineSyncSession,
              Person(id: const Uuid().v7obj(), name: 'person-$i'),
              transaction: tx,
            );
          },
        );
      }
    });

    test(
      'when collected pending changes are chunked, '
      'then each chunk is no larger than the batch size.',
      () async {
        final chunks = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .chunked(2)
            .toList();

        expect(chunks, hasLength(2));
        expect(chunks.map((chunk) => chunk.length), [2, 1]);
        final changes = chunks.expand((chunk) => chunk).toList();
        expect(changes.whereType<CrdtMergeInsert>(), hasLength(3));
      },
    );
  });

  group('Given an inserted row with an active set-null projection,', () {
    late Person attemptedParent;
    late Town child;

    setUp(() async {
      await offlineSyncSession.db.transactionForUser(testCrdtUserId, (tx) async {
        attemptedParent = await Person.db.insertRow(
          offlineSyncSession,
          Person(id: const Uuid().v7obj(), name: 'sync attempted mayor'),
          transaction: tx,
        );
        child = await Town.db.insertRow(
          offlineSyncSession,
          Town(
            id: const Uuid().v7obj(),
            name: 'sync projected town',
            mayorId: attemptedParent.id,
          ),
          transaction: tx,
        );
      });

      await offlineSyncSession.db.mergeChanges(
        [
          CrdtMergeDelete(
            uuidSpaceId: testCrdtUserId,
            tableName: Person.t.tableName,
            uuidRowId: attemptedParent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: DateTime.now().toUtc(),
            hlcCounter: 100, // Advanced to avoid tie-break with the insert.
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ],
        spaceId: testCrdtUserId,
      );

      final visibleChild = await Town.db.findById(offlineSyncSession, child.id!);
      expect(visibleChild, isNotNull);
      expect(visibleChild!.mayorId, isNull);
    });

    test(
      'when pending changes are collected, '
      'then the insert payload carries the attempted foreign key value.',
      () async {
        final mergeSet = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final childInsert = mergeSet.inserts
            .where((i) => i.tableName == Town.t.tableName && i.uuidRowId == child.id)
            .single;
        final childPayload = childInsert.data as Town;

        expect(childPayload.mayorId, attemptedParent.id);
      },
    );
  });

  group('Given an updated row with an active set-null projection,', () {
    late Town child;
    late UuidValue missingParentId;

    setUp(() async {
      missingParentId = const Uuid().v7obj();
      child = await offlineSyncSession.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(
          offlineSyncSession,
          Town(id: const Uuid().v7obj(), name: 'sync projected update town'),
          transaction: tx,
        ),
      );

      await offlineSyncSession.db.mergeChanges(
        [
          CrdtMergeUpdate(
            uuidSpaceId: testCrdtUserId,
            tableName: Town.t.tableName,
            uuidRowId: child.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: DateTime.now().toUtc(),
            hlcCounter: 100, // Advanced to avoid tie-break with the update.
            columnName: Town.t.mayorId.columnName,
            value: missingParentId,
          ),
        ],
        spaceId: testCrdtUserId,
      );

      final visibleChild = await Town.db.findById(offlineSyncSession, child.id!);
      expect(visibleChild, isNotNull);
      expect(visibleChild!.mayorId, isNull);
    });

    test(
      'when pending changes are collected, '
      'then the update payload carries the attempted foreign key value.',
      () async {
        final mergeSet = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {testCrdtUserId: const []},
            )
            .toList();

        final mayorUpdate = mergeSet.updates
            .where(
              (u) =>
                  u.tableName == Town.t.tableName &&
                  u.uuidRowId == child.id &&
                  u.columnName == Town.t.mayorId.columnName,
            )
            .single;

        expect(mayorUpdate.value, missingParentId);
      },
    );
  });

  group('Given personal and shared space rows authored by the same local node,', () {
    late UuidValue sharedSpaceId;
    late Person sharedPerson;
    late Person personalPerson;

    setUp(() async {
      sharedSpaceId = const Uuid().v7obj();
      final sharedSpace = await OfflineSyncSpaceManager(testSession).getOrCreate(
        sharedSpaceId,
      );

      await OfflineSyncSpaceMember.db.insertRow(
        testSession,
        OfflineSyncSpaceMember(
          spaceId: sharedSpace.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );

      sharedPerson = await offlineSyncSession.db.transactionForUser(
        testCrdtUserId,
        spaceId: sharedSpaceId,
        (tx) => Person.db.insertRow(
          offlineSyncSession,
          Person(id: const Uuid().v7obj(), name: 'shared-person'),
          transaction: tx,
        ),
      );

      personalPerson = await offlineSyncSession.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          offlineSyncSession,
          Person(id: const Uuid().v7obj(), name: 'personal-person'),
          transaction: tx,
        ),
      );
    });

    test(
      'when only the personal space checkpoint has advanced, '
      'then only the shared space row is collected.',
      () async {
        final personalSpace = await OfflineSyncSpace.db.findFirstRow(
          testSession,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
          include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
        );
        final sharedSpace = await OfflineSyncSpace.db.findFirstRow(
          testSession,
          where: (t) => t.uuidSpaceId.equals(sharedSpaceId),
          include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
        );
        final personalTracker = await CrdtDataRow.db.findFirstRow(
          testSession,
          where: (t) => t.uuidRowId.equals(personalPerson.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(
          personalSpace!.currentNode!.uuidNodeId,
          sharedSpace!.currentNode!.uuidNodeId,
        );

        final changes = await offlineSync
            .collectPendingChanges(
              testSession,
              checkpointsBySpaceUuid: {
                // Simulate the personal space checkpoint advancing by passing
                // the personal tracker's HLC and not the shared space's HLC.
                testCrdtUserId: [personalTracker!.hlc],
                sharedSpaceId: const [],
              },
            )
            .toList();

        final changedRowIds = changes.map((change) => change.uuidRowId);
        expect(changedRowIds, contains(sharedPerson.id));
        expect(changedRowIds, isNot(contains(personalPerson.id)));
      },
    );
  });

  group('Given existing spaces with different current CRDT nodes,', () {
    late UuidValue firstSpaceId;
    late UuidValue secondSpaceId;
    late CrdtNode firstNode;
    late Hlc newerSecondNodeHlc;
    late OfflineSyncSpace secondSpace;

    setUp(() async {
      firstSpaceId = const Uuid().v7obj();
      secondSpaceId = const Uuid().v7obj();

      // First space: already on this replica's stable current node (older clock).
      final firstNodeId = const Uuid().v7obj();
      firstNode = await CrdtNode.db.insertRow(
        testSession,
        CrdtNode(
          uuidNodeId: firstNodeId,
          lastHlc: Hlc(DateTime.utc(2026, 5, 8), 1, firstNodeId),
        ),
      );
      await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: firstSpaceId, currentNodeId: firstNode.id),
      );

      // Second space: opened on a different node with a newer clock.
      final secondNodeId = const Uuid().v7obj();
      newerSecondNodeHlc = Hlc(DateTime.utc(2026, 5, 9), 1, secondNodeId);
      final secondNode = await CrdtNode.db.insertRow(
        testSession,
        CrdtNode(uuidNodeId: secondNodeId, lastHlc: newerSecondNodeHlc),
      );
      secondSpace = await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: secondSpaceId, currentNodeId: secondNode.id),
      );
    });

    test(
      'when getOrCreate reopens the second space, '
      'then it reuses the first space node with the second space HLC instead of creating a new node.',
      () async {
        final adoptedSpace = await OfflineSyncSpaceManager(
          testSession,
        ).getOrCreate(secondSpaceId);
        final expectedHlc = newerSecondNodeHlc.copyWith(
          nodeId: firstNode.uuidNodeId,
        );

        expect(adoptedSpace.currentNodeId, firstNode.id);
        expect(adoptedSpace.currentNode!.lastHlc, expectedHlc);

        final persistedSecondSpace = await OfflineSyncSpace.db.findById(
          testSession,
          secondSpace.id!,
          include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
        );
        final spaceNode = await OfflineSyncSpaceNode.db.findFirstRow(
          testSession,
          where: (t) =>
              t.spaceId.equals(secondSpace.id) & t.nodeId.equals(firstNode.id),
        );

        expect(persistedSecondSpace!.currentNodeId, firstNode.id);
        expect(persistedSecondSpace.currentNode!.lastHlc, expectedHlc);
        expect(spaceNode, isNotNull);
      },
    );
  });

  test(
    'Given a CRDT node without local changes, '
    'when synchronization checkpoints are created, '
    'then one fresh checkpoint for the local node is included.',
    () async {
      final space = await OfflineSyncSpaceManager(
        testSession,
      ).getOrCreate(testCrdtUserId);
      final sinceHlc = await offlineSync.createSyncSinceHlc(
        testSession,
        spaceId: testCrdtUserId,
      );

      expect(sinceHlc.uuidSpaceId, testCrdtUserId);
      expect(sinceHlc.nodeCheckpoints, hasLength(1));
      expect(sinceHlc.nodeCheckpoints.single.nodeId, space.currentNode!.uuidNodeId);
      expect(
        sinceHlc.nodeCheckpoints.single,
        greaterThan(Hlc.zero(sinceHlc.nodeCheckpoints.single.nodeId)),
      );
    },
  );
}

extension on List<int> {
  ByteData toBlob() => ByteData.sublistView(Uint8List.fromList(this));
}

extension on ByteData {
  List<int> toBytes() => buffer.asUint8List();
}
