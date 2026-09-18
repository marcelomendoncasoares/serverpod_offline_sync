import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';

/// One reported merge, with the state the callback could read while it ran.
typedef _Reported = ({OfflineSyncMergeEvent event, List<String> names});

/// Drives the real module endpoint against a real client replica and asserts on
/// the [OfflineSyncMergeEvent]s the server-wide handler registered with
/// `pod.configureOfflineSync` receives.
///
/// The second [withServerpod] group owns its own [Serverpod] instance, which is
/// what makes the registration isolation observable: both pods are configured
/// while the file is registered, so a process-wide registration would have the
/// first pod's handler report the second pod's syncs.
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

  final firstPodReports = <_Reported>[];
  final secondPodReports = <_Reported>[];

  late client.Client testClient;
  late OfflineSyncDatabaseSession clientSession;
  late OfflineSyncDatabaseSession serverSession;

  withServerpod(
    '[CRDT merge events]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      final pod = rawServerSession.serverpod
        ..initializeOfflineSync(syncTables: serverSyncTables)
        ..configureOfflineSync(
          onMergeSuccess: (session, event) async {
            final people = await server.Person.db.find(session);
            firstPodReports.add((
              event: event,
              names: [for (final person in people) person.name],
            ));
          },
        )
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          token.split(' ').last,
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        firstPodReports.clear();

        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider(testCrdtUserId.toString());

        clientSession = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        serverSession = OfflineSyncDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group('Given a person pending on the client only,', () {
        setUp(() async {
          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: const Uuid().v7obj(), name: 'client-person'),
          );
        });

        test(
          'when the client synchronizes once, '
          'then one event reports the syncing user, the personal space and the '
          "client replica's node.",
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports, hasLength(1));
            final event = firstPodReports.single.event;
            expect(event.syncingUserId, testCrdtUserId);
            expect(event.spaceUuid, testCrdtUserId);
            expect(event.peerNodeId, await clientSession.db.currentNodeId());
          },
        );

        test(
          'when the client synchronizes once, '
          'then the event is inbound only and its synced HLC covers what was '
          'received.',
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            final event = firstPodReports.single.event;
            expect(event.receivedHlc, isNotNull);
            expect(event.sentHlc, isNull);
            expect(event.syncedHlc >= event.receivedHlc!, isTrue);
          },
        );

        test(
          'when the client synchronizes once, '
          'then the merged row is already readable from the reported session.',
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports.single.names, contains('client-person'));
          },
        );
      });

      group('Given a person pending on the server only,', () {
        setUp(() async {
          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: const Uuid().v7obj(), name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when the client synchronizes once, '
          'then the event is outbound only.',
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports, hasLength(1));
            final event = firstPodReports.single.event;
            expect(event.sentHlc, isNotNull);
            expect(event.receivedHlc, isNull);
            expect(event.spaceUuid, testCrdtUserId);
          },
        );
      });

      group('Given a person pending on each side of the same space,', () {
        setUp(() async {
          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: const Uuid().v7obj(), name: 'client-person'),
          );
          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: const Uuid().v7obj(), name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when the client synchronizes once, '
          'then one event carries both directional HLCs.',
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports, hasLength(1));
            final event = firstPodReports.single.event;
            expect(event.receivedHlc, isNotNull);
            expect(event.sentHlc, isNotNull);
          },
        );
      });

      group('Given nothing pending on either side,', () {
        test(
          'when the client synchronizes once, '
          'then no event is reported.',
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports, isEmpty);
          },
        );
      });

      group(
        'Given a stale client with a personal write and a write for a space the '
        'server grants as readOnly,',
        () {
          late UuidValue sharedSpaceId;
          late Object? sessionError;

          setUp(() async {
            sharedSpaceId = await rawServerSession.offlineSync.spaces.create(
              grants: {testCrdtUserId: OfflineSyncSpaceRole.readOnly},
            );
            await _upsertSpaceMembership(
              clientSession,
              userUuid: testCrdtUserId,
              spaceUuid: sharedSpaceId,
            );

            await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'personal-write'),
                transaction: tx,
              ),
            );
            await clientSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'rejected-shared-write'),
                transaction: tx,
              ),
              spaceId: sharedSpaceId,
            );

            final clientSync = OfflineSyncEngine(
              syncTables: clientSyncTables,
              serializationManager: clientSession.db.serializationManager,
            );
            final changes = await clientSync
                .collectPendingChanges(
                  clientSession,
                  checkpointsBySpaceUuid: {
                    testCrdtUserId: const [],
                    sharedSpaceId: const [],
                  },
                )
                .toList();
            firstPodReports.clear();

            sessionError = await _syncOncePaired(
              serverSync: rawServerSession.offlineSync,
              clientSync: clientSync,
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              splicedChanges: [
                ...changes.where((change) => change.uuidSpaceId == testCrdtUserId),
                ...changes.where((change) => change.uuidSpaceId == sharedSpaceId),
              ],
            );
          });

          test(
            'when the rejected chunk aborts the session, '
            'then the committed space is still reported.',
            () {
              expect(sessionError, isA<OfflineSyncIntegrityViolationException>());
              expect(
                firstPodReports.map((report) => report.event.spaceUuid),
                [testCrdtUserId],
              );
            },
          );

          test(
            'when the rejected chunk aborts the session, '
            'then the rolled back space produces no received notification.',
            () {
              expect(
                firstPodReports.where(
                  (report) => report.event.spaceUuid == sharedSpaceId,
                ),
                isEmpty,
              );
            },
          );
        },
      );

      group('Given a per-sync observer alongside the server-wide handler,', () {
        late List<OfflineSyncMergeEvent> observed;

        setUp(() async {
          observed = [];
          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: const Uuid().v7obj(), name: 'client-person'),
          );
        });

        test(
          'when both observers succeed, '
          'then both receive the same event.',
          () async {
            final error = await _syncOncePaired(
              serverSync: rawServerSession.offlineSync,
              clientSync: OfflineSyncEngine(
                syncTables: clientSyncTables,
                serializationManager: clientSession.db.serializationManager,
              ),
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              onMergeSuccess: observed.add,
            );

            expect(error, isNull);
            expect(firstPodReports, hasLength(1));
            expect(observed, hasLength(1));
            expect(observed.single.syncedHlc, firstPodReports.single.event.syncedHlc);
            expect(observed.single.spaceUuid, firstPodReports.single.event.spaceUuid);
          },
        );

        test(
          'when the per-sync observer throws, '
          'then the server-wide handler still runs and the session succeeds.',
          () async {
            final error = await _syncOncePaired(
              serverSync: rawServerSession.offlineSync,
              clientSync: OfflineSyncEngine(
                syncTables: clientSyncTables,
                serializationManager: clientSession.db.serializationManager,
              ),
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              onMergeSuccess: (event) {
                observed.add(event);
                throw StateError('observer failure');
              },
            );

            expect(error, isNull);
            expect(observed, hasLength(1));
            expect(firstPodReports, hasLength(1));
          },
        );

        test(
          'when the server-wide handler throws, '
          'then the per-sync observer still runs and the session succeeds.',
          () async {
            pod.configureOfflineSync(
              onMergeSuccess: (session, event) => throw StateError('handler failure'),
            );
            addTearDown(
              () => pod.configureOfflineSync(
                onMergeSuccess: (session, event) async {
                  final people = await server.Person.db.find(session);
                  firstPodReports.add((
                    event: event,
                    names: [for (final person in people) person.name],
                  ));
                },
              ),
            );

            final error = await _syncOncePaired(
              serverSync: rawServerSession.offlineSync,
              clientSync: OfflineSyncEngine(
                syncTables: clientSyncTables,
                serializationManager: clientSession.db.serializationManager,
              ),
              clientSession: clientSession,
              userUuid: testCrdtUserId,
              onMergeSuccess: observed.add,
            );

            expect(error, isNull);
            expect(observed, hasLength(1));
          },
        );
      });

      group('Given the handler of another Serverpod instance,', () {
        setUp(() async {
          secondPodReports.clear();
          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: const Uuid().v7obj(), name: 'client-person'),
          );
        });

        test(
          'when this pod runs a sync session, '
          "then the other pod's handler is not reported to.",
          () async {
            await testClient.offlineSync.syncOnce(clientSession);

            expect(firstPodReports, hasLength(1));
            expect(secondPodReports, isEmpty);
          },
        );
      });
    },
  );

  withServerpod(
    '[CRDT merge events for two users sharing one readWrite space]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      final secondUserId = const Uuid().v7obj();
      late client.Client firstClient;
      late client.Client secondClient;
      late OfflineSyncDatabaseSession firstClientSession;
      late OfflineSyncDatabaseSession secondClientSession;
      late UuidValue sharedSpaceId;

      rawServerSession.serverpod
        ..initializeOfflineSync(syncTables: serverSyncTables)
        ..configureOfflineSync(
          onMergeSuccess: (session, event) =>
              secondPodReports.add((event: event, names: const [])),
        )
        ..authenticationHandler = (session, token) async => AuthenticationInfo(
          token.split(' ').last,
          <Scope>{},
          authId: const Uuid().v4(),
        );

      setUp(() async {
        final serverUrl = 'http://localhost:${rawServerSession.server.port}';
        firstClient = client.Client(serverUrl)
          ..authKeyProvider = TestClientAuthKeyProvider(testCrdtUserId.toString());
        secondClient = client.Client(serverUrl)
          ..authKeyProvider = TestClientAuthKeyProvider(secondUserId.toString());

        firstClientSession = OfflineSyncDatabaseSession.wraps(
          testSession,
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await firstClientSession.db.initialize();

        secondClientSession = OfflineSyncDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: secondUserId,
        );
        await secondClientSession.db.initialize();

        serverSession = OfflineSyncDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
        );
        await serverSession.db.initialize();

        sharedSpaceId = await rawServerSession.offlineSync.spaces.create(
          grants: {
            testCrdtUserId: OfflineSyncSpaceRole.readWrite,
            secondUserId: OfflineSyncSpaceRole.readWrite,
          },
        );

        await firstClient.offlineSync.syncOnce(firstClientSession);
        await secondClient.offlineSync.syncOnce(secondClientSession);
        secondPodReports.clear();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group('Given each user writes into the shared space,', () {
        setUp(() async {
          await firstClientSession.db.transactionForUser(
            testCrdtUserId,
            (tx) => client.Person.db.insertRow(
              firstClientSession,
              client.Person(name: 'first-user-shared-person'),
              transaction: tx,
            ),
            spaceId: sharedSpaceId,
          );
          await secondClientSession.db.transactionForUser(
            secondUserId,
            (tx) => client.Person.db.insertRow(
              secondClientSession,
              client.Person(name: 'second-user-shared-person'),
              transaction: tx,
            ),
            spaceId: sharedSpaceId,
          );
        });

        test(
          'when both clients synchronize, '
          'then each upload is reported for the shared space under its own '
          'syncing user.',
          () async {
            await firstClient.offlineSync.syncOnce(firstClientSession);
            await secondClient.offlineSync.syncOnce(secondClientSession);

            final inbound = [
              for (final report in secondPodReports)
                if (report.event.receivedHlc != null) report.event,
            ];
            expect(
              inbound.map((event) => event.spaceUuid).toSet(),
              {sharedSpaceId},
            );
            expect(
              inbound.map((event) => event.syncingUserId).toList(),
              [testCrdtUserId, secondUserId],
            );
          },
        );

        test(
          'when both clients synchronize, '
          'then each replica is reported under its own peer node.',
          () async {
            await firstClient.offlineSync.syncOnce(firstClientSession);
            await secondClient.offlineSync.syncOnce(secondClientSession);

            final firstNodeId = await firstClientSession.db.currentNodeId();
            final secondNodeId = await secondClientSession.db.currentNodeId();
            expect(firstNodeId, isNot(secondNodeId));
            expect(
              {
                for (final report in secondPodReports)
                  report.event.syncingUserId: report.event.peerNodeId,
              },
              {testCrdtUserId: firstNodeId, secondUserId: secondNodeId},
            );
          },
        );
      });

      group('Given the first user writes into a personal and the shared space,', () {
        setUp(() async {
          await client.Person.db.insertRow(
            firstClientSession,
            client.Person(name: 'first-user-personal-person'),
          );
          await firstClientSession.db.transactionForUser(
            testCrdtUserId,
            (tx) => client.Person.db.insertRow(
              firstClientSession,
              client.Person(name: 'first-user-shared-person'),
              transaction: tx,
            ),
            spaceId: sharedSpaceId,
          );
        });

        test(
          'when the first client synchronizes, '
          'then one event is reported per affected space.',
          () async {
            await firstClient.offlineSync.syncOnce(firstClientSession);

            expect(
              secondPodReports.map((report) => report.event.spaceUuid).toSet(),
              {testCrdtUserId, sharedSpaceId},
            );
          },
        );
      });
    },
  );
}

