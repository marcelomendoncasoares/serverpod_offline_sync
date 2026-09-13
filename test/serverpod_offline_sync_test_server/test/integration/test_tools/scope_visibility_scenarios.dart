import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/embedded.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:test/test.dart';

import 'serverpod_test_tools.dart';

void scopeVisibilityScenarios(DatabaseDialect dialect) {
  final project = Directory.current.absolute;
  final postgresDirectory = Directory(
    '${Directory.systemTemp.path}/offline-sync-scope-${const Uuid().v7()}',
  );
  ResolvedEmbeddedPostgres? postgres;
  if (dialect == DatabaseDialect.postgres) {
    setUpAll(() async {
      final prepare = await Process.run(
        Platform.resolvedExecutable,
        [
          'run',
          'tool/prepare_scope_test_server.dart',
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
          name: 'scope_cache',
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
  CrdtSync? sync;
  final rawDatabases = Expando<Database>();
  withServerpod(
    'Scope visibility on ${dialect.name}',
    (sessionBuilder, _) {
      late Session writer;
      late Session reader;
      late Session otherWriter;

      late Zone readerZone;
      final persistentReaders = <UuidValue, CrdtDatabaseSession>{};

      Future<Set<String>> readOutside(UuidValue user) {
        final session = persistentReaders.putIfAbsent(
          user,
          () => CrdtDatabaseSession(
            sync!.wrapDatabase(rawDatabases[reader]!, persistentUserId: user),
            syncTables: model.syncTables,
          ),
        );
        return readerZone.run(() => _names(session, user));
      }

      setUp(() async {
        readerZone = Zone.current;
        final bootstrap = sessionBuilder.build();
        bootstrap.serverpod.initializeCrdtSync(syncTables: model.syncTables);
        sync = CrdtSync(
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
        'then only its transaction sees the grant before commit and both sessions see it afterwards.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await _person(writer, name: 'shared');
          expect(await readOutside(user), isEmpty);

          late Set<String> inside;
          late Set<String> outside;
          await writer.crdtDb.transactionForUser(user, (tx) async {
            await writer.crdt.scopes.grant(
              scope: scope,
              user: user,
              role: CrdtScopeRole.readOnly,
              transaction: tx,
            );
            inside = await _names(writer, user, transaction: tx);
            outside = await readOutside(user);
          });

          expect(inside, {'shared'});
          expect(outside, isEmpty);
          expect(await readOutside(user), {'shared'});
          expect(await _names(writer, user), {'shared'});
        },
      );

      test(
        'Given a user with access to a shared person, '
        'when a membership revocation is rolled back, '
        'then the revocation is private to its transaction and leaves no denied access afterwards.',
        () async {
          final user = const Uuid().v7obj();
          final scope = await _person(writer, name: 'shared', member: user);
          expect(await readOutside(user), {'shared'});

          late Set<String> inside;
          late Set<String> outside;
          await expectLater(
            writer.crdtDb.transactionForUser<void>(user, (tx) async {
              await writer.crdt.scopes.revoke(
                scope: scope,
                user: user,
                transaction: tx,
              );
              inside = await _names(writer, user, transaction: tx);
              outside = await readOutside(user);
              throw const _Abort();
            }),
            throwsA(isA<_Abort>()),
          );

          expect(inside, isEmpty);
          expect(outside, {'shared'});
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
          final scope = await _person(writer, name: 'shared');
          expect(await readOutside(user), isEmpty);

          late Set<String> granted;
          late Set<String> rolledBack;
          await writer.crdtDb.transactionForUser(user, (tx) async {
            final savepoint = await tx.createSavepoint();
            await writer.crdt.scopes.grant(
              scope: scope,
              user: user,
              role: CrdtScopeRole.readOnly,
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

      if (dialect == DatabaseDialect.postgres) {
        test(
          'Given two overlapping transactions granting different scopes to one user, '
          'when the second transaction commits before the first, '
          'then the committed visibility preserves both grants without exposing the pending one.',
          () async {
            final user = const Uuid().v7obj();
            final firstScope = await _person(writer, name: 'first');
            final secondScope = await _person(writer, name: 'second');
            expect(await readOutside(user), isEmpty);
            final firstWritten = Completer<void>();
            final commitFirst = Completer<void>();
            final first = writer.crdtDb.transaction((tx) async {
              await writer.crdt.scopes.grant(
                scope: firstScope,
                user: user,
                role: CrdtScopeRole.readOnly,
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
            late Set<String> afterSecond;
            try {
              await Future.any([firstWritten.future, first]);
              await otherWriter.crdtDb.transaction((tx) async {
                await otherWriter.crdt.scopes.grant(
                  scope: secondScope,
                  user: user,
                  role: CrdtScopeRole.readOnly,
                  transaction: tx,
                );
              });
              afterSecond = await readOutside(user);
            } finally {
              commitFirst.complete();
            }
            expect(await firstResult, isNull);

            expect(afterSecond, {'second'});
            expect(await readOutside(user), {'first', 'second'});
          },
        );

        for (final isolation in [
          IsolationLevel.readCommitted,
          IsolationLevel.repeatableRead,
        ]) {
          test(
            'Given a user reading without shared access at ${isolation.name} isolation, '
            'when another session commits a grant during that transaction, '
            'then visibility follows the selected isolation without changing other readers.',
            () async {
              final user = const Uuid().v7obj();
              final scope = await _person(writer, name: 'shared');
              late Set<String> before;
              late Set<String> after;
              await reader.crdtDb.transactionForUser(
                user,
                (tx) async {
                  before = await _names(reader, user, transaction: tx);
                  await writer.crdt.scopes.grant(
                    scope: scope,
                    user: user,
                    role: CrdtScopeRole.readOnly,
                  );
                  after = await _names(reader, user, transaction: tx);
                },
                settings: TransactionSettings(isolationLevel: isolation),
              );

              expect(before, isEmpty);
              expect(
                after,
                isolation == IsolationLevel.readCommitted ? {'shared'} : isEmpty,
              );
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
              name: 'scope_cache',
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
  await session.crdtDb.transactionForUser(owner, (tx) async {
    await model.Person.db.insertRow(
      session,
      model.Person(id: const Uuid().v7obj(), name: name),
      transaction: tx,
    );
  });
  if (member != null) {
    await session.crdt.scopes.grant(
      scope: owner,
      user: member,
      role: CrdtScopeRole.readOnly,
    );
  }
  return owner;
}

Future<Set<String>> _names(
  DatabaseSession session,
  UuidValue user, {
  Transaction? transaction,
}) async {
  if (transaction == null && session is! CrdtDatabaseSession) {
    return session.crdtDb.transactionForUser(
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
