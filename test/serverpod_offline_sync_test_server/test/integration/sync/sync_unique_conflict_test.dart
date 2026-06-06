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
  const syncBatchSize = 1;

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
        ..initializeCrdtSync(
          syncTables: serverSyncTables,
          syncBatchSize: syncBatchSize,
        )
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
          syncBatchSize: syncBatchSize,
          persistentUserId: testCrdtUserId,
        );
        await firstClientSession.db.initialize();

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          syncBatchSize: syncBatchSize,
          persistentUserId: testCrdtUserId,
        );
        await secondClientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
          syncBatchSize: syncBatchSize,
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
            'then both rows remain visible and the older row keeps the unique value.',
            () async {
              await syncHttpClient.crdt.syncOnce(secondClientSession);
              await syncHttpClient.crdt.syncOnce(firstClientSession);

              await _expectVisibleUniqueRowsOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                originalValueId: olderRow.id!,
                conflictValueId: newerRow.id!,
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
            'then both rows remain visible and the older row keeps the unique value.',
            () async {
              await syncHttpClient.crdt.syncOnce(secondClientSession);
              await syncHttpClient.crdt.syncOnce(firstClientSession);

              await _expectVisibleUniqueRowsOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                originalValueId: olderRow.id!,
                conflictValueId: newerRow.id!,
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
            await syncHttpClient.crdt.syncOnce(firstClientSession);
            await syncHttpClient.crdt.syncOnce(secondClientSession);

            // The `firstClientSession` holds the older update.
            await client.Unique.db.updateRow(
              firstClientSession,
              olderUpdatedRow.copyWith(name: 'shared-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            // The `secondClientSession` holds the newer update.
            await client.Unique.db.updateRow(
              secondClientSession,
              newerUpdatedRow.copyWith(name: 'shared-name'),
            );

            // The `secondClientSession` syncs first, so the newer update
            // reaches the server first.
            await syncHttpClient.crdt.syncOnce(secondClientSession);
          });

          test(
            'when the incoming update synchronizes, '
            'then both rows remain visible and the row with the older unique update keeps the unique value.',
            () async {
              await syncHttpClient.crdt.syncOnce(firstClientSession);
              await syncHttpClient.crdt.syncOnce(secondClientSession);

              await _expectVisibleUniqueRowsOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                originalValueId: olderUpdatedRow.id!,
                conflictValueId: newerUpdatedRow.id!,
              );
            },
            timeout: const Timeout(Duration(seconds: 60)),
          );
        },
      );

      group(
        'and an older incoming insert conflicts with a newer server update,',
        () {
          late client.Unique insertedRow;
          late client.Unique updatedRow;

          setUp(() async {
            updatedRow = await client.Unique.db.insertRow(
              firstClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'first-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            insertedRow = await client.Unique.db.insertRow(
              secondClientSession,
              client.Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            );
            await Future<void>.delayed(const Duration(milliseconds: 2));
            await client.Unique.db.updateRow(
              firstClientSession,
              updatedRow.copyWith(name: 'shared-name'),
            );

            await syncHttpClient.crdt.syncOnce(firstClientSession);
          });

          test(
            'when the incoming insert synchronizes, '
            'then both rows remain visible and the row with the older unique value keeps it on every node.',
            () async {
              await syncHttpClient.crdt.syncOnce(secondClientSession);
              await syncHttpClient.crdt.syncOnce(firstClientSession);

              await _expectVisibleUniqueRowsOnAllNodes(
                firstClientSession: firstClientSession,
                secondClientSession: secondClientSession,
                serverSession: serverSession,
                originalValueId: insertedRow.id!,
                conflictValueId: updatedRow.id!,
              );
            },
            timeout: const Timeout(Duration(seconds: 60)),
          );
        },
      );
    },
  );
}

Future<void> _expectVisibleUniqueRowsOnAllNodes({
  required CrdtDatabaseSession firstClientSession,
  required CrdtDatabaseSession secondClientSession,
  required CrdtDatabaseSession serverSession,
  required UuidValue originalValueId,
  required UuidValue conflictValueId,
}) async {
  final firstClientRows = await client.Unique.db.find(firstClientSession);
  expect(firstClientRows, hasLength(2));
  expect(
    firstClientRows.singleWhere((row) => row.id == originalValueId).name,
    'shared-name',
  );
  expect(
    firstClientRows.singleWhere((row) => row.id == conflictValueId).name,
    'shared-name__conflict__${conflictValueId.uuid}',
  );

  final secondClientRows = await client.Unique.db.find(secondClientSession);
  expect(secondClientRows, hasLength(2));
  expect(
    secondClientRows.singleWhere((row) => row.id == originalValueId).name,
    'shared-name',
  );
  expect(
    secondClientRows.singleWhere((row) => row.id == conflictValueId).name,
    'shared-name__conflict__${conflictValueId.uuid}',
  );

  final serverRows = await server.Unique.db.find(serverSession);
  expect(serverRows, hasLength(2));
  expect(
    serverRows.singleWhere((row) => row.id == originalValueId).name,
    'shared-name',
  );
  expect(
    serverRows.singleWhere((row) => row.id == conflictValueId).name,
    'shared-name__conflict__${conflictValueId.uuid}',
  );
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
