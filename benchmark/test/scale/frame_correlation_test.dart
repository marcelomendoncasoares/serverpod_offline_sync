import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_benchmark/scale/diagnostics.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given two traces receiving different rounds of the same updated row, '
    'when numbered frames and nested merges are observed, '
    'then round identities and shared timestamps distinguish their work.',
    () async {
      final records = <Map<String, dynamic>>[];
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
      final first = SyncTrace(
        side: 'server',
        requestId: 'first',
        runId: 'correlation',
        userId: id.toString(),
        deviceId: '0',
        once: false,
        streamDetails: true,
        measurePayloadBytes: false,
        output: records.add,
      );
      final second = SyncTrace(
        side: 'server',
        requestId: 'second',
        runId: 'correlation',
        userId: id.toString(),
        deviceId: '1',
        once: false,
        streamDetails: true,
        measurePayloadBytes: false,
        output: records.add,
      );
      final insert = CrdtMergeInsert(
        hlcDatetime: DateTime.utc(2026),
        hlcCounter: 0,
        uuidSpaceId: id,
        tableName: 'person',
        uuidRowId: id,
        uuidNodeId: id,
        data: Person(
          id: id,
          name: 'payload excluded',
          surname: 'round:0/row:0/writer:0',
        ),
      );
      final update = CrdtMergeUpdate(
        hlcDatetime: DateTime.utc(2026),
        hlcCounter: 1,
        uuidSpaceId: id,
        tableName: 'person',
        uuidRowId: id,
        uuidNodeId: id,
        columnName: 'surname',
        value: 'round:1/row:0/writer:1',
      );

      await first.run(() async {
        first.wire(
          OfflineSyncMergeChunk(batchId: 7, changes: [insert]),
          direction: 'received',
        );
        await OfflineSyncDiagnostics.measure(
          'sync.inboundBatch',
          () => OfflineSyncDiagnostics.measure('merge', () async {}),
          data: {'batchId': 7},
        );
      });
      second.wire(
        OfflineSyncMergeChunk(batchId: 3, changes: [update]),
        direction: 'yielded',
      );
      first.finish(outcome: 'completed');
      second.finish(outcome: 'completed');

      final frames = records.where((row) => row['type'] == 'syncFrame').toList();
      expect(frames.map((row) => row['batchId']), [7, 3]);
      expect(frames.map((row) => row['rounds']), [
        [
          {'round': 0, 'writer': 0},
        ],
        [
          {'round': 1, 'writer': 1},
        ],
      ]);
      final merge = records.singleWhere((row) => row['type'] == 'mergeTrace');
      expect(merge['batchId'], 7);
      final mergeEnd =
          (merge['processOriginMicros'] as int) + (merge['endMicros'] as int);
      expect(mergeEnd, lessThanOrEqualTo(frames.last['processMicros'] as int));
      expect(frames.first.keys, isNot(contains('payload')));
    },
  );
}
