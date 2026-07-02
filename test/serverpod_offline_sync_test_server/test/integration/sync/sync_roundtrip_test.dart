import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
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

  late CrdtDatabaseSession crdtSession;
  late CrdtSync crdtSync;

  setUp(() async {
    crdtSession = CrdtDatabaseSession.wraps(testSession, syncTables: syncTables);
    await crdtSession.db.initialize();

    crdtSync = CrdtSync(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
  });

  group('Given an inserted typed CRDT row', () {
    late Types insertedRow;

    setUp(() async {
      insertedRow = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          return Types.db.insertRow(
            crdtSession,
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
      'when pending changes are collected '
      'then the row payload roundtrips with its original Dart type.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
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

  group('Given inserted CRDT rows', () {
    setUp(() async {
      for (var i = 0; i < 3; i++) {
        await crdtSession.db.transactionForUser(
          testCrdtUserId,
          (tx) async {
            await Person.db.insertRow(
              crdtSession,
              Person(id: const Uuid().v7obj(), name: 'person-$i'),
              transaction: tx,
            );
          },
        );
      }
    });

    test(
      'when collected pending changes are chunked '
      'then each chunk is no larger than the batch size.',
      () async {
        final chunks = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
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

  group('Given personal and shared scope rows authored by the same local node', () {
    late UuidValue sharedScopeId;
    late Person sharedPerson;
    late Person personalPerson;

    setUp(() async {
      sharedScopeId = const Uuid().v7obj();
      final sharedScope = await CrdtScopeManager(
        testSession,
      ).getOrCreate(sharedScopeId);
      await CrdtScopeMember.db.insertRow(
        testSession,
        CrdtScopeMember(
          scopeId: sharedScope.id!,
          userUuid: testCrdtUserId,
          role: CrdtScopeRole.readWrite,
        ),
      );

      sharedPerson = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        scopeId: sharedScopeId,
        (tx) => Person.db.insertRow(
          crdtSession,
          Person(id: const Uuid().v7obj(), name: 'shared-person'),
          transaction: tx,
        ),
      );
      personalPerson = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          crdtSession,
          Person(id: const Uuid().v7obj(), name: 'personal-person'),
          transaction: tx,
        ),
      );
    });

    test(
      'when only the personal scope checkpoint has advanced '
      'then the shared scope row is still collected.',
      () async {
        final personalScope = await CrdtScope.db.findFirstRow(
          testSession,
          where: (t) => t.uuidScopeId.equals(testCrdtUserId),
          include: CrdtScope.include(currentNode: CrdtNode.include()),
        );
        final sharedScope = await CrdtScope.db.findFirstRow(
          testSession,
          where: (t) => t.uuidScopeId.equals(sharedScopeId),
          include: CrdtScope.include(currentNode: CrdtNode.include()),
        );
        final personalTracker = await CrdtDataRow.db.findFirstRow(
          testSession,
          where: (t) => t.uuidRowId.equals(personalPerson.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(
          personalScope!.currentNode!.uuidNodeId,
          sharedScope!.currentNode!.uuidNodeId,
        );

        final changes = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {
                testCrdtUserId: [personalTracker!.hlc],
                sharedScopeId: const [],
              },
            )
            .toList();

        expect(changes.map((change) => change.uuidRowId), contains(sharedPerson.id));
        expect(
          changes.map((change) => change.uuidRowId),
          isNot(contains(personalPerson.id)),
        );
      },
    );
  });

  group('Given existing scopes with different current CRDT nodes', () {
    late UuidValue firstScopeId;
    late UuidValue secondScopeId;
    late CrdtNode firstNode;
    late Hlc newerSecondNodeHlc;
    late CrdtScope secondScope;

    setUp(() async {
      firstScopeId = const Uuid().v7obj();
      secondScopeId = const Uuid().v7obj();
      final firstNodeId = const Uuid().v7obj();
      final secondNodeId = const Uuid().v7obj();
      firstNode = await CrdtNode.db.insertRow(
        testSession,
        CrdtNode(
          uuidNodeId: firstNodeId,
          lastHlc: Hlc(DateTime.utc(2026, 5, 8), 1, firstNodeId),
        ),
      );
      newerSecondNodeHlc = Hlc(DateTime.utc(2026, 5, 9), 1, secondNodeId);
      final secondNode = await CrdtNode.db.insertRow(
        testSession,
        CrdtNode(uuidNodeId: secondNodeId, lastHlc: newerSecondNodeHlc),
      );
      await CrdtScope.db.insertRow(
        testSession,
        CrdtScope(uuidScopeId: firstScopeId, currentNodeId: firstNode.id),
      );
      secondScope = await CrdtScope.db.insertRow(
        testSession,
        CrdtScope(uuidScopeId: secondScopeId, currentNodeId: secondNode.id),
      );
    });

    test(
      'when the second scope is opened '
      'then it adopts the stable current node and preserves the newest clock.',
      () async {
        final adoptedScope = await CrdtScopeManager(
          testSession,
        ).getOrCreate(secondScopeId);
        final expectedHlc = newerSecondNodeHlc.copyWith(
          nodeId: firstNode.uuidNodeId,
        );

        expect(adoptedScope.currentNodeId, firstNode.id);
        expect(adoptedScope.currentNode!.lastHlc, expectedHlc);

        final persistedSecondScope = await CrdtScope.db.findById(
          testSession,
          secondScope.id!,
          include: CrdtScope.include(currentNode: CrdtNode.include()),
        );
        final scopeNode = await CrdtScopeNode.db.findFirstRow(
          testSession,
          where: (t) =>
              t.scopeId.equals(secondScope.id) & t.nodeId.equals(firstNode.id),
        );

        expect(persistedSecondScope!.currentNodeId, firstNode.id);
        expect(persistedSecondScope.currentNode!.lastHlc, expectedHlc);
        expect(scopeNode, isNotNull);
      },
    );
  });

  group('Given an updated typed CRDT row', () {
    late Types row;
    late Types updatedRow;

    setUp(() async {
      row = await crdtSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return Types.db.insertRow(
          crdtSession,
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

      await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          await Types.db.updateRow(
            crdtSession,
            updatedRow,
            transaction: tx,
          );
        },
      );
    });

    test(
      'when pending changes are collected '
      'then the field values roundtrip with their original Dart types.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
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

  group('Given an inserted row with an active set-null projection', () {
    late Person attemptedParent;
    late Town child;

    setUp(() async {
      await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        attemptedParent = await Person.db.insertRow(
          crdtSession,
          Person(id: const Uuid().v7obj(), name: 'sync attempted mayor'),
          transaction: tx,
        );
        child = await Town.db.insertRow(
          crdtSession,
          Town(
            id: const Uuid().v7obj(),
            name: 'sync projected town',
            mayorId: attemptedParent.id,
          ),
          transaction: tx,
        );
      });

      await crdtSession.db.mergeChanges(
        [
          CrdtMergeDelete(
            uuidScopeId: testCrdtUserId,
            tableName: Person.t.tableName,
            uuidRowId: attemptedParent.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: DateTime.now().toUtc(),
            hlcCounter: 100, // Advanced to avoid tie-break with the insert.
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ],
        scopeId: testCrdtUserId,
      );

      final visibleChild = await Town.db.findById(crdtSession, child.id!);
      expect(visibleChild, isNotNull);
      expect(visibleChild!.mayorId, isNull);
    });

    test(
      'when pending changes are collected '
      'then the insert payload carries the attempted foreign key value.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
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

  group('Given an updated row with an active set-null projection', () {
    late Town child;
    late UuidValue missingParentId;

    setUp(() async {
      missingParentId = const Uuid().v7obj();
      child = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(
          crdtSession,
          Town(id: const Uuid().v7obj(), name: 'sync projected update town'),
          transaction: tx,
        ),
      );

      await crdtSession.db.mergeChanges(
        [
          CrdtMergeUpdate(
            uuidScopeId: testCrdtUserId,
            tableName: Town.t.tableName,
            uuidRowId: child.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: DateTime.now().toUtc(),
            hlcCounter: 100, // Advanced to avoid tie-break with the update.
            columnName: Town.t.mayorId.columnName,
            value: missingParentId,
          ),
        ],
        scopeId: testCrdtUserId,
      );

      final visibleChild = await Town.db.findById(crdtSession, child.id!);
      expect(visibleChild, isNotNull);
      expect(visibleChild!.mayorId, isNull);
    });

    test(
      'when pending changes are collected '
      'then the update payload carries the attempted foreign key value.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              checkpointsByScopeUuid: {testCrdtUserId: const []},
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

  test(
    'Given a CRDT node without local changes '
    'when synchronization checkpoints are created '
    'then one fresh checkpoint for the local node is included.',
    () async {
      final scope = await CrdtScopeManager(testSession).getOrCreate(testCrdtUserId);
      final sinceHlc = await crdtSync.createSyncSinceHlc(
        testSession,
        scopeId: testCrdtUserId,
      );

      expect(sinceHlc.uuidScopeId, testCrdtUserId);
      expect(sinceHlc.localNodeId, scope.currentNode!.uuidNodeId);
      expect(sinceHlc.nodeCheckpoints, hasLength(1));
      expect(sinceHlc.nodeCheckpoints.single.nodeId, scope.currentNode!.uuidNodeId);
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
