@TestOn('browser')
library;

import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

const _readTimeout = Duration(seconds: 5);

void main() {
  group('Given a persistent user with a personal space on web,', () {
    late UuidValue userId;
    late OfflineSyncDatabaseSession session;

    setUpAll(() async {
      userId = const Uuid().v7obj();
      session = await Client('http://localhost:8081/').createSyncSession(
        'transaction-membership-$userId.db',
        persistentUserId: userId,
      );
      await session.db.currentNodeId();
    });

    tearDownAll(() async {
      await session.close();
    });

    group('when inserting and reading within transactionForUser,', () {
      late Person inserted;
      late List<Person> found;
      late Person? foundById;
      late Person? first;
      late int count;
      late List<Person> committed;

      setUpAll(() async {
        await session.db.transactionForUser(userId, (tx) async {
          inserted = await Person.db.insertRow(
            session,
            Person(name: 'personal'),
            transaction: tx,
          );

          // Bound the read inside the callback so a regression throws and
          // rolls back the transaction instead of keeping its lock forever.
          found = await Person.db.find(session, transaction: tx).timeout(_readTimeout);
          foundById = await Person.db
              .findById(
                session,
                inserted.id!,
                transaction: tx,
              )
              .timeout(_readTimeout);
          first = await Person.db
              .findFirstRow(
                session,
                where: (t) => t.name.equals('personal'),
                transaction: tx,
              )
              .timeout(_readTimeout);
          count = await Person.db.count(session, transaction: tx).timeout(_readTimeout);
        });

        committed = await Person.db.find(session);
      });

      test('then find returns the uncommitted row without deadlocking.', () {
        expect(found.map((row) => row.id), [inserted.id]);
      });

      test('then findById returns the uncommitted row without deadlocking.', () {
        expect(foundById?.id, inserted.id);
      });

      test('then findFirstRow returns the uncommitted row without deadlocking.', () {
        expect(first?.id, inserted.id);
      });

      test('then count includes the uncommitted row without deadlocking.', () {
        expect(count, 1);
      });

      test('then the transaction commits the inserted row.', () {
        expect(committed.map((row) => row.id), [inserted.id]);
      });
    });
  });
}
