import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import 'test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given an empty person table, '
    'when inserting a Person with insertRow,',
    () {
      const targetName = 'test';
      late Person person;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: targetName),
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
        expect(row!.name, targetName);
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
          final hlc = crdtRow!.toHlcForNode(crdtRow!.node!.uuidNodeId);
          expect(hlc, greaterThan(Hlc.zero(hlc.node)));
        });
      });

      test('then no CRDT fields metadata are registered.', () async {
        final fieldCount = await CrdtDataField.db.count(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );
        expect(fieldCount, 0);
      });

      test('then no CRDT tombstone is created for the row.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNull);
      });
    },
  );

  // TODO: Add tests for insert.
  // TODO: Add a test for insert with ignoreConflicts.

  group(
    'Given a person table with an existing row, ',
    () {
      const initialName = 'test';
      const targetName = 'test2';
      late Person person;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: initialName),
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
              person.copyWith(name: targetName),
              columns: (t) => [t.name],
              transaction: tx,
            ),
          );
        });

        test('then the person row reflects the new values.', () async {
          final row = await Person.db.findById(session, person.id!);
          expect(row?.name, targetName);
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

      // TODO: Add tests for update.

      group('when updating the Person name column without specifying columns,', () {
        setUp(() async {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.updateRow(
              session,
              person.copyWith(name: targetName),
              transaction: tx,
            ),
          );
        });

        test('then the person row reflects the new values.', () async {
          final row = await Person.db.findById(session, person.id!);
          expect(row?.name, targetName);
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

      group('when deleting the Person row with deleteRow,', () {
        setUp(() async {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.deleteRow(session, person, transaction: tx),
          );
        });

        test('then a CRDT tombstone is created for the row.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(person.id),
          );

          expect(tombstone, isNotNull);
          expect(tombstone!.isDeleted, true);
        });
      });
    },
  );

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

    test('when calling findById, then it returns null.', () async {
      expect(
        await Person.db.findById(session, person.id!),
        isNull,
      );
    });

    test('when calling findFirstRow, then it returns null.', () async {
      expect(
        await Person.db.findFirstRow(
          session,
          where: (t) => t.id.equals(person.id),
        ),
        isNull,
      );
    });

    test('when calling find, then it returns an empty list.', () async {
      expect(
        await Person.db.find(
          session,
          where: (t) => t.id.equals(person.id),
        ),
        isEmpty,
      );
    });
  });
}
