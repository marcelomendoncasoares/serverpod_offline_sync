import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';
import '../test_tools/sync_streams.dart';

/// Proves the authoritative server rejects inbound merge writes for spaces the
/// user cannot write to, independently of the client-side prevention that
/// normally keeps such writes off the wire (`sync_flow_test.dart` covers that
/// side). A real follower session completes the whole protocol handshake; the
/// tests only splice one adversarial [OfflineSyncMergeChunk] into the
/// client-to-server stream, as a stale or malicious client would.
void main() {
  initTestClientSession(withPersistentUser: true);

  final clientSyncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];

  final serverSyncTables = [
    server.Address.t,
    server.Person.t,
    server.Types.t,
    server.Unique.t,
  ];

  late OfflineSyncDatabaseSession serverSession;
  late OfflineSyncDatabaseSession clientSession;
  late OfflineSyncEngine clientSync;

  withServerpod(
    '[CRDT Sync Inbound Authorization]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();

      rawServerSession.serverpod.initializeOfflineSync(syncTables: serverSyncTables);

      setUp(() async {
        clientSession = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();
        clientSync = OfflineSyncEngine(
          syncTables: clientSyncTables,
          serializationManager: clientSession.db.serializationManager,
        );

        serverSession = OfflineSyncDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group(
        'Given a stale client session with a readWrite projection for a space the server never granted, with a pending write, '
        'when the crafted batch is spliced into a real sync session,',
        () {
          late UuidValue ungrantedSpaceId;
          late UuidValue spaceScopedPersonId;
          late Object? sessionError;

          setUp(() async {
            ungrantedSpaceId = const Uuid().v7obj();
            await _upsertSpaceMembership(
              clientSession,
              userUuid: testCrdtUserId,
              spaceUuid: ungrantedSpaceId,
              role: OfflineSyncSpaceRole.readWrite,
            );

            final spaceScopedPerson = await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'never-granted-write'),
                transaction: tx,
              ),
              spaceId: ungrantedSpaceId,
            );
            spaceScopedPersonId = spaceScopedPerson.id!;

            final changes = await clientSync
                .collectPendingChanges(
                  clientSession,
                  checkpointsBySpaceUuid: {ungrantedSpaceId: const []},
                )
                .toList();
            expect(changes, isNotEmpty);

            sessionError = (await syncOnceOverStreams(
              serverSync: rawServerSession.offlineSync,
              follower: (inbound) => clientSync.sync(
                clientSession,
                userId: testCrdtUserId,
                inbound: inbound,
                once: true,
                mode: OfflineSyncPeerMode.follower,
              ),
              userUuid: testCrdtUserId,
              splice: changes,
              timeout: const Duration(seconds: 5),
            )).serverError;
          });

          test('then the session completes without an error.', () {
            expect(sessionError, isNull);
          });

          test(
            'then the non-member write is skipped without recording a violation.',
            () async {
              expect(
                await server.Person.db.findById(serverSession, spaceScopedPersonId),
                isNull,
              );
              expect(
                await OfflineSyncIntegrityViolation.db.find(
                  rawServerSession,
                  where: (t) => t.uuidRowId.equals(spaceScopedPersonId),
                ),
                isEmpty,
              );
            },
          );
        },
      );

      group(
        'Given a stale client session with a readWrite projection for a shared space the server grants as readOnly, with pending personal and shared writes, '
        'when the combined batch is spliced into a real sync session,',
        () {
          late UuidValue sharedSpaceId;
          late UuidValue personalPersonId;
          late UuidValue sharedPersonId;
          late Object? sessionError;

          setUp(() async {
            sharedSpaceId = await rawServerSession.offlineSync.spaces.create(
              grants: {testCrdtUserId: OfflineSyncSpaceRole.readOnly},
            );
            await _upsertSpaceMembership(
              clientSession,
              userUuid: testCrdtUserId,
              spaceUuid: sharedSpaceId,
              role: OfflineSyncSpaceRole.readWrite,
            );

            final personalPerson = await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'stale-personal-write'),
                transaction: tx,
              ),
            );
            personalPersonId = personalPerson.id!;
            final sharedPerson = await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'stale-shared-write'),
                transaction: tx,
              ),
              spaceId: sharedSpaceId,
            );
            sharedPersonId = sharedPerson.id!;

            final changes = await clientSync
                .collectPendingChanges(
                  clientSession,
                  checkpointsBySpaceUuid: {
                    testCrdtUserId: const [],
                    sharedSpaceId: const [],
                  },
                )
                .toList();
            // Personal changes first, so the server merges the authorized
            // space group before it reaches the unauthorized one.
            final orderedChanges = [
              ...changes.where((change) => change.uuidSpaceId == testCrdtUserId),
              ...changes.where((change) => change.uuidSpaceId == sharedSpaceId),
            ];
            expect(orderedChanges, hasLength(changes.length));
            expect(
              orderedChanges.map((change) => change.uuidSpaceId).toSet(),
              hasLength(2),
            );

            sessionError = (await syncOnceOverStreams(
              serverSync: rawServerSession.offlineSync,
              follower: (inbound) => clientSync.sync(
                clientSession,
                userId: testCrdtUserId,
                inbound: inbound,
                once: true,
                mode: OfflineSyncPeerMode.follower,
              ),
              userUuid: testCrdtUserId,
              splice: orderedChanges,
              timeout: const Duration(seconds: 5),
            )).serverError;
          });

          test('then the sync session fails with an integrity violation.', () {
            expect(sessionError, isA<OfflineSyncIntegrityViolationException>());
          });

          test('then the authorized personal-space write is merged.', () async {
            final serverPerson = await server.Person.db.findById(
              serverSession,
              personalPersonId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.name, 'stale-personal-write');
          });

          test(
            'then the unauthorized shared-space write is not applied and records an unauthorizedWrite violation.',
            () async {
              expect(
                await server.Person.db.findById(serverSession, sharedPersonId),
                isNull,
              );

              final violation = await OfflineSyncIntegrityViolation.db.findFirstRow(
                rawServerSession,
                where: (t) =>
                    t.type.equals(OfflineSyncViolationType.unauthorizedWrite) &
                    t.uuidRowId.equals(sharedPersonId),
              );
              expect(violation, isNotNull);
              expect(violation!.operation, OfflineSyncViolationOperation.mergeInsert);
              expect(violation.incomingSpaceUuid, sharedSpaceId);
            },
          );
        },
      );
    },
  );
}

/// Upserts a projected `offline_sync_space_members` row for stale or adversarial client
/// state.
Future<void> _upsertSpaceMembership(
  DatabaseSession session, {
  required UuidValue userUuid,
  required UuidValue spaceUuid,
  OfflineSyncSpaceRole role = OfflineSyncSpaceRole.readWrite,
}) async {
  final space = await OfflineSyncSpaceManager(session).getOrCreate(spaceUuid);
  await OfflineSyncSpaceMember.db.upsertRow(
    session,
    OfflineSyncSpaceMember(
      spaceId: space.id!,
      userUuid: userUuid,
      role: role,
    ),
    conflictColumns: (t) => [t.spaceId, t.userUuid],
    updateColumns: (t) => [t.role],
  );
}
