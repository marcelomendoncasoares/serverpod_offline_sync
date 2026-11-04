import 'dart:async';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final directory = Directory(
    '${Directory.systemTemp.path}/offline_sync_cancel_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL cancellation lifecycle]',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: directory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 3,
      ),
    ),
    (sessions, _) {
      late Session observer;

      setUpAll(() async {
        observer = sessions.build();
        await observer.db.unsafeExecute(
          'CREATE TABLE cancellation_probe (id int PRIMARY KEY, value int)',
        );
      });

      Future<void> observeLock(int pid) async {
        final deadline = Stopwatch()..start();
        while (deadline.elapsed < const Duration(seconds: 10)) {
          final result = await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE pid = $pid AND wait_event_type = 'Lock'
  AND cardinality(pg_blocking_pids(pid)) > 0
''');
          if (result.first.first == 1) return;
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        throw StateError('Expected a database-observed lock waiter.');
      }

      group('Given a transaction waiting on a row held by another session,', () {
        late Completer<void> release;
        late Future<void> holder;
        late Session writer;

        setUpAll(() async {
          await observer.db.unsafeExecute(
            'INSERT INTO cancellation_probe VALUES (1, 0)',
          );
          writer = sessions.build();
          release = Completer<void>();
          final entered = Completer<void>();
          final holdingSession = sessions.build();
          holder = holdingSession.db.transaction((tx) async {
            await holdingSession.db.unsafeQuery(
              'SELECT * FROM cancellation_probe WHERE id = 1 FOR UPDATE',
              transaction: tx,
            );
            entered.complete();
            await release.future;
          });
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await holder;
          });
          await entered.future;
        });

        group('when native cancellation arrives before the blocker releases,', () {
          late bool rollbackFinishedWhileBlocked;
          late String callbackResult;
          late int persistedValue;

          setUpAll(() async {
            final entered = Completer<(Transaction, int)>();
            late Future<void> rollback;
            final waiting = writer.db.transaction((tx) async {
              final pid =
                  (await writer.db.unsafeQuery(
                        'SELECT pg_backend_pid()',
                        transaction: tx,
                      )).first.first
                      as int;
              entered.complete((tx, pid));
              await writer.db.unsafeExecute(
                'UPDATE cancellation_probe SET value = 1 WHERE id = 1',
                transaction: tx,
              );
              await rollback;
              return 'callback continued';
            });
            final (transaction, pid) = await entered.future;
            await observeLock(pid);

            var completed = false;
            rollback = transaction.cancel().then((_) => completed = true);
            await observeLock(pid);
            rollbackFinishedWhileBlocked = completed;

            release.complete();
            await holder;
            callbackResult = await waiting;
            await rollback;
            persistedValue =
                (await observer.db.unsafeQuery(
                      'SELECT value FROM cancellation_probe WHERE id = 1',
                    )).first.first
                    as int;
          });

          test('then cancellation still waits for the lock holder.', () {
            expect(rollbackFinishedWhileBlocked, isFalse);
          });

          test(
            'then the callback continues and can return success after rollback.',
            () {
              expect(callbackResult, 'callback continued');
              expect(persistedValue, 0);
            },
          );
        });
      });

      group('Given the final write has finished inside a cancellable transaction,', () {
        late OfflineSyncCancellation cancellation;
        late Completer<void> release;
        late Future<Object?> result;
        late int pid;
        late bool completed;

        setUpAll(() async {
          cancellation = OfflineSyncCancellation();
          release = Completer<void>();
          final entered = Completer<void>();
          final writer = sessions.build();
          completed = false;
          result = writer.db
              .transaction(
                (tx) => cancellation.run(tx, () async {
                  pid =
                      (await writer.db.unsafeQuery(
                            'SELECT pg_backend_pid()',
                            transaction: tx,
                          )).first.first
                          as int;
                  await writer.db.unsafeExecute(
                    'INSERT INTO cancellation_probe VALUES (2, 1)',
                    transaction: tx,
                  );
                  entered.complete();
                  await release.future;
                  return 'success';
                }),
              )
              .then<Object?>((value) => value, onError: (Object error) => error)
              .whenComplete(() => completed = true);
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await result;
          });
          await entered.future;
        });

        group('when cancellation arrives before the callback returns,', () {
          late Object? error;
          late int count;
          late int countWhileHeld;
          late bool completedWhileHeld;

          setUpAll(() async {
            cancellation.cancel();
            final deadline = Stopwatch()..start();
            while (true) {
              final state = await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE pid = $pid AND state = 'idle' AND xact_start IS NULL
''');
              if (state.first.first == 1) break;
              if (deadline.elapsed > const Duration(seconds: 10)) {
                throw TimeoutException(
                  'Cancellation did not roll back the held merge.',
                );
              }
            }
            countWhileHeld =
                (await observer.db.unsafeQuery(
                      'SELECT count(*)::int FROM cancellation_probe WHERE id = 2',
                    )).first.first
                    as int;
            completedWhileHeld = completed;
            release.complete();
            error = await result;
            count =
                (await observer.db.unsafeQuery(
                      'SELECT count(*)::int FROM cancellation_probe WHERE id = 2',
                    )).first.first
                    as int;
          });

          test(
            'then rollback finishes while the operation still awaits its callback.',
            () {
              expect(countWhileHeld, 0);
              expect(completedWhileHeld, isFalse);
            },
          );

          test('then the boundary reports cancellation and the write rolls back.', () {
            expect(error, isA<OfflineSyncCancelledException>());
            expect(count, 0);
          });
        });
      });

      group('Given a cancellable transaction has already committed,', () {
        late OfflineSyncCancellation cancellation;

        setUpAll(() async {
          cancellation = OfflineSyncCancellation();
          final writer = sessions.build();
          await writer.db.transaction(
            (tx) => cancellation.run(tx, () async {
              await writer.db.unsafeExecute(
                'INSERT INTO cancellation_probe VALUES (3, 1)',
                transaction: tx,
              );
            }),
          );
        });

        group('when its signal is cancelled and the pool serves a successor,', () {
          late List<int> persisted;

          setUpAll(() async {
            cancellation.cancel();
            final writer = sessions.build();
            await writer.db.transaction((tx) async {
              await writer.db.unsafeExecute(
                'INSERT INTO cancellation_probe VALUES (4, 1)',
                transaction: tx,
              );
            });
            persisted = (await observer.db.unsafeQuery(
              'SELECT id FROM cancellation_probe WHERE id IN (3, 4) ORDER BY id',
            )).map((row) => row.first as int).toList();
          });

          test('then the committed write and the successor remain intact.', () {
            expect(persisted, [3, 4]);
          });
        });
      });

      group('Given two suspended callbacks in a three-connection pool,', () {
        final release = Completer<void>();
        final transactions = <(Transaction, int)>[];
        final callbacks = <Future<void>>[];

        setUpAll(() async {
          for (var index = 0; index < 2; index++) {
            final entered = Completer<void>();
            final writer = sessions.build();
            callbacks.add(
              writer.db.transaction((tx) async {
                final pid =
                    (await writer.db.unsafeQuery(
                          'SELECT pg_backend_pid()',
                          transaction: tx,
                        )).first.first
                        as int;
                transactions.add((tx, pid));
                entered.complete();
                await release.future;
              }),
            );
            await entered.future;
          }
          addTearDown(() async {
            if (!release.isCompleted) release.complete();
            await Future.wait(callbacks);
          });
        });

        group('when an observer occupies the last slot and the first two roll back,', () {
          late int idleBackends;
          late bool successorFinishedWhileHeld;
          late int successorResult;

          setUpAll(() async {
            // This observer reserves the third and final connection while
            // inspecting the other two through an independent transaction.
            await observer.db.transaction((observerTx) async {
              await Future.wait([
                for (final (transaction, _) in transactions) transaction.cancel(),
              ]);
              var completed = false;
              final successor = observer.db.unsafeQuery('SELECT 42').then((rows) {
                completed = true;
                return rows.first.first as int;
              });
              final pids = transactions.map((entry) => entry.$2).join(', ');
              idleBackends =
                  (await observer.db.unsafeQuery('''
SELECT count(*)::int FROM pg_stat_activity
WHERE pid IN ($pids) AND xact_start IS NULL AND state = 'idle'
''', transaction: observerTx)).first.first
                      as int;
              successorFinishedWhileHeld = completed;

              release.complete();
              await Future.wait(callbacks);
              successorResult = await successor;
            });
          });

          test(
            'then rollback ends the database transactions without releasing the slots.',
            () {
              expect(idleBackends, 2);
              expect(successorFinishedWhileHeld, false);
            },
          );

          test('then the successor runs after the callbacks settle.', () {
            expect(successorResult, 42);
          });
        });
      });
    },
  );
}
