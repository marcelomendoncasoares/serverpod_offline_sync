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
    'PostgreSQL user scopes',
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
          await session.db.prepareForUser(const Uuid().v7obj());
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
                session.db.prepareForUser(user),
                secondSession.db.prepareForUser(user),
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
              session.db.prepareForUser(const Uuid().v7obj()),
              secondSession.db.prepareForUser(const Uuid().v7obj()),
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

      group('Given a prepared personal space,', () {
        late UuidValue user;
        late OfflineSyncSpace prepared;

        setUp(() async {
          user = const Uuid().v7obj();
          await session.db.prepareForUser(user);
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
            final first = session.db.transaction((tx) async {
              await session.db.runForUser(user, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'first'),
                  transaction: tx,
                );
              }, transaction: tx);
              firstReady.complete();
              await releaseFirst.future;
            });
            await firstReady.future;
            final second = secondSession.db.transaction((tx) async {
              await secondSession.db.runForUser(user, (tx) async {
                await Person.db.insertRow(
                  secondSession,
                  Person(name: 'second'),
                  transaction: tx,
                );
              }, transaction: tx);
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
              session.db.transaction((tx) async {
                await session.db.runForUser(user, (tx) async {
                  await Person.db.insertRow(
                    session,
                    Person(name: 'discard'),
                    transaction: tx,
                  );
                }, transaction: tx);
                throw failure;
              }),
              throwsA(same(failure)),
            );
            await session.db.transaction((tx) async {
              await session.db.runForUser(user, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'retry'),
                  transaction: tx,
                );
              }, transaction: tx);
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
