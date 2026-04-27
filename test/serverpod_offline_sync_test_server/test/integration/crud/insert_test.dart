import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table, '
      'when inserting a Person with insertRow,', () {
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

    test('then the row exists in the person table.', () async {
      final row = await Person.db.findFirstRow(
        session,
        where: (t) => t.id.equals(person.id),
      );
      expect(row, isNotNull);
      expect(row!.name, 'test');
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
  });

  // TODO: Add tests for insert method.
  // TODO: Add a test for insert with ignoreConflicts.

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

    test('when reinserting the row, then it succeeds.', () async {
      final insertFuture = session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, person, transaction: tx),
      );

      await expectLater(
        insertFuture,
        completes,
        reason: 'This should succeed by un-marking the row as tombstoned.',
      );

      final newPerson = await insertFuture;
      expect(newPerson, isNotNull);
      expect(newPerson.name, person.name);
    });
  });

  group('Given a person table with a deleted row that is reinserted, ', () {
    late Person person;

    setUp(() async {
      final firstPerson = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, Person(name: 'first'), transaction: tx),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, firstPerson, transaction: tx),
      );

      final secondPerson = firstPerson.copyWith(name: 'second');
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, secondPerson, transaction: tx),
      );
    });

    group('when calling findById,', () {
      late Person? foundPerson;

      setUp(() async {
        foundPerson = await Person.db.findById(session, person.id!);
      });

      test('then it finds the row.', () async {
        expect(foundPerson, isNotNull);
      });

      test('then it has the reinserted name.', () async {
        expect(foundPerson!.name, 'second');
      });
    });
  });

  // TODO: Add tests for insert that generates unique conflict with a deleted row.
}
