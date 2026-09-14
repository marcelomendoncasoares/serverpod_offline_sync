import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given rows owned by two different spaces,', () {
    late Person firstUserPerson;
    late Person otherUserPerson;
    late UuidValue otherUserId;
    late int firstSpaceId;
    late int otherSpaceId;

    setUp(() async {
      otherUserId = const Uuid().v7obj();

      firstUserPerson = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'first user'),
          transaction: tx,
        ),
      );
      final firstSpace = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      firstSpaceId = firstSpace!.id!;

      otherUserPerson = await session.db.transactionForUser(
        otherUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'other user'),
          transaction: tx,
        ),
      );
      final otherSpace = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(otherUserId),
      );
      otherSpaceId = otherSpace!.id!;
    });

    group('when finding inside the first space,', () {
      late List<Person> rows;

      setUp(() async {
        rows = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.find(session, transaction: tx),
        );
      });

      test('then only the first space row is returned.', () async {
        expect(rows.map((row) => row.id).toSet(), {firstUserPerson.id});
      });

      test('then spaceId is null.', () async {
        expect(rows.single.spaceId, isNull);
      });
    });

    test(
      'when finding the other space row by id inside the first space, '
      'then it returns null.',
      () async {
        final row = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.findById(session, otherUserPerson.id!, transaction: tx),
        );

        expect(row, isNull);
      },
    );

    test(
      'when counting inside the first space, '
      'then only the first space row is counted.',
      () async {
        final count = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.count(session, transaction: tx),
        );

        expect(count, 1);
      },
    );

    test(
      'when finding without a space, '
      'then both rows keep their stored spaceId.',
      () async {
        final rows = await Person.db.find(session);

        expect(rows.map((row) => row.id).toSet(), {
          firstUserPerson.id,
          otherUserPerson.id,
        });
        expect(
          {for (final row in rows) row.id: row.spaceId},
          {
            firstUserPerson.id: firstSpaceId,
            otherUserPerson.id: otherSpaceId,
          },
        );
      },
    );
  });

  group('Given a town row with an included mayor owned by the same space,', () {
    late Town town;
    late Person mayor;
    late int spaceId;

    setUp(() async {
      town = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(session, Town(name: 'Rio'), transaction: tx),
      );

      mayor = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'Lisa'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.attachRow.mayor(session, town, mayor, transaction: tx),
      );

      final space = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      spaceId = space!.id!;
    });

    test(
      'when finding with includes inside the owner space, '
      'then the returned town and mayor hide spaceId.',
      () async {
        final found = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.findById(
            session,
            town.id!,
            include: Town.include(mayor: Person.include()),
            transaction: tx,
          ),
        );

        expect(found, isNotNull);
        expect(found!.spaceId, isNull);
        expect(found.mayor, isNotNull);
        expect(found.mayor!.spaceId, isNull);
      },
    );

    test(
      'when finding with includes without a space, '
      'then the returned town and mayor keep their stored spaceId.',
      () async {
        final found = await Town.db.findById(
          session,
          town.id!,
          include: Town.include(mayor: Person.include()),
        );

        expect(found, isNotNull);
        expect(found!.spaceId, spaceId);
        expect(found.mayor, isNotNull);
        expect(found.mayor!.spaceId, spaceId);
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

    test('when calling count, then the deleted row is not counted.', () async {
      expect(await Person.db.count(session), 0);
    });

    test(
      'when calling count with includeHiddenRows, '
      'then the deleted row is counted.',
      () async {
        expect(await Person.db.count(session, where: (t) => t.includeHiddenRows), 1);
      },
    );
  });

  // This test is not expected to happen in production since the tombstone
  // should never be manually accessed. It is here mostly to validate the
  // correct filtering of include filters.
  group(
    'Given a town row that references a manually tombstoned person row,',
    () {
      late Town town;
      late Person person;

      setUp(() async {
        town = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(session, Town(name: 'Rio'), transaction: tx),
        );

        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, Person(name: 'Lisa'), transaction: tx),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.attachRow.mayor(session, town, person, transaction: tx),
        );

        final personCrdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
        );

        expect(personCrdtRow, isNotNull);

        // Manually tombstone the person row, since a delete will apply the
        // ON DELETE RESTRICT constraint on the town row.
        await CrdtDataDeleted.db.insert(
          session,
          [
            CrdtDataDeleted(
              rowId: personCrdtRow!.id!,
              nodeId: 1,
              hlcDatetime: DateTime.now().toUtc(),
              hlcCounter: 1,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
        );
        await CrdtDataRow.db.updateRow(
          session,
          personCrdtRow.copyWith(
            visibility: CrdtDataRowVisibility.userDelete,
          ),
          columns: (t) => [t.visibility],
        );
      });

      test(
        'when calling findById with includes, then it does not return the town.',
        () async {
          final found = await Town.db.findById(
            session,
            town.id!,
            include: Town.include(mayor: Person.include()),
          );

          expect(found, isNull);
        },
      );

      test(
        'when calling findFirstRow with includes, then it does not return the town.',
        () async {
          final found = await Town.db.findFirstRow(
            session,
            where: (t) => t.id.equals(town.id),
            include: Town.include(mayor: Person.include()),
          );

          expect(found, isNull);
        },
      );

      test(
        'when calling find with includes, then it does not return the town.',
        () async {
          final found = await Town.db.find(
            session,
            where: (t) => t.id.equals(town.id),
            include: Town.include(mayor: Person.include()),
          );

          expect(found, isEmpty);
        },
      );
    },
  );
}
