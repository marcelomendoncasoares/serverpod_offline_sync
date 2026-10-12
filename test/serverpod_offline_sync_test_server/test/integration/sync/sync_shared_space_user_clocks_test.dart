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

/// Round trips through a shared space written by several users' clocks, on
/// the server and on clients.
void main() {
  initTestClientSession(createSessionPerTest: false);

  final clientSyncTables = [client.Address.t, client.Person.t];
  final serverSyncTables = [server.Address.t, server.Person.t];

  withServerpod(
    '[Shared space user clocks]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      final rawServerSession = sessionBuilder.build();
      rawServerSession.serverpod.initializeOfflineSync(syncTables: serverSyncTables);

      group(
        'Given a writer and a read-only member sharing a space with a server user,',
        () {
          late UuidValue writer;
          late UuidValue reader;
          late UuidValue serverUser;
          late UuidValue shared;
          late OfflineSyncDatabaseSession serverSession;
          late OfflineSyncDatabaseSession writerClient;
          late OfflineSyncDatabaseSession readerClient;

          Future<OfflineSyncDatabaseSession> clientFor(UuidValue user) async {
            final session = OfflineSyncDatabaseSession.wraps(
              await createAdditionalTestSession(),
              syncTables: clientSyncTables,
              persistentUserId: user,
            );
            await session.db.initialize();
            return session;
          }

          Future<SyncRound> syncOnce(
            OfflineSyncDatabaseSession clientSession,
            UuidValue user, {
            List<CrdtMergeChange> splice = const [],
          }) => syncOnceOverStreams(
            serverSync: rawServerSession.offlineSync,
            follower: (inbound) => clientSession.db.sync(
              inbound: inbound,
              once: true,
              mode: OfflineSyncPeerMode.follower,
            ),
            userUuid: user,
            splice: splice,
          );

          Future<UuidValue> serverAuthor(UuidValue rowId) async {
            final row = await CrdtDataRow.db.findFirstRow(
              rawServerSession,
              where: (t) => t.uuidRowId.equals(rowId),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            return row!.node!.uuidNodeId;
          }

          Future<UuidValue?> clientAuthor(
            OfflineSyncDatabaseSession clientSession,
            UuidValue rowId,
          ) async {
            final row = await CrdtDataRow.db.findFirstRow(
              clientSession,
              where: (t) => t.uuidRowId.equals(rowId),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            return row?.node?.uuidNodeId;
          }

          Set<UuidValue> rowIds(List<CrdtMergeChange> changes) => {
            for (final change in changes) change.uuidRowId,
          };

          late client.Person writerPerson;
          late server.Person serverUserPerson;
          late server.Person serverWriterPerson;

          setUpAll(() async {
            writer = const Uuid().v7obj();
            reader = const Uuid().v7obj();
            serverUser = const Uuid().v7obj();
            shared = await rawServerSession.offlineSync.spaces.create(
              grants: {
                writer: OfflineSyncSpaceRole.readWrite,
                reader: OfflineSyncSpaceRole.readOnly,
                serverUser: OfflineSyncSpaceRole.readWrite,
              },
            );

            serverSession = OfflineSyncDatabaseSession.wraps(
              sessionBuilder.build(),
              syncTables: serverSyncTables,
            );
            await serverSession.db.initialize();
            writerClient = await clientFor(writer);
            readerClient = await clientFor(reader);

            // Establish both clients so they learn their shared grants.
            await syncOnce(writerClient, writer);
            await syncOnce(readerClient, reader);

            writerPerson = await writerClient.db.transactionForUser(
              writer,
              spaceId: shared,
              (tx) => client.Person.db.insertRow(
                writerClient,
                client.Person(name: 'written on the writer device'),
                transaction: tx,
              ),
            );
            await syncOnce(writerClient, writer);

            serverUserPerson = await serverSession.db.transactionForUser(
              serverUser,
              spaceId: shared,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'written by another user on the server'),
                transaction: tx,
              ),
            );
            serverWriterPerson = await serverSession.db.transactionForUser(
              writer,
              spaceId: shared,
              (tx) => server.Person.db.insertRow(
                serverSession,
                server.Person(name: 'written by the writer on the server'),
                transaction: tx,
              ),
            );
          });

          test(
            'then each fact on the server keeps the clock of the user and database '
            'that authored it.',
            () async {
              final writerDevice = await writerClient.db.currentNodeId();
              final writerOnServer = await serverSession.db.currentNodeId(
                userId: writer,
              );
              final serverUserOnServer = await serverSession.db.currentNodeId(
                userId: serverUser,
              );

              expect(await serverAuthor(writerPerson.id!), writerDevice);
              expect(await serverAuthor(serverUserPerson.id!), serverUserOnServer);
              expect(await serverAuthor(serverWriterPerson.id!), writerOnServer);
              expect(
                {writerDevice, writerOnServer, serverUserOnServer},
                hasLength(3),
              );
            },
          );

          group('when the read-only member syncs,', () {
            late SyncRound round;

            setUpAll(() async {
              round = await syncOnce(readerClient, reader);
            });

            test('then it downloads every fact in the shared space.', () async {
              expect(round.serverError, isNull);
              expect(
                rowIds(round.toClient),
                containsAll([
                  writerPerson.id,
                  serverUserPerson.id,
                  serverWriterPerson.id,
                ]),
              );
              final people = await client.Person.db.find(
                readerClient,
                where: (t) => t.spaceEquals(shared),
              );
              expect(
                people.map((person) => person.id),
                unorderedEquals([
                  writerPerson.id,
                  serverUserPerson.id,
                  serverWriterPerson.id,
                ]),
              );
            });

            test('then the downloaded facts keep their source nodes.', () async {
              for (final rowId in [
                writerPerson.id!,
                serverUserPerson.id!,
                serverWriterPerson.id!,
              ]) {
                expect(
                  await clientAuthor(readerClient, rowId),
                  await serverAuthor(rowId),
                );
              }
            });

            test('then it uploads nothing.', () {
              expect(round.toServer, isEmpty);
            });
          });

          group('when the writer reconnects,', () {
            late SyncRound round;
            late SyncRound idleRound;

            setUpAll(() async {
              round = await syncOnce(writerClient, writer);
              idleRound = await syncOnce(writerClient, writer);
            });

            test(
              "then it receives the server's facts, including its own user's server "
              'clock, but not its own device facts.',
              () async {
                expect(round.serverError, isNull);
                expect(rowIds(round.toClient), {
                  serverUserPerson.id,
                  serverWriterPerson.id,
                });
                expect(
                  await clientAuthor(writerClient, serverWriterPerson.id!),
                  await serverSession.db.currentNodeId(userId: writer),
                );
              },
            );

            test('then it echoes nothing back to the server.', () {
              expect(round.toServer, isEmpty);
            });

            test('then the persisted checkpoints leave nothing to resend.', () {
              expect(idleRound.toClient, isEmpty);
              expect(idleRound.toServer, isEmpty);
            });
          });

          group('when the read-only member uploads a write to the shared space,', () {
            late UuidValue deniedId;
            late SyncRound round;

            setUpAll(() async {
              deniedId = const Uuid().v7obj();
              final readerDevice = await readerClient.db.currentNodeId();
              round = await syncOnce(
                readerClient,
                reader,
                splice: [
                  CrdtMergeInsert(
                    uuidSpaceId: shared,
                    tableName: client.Person.t.tableName,
                    uuidRowId: deniedId,
                    uuidNodeId: readerDevice,
                    hlcDatetime: DateTime.now().toUtc(),
                    hlcCounter: 0,
                    data: client.Person(id: deniedId, name: 'denied'),
                  ),
                ],
              );
            });

            test('then the server rejects it as an unauthorized write.', () async {
              expect(round.serverError, isA<OfflineSyncIntegrityViolationException>());
              expect(
                await server.Person.db.findById(rawServerSession, deniedId),
                isNull,
              );
            });
          });
        },
      );
    },
  );
}
