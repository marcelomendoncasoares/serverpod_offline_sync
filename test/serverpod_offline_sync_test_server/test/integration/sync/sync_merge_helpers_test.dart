import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Given an HlcManager', () {
    final userId = const Uuid().v7obj();
    final nodeId = const Uuid().v7obj();
    final lastHlc = Hlc(DateTime.utc(2026, 5, 10, 12), 7, nodeId);

    final manager = HlcManager.forUser(
      CrdtUser(
        id: 42,
        uuidUserId: userId,
        currentNodeId: 9,
        currentNode: CrdtNode(
          id: 9,
          userId: 42,
          uuidNodeId: nodeId,
          lastReceivedHlc: lastHlc,
        ),
      ),
    );

    test(
      'when getting the node then the persisted node shape is preserved.',
      () {
        final node = manager.getNode();

        expect(node.id, 9);
        expect(node.userId, 42);
        expect(node.uuidNodeId, nodeId);
        expect(node.lastReceivedHlc, lastHlc);
      },
    );
  });

  group('Given a sync stream with complete framed sync batches', () {
    final rowId = const Uuid().v7obj();
    final requesterNodeId = const Uuid().v7obj();
    final row = CrdtNode(userId: 1, uuidNodeId: rowId);

    final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
      CrdtSyncMergeChange(
        change: CrdtMergeInsert(
          hlcDatetime: DateTime.utc(2026, 5, 10, 12),
          hlcCounter: 1,
          tableName: 'person',
          uuidRowId: rowId,
          uuidNodeId: requesterNodeId,
          data: row,
        ),
      ),
      CrdtSyncEndOfBatch(),
      CrdtSyncMergeChange(
        change: CrdtMergeDelete(
          hlcDatetime: DateTime.utc(2026, 5, 10, 13),
          hlcCounter: 2,
          tableName: 'person',
          uuidRowId: rowId,
          uuidNodeId: requesterNodeId,
          isDeleted: true,
        ),
      ),
      CrdtSyncEndOfBatch(),
    ]);

    test(
      'when collecting batches then each framed batch becomes a merge set.',
      () async {
        final iterator = StreamIterator(stream);
        final firstBatch = await iterator.collectNextBatch();
        final secondBatch = await iterator.collectNextBatch();

        expect(firstBatch.inserts, hasLength(1));
        expect(firstBatch.deletes, isEmpty);
        expect(secondBatch.inserts, isEmpty);
        expect(secondBatch.deletes, hasLength(1));
        expect(iterator.collectNextBatch, throwsA(isA<StateError>()));
      },
    );

    test(
      'when collecting the next batch then merge changes are preserved.',
      () async {
        final singleBatchStream = Stream<CrdtSyncStreamEvent>.fromIterable([
          CrdtSyncMergeChange(
            change: CrdtMergeInsert(
              hlcDatetime: DateTime.utc(2026, 5, 10, 16),
              hlcCounter: 1,
              tableName: 'person',
              uuidRowId: rowId,
              uuidNodeId: requesterNodeId,
              data: row,
            ),
          ),
          CrdtSyncEndOfBatch(),
        ]);

        final batch = await StreamIterator(singleBatchStream).collectNextBatch();

        expect(batch, hasLength(1));
      },
    );
  });

  test(
    'Given an empty stream when collecting the next batch then collection fails.',
    () async {
      const stream = Stream<CrdtSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      expect(iterator.collectNextBatch, throwsA(isA<StateError>()));
    },
  );

  test(
    'Given a stream that ends without CrdtSyncEndOfBatch '
    'when collecting the next batch '
    'then collection fails.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncMergeChange(
          change: CrdtMergeDelete(
            hlcDatetime: DateTime.utc(2026, 5, 10, 14),
            hlcCounter: 3,
            tableName: 'person',
            uuidRowId: const Uuid().v7obj(),
            uuidNodeId: const Uuid().v7obj(),
            isDeleted: true,
          ),
        ),
      ]);
      final iterator = StreamIterator(stream);

      expect(iterator.collectNextBatch, throwsA(isA<StateError>()));
    },
  );

  test(
    'Given a stream that starts with CrdtSyncEndOfBatch '
    'when collecting the next batch '
    'then an empty merge set is returned.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isEmpty);
    },
  );
}
