import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:test/test.dart';

void main() {
  group('Given an HlcManager', () {
    test(
      'when converting it to a CrdtNode then the persisted node shape is preserved.',
      () {
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

        final node = manager.toCrdtNode();

        expect(node.id, 9);
        expect(node.userId, 42);
        expect(node.uuidNodeId, nodeId);
        expect(node.lastReceivedHlc, lastHlc);
      },
    );
  });

  group('Given null-delimited merge change streams', () {
    test(
      'when collecting batches then each null-delimited batch becomes a merge set.',
      () async {
        final firstNodeId = const Uuid().v7obj();
        final secondNodeId = const Uuid().v7obj();
        final rowId = const Uuid().v7obj();
        final row = CrdtNode(userId: 1, uuidNodeId: rowId);

        final batches = await Stream<CrdtMergeChange?>.fromIterable([
          CrdtMergeInsert(
            hlcDatetime: DateTime.utc(2026, 5, 10, 12),
            hlcCounter: 1,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: firstNodeId,
            data: row,
          ),
          null,
          CrdtMergeDelete(
            hlcDatetime: DateTime.utc(2026, 5, 10, 13),
            hlcCounter: 2,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: secondNodeId,
            isDeleted: true,
          ),
          null,
        ]).collectMergeSets().toList();

        expect(batches, hasLength(2));
        expect(batches.first.inserts, hasLength(1));
        expect(batches.first.deletes, isEmpty);
        expect(batches.last.inserts, isEmpty);
        expect(batches.last.deletes, hasLength(1));
      },
    );

    test(
      'when the stream is empty then no merge sets are emitted.',
      () async {
        final batches = await const Stream<CrdtMergeChange?>.empty()
            .collectMergeSets()
            .toList();

        expect(batches, isEmpty);
      },
    );

    test(
      'when the stream ends without a null sentinel then no partial merge set is emitted.',
      () async {
        final nodeId = const Uuid().v7obj();
        final rowId = const Uuid().v7obj();
        final batches = await Stream<CrdtMergeChange?>.fromIterable([
          CrdtMergeDelete(
            hlcDatetime: DateTime.utc(2026, 5, 10, 14),
            hlcCounter: 3,
            tableName: 'person',
            uuidRowId: rowId,
            uuidNodeId: nodeId,
            isDeleted: true,
          ),
        ]).collectMergeSets().toList();

        expect(batches, isEmpty);
      },
    );
  });
}
