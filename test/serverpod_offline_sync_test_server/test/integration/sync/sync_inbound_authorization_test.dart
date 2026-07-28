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

/// Proves the authoritative server rejects inbound merge writes for scopes the
/// user cannot write to, independently of the client-side prevention that
/// normally keeps such writes off the wire (`sync_flow_test.dart` covers that
/// side). A real follower session completes the whole protocol handshake; the
/// tests only splice one adversarial [CrdtSyncMergeChunk] into the
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

  late CrdtDatabaseSession serverSession;
  late CrdtDatabaseSession clientSession;
  late CrdtSync clientSync;

  withServerpod(
    '[CRDT Sync Inbound Authorization]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();

      rawServerSession.serverpod.initializeCrdtSync(syncTables: serverSyncTables);

      setUp(() async {
        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();
        clientSync = CrdtSync(
          syncTables: clientSyncTables,
          serializationManager: clientSession.db.serializationManager,
        );

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
        'Given a stale client session with a readWrite projection for a scope the server never granted, with a pending write, '
        'when the crafted batch is spliced into a real sync session,',
        () {
          late UuidValue ungrantedScopeId;
          late UuidValue scopedPersonId;
          late Object? sessionError;

          setUp(() async {
            ungrantedScopeId = const Uuid().v7obj();
            await _upsertScopeMembership(
              clientSession,
              userUuid: testCrdtUserId,
              scopeUuid: ungrantedScopeId,
              role: CrdtScopeRole.readWrite,
            );

            final scopedPerson = await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'never-granted-write'),
                transaction: tx,
              ),
              scopeId: ungrantedScopeId,
            );
            scopedPersonId = scopedPerson.id!;

            final changes = await clientSync
                .collectPendingChanges(
                  clientSession,
                  checkpointsByScopeUuid: {ungrantedScopeId: const []},
                )
                .toList();
            expect(changes, isNotEmpty);

            sessionError = await _syncOnceWithSplicedMergeChunk(
              serverSync: rawServerSession.crdt,
              clientSync: clientSync,
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              splicedChanges: changes,
            );
          });

          test('then the session completes without an error.', () {
            expect(sessionError, isNull);
          });

          test(
            'then the non-member write is skipped without recording a violation.',
            () async {
              expect(
                await server.Person.db.findById(serverSession, scopedPersonId),
                isNull,
              );
              expect(
                await CrdtSyncIntegrityViolation.db.find(
                  rawServerSession,
                  where: (t) => t.uuidRowId.equals(scopedPersonId),
                ),
                isEmpty,
              );
            },
          );
        },
      );

      group(
        'Given a stale client session with a readWrite projection for a shared scope the server grants as readOnly, with pending personal and shared writes, '
        'when the combined batch is spliced into a real sync session,',
        () {
          late UuidValue sharedScopeId;
          late UuidValue personalPersonId;
          late UuidValue sharedPersonId;
          late Object? sessionError;

          setUp(() async {
            sharedScopeId = await rawServerSession.crdt.scopes.create(
              grants: {testCrdtUserId: CrdtScopeRole.readOnly},
            );
            await _upsertScopeMembership(
              clientSession,
              userUuid: testCrdtUserId,
              scopeUuid: sharedScopeId,
              role: CrdtScopeRole.readWrite,
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
              scopeId: sharedScopeId,
            );
            sharedPersonId = sharedPerson.id!;

            final changes = await clientSync
                .collectPendingChanges(
                  clientSession,
                  checkpointsByScopeUuid: {
                    testCrdtUserId: const [],
                    sharedScopeId: const [],
                  },
                )
                .toList();
            // Personal changes first, so the server merges the authorized
            // scope group before it reaches the unauthorized one.
            final orderedChanges = [
              ...changes.where((change) => change.uuidScopeId == testCrdtUserId),
              ...changes.where((change) => change.uuidScopeId == sharedScopeId),
            ];
            expect(orderedChanges, hasLength(changes.length));
            expect(
              orderedChanges.map((change) => change.uuidScopeId).toSet(),
              hasLength(2),
            );

            sessionError = await _syncOnceWithSplicedMergeChunk(
              serverSync: rawServerSession.crdt,
              clientSync: clientSync,
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              splicedChanges: orderedChanges,
            );
          });

          test('then the sync session fails with an integrity violation.', () {
            expect(sessionError, isA<CrdtSyncIntegrityViolationException>());
          });

          test('then the authorized personal-scope write is merged.', () async {
            final serverPerson = await server.Person.db.findById(
              serverSession,
              personalPersonId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.name, 'stale-personal-write');
          });

          test(
            'then the unauthorized shared-scope write is not applied and records an unauthorizedWrite violation.',
            () async {
              expect(
                await server.Person.db.findById(serverSession, sharedPersonId),
                isNull,
              );

              final violation = await CrdtSyncIntegrityViolation.db.findFirstRow(
                rawServerSession,
                where: (t) =>
                    t.type.equals(CrdtSyncViolationType.unauthorizedWrite) &
                    t.uuidRowId.equals(sharedPersonId),
              );
              expect(violation, isNotNull);
              expect(violation!.operation, CrdtSyncViolationOperation.mergeInsert);
              expect(violation.incomingScopeUuid, sharedScopeId);
            },
          );
        },
      );
    },
  );
}

