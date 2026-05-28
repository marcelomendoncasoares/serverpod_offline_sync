// Uses serverpod_database and serverpod_test types already available transitively from the test setup.
// ignore_for_file: depend_on_referenced_packages

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
        );
        await serverSession.db.initialize();
      });

      tearDown(() async {
        await serverSession.clearUserTables();
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

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
