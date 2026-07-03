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

      test('then the returned row keeps scopeId null.', () async {
        expect(person, isNotNull);
        expect(person!.scopeId, isNull);
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
    });
  });

  group('Given a person table with an existing row,', () {
    late Person person;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'original'),
          transaction: tx,
        ),
      );
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

      test('then the returned row keeps scopeId null.', () async {
        expect(updatedPerson, isNotNull);
        expect(updatedPerson!.scopeId, isNull);
      });

      test('then the person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'updated');
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

    group('when upserting an existing Person and a new Person with noReturn,', () {
      late UuidValue newPersonId;
      late List<Person> upserted;

      setUp(() async {
        newPersonId = const Uuid().v7obj();
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.upsert(
            session,
            [
              person.copyWith(name: 'batch updated'),
              Person(id: newPersonId, name: 'batch created'),
            ],
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

      test('then the existing person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'batch updated');
      });

      test('then the new person row exists in the person table.', () async {
        final row = await Person.db.findById(session, newPersonId);
        expect(row?.name, 'batch created');
      });

      test('then CRDT metadata is recorded for both affected rows.', () async {
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.inSet({person.id!, newPersonId}),
        );
        final fields = await CrdtDataField.db.find(
          session,
          where: (t) => t.row.uuidRowId.inSet({person.id!, newPersonId}),
          include: CrdtDataField.include(
            column: CrdtSchemaColumn.include(),
            row: CrdtDataRow.include(),
          ),
        );

        expect(crdtRows.map((e) => e.uuidRowId).toSet(), {
          person.id,
          newPersonId,
        });
        expect(fields.map((e) => e.row!.uuidRowId).toSet(), {
          person.id,
          newPersonId,
        });
        expect(fields.map((e) => e.column!.name).toSet(), {'name'});
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

    group('when upserting another row with the same scoped unique key,', () {
      late UniqueComposite? upserted;

      setUp(() async {
        upserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueComposite.db.upsertRow(
            session,
            UniqueComposite(scope: 'domain', value: 'key'),
            conflictColumns: (t) => [t.scopeId, t.scope, t.value],
            transaction: tx,
          ),
        );
      });

      test('then the existing row is returned.', () async {
        expect(upserted, isNotNull);
        expect(upserted!.id, uniqueComposite.id);
        expect(upserted!.scopeId, isNull);
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

        expect(fields.map((e) => e.column!.name).toSet(), {
          'scope',
          'value',
        });
      });
    });
  });
}