/// Runs a real follower and a real authoritative `once` sync pair over
/// in-memory streams, splicing [splicedChanges] into the client-to-server
/// stream as an extra [CrdtSyncMergeChunk] right before the follower's first
/// [CrdtSyncEndOfBatch], so the chunk lands inside a well-formed batch.
///
/// Both peers run the production [CrdtSync.sync] state machine end to end;
/// the spliced chunk is the only frame the production client would not send.
///
/// Returns the error that ended the authoritative session, or null when it
/// closed cleanly.
Future<Object?> _syncOnceWithSplicedMergeChunk({
  required CrdtSession serverSync,
  required CrdtSync clientSync,
  required DatabaseSession clientSession,
  required UuidValue userUuid,
  required List<CrdtMergeChange> splicedChanges,
}) async {
  final clientToServer = StreamController<CrdtSyncStreamEvent>();
  final serverToClient = StreamController<CrdtSyncStreamEvent>();
  final serverCompletion = Completer<Object?>();
  final clientCompletion = Completer<void>();
  var spliced = false;

  void addIfOpen(
    StreamController<CrdtSyncStreamEvent> controller,
    CrdtSyncStreamEvent event,
  ) {
    if (!controller.isClosed) {
      controller.add(event);
    }
  }

  final clientSubscription = clientSync
      .sync(
        clientSession,
        userId: userUuid,
        inbound: serverToClient.stream,
        once: true,
        mode: CrdtSyncPeerMode.follower,
      )
      .listen(
        (event) {
          if (!spliced && event is CrdtSyncEndOfBatch) {
            spliced = true;
            addIfOpen(clientToServer, CrdtSyncMergeChunk(changes: splicedChanges));
          }
          addIfOpen(clientToServer, event);
        },
        // When the server aborts the session, the follower fails with a
        // truncated stream; the error under test is the authoritative one.
        onError: (Object _) {
          if (!clientCompletion.isCompleted) clientCompletion.complete();
          unawaited(clientToServer.close());
        },
        onDone: () {
          if (!clientCompletion.isCompleted) clientCompletion.complete();
          unawaited(clientToServer.close());
        },
      );

  final serverSubscription = serverSync
      .sync(
        userId: userUuid,
        inbound: clientToServer.stream,
        once: true,
        mode: CrdtSyncPeerMode.authoritative,
      )
      .listen(
        (event) => addIfOpen(serverToClient, event),
        onError: (Object error) {
          if (!serverCompletion.isCompleted) serverCompletion.complete(error);
          unawaited(serverToClient.close());
        },
        onDone: () {
          if (!serverCompletion.isCompleted) serverCompletion.complete(null);
          unawaited(serverToClient.close());
        },
      );

  try {
    const timeout = Duration(seconds: 5);
    final sessionError = await serverCompletion.future.timeout(timeout);
    await clientCompletion.future.timeout(timeout);
    return sessionError;
  } finally {
    await clientSubscription.cancel();
    await serverSubscription.cancel();
    if (!clientToServer.isClosed) unawaited(clientToServer.close());
    if (!serverToClient.isClosed) unawaited(serverToClient.close());
  }
}

/// Upserts a projected `crdt_scope_members` row for stale or adversarial client
/// state.
Future<void> _upsertScopeMembership(
  DatabaseSession session, {
  required UuidValue userUuid,
  required UuidValue scopeUuid,
  CrdtScopeRole role = CrdtScopeRole.readWrite,
}) async {
  final scope = await CrdtScopeManager(session).getOrCreate(scopeUuid);
  await CrdtScopeMember.db.upsertRow(
    session,
    CrdtScopeMember(
      scopeId: scope.id!,
      userUuid: userUuid,
      role: role,
    ),
    conflictColumns: (t) => [t.scopeId, t.userUuid],
    updateColumns: (t) => [t.role],
  );
}
