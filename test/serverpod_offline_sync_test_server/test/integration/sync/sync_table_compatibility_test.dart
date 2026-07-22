import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  withServerpod(
    'Given initialized server and client CRDT sessions with matching sync tables,',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      late client.Client testClient;
      late CrdtDatabaseSession clientSession;
      late CrdtDatabaseSession serverSession;

      final serverSyncTables = [
        server.Address.t,
        server.Person.t,
        server.Types.t,
        server.Unique.t,
      ];

      final clientSyncTables = [
        client.Address.t,
        client.Person.t,
        client.Types.t,
        client.Unique.t,
      ];

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      test(
        'when client syncOnce is called, '
        'then synchronization completes.',
        () async {
          await expectLater(
            testClient.crdt.syncOnce(clientSession).timeout(const Duration(seconds: 3)),
            completes,
          );
        },
      );
    },
  );

  withServerpod(
    'Given initialized server and client CRDT sessions with different sync tables,',
    rollbackDatabase: RollbackDatabase.disabled,
    // Silent mode avoids printing the symmetric hash mismatch from the server.
    // The client-side exception is asserted below.
    testServerOutputMode: TestServerOutputMode.silent,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      late client.Client testClient;
      late CrdtDatabaseSession clientSession;
      late CrdtDatabaseSession serverSession;

      final serverSyncTables = [
        server.Address.t,
        server.Person.t,
        server.Types.t,
        server.Unique.t,
      ];

      final clientSyncTables = [
        client.Address.t,
        client.Person.t,
      ];

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      final expectedHashMismatch = isA<SyncTablesHashMismatchException>()
          .having(
            (e) => e.toString(),
            'message',
            contains('SyncTablesHashMismatchException: schema hash mismatch.'),
          )
          .having(
            (e) => e.toString(),
            'message',
            contains(
              'Ensure both sides are on the same schema version before syncing.',
            ),
          );

      test(
        'when client syncOnce is called, '
        'then SyncTablesHashMismatchException is thrown.',
        () async {
          await expectLater(
            testClient.crdt.syncOnce(clientSession),
            throwsA(expectedHashMismatch),
          );
        },
      );

      test(
        'when client syncContinuously is called, '
        'then SyncTablesHashMismatchException is thrown.',
        () async {
          final syncSession = testClient.crdt.syncContinuously(clientSession);
          addTearDown(syncSession.cancel);

          await expectLater(
            syncSession.done,
            throwsA(expectedHashMismatch),
          );
        },
      );
    },
  );
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
