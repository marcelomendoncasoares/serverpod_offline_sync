import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/endpoints/demo_debug_endpoint.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:serverpod_offline_sync_test_shared/demo_reset.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/serverpod_test_tools.dart';
import '../test_tools/sync_streams.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  withServerpod(
    '[Demo replica reset]',
    rollbackDatabase: RollbackDatabase.disabled,
    databaseInterceptor: offlineSyncDatabaseInterceptor,
    configOverride: (config) => config.copyWith(
      apiServer: ServerConfig(
        port: 0,
        publicHost: 'localhost',
        publicPort: 0,
        publicScheme: 'http',
      ),
    ),
    (sessions, _) {
      late Session serverSession;

      setUpAll(() async {
        final pod = sessions.build().serverpod
          ..initializeOfflineSync(syncTables: server.syncTables);
        serverSession = await pod.createSession(enableLogging: false);
        addTearDown(serverSession.close);
        await serverSession.offlineSyncDb.initialize();
      });

      group(
        'Given a synchronized demo replica with personal data and retained shared-space history,',
        () {
          late UuidValue user;
          late UuidValue sharedSpace;
          late OfflineSyncDatabaseSession replica;
          late UuidValue oldEpoch;
          late Map<String, Map<int, Hlc>> retainedFacts;
          late List<String> expectedRows;
          late int acknowledgedRevision;

          setUpAll(() async {
            user = const Uuid().v7obj();
            sharedSpace = await serverSession.offlineSync.spaces.createFor(user);
            replica = await _replica(user);
            await client.Person.db.insertRow(
              replica,
              client.Person(name: 'originally authored by the reset replica'),
            );
            await serverSession.offlineSyncDb.transactionForUser(user, (tx) async {
              await server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'originally authored by the server'),
                transaction: tx,
              );
            });
            await _sync(serverSession, replica, user);
            await replica.db.transactionForUser(user, spaceId: sharedSpace, (tx) async {
              final retained = await client.Person.db.insertRow(
                replica,
                client.Person(name: 'retained insertion'),
                transaction: tx,
              );
              await client.Person.db.updateRow(
                replica,
                retained.copyWith(name: 'retained field update'),
                columns: (t) => [t.name],
                transaction: tx,
              );
              final deleted = await client.Person.db.insertRow(
                replica,
                client.Person(name: 'retained tombstone'),
                transaction: tx,
              );
              await client.Person.db.deleteRow(replica, deleted, transaction: tx);
            });
            await _sync(serverSession, replica, user);
            oldEpoch = await replica.db.currentNodeId();
            retainedFacts = await _facts(replica, sharedSpace);
            expectedRows = _values(await client.Person.db.find(replica));
            final receipt = await OfflineSyncPeerCheckpoint.db.findFirstRow(
              serverSession,
              where: (t) =>
                  t.space.uuidSpaceId.equals(user) & t.peer.peerUuid.equals(oldEpoch),
            );
            acknowledgedRevision = receipt!.revision;
          });

          group(
            'when the replica resets and reconnects with another shared-space write,',
            () {
              late UuidValue newEpoch;
              late CrdtNode retiredNode;
              late Map<String, Map<int, Hlc>> factsAfterReset;
              late UuidValue nextAuthor;
              late int personalRowsAfterReset;
              late List<String> actualRows;
              late List<String> serverRows;
              Object? syncError;

              setUpAll(() async {
                await resetDemoSpace(replica, user);
                newEpoch = await replica.db.currentNodeId();
                retiredNode = (await CrdtNode.db.findFirstRow(
                  replica,
                  where: (t) => t.uuidNodeId.equals(oldEpoch),
                ))!;
                personalRowsAfterReset = await client.Person.db.count(
                  replica,
                  where: (t) => t.spaceEquals(user),
                );
                factsAfterReset = await _facts(replica, sharedSpace);
                final next = await replica.db.transactionForUser(
                  user,
                  spaceId: sharedSpace,
                  (tx) => client.Person.db.insertRow(
                    replica,
                    client.Person(name: 'authored after reset'),
                    transaction: tx,
                  ),
                );
                nextAuthor = (await CrdtDataRow.db.findFirstRow(
                  replica,
                  where: (t) => t.uuidRowId.equals(next.id),
                  include: CrdtDataRow.include(node: CrdtNode.include()),
                ))!.node!.uuidNodeId;
                expectedRows = [
                  ...expectedRows,
                  ..._values([next]),
                ]..sort();
                try {
                  await _sync(serverSession, replica, user);
                } on Object catch (error) {
                  syncError = error;
                }
                actualRows = _values(await client.Person.db.find(replica));
                serverRows = _values(
                  await server.Person.db.find(
                    serverSession,
                    where: (t) => t.spaceEquals(user) | t.spaceEquals(sharedSpace),
                  ),
                );
              });

              test('then the cleared space uses a fresh epoch for later writes.', () {
                expect(acknowledgedRevision, greaterThan(0));
                expect(personalRowsAfterReset, 0);
                expect(newEpoch, isNot(oldEpoch));
                expect(nextAuthor, newEpoch);
                expect(retiredNode.localUserUuid, isNull);
              });

              test(
                'then retained insertions, field edits and tombstones keep their authors.',
                () {
                  expect(
                    retainedFacts.values.every((facts) => facts.isNotEmpty),
                    isTrue,
                  );
                  expect(
                    retainedFacts.values
                        .expand((facts) => facts.values)
                        .map((hlc) => hlc.nodeId),
                    everyElement(oldEpoch),
                  );
                  expect(factsAfterReset, retainedFacts);
                  expect(retiredNode.uuidNodeId, oldEpoch);
                },
              );

              test('then both replicas reconverge to every exact payload.', () {
                expect(syncError, isNull);
                expect(actualRows, expectedRows);
                expect(serverRows, expectedRows);
              });
            },
          );
        },
      );

      group(
        'Given a demo server and client with acknowledged data in both directions,',
        () {
          late UuidValue user;
          late Session authenticated;
          late OfflineSyncDatabaseSession replica;
          late UuidValue oldEpoch;
          late List<String> expectedRows;

          setUpAll(() async {
            user = const Uuid().v7obj();
            authenticated =
                (await serverSession.serverpod.createSession(enableLogging: false))
                  ..updateAuthenticated(
                    AuthenticationInfo(user.uuid, {}, authId: const Uuid().v7()),
                  );
            addTearDown(authenticated.close);
            replica = await _replica(user);
            await client.Person.db.insertRow(
              replica,
              client.Person(name: 'client fact'),
            );
            await serverSession.offlineSyncDb.transactionForUser(user, (tx) async {
              await server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'server fact'),
                transaction: tx,
              );
            });
            await _sync(serverSession, replica, user);
            oldEpoch = await serverSession.offlineSyncDb.currentNodeId(userId: user);
            expectedRows = _values(await client.Person.db.find(replica));
          });

          group(
            'when the authenticated reset endpoint clears the server space and sync resumes,',
            () {
              late UuidValue newEpoch;
              late int rowsAfterReset;
              late List<String> clientRows;
              late List<String> serverRows;
              Object? syncError;

              setUpAll(() async {
                await DemoDebugEndpoint().resetSpace(authenticated);
                final fresh = authenticated;
                newEpoch = await fresh.offlineSyncDb.currentNodeId(userId: user);
                rowsAfterReset = await server.Person.db.count(
                  fresh,
                  where: (t) => t.spaceEquals(user),
                );
                try {
                  await _sync(fresh, replica, user);
                } on Object catch (error) {
                  syncError = error;
                }
                clientRows = _values(await client.Person.db.find(replica));
                serverRows = _values(
                  await server.Person.db.find(fresh, where: (t) => t.spaceEquals(user)),
                );
              });

              test('then the server clears its rows and retires its prior epoch.', () {
                expect(rowsAfterReset, 0);
                expect(newEpoch, isNot(oldEpoch));
              });

              test(
                'then client and server facts are restored exactly through sync.',
                () {
                  expect(syncError, isNull);
                  expect(clientRows, expectedRows);
                  expect(serverRows, expectedRows);
                },
              );
            },
          );
        },
      );

      group(
        'Given a demo replica whose space deletion fails after epoch retirement,',
        () {
          late UuidValue user;
          late OfflineSyncDatabaseSession replica;
          late UuidValue oldEpoch;
          late int originalNodeCount;
          late List<String> expectedRows;

          setUpAll(() async {
            user = const Uuid().v7obj();
            replica = await _replica(user);
            await client.Person.db.insertRow(
              replica,
              client.Person(name: 'keep on failure'),
            );
            oldEpoch = await replica.db.currentNodeId();
            originalNodeCount = await CrdtNode.db.count(replica);
            expectedRows = _values(await client.Person.db.find(replica));
            await replica.db.unsafeExecute('''
CREATE TRIGGER reject_demo_reset BEFORE DELETE ON offline_sync_spaces
BEGIN
  SELECT RAISE(ABORT, 'reject demo reset');
END;
''');
          });

          group('when reset rolls back and a later write succeeds,', () {
            Object? resetError;
            late UuidValue durableEpoch;
            late UuidValue nextAuthor;
            late int nodeCount;
            late List<String> rowsAfterFailure;

            setUpAll(() async {
              try {
                await resetDemoSpace(replica, user);
              } on Object catch (error) {
                resetError = error;
              }
              await replica.db.unsafeExecute('DROP TRIGGER reject_demo_reset');
              durableEpoch = (await CrdtNode.db.findFirstRow(
                replica,
                where: (t) => t.localUserUuid.equals(user),
              ))!.uuidNodeId;
              nodeCount = await CrdtNode.db.count(replica);
              rowsAfterFailure = _values(await client.Person.db.find(replica));
              final next = await client.Person.db.insertRow(
                replica,
                client.Person(name: 'after failed reset'),
              );
              nextAuthor = (await CrdtDataRow.db.findFirstRow(
                replica,
                where: (t) => t.uuidRowId.equals(next.id),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              ))!.node!.uuidNodeId;
            });

            test('then data and the original local binding survive together.', () {
              expect(resetError.toString(), contains('reject demo reset'));
              expect(rowsAfterFailure, expectedRows);
              expect(durableEpoch, oldEpoch);
              expect(nodeCount, originalNodeCount);
            });

            test('then subsequent writes still use the committed original epoch.', () {
              expect(nextAuthor, oldEpoch);
            });
          });
        },
      );
    },
  );
}

