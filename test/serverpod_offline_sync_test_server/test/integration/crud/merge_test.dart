import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeset;

  group('Given an empty table and a remote insert, ', () {
    late UuidValue remoteNodeId;
    late Person remotePerson;
    late CrdtMergeInsert remoteInsert;

    setUp(() {
      remoteNodeId = const Uuid().v7obj();
      remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

      final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
      remoteInsert = CrdtMergeInsert(
        tableName: Person.t.tableName,
        uuidRowId: remotePerson.id!,
        uuidNodeId: hlc.nodeId,
        hlcDatetime: hlc.datetime,
        hlcCounter: hlc.counter,
        data: remotePerson,
      );

      mergeset = CrdtMergeSet(
        inserts: [remoteInsert],
        updates: [],
        deletes: [],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
          userId: testCrdtUserId,
        );
      });

      test('then the remote row is inserted into the domain table.', () async {
        final row = await Person.db.findById(session, remotePerson.id!);

        expect(row, isNotNull);
        expect(row!.name, remotePerson.name);
      });

      test('then the remote CRDT row metadata is recorded.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(remotePerson.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(crdtRow, isNotNull);
        expect(crdtRow!.node!.uuidNodeId, remoteNodeId);
        expect(crdtRow.hlc, remoteInsert.hlc);
      });
    });
  });

  group(
    'Given an empty table, a remote insert and a newer remote update for the same row, ',
    () {
      late UuidValue remoteNodeId;
      late Person remotePerson;
      late CrdtMergeInsert remoteInsert;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() {
        remoteNodeId = const Uuid().v7obj();
        remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

        final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: hlc.nodeId,
          hlcDatetime: hlc.datetime,
          hlcCounter: hlc.counter,
          data: remotePerson,
        );

        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: remoteInsert.hlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeset = CrdtMergeSet(
          inserts: [remoteInsert],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the newer remote field value wins.', () async {
          final row = await Person.db.findById(session, remotePerson.id!);

          expect(row, isNotNull);
          expect(row!.name, remoteUpdate.value);
        });

        test(
          'then the CRDT field metadata is recorded for the updated column.',
          () async {
            final field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(remotePerson.id) &
                  t.column.name.equals(Person.t.name.columnName),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(field, isNotNull);
            expect(field!.node!.uuidNodeId, remoteNodeId);
            expect(field.hlc, remoteUpdate.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and a newer insert '
    'with the same row ID but different data, ',
    () {
      late Person person;
      late Hlc localRowHlc;
      late Hlc localFieldHlc;
      late Person remotePerson;
      late UuidValue remoteNodeId;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'original'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'local'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(person.id) &
              t.column.name.equals(Person.t.name.columnName),
          include: CrdtDataField.include(
            node: CrdtNode.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        localRowHlc = field!.row!.hlc;
        localFieldHlc = field.hlc;
        remoteNodeId = const Uuid().v7obj();

        remotePerson = person.copyWith(name: 'remote');
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.advance(),
          hlcCounter: localFieldHlc.counter,
          data: remotePerson,
        );

        mergeset = CrdtMergeSet(
          inserts: [remoteInsert],
          updates: [],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the row field value is updated to the remote value.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, remotePerson.name);
        });

        // We can't update the row original HLC because it would break the causal
        // order of the operations on the node.
        test('then the CRDT row metadata is not updated.', () async {
          final row = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.uuidRowId.equals(person.id),
            include: CrdtDataRow.include(node: CrdtNode.include()),
          );

          expect(row!.hlc, localRowHlc);
        });

        // Since different nodes will have different HLCs for the row, we need to
        // ensure that no future conflict resolution on the node with the older HLC
        // will fallback to the row-level HLC. This is done by forcefully touching
        // all columns of the row with the new HLC.
        test(
          'then each column of the table receives a CRDT field metadata record for the remote HLC.',
          () async {
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(fields.length, Person.t.columns.length - 1); // -1 for the id column
            expect(
              fields.map((f) => f.hlc),
              everyElement(remoteInsert.hlc),
            );
          },
        );

        // For the same reason above, we need to touch the tombstone for the row
        // to ensure that tombstone conflict resolution never falls back to the
        // row-level HLC.
        test(
          'then a CRDT tombstone record is inserted with deleted set to false.',
          () async {
            final tombstone = await CrdtDataDeleted.db.findFirstRow(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataDeleted.include(node: CrdtNode.include()),
            );

            expect(tombstone, isNotNull);
            expect(tombstone!.isDeleted, isFalse);
            expect(tombstone.hlc, remoteInsert.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and a remote insert '
    'that is after the insert and before the update for the same row ID but '
    'different data, ',
    () {
      late Person person;
      late Hlc localRowHlc;
      late Person remotePerson;
      late UuidValue remoteNodeId;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'original', surname: 'original'),
            transaction: tx,
          ),
        );

        final row = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        localRowHlc = row!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remotePerson = person.copyWith(name: 'remote', surname: 'remote');
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localRowHlc.datetime.advance(),
          hlcCounter: localRowHlc.counter,
          data: remotePerson,
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'updated locally'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        mergeset = CrdtMergeSet(
          inserts: [remoteInsert],
          updates: [],
          deletes: [],
        );
      });

      group('when merging, ', () {
        late Person mergedPerson;

        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );

          final row = await Person.db.findById(session, person.id!);
          mergedPerson = row!;
        });

        test('then the row field value is updated to the remote value.', () async {
          expect(mergedPerson.name, remotePerson.name);
        });

        test('then the local newer column update is preserved.', () async {
          expect(mergedPerson.surname, 'original');
        });

        // Local updates that have a newer HLC than the remote insert should still
        // be preserved as in any HLC conflict resolution (last writer wins).
        test(
          'then the CRDT field metadata of the local newer column is not updated.',
          () async {
            final field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(person.id) &
                  t.column.name.equals(Person.t.name.columnName),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(field, isNotNull);
            expect(field!.node!.uuidNodeId, localRowHlc.nodeId);
            expect(field.hlc, localRowHlc);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing unchanged row and a remote update for one of its columns, ',
    () {
      late Person person;
      late Hlc localFieldHlc;
      late UuidValue remoteNodeId;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'local'),
            transaction: tx,
          ),
        );

        final row = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        localFieldHlc = row!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.advance(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeset = CrdtMergeSet(
          inserts: [],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the row field value is updated to the remote value.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, 'updated remotely');
        });

        test('then the CRDT field metadata is inserted to the remote HLC.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNotNull);
          expect(field!.node!.uuidNodeId, remoteNodeId);
          expect(field.hlc, remoteUpdate.hlc);
        });
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and an older remote update for the same column, ',
    () {
      late Person person;
      late Hlc localFieldHlc;
      late UuidValue remoteNodeId;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'local'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'newer local'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(person.id) &
              t.column.name.equals(Person.t.name.columnName),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );

        localFieldHlc = field!.hlc;
        remoteNodeId = const Uuid().v7obj();

        final remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.retreat(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'older remote',
        );

        mergeset = CrdtMergeSet(
          inserts: [],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the local field value is preserved.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, 'newer local');
        });

        test('then the CRDT field metadata is preserved.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNotNull);
          expect(field!.node!.uuidNodeId, localFieldHlc.nodeId);
          expect(field.hlc, localFieldHlc);
        });
      });
    },
  );

  group('Given a table with an existing row and a newer remote delete, ', () {
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
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: rowHlc.datetime.advance(),
        hlcCounter: 0,
        isDeleted: true,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteDelete],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
          userId: testCrdtUserId,
        );
      });

      test('then the row is hidden by the tombstone.', () async {
        expect(await Person.db.findById(session, person.id!), isNull);
        expect(await Person.db.findById(testSession, person.id!), isNotNull);
      });

      test('then the tombstone is recorded as deleted.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isTrue);
        expect(tombstone.hlc, remoteDelete.hlc);
      });
    });
  });

  group('Given a table with a deleted row and a newer remote restore, ', () {
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
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.advance(),
        hlcCounter: 0,
        isDeleted: false,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteRestore],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
          userId: testCrdtUserId,
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
      });
    });
  });

  group('Given a table with a restored row and an older remote delete, ', () {
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
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.retreat(),
        hlcCounter: 0,
        isDeleted: true,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteRestore],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
          userId: testCrdtUserId,
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
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
