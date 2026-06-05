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
            olderRow = await _insertUniqueRow(firstClientSession, 'shared-name');
            await _allowNextHlc();
            newerRow = await _insertUniqueRow(secondClientSession, 'shared-name');

            await syncHttpClient.crdt.syncOnce(firstClientSession);
          });

          test(
            'when the incoming row synchronizes, '
            'then both rows remain visible and the older row keeps the unique value.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                secondClientSession,
                firstClientSession,
              );
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
            olderRow = await _insertUniqueRow(secondClientSession, 'shared-name');
            await _allowNextHlc();
            newerRow = await _insertUniqueRow(firstClientSession, 'shared-name');

            await syncHttpClient.crdt.syncOnce(firstClientSession);
          });

          test(
            'when the incoming row synchronizes, '
            'then both rows remain visible and the older row keeps the unique value.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                secondClientSession,
                firstClientSession,
              );
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
            olderUpdatedRow = await _insertUniqueRow(firstClientSession, 'first-name');
            newerUpdatedRow = await _insertUniqueRow(firstClientSession, 'second-name');
            await _syncRowsToAllNodes(
              syncHttpClient,
              firstClientSession,
              secondClientSession,
            );

            await client.Unique.db.updateRow(
              firstClientSession,
              olderUpdatedRow.copyWith(name: 'shared-name'),
            );
            await _allowNextHlc();
            await client.Unique.db.updateRow(
              secondClientSession,
              newerUpdatedRow.copyWith(name: 'shared-name'),
            );

            await syncHttpClient.crdt.syncOnce(secondClientSession);
          });

          test(
            'when the incoming update synchronizes, '
            'then both rows remain visible and the row with the older unique update keeps the unique value.',
            () async {
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                firstClientSession,
                secondClientSession,
              );
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
            updatedRow = await _insertUniqueRow(firstClientSession, 'first-name');
            await _allowNextHlc();
            insertedRow = await _insertUniqueRow(secondClientSession, 'shared-name');
            await _allowNextHlc();
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
              await _syncIncomingConflictToAllNodes(
                syncHttpClient,
                secondClientSession,
                firstClientSession,
              );
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

Future<client.Unique> _insertUniqueRow(
  CrdtDatabaseSession session,
  String name,
) {
  return client.Unique.db.insertRow(
    session,
    client.Unique(id: const Uuid().v7obj(), name: name),
  );
}

Future<void> _allowNextHlc() {
  return Future<void>.delayed(const Duration(milliseconds: 2));
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

Future<void> _expectVisibleUniqueRowsOnAllNodes({
  required CrdtDatabaseSession firstClientSession,
  required CrdtDatabaseSession secondClientSession,
  required CrdtDatabaseSession serverSession,
  required UuidValue originalValueId,
  required UuidValue conflictValueId,
}) async {
  await _expectVisibleClientUniqueRows(
    firstClientSession,
    originalValueId: originalValueId,
    conflictValueId: conflictValueId,
  );
  await _expectVisibleClientUniqueRows(
    secondClientSession,
    originalValueId: originalValueId,
    conflictValueId: conflictValueId,
  );
  await _expectVisibleServerUniqueRows(
    serverSession,
    originalValueId: originalValueId,
    conflictValueId: conflictValueId,
  );
}

Future<void> _expectVisibleClientUniqueRows(
  CrdtDatabaseSession session, {
  required UuidValue originalValueId,
  required UuidValue conflictValueId,
}) async {
  final rows = await client.Unique.db.find(session);

  expect(rows, hasLength(2));
  final originalValueRow = rows.singleWhere((row) => row.id == originalValueId);
  final conflictValueRow = rows.singleWhere((row) => row.id == conflictValueId);
  expect(originalValueRow.name, 'shared-name');
  expect(conflictValueRow.name, _conflictName(conflictValueId));
}

Future<void> _expectVisibleServerUniqueRows(
  CrdtDatabaseSession session, {
  required UuidValue originalValueId,
  required UuidValue conflictValueId,
}) async {
  final rows = await server.Unique.db.find(session);

  expect(rows, hasLength(2));
  final originalValueRow = rows.singleWhere((row) => row.id == originalValueId);
  final conflictValueRow = rows.singleWhere((row) => row.id == conflictValueId);
  expect(originalValueRow.name, 'shared-name');
  expect(conflictValueRow.name, _conflictName(conflictValueId));
}

String _conflictName(UuidValue rowId) {
  return 'shared-name__conflict__${rowId.uuid}';
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
