import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an empty local database configured with a persistent CRDT user id,', () {
    late OfflineSyncDatabaseSession app;

    setUpAll(() async {
      app = OfflineSyncDatabaseSession.wraps(
        await createAdditionalTestSession(),
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await app.db.initialize();
    });

    group('when a Person is inserted without a transaction,', () {
      late Person? loaded;
      late OfflineSyncSpace? space;
      late CrdtNode? userNode;
      late CrdtDataRow? fact;

      setUpAll(() async {
        final person = await Person.db.insertRow(app, Person(name: 'local-only'));

        loaded = await Person.db.findById(app, person.id!);
        space = await OfflineSyncSpace.db.findFirstRow(
          app,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
        );
        userNode = await CrdtNode.db.findFirstRow(
          app,
          where: (t) => t.localUserUuid.equals(testCrdtUserId),
        );
        fact = await CrdtDataRow.db.findFirstRow(
          app,
          where: (t) => t.uuidRowId.equals(person.id),
        );
      });

      test('then the row is persisted.', () {
        expect(loaded?.name, 'local-only');
      });

      test('then the CRDT space exists.', () {
        expect(space, isNotNull);
      });

      test('then the persistent user owns the clock that authored the row.', () {
        expect(userNode, isNotNull);
        expect(fact, isNotNull);
        expect(fact!.nodeId, userNode!.id);
      });

      test('then the CRDT metadata is written.', () {
        expect(fact, isNotNull);
        expect(fact!.spaceId, space!.id);
      });
    });
  });
}
