import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

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
