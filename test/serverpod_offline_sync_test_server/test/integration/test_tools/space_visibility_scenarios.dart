import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/embedded.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:test/test.dart';

import 'serverpod_test_tools.dart';
import 'space_cache_peer_client.dart';

void spaceVisibilityScenarios(DatabaseDialect dialect) {
  final project = Directory.current.absolute;
  final postgresDirectory = Directory(
    '${Directory.systemTemp.path}/offline-sync-space-${const Uuid().v7()}',
  );
  ResolvedEmbeddedPostgres? postgres;
  if (dialect == DatabaseDialect.postgres) {
    setUpAll(() async {
      final prepare = await Process.run(
        Platform.resolvedExecutable,
        [
          'run',
          'tool/prepare_space_test_server.dart',
          project.path,
          postgresDirectory.path,
        ],
        workingDirectory: project.parent.parent.path,
      );
      if (prepare.exitCode != 0) {
        throw StateError(
          'PostgreSQL schema generation failed: '
          '${prepare.stdout}\n${prepare.stderr}',
        );
      }
      postgres = await startOrAttachEmbeddedPostgres(
        PostgresDatabaseConfig.embedded(
          dataPath: '${postgresDirectory.path}/pgdata',
          name: 'space_cache',
        ),
      );
    });
    tearDownAll(() async {
      await postgres?.stop?.call();
      if (postgresDirectory.existsSync()) {
        await postgresDirectory.delete(recursive: true);
      }
    });
  }
  OfflineSyncEngine? sync;
  final rawDatabases = Expando<Database>();
  withServerpod(
    'Space visibility on ${dialect.name}',
    (sessionBuilder, _) {
      late Session writer;
      late Session reader;
      late Session otherWriter;

      late Zone readerZone;
      final persistentReaders = <UuidValue, OfflineSyncDatabaseSession>{};

      Future<Set<String>> readOutside(UuidValue user) {
        final session = persistentReaders.putIfAbsent(
          user,
          () => OfflineSyncDatabaseSession(
            sync!.wrapDatabase(rawDatabases[reader]!, persistentUserId: user),
            syncTables: model.syncTables,
          ),
        );
        return readerZone.run(() => _names(session, user));
      }

      setUp(() async {
        readerZone = Zone.current;
        final bootstrap = sessionBuilder.build();
        bootstrap.serverpod.initializeOfflineSync(syncTables: model.syncTables);
        sync = OfflineSyncEngine(
          syncTables: model.syncTables,
          serializationManager: model.Protocol(),
        );
        persistentReaders.clear();
        writer = await bootstrap.serverpod.createSession(enableLogging: false);
        reader = await bootstrap.serverpod.createSession(enableLogging: false);
        otherWriter = await bootstrap.serverpod.createSession(enableLogging: false);
        addTearDown(() async {
          await writer.close();
          await reader.close();
          await otherWriter.close();
        });
      });

      test(
        'Given a user without access to a shared person, '
        'when a membership grant is committed, '
        'then other readers wait for commit and both sessions see the committed grant.',
        () async {
          final user = const Uuid().v7obj();
          final space = await _person(writer, name: 'shared');
          expect(await readOutside(user), isEmpty);

          late Set<String> inside;
          late Future<Set<String>> outside;
          await writer.offlineSyncDb.transactionForUser(user, (tx) async {
            await writer.offlineSync.spaces.grant(
              space: space,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
              transaction: tx,
            );
            inside = await _names(writer, user, transaction: tx);
            outside = readOutside(user);
            await _expectPending(outside);
          });

          expect(inside, {'shared'});
          expect(await outside, {'shared'});
          expect(await readOutside(user), {'shared'});
          expect(await _names(writer, user), {'shared'});
        },
      );

      test(
        'Given a user with access to a shared person, '
        'when a membership revocation is rolled back, '
        'then other readers wait for rollback and retain their committed access.',
        () async {
          final user = const Uuid().v7obj();
          final space = await _person(writer, name: 'shared', member: user);
          expect(await readOutside(user), {'shared'});

          late Set<String> inside;
          late Future<Set<String>> outside;
          await expectLater(
            writer.offlineSyncDb.transactionForUser<void>(user, (tx) async {
              await writer.offlineSync.spaces.revoke(
                space: space,
                user: user,
                transaction: tx,
              );
              inside = await _names(writer, user, transaction: tx);
              outside = readOutside(user);
              await _expectPending(outside);
              throw const _Abort();
            }),
            throwsA(isA<_Abort>()),
          );

          expect(inside, isEmpty);
          expect(await outside, {'shared'});
          expect(await readOutside(user), {'shared'});
          expect(await _names(writer, user), {'shared'});
        },
      );

      test(
        'Given a user without access to a shared person, '
        'when a grant is rolled back to a savepoint and the transaction commits, '
        'then neither that transaction nor later reads retain the rolled-back grant.',
        () async {
          final user = const Uuid().v7obj();
          final space = await _person(writer, name: 'shared');
          expect(await readOutside(user), isEmpty);

          late Set<String> granted;
          late Set<String> rolledBack;
          await writer.offlineSyncDb.transactionForUser(user, (tx) async {
            final savepoint = await tx.createSavepoint();
            await writer.offlineSync.spaces.grant(
              space: space,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
              transaction: tx,
            );
            granted = await _names(writer, user, transaction: tx);
            await savepoint.rollback();
            rolledBack = await _names(writer, user, transaction: tx);
            await savepoint.release();
          });

          expect(granted, {'shared'});
          expect(rolledBack, isEmpty);
          expect(await readOutside(user), isEmpty);
        },
      );

      test(
        'Given a warmed user without shared access, '
        'when a grant is cancelled and another user is subsequently granted access, '
        'then cancellation publishes no access for the first user.',
        () async {
          final user = const Uuid().v7obj();
          final otherUser = const Uuid().v7obj();
          final space = await _person(writer, name: 'shared');
          expect(await readOutside(user), isEmpty);
          expect(await readOutside(otherUser), isEmpty);
          late Set<String> granted;

          await writer.offlineSyncDb.transactionForUser<void>(user, (tx) async {
            await writer.offlineSync.spaces.grant(
              space: space,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
              transaction: tx,
            );
            granted = await _names(writer, user, transaction: tx);
            await tx.cancel();
          });
          await writer.offlineSync.spaces.grant(
            space: space,
            user: otherUser,
            role: OfflineSyncSpaceRole.readOnly,
          );

          expect(granted, {'shared'});
          expect(await readOutside(user), isEmpty);
          expect(await readOutside(otherUser), {'shared'});
        },
      );

      test(
        'Given a user with one committed shared space, '
        'when a released inner savepoint is rolled back with its outer savepoint, '
        'then only the committed space remains visible inside and after the transaction.',
        () async {
          final user = const Uuid().v7obj();
          await _person(writer, name: 'committed', member: user);
          final second = await _person(writer, name: 'outer');
          final third = await _person(writer, name: 'inner');
          expect(await readOutside(user), {'committed'});
          late Set<String> inside;

          await writer.offlineSyncDb.transactionForUser(user, (tx) async {
            expect(await _names(writer, user, transaction: tx), {'committed'});
            final outer = await tx.createSavepoint();
            await writer.offlineSync.spaces.grant(
              space: second,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
              transaction: tx,
            );
            final inner = await tx.createSavepoint();
            await writer.offlineSync.spaces.grant(
              space: third,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
              transaction: tx,
            );
            expect(await _names(writer, user, transaction: tx), {
              'committed',
              'outer',
              'inner',
            });
            await inner.release();
            await outer.rollback();
            inside = await _names(writer, user, transaction: tx);
            await outer.release();
          });

          expect(inside, {'committed'});
          expect(await readOutside(user), {'committed'});
        },
      );

      test(
        'Given two warmed users and a shared membership held by the first, '
        'when the membership is reassigned to the second user using a bulk update, '
        'then the committed visibility removes the first user and admits the second.',
        () async {
          final user = const Uuid().v7obj();
          final otherUser = const Uuid().v7obj();
          await _person(writer, name: 'shared', member: user);
          expect(await readOutside(user), {'shared'});
          expect(await readOutside(otherUser), isEmpty);

          await OfflineSyncSpaceMember.db.updateWhere(
            writer,
            columnValues: (t) => [t.userUuid(otherUser)],
            where: (t) => t.userUuid.equals(user),
            noReturn: true,
          );

          expect(await readOutside(user), isEmpty);
          expect(await readOutside(otherUser), {'shared'});
        },
      );

      test(
        'Given a warmed personal-space owner and another warmed user, '
        'when the personal space UUID is reassigned, '
        'then the cached numeric space identity follows its committed UUID.',
        () async {
          final user = await _person(writer, name: 'personal');
          final otherUser = const Uuid().v7obj();
          expect(await readOutside(user), {'personal'});
          expect(await readOutside(otherUser), isEmpty);
          final otherSpace = await OfflineSyncSpace.db.findFirstRow(
            writer,
            where: (t) => t.uuidSpaceId.equals(otherUser),
          );
          await OfflineSyncSpace.db.deleteRow(writer, otherSpace!);
          final space = await OfflineSyncSpace.db.findFirstRow(
            writer,
            where: (t) => t.uuidSpaceId.equals(user),
          );

          await OfflineSyncSpace.db.updateById(
            writer,
            space!.id!,
            columnValues: (t) => [t.uuidSpaceId(otherUser)],
          );

          expect(await readOutside(user), isEmpty);
          expect(await readOutside(otherUser), {'personal'});
        },
      );

      test(
        'Given a CRDT database wrapped again by an application session, '
        'when it creates a personal row and reads an uncommitted shared grant that is rolled back, '
        'then nested wrappers preserve ownership and publish only committed membership.',
        () async {
          final user = const Uuid().v7obj();
          final shared = await _person(writer, name: 'shared');
          final nested = OfflineSyncDatabaseSession(
            OfflineSyncDatabase(writer.db, syncTables: model.syncTables),
            syncTables: model.syncTables,
          );
          await nested.db.initialize();
          await nested.db.transactionForUser(user, (tx) async {
            await model.Person.db.insertRow(
              nested,
              model.Person(id: const Uuid().v7obj(), name: 'personal'),
              transaction: tx,
            );
          });
          expect(await readOutside(user), {'personal'});
          final space = await OfflineSyncSpace.db.findFirstRow(
            nested,
            where: (t) => t.uuidSpaceId.equals(shared),
          );
          late Set<String> inside;

          await expectLater(
            nested.db.transactionForUser(user, (tx) async {
              await OfflineSyncSpaceMember.db.insertRow(
                nested,
                OfflineSyncSpaceMember(
                  spaceId: space!.id!,
                  userUuid: user,
                  role: OfflineSyncSpaceRole.readOnly,
                ),
                transaction: tx,
              );
              inside = await _names(nested, user, transaction: tx);
              throw const _Abort();
            }),
            throwsA(isA<_Abort>()),
          );

          expect(inside, {'personal', 'shared'});
          expect(await readOutside(user), {'personal'});
        },
      );

      if (dialect == DatabaseDialect.postgres) {
        test(
          'Given two readers that both subsequently change membership, '
          'when PostgreSQL aborts one lock upgrade and the caller retries it, '
          'then only committed grants are visible and the retry preserves both grants.',
          () async {
            final user = const Uuid().v7obj();
            final firstSpace = await _person(writer, name: 'first');
            final secondSpace = await _person(writer, name: 'second');
            expect(await _names(writer, user), isEmpty);
            expect(await _names(otherWriter, user), isEmpty);
            final bothReading = Completer<void>();
            var readers = 0;
            Future<Object?> grantAfterRead(Session session, UuidValue space) => session
                .offlineSyncDb
                .transactionForUser(user, (tx) async {
                  expect(await _names(session, user, transaction: tx), isEmpty);
                  if (++readers == 2) bothReading.complete();
                  await bothReading.future;
                  await session.offlineSync.spaces.grant(
                    space: space,
                    user: user,
                    role: OfflineSyncSpaceRole.readOnly,
                    transaction: tx,
                  );
                  return space;
                })
                .then<Object?>((space) => space, onError: (Object error) => error);

            final outcomes = await Future.wait([
              grantAfterRead(writer, firstSpace),
              grantAfterRead(otherWriter, secondSpace),
            ]).timeout(const Duration(seconds: 10));
            final failures = outcomes.whereType<DatabaseQueryException>().toList();
            expect(failures, hasLength(1));
            expect(failures.single.code, '40P01');
            final committedSpace = outcomes.whereType<UuidValue>().single;
            expect(await readOutside(user), {
              committedSpace == firstSpace ? 'first' : 'second',
            });

            await writer.offlineSync.spaces.grant(
              space: committedSpace == firstSpace ? secondSpace : firstSpace,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
            );

            expect(await readOutside(user), {'first', 'second'});
          },
        );

        test(
          'Given two server processes with independently warmed visibility caches, '
          'when each process changes shared membership, '
          'then both observe the other process grants and revocations without restarting.',
          () async {
            final user = const Uuid().v7obj();
            final space = await _person(writer, name: 'shared');
            final connectivity = postgres!.connectivity.withName(
              (writer.serverpod.config.database! as PostgresDatabaseConfig).name,
            );
            final peer = await SpaceCachePeer.start(project, connectivity);
            addTearDown(peer.close);
            expect(peer.pid, isNot(pid));
            expect(await readOutside(user), isEmpty);
            expect(await peer.read(user), isEmpty);

            await writer.offlineSync.spaces.grant(
              space: space,
              user: user,
              role: OfflineSyncSpaceRole.readOnly,
            );
            expect(await peer.read(user), {'shared'});
            expect(await readOutside(user), {'shared'});
            await peer.command({
              'action': 'revoke',
              'spaceUuid': space.uuid,
              'userUuid': user.uuid,
            });
            expect(await readOutside(user), isEmpty);
            expect(await peer.read(user), isEmpty);
            await peer.command({
              'action': 'grant',
              'spaceUuid': space.uuid,
              'userUuid': user.uuid,
            });
            expect(await readOutside(user), {'shared'});
            await writer.offlineSync.spaces.revoke(space: space, user: user);
            expect(await peer.read(user), isEmpty);
          },
        );

        test(
          'Given two overlapping transactions granting different spaces to one user, '
          'when both membership grants are committed, '
          'then the writers serialize without losing either committed grant.',
          () async {
            final user = const Uuid().v7obj();
            final firstSpace = await _person(writer, name: 'first');
            final secondSpace = await _person(writer, name: 'second');
            expect(await readOutside(user), isEmpty);
            final firstWritten = Completer<void>();
            final commitFirst = Completer<void>();
            final first = writer.offlineSyncDb.transaction((tx) async {
              await writer.offlineSync.spaces.grant(
                space: firstSpace,
                user: user,
                role: OfflineSyncSpaceRole.readOnly,
                transaction: tx,
              );
              firstWritten.complete();
              await commitFirst.future;
            });
            // Observe a transaction failure while the other session runs.
            final firstResult = first.then<Object?>(
              (_) => null,
              onError: (Object e) => e,
            );
            late Future<void> second;
            try {
              await Future.any([firstWritten.future, first]);
              second = otherWriter.offlineSyncDb.transaction((tx) async {
                await otherWriter.offlineSync.spaces.grant(
                  space: secondSpace,
                  user: user,
                  role: OfflineSyncSpaceRole.readOnly,
                  transaction: tx,
                );
              });
              await _expectPending(second);
            } finally {
              commitFirst.complete();
            }
            expect(await firstResult, isNull);
            await second;
            expect(await readOutside(user), {'first', 'second'});
          },
        );

        for (final isolation in [
          IsolationLevel.readCommitted,
          IsolationLevel.repeatableRead,
        ]) {
          test(
            'Given a shared reader at ${isolation.name} isolation, '
            'when another transaction commits a new domain row during its read, '
            'then writes remain concurrent and visibility follows the selected snapshot.',
            () async {
              final user = const Uuid().v7obj();
              final owner = await _person(writer, name: 'before', member: user);
              expect(await readOutside(user), {'before'});
              late Set<String> before;
              late Set<String> after;

              await reader.offlineSyncDb.transactionForUser(user, (tx) async {
                before = await _names(reader, user, transaction: tx);
                await writer.offlineSyncDb
                    .transactionForUser(owner, (writeTx) async {
                      await model.Person.db.insertRow(
                        writer,
                        model.Person(id: const Uuid().v7obj(), name: 'after'),
                        transaction: writeTx,
                      );
                    })
                    .timeout(const Duration(seconds: 5));
                after = await _names(reader, user, transaction: tx);
              }, settings: TransactionSettings(isolationLevel: isolation));

              expect(before, {'before'});
              expect(
                after,
                isolation == IsolationLevel.readCommitted
                    ? {'before', 'after'}
                    : {'before'},
              );
              expect(await readOutside(user), {'before', 'after'});
            },
          );
        }

        for (final isolation in [
          IsolationLevel.readCommitted,
          IsolationLevel.repeatableRead,
        ]) {
          test(
            'Given a user reading without shared access at ${isolation.name} isolation, '
            'when another session attempts a grant during that transaction, '
            'then the grant waits for the reader and becomes visible after both transactions commit.',
            () async {
              final user = const Uuid().v7obj();
              final space = await _person(writer, name: 'shared');
              late Set<String> before;
              late Set<String> after;
              late Future<void> grant;
              await reader.offlineSyncDb.transactionForUser(
                user,
                (tx) async {
                  before = await _names(reader, user, transaction: tx);
                  grant = writer.offlineSync.spaces.grant(
                    space: space,
                    user: user,
                    role: OfflineSyncSpaceRole.readOnly,
                  );
                  await _expectPending(grant);
                  after = await _names(reader, user, transaction: tx);
                },
                settings: TransactionSettings(isolationLevel: isolation),
              );

              expect(before, isEmpty);
              expect(after, isEmpty);
              await grant;
              expect(await readOutside(user), {'shared'});
            },
          );
        }
      }
    },
    databaseInterceptor: (session, inner) {
      rawDatabases[session] = inner;
      return sync?.wrapDatabase(inner) ?? inner;
    },
    serverDirectory: dialect == DatabaseDialect.postgres ? postgresDirectory : null,
    rollbackDatabase: RollbackDatabase.disabled,
    configOverride: dialect == DatabaseDialect.postgres
        ? (config) => config.copyWith(
            database: PostgresDatabaseConfig.embedded(
              dataPath: '${postgresDirectory.path}/pgdata',
              name: 'space_cache',
              maxConnectionCount: 12,
            ),
          )
        : null,
  );
}

Future<UuidValue> _person(
  Session session, {
  required String name,
  UuidValue? member,
}) async {
  final owner = const Uuid().v7obj();
  await session.offlineSyncDb.transactionForUser(owner, (tx) async {
    await model.Person.db.insertRow(
      session,
      model.Person(id: const Uuid().v7obj(), name: name),
      transaction: tx,
    );
  });
  if (member != null) {
    await session.offlineSync.spaces.grant(
      space: owner,
      user: member,
      role: OfflineSyncSpaceRole.readOnly,
    );
  }
  return owner;
}

Future<Set<String>> _names(
  DatabaseSession session,
  UuidValue user, {
  Transaction? transaction,
}) async {
  if (transaction == null && session is! OfflineSyncDatabaseSession) {
    return session.offlineSyncDb.transactionForUser(
      user,
      (tx) => _names(session, user, transaction: tx),
    );
  }
  return {
    for (final row in await model.Person.db.find(
      session,
      transaction: transaction,
    ))
      row.name,
  };
}

final class _Abort implements Exception {
  const _Abort();
}

Future<void> _expectPending(Future<Object?> operation) => expectLater(
  operation.timeout(const Duration(milliseconds: 100)),
  throwsA(isA<TimeoutException>()),
);
