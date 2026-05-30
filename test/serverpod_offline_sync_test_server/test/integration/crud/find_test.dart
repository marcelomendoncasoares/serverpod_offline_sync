import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

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
        await CrdtDataDeleted.db.updateWhere(
          session,
          columnValues: (t) => [
            t.nodeId(1),
            t.hlcDatetime(DateTime.now().toUtc()),
            t.hlcCounter(1),
            t.clFlag(2),
            t.reason(CrdtDataDeletedReason.userDelete),
          ],
          where: (t) => t.rowId.equals(personCrdtRow!.id),
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
