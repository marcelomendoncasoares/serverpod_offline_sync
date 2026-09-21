import 'package:clock/clock.dart';
import 'package:serverpod_database/serverpod_database.dart' show Database;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a cached app clock and a newer insertion received through another wrapper,',
    () {
      late DateTime start;
      late SyncNode app;
      late SyncNode existingPeer;
      late SyncNode emptyPeer;
      late Unique remote;
      late Hlc insertionClock;

      setUpAll(() async {
        start = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        );

        app = await syncNode(await createAdditionalTestSession(), testSyncTables);
        existingPeer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        emptyPeer = await syncNode(await createAdditionalTestSession(), testSyncTables);

        remote = Unique(id: const Uuid().v7obj(), name: 'remote');

        await withClock(Clock.fixed(start), () async {
          await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(
              app.offlineSync,
              Unique(id: const Uuid().v7obj(), name: 'prime app clock'),
              transaction: tx,
            );
          });

          final insertion = CrdtMergeInsert(
            uuidSpaceId: testCrdtUserId,
            tableName: Unique.t.tableName,
            uuidRowId: remote.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: start.add(const Duration(seconds: 10)),
            hlcCounter: 0,
            data: remote,
          );
          await existingPeer.offlineSync.db.mergeChanges([
            insertion,
          ], spaceId: testCrdtUserId);
          await app.sync.wrapDatabase(app.raw.db).mergeChanges([
            insertion,
          ], spaceId: testCrdtUserId);
        });

        insertionClock = await rowHlc(remote.id!, databaseSession: app.offlineSync);
      });

      group(
        'when the app authors an edit and a new row and round-trips with both peers,',
        () {
          late CrdtDataField authored;
          late Hlc newRowClock;
          late Hlc persistedClock;
          late Unique? existingValue;
          late CrdtDataField? existingField;
          late Unique? bootstrapValue;
          late CrdtDataField? bootstrapField;
          late Unique? roundTripped;

          setUpAll(() async {
            final fresh = Unique(
              id: const Uuid().v7obj(),
              name: 'causally later insert',
            );

            await withClock(Clock.fixed(start), () async {
              await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
                await Unique.db.updateRow(
                  app.offlineSync,
                  remote.copyWith(name: 'local edit'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
                await Unique.db.insertRow(app.offlineSync, fresh, transaction: tx);
              });

              authored = (await CrdtDataField.db.findFirstRow(
                app.raw,
                where: (t) =>
                    t.row.uuidRowId.equals(remote.id) & t.column.name.equals('name'),
                include: CrdtDataField.include(node: CrdtNode.include()),
              ))!;
              newRowClock = await rowHlc(fresh.id!, databaseSession: app.offlineSync);

              final space = (await OfflineSyncSpace.db.findFirstRow(
                app.raw,
                where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
                include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
              ))!;
              persistedClock = space.currentNode!.lastHlc!;

              await pushChanges(app, existingPeer);
              await pushChanges(app, emptyPeer);

              existingValue = await Unique.db.findById(
                existingPeer.offlineSync,
                remote.id!,
              );
              existingField = await CrdtDataField.db.findFirstRow(
                existingPeer.raw,
                where: (t) =>
                    t.row.uuidRowId.equals(remote.id) & t.column.name.equals('name'),
                include: CrdtDataField.include(node: CrdtNode.include()),
              );

              bootstrapValue = await Unique.db.findById(
                emptyPeer.offlineSync,
                remote.id!,
              );
              bootstrapField = await CrdtDataField.db.findFirstRow(
                emptyPeer.raw,
                where: (t) =>
                    t.row.uuidRowId.equals(remote.id) & t.column.name.equals('name'),
                include: CrdtDataField.include(node: CrdtNode.include()),
              );

              await pushChanges(existingPeer, app);
              await pushChanges(emptyPeer, app);
              roundTripped = await Unique.db.findById(app.offlineSync, remote.id!);
            });
          });

          test('then the authored field clock follows the received row clock.', () {
            expect(authored.hlc.compareTo(insertionClock), greaterThan(0));
            expect(persistedClock.compareTo(authored.hlc), greaterThanOrEqualTo(0));
          });

          test('then an unrelated insertion also observes the received clock.', () {
            expect(newRowClock.compareTo(insertionClock), greaterThan(0));
            expect(persistedClock.compareTo(newRowClock), greaterThanOrEqualTo(0));
          });

          test(
            'then the existing peer accepts the local edit and its authored clock.',
            () {
              expect(existingValue?.name, 'local edit');
              expect(existingField?.hlc, authored.hlc);
              expect(roundTripped?.name, 'local edit');
            },
          );

          test(
            'then the empty bootstrap replica preserves the edit and its field clock.',
            () {
              expect(bootstrapValue?.name, 'local edit');
              expect(bootstrapField?.hlc, authored.hlc);
              expect(roundTripped?.name, 'local edit');
            },
          );
        },
      );
    },
  );

  group('Given two spaces sharing a node and a cached app clock,', () {
    late SyncNode app;
    late DateTime start;
    late Unique local;
    late Hlc receivedFieldClock;

    setUpAll(() async {
      app = await syncNode(await createAdditionalTestSession(), testSyncTables);

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );

      local = Unique(id: const Uuid().v7obj(), name: 'first space');
      final otherSpace = const Uuid().v7obj();
      final otherRow = Unique(id: const Uuid().v7obj(), name: 'second space');

      final remoteNode = const Uuid().v7obj();
      receivedFieldClock = Hlc(
        start.add(const Duration(seconds: 10)),
        41,
        remoteNode,
      );

      await withClock(Clock.fixed(start), () async {
        await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.insertRow(app.offlineSync, local, transaction: tx);
        });
        await app.offlineSync.db.transactionForUser(otherSpace, (tx) async {
          await Unique.db.insertRow(app.offlineSync, otherRow, transaction: tx);
        });

        await app.sync.wrapDatabase(app.raw.db).mergeChanges([
          CrdtMergeUpdate(
            uuidSpaceId: otherSpace,
            tableName: Unique.t.tableName,
            uuidRowId: otherRow.id!,
            uuidNodeId: remoteNode,
            hlcDatetime: receivedFieldClock.datetime,
            hlcCounter: receivedFieldClock.counter,
            columnName: 'name',
            value: 'remote second space',
          ),
        ], spaceId: otherSpace);
      });
    });

    group(
      'when the app edits its row after the other space receives a newer field,',
      () {
        late CrdtDataField authored;
        late Hlc persistedClock;

        setUpAll(() async {
          await withClock(Clock.fixed(start), () async {
            await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
              await Unique.db.updateRow(
                app.offlineSync,
                local.copyWith(name: 'after other space'),
                columns: (t) => [t.name],
                transaction: tx,
              );
            });
          });

          authored = (await CrdtDataField.db.findFirstRow(
            app.raw,
            where: (t) =>
                t.row.uuidRowId.equals(local.id) & t.column.name.equals('name'),
            include: CrdtDataField.include(node: CrdtNode.include()),
          ))!;

          final space = (await OfflineSyncSpace.db.findFirstRow(
            app.raw,
            where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
            include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
          ))!;
          persistedClock = space.currentNode!.lastHlc!;
        });

        test(
          'then the local field and persisted node observe the other space clock.',
          () {
            expect(authored.hlc.compareTo(receivedFieldClock), greaterThan(0));
            expect(persistedClock.compareTo(authored.hlc), greaterThanOrEqualTo(0));
          },
        );
      },
    );
  });

  group('Given two wrappers with cached clocks for the same database,', () {
    late SyncNode app;
    late OfflineSyncDatabaseSession second;
    late DateTime start;
    late Unique row;

    setUpAll(() async {
      app = await syncNode(await createAdditionalTestSession(), testSyncTables);
      second = OfflineSyncDatabaseSession.wraps(app.raw, syncTables: testSyncTables);
      await second.db.initialize();

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );
      row = Unique(id: const Uuid().v7obj(), name: 'first wrapper');

      await withClock(Clock.fixed(start), () async {
        await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.insertRow(app.offlineSync, row, transaction: tx);
        });

        await second.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.updateRow(
            second,
            row.copyWith(name: 'prime second wrapper'),
            columns: (t) => [t.name],
            transaction: tx,
          );
        });
      });
    });

    group(
      'when both wrappers write in the same transaction as wall time moves back,',
      () {
        late Hlc firstClock;
        late Hlc secondClock;
        late Hlc persistedClock;

        setUpAll(() async {
          await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await withClock(
              Clock.fixed(start.add(const Duration(seconds: 10))),
              () async {
                await Unique.db.updateRow(
                  app.offlineSync,
                  row.copyWith(name: 'future first wrapper'),
                  columns: (t) => [t.name],
                  transaction: tx,
                );
              },
            );
            firstClock = (await CrdtDataField.db.findFirstRow(
              app.raw,
              where: (t) =>
                  t.row.uuidRowId.equals(row.id) & t.column.name.equals('name'),
              include: CrdtDataField.include(node: CrdtNode.include()),
              transaction: tx,
            ))!.hlc;

            await withClock(Clock.fixed(start), () async {
              await Unique.db.updateRow(
                second,
                row.copyWith(name: 'later second wrapper'),
                columns: (t) => [t.name],
                transaction: tx,
              );
            });
            secondClock = (await CrdtDataField.db.findFirstRow(
              app.raw,
              where: (t) =>
                  t.row.uuidRowId.equals(row.id) & t.column.name.equals('name'),
              include: CrdtDataField.include(node: CrdtNode.include()),
              transaction: tx,
            ))!.hlc;
          });

          final space = (await OfflineSyncSpace.db.findFirstRow(
            app.raw,
            where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
            include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
          ))!;
          persistedClock = space.currentNode!.lastHlc!;
        });

        test(
          'then both wrappers advance one transaction-visible clock monotonically.',
          () {
            expect(secondClock.compareTo(firstClock), greaterThan(0));
            expect(persistedClock, secondClock);
          },
        );
      },
    );
  });

  group('Given a committed local deletion with no subsequent writes,', () {
    late SyncNode app;
    late DateTime start;
    late Hlc deletionClock;
    late Hlc persistedDeletionClock;

    setUpAll(() async {
      app = await syncNode(await createAdditionalTestSession(), testSyncTables);

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );
      final row = Unique(id: const Uuid().v7obj(), name: 'deleted');

      await withClock(Clock.fixed(start), () async {
        await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.insertRow(app.offlineSync, row, transaction: tx);
          await Unique.db.deleteRow(app.offlineSync, row, transaction: tx);
        });
      });

      deletionClock = (await CrdtDataDeleted.db.findFirstRow(
        app.raw,
        where: (t) => t.row.uuidRowId.equals(row.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      ))!.hlc;
      persistedDeletionClock = (await OfflineSyncSpace.db.findFirstRow(
        app.raw,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
        include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
      ))!.currentNode!.lastHlc!;
    });

    group('when a new wrapper inserts another row at the same wall time,', () {
      late Hlc newClock;

      setUpAll(() async {
        final second = OfflineSyncDatabaseSession.wraps(
          app.raw,
          syncTables: testSyncTables,
        );
        final row = Unique(id: const Uuid().v7obj(), name: 'after deletion');

        await withClock(Clock.fixed(start), () async {
          await second.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(second, row, transaction: tx);
          });
        });

        newClock = await rowHlc(row.id!, databaseSession: app.offlineSync);
      });

      test(
        'then the persisted deletion clock orders the new write after the tombstone.',
        () {
          expect(persistedDeletionClock, deletionClock);
          expect(newClock.compareTo(deletionClock), greaterThan(0));
        },
      );
    });
  });

  group('Given a persistent wrapper inside a caller-owned transaction,', () {
    late OfflineSyncDatabaseSession app;
    late Database rawDatabase;
    late DateTime start;
    late Hlc committedClock;

    setUpAll(() async {
      final raw = await createAdditionalTestSession();
      rawDatabase = raw.db;
      app = OfflineSyncDatabaseSession.wraps(
        raw,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await app.db.initialize();

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );
      final prime = Unique(
        id: const Uuid().v7obj(),
        name: 'committed before savepoint',
      );

      await withClock(Clock.fixed(start), () async {
        await Unique.db.insertRow(app, prime);
      });

      committedClock = await rowHlc(prime.id!, databaseSession: app);
    });

    group(
      'when the caller rolls back a savepoint containing a future-dated write,',
      () {
        late Hlc expectedNext;
        late Hlc nextClock;
        late Hlc persistedClock;
        late Unique? rolledBackRow;

        setUpAll(() async {
          final rolledBack = Unique(
            id: const Uuid().v7obj(),
            name: 'rollback savepoint',
          );
          final next = Unique(
            id: const Uuid().v7obj(),
            name: 'after savepoint rollback',
          );

          await rawDatabase.transaction((tx) async {
            final savepoint = await tx.createSavepoint();
            await withClock(
              Clock.fixed(start.add(const Duration(seconds: 30))),
              () async {
                await Unique.db.insertRow(app, rolledBack, transaction: tx);
              },
            );
            await savepoint.rollback();

            await withClock(Clock.fixed(start), () async {
              expectedNext = committedClock.increment();
              await Unique.db.insertRow(app, next, transaction: tx);
            });
          });

          nextClock = await rowHlc(next.id!, databaseSession: app);
          rolledBackRow = await Unique.db.findById(app, rolledBack.id!);

          final space = (await OfflineSyncSpace.db.findFirstRow(
            app,
            where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
            include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
          ))!;
          persistedClock = space.currentNode!.lastHlc!;
        });

        test(
          'then the next write reloads the clock surviving the caller rollback.',
          () {
            expect(rolledBackRow, isNull);
            expect(nextClock, expectedNext);
            expect(persistedClock, expectedNext);
          },
        );
      },
    );
  });

  group(
    'Given a client wrapper with a committed clock before explicit cancellation,',
    () {
      late OfflineSyncDatabaseSession app;
      late DateTime start;
      late Hlc committedClock;

      setUpAll(() async {
        app = OfflineSyncDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: testSyncTables,
          persistentUserId: testCrdtUserId,
        );
        await app.db.initialize();

        start = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
          isUtc: true,
        );
        final prime = Unique(id: const Uuid().v7obj(), name: 'before cancellation');

        await withClock(Clock.fixed(start), () async {
          await Unique.db.insertRow(app, prime);
        });

        committedClock = await rowHlc(prime.id!, databaseSession: app);
      });

      group(
        'when the caller cancels a future-dated transaction and then writes again,',
        () {
          String? returned;
          Object? failure;
          late Hlc persistedAfterCancel;
          late Hlc expectedNext;
          late Hlc nextClock;
          late Unique? cancelledRow;

          setUpAll(() async {
            final cancelled = Unique(id: const Uuid().v7obj(), name: 'cancelled');
            final next = Unique(id: const Uuid().v7obj(), name: 'after cancellation');

            try {
              returned = await withClock(
                Clock.fixed(start.add(const Duration(seconds: 30))),
                () => app.db.transaction((tx) async {
                  await Unique.db.insertRow(app, cancelled, transaction: tx);
                  await tx.cancel();
                  return 'cancelled';
                }),
              );
            } on Object catch (error) {
              failure = error;
            }

            cancelledRow = await Unique.db.findById(app, cancelled.id!);
            persistedAfterCancel = (await OfflineSyncSpace.db.findFirstRow(
              app,
              where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
              include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
            ))!.currentNode!.lastHlc!;

            await withClock(Clock.fixed(start), () async {
              expectedNext = committedClock.increment();
              await Unique.db.insertRow(app, next);
            });
            nextClock = await rowHlc(next.id!, databaseSession: app);
          });

          test(
            'then cancellation returns normally and discards the transaction clock.',
            () {
              expect(failure, isNull);
              expect(returned, 'cancelled');
              expect(cancelledRow, isNull);
              expect(persistedAfterCancel, committedClock);
              expect(nextClock, expectedNext);
            },
          );
        },
      );
    },
  );

  group('Given a wrapper with a committed local clock,', () {
    late SyncNode app;
    late DateTime start;
    late Hlc committedClock;

    setUpAll(() async {
      app = await syncNode(await createAdditionalTestSession(), testSyncTables);

      start = DateTime.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch,
        isUtc: true,
      );
      final prime = Unique(id: const Uuid().v7obj(), name: 'committed');

      await withClock(Clock.fixed(start), () async {
        await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
          await Unique.db.insertRow(app.offlineSync, prime, transaction: tx);
        });
      });

      committedClock = await rowHlc(prime.id!, databaseSession: app.offlineSync);
    });

    group('when a future-dated transaction rolls back before another local write,', () {
      late Object? failure;
      late Hlc afterRollback;
      late Hlc nextClock;
      late Hlc expectedNext;
      late Unique? rolledBackRow;

      setUpAll(() async {
        final rolledBack = Unique(id: const Uuid().v7obj(), name: 'rolled back');
        final next = Unique(id: const Uuid().v7obj(), name: 'after rollback');

        try {
          await withClock(
            Clock.fixed(start.add(const Duration(seconds: 30))),
            () async {
              await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
                await Unique.db.insertRow(app.offlineSync, rolledBack, transaction: tx);
                throw Exception('rollback clock');
              });
            },
          );
        } on Exception catch (error) {
          failure = error;
        }

        final space = (await OfflineSyncSpace.db.findFirstRow(
          app.raw,
          where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
          include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
        ))!;
        afterRollback = space.currentNode!.lastHlc!;
        rolledBackRow = await Unique.db.findById(app.offlineSync, rolledBack.id!);

        await withClock(Clock.fixed(start), () async {
          expectedNext = committedClock.increment();
          await app.offlineSync.db.transactionForUser(testCrdtUserId, (tx) async {
            await Unique.db.insertRow(app.offlineSync, next, transaction: tx);
          });
          nextClock = await rowHlc(next.id!, databaseSession: app.offlineSync);
        });
      });

      test(
        'then rollback leaves neither a persisted clock change nor a poisoned cache.',
        () {
          expect(failure, isA<Exception>());
          expect(rolledBackRow, isNull);
          expect(afterRollback, committedClock);
          expect(nextClock, expectedNext);
        },
      );
    });
  });
}
