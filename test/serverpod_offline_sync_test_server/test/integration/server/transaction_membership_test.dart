import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_membership_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL membership visibility]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${serverDirectory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
    (sessionBuilder, _) {
      late Session otherSession;
      late OfflineSyncDatabaseSession session;

      setUp(() async {
        otherSession = sessionBuilder.build();
        session = OfflineSyncDatabaseSession.wraps(
          sessionBuilder.build(),
          syncTables: server.syncTables,
        );
        await session.db.initialize();
      });

      group('Given a PostgreSQL user with membership in a populated shared space,', () {
        late UuidValue userId;
        late server.Person person;
        late OfflineSyncSpaceMember membership;

        setUp(() async {
          userId = const Uuid().v7obj();
          final ownerId = const Uuid().v7obj();
          person = await session.db.transactionForUser(
            ownerId,
            (tx) => server.Person.db.insertRow(
              session,
              server.Person(name: 'shared'),
              transaction: tx,
            ),
          );
          final sharedSpace = await OfflineSyncSpace.db.findFirstRow(
            otherSession,
            where: (t) => t.uuidSpaceId.equals(ownerId),
          );
          membership = await OfflineSyncSpaceMember.db.insertRow(
            otherSession,
            OfflineSyncSpaceMember(
              spaceId: sharedSpace!.id!,
              userUuid: userId,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );
        });

        group(
          'when another session revokes and restores membership during READ COMMITTED,',
          () {
            late List<server.Person> before;
            late List<server.Person> revoked;
            late List<server.Person> restored;

            setUp(() async {
              await session.db.transactionForUser(
                userId,
                (tx) async {
                  before = await server.Person.db.find(session, transaction: tx);

                  await OfflineSyncSpaceMember.db.deleteRow(otherSession, membership);
                  revoked = await server.Person.db.find(session, transaction: tx);

                  await OfflineSyncSpaceMember.db.insertRow(otherSession, membership);
                  restored = await server.Person.db.find(session, transaction: tx);
                },
                settings: const TransactionSettings(
                  isolationLevel: IsolationLevel.readCommitted,
                ),
              );
            });

            test('then successive reads observe both committed changes.', () {
              expect(before.map((row) => row.id), [person.id]);
              expect(revoked, isEmpty);
              expect(restored.map((row) => row.id), [person.id]);
            });
          },
        );

        group('when another session revokes membership during REPEATABLE READ,', () {
          late List<server.Person> before;
          late List<server.Person> insideTransaction;
          late List<server.Person> nextTransaction;
          late OfflineSyncSpaceMember? committedMembership;

          setUp(() async {
            await session.db.transactionForUser(
              userId,
              (tx) async {
                before = await server.Person.db.find(session, transaction: tx);

                await OfflineSyncSpaceMember.db.deleteRow(otherSession, membership);
                committedMembership = await OfflineSyncSpaceMember.db.findById(
                  otherSession,
                  membership.id!,
                );
                insideTransaction = await server.Person.db.find(
                  session,
                  transaction: tx,
                );
              },
              settings: const TransactionSettings(
                isolationLevel: IsolationLevel.repeatableRead,
              ),
            );

            nextTransaction = await session.db.transactionForUser(
              userId,
              (tx) => server.Person.db.find(session, transaction: tx),
            );
          });

          test('then membership follows the snapshot until the next transaction.', () {
            expect(before.map((row) => row.id), [person.id]);
            expect(committedMembership, isNull);
            expect(insideTransaction.map((row) => row.id), [person.id]);
            expect(nextTransaction, isEmpty);
          });
        });
      });
    },
  );
}
