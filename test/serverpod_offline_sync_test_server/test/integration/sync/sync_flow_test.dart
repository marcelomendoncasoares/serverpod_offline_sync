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
  late UuidValue serverNodeId;

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
          'http://localhost:${Serverpod.instance.server.port}',
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

        serverNodeId = await serverSession.db.currentNodeId(userId: testCrdtUserId);
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
            await testClient.crdt.syncOnce(
              clientSession,
              otherNodeId: serverNodeId,
            );

            final serverPerson = await server.Person.db.findById(
              serverSession,
              personId,
            );

            expect(serverPerson, isNotNull);
            expect(serverPerson!.id, personId);
            expect(serverPerson.name, 'client-person');
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
          'when client syncOnce is called '
          'then the client merges the server pending changes.',
          () async {
            await testClient.crdt.syncOnce(
              clientSession,
              otherNodeId: serverNodeId,
            );

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
            await testClient.crdt.syncOnce(
              clientSession,
              otherNodeId: serverNodeId,
            );

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
    },
  );
}

class TestClientAuthKeyProvider implements ClientAuthKeyProvider {
  @override
  Future<String?> get authHeaderValue async => 'Bearer token';
}
