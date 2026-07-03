import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table,', () {
    test(
      'when inserting a Person with a caller-provided id and noReturn, '
      'then the row and CRDT metadata are recorded.',
      () async {
        final id = const Uuid().v7obj();

        final inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(id: id, name: 'fixed')],
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(inserted, hasLength(1));
        expect(inserted.single.id, id);
        expect(inserted.single.scopeId, isNull);

        final row = await Person.db.findById(session, id);
        expect(row?.name, 'fixed');

        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(id),
        );
        expect(crdtRow, isNotNull);
      },
    );

    test(
      'when inserting a Person without a caller-provided id and noReturn, '
      'then the inserted row is returned.',
      () async {
        final inserted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insert(
            session,
            [Person(name: 'generated')],
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(inserted, hasLength(1));
        expect(inserted.single.id, isNotNull);
      },
    );
  });

  group('Given a person row,', () {
    late Person person;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'initial'),
          transaction: tx,
        ),
      );
    });

    test(
      'when updating the Person with update and noReturn, '
      'then the updated row is returned.',
      () async {
        final updated = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.update(
            session,
            [person.copyWith(name: 'updated')],
            columns: (t) => [t.name],
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(updated, hasLength(1));
        expect(updated.single.name, 'updated');

        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(column: CrdtSchemaColumn.include()),
        );
        expect(field?.column?.name, 'name');
      },
    );

    test(
      'when updating the Person with updateWhere and noReturn, '
      'then the updated row is returned.',
      () async {
        final updated = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateWhere(
            session,
            columnValues: (t) => [t.name('updated')],
            where: (t) => t.id.equals(person.id),
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(updated, hasLength(1));
        expect(updated.single.name, 'updated');
      },
    );

    test(
      'when deleting the Person with delete and noReturn, '
      'then the deleted row is returned.',
      () async {
        final deleted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.delete(
            session,
            [person],
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(deleted, hasLength(1));
        expect(deleted.single.id, person.id);

        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );
        expect(tombstone?.isDeleted, isTrue);
      },
    );

    test(
      'when deleting the Person with deleteWhere and noReturn, '
      'then the deleted row is returned.',
      () async {
        final deleted = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteWhere(
            session,
            where: (t) => t.id.equals(person.id),
            transaction: tx,
            noReturn: true,
          ),
        );

        expect(deleted, hasLength(1));
        expect(deleted.single.id, person.id);
      },
    );
  });
}
