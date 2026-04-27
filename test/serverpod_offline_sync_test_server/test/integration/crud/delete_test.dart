import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
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

  // TODO: Add tests for cascade delete.
  // TODO: Add tests for delete of rows with unique indexes (must rename fields).
}
