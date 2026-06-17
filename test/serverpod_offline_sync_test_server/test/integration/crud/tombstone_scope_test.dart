import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given a person tombstone and a town row with the same UUID in the same scope,',
    () {
      late UuidValue sharedId;

      setUp(() async {
        sharedId = const Uuid().v7obj();

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: sharedId, name: 'shared id person'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(
            session,
            Town(id: sharedId, name: 'shared id town'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteWhere(
            session,
            where: (t) => t.id.equals(sharedId),
            transaction: tx,
          ),
        );
      });

      test('when finding the deleted person, then it is hidden.', () async {
        expect(await Person.db.findById(session, sharedId), isNull);
      });

      test(
        'when finding the town, then the person tombstone does not mask another table.',
        () async {
          expect(await Town.db.findById(session, sharedId), isNotNull);
        },
      );

      test(
        'when counting towns, then the person tombstone does not mask another table.',
        () async {
          expect(await Town.db.count(session), 1);
        },
      );

      test(
        'when updating the town, then the person tombstone does not mask another table.',
        () async {
          final town = await Town.db.findById(session, sharedId);
          final updated = await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.updateRow(
              session,
              town!.copyWith(name: 'renamed town'),
              transaction: tx,
            ),
          );

          expect(updated.name, 'renamed town');
        },
      );
    },
  );

  group('Given a row owned by one user on the same database,', () {
    late UuidValue rowId;
    late UuidValue otherUserId;
    late UuidValue otherUserNodeId;
    late Hlc otherUserInsertHlc;
    late CrdtMergeInsert otherUserInsert;

    setUp(() async {
      rowId = const Uuid().v7obj();
      otherUserId = const Uuid().v7obj();
      otherUserNodeId = const Uuid().v7obj();

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(id: rowId, name: 'shared row'),
          transaction: tx,
        ),
      );

      otherUserInsertHlc = Hlc(DateTime.now().toUtc(), 0, otherUserNodeId);
      otherUserInsert = CrdtMergeInsert(
        tableName: Person.t.tableName,
        uuidRowId: rowId,
        uuidNodeId: otherUserNodeId,
        hlcDatetime: otherUserInsertHlc.datetime,
        hlcCounter: otherUserInsertHlc.counter,
        data: Person(id: rowId, name: 'foreign row'),
      );
    });

    group('when merging an insert with the same row id from another user,', () {
      late Exception? mergeError;

      setUp(() async {
        mergeError = null;
        try {
          await session.db.mergeChanges([otherUserInsert], scopeId: otherUserId);
        } on Exception catch (e) {
          mergeError = e;
        }
      });

      test('then the sync fails with an integrity violation.', () async {
        expect(
          mergeError,
          isA<CrdtSyncIntegrityViolationException>()
              .having(
                (e) => e.violation.domainTableName,
                'violation.domainTableName',
                Person.t.tableName,
              )
              .having((e) => e.violation.uuidRowId, 'violation.uuidRowId', rowId)
              .having(
                (e) => e.violation.ownerScopeUuid,
                'violation.ownerScopeUuid',
                testCrdtUserId,
              )
              .having(
                (e) => e.violation.incomingScopeUuid,
                'violation.incomingScopeUuid',
                otherUserId,
              )
              .having(
                (e) => e.violation.type,
                'violation.type',
                CrdtSyncViolationType.ownershipCollision,
              )
              .having(
                (e) => e.violation.operation,
                'violation.operation',
                CrdtSyncViolationOperation.mergeInsert,
              )
              .having((e) => e.violation.id, 'violation.id', isNotNull),
        );
      });

      test('then the integrity violation is recorded durably.', () async {
        final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(rowId),
        );

        expect(violation, isNotNull);
        expect(violation!.domainTableName, Person.t.tableName);
        expect(violation.crdtDataRowId, isNull);
        expect(violation.type, CrdtSyncViolationType.ownershipCollision);
        expect(violation.ownerScopeUuid, testCrdtUserId);
        expect(violation.incomingScopeUuid, otherUserId);
        expect(violation.operation, CrdtSyncViolationOperation.mergeInsert);
        expect(violation.uuidNodeId, otherUserNodeId);
        expect(violation.hlcDatetime, otherUserInsertHlc.datetime);
        expect(violation.hlcCounter, otherUserInsertHlc.counter);
        expect(violation.occurrences, 1);
      });

      test('then no second CRDT tracker is recorded.', () async {
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.equals(rowId),
        );

        expect(crdtRows, hasLength(1));
      });

      test('then the owner row is not overwritten.', () async {
        final row = await Person.db.findById(testSession, rowId);

        expect(row, isNotNull);
        expect(row!.name, 'shared row');
      });
    });

    test(
      'when merging an insert with the same row id from another user twice, '
      'then the same integrity violation is updated.',
      () async {
        for (var i = 0; i < 2; i++) {
          await expectLater(
            session.db.mergeChanges([otherUserInsert], scopeId: otherUserId),
            throwsA(isA<CrdtSyncIntegrityViolationException>()),
          );
        }

        final violations = await CrdtSyncIntegrityViolation.db.find(
          session,
          where: (t) =>
              t.uuidRowId.equals(rowId) &
              t.type.equals(CrdtSyncViolationType.ownershipCollision) &
              t.operation.equals(CrdtSyncViolationOperation.mergeInsert),
        );

        expect(violations, hasLength(1));
        expect(violations.single.occurrences, 2);
      },
    );
  });

  group(
    'Given a row owned by one user on the same database and another user '
    'has a stale CRDT tracker for the row,',
    () {
      late UuidValue rowId;
      late UuidValue otherUserId;
      late CrdtScope otherScope;
      late CrdtDataRow staleTracker;

      setUp(() async {
        rowId = const Uuid().v7obj();
        otherUserId = const Uuid().v7obj();
        final otherUserNodeId = const Uuid().v7obj();

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: rowId, name: 'shared row'),
            transaction: tx,
          ),
        );

        final otherUserInsertHlc = Hlc(DateTime.now().toUtc(), 0, otherUserNodeId);
        final otherUserInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: rowId,
          uuidNodeId: otherUserNodeId,
          hlcDatetime: otherUserInsertHlc.datetime,
          hlcCounter: otherUserInsertHlc.counter,
          data: Person(id: rowId, name: 'foreign row'),
        );

        await expectLater(
          session.db.mergeChanges([otherUserInsert], scopeId: otherUserId),
          throwsA(isA<CrdtSyncIntegrityViolationException>()),
        );

        final table = await CrdtSchemaTable.db.findFirstRow(
          session,
          where: (t) => t.name.equals(Person.t.tableName),
        );

        otherScope = await CrdtScopeManager(session).getOrCreate(otherUserId);
        staleTracker = await CrdtDataRow.db.insertRow(
          session,
          CrdtDataRow(
            scopeId: otherScope.id!,
            tblId: table!.id!,
            uuidRowId: rowId,
            nodeId: otherScope.currentNode!.id!,
            hlcDatetime: otherUserInsertHlc.datetime,
            hlcCounter: otherUserInsertHlc.counter,
          ),
        );
      });

      test(
        'when collecting pending changes for outbound sync, '
        'then the sync fails with an integrity violation.',
        () async {
          final sync = CrdtSync(
            syncTables: [Person.t],
            serializationManager: session.db.serializationManager,
          );

          await expectLater(
            sync
                .collectPendingChanges(
                  session,
                  userId: otherUserId,
                  peerNodeId: const Uuid().v7obj(),
                  nodeCheckpoints: const [],
                )
                .toList(),
            throwsA(
              isA<CrdtSyncIntegrityViolationException>()
                  .having(
                    (e) => e.violation.operation,
                    'violation.operation',
                    CrdtSyncViolationOperation.outboundInsert,
                  )
                  .having(
                    (e) => e.violation.type,
                    'violation.type',
                    CrdtSyncViolationType.ownershipCollision,
                  )
                  .having(
                    (e) => e.violation.ownerScopeUuid,
                    'violation.ownerScopeUuid',
                    testCrdtUserId,
                  )
                  .having(
                    (e) => e.violation.incomingScopeUuid,
                    'violation.incomingScopeUuid',
                    otherUserId,
                  )
                  .having((e) => e.violation.id, 'violation.id', isNotNull),
            ),
          );

          final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
            session,
            where: (t) =>
                t.uuidRowId.equals(rowId) &
                t.incomingScopeUuid.equals(otherUserId) &
                t.type.equals(CrdtSyncViolationType.ownershipCollision) &
                t.operation.equals(CrdtSyncViolationOperation.outboundInsert),
          );

          expect(violation, isNotNull);
          expect(violation!.operation, CrdtSyncViolationOperation.outboundInsert);
          expect(violation.type, CrdtSyncViolationType.ownershipCollision);
          expect(violation.ownerScopeUuid, testCrdtUserId);
          expect(violation.incomingScopeUuid, otherUserId);
          expect(violation.crdtDataRowId, staleTracker.id);
          expect(violation.uuidRowId, rowId);
          expect(violation.uuidNodeId, otherScope.currentNode!.uuidNodeId);
          expect(violation.occurrences, 1);
        },
      );
    },
  );

  group('Given insert CRDT metadata whose domain row is missing,', () {
    late Person person;
    late CrdtDataRow crdtRow;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(id: const Uuid().v7obj(), name: 'orphan insert'),
          transaction: tx,
        ),
      );

      crdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;

      await Person.db.deleteWhere(
        testSession,
        where: (t) => t.id.equals(person.id),
      );
    });

    test(
      'when collecting pending changes, '
      'then the sync fails and records orphan metadata.',
      () async {
        final sync = CrdtSync(
          syncTables: [Person.t],
          serializationManager: session.db.serializationManager,
        );

        await expectLater(
          sync
              .collectPendingChanges(
                session,
                userId: testCrdtUserId,
                peerNodeId: const Uuid().v7obj(),
                nodeCheckpoints: const [],
              )
              .toList(),
          throwsA(
            isA<CrdtSyncIntegrityViolationException>()
                .having(
                  (e) => e.violation.operation,
                  'violation.operation',
                  CrdtSyncViolationOperation.outboundInsert,
                )
                .having(
                  (e) => e.violation.type,
                  'violation.type',
                  CrdtSyncViolationType.missingDomainRow,
                )
                .having(
                  (e) => e.violation.ownerScopeUuid,
                  'violation.ownerScopeUuid',
                  isNull,
                )
                .having(
                  (e) => e.violation.incomingScopeUuid,
                  'violation.incomingScopeUuid',
                  testCrdtUserId,
                )
                .having((e) => e.violation.id, 'violation.id', isNotNull),
          ),
        );

        final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
          session,
          where: (t) =>
              t.uuidRowId.equals(person.id) &
              t.type.equals(CrdtSyncViolationType.missingDomainRow) &
              t.operation.equals(CrdtSyncViolationOperation.outboundInsert),
        );

        expect(violation, isNotNull);
        expect(violation!.domainTableName, Person.t.tableName);
        expect(violation.type, CrdtSyncViolationType.missingDomainRow);
        expect(violation.operation, CrdtSyncViolationOperation.outboundInsert);
        expect(violation.ownerScopeUuid, isNull);
        expect(violation.incomingScopeUuid, testCrdtUserId);
        expect(violation.crdtDataRowId, crdtRow.id);
        expect(violation.uuidNodeId, crdtRow.node!.uuidNodeId);
        expect(violation.hlcDatetime, crdtRow.hlcDatetime);
        expect(violation.hlcCounter, crdtRow.hlcCounter);
        expect(violation.occurrences, 1);
      },
    );
  });

  group('Given update CRDT metadata whose domain row is missing,', () {
    late Person person;
    late CrdtDataRow crdtRow;
    late CrdtDataField nameField;
    late Hlc insertCheckpoint;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(id: const Uuid().v7obj(), name: 'before orphan update'),
          transaction: tx,
        ),
      );

      crdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
      insertCheckpoint = crdtRow.hlc;

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.updateRow(
          session,
          person.copyWith(name: 'after orphan update'),
          columns: (t) => [t.name],
          transaction: tx,
        ),
      );

      nameField = (await CrdtDataField.db.findFirstRow(
        session,
        where: (t) =>
            t.row.uuidRowId.equals(person.id) &
            t.column.name.equals(Person.t.name.columnName),
        include: CrdtDataField.include(node: CrdtNode.include()),
      ))!;

      await Person.db.deleteWhere(
        testSession,
        where: (t) => t.id.equals(person.id),
      );
    });

    test(
      'when collecting pending changes after the insert checkpoint, '
      'then the sync fails and records orphan metadata.',
      () async {
        final sync = CrdtSync(
          syncTables: [Person.t],
          serializationManager: session.db.serializationManager,
        );

        await expectLater(
          sync
              .collectPendingChanges(
                session,
                userId: testCrdtUserId,
                peerNodeId: const Uuid().v7obj(),
                nodeCheckpoints: [insertCheckpoint],
              )
              .toList(),
          throwsA(
            isA<CrdtSyncIntegrityViolationException>()
                .having(
                  (e) => e.violation.operation,
                  'violation.operation',
                  CrdtSyncViolationOperation.outboundUpdate,
                )
                .having(
                  (e) => e.violation.type,
                  'violation.type',
                  CrdtSyncViolationType.missingDomainRow,
                )
                .having(
                  (e) => e.violation.ownerScopeUuid,
                  'violation.ownerScopeUuid',
                  isNull,
                )
                .having(
                  (e) => e.violation.incomingScopeUuid,
                  'violation.incomingScopeUuid',
                  testCrdtUserId,
                )
                .having((e) => e.violation.id, 'violation.id', isNotNull),
          ),
        );

        final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
          session,
          where: (t) =>
              t.uuidRowId.equals(person.id) &
              t.type.equals(CrdtSyncViolationType.missingDomainRow) &
              t.operation.equals(CrdtSyncViolationOperation.outboundUpdate),
        );

        expect(violation, isNotNull);
        expect(violation!.domainTableName, Person.t.tableName);
        expect(violation.type, CrdtSyncViolationType.missingDomainRow);
        expect(violation.operation, CrdtSyncViolationOperation.outboundUpdate);
        expect(violation.ownerScopeUuid, isNull);
        expect(violation.incomingScopeUuid, testCrdtUserId);
        expect(violation.crdtDataRowId, crdtRow.id);
        expect(violation.uuidNodeId, nameField.node!.uuidNodeId);
        expect(violation.hlcDatetime, nameField.hlcDatetime);
        expect(violation.hlcCounter, nameField.hlcCounter);
        expect(violation.occurrences, 1);
      },
    );
  });

  group('Given delete CRDT metadata whose domain row is missing,', () {
    late Person person;
    late Hlc insertCheckpoint;
    late CrdtDataDeleted tombstone;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(id: const Uuid().v7obj(), name: 'orphan delete'),
          transaction: tx,
        ),
      );

      final crdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
      insertCheckpoint = crdtRow.hlc;

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      tombstone = (await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      ))!;

      await Person.db.deleteWhere(
        testSession,
        where: (t) => t.id.equals(person.id),
      );
    });

    test(
      'when collecting pending changes after the insert checkpoint, '
      'then the tombstone is emitted without an integrity violation.',
      () async {
        final sync = CrdtSync(
          syncTables: [Person.t],
          serializationManager: session.db.serializationManager,
        );

        final changes = await sync
            .collectPendingChanges(
              session,
              userId: testCrdtUserId,
              peerNodeId: const Uuid().v7obj(),
              nodeCheckpoints: [insertCheckpoint],
            )
            .toList();

        final delete = changes.whereType<CrdtMergeDelete>().single;
        expect(delete.tableName, Person.t.tableName);
        expect(delete.uuidRowId, person.id);
        expect(delete.uuidNodeId, tombstone.node!.uuidNodeId);
        expect(delete.hlcDatetime, tombstone.hlcDatetime);
        expect(delete.hlcCounter, tombstone.hlcCounter);
        expect(delete.clFlag, tombstone.clFlag);
        expect(delete.reason, tombstone.reason);

        final violationCount = await CrdtSyncIntegrityViolation.db.count(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
        );
        expect(violationCount, 0);
      },
    );
  });
}
