import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/crdt_probes.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

/// Per-user clock ownership on PostgreSQL, where server sessions run real
/// concurrent transactions on separate connections.
///
/// Every wait asserted here is observed in `pg_stat_activity` while explicit
/// barriers hold the competing transaction open; no assertion relies on a
/// sleep winning a race.
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

      /// A new wrapper on its own session, so it shares no cached space or
      /// clock with any other wrapper.
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
        group(
          'when wrappers resolve it while another first use is still uncommitted,',
          () {
            late UuidValue user;
            late UuidValue claimedNodeId;
            late bool resolversWaited;
            late List<UuidValue> resolved;
            late List<CrdtNode> owned;
            late UuidValue reopened;
            late UuidValue otherUserNodeId;

            setUpAll(() async {
              user = const Uuid().v7obj();
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
              otherUserNodeId = await (await wrapper()).db.currentNodeId(
                userId: const Uuid().v7obj(),
              );
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

            test('then another user resolves a distinct node.', () {
              expect(otherUserNodeId, isNot(claimedNodeId));
            });
          },
        );
      });

      for (final steadyState in [false, true]) {
        group(
          steadyState
              ? 'Given two users whose clocks and spaces already exist,'
              : 'Given two users acting for the first time,',
          () {
            group(
              'when one holds a write transaction while the other writes and merges '
              'in its own space,',
              () {
                late UuidValue first;
                late UuidValue second;
                late server.Unique firstRow;
                late server.Unique secondRow;
                late server.Unique mergedRow;
                late bool firstStillOpen;
                late int waitersWhileHeld;

                setUpAll(() async {
                  first = const Uuid().v7obj();
                  second = const Uuid().v7obj();
                  final firstWrapper = await wrapper();
                  final secondWrapper = await wrapper();

                  if (steadyState) {
                    for (final (session, user) in [
                      (firstWrapper, first),
                      (secondWrapper, second),
                    ]) {
                      await session.db.transactionForUser(
                        user,
                        (tx) => server.Unique.db.insertRow(
                          session,
                          server.Unique(name: 'prime'),
                          transaction: tx,
                        ),
                      );
                    }
                  }

                  firstRow = server.Unique(id: const Uuid().v7obj(), name: 'held');
                  secondRow = server.Unique(id: const Uuid().v7obj(), name: 'free');
                  mergedRow = server.Unique(id: const Uuid().v7obj(), name: 'merged');

                  final entered = Completer<void>();
                  final release = _releasedOnTearDown();
                  var holdingCompleted = false;
                  final holding = firstWrapper.db
                      .transactionForUser(first, (tx) async {
                        await server.Unique.db.insertRow(
                          firstWrapper,
                          firstRow,
                          transaction: tx,
                        );
                        entered.complete();
                        await release.future;
                      })
                      .whenComplete(() => holdingCompleted = true);
                  await entered.future;

                  await secondWrapper.db
                      .transactionForUser(
                        second,
                        (tx) => server.Unique.db.insertRow(
                          secondWrapper,
                          secondRow,
                          transaction: tx,
                        ),
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
                  waitersWhileHeld = await _lockWaiters(observer);
                  firstStillOpen = !holdingCompleted;

                  release.complete();
                  await holding;
                });

                test(
                  'then the second user finishes without waiting for the held clock.',
                  () {
                    expect(firstStillOpen, isTrue);
                    expect(waitersWhileHeld, 0);
                  },
                );

                test('then each user authored with its own local clock.', () async {
                  final firstNode = await userNode(first);
                  final secondNode = await userNode(second);
                  expect((await authorOf(firstRow.id!)).id, firstNode!.id);
                  expect((await authorOf(secondRow.id!)).id, secondNode!.id);
                  expect(firstNode.id, isNot(secondNode.id));
                });
              },
            );
          },
        );
      }

      group('Given one user with two wrappers holding stale cached clocks,', () {
        late UuidValue user;
        late OfflineSyncDatabaseSession firstWrapper;
        late OfflineSyncDatabaseSession secondWrapper;
        late server.Unique counter;

        Future<String> readCounter(
          OfflineSyncDatabaseSession session,
          Transaction tx,
        ) async => (await server.Unique.db.findById(
          session,
          counter.id!,
          transaction: tx,
        ))!.name;

        Future<void> writeCounter(
          OfflineSyncDatabaseSession session,
          Transaction tx,
          String value,
        ) => server.Unique.db.updateRow(
          session,
          counter.copyWith(name: value),
          columns: (t) => [t.name],
          transaction: tx,
        );

        setUpAll(() async {
          user = const Uuid().v7obj();
          firstWrapper = await wrapper();
          secondWrapper = await wrapper();
          counter = server.Unique(id: const Uuid().v7obj(), name: '10');

          await withClock(Clock.fixed(start), () async {
            await firstWrapper.db.transactionForUser(
              user,
              (tx) =>
                  server.Unique.db.insertRow(firstWrapper, counter, transaction: tx),
            );
            // Warm the second wrapper's cached space and clock at the same time.
            await secondWrapper.db.transactionForUser(
              user,
              (tx) => readCounter(secondWrapper, tx),
            );
          });
        });

        group(
          'when the first reads, the second starts, and the first commits a write '
          'with a newer wall clock,',
          () {
            late String firstRead;
            late String secondRead;
            late bool secondEnteredWhileHeld;
            late Hlc firstClock;
            late Hlc secondClock;
            late Hlc persistedClock;

            setUpAll(() async {
              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              final firstTransaction = withClock(
                Clock.fixed(start.add(const Duration(seconds: 10))),
                () => firstWrapper.db.transactionForUser(user, (tx) async {
                  firstRead = await readCounter(firstWrapper, tx);
                  entered.complete();
                  await release.future;
                  await writeCounter(firstWrapper, tx, '${int.parse(firstRead) + 1}');
                  firstClock = await fieldHlc(counter.id!, 'name', transaction: tx);
                }),
              );
              await entered.future;

              var secondEntered = false;
              final secondTransaction = withClock(
                Clock.fixed(start),
                () => secondWrapper.db.transactionForUser(user, (tx) async {
                  secondEntered = true;
                  secondRead = await readCounter(secondWrapper, tx);
                  await writeCounter(secondWrapper, tx, '${int.parse(secondRead) + 1}');
                }),
              );
              await _untilLockWait(observer);
              secondEnteredWhileHeld = secondEntered;

              release.complete();
              await Future.wait([firstTransaction, secondTransaction]);
              secondClock = await fieldHlc(counter.id!, 'name');
              persistedClock = await persistedUserClock(raw, user);
            });

            test('then the second callback waits for the first to commit.', () {
              expect(secondEnteredWhileHeld, isFalse);
            });

            test('then the second callback reads the committed value.', () async {
              expect(firstRead, '10');
              expect(secondRead, '11');
              final committed = await firstWrapper.db.transactionForUser(
                user,
                (tx) => readCounter(firstWrapper, tx),
              );
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
                await writeCounter(firstWrapper, tx, 'rolled back');
                written.complete();
                await release.future;
                throw StateError('roll back');
              }),
            ).then<Object?>((_) => null, onError: (Object error) => error);
            await written.future;

            final secondTransaction = withClock(
              Clock.fixed(start),
              () => secondWrapper.db.transactionForUser(user, (tx) async {
                await writeCounter(secondWrapper, tx, 'after rollback');
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
              (tx) => readCounter(firstWrapper, tx),
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

        group(
          'when an inbound merge for the same user starts during a transaction,',
          () {
            late bool mergeFinishedWhileHeld;
            late bool waited;

            setUpAll(() async {
              final entered = Completer<void>();
              final release = _releasedOnTearDown();
              final holding = firstWrapper.db.transactionForUser(user, (tx) async {
                await readCounter(firstWrapper, tx);
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
          'when one writes the space while the other writes it and a third user '
          'writes elsewhere,',
          () {
            late server.Unique firstRow;
            late server.Unique secondRow;
            late bool secondEnteredWhileHeld;
            late bool thirdFinishedWhileHeld;
            late bool grantFinishedWhileHeld;
            late bool sharedStillHeld;

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

            test('then each user keeps its own clock in the shared space.', () async {
              final firstNode = await userNode(first);
              final secondNode = await userNode(second);
              expect((await authorOf(firstRow.id!)).id, firstNode!.id);
              expect((await authorOf(secondRow.id!)).id, secondNode!.id);
              expect(firstNode.id, isNot(secondNode.id));
              expect(await userNode(shared), isNull);
            });
          },
        );

        group(
          "when one user's clock runs ahead and the other then edits that user's row,",
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

        group(
          'when a merge claims a unique value and a parent that a held transaction '
          'claims and deletes,',
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

      group('Given users acting across two shared spaces,', () {
        group(
          'when every user and space pair writes and merges concurrently while '
          'disjoint pairs hold their transactions,',
          () {
            late Object? failure;
            late bool disjointOverlapped;

            setUpAll(() async {
              final users = [const Uuid().v7obj(), const Uuid().v7obj()];
              final spaces = [
                for (var i = 0; i < 2; i++)
                  await OfflineSyncSpaces(raw).create(
                    grants: {
                      for (final user in users) user: OfflineSyncSpaceRole.readWrite,
                    },
                  ),
              ];

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

/// A barrier that the enclosing group releases when it ends.
///
/// A held transaction waits on it. If the arrangement fails before releasing
/// it, the group teardown still does, so the transaction cannot stay open and
/// block the server from stopping.
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

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}
