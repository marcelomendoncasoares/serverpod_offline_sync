import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseUniqueViolationException;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  late OfflineSyncEngine offlineSync;

  setUp(() {
    offlineSync = OfflineSyncEngine(
      syncTables: testSyncTables,
      serializationManager: testSession.db.serializationManager,
    );
  });

  group('Given two new records with the same unique name, ', () {
    late Unique first;
    late Unique second;

    setUp(() {
      first = Unique(id: const Uuid().v7obj(), name: 'shared-name');
      second = Unique(id: const Uuid().v7obj(), name: 'shared-name');
    });

    group('when both records are inserted in one local batch, ', () {
      Object? failure;

      setUp(() async {
        failure = null;
        try {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insert(session, [first, second], transaction: tx),
          );
        } on Object catch (error) {
          failure = error;
        }
      });

      test(
        'then the database rejects the duplicate and retains neither record nor sync fact.',
        () async {
          expect(failure, isA<DatabaseUniqueViolationException>());
          expect(await Unique.db.find(session), isEmpty);
          expect(await _pendingInserts(offlineSync), isEmpty);
          expect(await _pendingUpdates(offlineSync), isEmpty);
          expect(await CrdtDataAttemptedValue.db.find(testSession), isEmpty);
        },
      );
    });
  });

  group(
    'Given two visible unique rows, ',
    () {
      late Unique first;
      late Unique second;

      setUp(() async {
        first = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'alice'),
            transaction: tx,
          ),
        );
        second = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'bob'),
            transaction: tx,
          ),
        );
      });

      group('when they swap names in one update,', () {
        setUp(() async {
          await session.db.transactionForUser(testCrdtUserId, (tx) {
            return Unique.db.update(
              session,
              [
                first.copyWith(name: 'bob'),
                second.copyWith(name: 'alice'),
              ],
              columns: (t) => [t.name],
              transaction: tx,
            );
          });
        });

        test("then each row holds the other row's former name.", () async {
          expect((await Unique.db.findById(session, first.id!))!.name, 'bob');
          expect((await Unique.db.findById(session, second.id!))!.name, 'alice');
        });
      });
    },
  );

  group(
    'Given a visible unique discriminator row and a newer remote insert that '
    'claims the same category and name, ',
    () {
      late UniqueDiscriminator winner;
      late UniqueDiscriminator loser;

      setUp(() async {
        winner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueDiscriminator.db.insertRow(
            session,
            UniqueDiscriminator(
              id: const Uuid().v7obj(),
              categoryId: 7,
              name: 'taken',
            ),
            transaction: tx,
          ),
        );
        loser = UniqueDiscriminator(
          id: const Uuid().v7obj(),
          categoryId: 7,
          name: 'taken',
        );
        final winnerHlc = await rowHlc(winner.id!);
        await session.db.mergeChanges(
          [
            CrdtMergeInsert(
              uuidSpaceId: testCrdtUserId,
              tableName: UniqueDiscriminator.t.tableName,
              uuidRowId: loser.id!,
              uuidNodeId: const Uuid().v7obj(),
              hlcDatetime: winnerHlc.datetime.add(const Duration(milliseconds: 1)),
              hlcCounter: 0,
              data: loser,
            ),
          ],
          spaceId: testCrdtUserId,
        );
      });

      test(
        'when they merge, '
        'then the loser keeps the discriminator and releases only the name.',
        () async {
          final rows = await UniqueDiscriminator.db.find(session);
          final winnerRow = rows.singleWhere((row) => row.id == winner.id);
          final loserRow = rows.singleWhere((row) => row.id == loser.id);

          expect(winnerRow.categoryId, 7);
          expect(winnerRow.name, 'taken');
          expect(loserRow.categoryId, 7);
          expect(loserRow.name, 'taken__conflict__${loser.id!.uuid}');
        },
      );
    },
  );

  group(
    'Given an independently authored unique loser merged with an occupied name, ',
    () {
      late Unique winner;
      late Unique loser;

      setUp(() async {
        winner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            transaction: tx,
          ),
        );
        loser = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        await mergeIndependentInsert(
          session,
          loser,
          space: testCrdtUserId,
          tables: [Unique.t],
        );
      });

      test(
        'when pending changes are collected, '
        'then the outbound insert carries the authored name.',
        () async {
          final domainLoser = await Unique.db.findById(session, loser.id!);
          expect(domainLoser!.name, 'shared-name__conflict__${loser.id!.uuid}');

          final attempted = await attemptedValue(
            rowId: loser.id!,
            columnName: Unique.t.name.columnName,
          );
          expect(attempted, isNotNull);
          expect(attempted!.value, 'shared-name');
          expect(attempted.projectionReason, CrdtProjectionReason.uniqueConflict);

          final insert = (await _pendingInserts(
            offlineSync,
          )).where((change) => change.uuidRowId == loser.id).single;
          expect((insert.data as Unique).name, 'shared-name');
        },
      );

      test(
        'when pending changes are collected, '
        'then projection does not emit an authored name update.',
        () async {
          final nameUpdates = (await _pendingUpdates(offlineSync)).where(
            (change) =>
                change.uuidRowId == loser.id &&
                change.columnName == Unique.t.name.columnName,
          );

          expect(nameUpdates, isEmpty);
        },
      );

      test(
        'when the domain row is read, '
        'then the winner still holds the authored name.',
        () async {
          expect((await Unique.db.findById(session, winner.id!))!.name, 'shared-name');
        },
      );

      test(
        'when a set-based write gives the loser a free name, '
        'then the write is authored and the released claim is not restored.',
        () async {
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.updateWhere(
              session,
              columnValues: (t) => [t.name('renamed')],
              where: (t) => t.id.equals(loser.id),
              transaction: tx,
            ),
          );

          expect((await Unique.db.findById(session, loser.id!))!.name, 'renamed');
          expect(
            await attemptedValue(
              rowId: loser.id!,
              columnName: Unique.t.name.columnName,
            ),
            isNull,
          );
          expect((await Unique.db.findById(session, winner.id!))!.name, 'shared-name');
        },
      );
    },
  );

  group(
    'Given a nullable unique loser whose claim was released to null, ',
    () {
      late UniqueNullable winner;
      late UniqueNullable loser;

      setUp(() async {
        winner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueNullable.db.insertRow(
            session,
            UniqueNullable(id: const Uuid().v7obj(), value: 1),
            transaction: tx,
          ),
        );
        loser = UniqueNullable(id: const Uuid().v7obj(), value: 1);
        await mergeIndependentInsert(
          session,
          loser,
          space: testCrdtUserId,
          tables: [UniqueNullable.t],
        );
      });

      test(
        'when a set-based write authors null on both rows, '
        'then the loser keeps the written null rather than reclaiming its value.',
        () async {
          // The loser displays the null its release wrote, so writing null is
          // an unchanged domain value. A narrowed write authors it anyway:
          // otherwise the freed claim behind it would win the reprojection the
          // winner's own null triggers, and reappear as a value nobody wrote.
          await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => UniqueNullable.db.updateWhere(
              session,
              columnValues: (t) => [t.value(null)],
              where: (t) => t.id.inSet(<UuidValue>{winner.id!, loser.id!}),
              transaction: tx,
            ),
          );

          expect((await UniqueNullable.db.findById(session, loser.id!))!.value, isNull);
          expect(
            await attemptedValue(
              rowId: loser.id!,
              columnName: UniqueNullable.t.value.columnName,
            ),
            isNull,
          );
          expect(
            (await UniqueNullable.db.findById(session, winner.id!))!.value,
            isNull,
          );
        },
      );
    },
  );

  group(
    'Given a cascade-hidden unique child that never had a local delete, ',
    () {
      late Person parent;
      late UniqueCascadeChild child;

      setUp(() async {
        parent = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'parent'),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, parent, transaction: tx),
        );
        child = UniqueCascadeChild(
          id: const Uuid().v7obj(),
          name: 'taken',
          parentId: parent.id,
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueCascadeChild.db.insertRow(
            session,
            child,
            transaction: tx,
          ),
        );
      });

      test(
        'when pending changes are collected, '
        'then the outbound insert carries the authored name.',
        () async {
          final hidden = await UniqueCascadeChild.db.findFirstRow(
            session,
            where: (t) => t.id.equals(child.id) & t.includeHiddenRows,
          );
          expect(hidden, isNotNull);
          expect(hidden!.name, 'taken__hidden__${child.id!.uuid}');

          final attempted = await attemptedValue(
            rowId: child.id!,
            columnName: UniqueCascadeChild.t.name.columnName,
          );
          expect(attempted, isNotNull);
          expect(attempted!.value, 'taken');
          expect(
            attempted.projectionReason,
            CrdtProjectionReason.hiddenUniqueRelease,
          );

          final insert = (await _pendingInserts(
            offlineSync,
          )).where((change) => change.uuidRowId == child.id).single;
          expect((insert.data as UniqueCascadeChild).name, 'taken');
        },
      );
    },
  );

  group(
    'Given a unique set-null child whose parent was deleted locally, ',
    () {
      late Person parent;
      late UniqueSetNullChild child;

      setUp(() async {
        parent = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'parent'),
            transaction: tx,
          ),
        );
        child = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueSetNullChild.db.insertRow(
            session,
            UniqueSetNullChild(
              id: const Uuid().v7obj(),
              name: 'child',
              parentId: parent.id,
            ),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, parent, transaction: tx),
        );
      });

      test(
        'when pending changes are collected, '
        'then the outbound child insert carries the authored null.',
        () async {
          final domainChild = await UniqueSetNullChild.db.findById(
            session,
            child.id!,
          );
          expect(domainChild!.parentId, isNull);

          // A locally initiated SET NULL is the observable consequence of the
          // delete the user just performed, so it is authored rather than
          // projected: the null is the authored value and nothing is retained.
          final attempted = await attemptedValue(
            rowId: child.id!,
            columnName: UniqueSetNullChild.t.parentId.columnName,
          );
          expect(attempted, isNull);

          final insert = (await _pendingInserts(
            offlineSync,
          )).where((change) => change.uuidRowId == child.id).single;
          expect((insert.data as UniqueSetNullChild).parentId, isNull);
        },
      );
    },
  );
}

Future<List<CrdtMergeChange>> _pendingChanges(OfflineSyncEngine offlineSync) =>
    offlineSync
        .collectPendingChanges(
          testSession,
          checkpointsBySpaceUuid: {testCrdtUserId: const []},
        )
        .toList();

Future<List<CrdtMergeInsert>> _pendingInserts(OfflineSyncEngine offlineSync) async =>
    (await _pendingChanges(offlineSync)).inserts.toList();

Future<List<CrdtMergeUpdate>> _pendingUpdates(OfflineSyncEngine offlineSync) async =>
    (await _pendingChanges(offlineSync)).updates.toList();
