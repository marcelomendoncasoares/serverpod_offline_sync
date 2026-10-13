import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Per-user clock ownership under real concurrent PostgreSQL transactions.
///
/// Waits are observed in `pg_stat_activity` while barriers hold transactions open.
void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_user_clock_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL per-user clocks]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${serverDirectory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 20,
      ),
    ),
    (sessionBuilder, _) {
      late Session raw;
      late Session observer;
      late DateTime start;

      /// A new wrapper on its own session, sharing no cache with the others.
      Future<OfflineSyncDatabaseSession> wrapper() async {
        final session = OfflineSyncDatabaseSession.wraps(
          sessionBuilder.build(),
          syncTables: server.syncTables,
        );
        await session.db.initialize();
        return session;
      }

      setUpAll(() async {
        raw = sessionBuilder.build();
        observer = sessionBuilder.build();
        start = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        );
        await (await wrapper()).db.initialize();
      });

      Future<Hlc> fieldHlc(
        UuidValue rowId,
        String column, {
        Transaction? transaction,
      }) async {
        final field = await CrdtDataField.db.findFirstRow(
          raw,
          where: (t) => t.row.uuidRowId.equals(rowId) & t.column.name.equals(column),
          include: CrdtDataField.include(node: CrdtNode.include()),
          transaction: transaction,
        );
        return field!.hlc;
      }

      Future<CrdtNode> authorOf(UuidValue rowId) async {
        final row = await CrdtDataRow.db.findFirstRow(
          raw,
          where: (t) => t.uuidRowId.equals(rowId),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );
        return row!.node!;
      }

      Future<CrdtNode?> userNode(UuidValue userId) => CrdtNode.db.findFirstRow(
        raw,
        where: (t) => t.localUserUuid.equals(userId),
      );

      group('Given a user without a local clock,', () {
        late UuidValue user;

        setUpAll(() {
          user = const Uuid().v7obj();
        });

        group(
          'when wrappers resolve it while another first use is still uncommitted,',
          () {
            late UuidValue claimedNodeId;
            late bool resolversWaited;
            late List<UuidValue> resolved;
            late List<CrdtNode> owned;
            late UuidValue reopened;

            setUpAll(() async {
              claimedNodeId = const Uuid().v7obj();
              final resolvers = [for (var i = 0; i < 4; i++) await wrapper()];

              final claimed = Completer<void>();
              final release = _releasedOnTearDown();
              final claimant = raw.db.transaction((tx) async {
                await CrdtNode.db.insertRow(
                  raw,
                  CrdtNode(
                    uuidNodeId: claimedNodeId,
                    localUserUuid: user,
                    lastHlc: Hlc.zero(claimedNodeId),
                  ),
                  transaction: tx,
                );
                claimed.complete();
                await release.future;
              });
              await claimed.future;

              final resolving = [
                for (final resolver in resolvers)
                  resolver.db.currentNodeId(userId: user),
              ];
              await _untilLockWait(observer);
              resolversWaited = true;

              release.complete();
              await claimant;
              resolved = await Future.wait(resolving);

              owned = await CrdtNode.db.find(
                raw,
                where: (t) => t.localUserUuid.equals(user),
              );
              reopened = await (await wrapper()).db.currentNodeId(userId: user);
            });

            test('then the later first uses wait for the uncommitted one.', () {
              expect(resolversWaited, isTrue);
            });

            test('then every wrapper resolves the one persisted node.', () {
              expect(resolved.toSet(), {claimedNodeId});
              expect(owned.map((node) => node.uuidNodeId), [claimedNodeId]);
            });

            test('then a reopened wrapper resolves the same node.', () {
              expect(reopened, claimedNodeId);
            });
          },
        );
      });

      group('Given two users without local clocks,', () {
        late UuidValue first;
        late UuidValue second;

        setUpAll(() {
          first = const Uuid().v7obj();
          second = const Uuid().v7obj();
        });

        test(
          'when one wrapper resolves both clocks, '
          'then each user gets a distinct node.',
          () async {
            final session = await wrapper();
            final firstNodeId = await session.db.currentNodeId(userId: first);
            final secondNodeId = await session.db.currentNodeId(userId: second);

            expect(firstNodeId, isNot(secondNodeId));
          },
        );
      });

      /// Holds a write transaction for [first] while [second] writes and merges
      /// in its own space, then releases it.
      Future<_DisjointRun> holdFirstWhileSecondWritesAndMerges({
        required OfflineSyncDatabaseSession firstWrapper,
        required UuidValue first,
        required OfflineSyncDatabaseSession secondWrapper,
        required UuidValue second,
      }) async {
        final firstRow = server.Unique(id: const Uuid().v7obj(), name: 'held');
        final secondRow = server.Unique(id: const Uuid().v7obj(), name: 'free');
        final mergedRow = server.Unique(id: const Uuid().v7obj(), name: 'merged');

        final entered = Completer<void>();
        final release = _releasedOnTearDown();
        var holdingCompleted = false;
        final holding = firstWrapper.db
            .transactionForUser(first, (tx) async {
              await server.Unique.db.insertRow(firstWrapper, firstRow, transaction: tx);
              entered.complete();
              await release.future;
            })
            .whenComplete(() => holdingCompleted = true);
        await entered.future;

        await secondWrapper.db
            .transactionForUser(
              second,
              (tx) =>
                  server.Unique.db.insertRow(secondWrapper, secondRow, transaction: tx),
            )
            .timeout(const Duration(seconds: 10));
        await secondWrapper.db
            .mergeChanges([
              CrdtMergeInsert(
                uuidSpaceId: second,
                tableName: server.Unique.t.tableName,
                uuidRowId: mergedRow.id!,
                uuidNodeId: const Uuid().v7obj(),
                hlcDatetime: clock.now().toUtc(),
                hlcCounter: 0,
                data: mergedRow,
              ),
            ], userId: second)
            .timeout(const Duration(seconds: 10));
        final waitersWhileHeld = await _lockWaiters(observer);
        final firstStillOpen = !holdingCompleted;

        release.complete();
        await holding;

        return (
          firstStillOpen: firstStillOpen,
          waitersWhileHeld: waitersWhileHeld,
          firstAuthor: (await authorOf(firstRow.id!)).id!,
          secondAuthor: (await authorOf(secondRow.id!)).id!,
          firstClock: (await userNode(first))!.id!,
          secondClock: (await userNode(second))!.id!,
        );
      }

      group('Given two users acting for the first time,', () {
        late UuidValue first;
        late UuidValue second;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;

        setUpAll(() async {
          first = const Uuid().v7obj();
          second = const Uuid().v7obj();
          firstWrapper = await wrapper();
          secondWrapper = await wrapper();
        });

        group(
          'when one holds a write transaction while the other writes and merges in its own space,',
          () {
            late _DisjointRun run;

            setUpAll(() async {
              run = await holdFirstWhileSecondWritesAndMerges(
                firstWrapper: firstWrapper,
                first: first,
                secondWrapper: secondWrapper,
                second: second,
              );
            });

            test(
              'then the second user finishes without waiting for the held clock.',
              () {
                expect(run.firstStillOpen, isTrue);
                expect(run.waitersWhileHeld, 0);
              },
            );

            test('then each user authored with its own local clock.', () {
              expect(run.firstAuthor, run.firstClock);
              expect(run.secondAuthor, run.secondClock);
              expect(run.firstClock, isNot(run.secondClock));
            });
          },
        );
      });

      group('Given two users whose clocks and spaces already exist,', () {
        late UuidValue first;
        late UuidValue second;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;

        setUpAll(() async {
          first = const Uuid().v7obj();
          second = const Uuid().v7obj();
          firstWrapper = await wrapper();
          secondWrapper = await wrapper();
          await firstWrapper.db.transactionForUser(
            first,
            (tx) => server.Unique.db.insertRow(
              firstWrapper,
              server.Unique(name: 'prime'),
              transaction: tx,
            ),
          );
          await secondWrapper.db.transactionForUser(
            second,
            (tx) => server.Unique.db.insertRow(
              secondWrapper,
              server.Unique(name: 'prime'),
              transaction: tx,
            ),
          );
        });

        group(
          'when one holds a write transaction while the other writes and merges in its own space,',
          () {
            late _DisjointRun run;

            setUpAll(() async {
              run = await holdFirstWhileSecondWritesAndMerges(
                firstWrapper: firstWrapper,
                first: first,
                secondWrapper: secondWrapper,
                second: second,
              );
            });

            test(
              'then the second user finishes without waiting for the held clock.',
              () {
                expect(run.firstStillOpen, isTrue);
                expect(run.waitersWhileHeld, 0);
              },
            );

            test('then each user authored with its own local clock.', () {
              expect(run.firstAuthor, run.firstClock);
              expect(run.secondAuthor, run.secondClock);
              expect(run.firstClock, isNot(run.secondClock));
            });
          },
        );
      });

      Future<String> readCounter(
        OfflineSyncDatabaseSession session,
        server.Unique counter,
        Transaction tx,
      ) async => (await server.Unique.db.findById(
        session,
        counter.id!,
        transaction: tx,
      ))!.name;

      Future<void> writeCounter(
        OfflineSyncDatabaseSession session,
        server.Unique counter,
        Transaction tx,
        String value,
      ) => server.Unique.db.updateRow(
        session,
        counter.copyWith(name: value),
        columns: (t) => [t.name],
        transaction: tx,
      );

      /// A new user with a counter named [counter] that the first of two new
      /// wrappers inserts and the second reads at [start], so both cache the
      /// user's clock and space from then.
      Future<_StaleWrappers> staleWrappers({required String counter}) async {
        final user = const Uuid().v7obj();
        final first = await wrapper();
        final second = await wrapper();
        final row = server.Unique(id: const Uuid().v7obj(), name: counter);

        await withClock(Clock.fixed(start), () async {
          await first.db.transactionForUser(
            user,
            (tx) => server.Unique.db.insertRow(first, row, transaction: tx),
          );
          await second.db.transactionForUser(
            user,
            (tx) => readCounter(second, row, tx),
          );
        });
        return (user: user, first: first, second: second, counter: row);
      }

      group('Given one user with two wrappers holding stale cached clocks,', () {
        late UuidValue user;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;
        late server.Unique counter;

        setUpAll(() async {
          (user: user, first: firstWrapper, second: secondWrapper, counter: counter) =
              await staleWrappers(counter: '10');
        });

        group(
          'when the first reads, the second starts, and the first commits a write with a newer wall clock,',
          () {
            late String firstRead;
            late String secondRead;
            late bool secondEnteredWhileHeld;
            late Hlc firstClock;
            late Hlc secondClock;
            late Hlc persistedClock;
            late String committed;

            setUpAll(() async {
              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              final firstTransaction = withClock(
                Clock.fixed(start.add(const Duration(seconds: 10))),
                () => firstWrapper.db.transactionForUser(user, (tx) async {
                  firstRead = await readCounter(firstWrapper, counter, tx);
                  entered.complete();
                  await release.future;
                  await writeCounter(
                    firstWrapper,
                    counter,
                    tx,
                    '${int.parse(firstRead) + 1}',
                  );
                  firstClock = await fieldHlc(counter.id!, 'name', transaction: tx);
                }),
              );
              await entered.future;

              var secondEntered = false;
              final secondTransaction = withClock(
                Clock.fixed(start),
                () => secondWrapper.db.transactionForUser(user, (tx) async {
                  secondEntered = true;
                  secondRead = await readCounter(secondWrapper, counter, tx);
                  await writeCounter(
                    secondWrapper,
                    counter,
                    tx,
                    '${int.parse(secondRead) + 1}',
                  );
                }),
              );
              await _untilLockWait(observer);
              secondEnteredWhileHeld = secondEntered;

              release.complete();
              await Future.wait([firstTransaction, secondTransaction]);
              secondClock = await fieldHlc(counter.id!, 'name');
              persistedClock = await persistedUserClock(raw, user);
              committed = await firstWrapper.db.transactionForUser(
                user,
                (tx) => readCounter(firstWrapper, counter, tx),
              );
            });

            test('then the second callback waits for the first to commit.', () {
              expect(secondEnteredWhileHeld, isFalse);
            });

            test('then the second callback reads the committed value.', () {
              expect(firstRead, '10');
              expect(secondRead, '11');
              expect(committed, '12');
            });

            test(
              'then the second write follows the first despite its older wall clock.',
              () {
                expect(secondClock.compareTo(firstClock), greaterThan(0));
                expect(persistedClock, secondClock);
              },
            );
          },
        );
      });

      group('Given one user with two wrappers holding stale cached clocks,', () {
        late UuidValue user;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;
        late server.Unique counter;

        setUpAll(() async {
          (user: user, first: firstWrapper, second: secondWrapper, counter: counter) =
              await staleWrappers(counter: '10');
        });

        group('when the first allocates a newer clock and rolls back,', () {
          late Hlc clockBefore;
          late Object? rollbackError;
          late Hlc secondClock;
          late Hlc persistedClock;
          late String committed;

          setUpAll(() async {
            clockBefore = await persistedUserClock(raw, user);
            final written = Completer<void>();
            final release = _releasedOnTearDown();
            final firstTransaction = withClock(
              Clock.fixed(start.add(const Duration(seconds: 30))),
              () => firstWrapper.db.transactionForUser(user, (tx) async {
                await writeCounter(firstWrapper, counter, tx, 'rolled back');
                written.complete();
                await release.future;
                throw StateError('roll back');
              }),
            ).then<Object?>((_) => null, onError: (Object error) => error);
            await written.future;

            final secondTransaction = withClock(
              Clock.fixed(start),
              () => secondWrapper.db.transactionForUser(user, (tx) async {
                await writeCounter(secondWrapper, counter, tx, 'after rollback');
              }),
            );
            await _untilLockWait(observer);

            release.complete();
            rollbackError = await firstTransaction;
            await secondTransaction;
            secondClock = await fieldHlc(counter.id!, 'name');
            persistedClock = await persistedUserClock(raw, user);
            committed = await firstWrapper.db.transactionForUser(
              user,
              (tx) => readCounter(firstWrapper, counter, tx),
            );
          });

          test('then the rolled back write leaves no value behind.', () {
            expect(rollbackError, isA<StateError>());
            expect(committed, 'after rollback');
          });

          test('then the next write continues from the committed clock.', () {
            expect(secondClock.compareTo(clockBefore), greaterThan(0));
            expect(
              secondClock.datetime.isBefore(start.add(const Duration(seconds: 30))),
              isTrue,
            );
            expect(persistedClock, secondClock);
          });
        });
      });

      group('Given one user with two wrappers holding stale cached clocks,', () {
        late UuidValue user;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;
        late server.Unique counter;

        setUpAll(() async {
          (user: user, first: firstWrapper, second: secondWrapper, counter: counter) =
              await staleWrappers(counter: '10');
        });

        group(
          'when a transaction starts while an inbound merge for the same user is held,',
          () {
            late bool callbackEnteredWhileHeld;
            late String? readInCallback;

            setUpAll(() async {
              final paused = Completer<void>();
              final release = _releasedOnTearDown();
              final merger = OfflineSyncDatabaseSession(
                _PauseInMergeTransaction(sessionBuilder.build().db, paused, release),
                syncTables: server.syncTables,
              );
              await merger.db.initialize();

              final merged = server.Unique(
                id: const Uuid().v7obj(),
                name: 'merged first',
              );
              final merging = merger.db.mergeChanges([
                CrdtMergeInsert(
                  uuidSpaceId: user,
                  tableName: server.Unique.t.tableName,
                  uuidRowId: merged.id!,
                  uuidNodeId: const Uuid().v7obj(),
                  hlcDatetime: clock.now().toUtc(),
                  hlcCounter: 0,
                  data: merged,
                ),
              ], userId: user);
              await paused.future.timeout(const Duration(seconds: 10));

              var callbackEntered = false;
              final reading = firstWrapper.db.transactionForUser(user, (tx) async {
                callbackEntered = true;
                readInCallback = (await server.Unique.db.findById(
                  firstWrapper,
                  merged.id!,
                  transaction: tx,
                ))?.name;
              });
              await _untilLockWait(observer);
              callbackEnteredWhileHeld = callbackEntered;

              release.complete();
              await Future.wait([merging, reading]);
            });

            test('then the callback waits for the merge to commit.', () {
              expect(callbackEnteredWhileHeld, isFalse);
            });

            test('then its first read sees the merged row.', () {
              expect(readInCallback, 'merged first');
            });
          },
        );

        group(
          'when an inbound merge for the same user starts during a transaction,',
          () {
            late bool mergeFinishedWhileHeld;
            late bool waited;

            setUpAll(() async {
              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              final holding = firstWrapper.db.transactionForUser(user, (tx) async {
                await readCounter(firstWrapper, counter, tx);
                entered.complete();
                await release.future;
              });
              await entered.future;

              final merged = server.Unique(id: const Uuid().v7obj(), name: 'merged');
              var mergeFinished = false;
              final merging = secondWrapper.db
                  .mergeChanges([
                    CrdtMergeInsert(
                      uuidSpaceId: user,
                      tableName: server.Unique.t.tableName,
                      uuidRowId: merged.id!,
                      uuidNodeId: const Uuid().v7obj(),
                      hlcDatetime: clock.now().toUtc(),
                      hlcCounter: 0,
                      data: merged,
                    ),
                  ], userId: user)
                  .whenComplete(() => mergeFinished = true);
              await _untilLockWait(observer);
              waited = true;
              mergeFinishedWhileHeld = mergeFinished;

              release.complete();
              await Future.wait([holding, merging]);
            });

            test('then the merge waits for the transaction to finish.', () {
              expect(waited, isTrue);
              expect(mergeFinishedWhileHeld, isFalse);
            });
          },
        );
      });

      group(
        'Given a user who already wrote through a wrapper counting clock access,',
        () {
          late UuidValue user;
          late _CountClockAccess counter;
          late OfflineSyncDatabaseSession session;

          setUpAll(() async {
            user = const Uuid().v7obj();
            counter = _CountClockAccess(sessionBuilder.build().db);
            session = OfflineSyncDatabaseSession(
              counter,
              syncTables: server.syncTables,
            );
            await session.db.initialize();
            await session.db.transactionForUser(
              user,
              (tx) => server.Unique.db.insertRow(
                session,
                server.Unique(name: 'prime'),
                transaction: tx,
              ),
            );
          });

          Future<Hlc> rowClock(UuidValue rowId) async =>
              (await CrdtDataRow.db.findFirstRow(
                raw,
                where: (t) => t.uuidRowId.equals(rowId),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              ))!.hlc;

          Future<Hlc?> spaceClock() async => (await OfflineSyncSpace.db.findFirstRow(
            raw,
            where: (t) => t.uuidSpaceId.equals(user),
          ))!.lastHlc;

          group('when one callback writes three times,', () {
            late int lockReads;
            late int clockWrites;
            late List<Hlc> rowClocks;
            late Hlc persistedClock;
            late Hlc? persistedSpaceClock;

            setUpAll(() async {
              final rows = [
                for (var i = 0; i < 3; i++)
                  server.Unique(id: const Uuid().v7obj(), name: 'write $i'),
              ];
              final locksBefore = counter.lockReads;
              final writesBefore = counter.clockWrites;
              await session.db.transactionForUser(user, (tx) async {
                for (final row in rows) {
                  await server.Unique.db.insertRow(session, row, transaction: tx);
                }
              });
              lockReads = counter.lockReads - locksBefore;
              clockWrites = counter.clockWrites - writesBefore;

              rowClocks = [for (final row in rows) await rowClock(row.id!)];
              persistedClock = await persistedUserClock(raw, user);
              persistedSpaceClock = await spaceClock();
            });

            test('then it locks the clock and the space only once.', () {
              expect(lockReads, 2);
            });

            test('then it stores the clock and the space high-water mark once.', () {
              expect(clockWrites, 2);
            });

            test('then the writes advance one clock monotonically.', () {
              expect(rowClocks[1].compareTo(rowClocks[0]), greaterThan(0));
              expect(rowClocks[2].compareTo(rowClocks[1]), greaterThan(0));
            });

            test('then the stored clocks cover the last write.', () {
              expect(persistedClock, rowClocks[2]);
              expect(persistedSpaceClock, rowClocks[2]);
            });
          });

          group('when a callback only reads,', () {
            late int clockWrites;
            late Hlc clockBefore;
            late Hlc clockAfter;

            setUpAll(() async {
              clockBefore = await persistedUserClock(raw, user);
              final writesBefore = counter.clockWrites;
              await session.db.transactionForUser(
                user,
                (tx) => server.Unique.db.find(session, transaction: tx),
              );
              clockWrites = counter.clockWrites - writesBefore;
              clockAfter = await persistedUserClock(raw, user);
            });

            test('then it stores no clock.', () {
              expect(clockWrites, 0);
              expect(clockAfter, clockBefore);
            });
          });

          group('when a callback catches a failed write and writes again,', () {
            late Object? caught;
            late server.Unique kept;
            late Hlc keptClock;
            late Hlc persistedClock;
            late Hlc? persistedSpaceClock;

            setUpAll(() async {
              final taken = server.Unique(id: const Uuid().v7obj(), name: 'taken');
              kept = server.Unique(id: const Uuid().v7obj(), name: 'kept');
              await session.db.transactionForUser(user, (tx) async {
                await server.Unique.db.insertRow(session, taken, transaction: tx);
                try {
                  await server.Unique.db.insertRow(
                    session,
                    server.Unique(name: 'taken'),
                    transaction: tx,
                  );
                  caught = null;
                } on Object catch (error) {
                  caught = error;
                }
                await server.Unique.db.insertRow(session, kept, transaction: tx);
              });

              keptClock = await rowClock(kept.id!);
              persistedClock = await persistedUserClock(raw, user);
              persistedSpaceClock = await spaceClock();
            });

            test('then the failed write is rejected.', () {
              expect(caught, isA<DatabaseQueryException>());
            });

            test('then the stored clocks cover the write that followed it.', () {
              expect(persistedClock.compareTo(keptClock), greaterThanOrEqualTo(0));
              expect(
                persistedSpaceClock!.compareTo(keptClock),
                greaterThanOrEqualTo(0),
              );
            });
          });

          group('when a callback fails after writing,', () {
            late Object? failure;
            late int clockWrites;
            late Hlc clockBefore;
            late Hlc clockAfter;
            late CrdtDataRow? rolledBackFact;

            setUpAll(() async {
              clockBefore = await persistedUserClock(raw, user);
              final rolledBack = server.Unique(
                id: const Uuid().v7obj(),
                name: 'rolled back',
              );
              final writesBefore = counter.clockWrites;
              failure = await session.db
                  .transactionForUser(user, (tx) async {
                    await server.Unique.db.insertRow(
                      session,
                      rolledBack,
                      transaction: tx,
                    );
                    throw StateError('fail after writing');
                  })
                  .then<Object?>((_) => null, onError: (Object error) => error);
              clockWrites = counter.clockWrites - writesBefore;
              clockAfter = await persistedUserClock(raw, user);
              rolledBackFact = await CrdtDataRow.db.findFirstRow(
                raw,
                where: (t) => t.uuidRowId.equals(rolledBack.id),
              );
            });

            test('then neither the write nor any clock is stored.', () {
              expect(failure, isA<StateError>());
              expect(clockWrites, 0);
              expect(clockAfter, clockBefore);
              expect(rolledBackFact, isNull);
            });
          });
        },
      );

      group('Given two users with write access to one shared space,', () {
        late UuidValue first;
        late UuidValue second;
        late UuidValue shared;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;

        setUpAll(() async {
          first = const Uuid().v7obj();
          second = const Uuid().v7obj();
          shared = await OfflineSyncSpaces(raw).create(
            grants: {
              first: OfflineSyncSpaceRole.readWrite,
              second: OfflineSyncSpaceRole.readWrite,
            },
          );
          firstWrapper = await wrapper();
          secondWrapper = await wrapper();
        });

        group(
          'when one writes the space while the other writes it and a third user writes elsewhere,',
          () {
            late server.Unique firstRow;
            late server.Unique secondRow;
            late bool secondEnteredWhileHeld;
            late bool thirdFinishedWhileHeld;
            late bool grantFinishedWhileHeld;
            late bool sharedStillHeld;
            late CrdtNode firstAuthor;
            late CrdtNode secondAuthor;
            late CrdtNode? firstNode;
            late CrdtNode? secondNode;
            late CrdtNode? spaceNode;

            setUpAll(() async {
              firstRow = server.Unique(id: const Uuid().v7obj(), name: 'first shared');
              secondRow = server.Unique(
                id: const Uuid().v7obj(),
                name: 'second shared',
              );

              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              var holdingCompleted = false;
              final holding = firstWrapper.db
                  .transactionForUser(
                    first,
                    spaceId: shared,
                    (tx) async {
                      await server.Unique.db.insertRow(
                        firstWrapper,
                        firstRow,
                        transaction: tx,
                      );
                      entered.complete();
                      await release.future;
                    },
                  )
                  .whenComplete(() => holdingCompleted = true);
              await entered.future;

              var secondEntered = false;
              final secondWrite = secondWrapper.db.transactionForUser(
                second,
                spaceId: shared,
                (tx) async {
                  secondEntered = true;
                  await server.Unique.db.insertRow(
                    secondWrapper,
                    secondRow,
                    transaction: tx,
                  );
                },
              );
              await _untilLockWait(observer);
              secondEnteredWhileHeld = secondEntered;

              final third = await wrapper();
              final thirdUser = const Uuid().v7obj();
              await third.db
                  .transactionForUser(
                    thirdUser,
                    (tx) => server.Unique.db.insertRow(
                      third,
                      server.Unique(name: 'elsewhere'),
                      transaction: tx,
                    ),
                  )
                  .timeout(const Duration(seconds: 10));
              thirdFinishedWhileHeld = true;

              // Space and clock locks do not block rows that only reference
              // them, such as a new membership in the held space.
              await OfflineSyncSpaces(raw)
                  .grant(
                    space: shared,
                    user: const Uuid().v7obj(),
                    role: OfflineSyncSpaceRole.readOnly,
                  )
                  .timeout(const Duration(seconds: 10));
              grantFinishedWhileHeld = true;
              sharedStillHeld = !holdingCompleted;

              release.complete();
              await Future.wait([holding, secondWrite]);

              firstAuthor = await authorOf(firstRow.id!);
              secondAuthor = await authorOf(secondRow.id!);
              firstNode = await userNode(first);
              secondNode = await userNode(second);
              spaceNode = await userNode(shared);
            });

            test('then writes to the shared space serialize.', () {
              expect(secondEnteredWhileHeld, isFalse);
            });

            test('then a user in another space does not wait for them.', () {
              expect(thirdFinishedWhileHeld, isTrue);
              expect(sharedStillHeld, isTrue);
            });

            test('then granting membership in the space does not wait for them.', () {
              expect(grantFinishedWhileHeld, isTrue);
              expect(sharedStillHeld, isTrue);
            });

            test('then each user keeps its own clock in the shared space.', () {
              expect(firstAuthor.id, firstNode!.id);
              expect(secondAuthor.id, secondNode!.id);
              expect(firstNode!.id, isNot(secondNode!.id));
              expect(spaceNode, isNull);
            });
          },
        );

        group(
          'when a merge claims a unique value and a parent that a held transaction claims and deletes,',
          () {
            late server.Unique localClaim;
            late server.Unique mergedClaim;
            late server.Person mayor;
            late server.Town mergedTown;
            late bool mergeEnteredWhileHeld;
            late List<server.Unique> claims;
            late CrdtDataAttemptedValue? releasedClaim;
            late server.Town? town;
            late CrdtDataAttemptedValue? releasedMayor;

            setUpAll(() async {
              localClaim = server.Unique(id: const Uuid().v7obj(), name: 'claimed');
              mergedClaim = server.Unique(id: const Uuid().v7obj(), name: 'claimed');
              mayor = server.Person(id: const Uuid().v7obj(), name: 'mayor');
              mergedTown = server.Town(
                id: const Uuid().v7obj(),
                name: 'town',
                mayorId: mayor.id,
              );

              await firstWrapper.db.transactionForUser(
                first,
                spaceId: shared,
                (tx) =>
                    server.Person.db.insertRow(firstWrapper, mayor, transaction: tx),
              );

              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              final holding = firstWrapper.db.transactionForUser(
                first,
                spaceId: shared,
                (tx) async {
                  await server.Unique.db.insertRow(
                    firstWrapper,
                    localClaim,
                    transaction: tx,
                  );
                  await server.Person.db.deleteRow(
                    firstWrapper,
                    mayor,
                    transaction: tx,
                  );
                  entered.complete();
                  await release.future;
                },
              );
              await entered.future;

              final remoteNode = const Uuid().v7obj();
              var mergeFinished = false;
              final merging = secondWrapper.db
                  .mergeChanges(
                    [
                      CrdtMergeInsert(
                        uuidSpaceId: shared,
                        tableName: server.Unique.t.tableName,
                        uuidRowId: mergedClaim.id!,
                        uuidNodeId: remoteNode,
                        hlcDatetime: clock.now().toUtc(),
                        hlcCounter: 0,
                        data: mergedClaim,
                      ),
                      CrdtMergeInsert(
                        uuidSpaceId: shared,
                        tableName: server.Town.t.tableName,
                        uuidRowId: mergedTown.id!,
                        uuidNodeId: remoteNode,
                        hlcDatetime: clock.now().toUtc(),
                        hlcCounter: 1,
                        data: mergedTown,
                      ),
                    ],
                    userId: second,
                    spaceId: shared,
                  )
                  .whenComplete(() => mergeFinished = true);
              await _untilLockWait(observer);
              mergeEnteredWhileHeld = mergeFinished;

              release.complete();
              await Future.wait([holding, merging]);

              claims = await firstWrapper.db.transactionForUser(
                first,
                spaceId: shared,
                (tx) => server.Unique.db.find(
                  firstWrapper,
                  where: (t) =>
                      t.id.inSet(<UuidValue>{localClaim.id!, mergedClaim.id!}) &
                      t.spaceEquals(shared),
                  transaction: tx,
                ),
              );
              releasedClaim =
                  await attemptedValue(
                    rowId: localClaim.id!,
                    columnName: 'name',
                    databaseSession: firstWrapper,
                  ) ??
                  await attemptedValue(
                    rowId: mergedClaim.id!,
                    columnName: 'name',
                    databaseSession: firstWrapper,
                  );
              town = await firstWrapper.db.transactionForUser(
                first,
                spaceId: shared,
                (tx) => server.Town.db.findById(
                  firstWrapper,
                  mergedTown.id!,
                  transaction: tx,
                ),
              );
              releasedMayor = await attemptedValue(
                rowId: mergedTown.id!,
                columnName: 'mayorId',
                databaseSession: firstWrapper,
              );
            });

            test('then the merge waits for the held transaction.', () {
              expect(mergeEnteredWhileHeld, isFalse);
            });

            test('then exactly one row holds the unique value.', () {
              expect(claims, hasLength(2));
              expect(claims.where((row) => row.name == 'claimed'), hasLength(1));
              expect(releasedClaim?.value, 'claimed');
            });

            test('then the merged town no longer references the deleted mayor.', () {
              expect(town, isNotNull);
              expect(town!.mayorId, isNull);
              expect(releasedMayor?.value, mayor.id);
            });
          },
        );
      });

      group('Given two users with write access to one shared space,', () {
        late UuidValue first;
        late UuidValue second;
        late UuidValue shared;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;

        setUpAll(() async {
          first = const Uuid().v7obj();
          second = const Uuid().v7obj();
          shared = await OfflineSyncSpaces(raw).create(
            grants: {
              first: OfflineSyncSpaceRole.readWrite,
              second: OfflineSyncSpaceRole.readWrite,
            },
          );
          firstWrapper = await wrapper();
          secondWrapper = await wrapper();
        });

        group(
          "when one user's clock runs ahead and the other edits that user's row,",
          () {
            late server.Unique row;
            late Hlc aheadClock;
            late Hlc dependentClock;

            setUpAll(() async {
              row = server.Unique(id: const Uuid().v7obj(), name: 'ahead');
              final remote = server.Unique(id: const Uuid().v7obj(), name: 'remote');

              await withClock(Clock.fixed(start), () async {
                // A remote fact 30 seconds ahead advances only the first clock.
                await firstWrapper.db.mergeChanges([
                  CrdtMergeInsert(
                    uuidSpaceId: first,
                    tableName: server.Unique.t.tableName,
                    uuidRowId: remote.id!,
                    uuidNodeId: const Uuid().v7obj(),
                    hlcDatetime: start.add(const Duration(seconds: 30)),
                    hlcCounter: 0,
                    data: remote,
                  ),
                ], userId: first);
                await firstWrapper.db.transactionForUser(
                  first,
                  spaceId: shared,
                  (tx) =>
                      server.Unique.db.insertRow(firstWrapper, row, transaction: tx),
                );
                await secondWrapper.db.transactionForUser(
                  second,
                  spaceId: shared,
                  (tx) => server.Unique.db.updateRow(
                    secondWrapper,
                    row.copyWith(name: 'dependent'),
                    columns: (t) => [t.name],
                    transaction: tx,
                  ),
                );
              });

              aheadClock = (await CrdtDataRow.db.findFirstRow(
                raw,
                where: (t) => t.uuidRowId.equals(row.id),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              ))!.hlc;
              dependentClock = await fieldHlc(row.id!, 'name');
            });

            test(
              'then the dependent write is timestamped after the fact it observed.',
              () {
                expect(aheadClock.datetime, start.add(const Duration(seconds: 30)));
                expect(dependentClock.compareTo(aheadClock), greaterThan(0));
              },
            );
          },
        );
      });

      group("Given a user whose clock runs ahead of a shared space's facts,", () {
        late UuidValue ahead;
        late UuidValue editor;
        late UuidValue shared;
        late OfflineSyncDatabaseSession aheadWrapper;
        late OfflineSyncDatabaseSession editorWrapper;
        late Hlc clockBeforeMerge;

        CrdtMergeInsert remoteInsert(
          UuidValue spaceId,
          server.Unique data,
          Duration offset,
        ) => CrdtMergeInsert(
          uuidSpaceId: spaceId,
          tableName: server.Unique.t.tableName,
          uuidRowId: data.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: start.add(offset),
          hlcCounter: 0,
          data: data,
        );

        setUpAll(() async {
          ahead = const Uuid().v7obj();
          editor = const Uuid().v7obj();
          shared = await OfflineSyncSpaces(raw).create(
            grants: {
              ahead: OfflineSyncSpaceRole.readWrite,
              editor: OfflineSyncSpaceRole.readWrite,
            },
          );
          aheadWrapper = await wrapper();
          editorWrapper = await wrapper();

          // A fact 30 seconds ahead in the user's own space advances the clock.
          await withClock(
            Clock.fixed(start),
            () => aheadWrapper.db.mergeChanges([
              remoteInsert(
                ahead,
                server.Unique(id: const Uuid().v7obj(), name: 'elsewhere'),
                const Duration(seconds: 30),
              ),
            ], userId: ahead),
          );
          clockBeforeMerge = await persistedUserClock(raw, ahead);
        });

        group(
          'when the user merges an older remote fact into the space and another user edits it,',
          () {
            late Hlc mergedFact;
            late Hlc clockAfterMerge;
            late Hlc? spaceClock;
            late Hlc edit;

            setUpAll(() async {
              final row = server.Unique(id: const Uuid().v7obj(), name: 'merged');

              await withClock(Clock.fixed(start), () async {
                await aheadWrapper.db.mergeChanges(
                  [remoteInsert(shared, row, const Duration(seconds: 10))],
                  userId: ahead,
                  spaceId: shared,
                );
                clockAfterMerge = await persistedUserClock(raw, ahead);

                await editorWrapper.db.transactionForUser(
                  editor,
                  spaceId: shared,
                  (tx) => server.Unique.db.updateRow(
                    editorWrapper,
                    row.copyWith(name: 'edited'),
                    columns: (t) => [t.name],
                    transaction: tx,
                  ),
                );
              });

              mergedFact = (await CrdtDataRow.db.findFirstRow(
                raw,
                where: (t) => t.uuidRowId.equals(row.id),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              ))!.hlc;
              spaceClock = (await OfflineSyncSpace.db.findFirstRow(
                raw,
                where: (t) => t.uuidSpaceId.equals(shared),
              ))!.lastHlc;
              edit = await fieldHlc(row.id!, 'name');
            });

            test('then the merge does not advance the clock.', () {
              expect(clockAfterMerge, clockBeforeMerge);
            });

            test('then the space high-water mark still covers the merged fact.', () {
              expect(spaceClock!.compareTo(mergedFact), greaterThan(0));
            });

            test('then the edit is timestamped after the merged fact.', () {
              expect(edit.compareTo(mergedFact), greaterThan(0));
            });
          },
        );
      });

      group('Given a user with read access to a shared space,', () {
        late UuidValue user;
        late UuidValue shared;
        late OfflineSyncDatabaseSession session;

        setUpAll(() async {
          user = const Uuid().v7obj();
          shared = await OfflineSyncSpaces(raw).create(
            grants: {user: OfflineSyncSpaceRole.readOnly},
          );
          session = await wrapper();
        });

        group('when the user replicates a remote fact into the shared space,', () {
          late UuidValue remoteNode;
          late Hlc incoming;
          late server.Unique row;
          late CrdtNode author;
          late CrdtNode? clockOfUser;
          late CrdtNode? clockOfSpace;
          late OfflineSyncSpace? space;
          late OfflineSyncSpaceNode? checkpoint;

          setUpAll(() async {
            remoteNode = const Uuid().v7obj();
            incoming = Hlc(start.add(const Duration(seconds: 20)), 3, remoteNode);
            row = server.Unique(id: const Uuid().v7obj(), name: 'replicated');

            await withClock(Clock.fixed(start), () async {
              await session.db.mergeChanges(
                [
                  CrdtMergeInsert(
                    uuidSpaceId: shared,
                    tableName: server.Unique.t.tableName,
                    uuidRowId: row.id!,
                    uuidNodeId: remoteNode,
                    hlcDatetime: incoming.datetime,
                    hlcCounter: incoming.counter,
                    data: row,
                  ),
                ],
                userId: user,
                spaceId: shared,
              );
            });

            author = await authorOf(row.id!);
            clockOfUser = await userNode(user);
            clockOfSpace = await userNode(shared);
            space = await OfflineSyncSpace.db.findFirstRow(
              raw,
              where: (t) => t.uuidSpaceId.equals(shared),
            );
            checkpoint = await OfflineSyncSpaceNode.db.findFirstRow(
              raw,
              where: (t) =>
                  t.space.uuidSpaceId.equals(shared) & t.nodeId.equals(author.id),
            );
          });

          test('then the fact keeps its source node.', () {
            expect(author.uuidNodeId, remoteNode);
            expect(author.localUserUuid, isNull);
          });

          test("then the user's clock advances past the fact.", () {
            expect(clockOfUser, isNotNull);
            expect(clockOfUser!.lastHlc!.compareTo(incoming), greaterThanOrEqualTo(0));
          });

          test('then the space is never treated as a user with its own clock.', () {
            expect(clockOfSpace, isNull);
          });

          test('then the space records the fact and its source checkpoint.', () {
            expect(space!.lastHlc!.compareTo(incoming), greaterThanOrEqualTo(0));
            expect(checkpoint?.lastReceivedHlc, incoming);
          });
        });

        group('when the user tries to author a write in the space,', () {
          late Object error;

          setUpAll(() async {
            error = await session.db
                .transactionForUser(
                  user,
                  spaceId: shared,
                  (tx) => server.Unique.db.insertRow(
                    session,
                    server.Unique(name: 'denied'),
                    transaction: tx,
                  ),
                )
                .then<Object>((_) => 'unexpected success', onError: (Object e) => e);
          });

          test('then the write is rejected for its role.', () {
            expect(error, isA<OfflineSyncSpaceRoleException>());
          });
        });
      });

      group(
        'Given two users receiving the same new source nodes in disjoint spaces,',
        () {
          late List<UuidValue> users;
          late List<UuidValue> sources;
          late List<Completer<void>> paused;
          late Completer<void> release;
          late List<OfflineSyncDatabaseSession> sessions;

          setUpAll(() async {
            users = [const Uuid().v7obj(), const Uuid().v7obj()];
            sources = [const Uuid().v7obj(), const Uuid().v7obj()];
            paused = [Completer<void>(), Completer<void>()];
            release = _releasedOnTearDown();
            sessions = [];
            for (final (index, user) in users.indexed) {
              final session = OfflineSyncDatabaseSession(
                _PauseInMergeTransaction(
                  sessionBuilder.build().db,
                  paused[index],
                  release,
                ),
                syncTables: server.syncTables,
              );
              await session.db.initialize();
              // Prepare the space and clock, so the merges only discover sources.
              await session.db.transactionForUser(user, (_) async {});
              sessions.add(session);
            }
          });

          group(
            'when their merges discover the sources in opposite orders and overlap,',
            () {
              late List<Object?> outcomes;
              late List<CrdtNode> sourceNodes;

              setUpAll(() async {
                final time = DateTime.now().toUtc().subtract(
                  const Duration(seconds: 5),
                );
                CrdtMergeInsert insert(UuidValue space, UuidValue source, int second) {
                  final row = server.Person(
                    id: const Uuid().v7obj(),
                    name: 'from $source',
                  );
                  return CrdtMergeInsert(
                    uuidSpaceId: space,
                    tableName: server.Person.t.tableName,
                    uuidRowId: row.id!,
                    uuidNodeId: source,
                    hlcDatetime: time.add(Duration(seconds: second)),
                    hlcCounter: 0,
                    data: row,
                  );
                }

                // Causal order applies the first batch's sources as 0, 1 and the
                // second batch's as 1, 0.
                final merges = [
                  sessions[0].db.mergeChanges([
                    insert(users[0], sources[0], 0),
                    insert(users[0], sources[1], 3),
                  ], userId: users[0]),
                  sessions[1].db.mergeChanges([
                    insert(users[1], sources[1], 1),
                    insert(users[1], sources[0], 2),
                  ], userId: users[1]),
                ];
                final settled = [
                  for (final merge in merges)
                    merge.then<Object?>((_) => null, onError: (Object error) => error),
                ];

                // Both merges hold their transactions open at the first metadata
                // they write there before either continues.
                await Future.wait([
                  for (final barrier in paused) barrier.future,
                ]).timeout(const Duration(seconds: 15));
                release.complete();
                outcomes = await Future.wait(
                  settled,
                ).timeout(const Duration(seconds: 20));

                sourceNodes = await CrdtNode.db.find(
                  raw,
                  where: (t) => t.uuidNodeId.inSet(sources.toSet()),
                );
              });

              test('then both merges commit without a deadlock.', () {
                expect(outcomes, [null, null]);
              });

              test('then each source is recorded once as a remote node.', () {
                expect(
                  sourceNodes.map((node) => node.uuidNodeId),
                  unorderedEquals(sources),
                );
                expect(
                  sourceNodes.map((node) => node.localUserUuid),
                  everyElement(isNull),
                );
                expect(sourceNodes.map((node) => node.lastHlc), everyElement(isNull));
              });
            },
          );
        },
      );

      group('Given two users who can both write two shared spaces,', () {
        late List<UuidValue> users;
        late List<UuidValue> spaces;

        setUpAll(() async {
          users = [const Uuid().v7obj(), const Uuid().v7obj()];
          spaces = [
            for (var i = 0; i < 2; i++)
              await OfflineSyncSpaces(raw).create(
                grants: {
                  for (final user in users) user: OfflineSyncSpaceRole.readWrite,
                },
              ),
          ];
        });

        group(
          'when every user and space pair writes and merges concurrently while disjoint pairs hold their transactions,',
          () {
            late Object? failure;
            late bool disjointOverlapped;

            setUpAll(() async {
              // Hold (user 0, space 0) and (user 1, space 1) open together: they
              // share neither a clock nor a space, so both must be inside their
              // callbacks at the same time.
              final entered = [Completer<void>(), Completer<void>()];
              final release = _releasedOnTearDown();
              final holders = [
                for (var i = 0; i < 2; i++)
                  (await wrapper()).let(
                    (session) => session.db.transactionForUser(
                      users[i],
                      spaceId: spaces[i],
                      (tx) async {
                        await server.Unique.db.insertRow(
                          session,
                          server.Unique(name: 'holder $i'),
                          transaction: tx,
                        );
                        entered[i].complete();
                        await release.future;
                      },
                    ),
                  ),
              ];
              await Future.wait([
                for (final barrier in entered) barrier.future,
              ]).timeout(const Duration(seconds: 10));
              disjointOverlapped = !release.isCompleted;

              // The crossing pairs wait on both held clocks and spaces.
              final crossing = <Future<void>>[];
              for (final (userIndex, spaceIndex) in [(0, 1), (1, 0), (0, 0), (1, 1)]) {
                final session = await wrapper();
                crossing
                  ..add(
                    session.db.transactionForUser(
                      users[userIndex],
                      spaceId: spaces[spaceIndex],
                      (tx) => server.Unique.db.insertRow(
                        session,
                        server.Unique(name: 'write $userIndex $spaceIndex'),
                        transaction: tx,
                      ),
                    ),
                  )
                  ..add(
                    session.db.mergeChanges(
                      [
                        CrdtMergeInsert(
                          uuidSpaceId: spaces[spaceIndex],
                          tableName: server.Unique.t.tableName,
                          uuidRowId: const Uuid().v7obj(),
                          uuidNodeId: const Uuid().v7obj(),
                          hlcDatetime: clock.now().toUtc(),
                          hlcCounter: 0,
                          data: server.Unique(name: 'merge $userIndex $spaceIndex'),
                        ),
                      ],
                      userId: users[userIndex],
                      spaceId: spaces[spaceIndex],
                    ),
                  );
              }
              await _untilLockWait(observer);

              release.complete();
              failure =
                  await Future.wait([
                        ...holders,
                        ...crossing,
                      ])
                      .timeout(const Duration(seconds: 30))
                      .then<Object?>(
                        (_) => null,
                        onError: (Object error) => error,
                      );
            });

            test('then disjoint user and space pairs run at the same time.', () {
              expect(disjointOverlapped, isTrue);
            });

            test(
              'then every overlapping transaction completes without a deadlock.',
              () {
                expect(failure, isNull);
              },
            );
          },
        );
      });
    },
  );
}

