import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given rows owned by two different scopes,', () {
    late Person firstUserPerson;
    late Person otherUserPerson;
    late UuidValue otherUserId;
    late int firstScopeId;
    late int otherScopeId;

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
      final firstScope = await CrdtScope.db.findFirstRow(
        session,
        where: (t) => t.uuidScopeId.equals(testCrdtUserId),
      );
      firstScopeId = firstScope!.id!;

      otherUserPerson = await session.db.transactionForUser(
        otherUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'other user'),
          transaction: tx,
        ),
      );
      final otherScope = await CrdtScope.db.findFirstRow(
        session,
        where: (t) => t.uuidScopeId.equals(otherUserId),
      );
      otherScopeId = otherScope!.id!;
    });

    test(
      'when finding inside the first scope, then only the first scope row is returned.',
      () async {
        final rows = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.find(session, transaction: tx),
        );

        expect(rows.map((row) => row.id).toSet(), {firstUserPerson.id});
        expect(rows.single.scopeId, isNull);
      },
    );

    test(
      'when finding the other scope row by id inside the first scope, then null is returned.',
      () async {
        final row = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.findById(session, otherUserPerson.id!, transaction: tx),
        );

        expect(row, isNull);
      },
    );

    test(
      'when finding without a scope, then both rows keep their stored scopeId.',
      () async {
        final rows = await Person.db.find(session);

        expect(rows.map((row) => row.id).toSet(), {
          firstUserPerson.id,
          otherUserPerson.id,
        });
        expect(
          {for (final row in rows) row.id: row.scopeId},
          {
            firstUserPerson.id: firstScopeId,
            otherUserPerson.id: otherScopeId,
          },
        );
      },
    );
  });

  group('Given a town row with an included mayor owned by the same scope,', () {
    late Town town;
    late Person mayor;
    late int scopeId;

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

      final scope = await CrdtScope.db.findFirstRow(
        session,
        where: (t) => t.uuidScopeId.equals(testCrdtUserId),
      );
      scopeId = scope!.id!;
    });

    test(
      'when finding with includes inside the owner scope, '
      'then the returned town and mayor hide scopeId.',
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
        expect(found!.scopeId, isNull);
        expect(found.mayor, isNotNull);
        expect(found.mayor!.scopeId, isNull);
      },
    );

    test(
      'when finding with includes without a scope, '
      'then the returned town and mayor keep their stored scopeId.',
      () async {
        final found = await Town.db.findById(
          session,
          town.id!,
          include: Town.include(mayor: Person.include()),
        );

        expect(found, isNotNull);
        expect(found!.scopeId, scopeId);
        expect(found.mayor, isNotNull);
        expect(found.mayor!.scopeId, scopeId);
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
