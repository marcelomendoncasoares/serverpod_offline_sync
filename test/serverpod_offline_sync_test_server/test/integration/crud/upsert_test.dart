import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table,', () {
    group('when upserting a Person with upsertRow,', () {
      late UuidValue personId;
      late Person? person;

      setUp(() async {
        personId = const Uuid().v7obj();
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            Person(id: personId, name: 'created'),
            conflictColumns: (t) => [t.id],
            transaction: tx,
          ),
        );
      });

      test('then the returned row keeps spaceId null.', () async {
        expect(person, isNotNull);
        expect(person!.spaceId, isNull);
      });

      test('then the row exists in the person table.', () async {
        final row = await Person.db.findById(session, personId);
        expect(row?.name, 'created');
      });

      test('then CRDT metadata is recorded for the row.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(personId),
        );
        expect(crdtRow, isNotNull);
      });

      test('then no CRDT field is created for the inserted row.', () async {
        final fieldCount = await CrdtDataField.db.count(
          session,
          where: (t) => t.row.uuidRowId.equals(personId),
        );
        expect(fieldCount, 0);
      });
    });

    group('when upserting a Person without an id with upsertRow,', () {
      late Person? created;

      setUp(() async {
        created = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            Person(name: 'created without id'),
            conflictColumns: (t) => [t.id],
            transaction: tx,
          ),
        );
      });

      test('then the returned row has a generated id and null spaceId.', () {
        expect(created, isNotNull);
        expect(created!.id, isNotNull);
        expect(created!.spaceId, isNull);
      });

      test('then the row exists in the person table.', () async {
        final row = await Person.db.findById(session, created!.id!);
        expect(row?.name, 'created without id');
      });

      test('then CRDT metadata is recorded for the row.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(created!.id),
        );
        expect(crdtRow, isNotNull);
      });

      test('then no CRDT field is created for the inserted row.', () async {
        final fieldCount = await CrdtDataField.db.count(
          session,
          where: (t) => t.row.uuidRowId.equals(created!.id),
        );
        expect(fieldCount, 0);
      });
    });
  });

  group('Given a person table with an existing row,', () {
    late Person person;
    late CrdtDataRow insertedCrdtRow;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'original'),
          transaction: tx,
        ),
      );
      insertedCrdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
    });

    group('when upserting the Person name column with upsertRow,', () {
      late Person? updatedPerson;

      setUp(() async {
        updatedPerson = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            person.copyWith(name: 'updated'),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then the returned row keeps spaceId null.', () async {
        expect(updatedPerson, isNotNull);
        expect(updatedPerson!.spaceId, isNull);
      });

      test('then the person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'updated');
      });

      test('then the previously existing CRDT row is not affected.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(crdtRow!.uuidRowId, insertedCrdtRow.uuidRowId);
        expect(crdtRow.hlc, insertedCrdtRow.hlc);
      });

      test('then a CRDT field is created for the name column.', () async {
        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(column: CrdtSchemaColumn.include()),
        );

        expect(field, isNotNull);
        expect(field!.column!.name, 'name');
      });
    });

    group('when upserting the Person with a non-matching updateWhere,', () {
      late Person? updatedPerson;

      setUp(() async {
        updatedPerson = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            person.copyWith(name: 'skipped'),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            updateWhere: (t) => t.name.equals('other'),
            transaction: tx,
          ),
        );
      });

      test('then no row is returned.', () async {
        expect(updatedPerson, isNull);
      });

      test('then the person row is unchanged.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'original');
      });

      test('then no CRDT field is created for the skipped update.', () async {
        final fieldCount = await CrdtDataField.db.count(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );
        expect(fieldCount, 0);
      });
    });

    group('when upserting an existing Person and a new Person without an id,', () {
      late List<Person> upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsert(
            session,
            [
              person.copyWith(name: 'batch updated'),
              Person(name: 'batch created'),
            ],
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then both rows are returned with spaceId null.', () {
        expect(upserted, hasLength(2));
        expect(upserted.map((e) => e.spaceId), everyElement(isNull));
      });

      test('then the existing row keeps its id and reflects the new values.', () {
        final updated = upserted.singleWhere((e) => e.name == 'batch updated');
        expect(updated.id, person.id);
      });

      test('then the created row has a generated id and is persisted.', () async {
        final created = upserted.singleWhere((e) => e.name == 'batch created');
        expect(created.id, isNotNull);

        final row = await Person.db.findById(session, created.id!);
        expect(row?.name, 'batch created');
      });

      test('then CRDT row metadata is recorded for both affected rows.', () async {
        final created = upserted.singleWhere((e) => e.name == 'batch created');
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.inSet({person.id!, created.id!}),
        );

        expect(crdtRows.map((e) => e.uuidRowId).toSet(), {
          person.id,
          created.id,
        });
      });

      test(
        'then CRDT fields are recorded only for the existing updated row.',
        () async {
          final created = upserted.singleWhere((e) => e.name == 'batch created');
          final fields = await CrdtDataField.db.find(
            session,
            where: (t) => t.row.uuidRowId.inSet({person.id!, created.id!}),
            include: CrdtDataField.include(
              column: CrdtSchemaColumn.include(),
              row: CrdtDataRow.include(),
            ),
          );

          expect(fields.map((e) => e.row!.uuidRowId).toSet(), {
            person.id,
          });
          expect(fields.map((e) => e.column!.name).toSet(), {'name'});
        },
      );
    });

    group('when upserting an existing Person and a new Person with noReturn,', () {
      late Person? createdPerson;
      late List<Person> upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsert(
            session,
            [
              person.copyWith(name: 'batch updated'),
              Person(name: 'batch created'),
            ],
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
            noReturn: true,
          ),
        );
        createdPerson = await Person.db.findFirstRow(
          session,
          where: (t) => t.name.equals('batch created'),
        );
      });

      test('then an empty list is returned.', () async {
        expect(upserted, isEmpty);
      });

      test('then the existing person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'batch updated');
      });

      test('then the new person row exists in the person table.', () async {
        expect(createdPerson, isNotNull);
        expect(createdPerson!.id, isNotNull);
      });

      test('then CRDT row metadata is recorded for both affected rows.', () async {
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.inSet({person.id!, createdPerson!.id!}),
        );

        expect(crdtRows.map((e) => e.uuidRowId).toSet(), {
          person.id,
          createdPerson!.id,
        });
      });

      test(
        'then CRDT fields are recorded only for the existing updated row.',
        () async {
          final fields = await CrdtDataField.db.find(
            session,
            where: (t) => t.row.uuidRowId.inSet({person.id!, createdPerson!.id!}),
            include: CrdtDataField.include(
              column: CrdtSchemaColumn.include(),
              row: CrdtDataRow.include(),
            ),
          );

          expect(fields.map((e) => e.row!.uuidRowId).toSet(), {
            person.id,
          });
          expect(fields.map((e) => e.column!.name).toSet(), {'name'});
        },
      );
    });
  });

  group('Given a person table with a deleted row,', () {
    late Person person;
    late CrdtDataRow insertedCrdtRow;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'original'),
          transaction: tx,
        ),
      );
      insertedCrdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );
    });

    group('when upserting the Person with upsertRow,', () {
      late Person? reinserted;

      setUp(() async {
        reinserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            person.copyWith(name: 'reinserted'),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then the row is returned with the new values and null spaceId.', () {
        expect(reinserted, isNotNull);
        expect(reinserted!.name, 'reinserted');
        expect(reinserted!.spaceId, isNull);
      });

      test('then the row is visible again.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'reinserted');
      });

      test('then the CRDT metadata row is updated.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );
        expect(crdtRow!.hlc, greaterThan(insertedCrdtRow.hlc));
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

    group(
      'when upserting the Person with a column outside updateColumns changed,',
      () {
        late Person? reinserted;

        setUp(() async {
          reinserted = await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.upsertRow(
              session,
              person.copyWith(
                name: 'reinserted',
                surname: 'reinserted surname',
              ),
              conflictColumns: (t) => [t.id],
              updateColumns: (t) => [t.name],
              transaction: tx,
            ),
          );
        });

        test(
          'then the full incoming row is persisted, '
          'including the column outside updateColumns.',
          () async {
            expect(reinserted, isNotNull);
            expect(reinserted!.surname, 'reinserted surname');

            final row = await Person.db.findById(session, person.id!);
            expect(row, isNotNull);
            expect(row!.name, 'reinserted');
            expect(row.surname, 'reinserted surname');
          },
        );
      },
    );

    group('when upserting the Person with noReturn,', () {
      late List<Person> upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsert(
            session,
            [person.copyWith(name: 'reinserted')],
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
            noReturn: true,
          ),
        );
      });

      test('then an empty list is returned.', () async {
        expect(upserted, isEmpty);
      });

      test('then the row is visible again with the new values.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, 'reinserted');
      });
    });

    group('when upserting the Person with a non-matching updateWhere,', () {
      late Person? reinserted;

      setUp(() async {
        reinserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsertRow(
            session,
            person.copyWith(name: 'reinserted'),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            updateWhere: (t) => t.name.equals('other'),
            transaction: tx,
          ),
        );
      });

      test(
        'then the row is reinserted anyway, as it does not exist for the caller.',
        () async {
          expect(reinserted, isNotNull);
          expect(reinserted!.name, 'reinserted');

          final row = await Person.db.findById(session, person.id!);
          expect(row?.name, 'reinserted');
        },
      );
    });
  });

  group('Given a person table with a live and a deleted row,', () {
    late Person deletedPerson;
    late Person livePerson;

    setUp(() async {
      deletedPerson = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'deleted'),
          transaction: tx,
        ),
      );
      livePerson = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'live'),
          transaction: tx,
        ),
      );
      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, deletedPerson, transaction: tx),
      );
    });

    group('when upserting the live, the deleted, and a new row in one batch,', () {
      late List<Person> upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsert(
            session,
            [
              deletedPerson.copyWith(name: 'batch reinserted'),
              livePerson.copyWith(name: 'batch updated'),
              Person(name: 'batch created'),
            ],
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then all three rows are returned with spaceId null.', () {
        expect(upserted, hasLength(3));
        expect(upserted.map((e) => e.spaceId), everyElement(isNull));
        expect(upserted.map((e) => e.name).toSet(), {
          'batch reinserted',
          'batch updated',
          'batch created',
        });
      });

      test('then the deleted row is visible again with the new values.', () async {
        final row = await Person.db.findById(session, deletedPerson.id!);
        expect(row?.name, 'batch reinserted');
      });

      test('then the live and new rows are persisted with the new values.', () async {
        final updated = await Person.db.findById(session, livePerson.id!);
        expect(updated?.name, 'batch updated');

        final created = upserted.singleWhere((e) => e.name == 'batch created');
        final row = await Person.db.findById(session, created.id!);
        expect(row, isNotNull);
      });
    });
  });

  group('Given a unique composite table with an existing row,', () {
    late UniqueComposite uniqueComposite;

    setUp(() async {
      uniqueComposite = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueComposite.db.insertRow(
          session,
          UniqueComposite(scope: 'domain', value: 'key'),
          transaction: tx,
        ),
      );
    });

    group('when upserting another row with the same space-scoped unique key,', () {
      late UniqueComposite? upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueComposite.db.upsertRow(
            session,
            UniqueComposite(scope: 'domain', value: 'key'),
            conflictColumns: (t) => [t.spaceId, t.scope, t.value],
            transaction: tx,
          ),
        );
      });

      test('then the existing row is returned.', () async {
        expect(upserted, isNotNull);
        expect(upserted!.id, uniqueComposite.id);
        expect(upserted!.spaceId, isNull);
      });

      test('then no duplicate row is inserted.', () async {
        final rows = await UniqueComposite.db.find(
          session,
          where: (t) => t.scope.equals('domain') & t.value.equals('key'),
        );
        expect(rows, hasLength(1));
      });

      test('then CRDT fields are tracked for the default updated columns.', () async {
        final fields = await CrdtDataField.db.find(
          session,
          where: (t) => t.row.uuidRowId.equals(uniqueComposite.id),
          include: CrdtDataField.include(column: CrdtSchemaColumn.include()),
        );

        expect(fields.map((e) => e.column!.name).toSet(), {'scope', 'value'});
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

    group('when upserting a new row without an id,', () {
      late UuidValue rowUuid;
      late OfflineSyncIntegrityViolation? inserted;

      setUp(() async {
        rowUuid = const Uuid().v7obj();
        inserted = await OfflineSyncIntegrityViolation.db.upsertRow(
          session,
          violation.copyWith(id: null, uuidRowId: rowUuid, occurrences: 2),
          conflictColumns: (t) => [t.id],
        );
      });

      test('then the returned row has a generated id and the supplied values.', () {
        expect(inserted?.id, isNotNull);
        expect(inserted?.id, isNot(violation.id));
        expect(inserted?.uuidRowId, rowUuid);
        expect(inserted?.occurrences, 2);
      });

      test('then both rows are stored with their respective values.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(rowUuid),
        );
        final original = await OfflineSyncIntegrityViolation.db.findById(
          session,
          violation.id!,
        );
        expect(stored?.occurrences, 2);
        expect(original?.occurrences, 1);
      });
    });

    group(
      'when upserting a conflicting row with only occurrences selected for update,',
      () {
        late OfflineSyncIntegrityViolation? updated;

        setUp(() async {
          updated = await OfflineSyncIntegrityViolation.db.upsertRow(
            session,
            violation.copyWith(occurrences: 2, lastSeenAt: DateTime.utc(2027)),
            conflictColumns: (t) => [t.id],
            updateColumns: (t) => [t.occurrences],
          );
        });

        test('then the returned row preserves its id and unselected timestamp.', () {
          expect(updated?.id, violation.id);
          expect(updated?.occurrences, 2);
          expect(updated?.lastSeenAt, violation.lastSeenAt);
        });

        test('then only the selected column changes in the database.', () async {
          final stored = await OfflineSyncIntegrityViolation.db.findById(
            session,
            violation.id!,
          );
          expect(stored?.occurrences, 2);
          expect(stored?.lastSeenAt, violation.lastSeenAt);
        });
      },
    );

    group('when upserting a conflicting row with a non-matching updateWhere,', () {
      late OfflineSyncIntegrityViolation? updated;

      setUp(() async {
        updated = await OfflineSyncIntegrityViolation.db.upsertRow(
          session,
          violation.copyWith(occurrences: 2),
          conflictColumns: (t) => [t.id],
          updateWhere: (t) => t.occurrences.equals(99),
        );
      });

      test('then no row is returned.', () {
        expect(updated, isNull);
      });

      test('then the original row is preserved.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findById(
          session,
          violation.id!,
        );
        expect(stored?.occurrences, 1);
      });
    });

    group('when upserting a conflicting row with noReturn,', () {
      late List<OfflineSyncIntegrityViolation> updated;

      setUp(() async {
        updated = await OfflineSyncIntegrityViolation.db.upsert(
          session,
          [violation.copyWith(occurrences: 2)],
          conflictColumns: (t) => [t.id],
          noReturn: true,
        );
      });

      test('then an empty list is returned.', () {
        expect(updated, isEmpty);
      });

      test('then the row reflects the new values.', () async {
        final stored = await OfflineSyncIntegrityViolation.db.findById(
          session,
          violation.id!,
        );
        expect(stored?.occurrences, 2);
      });
    });
  });
}
