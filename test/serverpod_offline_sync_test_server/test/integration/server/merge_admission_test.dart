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
          await entered.future;
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
          await entered.future;
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
          await entered.future;

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
  );
  return row;
}

/// Holds a real transaction after its first CRDT row insert.
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
    if (row is CrdtDataRow && transaction != null && !entered.isCompleted) {
      entered.complete();
      await release.future;
      if (fail) throw StateError('Fail after persisting merge metadata.');
    }
    return result;
  }
}
