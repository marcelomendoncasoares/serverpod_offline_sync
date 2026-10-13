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
  final directory = Directory(
    '${Directory.systemTemp.path}/persistent_savepoint_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(directory));

  tearDownAll(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL persistent transaction savepoints',
    rollbackDatabase: RollbackDatabase.disabled,
    serverDirectory: directory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
    (builder, _) {
      late Session raw;

      setUpAll(() {
        raw = builder.build();
      });

      group('Given two persistent-user wrappers sharing one PostgreSQL user clock,', () {
        late UuidValue user;
        late OfflineSyncDatabaseSession first;
        late OfflineSyncDatabaseSession second;
        late Person discarded;
        late Person later;
        late Person competing;
        late Clock now;

        setUpAll(() async {
          user = const Uuid().v7obj();
          first = OfflineSyncDatabaseSession.wraps(
            raw,
            syncTables: syncTables,
            persistentUserId: user,
          );
          second = OfflineSyncDatabaseSession.wraps(
            raw,
            syncTables: syncTables,
            persistentUserId: user,
          );
          await first.db.initialize();
          await second.db.initialize();

          discarded = Person(id: const Uuid().v7obj(), name: 'discarded');
          later = Person(id: const Uuid().v7obj(), name: 'outer later write');
          competing = Person(id: const Uuid().v7obj(), name: 'competing commit');
          now = Clock.fixed(DateTime.utc(2030));
        });

        group(
          'when a caller savepoint discards the first write before another transaction commits,',
          () {
            late Hlc checkpoint;
            late Hlc laterClock;
            late Hlc storedClock;
            late Hlc? spaceClock;
            late Person? discardedRow;
            late List<CrdtMergeChange> pending;

            setUpAll(() async {
              final rolledBack = Completer<void>();
              final resume = Completer<void>();

              final outer = withClock(now, () {
                return first.db.transaction<void>((tx) async {
                  final savepoint = await tx.createSavepoint();
                  await Person.db.insertRow(first, discarded, transaction: tx);
                  await savepoint.rollback();

                  rolledBack.complete();
                  await resume.future;
                  await Person.db.insertRow(first, later, transaction: tx);
                });
              });

              try {
                await rolledBack.future.timeout(const Duration(seconds: 10));
                // The competitor must finish while the outer callback is paused.
                // Rolling back the caller savepoint released the first write's locks.
                await withClock(now, () {
                  return second.db.transaction<void>((tx) async {
                    await Person.db.insertRow(
                      second,
                      Person(name: 'competing 1'),
                      transaction: tx,
                    );
                    await Person.db.insertRow(
                      second,
                      Person(name: 'competing 2'),
                      transaction: tx,
                    );
                    await Person.db.insertRow(second, competing, transaction: tx);
                  });
                }).timeout(const Duration(seconds: 10));
              } finally {
                resume.complete();
                await outer;
              }

              final records = await CrdtDataRow.db.find(
                raw,
                include: CrdtDataRow.include(node: CrdtNode.include()),
              );
              checkpoint = records
                  .singleWhere((row) => row.uuidRowId == competing.id)
                  .hlc;
              laterClock = records.singleWhere((row) => row.uuidRowId == later.id).hlc;
              storedClock = (await CrdtNode.db.find(raw)).single.lastHlc!;
              spaceClock = (await OfflineSyncSpace.db.find(raw)).single.lastHlc;
              discardedRow = await Person.db.findById(raw, discarded.id!);
              pending =
                  await OfflineSyncEngine(
                        syncTables: syncTables,
                        serializationManager: raw.db.serializationManager,
                      )
                      .collectPendingChanges(
                        raw,
                        checkpointsBySpaceUuid: {
                          user: [checkpoint],
                        },
                      )
                      .toList();
            });

            test(
              'then the later write advances beyond the competing committed clock.',
              () {
                expect(discardedRow, isNull);
                expect(laterClock.compareTo(checkpoint), greaterThan(0));
                expect(storedClock, laterClock);
                expect(spaceClock, laterClock);
              },
            );

            test(
              'then outbound sync includes the later row after the competing checkpoint.',
              () {
                expect(pending.map((change) => change.uuidRowId), [later.id]);
                expect(pending.single.uuidSpaceId, user);
              },
            );
          },
        );
      });
    },
  );
}
