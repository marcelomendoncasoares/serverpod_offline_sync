import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart' show ClientDatabaseSession;
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

  group('Given a generated sync session with a persisted Person,', () {
    late String path;
    late OfflineSyncDatabaseSession session;
    late Person person;
    late UuidValue nodeId;

    setUpAll(() async {
      path = p.join(directory.path, 'reopened.db');
      session = await client.createSyncSession(path, persistentUserId: userId);
      addTearDown(session.close);
      person = await Person.db.insertRow(session, Person(name: 'Alice'));
      nodeId = await session.db.currentNodeId();
    });

    group('when it is closed and the database is reopened,', () {
      late OfflineSyncDatabaseSession reopened;

      setUpAll(() async {
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
    });
  });

  group('Given a generated sync session,', () {
    late OfflineSyncDatabaseSession session;

    setUpAll(() async {
      session = await client.createSyncSession(
        p.join(directory.path, 'repeated.db'),
        persistentUserId: userId,
      );
      addTearDown(session.close);
    });

    group('when it is closed concurrently and closed again afterwards,', () {
      setUpAll(() async {
        await Future.wait([session.close(), session.close()]);
        await session.close();
      });

      test('then every close completes and the database stays closed.', () async {
        await expectLater(session.db.testConnection(), throwsStateError);
      });
    });
  });

  group('Given two generated sync sessions for different replica files,', () {
    late OfflineSyncDatabaseSession first;
    late OfflineSyncDatabaseSession second;

    setUpAll(() async {
      first = await client.createSyncSession(
        p.join(directory.path, 'first.db'),
        persistentUserId: userId,
      );
      addTearDown(first.close);
      second = await client.createSyncSession(
        p.join(directory.path, 'second.db'),
        persistentUserId: userId,
      );
      addTearDown(second.close);
    });

    group('when one session is closed and a Person is written to the other,', () {
      late Person person;

      setUpAll(() async {
        await first.close();
        person = await Person.db.insertRow(second, Person(name: 'Bob'));
      });

      test('then the other replica can still read the persisted Person.', () async {
        expect((await Person.db.findById(second, person.id!))?.name, 'Bob');
      });
    });
  });

  group('Given a generated sync session wrapped in another sync session,', () {
    late OfflineSyncDatabaseSession session;
    late OfflineSyncDatabaseSession outer;

    setUpAll(() async {
      session = await client.createSyncSession(
        p.join(directory.path, 'nested.db'),
        persistentUserId: userId,
      );
      addTearDown(session.close);
      outer = OfflineSyncDatabaseSession.wraps(session, syncTables: syncTables);
    });

    group('when the outer session is closed,', () {
      setUpAll(() async {
        await outer.close();
      });

      test('then the underlying client database is closed.', () async {
        await expectLater(session.db.testConnection(), throwsStateError);
      });
    });
  });

  group(
    'Given a sync session constructed directly from an externally owned database,',
    () {
      late ClientDatabaseSession owner;
      late OfflineSyncDatabaseSession session;

      setUpAll(() async {
        owner = await client.createSession(p.join(directory.path, 'external.db'));
        addTearDown(owner.close);
        session = OfflineSyncDatabaseSession(owner.db, syncTables: syncTables);
      });

      group('when closing the sync session is attempted,', () {
        Object? closeError;

        setUpAll(() async {
          try {
            await session.close();
          } on Object catch (error) {
            closeError = error;
          }
        });

        test(
          'then it rejects the operation and leaves the owner connection open.',
          () async {
            expect(closeError, isUnsupportedError);
            expect(await owner.db.testConnection(), isTrue);
          },
        );
      });
    },
  );
}
