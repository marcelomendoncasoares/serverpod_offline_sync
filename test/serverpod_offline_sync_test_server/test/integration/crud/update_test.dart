import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a person table with an existing row, ', () {
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

        final fieldHlc = field!.toHlcForNode(field.node!.uuidNodeId);
        final rowHlc = field.row!.toHlcForNode(field.row!.node!.uuidNodeId);
        expect(fieldHlc, greaterThan(rowHlc));
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
  });

  group('Given a person table with a deleted row, ', () {
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
  });

  group('Given a person table with a deleted organization row, ', () {
    late Person person;
    late Organization deletedOrganization;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'new'), transaction: tx),
      );

      deletedOrganization = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Organization.db.insertRow(
          session,
          Organization(name: 'deleted'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Organization.db.deleteRow(
          session,
          deletedOrganization,
          transaction: tx,
        ),
      );
    });

    group(
      'when updating the organization foreign key with updateWhere to the deleted row id,',
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

        test('then the row keeps its original foreign key value.', () async {
          await expectLater(updateFuture, throwsA(isA<Exception>()));

          final row = await Person.db.findById(session, person.id!);
          expect(row, isNotNull);
          expect(row!.organizationId, isNull);
        });
      },
    );
  });

  group(
    'Given a person table with an existing row that was inserted and updated from a different node, ',
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

        final user = await CrdtUser.db.findFirstRow(session);

        otherNode = await CrdtNode.db.insertRow(
          session,
          CrdtNode(userId: user!.id!),
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

  group('Given a unique table with one visible and one deleted row, ', () {
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

    group('when updating the table with updateWhere, ', () {
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

        // Use the test session to find the deleted row, since it is not visible
        // in the CRDT database.
        final foundDeletedRow = await Unique.db.findById(testSession, deletedRow.id!);
        expect(foundDeletedRow, isNotNull);
        expect(foundDeletedRow!.name, startsWith(deletedRow.name));
        expect(foundDeletedRow.name, isNot(deletedRow.name));
      });
    });

    group('when updating the visible row to the same name as the deleted row, ', () {
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
        final row = await Unique.db.findById(testSession, deletedRow.id!);

        expect(row, isNotNull);
        expect(row!.name, startsWith(deletedRow.name));
        expect(row.name, isNot(deletedRow.name));
      });
    });
  });
}
