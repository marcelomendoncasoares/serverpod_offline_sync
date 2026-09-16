import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table,', () {
    group('when inserting a Person with insertRow,', () {
      late Person person;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'test'),
            transaction: tx,
          ),
        );
      });

      test('then the row exists in the person table.', () async {
        final row = await Person.db.findFirstRow(
          session,
          where: (t) => t.id.equals(person.id),
        );
        expect(row, isNotNull);
        expect(row!.name, 'test');
      });

      test('then the returned row keeps spaceId null.', () async {
        expect(person.spaceId, isNull);
      });

      test('then the stored row is stamped with the effective space.', () async {
        final row = await Person.db.findById(testSession, person.id!);
        final space = await OfflineSyncSpace.db.findFirstRow(
          session,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
        );

        expect(row, isNotNull);
        expect(row!.spaceId, space!.id);
      });

      group('then CRDT metadata row', () {
        late CrdtDataRow? crdtRow;

        setUp(() async {
          crdtRow = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.uuidRowId.equals(person.id),
            include: CrdtDataRow.include(node: CrdtNode.include()),
          );
        });

        test('is recorded.', () async {
          expect(crdtRow, isNotNull);
          expect(crdtRow!.tblId, isNotNull);
          expect(crdtRow!.uuidRowId, person.id);
        });

        test('has the HLC components populated consistently.', () async {
          final hlc = crdtRow!.hlc;
          expect(hlc, greaterThan(Hlc.zero(hlc.nodeId)));
        });
      });

      test('then no CRDT fields metadata are registered.', () async {
        final fieldCount = await CrdtDataField.db.count(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );
        expect(fieldCount, 0);
      });

      test('then no CRDT visibility generation is created for the row.', () async {
        final clFlag = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(clFlag, isNull);
      });
    });

    group('when inserting a Person with an explicit matching spaceId,', () {
      late Person person;
      late int spaceId;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) async {
            final space = await OfflineSyncSpace.db.findFirstRow(
              session,
              where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
            );
            spaceId = space!.id!;
            return Person.db.insertRow(
              session,
              Person(name: 'explicit', spaceId: spaceId),
              transaction: tx,
            );
          },
        );
      });

      test('then the returned row keeps the explicit spaceId.', () async {
        expect(person.spaceId, spaceId);
      });
    });

    group('when inserting two Person rows with insert,', () {
      late List<Person> inserted;

      setUp(() async {
        inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(name: 'a'), Person(name: 'b')],
            transaction: tx,
          ),
        );
      });

      test('then both rows exist with distinct ids and CRDT metadata.', () async {
        expect(inserted, hasLength(2));
        expect(inserted[0].id, isNot(equals(inserted[1].id)));

        final insertedIds = inserted.map((e) => e.id!).toSet();
        final crdt = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.inSet(insertedIds),
        );

        expect(crdt, hasLength(2));
        expect(crdt.map((e) => e.uuidRowId).toSet(), insertedIds);
      });
    });

    group('when inserting a Person with a caller-provided id and noReturn,', () {
      late UuidValue id;
      late List<Person> inserted;

      setUp(() async {
        id = const Uuid().v7obj();
        inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(id: id, name: 'fixed')],
            transaction: tx,
            noReturn: true,
          ),
        );
      });

      test('then an empty list is returned.', () async {
        expect(inserted, isEmpty);
      });

      test('then the row exists in the person table.', () async {
        final row = await Person.db.findById(session, id);
        expect(row?.name, 'fixed');
      });

      test('then CRDT metadata is recorded for the row.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(id),
        );
        expect(crdtRow, isNotNull);
      });
    });

    group('when inserting a Person without a caller-provided id and noReturn,', () {
      late List<Person> inserted;
      late Person? row;

      setUp(() async {
        inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(name: 'generated')],
            transaction: tx,
            noReturn: true,
          ),
        );

        row = await Person.db.findFirstRow(
          session,
          where: (t) => t.name.equals('generated'),
        );
      });

      test('then an empty list is returned.', () async {
        expect(inserted, isEmpty);
      });

      test('then the row exists in the person table.', () async {
        expect(row, isNotNull);
      });

      test('then CRDT metadata is recorded for the row.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(row!.id),
        );
        expect(crdtRow, isNotNull);
      });
    });

    test(
      'when inserting a Person with another spaceId, '
      'then the insert throws.',
      () async {
        final insertFuture = session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'wrong space', spaceId: -1),
            transaction: tx,
          ),
        );

        await expectLater(
          insertFuture,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Cannot write person row'),
                contains('with spaceId -1 while acting in space 1'),
              ]),
            ),
          ),
        );
      },
    );
  });

  group('Given a person row with a fixed id,', () {
    late UuidValue id;

    setUp(() async {
      id = const Uuid().v7obj();

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insert(
          session,
          [Person(id: id, name: 'first')],
          transaction: tx,
        ),
      );
    });

    group('when inserting the same primary key again with ignoreConflicts,', () {
      late Future<List<Person>> insertFuture;
      late CrdtDataRow crdtRow;

      setUp(() async {
        insertFuture = session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(id: id, name: 'ignored')],
            transaction: tx,
            ignoreConflicts: true,
          ),
        );

        crdtRow = (await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(id),
        ))!;
      });

      test('then the insert returns an empty list.', () async {
        expect(await insertFuture, isEmpty);
      });

      test('then the original row is unchanged.', () async {
        final row = await Person.db.findById(session, id);
        expect(row?.name, 'first');
      });

      test('then no changes are recorded on CRDT for the ignored row.', () async {
        final crdt = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.equals(id),
        );

        expect(crdt, hasLength(1));
        expect(crdt.first.nodeId, crdtRow.nodeId);
        expect(crdt.first.hlcDatetime, crdtRow.hlcDatetime);
        expect(crdt.first.hlcCounter, crdtRow.hlcCounter);
      });
    });
  });

  group('Given a person table with a deleted row,', () {
    late Person person;
    late CrdtDataRow firstInsertedCrdtRow;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'test'), transaction: tx),
      );

      firstInsertedCrdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );
    });

    group('when reinserting the row,', () {
      late Future<Person> insertFuture;

      setUp(() async {
        insertFuture = session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, person, transaction: tx),
        );
      });

      test('then it succeeds.', () async {
        await expectLater(
          insertFuture,
          completes,
          reason: 'This should succeed by un-marking the row as tombstoned.',
        );
      });

      test('then the CRDT metadata row is updated.', () async {
        await insertFuture;

        final crdt = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(crdt!.hlc, greaterThan(firstInsertedCrdtRow.hlc));
      });
    });

    group('when inserting the same id and a new row in a batch,', () {
      late Person newPerson;
      late List<Person> inserted;

      setUp(() async {
        newPerson = Person(id: const Uuid().v7obj(), name: 'batch new');
        inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [person.copyWith(name: 'batch reinserted'), newPerson],
            transaction: tx,
          ),
        );
      });

      test('then both rows are returned.', () async {
        expect(inserted.map((e) => e.name).toSet(), {
          'batch reinserted',
          'batch new',
        });
      });

      test('then the deleted row is visible again with the new values.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, 'batch reinserted');
      });

      test('then the new row exists in the person table.', () async {
        final row = await Person.db.findById(session, newPerson.id!);

        expect(row, isNotNull);
        expect(row!.name, 'batch new');
      });

      test('then the CRDT metadata row of the reinserted row is updated.', () async {
        final crdt = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(crdt!.hlc, greaterThan(firstInsertedCrdtRow.hlc));
      });

      test('then the tombstone of the reinserted row is lifted.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isFalse);
        expect(tombstone.reason, CrdtDataDeletedReason.userReinsert);
      });
    });

    group('when inserting the same id in a batch with ignoreConflicts,', () {
      late List<Person> inserted;

      setUp(() async {
        inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [person.copyWith(name: 'batch reinserted')],
            transaction: tx,
            ignoreConflicts: true,
          ),
        );
      });

      test('then the reinserted row is returned.', () async {
        expect(inserted, hasLength(1));
        expect(inserted.single.name, 'batch reinserted');
      });

      test('then the deleted row is visible again with the new values.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, 'batch reinserted');
      });
    });
  });

  group('Given a person table with a deleted row that is reinserted,', () {
    late Person person;

    setUp(() async {
      final firstPerson = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'first'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, firstPerson, transaction: tx),
      );

      final secondPerson = firstPerson.copyWith(name: 'second');
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, secondPerson, transaction: tx),
      );
    });

    group('when calling findById,', () {
      late Person? foundPerson;

      setUp(() async {
        foundPerson = await Person.db.findById(session, person.id!);
      });

      test('then it finds the row.', () async {
        expect(foundPerson, isNotNull);
      });

      test('then it has the reinserted name.', () async {
        expect(foundPerson!.name, 'second');
      });
    });
  });

  group('Given a unique table with a soft-deleted row,', () {
    const name = 'unique';
    late Unique deletedRow;

    setUp(() async {
      deletedRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(session, Unique(name: name), transaction: tx),
      );

      deletedRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.deleteRow(session, deletedRow, transaction: tx),
      );

      expect(
        await Unique.db.findFirstRow(
          session,
          where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
        ),
        isNotNull,
      );
    });

    group('when inserting another row with the same unique key,', () {
      late Unique insertedRow;

      setUp(() async {
        insertedRow = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(session, Unique(name: name), transaction: tx),
        );
      });

      test('then it succeeds.', () async {
        expect(insertedRow, isNotNull);
      });

      test('then the deleted row is still soft-deleted.', () async {
        expect(
          await Unique.db.findFirstRow(
            session,
            where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
          ),
          isNotNull,
        );
      });

      test('then the soft-deleted row has another conflict-free name.', () async {
        final row = await Unique.db.findFirstRow(
          session,
          where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
        );

        expect(row, isNotNull);
        expect(row!.name, startsWith(name));
        expect(row.name, isNot(name));
      });
    });
  });

  group('Given an empty table not tracked by CRDT,', () {
    late OfflineSyncIntegrityViolation violation;

    setUp(() {
      violation = OfflineSyncIntegrityViolation(
        type: OfflineSyncViolationType.ownershipCollision,
        domainTableName: Person.t.tableName,
        uuidRowId: const Uuid().v7obj(),
        incomingSpaceUuid: testCrdtUserId,
        operation: OfflineSyncViolationOperation.mergeInsert,
        firstSeenAt: DateTime.utc(2026),
        lastSeenAt: DateTime.utc(2026),
        occurrences: 1,
      );
    });

    group('when inserting a row with insertRow,', () {
      late OfflineSyncIntegrityViolation inserted;

      setUp(() async {
        inserted = await OfflineSyncIntegrityViolation.db.insertRow(session, violation);
      });

      test('then the returned row has a generated id and the supplied values.', () {
        expect(inserted.id, isNotNull);
        expect(inserted.uuidRowId, violation.uuidRowId);
        expect(inserted.occurrences, 1);
      });

      test('then the row is stored in the database.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findById(
          session,
          inserted.id!,
        );
        expect(stored?.uuidRowId, violation.uuidRowId);
        expect(stored?.occurrences, 1);
      });
    });

    group('when inserting rows with noReturn,', () {
      late List<OfflineSyncIntegrityViolation> inserted;

      setUp(() async {
        inserted = await OfflineSyncIntegrityViolation.db.insert(
          session,
          [violation],
          noReturn: true,
        );
      });

      test('then an empty list is returned.', () {
        expect(inserted, isEmpty);
      });

      test('then the row is stored in the database.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(violation.uuidRowId),
        );
        expect(stored?.occurrences, 1);
      });
    });
  });

  group('Given an existing row on a table not tracked by CRDT,', () {
    late OfflineSyncIntegrityViolation violation;

    setUp(() async {
      violation = await OfflineSyncIntegrityViolation.db.insertRow(
        session,
        OfflineSyncIntegrityViolation(
          type: OfflineSyncViolationType.ownershipCollision,
          domainTableName: Person.t.tableName,
          uuidRowId: const Uuid().v7obj(),
          incomingSpaceUuid: testCrdtUserId,
          operation: OfflineSyncViolationOperation.mergeInsert,
          firstSeenAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
          occurrences: 1,
        ),
      );
    });

    group('when inserting the same primary key with ignoreConflicts,', () {
      late List<OfflineSyncIntegrityViolation> inserted;

      setUp(() async {
        inserted = await OfflineSyncIntegrityViolation.db.insert(
          session,
          [violation.copyWith(occurrences: 2)],
          ignoreConflicts: true,
        );
      });

      test('then an empty list is returned.', () {
        expect(inserted, isEmpty);
      });

      test('then the original row is preserved.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findById(
          session,
          violation.id!,
        );
        expect(stored?.occurrences, 1);
      });
    });
  });
}
