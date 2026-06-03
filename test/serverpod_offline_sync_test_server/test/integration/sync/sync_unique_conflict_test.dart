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

      group(
        'and an older server row conflicts with a newer incoming row,',
        () {
          late client.Unique olderRow;
          late client.Unique newerRow;

          setUp(() async {
            olderRow = await client.Unique.db.insertRow(
              firstClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            newerRow = await client.Unique.db.insertRow(
              secondClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );

            await syncHttpClient.crdt.syncOnce(firstClientSession);
          });

          test(
            'when the incoming row synchronizes, '
            'then exactly the older row remains visible on every node.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                secondClientSession,
                firstClientSession,
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
        },
      );

      group(
        'and a newer server row conflicts with an older incoming row,',
        () {
          late client.Unique olderRow;
          late client.Unique newerRow;

          setUp(() async {
            olderRow = await client.Unique.db.insertRow(
              secondClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            newerRow = await client.Unique.db.insertRow(
              firstClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );

            await syncHttpClient.crdt.syncOnce(firstClientSession);
          });

          test(
            'when the incoming row synchronizes, '
            'then exactly the older row remains visible on every node.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                secondClientSession,
                firstClientSession,
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
        },
      );

      group(
        'and a newer server update conflicts with an older incoming update,',
        () {
          late client.Unique olderUpdatedRow;
          late client.Unique newerUpdatedRow;

          setUp(() async {
            olderUpdatedRow = await client.Unique.db.insertRow(
              firstClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'first-name'),
            );
            newerUpdatedRow = await client.Unique.db.insertRow(
              firstClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'second-name'),
            );
            await _syncRowsToAllNodes(
              syncHttpClient,
              firstClientSession,
              secondClientSession,
            );

            await client.Unique.db.updateRow(
              firstClientSession,
              olderUpdatedRow.copyWith(name: 'shared-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            await client.Unique.db.updateRow(
              secondClientSession,
              newerUpdatedRow.copyWith(name: 'shared-name'),
            );

            await syncHttpClient.crdt.syncOnce(secondClientSession);
          });

          test(
            'when the incoming update synchronizes, '
            'then exactly the row with the older unique update remains visible on every node.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                firstClientSession,
                secondClientSession,
              );
              await _expectOnlyVisibleUniqueRowOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                visibleId: olderUpdatedRow.id!,
                hiddenId: newerUpdatedRow.id!,
              );
              await _expectHiddenUniqueRowNameOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                rowId: newerUpdatedRow.id!,
                name: 'shared-name__deleted__${newerUpdatedRow.id!.uuid}',
              );
            },
            timeout: const Timeout(Duration(seconds: 60)),
          );
        },
      );
    },
  );
}

Future<void> _expectHiddenUniqueRowNameOnAllNodes({
  required CrdtDatabaseSession firstClientSession,
  required CrdtDatabaseSession secondClientSession,
  required CrdtDatabaseSession serverSession,
  required UuidValue rowId,
  required String name,
}) async {
  await _expectRawUniqueRowName(firstClientSession, rowId: rowId, name: name);
  await _expectRawUniqueRowName(secondClientSession, rowId: rowId, name: name);
  await _expectRawUniqueRowName(serverSession, rowId: rowId, name: name);
}

Future<void> _expectRawUniqueRowName(
  CrdtDatabaseSession session, {
  required UuidValue rowId,
  required String name,
}) async {
  final result = await session.db.unsafeQuery(
    '''
SELECT "name"
FROM "unique"
WHERE "id" = ${ValueEncoder.instance.convert(rowId)}
''',
  );

  expect(result, hasLength(1));
  expect(result.single.single, name);
}

Future<void> _syncRowsToAllNodes(
  client.Client syncHttpClient,
  CrdtDatabaseSession firstClientSession,
  CrdtDatabaseSession secondClientSession,
) async {
  await syncHttpClient.crdt.syncOnce(firstClientSession);
  await syncHttpClient.crdt.syncOnce(secondClientSession);
  await syncHttpClient.crdt.syncOnce(firstClientSession);
  await syncHttpClient.crdt.syncOnce(secondClientSession);
}

Future<void> _syncIncomingConflictToAllNodes(
  client.Client syncHttpClient,
  CrdtDatabaseSession incomingClientSession,
  CrdtDatabaseSession existingClientSession,
) async {
  await syncHttpClient.crdt.syncOnce(incomingClientSession);
  await syncHttpClient.crdt.syncOnce(existingClientSession);
  await syncHttpClient.crdt.syncOnce(incomingClientSession);
  await syncHttpClient.crdt.syncOnce(existingClientSession);
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