/// A barrier released at group teardown too, so a failed arrangement cannot
/// leave a held transaction blocking the server from stopping.
Completer<void> _releasedOnTearDown() {
  final release = Completer<void>();
  addTearDown(() {
    if (!release.isCompleted) release.complete();
  });
  return release;
}

/// Backends of this database other than [observer] waiting for a lock.
Future<int> _lockWaiters(Session observer) async {
  final result = await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE datname = current_database()
  AND wait_event_type = 'Lock'
  AND pid <> pg_backend_pid()
''');
  return result.first.first as int;
}

/// Completes once another backend is observed waiting for a lock.
Future<void> _untilLockWait(Session observer) async {
  final deadline = clock.now().add(const Duration(seconds: 10));
  while (await _lockWaiters(observer) == 0) {
    if (clock.now().isAfter(deadline)) {
      throw TimeoutException('No transaction waited for a lock.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Pauses the first node or row metadata insert inside a merge transaction.
class _PauseInMergeTransaction extends QueryCountingDatabase {
  // The proxy's own parameter is private to its library.
  // ignore: matching_super_parameters
  _PauseInMergeTransaction(super.database, this._paused, this._release);

  final Completer<void> _paused;
  final Completer<void> _release;

  Future<void> _pauseOnce(Iterable<TableRow> rows, Transaction? transaction) async {
    if (transaction == null || _paused.isCompleted) return;
    if (!rows.any((row) => row is CrdtNode || row is CrdtDataRow)) return;
    _paused.complete();
    await _release.future;
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    final result = await super.insert<T>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
    await _pauseOnce(rows, transaction);
    return result;
  }

  @override
  Future<T> insertRow<T extends TableRow>(T row, {Transaction? transaction}) async {
    final result = await super.insertRow<T>(row, transaction: transaction);
    await _pauseOnce([row], transaction);
    return result;
  }
}

/// Counts clock and space lock reads and clock and space writes.
class _CountClockAccess extends QueryCountingDatabase {
  // The proxy's own parameter is private to its library.
  // ignore: matching_super_parameters
  _CountClockAccess(super.database);

  int lockReads = 0;

  int clockWrites = 0;

  @override
  Future<List<T>> updateWhere<T extends TableRow>({
    required List<ColumnValue> columnValues,
    required Expression where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    if (T == CrdtNode || T == OfflineSyncSpace) clockWrites++;
    return super.updateWhere<T>(
      columnValues: columnValues,
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  @override
  Future<T?> findById<T extends TableRow>(
    Object id, {
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    if (lockMode != null) lockReads++;
    return super.findById<T>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<T?> findFirstRow<T extends TableRow>({
    Expression? where,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    if (lockMode != null) lockReads++;
    return super.findFirstRow<T>(
      where: where,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    if (lockMode != null) lockReads++;
    return super.find<T>(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}

/// What `holdFirstWhileSecondWritesAndMerges` observed, with authors and
/// clocks as node ids.
typedef _DisjointRun = ({
  bool firstStillOpen,
  int waitersWhileHeld,
  int firstAuthor,
  int secondAuthor,
  int firstClock,
  int secondClock,
});

/// One user's counter and two wrappers that cached the user's clock and space
/// when it was written.
typedef _StaleWrappers = ({
  UuidValue user,
  OfflineSyncDatabaseSession first,
  OfflineSyncDatabaseSession second,
  server.Unique counter,
});
