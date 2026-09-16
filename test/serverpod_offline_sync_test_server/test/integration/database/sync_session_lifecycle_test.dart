import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late Client client;
  final userId = UuidValue.fromString('00000000-0000-4000-8000-000000000001');

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sync_session_lifecycle_');
    client = Client('http://localhost:8080/');
  });

  tearDownAll(() async {
    client.close();
    await directory.delete(recursive: true);
  });

  group(
    'Given a generated sync session with a persisted Person, '
    'when it is closed and the database is reopened,',
    () {
      late OfflineSyncDatabaseSession session;
      late OfflineSyncDatabaseSession reopened;
      late Person person;
      late UuidValue nodeId;

      setUpAll(() async {
        final path = p.join(directory.path, 'reopened.db');
        session = await client.createSyncSession(path, persistentUserId: userId);
        addTearDown(session.close);
        person = await Person.db.insertRow(session, Person(name: 'Alice'));
        nodeId = await session.db.currentNodeId();

        await session.close();
        reopened = await client.createSyncSession(path, persistentUserId: userId);
        addTearDown(reopened.close);
      });

      test('then the closed session rejects database queries.', () async {
        await expectLater(session.db.testConnection(), throwsStateError);
      });

      test('then the stored Person is available in the reopened session.', () async {
        final loaded = await Person.db.findById(reopened, person.id!);

        expect(loaded?.name, 'Alice');
        expect(loaded?.spaceId, person.spaceId);
      });

      test('then the replica keeps its CRDT node identity.', () async {
        expect(await reopened.db.currentNodeId(), nodeId);
      });
    },
  );

  test(
    'Given a generated sync session, '
    'when it is closed concurrently and then closed again, '
    'then every close completes and the database stays closed.',
    () async {
      final session = await client.createSyncSession(
        p.join(directory.path, 'repeated.db'),
        persistentUserId: userId,
      );
      addTearDown(session.close);

      await Future.wait([session.close(), session.close()]);
      await session.close();

      await expectLater(session.db.testConnection(), throwsStateError);
    },
  );

  test(
    'Given two generated sync sessions for different replica files, '
    'when one session is closed, '
    'then the other replica can still persist and read a Person.',
    () async {
      final first = await client.createSyncSession(
        p.join(directory.path, 'first.db'),
        persistentUserId: userId,
      );
      addTearDown(first.close);
      final second = await client.createSyncSession(
        p.join(directory.path, 'second.db'),
        persistentUserId: userId,
      );
      addTearDown(second.close);

      await first.close();
      final person = await Person.db.insertRow(second, Person(name: 'Bob'));

      expect((await Person.db.findById(second, person.id!))?.name, 'Bob');
    },
  );

  test(
    'Given a generated sync session wrapped in another sync session, '
    'when the outer session is closed, '
    'then the underlying client database is closed.',
    () async {
      final session = await client.createSyncSession(
        p.join(directory.path, 'nested.db'),
        persistentUserId: userId,
      );
      addTearDown(session.close);
      final outer = OfflineSyncDatabaseSession.wraps(session, syncTables: syncTables);

      await outer.close();

      await expectLater(session.db.testConnection(), throwsStateError);
    },
  );

  test(
    'Given a sync session constructed directly from an externally owned database, '
    'when closing the sync session is attempted, '
    'then it rejects the operation and leaves the owner connection open.',
    () async {
      final owner = await client.createSession(p.join(directory.path, 'external.db'));
      addTearDown(owner.close);
      final session = OfflineSyncDatabaseSession(owner.db, syncTables: syncTables);

      await expectLater(session.close(), throwsUnsupportedError);

      expect(await owner.db.testConnection(), isTrue);
    },
  );
}
