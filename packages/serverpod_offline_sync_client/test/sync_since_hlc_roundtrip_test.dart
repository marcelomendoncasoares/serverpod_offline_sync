import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart'
    hide Protocol;
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test(
    'Given a since-HLC frame when serialized then node checkpoints roundtrip.',
    () {
      final nodeA = const Uuid().v7obj();
      final nodeB = const Uuid().v7obj();

      final checkpoints = <Hlc>[
        Hlc(DateTime.utc(2026, 1, 1), 1, nodeA),
        Hlc(DateTime.utc(2026, 1, 1), 2, nodeB),
      ];

      final original = CrdtSyncSinceHlc(nodeCheckpoints: checkpoints);
      final serialized = original.toJson();
      final deserialized = Protocol().deserialize<CrdtSyncSinceHlc>(serialized);

      expect(
        deserialized.nodeCheckpoints.map((h) => h.toString()).toList(),
        checkpoints.map((h) => h.toString()).toList(),
      );
    },
  );
}
