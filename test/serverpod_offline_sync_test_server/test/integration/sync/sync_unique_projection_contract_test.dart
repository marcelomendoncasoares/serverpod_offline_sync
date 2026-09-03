import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

void main() {
  initTestClientSession();

  late CrdtSync crdtSync;

  setUp(() {
    crdtSync = CrdtSync(
      syncTables: testSyncTables,
      serializationManager: testSession.db.serializationManager,
    );
  });

  group(
    'Given two local unique inserts that claim the same name in one write, ',
    () {
      late Unique first;
      late Unique second;

      setUp(() async {
        first = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        second = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        await session.db.transactionForUser(testCrdtUserId, (tx) {
          return Unique.db.insert(session, [first, second], transaction: tx);
        });
      });

      test(
        'when the insert completes, '
        'then one row keeps the name and the other is released without failing.',
        () async {
          final rows = await Unique.db.find(session);
          final names = {for (final row in rows) row.id: row.name};

          expect(rows, hasLength(2));
          expect(names.values, contains('shared-name'));
          expect(
            names.values,
            contains(matches(RegExp(r'^shared-name__conflict__[0-9a-f-]+$'))),
          );
        },
      );
    },
  );

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
              uuidScopeId: testCrdtUserId,
              tableName: UniqueDiscriminator.t.tableName,
              uuidRowId: loser.id!,
              uuidNodeId: const Uuid().v7obj(),
              hlcDatetime: winnerHlc.datetime.add(const Duration(milliseconds: 1)),
              hlcCounter: 0,
              data: loser,
            ),
          ],
          scopeId: testCrdtUserId,
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
    'Given a locally inserted unique loser whose domain name was released, ',
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
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(session, loser, transaction: tx),
        );
      });

      test(
        'when pending changes are collected, '
        'then the outbound insert carries the authored name.',
        () async {
          final domainLoser = await Unique.db.findById(session, loser.id!);
          expect(domainLoser!.name, 'shared-name__conflict__${loser.id!.uuid}');

          final attempted = await attemptedValue(rowId: loser.id!, columnName: Unique.t.name.columnName);
          expect(attempted, isNotNull);
          expect(attempted!.value, 'shared-name');
          expect(attempted.projectionReason, CrdtProjectionReason.uniqueConflict);

          final insert = (await _pendingInserts(crdtSync))
              .where((change) => change.uuidRowId == loser.id)
              .single;
          expect((insert.data as Unique).name, 'shared-name');
        },
      );

      test(
        'when pending changes are collected, '
        'then projection does not emit an authored name update.',
        () async {
          final nameUpdates = (await _pendingUpdates(crdtSync)).where(
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

          final insert = (await _pendingInserts(crdtSync))
              .where((change) => change.uuidRowId == child.id)
              .single;
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

          final insert = (await _pendingInserts(crdtSync))
              .where((change) => change.uuidRowId == child.id)
              .single;
          expect((insert.data as UniqueSetNullChild).parentId, isNull);
        },
      );
    },
  );
}

Future<List<CrdtMergeChange>> _pendingChanges(CrdtSync crdtSync) => crdtSync
    .collectPendingChanges(
      testSession,
      checkpointsByScopeUuid: {testCrdtUserId: const []},
    )
    .toList();

Future<List<CrdtMergeInsert>> _pendingInserts(CrdtSync crdtSync) async =>
    (await _pendingChanges(crdtSync)).inserts.toList();

Future<List<CrdtMergeUpdate>> _pendingUpdates(CrdtSync crdtSync) async =>
    (await _pendingChanges(crdtSync)).updates.toList();
