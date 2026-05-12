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

  group('Given null-delimited merge change streams', () {
    final rowId = const Uuid().v7obj();
    final row = CrdtNode(userId: 1, uuidNodeId: rowId);

    final stream = Stream<CrdtMergeChange?>.fromIterable([
      CrdtMergeInsert(
        hlcDatetime: DateTime.utc(2026, 5, 10, 12),
        hlcCounter: 1,
        tableName: 'person',
        uuidRowId: rowId,
        uuidNodeId: const Uuid().v7obj(),
        data: row,
      ),
      null,
      CrdtMergeDelete(
        hlcDatetime: DateTime.utc(2026, 5, 10, 13),
        hlcCounter: 2,
        tableName: 'person',
        uuidRowId: rowId,
        uuidNodeId: const Uuid().v7obj(),
        isDeleted: true,
      ),
      null,
    ]);

    test(
      'when collecting batches then each null-delimited batch becomes a merge set.',
      () async {
        final batches = await stream.collectMergeSets().toList();

        expect(batches, hasLength(2));
        expect(batches.first.inserts, hasLength(1));
        expect(batches.first.deletes, isEmpty);
        expect(batches.last.inserts, isEmpty);
        expect(batches.last.deletes, hasLength(1));
      },
    );
  });

  test(
    'Given an empty stream when collecting batches then no merge sets are emitted.',
    () async {
      const stream = Stream<CrdtMergeChange?>.empty();

      final batches = await stream.collectMergeSets().toList();

      expect(batches, isEmpty);
    },
  );

  test(
    'Given a stream that ends without a null sentinel '
    'when collecting batches '
    'then no partial merge sets are emitted.',
    () async {
      final stream = Stream<CrdtMergeChange?>.fromIterable([
        CrdtMergeDelete(
          hlcDatetime: DateTime.utc(2026, 5, 10, 14),
          hlcCounter: 3,
          tableName: 'person',
          uuidRowId: const Uuid().v7obj(),
          uuidNodeId: const Uuid().v7obj(),
          isDeleted: true,
        ),
      ]);

      final batches = await stream.collectMergeSets().toList();

      expect(batches, isEmpty);
    },
  );
}