/// Runs a real follower and a real authoritative `once` sync pair over
/// in-memory streams, so the server session can be given a per-sync
/// [onMergeSuccess] observer the generated module endpoint does not expose.
///
/// [splicedChanges] are added as an extra [OfflineSyncMergeChunk] right before
/// the follower's first [OfflineSyncEndOfBatch], as a stale or malicious client
/// would, so the chunk lands inside a well-formed batch.
///
/// Returns the error that ended the authoritative session, or null when it
/// closed cleanly.
Future<Object?> _syncOncePaired({
  required OfflineSyncSession serverSync,
  required OfflineSyncEngine clientSync,
  required DatabaseSession clientSession,
  required UuidValue userUuid,
  List<CrdtMergeChange> splicedChanges = const [],
  OfflineSyncOnMergeSuccess? onMergeSuccess,
}) async {
  final clientToServer = StreamController<OfflineSyncStreamEvent>();
  final serverToClient = StreamController<OfflineSyncStreamEvent>();
  final serverCompletion = Completer<Object?>();
  final clientCompletion = Completer<void>();
  var spliced = splicedChanges.isEmpty;

  void addIfOpen(
    StreamController<OfflineSyncStreamEvent> controller,
    OfflineSyncStreamEvent event,
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
        mode: OfflineSyncPeerMode.follower,
      )
      .listen(
        (event) {
          if (!spliced && event is OfflineSyncEndOfBatch) {
            spliced = true;
            addIfOpen(clientToServer, OfflineSyncMergeChunk(changes: splicedChanges));
          }
          addIfOpen(clientToServer, event);
        },
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
        mode: OfflineSyncPeerMode.authoritative,
        onMergeSuccess: onMergeSuccess,
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

/// Upserts a projected `offline_sync_space_members` row for stale client state.
Future<void> _upsertSpaceMembership(
  DatabaseSession session, {
  required UuidValue userUuid,
  required UuidValue spaceUuid,
}) async {
  final space = await OfflineSyncSpaceManager(session).getOrCreate(spaceUuid);
  await OfflineSyncSpaceMember.db.upsertRow(
    session,
    OfflineSyncSpaceMember(
      spaceId: space.id!,
      userUuid: userUuid,
      role: OfflineSyncSpaceRole.readWrite,
    ),
    conflictColumns: (t) => [t.spaceId, t.userUuid],
    updateColumns: (t) => [t.role],
  );
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  TestClientAuthKeyProvider([this.userKey = 'token']);

  final String userKey;

  @override
  Future<String?> get authHeaderValue async => 'Bearer $userKey';
}
