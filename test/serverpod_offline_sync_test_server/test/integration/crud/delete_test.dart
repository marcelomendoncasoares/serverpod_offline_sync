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

  group('Given a unique row that was deleted,', () {
    late Unique unique;

    setUp(() async {
      unique = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(session, Unique(name: 'test'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.deleteRow(session, unique, transaction: tx),
      );
    });

    test(
      'then the unique property of the row is updated to a conflict-free value.',
      () async {
        final row = await Unique.db.findById(testSession, unique.id!);

        expect(row, isNotNull);
        expect(row!.name, startsWith(unique.name));
        expect(row.name, contains('${unique.name}__deleted__${unique.id!}'));
      },
    );
  });

  group('Given a row with a unique UUID value that was deleted,', () {
    const uuidValue = UuidValue.raw('11111111-1111-4111-8111-111111111111');
    late UniqueUuid uniqueUuid;

    setUp(() async {
      uniqueUuid = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.insertRow(
          session,
          UniqueUuid(value: uuidValue),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => UniqueUuid.db.deleteRow(session, uniqueUuid, transaction: tx),
      );
    });

    test(
      'then the unique UUID property of the row is updated to a conflict-free value.',
      () async {
        final row = await UniqueUuid.db.findById(testSession, uniqueUuid.id!);

        expect(row, isNotNull);
        expect(row!.value, isNot(uniqueUuid.value));
      },
    );

    test(
      'then another row can reuse the original UUID value.',
      () async {
        final row = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueUuid.db.insertRow(
            session,
            UniqueUuid(value: uniqueUuid.value),
            transaction: tx,
          ),
        );

        expect(row.value, uniqueUuid.value);
      },
    );
  });

  group(
    'Given an address row with a unique nullable UUID foreign key that was deleted,',
    () {
      late Address address;
      late Person person;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              Person.db.insertRow(session, Person(name: 'inhabitant'), transaction: tx),
        );

        address = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Address.db.insertRow(
            session,
            Address(street: 'Pine', inhabitantId: person.id),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Address.db.deleteRow(session, address, transaction: tx),
        );
      });

      test(
        'then the unique nullable UUID foreign key is set to null.',
        () async {
          final row = await Address.db.findById(testSession, address.id!);

          expect(row, isNotNull);
          expect(row!.inhabitantId, isNull);
        },
      );

      test(
        'then another row can reuse the original foreign key value.',
        () async {
          final row = await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Address.db.insertRow(
              session,
              Address(street: 'Cedar', inhabitantId: person.id),
              transaction: tx,
            ),
          );

          expect(row.inhabitantId, person.id);
        },
      );
    },
  );

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

  group('Given an ON DELETE CASCADE city -> organization -> person relationship, ', () {
    late City city;
    late Organization organization;
    late Person person;

    setUp(() async {
      city = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => City.db.insertRow(session, City(name: 'parent'), transaction: tx),
      );

      organization = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Organization.db.insertRow(
          session,
          Organization(name: 'child', cityId: city.id),
          transaction: tx,
        ),
      );

      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'grandchild', organizationId: organization.id),
          transaction: tx,
        ),
      );
    });

    group('when deleting the city with delete,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => City.db.delete(session, [city], transaction: tx),
        );
      });

      test('then a CRDT tombstone is created for the organization row.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(organization.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);
      });

      test('then a CRDT tombstone is also created for the person row.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);
      });
    });

    group('when deleting the city,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => City.db.deleteRow(session, city, transaction: tx),
        );
      });

      test('then a CRDT tombstone is created for the organization row.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(organization.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);
      });

      test(
        'then the organization row still exist on the organization table.',
        () async {
          final row = await Organization.db.findFirstRow(
            // Use the test session to avoid the tombstone filter of the CRDT database.
            testSession,
            where: (t) => t.id.equals(organization.id),
          );
          expect(row, isNotNull);
          expect(row!.name, organization.name);
        },
      );

      test('then a CRDT tombstone is also created for the person row.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, true);
      });
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

  group('Given an address row with an ON DELETE RESTRICT related person, '
      'when trying to delete the person with deleteWhere,', () {
    late Person person;
    late Future<List<Person>> personDelete;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'unique'), transaction: tx),
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
        (tx) => Person.db.deleteWhere(
          session,
          where: (t) => t.id.equals(person.id),
          transaction: tx,
        ),
      );
    });

    test('then no tombstone is created for the person row.', () async {
      await expectLater(personDelete, throwsA(isA<Exception>()));

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
      );

      expect(tombstone, isNull);
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
          session,
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

    group('when deleting the person with delete,', () {
      setUp(() async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.delete(session, [person], transaction: tx),
        );
      });

      test('then the town row is updated.', () async {
        final updatedTown = await Town.db.findFirstRow(
          session,
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
          Company(name: 'test', townId: town.id),
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
