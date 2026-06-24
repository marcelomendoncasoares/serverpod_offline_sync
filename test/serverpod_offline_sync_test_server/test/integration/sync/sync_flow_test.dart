// Uses serverpod_database and serverpod_test types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';

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

  late client.Client testClient;
  late CrdtDatabaseSession serverSession;
  late CrdtDatabaseSession clientSession;

  withServerpod(
    'Given a server and client CRDT session that are initialized with the same sync tables',
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
          scopeMembershipValidator: _scopeMembershipValidator,
          scopeMembershipResolver: CrdtScopeMembership.memberScopes,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      group('and no local or remote pending changes exist', () {
        test(
          'when client syncOnce is called '
          'then the sync completes.',
          () async {
            await expectLater(
              testClient.crdt
                  .syncOnce(clientSession)
                  .timeout(const Duration(seconds: 3)),
              completes,
            );
          },
        );

        test(
          'when client syncOnce is called repeatedly on a reused client '
          'then the rounds complete promptly instead of stalling on teardown.',
          () async {
            // The first round opens the shared websocket connection; later
            // rounds reuse it. If a finished round leaves its inbound transport
            // stream paused, closing that stream stalls for the transport close
            // timeout (~6s), and the stall lands on the next round's critical
            // path. Empty rounds should each take milliseconds, so several of
            // them together must stay well under a single close-timeout budget,
            // independent of how much data was synced.
            const rounds = 6;
            final stopwatch = Stopwatch()..start();
            for (var round = 0; round < rounds; round++) {
              await testClient.crdt.syncOnce(clientSession);
            }
            stopwatch.stop();

            expect(
              stopwatch.elapsed,
              lessThan(const Duration(seconds: 10)),
              reason:
                  '$rounds empty reused syncOnce rounds took '
                  '${stopwatch.elapsed}; a leaked paused inbound stream stalls '
                  'each reused round on the ~6s transport close timeout.',
            );
          },
          timeout: const Timeout(Duration(seconds: 90)),
        );

        test(
          'when client syncContinuously is called '
          'then neither side reports a successful merge.',
          () async {
            var mergeSuccessCount = 0;
            final syncSession = testClient.crdt.syncContinuously(
              clientSession,
              onMergeSuccess: (_, _) => mergeSuccessCount++,
            );
            addTearDown(syncSession.cancel);

            await Future<void>.delayed(const Duration(seconds: 2));

            expect(mergeSuccessCount, 0);
          },
        );

        test(
          'when client syncContinuously runs '
          'then neither side sends merge chunks while idle.',
          () async {
            final clientToServer = StreamController<CrdtSyncStreamEvent>();
            final serverToClient = StreamController<CrdtSyncStreamEvent>();
            final clientOutboundEvents = <CrdtSyncStreamEvent>[];
            final serverOutboundEvents = <CrdtSyncStreamEvent>[];

            void addIfOpen(
              StreamController<CrdtSyncStreamEvent> controller,
              CrdtSyncStreamEvent event,
            ) {
              if (!controller.isClosed) {
                controller.add(event);
              }
            }

            final clientSync = CrdtSync(
              syncTables: clientSyncTables,
              serializationManager: clientSession.db.serializationManager,
            );

            final clientSubscription = clientSync
                .sync(
                  clientSession,
                  userId: testCrdtUserId,
                  inbound: serverToClient.stream,
                  once: false,
                )
                .listen((event) {
                  clientOutboundEvents.add(event);
                  addIfOpen(clientToServer, event);
                });

            final serverSubscription = rawServerSession.crdt
                .sync(
                  serverSession,
                  userId: testCrdtUserId,
                  inbound: clientToServer.stream,
                  once: false,
                )
                .listen((event) {
                  serverOutboundEvents.add(event);
                  addIfOpen(serverToClient, event);
                });

            addTearDown(() async {
              await clientToServer.close();
              await serverToClient.close();
              await clientSubscription.cancel();
              await serverSubscription.cancel();
            });

            await Future<void>.delayed(const Duration(seconds: 2));

            await clientToServer.close();
            await serverToClient.close();
            await clientSubscription.cancel();
            await serverSubscription.cancel();

            for (final events in [clientOutboundEvents, serverOutboundEvents]) {
              expect(events.whereType<CrdtSyncMergeChunk>(), isEmpty);
              expect(events.whereType<CrdtSyncEndOfBatch>(), isNotEmpty);
              expect(events.whereType<CrdtSyncClose>(), isEmpty);
              expect(events.whereType<CrdtSyncIdleTimeout>(), isEmpty);
            }
          },
        );
      });

      group('and the user is a member of a shared scope', () {
        late UuidValue sharedScopeId;

        setUp(() async {
          sharedScopeId = const Uuid().v7obj();
          await _grantScopeMembership(
            rawServerSession,
            userUuid: testCrdtUserId,
            scopeUuid: sharedScopeId,
          );
        });

        test(
          'when client syncOnce is called '
          'then personal and shared scope rows converge in the same call.',
          () async {
            final personalPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'personal-server-person'),
                transaction: tx,
              ),
            );
            final sharedPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'shared-server-person'),
                transaction: tx,
              ),
              scopeId: sharedScopeId,
            );
            final allServerPeopleForUser = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.find(serverSession, transaction: tx),
            );

            await testClient.crdt.syncOnce(clientSession);

            final personalClientPerson = await client.Person.db.findById(
              clientSession,
              personalPerson.id!,
            );
            final sharedClientPerson = await client.Person.db.findById(
              clientSession,
              sharedPerson.id!,
            );
            final allClientPeople = await client.Person.db.find(clientSession);

            expect(personalClientPerson, isNotNull);
            expect(personalClientPerson!.name, 'personal-server-person');
            expect(sharedClientPerson, isNotNull);
            expect(sharedClientPerson!.name, 'shared-server-person');
            expect(allServerPeopleForUser.map((person) => person.id).toSet(), {
              personalPerson.id,
              sharedPerson.id,
            });
            expect(allClientPeople.map((person) => person.id).toSet(), {
              personalPerson.id,
              sharedPerson.id,
            });
          },
        );

        test(
          'when client syncContinuously is already running and a shared scope is granted '
          'then the client adopts and syncs the scope in the next cycle.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            final laterScopeId = const Uuid().v7obj();
            await _grantScopeMembership(
              rawServerSession,
              userUuid: testCrdtUserId,
              scopeUuid: laterScopeId,
            );

            final sharedPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'later-shared-person'),
                transaction: tx,
              ),
              scopeId: laterScopeId,
            );

            await _waitUntil(() async {
              final clientPerson = await client.Person.db.findById(
                clientSession,
                sharedPerson.id!,
              );
              return clientPerson?.name == 'later-shared-person';
            });
          },
        );
      });

      group('and the user is not a member of a shared scope', () {
        test(
          'when a transaction is started for that scope '
          'then it is rejected before writing.',
          () async {
            final ungrantedScopeId = const Uuid().v7obj();
            await CrdtScopeManager(rawServerSession).getOrCreate(
              ungrantedScopeId,
            );

            await expectLater(
              serverSession.db.transactionForUser(
                testCrdtUserId,
                (tx) => server.Person.db.insertRow(
                  serverSession,
                  server.Person(name: 'ungranted-server-person'),
                  transaction: tx,
                ),
                scopeId: ungrantedScopeId,
              ),
              throwsA(isA<CrdtScopeMembershipException>()),
            );
          },
        );
      });

      group('and the client has a local scope that the server has not granted', () {
        test(
          'when client syncOnce is called '
          'then the ungranted scope is not streamed to the server.',
          () async {
            final ungrantedScopeId = const Uuid().v7obj();
            final personalPerson = await client.Person.db.insertRow(
              clientSession,
              client.Person(name: 'personal-client-person'),
            );
            final ungrantedPerson = await clientSession.db.transactionForUser(
              ungrantedScopeId,
              (tx) => client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'ungranted-client-person'),
                transaction: tx,
              ),
            );

            await testClient.crdt.syncOnce(clientSession);

            final serverPersonalPerson = await server.Person.db.findById(
              serverSession,
              personalPerson.id!,
            );
            final serverUngrantedPerson = await server.Person.db.findById(
              serverSession,
              ungrantedPerson.id!,
            );

            expect(serverPersonalPerson, isNotNull);
            expect(serverPersonalPerson!.name, 'personal-client-person');
            expect(serverUngrantedPerson, isNull);
          },
        );
      });

      group('and an inserted client person', () {
        late UuidValue personId;

        setUp(() async {
          personId = const Uuid().v7obj();

          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: personId, name: 'client-person'),
          );
        });

        test(
          'when client syncOnce is called '
          'then the server merges the client pending changes.',
          () async {
            await testClient.crdt.syncOnce(clientSession);

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.id, personId);
            expect(serverPerson.name, 'client-person');
          },
        );

        test(
          'when client syncContinuously is called '
          'then the server merges the client pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final serverPerson = await server.Person.db.findById(
                serverSession,
                personId,
              );
              return serverPerson != null;
            });

            await syncSession.cancel();

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.id, personId);
            expect(serverPerson.name, 'client-person');
          },
        );

        test(
          'when a running syncContinuously session is cancelled '
          'then done completes without hanging.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);

            await syncSession.cancel();

            await expectLater(syncSession.done, completes);
          },
        );
      });

      group('and an inserted server person', () {
        late UuidValue personId;

        setUp(() async {
          personId = const Uuid().v7obj();

          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: personId, name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when client syncContinuously is called '
          'then the client merges the server pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final clientPerson = await client.Person.db.findById(
                clientSession,
                personId,
              );
              return clientPerson != null;
            });

            await syncSession.cancel();

            final clientPerson = await client.Person.db.findById(
              clientSession,
              personId,
            );

            expect(clientPerson, isNotNull);
            expect(clientPerson!.id, personId);
            expect(clientPerson.name, 'server-person');
          },
        );
      });

      group('and an inserted client and server person', () {
        late UuidValue clientPersonId;
        late UuidValue serverPersonId;

        setUp(() async {
          clientPersonId = const Uuid().v7obj();
          serverPersonId = const Uuid().v7obj();

          await client.Person.db.insertRow(
            clientSession,
            client.Person(id: clientPersonId, name: 'client-person'),
          );

          await serverSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await server.Person.db.insertRow(
              serverSession,
              server.Person(id: serverPersonId, name: 'server-person'),
              transaction: tx,
            );
          });
        });

        test(
          'when client syncOnce is called '
          'then both the client and server have the two persons.',
          () async {
            await testClient.crdt.syncOnce(clientSession);

            final clientPerson = await client.Person.db.find(clientSession);

            expect(clientPerson, hasLength(2));
            expect(clientPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(clientPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });

            final serverPerson = await server.Person.db.find(serverSession);

            expect(serverPerson, hasLength(2));
            expect(serverPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(serverPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });
          },
        );

        test(
          'when client syncContinuously is called '
          'then the client merges the server pending changes.',
          () async {
            final syncSession = testClient.crdt.syncContinuously(clientSession);
            addTearDown(syncSession.cancel);

            await _waitUntil(() async {
              final clientMergedPerson = await client.Person.db.findById(
                clientSession,
                serverPersonId,
              );
              final serverMergedPerson = await server.Person.db.findById(
                serverSession,
                clientPersonId,
              );
              return clientMergedPerson != null && serverMergedPerson != null;
            });
            await syncSession.cancel();

            final clientPerson = await client.Person.db.find(clientSession);

            expect(clientPerson, hasLength(2));
            expect(clientPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(clientPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });

            final serverPerson = await server.Person.db.find(serverSession);

            expect(serverPerson, hasLength(2));
            expect(serverPerson.map((e) => e.id).toSet(), {
              clientPersonId,
              serverPersonId,
            });
            expect(serverPerson.map((e) => e.name).toSet(), {
              'client-person',
              'server-person',
            });
          },
        );
      });

      group('and a running client syncContinuously session', () {
        late CrdtSyncSession syncSession;

        setUp(() async {
          syncSession = testClient.crdt.syncContinuously(clientSession);
        });

        tearDown(() async {
          await syncSession.cancel();
        });

        test(
          'when the session is cancelled '
          'then done completes without hanging.',
          () async {
            await syncSession.cancel();
            await expectLater(syncSession.done, completes);
          },
        );

        test(
          'when no local or remote changes exist '
          'then the idle session can still be cancelled cleanly.',
          () async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await syncSession.cancel();
            await expectLater(syncSession.done, completes);
          },
        );

        test(
          'when a new person is inserted into the client '
          'then the server merges the client pending changes.',
          () async {
            final clientPerson = await client.Person.db.insertRow(
              clientSession,
              client.Person(name: 'client-person'),
            );

            await expectLater(
              _waitUntil(() async {
                final serverPerson = await server.Person.db.findById(
                  serverSession,
                  clientPerson.id!,
                );
                return serverPerson != null && serverPerson.name == 'client-person';
              }),
              completes,
            );
          },
        );

        test(
          'when a new person is inserted into the server for the same user '
          'then the client merges the server pending changes.',
          () async {
            final serverPerson = await serverSession.db.transactionForUser(
              testCrdtUserId,
              (tx) async => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'server-person'),
                transaction: tx,
              ),
            );

            await expectLater(
              _waitUntil(() async {
                final clientPerson = await client.Person.db.findById(
                  clientSession,
                  serverPerson.id!,
                );
                return clientPerson != null && clientPerson.name == 'server-person';
              }),
              completes,
            );
          },
        );

        test(
          'when a new person is inserted into the server for a different user '
          'then the client does not merge the server pending changes.',
          () async {
            final serverPerson = await serverSession.db.transactionForUser(
              const Uuid().v7obj(),
              (tx) async => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'server-person'),
                transaction: tx,
              ),
            );

            await expectLater(
              _waitUntil(() async {
                final clientPerson = await client.Person.db.findById(
                  clientSession,
                  serverPerson.id!,
                );
                return clientPerson != null && clientPerson.name == 'server-person';
              }),
              throwsA(isA<TimeoutException>()),
            );
          },
        );
      });

      group(
        'and a running client syncContinuously session with a merge success callback',
        () {
          late CrdtSyncSession syncSession;
          late Completer<Hlc> mergeSuccessCompleter;

          setUp(() async {
            mergeSuccessCompleter = Completer<Hlc>();

            syncSession = testClient.crdt.syncContinuously(
              clientSession,
              onMergeSuccess: (_, hlc) => mergeSuccessCompleter.complete(hlc),
            );
          });

          tearDown(() async {
            await syncSession.cancel();
          });

          test(
            'when a new person is inserted into the client '
            'then the merge success callback is called.',
            () async {
              await client.Person.db.insertRow(
                clientSession,
                client.Person(name: 'client-person'),
              );

              await expectLater(mergeSuccessCompleter.future, completes);
            },
          );

          test(
            'when a new person is inserted into the server for the same user '
            'then the merge success callback is called.',
            () async {
              await serverSession.db.transactionForUser(
                testCrdtUserId,
                (tx) async => server.Person.db.insertRow(
                  serverSession,
                  server.Person(name: 'server-person'),
                  transaction: tx,
                ),
              );

              await expectLater(mergeSuccessCompleter.future, completes);
            },
          );
        },
      );
    },
  );

  withServerpod(
    'Given a server and two client CRDT sessions for the same user that are initialized with the same sync tables',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      late CrdtDatabaseSession secondClientSession;

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

        secondClientSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: clientSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await secondClientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
          scopeMembershipValidator: _scopeMembershipValidator,
          scopeMembershipResolver: CrdtScopeMembership.memberScopes,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      test(
        'when the first node uploads an offline deletion after the second node synchronized a newer change '
        'then the second node receives the deletion on its next sync.',
        () async {
          final rowToDelete = await client.Unique.db.insertRow(
            clientSession,
            client.Unique(name: 'deleted-by-first-node'),
          );
          await testClient.crdt.syncOnce(clientSession);
          await testClient.crdt.syncOnce(secondClientSession);

          // After both nodes have synchronized, the first node deletes the row.
          await client.Unique.db.deleteRow(clientSession, rowToDelete);

          // The second node inserts a new row and synchronizes it.
          await client.Unique.db.insertRow(
            secondClientSession,
            client.Unique(name: 'inserted-by-second-node'),
          );
          await testClient.crdt.syncOnce(secondClientSession);

          // The first node synchronizes the deletion with the server.
          await testClient.crdt.syncOnce(clientSession);

          // This last sync from the second node will only receive the deletion
          // from the first node if checkpoints are tracked per known node.
          await testClient.crdt.syncOnce(secondClientSession);
          final deletedRow = await client.Unique.db.findById(
            secondClientSession,
            rowToDelete.id!,
          );
          expect(deletedRow, isNull);
        },
      );
    },
  );

  withServerpod(
    'Given a server and client CRDT session that are initialized with the same sync tables and a continuous sync interval',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      const syncInterval = Duration(milliseconds: 400);

      rawServerSession.serverpod
        ..initializeCrdtSync(
          syncTables: serverSyncTables,
          continuousSyncInterval: syncInterval,
        )
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
          continuousSyncInterval: syncInterval,
        );
        await clientSession.db.initialize();
      });

      test(
        'when a client change is inserted after a sync round '
        'then the next merge chunk waits for the configured interval.',
        () async {
          var mergeSuccessCount = 0;
          final firstMergeCompleter = Completer<void>();
          final secondMergeCompleter = Completer<void>();

          final syncSession = testClient.crdt.syncContinuously(
            clientSession,
            onMergeSuccess: (_, _) {
              switch (++mergeSuccessCount) {
                case 1:
                  firstMergeCompleter.complete();
                case 2:
                  secondMergeCompleter.complete();
                default:
                  throw Exception('Unexpected merge success count: $mergeSuccessCount');
              }
            },
          );

          addTearDown(syncSession.cancel);

          await client.Person.db.insertRow(
            clientSession,
            client.Person(
              id: const Uuid().v7obj(),
              name: 'first-person',
            ),
          );

          await expectLater(
            firstMergeCompleter.future.timeout(const Duration(seconds: 3)),
            completes,
          );

          final stopwatch = Stopwatch()..start();
          await client.Person.db.insertRow(
            clientSession,
            client.Person(
              id: const Uuid().v7obj(),
              name: 'second-person',
            ),
          );

          await Future<void>.delayed(syncInterval * 0.8);

          expect(secondMergeCompleter.isCompleted, isFalse);

          await expectLater(
            secondMergeCompleter.future.timeout(const Duration(seconds: 3)),
            completes,
          );

          expect(stopwatch.elapsed, greaterThanOrEqualTo(syncInterval));
        },
      );
    },
  );

  withServerpod(
    'Given a server and client CRDT session that are initialized with different sync tables',
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
        testClient = client.Client(
          'http://localhost:${rawServerSession.server.port}',
        )..authKeyProvider = TestClientAuthKeyProvider();

        clientSession = CrdtDatabaseSession.wraps(
          testSession,
          syncTables: [client.Address.t, client.Person.t],
          persistentUserId: testCrdtUserId,
        );
        await clientSession.db.initialize();

        serverSession = CrdtDatabaseSession.wraps(
          rawServerSession,
          syncTables: serverSyncTables,
          scopeMembershipValidator: _scopeMembershipValidator,
          scopeMembershipResolver: CrdtScopeMembership.memberScopes,
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
      });

      test(
        'when client syncOnce is called '
        'then SyncTablesHashMismatchException is thrown.',
        () async {
          await expectLater(
            testClient.crdt.syncOnce(clientSession),
            throwsA(isA<SyncTablesHashMismatchException>()),
          );
        },
      );

      test(
        'when client syncContinuously is called '
        'then SyncTablesHashMismatchException is thrown.',
        () async {
          final syncSession = testClient.crdt.syncContinuously(clientSession);
          addTearDown(syncSession.cancel);

          await expectLater(
            syncSession.done,
            throwsA(isA<SyncTablesHashMismatchException>()),
          );
        },
      );
    },
  );
}

Future<void> _waitUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Condition was not met within $timeout.');
}

Future<void> _grantScopeMembership(
  Session session, {
  required UuidValue userUuid,
  required UuidValue scopeUuid,
}) async {
  final scope = await CrdtScopeManager(session).getOrCreate(scopeUuid);
  final encodedScopeId = ValueEncoder.instance.convert(scope.id);
  final encodedUserUuid = ValueEncoder.instance.convert(userUuid);
  await session.db.unsafeExecute(
    'INSERT INTO "crdt_scope_members" ("scopeId", "userUuid") '
    'VALUES ($encodedScopeId, $encodedUserUuid) '
    'ON CONFLICT ("scopeId", "userUuid") DO NOTHING',
  );
}

Future<bool> _scopeMembershipValidator(
  DatabaseSession session, {
  required UuidValue userId,
  required UuidValue scopeId,
}) {
  return CrdtScopeMembership.isMember(
    session,
    userUuid: userId,
    scopeUuid: scopeId,
  );
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
