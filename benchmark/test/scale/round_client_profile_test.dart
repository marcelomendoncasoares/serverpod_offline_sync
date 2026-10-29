import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_client_profile.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Given interleaved unrelated batches and two chunks of one authored round, '
    'when its upload and peer download boundaries arrive, '
    'then only matching numbered batches are retained without row payloads.',
    () {
      var now = 0;
      final profile = RoundClientProfile(
        round: 4,
        writer: 0,
        readMicros: () => now,
      );
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
      final change = CrdtMergeInsert(
        hlcDatetime: DateTime.utc(2026),
        hlcCounter: 0,
        uuidSpaceId: id,
        tableName: 'person',
        uuidRowId: id,
        uuidNodeId: id,
        data: Person(
          id: id,
          name: 'payload must stay private',
          surname: 'round:4/row:0/writer:0',
        ),
      );
      final unrelated = change.copyWith(
        data: Person(id: id, name: 'unrelated', surname: 'round:3/row:0/writer:1'),
      );

      now = 5;
      profile
        ..observe(
          0,
          OfflineSyncMergeChunk(batchId: 6, changes: [unrelated]),
          'sent',
        )
        ..observe(
          0,
          OfflineSyncEndOfBatch(batchId: 6, finalForOnce: false, checkpoints: const []),
          'sent',
        );
      now = 10;
      profile.observe(0, OfflineSyncMergeChunk(batchId: 7, changes: [change]), 'sent');
      now = 12;
      profile.observe(0, OfflineSyncMergeChunk(batchId: 7, changes: [change]), 'sent');
      now = 15;
      profile.observe(
        0,
        OfflineSyncEndOfBatch(batchId: 7, finalForOnce: false, checkpoints: const []),
        'sent',
      );
      now = 90;
      profile.observe(
        1,
        OfflineSyncMergeChunk(batchId: 3, changes: [change]),
        'received',
      );
      now = 95;
      profile.observe(
        1,
        OfflineSyncEndOfBatch(batchId: 3, finalForOnce: false, checkpoints: const []),
        'received',
      );
      now = 100;
      profile.observe(0, OfflineSyncCommitted(batchId: 7), 'received');

      expect(profile.toJson(), {
        'round': 4,
        'writer': 0,
        'droppedBatches': 0,
        'batches': [
          {
            'device': 0,
            'direction': 'sent',
            'batchId': 7,
            'firstChunkMicros': 10,
            'lastChunkMicros': 12,
            'chunks': 2,
            'endMicros': 15,
          },
          {
            'device': 1,
            'direction': 'received',
            'batchId': 3,
            'firstChunkMicros': 90,
            'lastChunkMicros': 90,
            'chunks': 1,
            'endMicros': 95,
          },
        ],
      });
    },
  );

  test(
    'Given a chunk whose upload boundary never arrives, '
    'when its profile is exported, '
    'then the missing boundary stays absent for correlation to reject.',
    () {
      final profile = RoundClientProfile(round: 0, writer: 0, readMicros: () => 10);
      final id = UuidValue.fromString('00000000-0000-4000-8000-000000000001');
      final change = CrdtMergeInsert(
        hlcDatetime: DateTime.utc(2026),
        hlcCounter: 0,
        uuidSpaceId: id,
        tableName: 'person',
        uuidRowId: id,
        uuidNodeId: id,
        data: Person(id: id, name: 'row', surname: 'round:0/row:0/writer:0'),
      );

      profile
        ..observe(0, OfflineSyncMergeChunk(batchId: 1, changes: [change]), 'sent')
        ..observe(
          0,
          OfflineSyncEndOfBatch(batchId: 2, finalForOnce: false, checkpoints: const []),
          'sent',
        );
      final batches = profile.toJson()['batches']! as List;

      expect(batches.single, isNot(contains('endMicros')));
    },
  );

  test(
    'Given eight benchmark users with full diagnostics disabled, '
    'when one user is selected for client profiling, '
    'then only the selected index is carried into worker options.',
    () {
      final options = RoundOptions.parse([
        '--target',
        'http://localhost:8080/',
        '--users',
        '8',
        '--no-sync-diagnostics',
        '--client-profile-user',
        '3',
      ]);

      expect(options.values['client-profile-user'], 3);
      expect(options.scale.flag('sync-diagnostics'), isFalse);
    },
  );

  test(
    'Given four benchmark users, '
    'when profiling selects a nonexistent user, '
    'then the command is rejected.',
    () {
      expect(
        () => RoundOptions.parse([
          '--target',
          'http://localhost:8080/',
          '--users',
          '4',
          '--client-profile-user',
          '4',
        ]),
        throwsFormatException,
      );
    },
  );
}
