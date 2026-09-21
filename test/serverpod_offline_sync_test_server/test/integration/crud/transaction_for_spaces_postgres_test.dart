import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_scopes_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL space transactions',
    (sessionBuilder, _) {
      late Session raw;
      late OfflineSyncDatabaseSession session;
      late OfflineSyncDatabaseSession secondSession;

      setUp(() async {
        raw = sessionBuilder.build();
        await raw.db.unsafeExecute(
          'TRUNCATE offline_sync_spaces, crdt_nodes RESTART IDENTITY CASCADE',
        );

        session = OfflineSyncDatabaseSession.wraps(raw, syncTables: syncTables);
        secondSession = OfflineSyncDatabaseSession.wraps(raw, syncTables: syncTables);

        await session.db.initialize();
        await secondSession.db.initialize();
      });

      group('Given a replica with an existing node and a new personal space,', () {
        late UuidValue user;

        setUp(() async {
          user = const Uuid().v7obj();

          await session.db.currentNodeId(userId: const Uuid().v7obj());
        });

        test(
          'when two sessions prepare that space concurrently, '
          'then both succeed with one space and node association.',
          () async {
            // Both preparations must read the absent space before either can
            // insert it. PostgreSQL's table lock provides that exact barrier.
            late Future<List<void>> preparations;

            await raw.db.transaction((barrier) async {
              await raw.db.unsafeExecute(
                'LOCK TABLE offline_sync_spaces IN SHARE MODE',
                transaction: barrier,
              );

              preparations = Future.wait([
                session.db.transactionForSpaces<void>(user, {user}, (_) async {}),
                secondSession.db.transactionForSpaces<void>(user, {user}, (_) async {}),
              ]);
              await _waitForBlockedTransactions(raw, 2);
            });
            await preparations;

            final spaces = await OfflineSyncSpace.db.find(
              raw,
              where: (t) => t.uuidSpaceId.equals(user),
            );
            final associations = await OfflineSyncSpaceNode.db.find(
              raw,
              where: (t) => t.spaceId.equals(spaces.single.id),
            );

            expect(spaces, hasLength(1));
            expect(associations, hasLength(1));
            expect(associations.single.nodeId, spaces.single.currentNodeId);
          },
        );
      });

      test(
        'Given a database without a local replica node, '
        'when different sessions prepare their first spaces concurrently, '
        'then both spaces share one committed replica identity.',
        () async {
          late Future<List<void>> preparations;

          await raw.db.transaction((barrier) async {
            await raw.db.unsafeExecute(
              'LOCK TABLE crdt_nodes IN SHARE MODE',
              transaction: barrier,
            );

            preparations = Future.wait([
              session.db.transactionForUser<void>(const Uuid().v7obj(), (_) async {}),
              secondSession.db.transactionForUser<void>(
                const Uuid().v7obj(),
                (_) async {},
              ),
            ]);
            await _waitForBlockedTransactions(raw, 2);
          });
          await preparations;

          final spaces = await OfflineSyncSpace.db.find(raw);
          final nodes = await CrdtNode.db.find(raw);

          expect(spaces, hasLength(2));
          expect(nodes, hasLength(1));
          expect(spaces.map((space) => space.currentNodeId).toSet(), {nodes.single.id});
        },
      );

      group('Given a user with a shared space and no personal space yet,', () {
        late UuidValue user;
        late OfflineSyncSpace shared;

        setUp(() async {
          user = const Uuid().v7obj();

          shared = await OfflineSyncSpace.db.insertRow(
            raw,
            OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
          );

          await OfflineSyncSpaceMember.db.insertRow(
            raw,
            OfflineSyncSpaceMember(
              spaceId: shared.id!,
              userUuid: user,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );
        });

        group(
          'when a failed nested write is caught and both spaces are written again,',
          () {
            late StateError failure;
            Object? caught;
            late List<Person> rows;
            late List<Person> visible;
            late List<CrdtDataRow> records;
            late List<OfflineSyncSpace> prepared;

            setUp(() async {
              failure = StateError('nested rollback');

              await session.db.transactionForSpaces(user, {user, shared.uuidSpaceId}, (
                spaces,
              ) async {
                prepared = await OfflineSyncSpace.db.find(raw);

                await spaces.runForSpace(user, (tx) async {
                  await Person.db.insertRow(
                    session,
                    Person(name: 'before'),
                    transaction: tx,
                  );

                  try {
                    await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                      await Person.db.insertRow(
                        session,
                        Person(name: 'discard'),
                        transaction: tx,
                      );

                      throw failure;
                    });
                  } on Object catch (error) {
                    caught = error;
                  }

                  await Person.db.insertRow(
                    session,
                    Person(name: 'after'),
                    transaction: tx,
                  );

                  await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'shared'),
                      transaction: tx,
                    );

                    visible = await Person.db.find(session, transaction: tx);
                  });
                });
              });

              rows = await Person.db.find(raw);
              records = await CrdtDataRow.db.find(raw);
            });

            test(
              'then the failed savepoint is rolled back and the outer binding is restored.',
              () {
                final personal = prepared.singleWhere((s) => s.uuidSpaceId == user);

                expect(caught, same(failure));
                expect(rows.map((r) => (r.name, r.spaceId)).toSet(), {
                  ('before', personal.id),
                  ('after', personal.id),
                  ('shared', shared.id),
                });
                expect(visible.map((r) => r.name).toSet(), {
                  'before',
                  'after',
                  'shared',
                });
              },
            );

            test('then CRDT rows retain the committed preparation identities.', () {
              expect(records, hasLength(3));

              for (final row in rows) {
                final record = records.singleWhere((r) => r.uuidRowId == row.id);
                final space = prepared.singleWhere((s) => s.id == row.spaceId);

                expect(record.spaceId, space.id);
                expect(record.nodeId, space.currentNodeId);
              }
            });
          },
        );
      });

      group('Given a PostgreSQL transaction spanning personal and shared spaces,', () {
        late UuidValue user;
        late OfflineSyncSpace shared;

        setUp(() async {
          user = const Uuid().v7obj();

          shared = await OfflineSyncSpace.db.insertRow(
            raw,
            OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
          );

          await OfflineSyncSpaceMember.db.insertRow(
            raw,
            OfflineSyncSpaceMember(
              spaceId: shared.id!,
              userUuid: user,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );
        });

        group('when a parent writes through another wrapper while its child runs,', () {
          Object? writeError;
          Object? transactionError;
          late int rows;
          late int records;

          setUp(() async {
            writeError = null;
            transactionError = null;

            final entered = Completer<void>();
            final resume = Completer<void>();

            await session.db
                .transactionForSpaces<void>(user, {user, shared.uuidSpaceId}, (
                  spaces,
                ) async {
                  try {
                    await spaces.runForSpace(user, (tx) async {
                      await Person.db.insertRow(
                        session,
                        Person(name: 'before'),
                        transaction: tx,
                      );

                      final child = spaces.runForSpace<void>(shared.uuidSpaceId, (
                        _,
                      ) async {
                        entered.complete();
                        await resume.future;
                      });
                      await entered.future;

                      try {
                        await Person.db.insertRow(
                          secondSession,
                          Person(name: 'private'),
                          transaction: tx,
                        );
                      } on Object catch (error) {
                        writeError = error;
                      } finally {
                        resume.complete();
                        await child;
                      }
                    });
                  } on Object {
                    // Handling a scope error cannot make the transaction healthy again.
                  }
                })
                .catchError((Object error) {
                  transactionError = error;
                });

            rows = await Person.db.count(raw);
            records = await CrdtDataRow.db.count(raw);
          });

          test(
            'then the private write is rejected and every domain and CRDT write rolls back.',
            () {
              expect(writeError, isA<StateError>());
              expect(transactionError, isA<StateError>());
              expect(rows, 0);
              expect(records, 0);
            },
          );
        });

        group(
          'when a caller destroys a scope savepoint and catches its rollback failure,',
          () {
            Object? scopeError;
            Object? transactionError;
            late int rows;
            late int records;

            setUp(() async {
              scopeError = null;
              transactionError = null;

              await session.db
                  .transactionForSpaces<void>(user, {user, shared.uuidSpaceId}, (
                    spaces,
                  ) async {
                    final tx = await spaces.runForSpace(user, (tx) async => tx);
                    final earlierSavepoint = await tx.createSavepoint();

                    try {
                      await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                        await Person.db.insertRow(
                          session,
                          Person(name: 'must not commit'),
                          transaction: tx,
                        );

                        await earlierSavepoint.release();
                        throw StateError('scope action failed');
                      });
                    } on Object catch (error) {
                      scopeError = error;
                    }
                  })
                  .catchError((Object error) {
                    transactionError = error;
                  });

              rows = await Person.db.count(raw);
              records = await CrdtDataRow.db.count(raw);
            });

            test(
              'then the enclosing transaction fails and the failed scope cannot commit.',
              () {
                expect(scopeError, isA<RollbackToSavepointFailedException>());
                expect(transactionError, isA<StateError>());
                expect(rows, 0);
                expect(records, 0);
              },
            );
          },
        );
      });

      group('Given two sessions with prepared personal and shared spaces,', () {
        late UuidValue user;
        late OfflineSyncSpace personal;
        late OfflineSyncSpace shared;
        late Person personalPerson;
        late Person sharedPerson;
        late Person remotePerson;
        late CrdtMergeSet incoming;

        setUp(() async {
          user = const Uuid().v7obj();

          shared = await OfflineSyncSpace.db.insertRow(
            raw,
            OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
          );

          await OfflineSyncSpaceMember.db.insertRow(
            raw,
            OfflineSyncSpaceMember(
              spaceId: shared.id!,
              userUuid: user,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );

          await session.db.transactionForSpaces<void>(user, {
            user,
            shared.uuidSpaceId,
          }, (_) async {});
          await secondSession.db.currentNodeId(userId: shared.uuidSpaceId);

          personal = (await OfflineSyncSpace.db.findFirstRow(
            raw,
            where: (t) => t.uuidSpaceId.equals(user),
          ))!;

          personalPerson = Person(id: const Uuid().v7obj(), name: 'personal');
          sharedPerson = Person(id: const Uuid().v7obj(), name: 'shared');

          remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');
          final remoteHlc = Hlc(DateTime.now().toUtc(), 0, const Uuid().v7obj());
          incoming = [
            CrdtMergeInsert(
              uuidSpaceId: shared.uuidSpaceId,
              tableName: Person.t.tableName,
              uuidRowId: remotePerson.id!,
              uuidNodeId: remoteHlc.nodeId,
              hlcDatetime: remoteHlc.datetime,
              hlcCounter: remoteHlc.counter,
              data: remotePerson,
            ),
          ];
        });

        group('when a merge into the second space overlaps the multi-space write,', () {
          Object? localError;
          Object? mergeError;
          late List<Person> rows;
          late List<CrdtDataRow> records;

          setUp(() async {
            localError = null;
            mergeError = null;

            final firstWritten = Completer<void>();
            final resume = Completer<void>();

            final local = session.db
                .transactionForSpaces<void>(
                  user,
                  {user, shared.uuidSpaceId},
                  (spaces) async {
                    await spaces.runForSpace(
                      user,
                      (tx) =>
                          Person.db.insertRow(session, personalPerson, transaction: tx),
                    );

                    firstWritten.complete();
                    await resume.future;

                    await spaces.runForSpace(
                      shared.uuidSpaceId,
                      (tx) =>
                          Person.db.insertRow(session, sharedPerson, transaction: tx),
                    );
                  },
                )
                .catchError((Object error) {
                  localError = error;
                });
            await firstWritten.future;

            final merge = secondSession.db
                .mergeChanges(
                  incoming,
                  spaceId: shared.uuidSpaceId,
                )
                .catchError((Object error) {
                  mergeError = error;
                });

            try {
              // The merge must contend with the live domain transaction;
              // a timer alone cannot establish the problematic lock order.
              await _waitForBlockedTransactions(raw, 1);
            } finally {
              resume.complete();
              await Future.wait([local, merge]);
            }

            rows = await Person.db.find(raw);
            records = await CrdtDataRow.db.find(raw);
          });

          test('then both operations finish without a deadlock.', () {
            expect(localError, isNull);
            expect(mergeError, isNull);
          });

          test(
            'then all local and remote rows retain their space and CRDT identity.',
            () {
              final expectedSpaces = {
                personalPerson.id: personal.id,
                sharedPerson.id: shared.id,
                remotePerson.id: shared.id,
              };

              expect({for (final row in rows) row.id: row.spaceId}, expectedSpaces);
              expect({
                for (final row in records) row.uuidRowId: row.spaceId,
              }, expectedSpaces);
            },
          );
        });
      });

      group('Given a prepared personal space,', () {
        late UuidValue user;
        late OfflineSyncSpace prepared;

        setUp(() async {
          user = const Uuid().v7obj();

          await session.db.transactionForSpaces<void>(user, {user}, (_) async {});

          prepared = (await OfflineSyncSpace.db.findFirstRow(
            raw,
            where: (t) => t.uuidSpaceId.equals(user),
          ))!;
        });

        test(
          'when two independent transactions write concurrently for the same user, '
          'then both commit with the prepared space and node IDs.',
          () async {
            final firstReady = Completer<void>();
            final releaseFirst = Completer<void>();

            final first = session.db.transactionForSpaces(user, {user}, (spaces) async {
              await spaces.runForSpace(user, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'first'),
                  transaction: tx,
                );
              });

              firstReady.complete();
              await releaseFirst.future;
            });
            await firstReady.future;

            final second = secondSession.db.transactionForSpaces(user, {user}, (
              spaces,
            ) async {
              await spaces.runForSpace(user, (tx) async {
                await Person.db.insertRow(
                  secondSession,
                  Person(name: 'second'),
                  transaction: tx,
                );
              });
            });
            final both = Future.wait([first, second]);

            try {
              await _waitForBlockedTransactions(raw, 1);
            } finally {
              releaseFirst.complete();
            }
            await both;

            final rows = await Person.db.find(raw);
            final records = await CrdtDataRow.db.find(raw);

            expect(rows.map((row) => row.name).toSet(), {'first', 'second'});
            expect(rows.map((row) => row.spaceId).toSet(), {prepared.id});
            expect(records.map((row) => row.spaceId).toSet(), {prepared.id});
            expect(records.map((row) => row.nodeId).toSet(), {prepared.currentNodeId});
          },
        );

        test(
          'when a failed first write is retried in a new transaction, '
          'then preparation survives and only the retry has CRDT records.',
          () async {
            final failure = StateError('outer rollback');

            await expectLater(
              session.db.transactionForSpaces(user, {user}, (spaces) async {
                await spaces.runForSpace(user, (tx) async {
                  await Person.db.insertRow(
                    session,
                    Person(name: 'discard'),
                    transaction: tx,
                  );
                });

                throw failure;
              }),
              throwsA(same(failure)),
            );

            await session.db.transactionForSpaces(user, {user}, (spaces) async {
              await spaces.runForSpace(user, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'retry'),
                  transaction: tx,
                );
              });
            });

            final spaces = await OfflineSyncSpace.db.find(raw);
            final rows = await Person.db.find(raw);
            final records = await CrdtDataRow.db.find(raw);

            expect(spaces.single.id, prepared.id);
            expect(spaces.single.currentNodeId, prepared.currentNodeId);
            expect(rows.map((row) => row.name), ['retry']);
            expect(records.single.uuidRowId, rows.single.id);
            expect(records.single.spaceId, prepared.id);
            expect(records.single.nodeId, prepared.currentNodeId);
          },
        );
      });
    },
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${serverDirectory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
  );
}

// Observe real lock waits rather than depending on a scheduling delay. The
// harness owns an isolated database, and tests in this group execute serially.
Future<void> _waitForBlockedTransactions(Session session, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));

  while (DateTime.now().isBefore(deadline)) {
    final result = await session.db.unsafeQuery(
      'SELECT count(*) FROM pg_stat_activity '
      "WHERE datname = current_database() AND wait_event_type = 'Lock'",
    );

    if ((result.single.single as int) >= count) return;

    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  throw StateError('$count transactions did not reach a database lock wait.');
}
