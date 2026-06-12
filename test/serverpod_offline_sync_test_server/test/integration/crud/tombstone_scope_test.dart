import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group(
    'Given two synced tables sharing the same UUID row id with a tombstone '
    'in only one of them,',
    () {
      late UuidValue sharedId;

      setUp(() async {
        sharedId = const Uuid().v7obj();

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(id: sharedId, name: 'shared id person'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Town.db.insertRow(
            session,
            Town(id: sharedId, name: 'shared id town'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteWhere(
            session,
            where: (t) => t.id.equals(sharedId),
            transaction: tx,
          ),
        );
      });

      test('when finding the deleted person, then it is hidden.', () async {
        expect(await Person.db.findById(session, sharedId), isNull);
      });

      test(
        'when finding the town, then the person tombstone does not mask it.',
        () async {
          expect(await Town.db.findById(session, sharedId), isNotNull);
        },
      );

      test(
        'when counting towns, then the person tombstone does not mask it.',
        () async {
          expect(await Town.db.count(session), 1);
        },
      );

      test(
        'when updating the town, then the person tombstone does not mask it.',
        () async {
          final town = await Town.db.findById(session, sharedId);
          final updated = await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Town.db.updateRow(
              session,
              town!.copyWith(name: 'renamed town'),
              transaction: tx,
            ),
          );

          expect(updated.name, 'renamed town');
        },
      );
    },
  );

  group('Given a row owned by one user on the same database,', () {
    late UuidValue rowId;
    late UuidValue otherUserId;
    late UuidValue otherUserNodeId;
    late Hlc otherUserInsertHlc;

    setUp(() async {
      rowId = const Uuid().v7obj();
      otherUserId = const Uuid().v7obj();
      otherUserNodeId = const Uuid().v7obj();

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(id: rowId, name: 'shared row'),
          transaction: tx,
        ),
      );

      otherUserInsertHlc = Hlc(DateTime.now().toUtc(), 0, otherUserNodeId);
      await session.db.mergeChanges(
        [
          CrdtMergeInsert(
            tableName: Person.t.tableName,
            uuidRowId: rowId,
            uuidNodeId: otherUserNodeId,
            hlcDatetime: otherUserInsertHlc.datetime,
            hlcCounter: otherUserInsertHlc.counter,
            data: Person(id: rowId, name: 'foreign row'),
          ),
        ],
        scopeId: otherUserId,
      );
    });

    test(
      'when finding without a user scope, then the row is returned exactly once.',
      () async {
        final rows = await Person.db.find(
          session,
          where: (t) => t.id.equals(rowId),
        );

        expect(rows, hasLength(1));
      },
    );

    test(
      'when another user merges an insert with the same row id, '
      'then no second CRDT tracker is recorded.',
      () async {
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.equals(rowId),
        );

        expect(crdtRows, hasLength(1));
      },
    );

    test(
      'when another user merges an insert with the same row id, '
      'then the owner row is not overwritten.',
      () async {
        final row = await Person.db.findById(testSession, rowId);

        expect(row, isNotNull);
        expect(row!.name, 'shared row');
      },
    );

    group('when the other user merges a delete for the row,', () {
      setUp(() async {
        await session.db.mergeChanges(
          [
            CrdtMergeDelete(
              tableName: Person.t.tableName,
              uuidRowId: rowId,
              uuidNodeId: otherUserNodeId,
              hlcDatetime: otherUserInsertHlc.datetime.add(const Duration(seconds: 1)),
              hlcCounter: 0,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
          scopeId: otherUserId,
        );
      });

      test(
        'then no tombstone is recorded.',
        () async {
          final tombstoneCount = await CrdtDataDeleted.db.count(
            session,
            where: (t) => t.row.uuidRowId.equals(rowId),
          );

          expect(tombstoneCount, 0);
        },
      );

      test(
        'then the owner can still read the row.',
        () async {
          final found = await session.db.transactionForUser(
            testCrdtUserId,
            (tx) => Person.db.findById(session, rowId, transaction: tx),
          );

          expect(found, isNotNull);
        },
      );
    });
  });
}
