import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/offline_sync_admission_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL merge admission]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: directory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
    (sessions, _) {
      late Session observer;

      setUpAll(() {
        observer = sessions.build();
      });

      OfflineSyncDatabaseContext context(int limit) => OfflineSyncDatabaseContext(
        syncTables: server.syncTables,
        serializationManager: observer.db.serializationManager,
        maxConcurrentMerges: limit,
      );

      Future<OfflineSyncDatabaseSession> wrapper(
        OfflineSyncDatabaseContext context, {
        Database? database,
      }) async {
        final session = OfflineSyncDatabaseSession(
          database ?? sessions.build().db,
          syncTables: server.syncTables,
          context: context,
        );
        await session.db.initialize();
        return session;
      }

      Future<int> lockWaiters() async {
        final result = await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE datname = current_database() AND wait_event_type = 'Lock'
''');
        return result.first.first as int;
      }

      group('Given a merge holding its user clock and space,', () {
        late UuidValue user;
        late UuidValue space;
        late OfflineSyncDatabaseContext shared;
        late Completer<void> release;
        late Future<server.Unique> holding;

        setUpAll(() async {
          user = const Uuid().v7obj();
          space = const Uuid().v7obj();
          shared = context(2);
          release = Completer<void>();
          final entered = Completer<void>();
          final session = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          holding = _merge(session, user: user, space: space);
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));
        });

        group('when overlapping merges and a disjoint merge arrive,', () {
          late List<int> queriesWhileQueued;
          late int waitersWhileHeld;
          late server.Unique? disjointWhileHeld;
          late List<server.Unique?> committed;

          setUpAll(() async {
            final counted = [
              QueryCountingDatabase(sessions.build().db),
              QueryCountingDatabase(sessions.build().db),
              QueryCountingDatabase(sessions.build().db),
            ];
            final samePair = await wrapper(shared, database: counted[0]);
            final sameUser = await wrapper(shared, database: counted[1]);
            final sameSpace = await wrapper(shared, database: counted[2]);
            final disjoint = await wrapper(shared);
            for (final database in counted) {
              database.queryCount = 0;
            }

            final queued = [
              _merge(samePair, user: user, space: space),
              _merge(sameUser, user: user, space: const Uuid().v7obj()),
              _merge(sameSpace, user: const Uuid().v7obj(), space: space),
            ];
            final freeRow = await _merge(disjoint, user: const Uuid().v7obj());
            disjointWhileHeld = await server.Unique.db.findById(observer, freeRow.id!);
            queriesWhileQueued = counted
                .map((database) => database.queryCount)
                .toList();
            waitersWhileHeld = await lockWaiters();

            release.complete();
            final rows = await Future.wait([holding, ...queued]);
            committed = await Future.wait([
              for (final row in rows) server.Unique.db.findById(observer, row.id!),
            ]);
          });

          test('then overlapping merges wait without issuing database queries.', () {
            expect(queriesWhileQueued, [0, 0, 0]);
            expect(waitersWhileHeld, 0);
          });

          test('then the disjoint merge commits while the first remains held.', () {
            expect(disjointWhileHeld, isNotNull);
          });

          test(
            'then every queued merge commits after the first releases its locks.',
            () {
              expect(committed, hasLength(4));
              expect(committed, everyElement(isNotNull));
            },
          );
        });
      });

      group('Given a single merge slot occupied by a transaction that will fail,', () {
        late UuidValue user;
        late OfflineSyncDatabaseContext shared;
        late Completer<void> release;
        late Future<Object?> failure;
        late server.Unique failedRow;

        setUpAll(() async {
          user = const Uuid().v7obj();
          shared = context(1);
          release = Completer<void>();
          final entered = Completer<void>();
          final session = await wrapper(
            shared,
            database: _HoldMerge(
              sessions.build().db,
              entered,
              release,
              fail: true,
            ),
          );
          failedRow = server.Unique(id: const Uuid().v7obj(), name: const Uuid().v4());
          failure = _merge(session, user: user, row: failedRow).then<Object?>(
            (_) => null,
            onError: (Object error) => error,
          );
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await failure;
          });
          await entered.future.timeout(const Duration(seconds: 10));
        });

        group('when a disjoint merge and a same-user merge queue behind it,', () {
          late List<int> queriesWhileQueued;
          late Object? error;
          late server.Unique? rolledBackRow;
          late CrdtDataRow? rolledBackMetadata;
          late List<server.Unique?> committed;

          setUpAll(() async {
            final disjointDb = QueryCountingDatabase(sessions.build().db);
            final sameUserDb = QueryCountingDatabase(sessions.build().db);
            final disjoint = await wrapper(shared, database: disjointDb);
            final sameUser = await wrapper(shared, database: sameUserDb);
            disjointDb.queryCount = 0;
            sameUserDb.queryCount = 0;

            final queued = [
              _merge(disjoint, user: const Uuid().v7obj()),
              _merge(sameUser, user: user),
            ];
            // A completed database round trip lets both calls reach admission.
            await observer.db.unsafeQuery('SELECT 1');
            queriesWhileQueued = [disjointDb.queryCount, sameUserDb.queryCount];

            release.complete();
            error = await failure;
            final rows = await Future.wait(queued);
            committed = await Future.wait([
              for (final row in rows) server.Unique.db.findById(observer, row.id!),
            ]);
            rolledBackRow = await server.Unique.db.findById(observer, failedRow.id!);
            rolledBackMetadata = await CrdtDataRow.db.findFirstRow(
              observer,
              where: (t) => t.uuidRowId.equals(failedRow.id),
            );
          });

          test('then the active limit also keeps disjoint work outside the pool.', () {
            expect(queriesWhileQueued, [0, 0]);
          });

          test(
            'then the failed merge rolls back its domain row and CRDT metadata.',
            () {
              expect(error, isA<StateError>());
              expect(rolledBackRow, isNull);
              expect(rolledBackMetadata, isNull);
            },
          );

          test('then the failure releases both the global slot and user queue.', () {
            expect(committed, hasLength(2));
            expect(committed, everyElement(isNotNull));
          });
        });
      });

      group('Given a sync stream paused after writing merge metadata,', () {
        late UuidValue user;
        late UuidValue source;
        late OfflineSyncDatabaseSession session;
        late Completer<void> release;
        late Completer<void> inboundCancelled;
        late StreamController<OfflineSyncStreamEvent> inbound;
        late StreamSubscription<OfflineSyncStreamEvent> subscription;
        late List<CrdtMergeChange> changes;
        late Hlc? clockBefore;
        late List<Object> streamErrors;

        setUpAll(() async {
          user = const Uuid().v7obj();
          source = const Uuid().v7obj();
          final shared = context(1);
          release = Completer<void>();
          final entered = Completer<void>();
          session = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          await session.db.currentNodeId(userId: user);
          clockBefore = (await CrdtNode.db.findFirstRow(
            observer,
            where: (t) => t.localUserUuid.equals(user),
          ))!.lastHlc;
          final rows = [
            server.Unique(id: const Uuid().v7obj(), name: const Uuid().v4()),
            server.Unique(id: const Uuid().v7obj(), name: const Uuid().v4()),
          ];
          changes = [
            for (final (index, row) in rows.indexed)
              CrdtMergeInsert(
                uuidSpaceId: user,
                tableName: server.Unique.t.tableName,
                uuidRowId: row.id!,
                uuidNodeId: source,
                hlcDatetime: DateTime.now().toUtc(),
                hlcCounter: index,
                data: row,
              ),
          ];
          final engine = OfflineSyncEngine(
            syncTables: server.syncTables,
            serializationManager: observer.db.serializationManager,
            databaseContext: shared,
          );
          inboundCancelled = Completer<void>();
          inbound = StreamController<OfflineSyncStreamEvent>(
            onCancel: () => inboundCancelled.complete(),
          );
          streamErrors = [];
          subscription = engine
              .sync(
                session,
                userId: user,
                inbound: inbound.stream,
                mode: OfflineSyncPeerMode.authoritative,
              )
              .listen(
                (_) {},
                onError: (Object error) => streamErrors.add(error),
              );
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await subscription.cancel();
            await inbound.close();
          });
          inbound
            ..add(
              OfflineSyncConnect(
                localNodeId: source,
                syncTablesHash: engine.currentSyncTablesHash,
                spaces: [
                  OfflineSyncSpaceGrant(
                    uuidSpaceId: user,
                    role: OfflineSyncSpaceRole.readWrite,
                  ),
                ],
              ),
            )
            ..add(OfflineSyncSinceRevision(uuidSpaceId: user, nodeCheckpoints: []))
            ..add(OfflineSyncReady())
            ..add(OfflineSyncMergeChunk(batchId: 1, changes: changes))
            ..add(
              OfflineSyncEndOfBatch(
                batchId: 1,
                finalForOnce: false,
                checkpoints: [
                  OfflineSyncSpaceCheckpoint(uuidSpaceId: user, revision: 1),
                ],
              ),
            );
          await entered.future.timeout(const Duration(seconds: 10));
        });

        group(
          'when the stream is cancelled and its pending database call returns,',
          () {
            late bool completedBeforeRelease;
            late List<server.Unique> rowsAfterCancel;
            late List<CrdtDataRow> metadataAfterCancel;
            late Hlc? clockAfterCancel;
            late Hlc? checkpointAfterCancel;
            late List<server.Unique> rowsAfterRetry;

            setUpAll(() async {
              var completed = false;
              final cancellation = subscription.cancel().then((_) {
                completed = true;
              });
              await inboundCancelled.future.timeout(const Duration(seconds: 10));
              completedBeforeRelease = completed;
              release.complete();
              await cancellation.timeout(const Duration(seconds: 10));

              final ids = changes.map((change) => change.uuidRowId).toSet();
              rowsAfterCancel = await server.Unique.db.find(
                observer,
                where: (t) => t.id.inSet(ids),
              );
              metadataAfterCancel = await CrdtDataRow.db.find(
                observer,
                where: (t) => t.uuidRowId.inSet(ids),
              );
              clockAfterCancel = (await CrdtNode.db.findFirstRow(
                observer,
                where: (t) => t.localUserUuid.equals(user),
              ))!.lastHlc;
              checkpointAfterCancel = (await OfflineSyncSpaceNode.db.findFirstRow(
                observer,
                where: (t) => t.node.uuidNodeId.equals(source),
              ))?.lastReceivedHlc;

              await session.db.mergeChanges(changes, userId: user);
              rowsAfterRetry = await server.Unique.db.find(
                observer,
                where: (t) => t.id.inSet(ids),
              );
            });

            test('then cancellation waits for the transaction to settle.', () {
              expect(completedBeforeRelease, isFalse);
              expect(streamErrors, isEmpty);
            });

            test(
              'then domain writes, metadata, clock and checkpoint roll back together.',
              () {
                expect(rowsAfterCancel, isEmpty);
                expect(metadataAfterCancel, isEmpty);
                expect(clockAfterCancel, clockBefore);
                expect(checkpointAfterCancel, isNull);
              },
            );

            test('then retrying the same batch commits every row.', () {
              expect(rowsAfterRetry, hasLength(2));
            });
          },
        );
      });

      test(
        'Given a queued merge behind a held transaction, '
        'when that merge is cancelled before admission, '
        'then it makes no database calls and releases its queue position.',
        () async {
          final user = const Uuid().v7obj();
          final shared = context(1);
          final entered = Completer<void>();
          final release = Completer<void>();
          final holdingSession = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          final counting = QueryCountingDatabase(sessions.build().db);
          final queuedSession = await wrapper(shared, database: counting);
          final holding = _merge(holdingSession, user: user);
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));
          counting.queryCount = 0;

          final cancellation = OfflineSyncCancellation();
          final queued =
              _merge(
                queuedSession,
                user: user,
                cancellation: cancellation,
              ).then<Object?>(
                (_) => null,
                onError: (Object error) => error,
              );
          await observer.db.unsafeQuery('SELECT 1');
          cancellation.cancel();
          final error = await queued.timeout(const Duration(seconds: 10));
          final cancelledCalls = counting.queryCount;
          release.complete();
          await holding;
          final retried = await _merge(queuedSession, user: user);
          final persisted = await server.Unique.db.findById(observer, retried.id!);

          expect(error, isA<OfflineSyncCancelledException>());
          expect(cancelledCalls, 0);
          expect(persisted, isNotNull);
        },
      );

      group('Given a held merge and queued work reserving another space,', () {
        late UuidValue firstUser;
        late UuidValue secondSpace;
        late OfflineSyncDatabaseSession cancelledSession;
        late OfflineSyncDatabaseSession disjointSession;
        late OfflineSyncDatabaseSession sameUserSession;
        late QueryCountingDatabase cancelledDatabase;
        late QueryCountingDatabase sameUserDatabase;
        late Completer<void> release;
        late Future<server.Unique> holding;

        setUpAll(() async {
          firstUser = const Uuid().v7obj();
          secondSpace = const Uuid().v7obj();
          final shared = context(2);
          final entered = Completer<void>();
          release = Completer<void>();
          final holder = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          cancelledDatabase = QueryCountingDatabase(sessions.build().db);
          sameUserDatabase = QueryCountingDatabase(sessions.build().db);
          cancelledSession = await wrapper(shared, database: cancelledDatabase);
          disjointSession = await wrapper(shared);
          sameUserSession = await wrapper(shared, database: sameUserDatabase);
          holding = _merge(holder, user: firstUser);
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));
          cancelledDatabase.queryCount = 0;
          sameUserDatabase.queryCount = 0;
        });

        group(
          'when the middle merge is cancelled before its predecessor releases,',
          () {
            late Object? cancellationError;
            late int cancelledQueries;
            late int sameUserQueriesBeforeRelease;
            late bool disjointFinishedBeforeRelease;
            late bool sameUserFinishedBeforeRelease;
            late server.Unique? disjointRow;
            late server.Unique? sameUserRow;

            setUpAll(() async {
              final cancellation = OfflineSyncCancellation();
              final cancelled =
                  _merge(
                    cancelledSession,
                    user: firstUser,
                    space: secondSpace,
                    cancellation: cancellation,
                  ).then<Object?>(
                    (_) => null,
                    onError: (Object error) => error,
                  );
              final disjoint = _merge(
                disjointSession,
                user: const Uuid().v7obj(),
                space: secondSpace,
              );
              var sameUserFinished = false;
              final sameUser =
                  _merge(
                    sameUserSession,
                    user: firstUser,
                    space: const Uuid().v7obj(),
                  ).then((row) {
                    sameUserFinished = true;
                    return row;
                  });
              // Initialized wrappers reach admission before this independent
              // database round trip completes; none needs initialization I/O.
              await observer.db.unsafeQuery('SELECT 1');
              cancellation.cancel();
              cancellationError = await cancelled.timeout(const Duration(seconds: 10));
              cancelledQueries = cancelledDatabase.queryCount;
              final independent = await disjoint.timeout(const Duration(seconds: 10));
              disjointFinishedBeforeRelease = !release.isCompleted;
              sameUserFinishedBeforeRelease = sameUserFinished;
              sameUserQueriesBeforeRelease = sameUserDatabase.queryCount;
              disjointRow = await server.Unique.db.findById(observer, independent.id!);

              release.complete();
              await holding;
              final dependent = await sameUser.timeout(const Duration(seconds: 10));
              sameUserRow = await server.Unique.db.findById(observer, dependent.id!);
            });

            test('then cancellation settles without issuing database calls.', () {
              expect(cancellationError, isA<OfflineSyncCancelledException>());
              expect(cancelledQueries, 0);
            });

            test('then the freed space allows its disjoint successor to commit.', () {
              expect(disjointFinishedBeforeRelease, isTrue);
              expect(disjointRow, isNotNull);
            });

            test(
              'then a successor sharing the held user still waits for that user.',
              () {
                expect(sameUserFinishedBeforeRelease, isFalse);
                expect(sameUserQueriesBeforeRelease, 0);
                expect(sameUserRow, isNotNull);
              },
            );
          },
        );
      });

      group('Given a full admission slot and two disjoint waiting merges,', () {
        late OfflineSyncDatabaseSession firstWaiting;
        late OfflineSyncDatabaseSession secondWaiting;
        late Completer<void> release;
        late Future<server.Unique> holding;

        setUpAll(() async {
          final shared = context(1);
          final entered = Completer<void>();
          release = Completer<void>();
          final holder = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          firstWaiting = await wrapper(shared);
          secondWaiting = await wrapper(shared);
          holding = _merge(holder, user: const Uuid().v7obj());
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));
        });

        group(
          'when the first capacity waiter is cancelled before the slot is freed,',
          () {
            late Object? cancellationError;
            late bool cancelledBeforeRelease;
            late server.Unique? committed;

            setUpAll(() async {
              final cancellation = OfflineSyncCancellation();
              final cancelled =
                  _merge(
                    firstWaiting,
                    user: const Uuid().v7obj(),
                    cancellation: cancellation,
                  ).then<Object?>(
                    (_) => null,
                    onError: (Object error) => error,
                  );
              final successor = _merge(secondWaiting, user: const Uuid().v7obj());
              await observer.db.unsafeQuery('SELECT 1');
              cancellation.cancel();
              cancellationError = await cancelled.timeout(const Duration(seconds: 10));
              cancelledBeforeRelease = !release.isCompleted;
              release.complete();
              await holding;
              final row = await successor.timeout(const Duration(seconds: 10));
              committed = await server.Unique.db.findById(observer, row.id!);
            });

            test(
              'then cancellation finishes while the active transaction stays held.',
              () {
                expect(cancellationError, isA<OfflineSyncCancelledException>());
                expect(cancelledBeforeRelease, isTrue);
              },
            );

            test('then the next waiter receives the slot and commits.', () {
              expect(committed, isNotNull);
            });
          },
        );
      });

      test(
        'Given an authorized upload queued behind global merge capacity, '
        'when its shared-space grant is revoked before admission, '
        'then the transaction rejects it without acknowledging or storing the row.',
        () async {
          final user = const Uuid().v7obj();
          final space = await OfflineSyncSpaceManager(
            observer,
          ).getOrCreate(const Uuid().v7obj());
          final member = await OfflineSyncSpaceMember.db.insertRow(
            observer,
            OfflineSyncSpaceMember(
              spaceId: space.id!,
              userUuid: user,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          );
          final shared = context(1);
          final entered = Completer<void>();
          final release = Completer<void>();
          final holder = await wrapper(
            shared,
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          final holding = _merge(holder, user: const Uuid().v7obj());
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));
          final engine = OfflineSyncEngine(
            syncTables: server.syncTables,
            serializationManager: observer.db.serializationManager,
            databaseContext: shared,
          );
          final inbound = StreamController<OfflineSyncStreamEvent>();
          final queued = Completer<void>();
          final finished = Completer<void>();
          final acknowledgements = <OfflineSyncCommitted>[];
          Object? error;
          final subscription = OfflineSyncDiagnostics.run(
            (event) {
              if (event['name'] == 'queue.join' && !queued.isCompleted) {
                queued.complete();
              }
            },
            () => engine
                .sync(
                  sessions.build(),
                  userId: user,
                  inbound: inbound.stream,
                  mode: OfflineSyncPeerMode.authoritative,
                )
                .listen(
                  (event) {
                    if (event is OfflineSyncCommitted) acknowledgements.add(event);
                  },
                  onError: (Object failure) => error = failure,
                  onDone: finished.complete,
                ),
          );
          addTearDown(() async {
            await subscription.cancel();
            if (!inbound.isClosed) unawaited(inbound.close());
          });
          final row = server.Unique(
            id: const Uuid().v7obj(),
            name: 'revoked while queued',
          );

          inbound
            ..add(
              OfflineSyncConnect(
                localNodeId: const Uuid().v7obj(),
                syncTablesHash: engine.currentSyncTablesHash,
                spaces: const [],
              ),
            )
            ..add(OfflineSyncSinceRevision(uuidSpaceId: user, nodeCheckpoints: []))
            ..add(
              OfflineSyncSinceRevision(
                uuidSpaceId: space.uuidSpaceId,
                nodeCheckpoints: [],
              ),
            )
            ..add(OfflineSyncReady())
            ..add(
              OfflineSyncMergeChunk(
                batchId: 1,
                changes: [
                  CrdtMergeInsert(
                    uuidSpaceId: space.uuidSpaceId,
                    tableName: server.Unique.t.tableName,
                    uuidRowId: row.id!,
                    uuidNodeId: const Uuid().v7obj(),
                    hlcDatetime: DateTime.utc(2026),
                    hlcCounter: 0,
                    data: row,
                  ),
                ],
              ),
            )
            ..add(
              OfflineSyncEndOfBatch(
                batchId: 1,
                finalForOnce: false,
                checkpoints: [
                  OfflineSyncSpaceCheckpoint(
                    uuidSpaceId: space.uuidSpaceId,
                    revision: 1,
                  ),
                ],
              ),
            );
          await queued.future.timeout(const Duration(seconds: 10));
          await OfflineSyncSpaceMember.db.deleteRow(observer, member);
          release.complete();
          await holding;
          await finished.future.timeout(const Duration(seconds: 10));
          final persisted = await server.Unique.db.findById(observer, row.id!);
          final violations = await OfflineSyncIntegrityViolation.db.find(
            observer,
            where: (t) => t.uuidRowId.equals(row.id),
          );

          expect(error, isA<OfflineSyncIntegrityViolationException>());
          expect(persisted, isNull);
          expect(acknowledgements, isEmpty);
          expect(violations.single.type, OfflineSyncViolationType.unauthorizedWrite);
        },
      );

      test(
        'Given independent admission contexts sharing a database, '
        'when they merge for the same user, '
        'then PostgreSQL still serializes their transactions.',
        () async {
          final user = const Uuid().v7obj();
          final entered = Completer<void>();
          final release = Completer<void>();
          final first = await wrapper(
            context(2),
            database: _HoldMerge(sessions.build().db, entered, release),
          );
          final second = await wrapper(context(2));
          final holding = _merge(first, user: user);
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holding;
          });
          await entered.future.timeout(const Duration(seconds: 10));

          var secondFinished = false;
          final merging = _merge(second, user: user).whenComplete(() {
            secondFinished = true;
          });
          final deadline = Stopwatch()..start();
          while (await lockWaiters() == 0) {
            if (deadline.elapsed > const Duration(seconds: 10)) {
              throw TimeoutException('The second merge did not wait for its lock.');
            }
          }
          final finishedWhileHeld = secondFinished;
          release.complete();
          final rows = await Future.wait([holding, merging]);
          final persisted = await server.Unique.db.find(
            observer,
            where: (t) => t.id.inSet(rows.map((row) => row.id!).toSet()),
          );

          expect(finishedWhileHeld, isFalse);
          expect(persisted, hasLength(2));
        },
      );
    },
  );
}

Future<server.Unique> _merge(
  OfflineSyncDatabaseSession session, {
  required UuidValue user,
  UuidValue? space,
  server.Unique? row,
  OfflineSyncCancellation? cancellation,
}) async {
  row ??= server.Unique(id: const Uuid().v7obj(), name: const Uuid().v4());
  await session.db.mergeChanges(
    [
      CrdtMergeInsert(
        uuidSpaceId: space ?? user,
        tableName: server.Unique.t.tableName,
        uuidRowId: row.id!,
        uuidNodeId: const Uuid().v7obj(),
        hlcDatetime: DateTime.now().toUtc(),
        hlcCounter: 0,
        data: row,
      ),
    ],
    userId: user,
    spaceId: space,
    cancellation: cancellation,
  );
  return row;
}

/// Holds a real transaction after its first persisted CRDT row metadata.
class _HoldMerge extends QueryCountingDatabase {
  // The delegate parameter belongs to the proxy's private implementation.
  // ignore: matching_super_parameters
  _HoldMerge(super.database, this.entered, this.release, {this.fail = false});

  final Completer<void> entered;
  final Completer<void> release;
  final bool fail;

  @override
  Future<T> insertRow<T extends TableRow>(T row, {Transaction? transaction}) async {
    final result = await super.insertRow(row, transaction: transaction);
    await _hold(row is CrdtDataRow, transaction);
    return result;
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    final result = await super.insert(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
    await _hold(rows.any((row) => row is CrdtDataRow), transaction);
    return result;
  }

  Future<void> _hold(bool wroteMetadata, Transaction? transaction) async {
    if (wroteMetadata && transaction != null && !entered.isCompleted) {
      entered.complete();
      await release.future;
      if (fail) throw StateError('Fail after persisting merge metadata.');
    }
  }
}
