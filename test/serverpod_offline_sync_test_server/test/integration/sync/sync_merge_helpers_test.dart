import 'dart:async';

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

void main() {
  group('Given an HlcManager,', () {
    final userId = const Uuid().v7obj();
    final nodeId = const Uuid().v7obj();
    final lastHlc = Hlc(DateTime.utc(2026, 5, 10, 12), 7, nodeId);

    final manager = HlcManager.forScope(
      CrdtScope(
        id: 42,
        uuidScopeId: userId,
        currentNodeId: 9,
        currentNode: CrdtNode(
          id: 9,
          uuidNodeId: nodeId,
          lastHlc: lastHlc,
        ),
      ),
    );

    test(
      'when getting the node, '
      'then the persisted node shape is preserved.',
      () {
        final node = manager.getNode();

        expect(node.id, 9);
        expect(node.uuidNodeId, nodeId);
        expect(node.lastHlc, lastHlc);
      },
    );
  });

  group('Given a sync stream with complete framed sync batches,', () {
    final uuidScopeId = const Uuid().v7obj();
    final rowId = const Uuid().v7obj();
    final requesterNodeId = const Uuid().v7obj();
    final row = CrdtNode(uuidNodeId: rowId);

    final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
      CrdtSyncMergeChunk(
        changes: [
          CrdtMergeInsert(
            uuidScopeId: uuidScopeId,
            hlcDatetime: DateTime.utc(2026, 5, 10, 12),
            hlcCounter: 1,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: requesterNodeId,
            data: row,
          ),
        ],
      ),
      CrdtSyncEndOfBatch(),
      CrdtSyncMergeChunk(
        changes: [
          CrdtMergeDelete(
            uuidScopeId: uuidScopeId,
            hlcDatetime: DateTime.utc(2026, 5, 10, 13),
            hlcCounter: 2,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: requesterNodeId,
            clFlag: 2,
            reason: CrdtDataDeletedReason.userDelete,
          ),
        ],
      ),
      CrdtSyncEndOfBatch(),
    ]);

    test(
      'when collecting batches, '
      'then each framed batch becomes a merge set.',
      () async {
        final iterator = StreamIterator(stream);
        final firstBatch = await iterator.collectNextBatch();
        final secondBatch = await iterator.collectNextBatch();

        expect(firstBatch, isNotNull);
        expect(secondBatch, isNotNull);
        expect(firstBatch!.changes.inserts, hasLength(1));
        expect(firstBatch.changes.deletes, isEmpty);
        expect(secondBatch!.changes.inserts, isEmpty);
        expect(secondBatch.changes.deletes, hasLength(1));
        expect(
          iterator.collectNextBatch,
          throwsA(isA<CrdtSyncStreamClosedException>()),
        );
      },
    );

    test(
      'when collecting the next batch, '
      'then batched merge changes are preserved.',
      () async {
        final singleBatchStream = Stream<CrdtSyncStreamEvent>.fromIterable([
          CrdtSyncMergeChunk(
            changes: [
              CrdtMergeInsert(
                uuidScopeId: uuidScopeId,
                hlcDatetime: DateTime.utc(2026, 5, 10, 16),
                hlcCounter: 1,
                tableName: 'person',
                uuidRowId: rowId,
                uuidNodeId: requesterNodeId,
                data: row,
              ),
              CrdtMergeDelete(
                uuidScopeId: uuidScopeId,
                hlcDatetime: DateTime.utc(2026, 5, 10, 17),
                hlcCounter: 2,
                tableName: 'person',
                uuidRowId: rowId,
                uuidNodeId: requesterNodeId,
                clFlag: 2,
                reason: CrdtDataDeletedReason.userDelete,
              ),
            ],
          ),
          CrdtSyncEndOfBatch(),
        ]);

        final batch = await StreamIterator(singleBatchStream).collectNextBatch();

        expect(batch, isNotNull);
        expect(batch!.changes, hasLength(2));
      },
    );
  });

  test(
    'Given a stream that starts with CrdtSyncEndOfBatch, '
    'when collecting the next batch, '
    'then an empty merge set is returned.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isNotNull);
      expect(batch!.isEmpty, isTrue);
      expect(batch.changes, isEmpty);
    },
  );

  test(
    'Given a stream that is idle before a batch starts, '
    'when collecting the next batch, '
    'then an empty merge set is returned.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncIdleTimeout(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isNotNull);
      expect(batch!.isEmpty, isTrue);
      expect(batch.changes, isEmpty);
    },
  );

  test(
    'Given a stream that is idle after a merge batch, '
    'when collecting the next batch, '
    'then the idle event does not end the batch.',
    () async {
      final uuidScopeId = const Uuid().v7obj();
      final rowId = const Uuid().v7obj();
      final requesterNodeId = const Uuid().v7obj();
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidScopeId: uuidScopeId,
              hlcDatetime: DateTime.utc(2026, 5, 10, 14),
              hlcCounter: 3,
              tableName: 'person',
              uuidRowId: rowId,
              uuidNodeId: requesterNodeId,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
        ),
        CrdtSyncIdleTimeout(),
        CrdtSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isNotNull);
      expect(batch!.changes.deletes, hasLength(1));
    },
  );

  test(
    'Given a stream with CrdtSyncClose before CrdtSyncEndOfBatch, '
    'when collecting the next batch, '
    'then changes are discarded and null is returned.',
    () async {
      final uuidScopeId = const Uuid().v7obj();
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidScopeId: uuidScopeId,
              hlcDatetime: DateTime.utc(2026, 5, 10, 14),
              hlcCounter: 3,
              tableName: 'person',
              uuidRowId: const Uuid().v7obj(),
              uuidNodeId: const Uuid().v7obj(),
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
        ),
        CrdtSyncClose(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isNull);
    },
  );

  test(
    'Given an empty stream, '
    'when collecting the next batch allowing close before batch, '
    'then null is returned.',
    () async {
      const stream = Stream<CrdtSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch(allowCloseBeforeBatch: true);

      expect(batch, isNull);
    },
  );

  test(
    'Given an empty stream, '
    'when collecting the next batch, '
    'then collection fails.',
    () async {
      const stream = Stream<CrdtSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      expect(
        iterator.collectNextBatch,
        throwsA(isA<CrdtSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given a stream that ends without CrdtSyncEndOfBatch, '
    'when collecting the next batch, '
    'then collection fails.',
    () async {
      final uuidScopeId = const Uuid().v7obj();
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidScopeId: uuidScopeId,
              hlcDatetime: DateTime.utc(2026, 5, 10, 14),
              hlcCounter: 3,
              tableName: 'person',
              uuidRowId: const Uuid().v7obj(),
              uuidNodeId: const Uuid().v7obj(),
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
        ),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        iterator.collectNextBatch,
        throwsA(isA<CrdtSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given a stream that ends after a merge batch without CrdtSyncEndOfBatch, '
    'when collecting the next batch allowing close before batch, '
    'then collection fails.',
    () async {
      final uuidScopeId = const Uuid().v7obj();
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidScopeId: uuidScopeId,
              hlcDatetime: DateTime.utc(2026, 5, 10, 14),
              hlcCounter: 3,
              tableName: 'person',
              uuidRowId: const Uuid().v7obj(),
              uuidNodeId: const Uuid().v7obj(),
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ],
        ),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.collectNextBatch(allowCloseBeforeBatch: true),
        throwsA(isA<CrdtSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given an empty stream, '
    'when expecting CrdtSyncConnect, '
    'then it throws a CrdtSyncStreamClosedException.',
    () async {
      const stream = Stream<CrdtSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<CrdtSyncConnect>(),
        throwsA(
          isA<CrdtSyncStreamClosedException>().having(
            (exception) => exception.toString(),
            'toString',
            'CrdtSyncStreamClosedException: sync stream closed before '
                '"CrdtSyncConnect" event.',
          ),
        ),
      );
    },
  );

  test(
    'Given a stream starting with CrdtSyncEndOfBatch, '
    'when expecting CrdtSyncConnect, '
    'then it throws a CrdtSyncUnexpectedEventException.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<CrdtSyncConnect>(),
        throwsA(
          isA<CrdtSyncUnexpectedEventException>()
              .having(
                (exception) => exception.received,
                'received',
                isA<CrdtSyncEndOfBatch>(),
              )
              .having(
                (exception) => exception.toString(),
                'toString',
                'CrdtSyncUnexpectedEventException: expected "CrdtSyncConnect", but '
                    'received "CrdtSyncEndOfBatch" instead.',
              ),
        ),
      );
    },
  );

  test(
    'Given a stream starting with CrdtSyncConnect, '
    'when expecting CrdtSyncClose, '
    'then it throws a CrdtSyncUnexpectedEventException.',
    () async {
      final stream = Stream<CrdtSyncStreamEvent>.fromIterable([
        CrdtSyncConnect(
          localNodeId: const Uuid().v7obj(),
          syncTablesHash: 'hash',
        ),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<CrdtSyncClose>(),
        throwsA(
          isA<CrdtSyncUnexpectedEventException>()
              .having(
                (exception) => exception.received,
                'received',
                isA<CrdtSyncConnect>(),
              )
              .having(
                (exception) => exception.toString(),
                'toString',
                'CrdtSyncUnexpectedEventException: expected "CrdtSyncClose", but '
                    'received "CrdtSyncConnect" instead.',
              ),
        ),
      );
    },
  );
}
