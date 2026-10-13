import 'dart:async';

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Given a space clock with a persisted timestamp and a use callback,', () {
    late UuidValue nodeId;
    late Hlc lastHlc;
    late HlcManager manager;
    late int uses;

    setUp(() {
      nodeId = const Uuid().v7obj();
      lastHlc = Hlc(DateTime.utc(2026, 5, 10, 12), 7, nodeId);
      uses = 0;
      manager = HlcManager(
        42,
        CrdtNode(id: 9, uuidNodeId: nodeId, lastHlc: lastHlc),
        onUse: () => uses++,
      );
    });

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

    test(
      'when observing a newer timestamp of another node, '
      'then the clock adopts it under its own node and reports one use.',
      () {
        final other = Hlc(DateTime.utc(2026, 5, 10, 13), 2, const Uuid().v7obj());

        manager.observe(other);

        expect(manager.lastHlc, other.copyWith(nodeId: nodeId));
        expect(uses, 1);
      },
    );

    test(
      'when observing a newer timestamp of its own node, '
      'then the clock adopts it and reports one use.',
      () {
        final own = Hlc(DateTime.utc(2026, 5, 10, 13), 2, nodeId);

        manager.observe(own);

        expect(manager.lastHlc, own);
        expect(uses, 1);
      },
    );

    test(
      'when observing an older timestamp, '
      'then the clock stays unchanged and still reports one use.',
      () {
        manager.observe(Hlc(DateTime.utc(2026, 5, 10, 11), 9, const Uuid().v7obj()));

        expect(manager.lastHlc, lastHlc);
        expect(uses, 1);
      },
    );

    test(
      'when peeking the next timestamp, '
      'then the clock stays unchanged and reports no use.',
      () {
        final next = manager.peekNext();

        expect(next.compareTo(lastHlc), greaterThan(0));
        expect(manager.lastHlc, lastHlc);
        expect(uses, 0);
      },
    );

    test(
      'when incrementing the timestamp, '
      'then the clock advances and reports one use.',
      () {
        final next = manager.increment();

        expect(next.compareTo(lastHlc), greaterThan(0));
        expect(manager.lastHlc, next);
        expect(uses, 1);
      },
    );

    test(
      'when merging an older timestamp, '
      'then the clock stays unchanged and still reports one use.',
      () {
        manager.merge(Hlc(DateTime.utc(2026, 5, 10, 12), 1, const Uuid().v7obj()));

        expect(manager.lastHlc, lastHlc);
        expect(uses, 1);
      },
    );
  });

  group('Given two space managers sharing the same user clock,', () {
    late HlcManager personal;
    late HlcManager shared;

    setUp(() {
      final nodeId = const Uuid().v7obj();
      final node = CrdtNode(
        id: 9,
        uuidNodeId: nodeId,
        lastHlc: Hlc(DateTime.utc(2026, 5, 10, 12), 7, nodeId),
      );
      personal = HlcManager(1, node);
      shared = HlcManager(2, node);
    });

    test(
      'when the personal manager advances the clock, '
      'then the shared manager observes the same timestamp.',
      () {
        final first = personal.increment();

        expect(shared.lastHlc, first);
      },
    );

    test(
      'when the managers allocate successive timestamps, '
      'then both observe the later timestamp.',
      () {
        final first = personal.increment();
        final second = shared.increment();

        expect(second.compareTo(first), greaterThan(0));
        expect(personal.lastHlc, second);
        expect(shared.lastHlc, second);
      },
    );
  });

  group('Given a sync stream with complete framed sync batches,', () {
    final uuidSpaceId = const Uuid().v7obj();
    final rowId = const Uuid().v7obj();
    final requesterNodeId = const Uuid().v7obj();
    final row = CrdtNode(uuidNodeId: rowId);

    final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
      OfflineSyncMergeChunk(
        changes: [
          CrdtMergeInsert(
            uuidSpaceId: uuidSpaceId,
            hlcDatetime: DateTime.utc(2026, 5, 10, 12),
            hlcCounter: 1,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: requesterNodeId,
            data: row,
          ),
        ],
      ),
      OfflineSyncEndOfBatch(),
      OfflineSyncMergeChunk(
        changes: [
          CrdtMergeDelete(
            uuidSpaceId: uuidSpaceId,
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
      OfflineSyncEndOfBatch(),
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
          throwsA(isA<OfflineSyncStreamClosedException>()),
        );
      },
    );

    test(
      'when collecting the next batch, '
      'then batched merge changes are preserved.',
      () async {
        final singleBatchStream = Stream<OfflineSyncStreamEvent>.fromIterable([
          OfflineSyncMergeChunk(
            changes: [
              CrdtMergeInsert(
                uuidSpaceId: uuidSpaceId,
                hlcDatetime: DateTime.utc(2026, 5, 10, 16),
                hlcCounter: 1,
                tableName: 'person',
                uuidRowId: rowId,
                uuidNodeId: requesterNodeId,
                data: row,
              ),
              CrdtMergeDelete(
                uuidSpaceId: uuidSpaceId,
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
          OfflineSyncEndOfBatch(),
        ]);

        final batch = await StreamIterator(singleBatchStream).collectNextBatch();

        expect(batch, isNotNull);
        expect(batch!.changes, hasLength(2));
      },
    );
  });

  test(
    'Given a stream that starts with OfflineSyncEndOfBatch, '
    'when collecting the next batch, '
    'then an empty merge set is returned.',
    () async {
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncEndOfBatch(),
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
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncIdleTimeout(),
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
      final uuidSpaceId = const Uuid().v7obj();
      final rowId = const Uuid().v7obj();
      final requesterNodeId = const Uuid().v7obj();
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidSpaceId: uuidSpaceId,
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
        OfflineSyncIdleTimeout(),
        OfflineSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      final batch = await iterator.collectNextBatch();

      expect(batch, isNotNull);
      expect(batch!.changes.deletes, hasLength(1));
    },
  );

  test(
    'Given a stream with OfflineSyncClose before OfflineSyncEndOfBatch, '
    'when collecting the next batch, '
    'then changes are discarded and null is returned.',
    () async {
      final uuidSpaceId = const Uuid().v7obj();
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidSpaceId: uuidSpaceId,
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
        OfflineSyncClose(),
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
      const stream = Stream<OfflineSyncStreamEvent>.empty();
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
      const stream = Stream<OfflineSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      expect(
        iterator.collectNextBatch,
        throwsA(isA<OfflineSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given a stream that ends without OfflineSyncEndOfBatch, '
    'when collecting the next batch, '
    'then collection fails.',
    () async {
      final uuidSpaceId = const Uuid().v7obj();
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidSpaceId: uuidSpaceId,
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
        throwsA(isA<OfflineSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given a stream that ends after a merge batch without OfflineSyncEndOfBatch, '
    'when collecting the next batch allowing close before batch, '
    'then collection fails.',
    () async {
      final uuidSpaceId = const Uuid().v7obj();
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncMergeChunk(
          changes: [
            CrdtMergeDelete(
              uuidSpaceId: uuidSpaceId,
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
        throwsA(isA<OfflineSyncStreamClosedException>()),
      );
    },
  );

  test(
    'Given an empty stream, '
    'when expecting OfflineSyncConnect, '
    'then it throws a OfflineSyncStreamClosedException.',
    () async {
      const stream = Stream<OfflineSyncStreamEvent>.empty();
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<OfflineSyncConnect>(),
        throwsA(
          isA<OfflineSyncStreamClosedException>().having(
            (exception) => exception.toString(),
            'toString',
            'OfflineSyncStreamClosedException: sync stream closed before '
                '"OfflineSyncConnect" event.',
          ),
        ),
      );
    },
  );

  test(
    'Given a stream starting with OfflineSyncEndOfBatch, '
    'when expecting OfflineSyncConnect, '
    'then it throws a OfflineSyncUnexpectedEventException.',
    () async {
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncEndOfBatch(),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<OfflineSyncConnect>(),
        throwsA(
          isA<OfflineSyncUnexpectedEventException>()
              .having(
                (exception) => exception.received,
                'received',
                isA<OfflineSyncEndOfBatch>(),
              )
              .having(
                (exception) => exception.toString(),
                'toString',
                'OfflineSyncUnexpectedEventException: expected "OfflineSyncConnect", but '
                    'received "OfflineSyncEndOfBatch" instead.',
              ),
        ),
      );
    },
  );

  test(
    'Given a stream starting with OfflineSyncConnect, '
    'when expecting OfflineSyncClose, '
    'then it throws a OfflineSyncUnexpectedEventException.',
    () async {
      final stream = Stream<OfflineSyncStreamEvent>.fromIterable([
        OfflineSyncConnect(
          localNodeId: const Uuid().v7obj(),
          syncTablesHash: 'hash',
        ),
      ]);
      final iterator = StreamIterator(stream);

      expect(
        () => iterator.moveAndThrowIfNot<OfflineSyncClose>(),
        throwsA(
          isA<OfflineSyncUnexpectedEventException>()
              .having(
                (exception) => exception.received,
                'received',
                isA<OfflineSyncConnect>(),
              )
              .having(
                (exception) => exception.toString(),
                'toString',
                'OfflineSyncUnexpectedEventException: expected "OfflineSyncClose", but '
                    'received "OfflineSyncConnect" instead.',
              ),
        ),
      );
    },
  );
}