Future<OfflineSyncDatabaseSession> _replica(UuidValue user) async {
  final replica = OfflineSyncDatabaseSession.wraps(
    await createAdditionalTestSession(),
    syncTables: client.syncTables,
    persistentUserId: user,
  );
  await replica.db.initialize();
  return replica;
}

Future<void> _sync(
  Session serverSession,
  OfflineSyncDatabaseSession replica,
  UuidValue user,
) async {
  final round = await syncOnceOverStreams(
    serverSync: serverSession.offlineSync,
    follower: (inbound) => replica.db.sync(
      inbound: inbound,
      once: true,
      mode: OfflineSyncPeerMode.follower,
    ),
    userUuid: user,
  );
  if (round.serverError case final error?) {
    Error.throwWithStackTrace(error, StackTrace.current);
  }
}

List<String> _values(Iterable<TableRow> rows) => [
  for (final row in rows)
    jsonEncode(Map<String, dynamic>.from(row.toJson() as Map)..remove('spaceId')),
]..sort();

Future<Map<String, Map<int, Hlc>>> _facts(
  DatabaseSession session,
  UuidValue space,
) async => {
  'insertions': {
    for (final row in await CrdtDataRow.db.find(
      session,
      where: (t) => t.space.uuidSpaceId.equals(space),
      include: CrdtDataRow.include(node: CrdtNode.include()),
    ))
      row.id!: row.hlc,
  },
  'fields': {
    for (final field in await CrdtDataField.db.find(
      session,
      where: (t) => t.row.space.uuidSpaceId.equals(space),
      include: CrdtDataField.include(node: CrdtNode.include()),
    ))
      field.id!: field.hlc,
  },
  'tombstones': {
    for (final deleted in await CrdtDataDeleted.db.find(
      session,
      where: (t) => t.row.space.uuidSpaceId.equals(space),
      include: CrdtDataDeleted.include(node: CrdtNode.include()),
    ))
      deleted.id!: deleted.hlc,
  },
};
