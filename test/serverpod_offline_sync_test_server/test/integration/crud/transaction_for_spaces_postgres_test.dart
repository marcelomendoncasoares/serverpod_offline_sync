import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
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

          await session.db.currentNodeId(userId: user);
        });

        test(
          'when two sessions prepare that space concurrently, '
          'then both succeed with one space and node association.',
          () async {
            // Both preparations must read the absent space before either can
            // insert it. PostgreSQL's table lock provides that exact barrier.
            late Future<List<void>> preparations;
            final callerZone = Zone.current;

            await raw.db.transaction((barrier) async {
              await raw.db.unsafeExecute(
                'LOCK TABLE offline_sync_spaces IN SHARE MODE',
                transaction: barrier,
              );

              // Independent preparations must not inherit the barrier's
              // transaction context when its pooled connection is reused later.
              preparations = callerZone.run(
                () => Future.wait([
                  session.db.transactionForSpaces<void>(user, {user}, (_) async {}),
                  secondSession.db.transactionForSpaces<void>(user, {
                    user,
                  }, (_) async {}),
                ]),
              );
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
            expect(associations.single.nodeId, (await CrdtNode.db.find(raw)).single.id);
            expect((await CrdtNode.db.find(raw)).single.localUserUuid, user);
          },
        );
      });

      test(
        'Given two users without local clocks, '
        'when different sessions prepare their first spaces concurrently, '
        'then each user has its own committed clock and participation.',
        () async {
          late Future<List<void>> preparations;
          final callerZone = Zone.current;
          final firstUser = const Uuid().v7obj();
          final secondUser = const Uuid().v7obj();

          await raw.db.transaction((barrier) async {
            await raw.db.unsafeExecute(
              'LOCK TABLE crdt_nodes IN SHARE MODE',
              transaction: barrier,
            );

            preparations = callerZone.run(
              () => Future.wait([
                session.db.transactionForSpaces<void>(firstUser, {
                  firstUser,
                }, (_) async {}),
                secondSession.db.transactionForSpaces<void>(secondUser, {
                  secondUser,
                }, (_) async {}),
              ]),
            );
            await _waitForBlockedTransactions(raw, 2);
          });
          await preparations;

          final spaces = await OfflineSyncSpace.db.find(raw);
          final nodes = await CrdtNode.db.find(raw);

          expect(spaces, hasLength(2));
          expect(nodes, hasLength(2));
          expect(nodes.map((node) => node.localUserUuid).toSet(), {
            firstUser,
            secondUser,
          });
          final participation = await OfflineSyncSpaceNode.db.find(raw);
          for (final node in nodes) {
            final space = spaces.singleWhere(
              (space) => space.uuidSpaceId == node.localUserUuid,
            );
            expect(
              participation.singleWhere((row) => row.nodeId == node.id).spaceId,
              space.id,
            );
          }
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
            late CrdtNode author;

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
              author = (await CrdtNode.db.find(raw)).single;
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
                expect(record.nodeId, author.id);
                expect(author.localUserUuid, user);
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

        group(
          'when a first nested write rolls back while another transaction waits,',
          () {
            late bool competitorEnteredBeforeCommit;
            late Hlc outerClock;
            late Hlc competingClock;
            late Hlc storedClock;
            late List<CrdtMergeChange> pending;
            late List<Person> rows;
            late Hlc? sharedClock;

            setUp(() async {
              final rolledBack = Completer<void>();
              final release = Completer<void>();
              var competitorEntered = false;
              final discarded = Person(id: const Uuid().v7obj(), name: 'discard');
              final outerRow = Person(id: const Uuid().v7obj(), name: 'outer');
              final competingRow = Person(id: const Uuid().v7obj(), name: 'competing');
              final failure = Exception('nested rollback');
              final now = Clock.fixed(DateTime.utc(2030));

              // Warm both wrappers before the held transaction, so preparation
              // cannot be the source of the observed lock wait.
              await session.db.transactionForSpaces<void>(user, {
                user,
                shared.uuidSpaceId,
              }, (_) async {});
              await secondSession.db.transactionForUser<void>(user, (_) async {});

              final outer = withClock(now, () {
                return session.db.transactionForSpaces<void>(
                  user,
                  {user, shared.uuidSpaceId},
                  (spaces) {
                    return spaces.runForSpace(user, (tx) async {
                      try {
                        await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                          await Person.db.insertRow(
                            session,
                            discarded,
                            transaction: tx,
                          );
                          throw failure;
                        });
                      } on Exception catch (error) {
                        if (!identical(error, failure)) rethrow;
                      }

                      rolledBack.complete();
                      await release.future;
                      await Person.db.insertRow(session, outerRow, transaction: tx);
                    });
                  },
                );
              });
              await rolledBack.future;

              final competing = withClock(now, () {
                return secondSession.db.transactionForUser<void>(user, (tx) async {
                  competitorEntered = true;
                  await Person.db.insertRow(
                    secondSession,
                    competingRow,
                    transaction: tx,
                  );
                });
              });

              try {
                await _waitForBlockedTransactions(raw, 1);
                competitorEnteredBeforeCommit = competitorEntered;
              } finally {
                release.complete();
                await Future.wait([outer, competing]);
              }

              final records = await CrdtDataRow.db.find(
                raw,
                include: CrdtDataRow.include(node: CrdtNode.include()),
              );
              outerClock = records
                  .singleWhere((row) => row.uuidRowId == outerRow.id)
                  .hlc;
              competingClock = records
                  .singleWhere((row) => row.uuidRowId == competingRow.id)
                  .hlc;
              storedClock = (await CrdtNode.db.find(raw)).single.lastHlc!;
              sharedClock = (await OfflineSyncSpace.db.findById(
                raw,
                shared.id!,
              ))!.lastHlc;
              rows = await Person.db.find(raw);
              pending =
                  await OfflineSyncEngine(
                        syncTables: syncTables,
                        serializationManager: raw.db.serializationManager,
                      )
                      .collectPendingChanges(
                        raw,
                        checkpointsBySpaceUuid: {
                          user: records
                              .singleWhere((row) => row.uuidRowId == outerRow.id)
                              .syncRevision,
                        },
                      )
                      .toList();
            });

            test('then the user lock survives the savepoint rollback.', () {
              expect(competitorEnteredBeforeCommit, isFalse);
              expect(rows.map((row) => row.name).toSet(), {'outer', 'competing'});
              expect(sharedClock, isNull);
            });

            test(
              'then committed clocks and outbound checkpoints preserve commit order.',
              () {
                expect(outerClock.counter, 0);
                expect(competingClock.compareTo(outerClock), greaterThan(0));
                expect(storedClock, competingClock);
                expect(pending, hasLength(1));
                expect(
                  (pending.single as CrdtMergeInsert).data.toJson()['name'],
                  'competing',
                );
              },
            );
          },
        );

        group(
          'when a caller savepoint inside a scope rolls back while another transaction waits,',
          () {
            late bool competitorEnteredBeforeCommit;
            late Hlc outerClock;
            late Hlc competingClock;
            late Hlc storedClock;
            late List<CrdtMergeChange> pending;
            late List<Person> rows;

            setUp(() async {
              final rolledBack = Completer<void>();
              final release = Completer<void>();
              var competitorEntered = false;
              final outerRow = Person(id: const Uuid().v7obj(), name: 'outer');
              final competingRow = Person(id: const Uuid().v7obj(), name: 'competing');
              final now = Clock.fixed(DateTime.utc(2030));

              await session.db.transactionForSpaces<void>(user, {
                user,
                shared.uuidSpaceId,
              }, (_) async {});
              await secondSession.db.transactionForUser<void>(user, (_) async {});

              final outer = withClock(now, () {
                return session.db.transactionForSpaces<void>(
                  user,
                  {user, shared.uuidSpaceId},
                  (spaces) => spaces.runForSpace(user, (tx) async {
                    final savepoint = await tx.createSavepoint();
                    await Person.db.insertRow(
                      session,
                      Person(name: 'discard'),
                      transaction: tx,
                    );
                    await savepoint.rollback();

                    rolledBack.complete();
                    await release.future;
                    await Person.db.insertRow(session, outerRow, transaction: tx);
                  }),
                );
              });
              await rolledBack.future;

              final competing = withClock(now, () {
                return secondSession.db.transactionForUser<void>(user, (tx) async {
                  competitorEntered = true;
                  await Person.db.insertRow(
                    secondSession,
                    competingRow,
                    transaction: tx,
                  );
                });
              });

              try {
                await _waitForBlockedTransactions(raw, 1);
                competitorEnteredBeforeCommit = competitorEntered;
              } finally {
                release.complete();
                await Future.wait([outer, competing]);
              }

              final records = await CrdtDataRow.db.find(
                raw,
                include: CrdtDataRow.include(node: CrdtNode.include()),
              );
              outerClock = records
                  .singleWhere((row) => row.uuidRowId == outerRow.id)
                  .hlc;
              competingClock = records
                  .singleWhere((row) => row.uuidRowId == competingRow.id)
                  .hlc;
              storedClock = (await CrdtNode.db.find(raw)).single.lastHlc!;
              rows = await Person.db.find(raw);
              pending =
                  await OfflineSyncEngine(
                        syncTables: syncTables,
                        serializationManager: raw.db.serializationManager,
                      )
                      .collectPendingChanges(
                        raw,
                        checkpointsBySpaceUuid: {
                          user: records
                              .singleWhere((row) => row.uuidRowId == outerRow.id)
                              .syncRevision,
                        },
                      )
                      .toList();
            });

            test('then the user lock survives the caller savepoint rollback.', () {
              expect(competitorEnteredBeforeCommit, isFalse);
              expect(rows.map((row) => row.name).toSet(), {'outer', 'competing'});
            });

            test(
              'then the competing commit remains sendable after the outer commit.',
              () {
                expect(competingClock.compareTo(outerClock), greaterThan(0));
                expect(storedClock, competingClock);
                expect(pending, hasLength(1));
                expect(
                  (pending.single as CrdtMergeInsert).data.toJson()['name'],
                  'competing',
                );
              },
            );
          },
        );

        group('when a parent fails after a nested scope succeeds,', () {
          late List<Person> rows;
          late List<CrdtDataRow> records;
          late Hlc storedClock;
          late Hlc? sharedClock;
          late StateError failure;
          Object? caught;

          setUp(() async {
            failure = StateError('parent failure');
            caught = null;

            await withClock(Clock.fixed(DateTime.utc(2030)), () {
              return session.db.transactionForSpaces<void>(
                user,
                {
                  user,
                  shared.uuidSpaceId,
                },
                (spaces) async {
                  try {
                    await spaces.runForSpace(user, (tx) async {
                      await Person.db.insertRow(
                        session,
                        Person(name: 'discard parent'),
                        transaction: tx,
                      );
                      await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
                        await Person.db.insertRow(
                          session,
                          Person(name: 'discard child'),
                          transaction: tx,
                        );
                      });

                      throw failure;
                    });
                  } on Object catch (error) {
                    caught = error;
                  }

                  await spaces.runForSpace(user, (tx) async {
                    await Person.db.insertRow(
                      session,
                      Person(name: 'kept'),
                      transaction: tx,
                    );
                  });
                },
              );
            });

            rows = await Person.db.find(raw);
            records = await CrdtDataRow.db.find(
              raw,
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            storedClock = (await CrdtNode.db.find(raw)).single.lastHlc!;
            sharedClock = (await OfflineSyncSpace.db.findById(
              raw,
              shared.id!,
            ))!.lastHlc;
          });

          test('then both scopes roll back their domain and CRDT writes.', () {
            expect(caught, same(failure));
            expect(rows.map((row) => row.name), ['kept']);
            expect(records.map((record) => record.uuidRowId), [rows.single.id]);
          });

          test(
            'then the user clock and shared space high-water discard both scopes.',
            () {
              expect(records.single.hlc.counter, 0);
              expect(storedClock, records.single.hlc);
              expect(sharedClock, isNull);
            },
          );
        });

        group('and another user owns an unrelated row,', () {
          late Person unrelated;

          setUp(() async {
            unrelated = await session.db.transactionForUser(
              const Uuid().v7obj(),
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'unrelated'),
                transaction: tx,
              ),
            );
          });

          group('when an unbound transaction attempts to lock that row,', () {
            Object? lockError;
            Object? observerError;
            late List<Person> observed;

            setUp(() async {
              lockError = null;
              observerError = null;
              observed = [];

              await session.db.transactionForSpaces(user, {user}, (spaces) async {
                final tx = await spaces.runForSpace(user, (tx) async => tx);

                try {
                  await Person.db.lockRows(
                    secondSession,
                    where: (t) => t.id.equals(unrelated.id),
                    lockMode: LockMode.forUpdate,
                    transaction: tx,
                  );
                } on Object catch (error) {
                  lockError = error;
                }

                try {
                  await raw.db.transaction((observer) async {
                    await Person.db.lockRows(
                      raw,
                      where: (t) => t.id.equals(unrelated.id),
                      lockMode: LockMode.forUpdate,
                      lockBehavior: LockBehavior.noWait,
                      transaction: observer,
                    );
                    observed = await Person.db.find(
                      raw,
                      where: (t) => t.id.equals(unrelated.id),
                      transaction: observer,
                    );
                  });
                } on Object catch (error) {
                  observerError = error;
                }
              });
            });

            test('then the tracked lock is rejected through another wrapper.', () {
              expect(lockError, isA<StateError>());
            });

            test('then an independent transaction can lock that row immediately.', () {
              expect(observerError, isNull);
              expect(observed.map((row) => row.id), [unrelated.id]);
            });
          });
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
                  userId: shared.uuidSpaceId,
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

      group('Given two users allowed to write the same two shared spaces,', () {
        late UuidValue firstUser;
        late UuidValue secondUser;
        late OfflineSyncSpace firstSpace;
        late OfflineSyncSpace secondSpace;

        setUp(() async {
          firstUser = const Uuid().v7obj();
          secondUser = const Uuid().v7obj();
          final manager = OfflineSyncSpaceManager(raw);
          firstSpace = await manager.getOrCreate(const Uuid().v7obj());
          secondSpace = await manager.getOrCreate(const Uuid().v7obj());
          await OfflineSyncSpaceMember.db.insert(raw, [
            for (final space in [firstSpace, secondSpace])
              for (final user in [firstUser, secondUser])
                OfflineSyncSpaceMember(
                  spaceId: space.id!,
                  userUuid: user,
                  role: OfflineSyncSpaceRole.readWrite,
                ),
          ]);
          final declared = {firstSpace.uuidSpaceId, secondSpace.uuidSpaceId};
          await session.db.transactionForSpaces<void>(
            firstUser,
            declared,
            (_) async {},
          );
          await secondSession.db.transactionForSpaces<void>(
            secondUser,
            declared,
            (_) async {},
          );
        });

        group(
          'when they declare opposite orders while one transaction holds both spaces,',
          () {
            late bool secondEnteredBeforeRelease;
            late List<Person> rows;
            late List<CrdtDataRow> records;
            late List<CrdtNode> nodes;

            setUp(() async {
              final entered = Completer<void>();
              final release = Completer<void>();
              var secondEntered = false;

              final first = session.db.transactionForSpaces<void>(
                firstUser,
                {
                  firstSpace.uuidSpaceId,
                  secondSpace.uuidSpaceId,
                },
                (spaces) async {
                  entered.complete();
                  await release.future;
                  await spaces.runForSpace(secondSpace.uuidSpaceId, (tx) {
                    return Person.db.insertRow(
                      session,
                      Person(name: 'first user'),
                      transaction: tx,
                    );
                  });
                },
              );
              await entered.future;

              final second = secondSession.db.transactionForSpaces<void>(
                secondUser,
                {
                  secondSpace.uuidSpaceId,
                  firstSpace.uuidSpaceId,
                },
                (spaces) async {
                  secondEntered = true;
                  await spaces.runForSpace(firstSpace.uuidSpaceId, (tx) {
                    return Person.db.insertRow(
                      secondSession,
                      Person(name: 'second user'),
                      transaction: tx,
                    );
                  });
                },
              );

              try {
                await _waitForBlockedTransactions(raw, 1);
                secondEnteredBeforeRelease = secondEntered;
              } finally {
                release.complete();
                await Future.wait([first, second]);
              }

              rows = await Person.db.find(raw);
              records = await CrdtDataRow.db.find(raw);
              nodes = await CrdtNode.db.find(raw);
            });

            test(
              'then the second callback waits and both writes commit without deadlock.',
              () {
                expect(secondEnteredBeforeRelease, isFalse);
                expect(rows.map((row) => (row.name, row.spaceId)).toSet(), {
                  ('first user', secondSpace.id),
                  ('second user', firstSpace.id),
                });
              },
            );

            test('then each write is authored by its acting user.', () {
              final owners = {for (final node in nodes) node.id: node.localUserUuid};
              final rowById = {for (final row in rows) row.id: row};
              expect(
                records
                    .map(
                      (record) =>
                          (rowById[record.uuidRowId]!.name, owners[record.nodeId]),
                    )
                    .toSet(),
                {
                  ('first user', firstUser),
                  ('second user', secondUser),
                },
              );
            });
          },
        );
      });

      group('Given a prepared personal space,', () {
        late UuidValue user;
        late OfflineSyncSpace prepared;
        late CrdtNode author;

        setUp(() async {
          user = const Uuid().v7obj();

          await session.db.transactionForSpaces<void>(user, {user}, (_) async {});

          author = (await CrdtNode.db.findFirstRow(
            raw,
            where: (t) => t.localUserUuid.equals(user),
          ))!;
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
            expect(records.map((row) => row.nodeId).toSet(), {author.id});
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
            expect((await CrdtNode.db.find(raw)).single.id, author.id);
            expect(rows.map((row) => row.name), ['retry']);
            expect(records.single.uuidRowId, rows.single.id);
            expect(records.single.spaceId, prepared.id);
            expect(records.single.nodeId, author.id);
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
