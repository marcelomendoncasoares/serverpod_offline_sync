import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    hide Protocol;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  test(
    'Given two databases with the same space layout but different owners, '
    'when one sync context reads both databases for the same user, '
    'then permissions cached from the first database expose no private rows in the second.',
    () async {
      final user = const Uuid().v7obj();
      final otherUser = const Uuid().v7obj();
      final firstRaw = await createAdditionalTestSession();
      final secondRaw = await createAdditionalTestSession();
      final first = OfflineSyncDatabaseSession.wraps(firstRaw, syncTables: syncTables);
      final second = OfflineSyncDatabaseSession.wraps(
        secondRaw,
        syncTables: syncTables,
      );
      await first.db.initialize();
      await second.db.initialize();
      await first.db.transactionForUser(user, (tx) async {
        await Person.db.insertRow(
          first,
          Person(id: const Uuid().v7obj(), name: 'allowed'),
          transaction: tx,
        );
      });
      await first.db.transactionForUser(otherUser, (tx) async {});
      await second.db.transactionForUser(otherUser, (tx) async {
        await Person.db.insertRow(
          second,
          Person(id: const Uuid().v7obj(), name: 'private'),
          transaction: tx,
        );
      });
      await second.db.transactionForUser(user, (tx) async {});
      final shared = OfflineSyncEngine(
        syncTables: syncTables,
        serializationManager: Protocol(),
      );
      final firstReader = OfflineSyncDatabaseSession(
        shared.wrapDatabase(firstRaw.db, persistentUserId: user),
        syncTables: syncTables,
      );
      final secondReader = OfflineSyncDatabaseSession(
        shared.wrapDatabase(secondRaw.db, persistentUserId: user),
        syncTables: syncTables,
      );

      final firstRows = await Person.db.find(firstReader);
      final secondRows = await Person.db.find(secondReader);
      final firstAgain = await Person.db.find(firstReader);

      expect(firstRows.map((row) => row.name), ['allowed']);
      expect(secondRows, isEmpty);
      expect(firstAgain.map((row) => row.name), ['allowed']);
    },
  );
}
