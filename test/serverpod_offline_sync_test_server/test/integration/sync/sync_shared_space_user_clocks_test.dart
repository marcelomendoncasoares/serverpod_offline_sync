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
        'Given a shared space with a read-only member and facts written by a writer device, a server user, and the writer on the server,',
        () {
          late UuidValue writer;
          late UuidValue reader;
          late UuidValue serverUser;
          late UuidValue shared;
          late OfflineSyncDatabaseSession serverSession;
          late OfflineSyncDatabaseSession writerClient;
          late OfflineSyncDatabaseSession readerClient;
          late client.Person writerPerson;
          late server.Person serverUserPerson;
          late server.Person serverWriterPerson;
          late Map<UuidValue, UuidValue> expectedAuthors;

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

          Future<UuidValue?> authorIn(
            DatabaseSession databaseSession,
            UuidValue rowId,
          ) async {
            final row = await CrdtDataRow.db.findFirstRow(
              databaseSession,
              where: (t) => t.uuidRowId.equals(rowId),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            return row?.node?.uuidNodeId;
          }

          Set<UuidValue> rowIds(List<CrdtMergeChange> changes) => {
            for (final change in changes) change.uuidRowId,
          };

          setUp(() async {
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
            expectedAuthors = {
              writerPerson.id!: await writerClient.db.currentNodeId(),
              serverUserPerson.id!: await serverSession.db.currentNodeId(
                userId: serverUser,
              ),
              serverWriterPerson.id!: await serverSession.db.currentNodeId(
                userId: writer,
              ),
            };
          });

          test(
            "when reading each fact's author on the server, "
            'then it is the clock of the user and database that wrote it.',
            () async {
              final authors = {
                for (final rowId in expectedAuthors.keys)
                  rowId: await authorIn(rawServerSession, rowId),
              };

              expect(authors, expectedAuthors);
              expect(expectedAuthors.values.toSet(), hasLength(3));
            },
          );

          group('when the read-only member syncs,', () {
            late SyncRound round;
            late List<client.Person> people;
            late Map<UuidValue, UuidValue?> readerAuthors;

            setUp(() async {
              round = await syncOnce(readerClient, reader);

              people = await client.Person.db.find(
                readerClient,
                where: (t) => t.spaceEquals(shared),
              );
              final written = [
                writerPerson.id!,
                serverUserPerson.id!,
                serverWriterPerson.id!,
              ];
              readerAuthors = {
                for (final rowId in written) rowId: await authorIn(readerClient, rowId),
              };
            });

            test('then it downloads every fact in the shared space.', () {
              expect(round.serverError, isNull);
              expect(
                rowIds(round.toClient),
                containsAll([
                  writerPerson.id,
                  serverUserPerson.id,
                  serverWriterPerson.id,
                ]),
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

            test('then the downloaded facts keep their source nodes.', () {
              expect(round.serverError, isNull);
              expect(readerAuthors, expectedAuthors);
            });

            test('then it uploads nothing.', () {
              expect(round.serverError, isNull);
              expect(round.toServer, isEmpty);
            });
          });

          group('when the writer reconnects twice,', () {
            late SyncRound firstRound;
            late SyncRound secondRound;
            late UuidValue? downloadedServerWriterAuthor;
            late UuidValue writerOnServer;

            setUp(() async {
              firstRound = await syncOnce(writerClient, writer);
              downloadedServerWriterAuthor = await authorIn(
                writerClient,
                serverWriterPerson.id!,
              );
              writerOnServer = await serverSession.db.currentNodeId(userId: writer);
              secondRound = await syncOnce(writerClient, writer);
            });

            test(
              "then the first reconnect receives the server's facts, including its own user's server clock, but not its own device facts.",
              () {
                expect(firstRound.serverError, isNull);
                expect(rowIds(firstRound.toClient), {
                  serverUserPerson.id,
                  serverWriterPerson.id,
                });
                expect(downloadedServerWriterAuthor, writerOnServer);
              },
            );

            test('then the first reconnect echoes nothing back to the server.', () {
              expect(firstRound.serverError, isNull);
              expect(firstRound.toServer, isEmpty);
            });

            test('then the second reconnect has nothing left to exchange.', () {
              expect(secondRound.serverError, isNull);
              expect(secondRound.toClient, isEmpty);
              expect(secondRound.toServer, isEmpty);
            });
          });

          group('when the read-only member uploads a write to the shared space,', () {
            late SyncRound round;
            late server.Person? stored;
            late UuidValue deniedId;

            setUp(() async {
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
              stored = await server.Person.db.findById(rawServerSession, deniedId);
            });

            test('then the server rejects it as an unauthorized write.', () {
              expect(rowIds(round.toServer), contains(deniedId));
              expect(round.serverError, isA<OfflineSyncIntegrityViolationException>());
              expect(stored, isNull);
            });
          });
        },
      );
    },
  );
}
