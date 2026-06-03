// Uses serverpod_database and serverpod_test types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

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

  final clientSyncTables = [client.Unique.t];
  final serverSyncTables = [server.Unique.t];

  late client.Client syncHttpClient;
  late CrdtDatabaseSession serverSession;
  late CrdtDatabaseSession firstClientSession;
  late CrdtDatabaseSession secondClientSession;

  withServerpod(
    'Given a server and two client CRDT sessions for the same user that are initialized with the unique sync table',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();

      rawServerSession.serverpod
        ..initializeCrdtSync(syncTables: serverSyncTables)
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          testCrdtUserId.toString(),
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        syncHttpClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        firstClientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await firstClientSession.db.initialize();

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await secondClientSession.db.initialize();

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
        'when both clients insert different rows with the same unique value and the older row reaches the server first, '
        'then exactly the older row remains visible on every node.',
        () async {
          final olderRow = await client.Unique.db.insertRow(
            firstClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 2));
          final newerRow = await client.Unique.db.insertRow(
            secondClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
          );

          await _syncUniqueConflictToAllNodes(
            syncHttpClient,
            firstClientSession,
            secondClientSession,
          );
          await _expectOnlyVisibleUniqueRowOnAllNodes(
            firstClientSession: firstClientSession,
            secondClientSession: secondClientSession,
            serverSession: serverSession,
            visibleId: olderRow.id!,
            hiddenId: newerRow.id!,
          );
        },
      );

      test(
        'when both clients insert different rows with the same unique value and the older row reaches the server second, '
        'then exactly the older row remains visible on every node.',
        () async {
          final olderRow = await client.Unique.db.insertRow(
            secondClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 2));
          final newerRow = await client.Unique.db.insertRow(
            firstClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
          );

          await _syncUniqueConflictToAllNodes(
            syncHttpClient,
            firstClientSession,
            secondClientSession,
          );
          await _expectOnlyVisibleUniqueRowOnAllNodes(
            firstClientSession: firstClientSession,
            secondClientSession: secondClientSession,
            serverSession: serverSession,
            visibleId: olderRow.id!,
            hiddenId: newerRow.id!,
          );
        },
      );

      test(
        'when both clients update different rows to the same unique value, '
        'then exactly the row with the older unique update remains visible on every node.',
        () async {
          final firstRow = await client.Unique.db.insertRow(
            firstClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'first-name'),
          );
          final secondRow = await client.Unique.db.insertRow(
            firstClientSession,
            client.Unique(id: const Uuid().v7obj(), name: 'second-name'),
          );
          await _syncUniqueConflictToAllNodes(
            syncHttpClient,
            firstClientSession,
            secondClientSession,
          );

          await client.Unique.db.updateRow(
            firstClientSession,
            firstRow.copyWith(name: 'shared-name'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await client.Unique.db.updateRow(
            secondClientSession,
            secondRow.copyWith(name: 'shared-name'),
          );

          await _syncUniqueConflictToAllNodes(
            syncHttpClient,
            secondClientSession,
            firstClientSession,
          );
          await _expectOnlyVisibleUniqueRowOnAllNodes(
            firstClientSession: firstClientSession,
            secondClientSession: secondClientSession,
            serverSession: serverSession,
            visibleId: firstRow.id!,
            hiddenId: secondRow.id!,
          );
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );
    },
  );
}

Future<void> _syncUniqueConflictToAllNodes(
  client.Client syncHttpClient,
  CrdtDatabaseSession firstClientDatabaseSession,
  CrdtDatabaseSession secondClientDatabaseSession,
) async {
  await syncHttpClient.crdt.syncOnce(firstClientDatabaseSession);
  await syncHttpClient.crdt.syncOnce(secondClientDatabaseSession);
  await syncHttpClient.crdt.syncOnce(firstClientDatabaseSession);
  await syncHttpClient.crdt.syncOnce(secondClientDatabaseSession);
}

Future<void> _expectOnlyVisibleUniqueRowOnAllNodes({
  required CrdtDatabaseSession firstClientSession,
  required CrdtDatabaseSession secondClientSession,
  required CrdtDatabaseSession serverSession,
  required UuidValue visibleId,
  required UuidValue hiddenId,
}) async {
  await _expectOnlyVisibleClientUniqueRow(
    firstClientSession,
    visibleId: visibleId,
    hiddenId: hiddenId,
  );
  await _expectOnlyVisibleClientUniqueRow(
    secondClientSession,
    visibleId: visibleId,
    hiddenId: hiddenId,
  );
  await _expectOnlyVisibleServerUniqueRow(
    serverSession,
    visibleId: visibleId,
    hiddenId: hiddenId,
  );
}

Future<void> _expectOnlyVisibleClientUniqueRow(
  CrdtDatabaseSession session, {
  required UuidValue visibleId,
  required UuidValue hiddenId,
}) async {
  final rows = await client.Unique.db.find(session);

  expect(rows, hasLength(1));
  expect(rows.single.id, visibleId);
  expect(rows.single.name, 'shared-name');
  expect(await client.Unique.db.findById(session, hiddenId), isNull);
}

Future<void> _expectOnlyVisibleServerUniqueRow(
  CrdtDatabaseSession session, {
  required UuidValue visibleId,
  required UuidValue hiddenId,
}) async {
  final rows = await server.Unique.db.find(session);

  expect(rows, hasLength(1));
  expect(rows.single.id, visibleId);
  expect(rows.single.name, 'shared-name');
  expect(await server.Unique.db.findById(session, hiddenId), isNull);
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
