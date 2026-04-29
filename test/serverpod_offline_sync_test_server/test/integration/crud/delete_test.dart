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
          Person(name: 'test'),
          transaction: tx,
        ),
      );
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

      test('then the row still exist on the person table.', () async {
        final row = await Person.db.findFirstRow(
          // Use the test session to avoid the tombstone filter of the CRDT database.
          testSession,
          where: (t) => t.id.equals(person.id),
        );
        expect(row, isNotNull);
        expect(row!.name, person.name);
      });
    });
  });

  group('Given a person table with a deleted row, ', () {
    late Person person;
    late CrdtDataDeleted firstDeletedTombstone;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'test'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      firstDeletedTombstone = (await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      ))!;
    });

    group('when deleting the person again with deleteRow,', () {
      Exception? exception;

      setUp(() async {
        // We can't store the future to test the completion because SQLite will
        // throw on the zone where the future was created and break the test.
        try {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.deleteRow(session, person, transaction: tx),
          );
          exception = null;
        } on Exception catch (e) {
          exception = e;
        }
      });

      test('then it throws.', () async {
        expect(
          exception,
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to delete row, no rows deleted.'),
          ),
        );
      });

      test('then the tombstone is not updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);

        final firstDeletedTombstoneHlc = firstDeletedTombstone.toHlcForNode(
          firstDeletedTombstone.node!.uuidNodeId,
        );
        final tombstoneHlc = tombstone.toHlcForNode(
          tombstone.node!.uuidNodeId,
        );

        expect(tombstoneHlc, equals(firstDeletedTombstoneHlc));
      });
    });

    group('when deleting the person again with delete,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.delete(
            session,
            [person],
            transaction: tx,
          ),
        );
      });

      test('then the tombstone is not updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);

        final firstDeletedTombstoneHlc = firstDeletedTombstone.toHlcForNode(
          firstDeletedTombstone.node!.uuidNodeId,
        );
        final tombstoneHlc = tombstone.toHlcForNode(
          tombstone.node!.uuidNodeId,
        );

        expect(tombstoneHlc, equals(firstDeletedTombstoneHlc));
      });
    });

    group('when deleting the person again with deleteWhere,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteWhere(
            session,
            where: (t) => t.id.equals(person.id),
            transaction: tx,
          ),
        );
      });

      test('then the tombstone is not updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);

        final firstDeletedTombstoneHlc = firstDeletedTombstone.toHlcForNode(
          firstDeletedTombstone.node!.uuidNodeId,
        );
        final tombstoneHlc = tombstone.toHlcForNode(
          tombstone.node!.uuidNodeId,
        );

        expect(tombstoneHlc, equals(firstDeletedTombstoneHlc));
      });
    });
  });

  group('Given a person that was deleted and reinserted, ', () {
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

      final tombstones = await CrdtDataDeleted.db.updateWhere(
        session,
        columnValues: (t) => [t.isDeleted(false)],
        where: (t) => t.row.uuidRowId.equals(person.id),
      );

      expect(tombstones.single.isDeleted, isFalse);
    });

    group('when deleting the person again,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, person, transaction: tx),
        );
      });

      test('then the tombstone is updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );
        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);
      });
    });
  });

  group('Given a person row with an ON DELETE CASCADE related address, '
      'when the person is deleted,', () {
    late Person person;
    late Address address;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'cascade'),
          transaction: tx,
        ),
      );

      address = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Address.db.insertRow(
          session,
          Address(street: 'Main', inhabitantId: person.id),
          transaction: tx,
        ),
      );

      await Person.db.deleteRow(session, person);
    });

    test('then a CRDT tombstone is created for the address row.', () async {
      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(address.id),
      );

      expect(tombstone, isNotNull);
      expect(tombstone!.isDeleted, true);
    });

    test('then the address row still exist on the address table.', () async {
      final row = await Address.db.findFirstRow(
        // Use the test session to avoid the tombstone filter of the CRDT database.
        testSession,
        where: (t) => t.id.equals(address.id),
      );
      expect(row, isNotNull);
      expect(row!.street, address.street);
    });
  });

  group('Given an address row with an ON DELETE RESTRICT related person, '
      'when trying to delete the person,', () {
    late Future<Person> personDelete;

    setUp(() async {
      final person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'unique'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Address.db.insertRow(
          session,
          Address(street: 'Oak', inhabitantId: person.id),
          transaction: tx,
        ),
      );

      personDelete = session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );
    });

    test('then the delete fails.', () async {
      await expectLater(personDelete, throwsA(isA<Exception>()));
    });
  });

  group('Given a town row with an ON DELETE SET NULL related person,', () {
    late Town town;
    late Person person;
    late CrdtDataField attachedCrdtField;

    setUp(() async {
      town = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(session, Town(name: 'test'), transaction: tx),
      );

      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'test'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.attachRow.mayor(session, town, person, transaction: tx),
      );

      attachedCrdtField = (await CrdtDataField.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(town.id) & t.column.name.equals('mayorId'),
        include: CrdtDataField.include(node: CrdtNode.include()),
      ))!;
    });

    group('when deleting the person,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, person, transaction: tx),
        );
      });

      test('then the town row is updated.', () async {
        final updatedTown = await Town.db.findFirstRow(
          testSession,
          where: (t) => t.id.equals(town.id),
        );
        expect(updatedTown, isNotNull);
        expect(updatedTown!.mayorId, isNull);
      });

      test('then the CRDT field entry for the mayor is updated.', () async {
        final crdtField = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(town.id) & t.column.name.equals('mayorId'),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );

        final attachedCrdtFieldHlc = attachedCrdtField.toHlcForNode(
          attachedCrdtField.node!.uuidNodeId,
        );
        final crdtFieldHlc = crdtField!.toHlcForNode(
          crdtField.node!.uuidNodeId,
        );

        expect(crdtFieldHlc, greaterThan(attachedCrdtFieldHlc));
      });
    });
  });

  group('Given a company row with an ON DELETE SET DEFAULT related town,', () {
    late Company company;
    late Town town;
    late CrdtDataRow companyCrdtRow;

    late final defaultTown = Town(
      id: const UuidValue.raw('550e8400-e29b-41d4-a716-446655440000'),
      name: 'default',
    );

    setUp(() async {
      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(session, defaultTown, transaction: tx),
      );

      town = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(session, Town(name: 'default'), transaction: tx),
      );

      company = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Company.db.insertRow(
          session,
          Company(name: 'test', townId: town.id!),
          transaction: tx,
        ),
      );

      companyCrdtRow = (await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(company.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      ))!;
    });

    group('when deleting the related town,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.deleteRow(session, town, transaction: tx),
        );
      });

      test('then the company row is updated to the default town.', () async {
        final updatedCompany = await Company.db.findFirstRow(
          testSession,
          where: (t) => t.id.equals(company.id),
        );

        expect(updatedCompany, isNotNull);
        expect(updatedCompany!.townId, defaultTown.id);
      });

      test('then a CRDT field entry for the town is updated.', () async {
        final crdtField = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(company.id) & t.column.name.equals('townId'),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );

        final companyCrdtRowHlc = companyCrdtRow.toHlcForNode(
          companyCrdtRow.node!.uuidNodeId,
        );
        final crdtFieldHlc = crdtField!.toHlcForNode(
          crdtField.node!.uuidNodeId,
        );

        expect(crdtFieldHlc, greaterThan(companyCrdtRowHlc));
      });
    });
  });
}
