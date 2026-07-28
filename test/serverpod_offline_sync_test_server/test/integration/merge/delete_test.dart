import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeSet;

  group('Given a table with an existing row and a newer remote delete,', () {
    late Person person;
    late Hlc rowHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteDelete;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'remote delete'),
          transaction: tx,
        ),
      );

      final crdtRow = await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      );
      rowHlc = crdtRow!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteDelete = CrdtMergeDelete(
        uuidScopeId: testCrdtUserId,
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: rowHlc.datetime.advance(),
        hlcCounter: 0,
        clFlag: 2,
        reason: CrdtDataDeletedReason.userDelete,
      );

      mergeSet = [remoteDelete];
    });

    group('when merging,', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );
      });

      test('then the row is hidden by the tombstone.', () async {
        expect(await Person.db.findById(session, person.id!), isNull);
        expect(
          await Person.db.findFirstRow(
            session,
            where: (t) => t.id.equals(person.id) & t.includeHiddenRows,
          ),
          isNotNull,
        );
      });

      test('then the tombstone is recorded as deleted.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isTrue);
        expect(tombstone.clFlag, 2);
        expect(tombstone.reason, CrdtDataDeletedReason.userDelete);
        expect(tombstone.hlc, remoteDelete.hlc);
      });
    });
  });

  group(
    'Given a table with an implicitly visible row and an older remote delete,',
    () {
      late Person person;
      late Hlc rowHlc;
      late UuidValue remoteNodeId;
      late CrdtMergeDelete remoteDelete;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'older remote delete'),
            transaction: tx,
          ),
        );

        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );
        rowHlc = crdtRow!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remoteDelete = CrdtMergeDelete(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: rowHlc.datetime.retreat(),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        );
        mergeSet = [remoteDelete];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the row is hidden by the later generation.', () async {
          expect(await Person.db.findById(session, person.id!), isNull);
        });

        test('then the winning generation keeps its event HLC and node.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(person.id),
            include: CrdtDataDeleted.include(node: CrdtNode.include()),
          );

          expect(tombstone, isNotNull);
          expect(tombstone!.clFlag, 2);
          expect(tombstone.reason, CrdtDataDeletedReason.userDelete);
          expect(tombstone.hlc, remoteDelete.hlc);
          expect(tombstone.node!.uuidNodeId, remoteNodeId);
        });
      });
    },
  );

  group('Given a table with a deleted row and a same-generation newer event,', () {
    late Person person;
    late Hlc tombstoneHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteDelete;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'same generation'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      );
      tombstoneHlc = tombstone!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteDelete = CrdtMergeDelete(
        uuidScopeId: testCrdtUserId,
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.advance(),
        hlcCounter: 0,
        clFlag: 2,
        reason: CrdtDataDeletedReason.userCascadeDelete,
      );
      mergeSet = [remoteDelete];
    });

    group('when merging,', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );
      });

      test('then the same-generation metadata tie-break uses the newer HLC.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.clFlag, 2);
        expect(tombstone.reason, CrdtDataDeletedReason.userCascadeDelete);
        expect(tombstone.hlc, remoteDelete.hlc);
        expect(tombstone.node!.uuidNodeId, remoteNodeId);
      });
    });
  });

  group('Given a table with a deleted row and a newer remote restore,', () {
    late Person person;
    late Hlc tombstoneHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteRestore;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'remote delete'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      );
      tombstoneHlc = tombstone!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteRestore = CrdtMergeDelete(
        uuidScopeId: testCrdtUserId,
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.advance(),
        hlcCounter: 0,
        clFlag: 3,
        reason: CrdtDataDeletedReason.userReinsert,
      );

      mergeSet = [remoteRestore];
    });

    group('when merging,', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );
      });

      test('then the row becomes visible again.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, person.name);
      });

      test('then the tombstone is recorded as restored.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isFalse);
        expect(tombstone.clFlag, 3);
        expect(tombstone.reason, CrdtDataDeletedReason.userReinsert);
      });
    });
  });

  group('Given a table with a restored row and an older remote delete,', () {
    late Person person;
    late Hlc tombstoneHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteRestore;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'restored now'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      // Restore the row by inserting it again.
      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, person, transaction: tx),
      );

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      );
      tombstoneHlc = tombstone!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteRestore = CrdtMergeDelete(
        uuidScopeId: testCrdtUserId,
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.retreat(),
        hlcCounter: 0,
        clFlag: 2,
        reason: CrdtDataDeletedReason.userDelete,
      );

      mergeSet = [remoteRestore];
    });

    group('when merging,', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );
      });

      test('then the row is still visible.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, person.name);
      });

      test('then the tombstone is not updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isFalse);
        expect(tombstone.hlc, tombstoneHlc);
      });
    });
  });

  group(
    'Given a table with a restored row and an older remote delete from a later generation,',
    () {
      late Person person;
      late Hlc tombstoneHlc;
      late UuidValue remoteNodeId;
      late CrdtMergeDelete remoteDelete;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'deleted later'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, person, transaction: tx),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, person, transaction: tx),
        );

        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );
        tombstoneHlc = tombstone!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remoteDelete = CrdtMergeDelete(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: tombstoneHlc.datetime.retreat(),
          hlcCounter: 0,
          clFlag: 4,
          reason: CrdtDataDeletedReason.userDelete,
        );
        mergeSet = [remoteDelete];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the row is hidden by the later generation.', () async {
          expect(await Person.db.findById(session, person.id!), isNull);
        });

        test('then the tombstone records the later generation.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(person.id),
            include: CrdtDataDeleted.include(node: CrdtNode.include()),
          );

          expect(tombstone, isNotNull);
          expect(tombstone!.clFlag, 4);
          expect(tombstone.reason, CrdtDataDeletedReason.userDelete);
          expect(tombstone.hlc, remoteDelete.hlc);
          expect(tombstone.node!.uuidNodeId, remoteNodeId);
        });
      });
    },
  );

  group(
    'Given a table with an existing row and a newer remote delete with a '
    'non-synced projection reason,',
    () {
      late Person person;
      late CrdtMergeDelete remoteDelete;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'projection reason delete'),
            transaction: tx,
          ),
        );

        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        remoteDelete = CrdtMergeDelete(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: crdtRow!.hlc.datetime.advance(),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.uniqueLoser,
        );

        mergeSet = [remoteDelete];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the non-synced delete is ignored and the row stays visible.',
          () async {
            final row = await Person.db.findById(session, person.id!);

            expect(row, isNotNull);
            expect(row!.name, person.name);
          },
        );

        test('then no tombstone metadata is recorded.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(person.id),
          );

          expect(tombstone, isNull);
        });
      });
    },
  );

  group(
    'Given an empty table and a remote delete for a non-existing row,',
    () {
      late UuidValue remoteNodeId;
      late CrdtMergeDelete remoteDelete;

      setUp(() async {
        remoteNodeId = const Uuid().v7obj();

        remoteDelete = CrdtMergeDelete(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: const Uuid().v7obj(),
          uuidNodeId: remoteNodeId,
          hlcDatetime: DateTime.now().toUtc(),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        );

        mergeSet = [remoteDelete];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the remote delete is ignored.', () async {
          final row = await Person.db.findById(testSession, remoteDelete.uuidRowId);

          expect(row, isNull);
        });

        test('then the CRDT field metadata is not inserted.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(remoteDelete.uuidRowId),
          );

          expect(tombstone, isNull);
        });
      });
    },
  );
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
