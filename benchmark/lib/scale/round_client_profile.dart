// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import 'diagnostics.dart';

/// Records client boundaries for one authored round without logging per frame.
/// Every device in a user group uses the same round clock in one worker isolate.
class RoundClientProfile {
  RoundClientProfile({
    required this.round,
    required this.writer,
    required this.readMicros,
  });

  final int round;
  final int writer;
  final int Function() readMicros;
  final _batches = <(int, String, int), Map<String, Object?>>{};
  var droppedBatches = 0;

  void observe(int device, Object event, String direction) {
    if (event is! OfflineSyncMergeChunk && event is! OfflineSyncEndOfBatch) return;

    final at = readMicros();
    if (event is OfflineSyncMergeChunk) {
      final matches = benchmarkRounds(event.changes).any(
        (identity) => identity['round'] == round && identity['writer'] == writer,
      );
      if (!matches) return;

      final key = (device, direction, event.batchId);
      if (!_batches.containsKey(key) && _batches.length >= 64) {
        droppedBatches++;
        return;
      }

      final batch = _batches.putIfAbsent(
        key,
        () => {
          'device': device,
          'direction': direction,
          'batchId': event.batchId,
          'firstChunkMicros': at,
          'chunks': 0,
        },
      );
      batch['lastChunkMicros'] = at;
      batch['chunks'] = (batch['chunks']! as int) + 1;
    } else if (event is OfflineSyncEndOfBatch) {
      final batch = _batches[(device, direction, event.batchId)];
      if (batch != null) batch['endMicros'] = at;
    }
  }

  Map<String, Object?> toJson() => {
    'round': round,
    'writer': writer,
    'droppedBatches': droppedBatches,
    'batches': [
      for (final batch in _batches.values) {...batch},
    ],
  };
}
