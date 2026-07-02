import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a person table with an existing row,', () {
    late Person person;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'new'),
          transaction: tx,
        ),
      );
    });

    group('when updating the Person name column with updateRow,', () {
      late Person updatedPerson;

      setUp(() async {
        updatedPerson = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'updated'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then the returned row keeps scopeId null.', () async {
        expect(updatedPerson.scopeId, isNull);
      });

      test('then the person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'updated');
      });

      test('then a CRDT field is created for the name column.', () async {
        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(
            column: CrdtSchemaColumn.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        expect(field, isNotNull);
        expect(field!.column!.name, 'name');
      });

      test('then the CRDT field has the HLC newer than the row HLC.', () async {
        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(
            node: CrdtNode.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        expect(field!.hlc, greaterThan(field.row!.hlc));
      });
    });

    group('when updating the person name column with update,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.update(
            session,
            [person.copyWith(name: 'updated')],
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then the person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'updated');
      });

      test('then a CRDT field is created for the name column.', () async {
        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(
            column: CrdtSchemaColumn.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        expect(field, isNotNull);
        expect(field!.column!.name, 'name');
      });
    });

    group('when updating the Person name column without specifying columns,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'updated'),
            transaction: tx,
          ),
        );
      });

      test('then the person row reflects the new values.', () async {
        final row = await Person.db.findById(session, person.id!);
        expect(row?.name, 'updated');
      });

      test('then a CRDT field is created for each column.', () async {
        final fields = await CrdtDataField.db.find(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataField.include(
            column: CrdtSchemaColumn.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        expect(
          fields.map((e) => e.column!.name).toSet(),
          {'name', 'surname', 'organizationId', 'oldCompanyId'},
        );
      });
    });

    test(
      'when updating a Person with another scopeId, then it throws.',
      () async {
        final updateFuture = session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'wrong scope', scopeId: -1),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        await expectLater(
          updateFuture,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf([
                contains('Cannot write person row'),
                contains('with scopeId -1 while acting in scope 1'),
              ]),
            ),
          ),
        );
      },
    );

    test(
      'when updateWhere sets scopeId, then it throws.',
      () async {
        final updateFuture = session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateWhere(
            session,
            columnValues: (t) => [t.scopeId(-1)],
            where: (t) => t.id.equals(person.id),
            transaction: tx,
          ),
        );

        await expectLater(
          updateFuture,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('scopeId is immutable and owned by the CRDT sync layer'),
            ),
          ),
        );
      },
    );
  });

  group('Given a person table with a deleted row,', () {
    late Person person;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'test'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );
    });

    test('when updating the deleted person with updateRow, then it throws.', () async {
      final updateFuture = session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.updateRow(
          session,
          person.copyWith(name: 'test2'),
          transaction: tx,
        ),
      );

      await expectLater(
        updateFuture,
        throwsA(isA<Exception>()),
        reason: 'This should fail due to the person being tombstoned.',
      );
    });

    group('when updating the deleted person with updateWhere,', () {
      late List<Person> updatedRows;

      setUp(() async {
        updatedRows = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateWhere(
            session,
            columnValues: (t) => [t.name('test2')],
            where: (t) => t.id.equals(person.id),
            transaction: tx,
          ),
        );
      });

      test('then an empty list is returned.', () async {
        expect(updatedRows, isEmpty);
      });

      test('then the deleted row keeps its original value.', () async {
        final row = await Person.db.findFirstRow(
          session,
          where: (t) => t.id.equals(person.id) & t.includeHiddenRows,
        );

        expect(row, isNotNull);
        expect(row!.name, person.name);
      });
    });
  });

  group(
    'Given a person table with a row and an organization table with a deleted row,',
    () {
      late Person person;
      late Organization deletedOrganization;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, Person(name: 'new'), transaction: tx),
        );

        final organization = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Organization.db.insertRow(
            session,
            Organization(name: 'deleted'),
            transaction: tx,
          ),
        );

        deletedOrganization = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Organization.db.deleteRow(
            session,
            organization,
            transaction: tx,
          ),
        );
      });

      group(
        'when updating the person with updateWhere to set the organization foreign key to the deleted row id,',
        () {
          late Future<List<Person>> updateFuture;

          setUp(() async {
            updateFuture = session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.updateWhere(
                session,
                columnValues: (t) => [t.organizationId(deletedOrganization.id)],
                where: (t) => t.id.equals(person.id),
                transaction: tx,
              ),
            );
          });

          test(
            'then an exception is thrown and the row keeps its original foreign key value.',
            () async {
              await expectLater(updateFuture, throwsA(isA<Exception>()));

              final row = await Person.db.findById(session, person.id!);
              expect(row, isNotNull);
              expect(row!.organizationId, person.organizationId);
            },
          );
        },
      );
    },
  );

  group(
    'Given a person table with an existing row that was inserted and updated from a different node,',
    () {
      late Person person;
      late CrdtNode otherNode;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'new'),
            transaction: tx,
          ),
        );

        final scope = await CrdtScope.db.findFirstRow(session);

        otherNode = await CrdtNode.db.insertRow(
          session,
          CrdtNode(),
        );
        await CrdtScopeNode.db.insertRow(
          session,
          CrdtScopeNode(scopeId: scope!.id!, nodeId: otherNode.id!),
        );

        final crdtDataRow = await CrdtDataRow.db
            .updateWhere(
              session,
              columnValues: (t) => [t.nodeId(otherNode.id!)],
              where: (t) => t.uuidRowId.equals(person.id),
            )
            .then((value) => value.first);

        final crdtSchemaColumn = await CrdtSchemaColumn.db.findFirstRow(
          session,
          where: (t) =>
              t.tbl.name.equals(Person.t.tableName) &
              t.name.equals(Person.t.name.columnName),
        );

        await CrdtDataField.db.insertRow(
          session,
          CrdtDataField(
            rowId: crdtDataRow.id!,
            columnId: crdtSchemaColumn!.id!,
            nodeId: otherNode.id!,
            hlcDatetime: DateTime.now(),
            hlcCounter: 0,
          ),
        );
      });

      group('when updating the same updated column from the current node,', () {
        setUp(() async {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.updateRow(
              session,
              person.copyWith(name: 'updated'),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        });

        test('then the node ID is updated in the CRDT field.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(
              node: CrdtNode.include(),
            ),
          );

          expect(field!.node!.uuidNodeId, isNot(otherNode.uuidNodeId));
        });
      });

      group('when updating a never updated column from the current node,', () {
        setUp(() async {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.updateRow(
              session,
              person.copyWith(surname: 'updated'),
              columns: (t) => [t.surname],
              transaction: tx,
            ),
          );
        });

        test('then the node ID is updated in the CRDT field.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.surname.columnName),
            include: CrdtDataField.include(
              node: CrdtNode.include(),
            ),
          );

          expect(field!.node!.uuidNodeId, isNot(otherNode.uuidNodeId));
        });
      });
    },
  );

  group('Given a unique table with one visible and one deleted row,', () {
    late Unique visibleRow;
    late Unique deletedRow;

    setUp(() async {
      visibleRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(session, Unique(name: 'visible'), transaction: tx),
      );

      deletedRow = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(session, Unique(name: 'deleted'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.deleteRow(session, deletedRow, transaction: tx),
      );
    });

    group('when updating the table with updateWhere,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.updateWhere(
            session,
            columnValues: (t) => [t.name('updated')],
            where: (t) => t.id.notEquals(null),
            transaction: tx,
          ),
        );
      });

      test('then only the visible row has the new values.', () async {
        final foundVisibleRow = await Unique.db.findById(session, visibleRow.id!);
        expect(foundVisibleRow, isNotNull);
        expect(foundVisibleRow!.name, 'updated');

        final foundDeletedRow = await Unique.db.findFirstRow(
          session,
          where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
        );
        expect(foundDeletedRow, isNotNull);
        expect(foundDeletedRow!.name, startsWith(deletedRow.name));
        expect(foundDeletedRow.name, isNot(deletedRow.name));
      });
    });

    group('when updating the visible row to the same name as the deleted row,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.update(
            session,
            [visibleRow.copyWith(name: deletedRow.name)],
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );
      });

      test('then the visible row reflects the new values.', () async {
        final row = await Unique.db.findById(session, visibleRow.id!);
        expect(row?.name, deletedRow.name);
      });

      test('then the soft-deleted row has another conflict-free name.', () async {
        final row = await Unique.db.findFirstRow(
          session,
          where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
        );

        expect(row, isNotNull);
        expect(row!.name, startsWith(deletedRow.name));
        expect(row.name, isNot(deletedRow.name));
      });
    });
  });
}
