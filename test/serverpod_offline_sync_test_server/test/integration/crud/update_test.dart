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

    // TODO: Add tests for update method.

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
          {'name', 'organizationId', 'oldCompanyId'},
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

  // TODO: Add tests for update that generates unique conflict with a deleted row.
}
