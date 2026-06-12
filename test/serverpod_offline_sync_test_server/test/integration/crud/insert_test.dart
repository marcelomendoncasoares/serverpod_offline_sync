import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table, '
      'when inserting a Person with insertRow,', () {
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

    test('then the returned row keeps scopeId null.', () async {
      expect(person.scopeId, isNull);
    });

    test('then the stored row is stamped with the effective scope.', () async {
      final row = await Person.db.findById(testSession, person.id!);

      expect(row, isNotNull);
      expect(row!.scopeId, await _currentScopeId());
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

  group('Given an empty person table, '
      'when inserting a Person with an explicit matching scopeId,', () {
    late Person person;
    late int scopeId;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          scopeId = await _currentScopeId();
          return Person.db.insertRow(
            session,
            Person(name: 'explicit', scopeId: scopeId),
            transaction: tx,
          );
        },
      );
    });

    test('then the returned row keeps the explicit scopeId.', () async {
      expect(person.scopeId, scopeId);
    });
  });

  test(
    'Given an empty person table, '
    'when inserting a Person with another scopeId, '
    'then the insert throws.',
    () async {
      final insertFuture = session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'wrong scope', scopeId: -1),
          transaction: tx,
        ),
      );

      await expectLater(insertFuture, throwsA(isA<StateError>()));
    },
  );

  group('Given an empty person table, '
      'when inserting two Person rows with insert,', () {
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
        await Unique.db.findById(testSession, deletedRow.id!),
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
        expect(await Unique.db.findById(testSession, deletedRow.id!), isNotNull);
      });

      test('then the soft-deleted row has another conflict-free name.', () async {
        final row = await Unique.db.findById(testSession, deletedRow.id!);

        expect(row, isNotNull);
        expect(row!.name, startsWith(name));
        expect(row.name, isNot(name));
      });
    });
  });
}

Future<int> _currentScopeId() async {
  final scope = await CrdtScope.db.findFirstRow(
    session,
    where: (t) => t.uuidScopeId.equals(testCrdtUserId),
  );
  return scope!.id!;
}
