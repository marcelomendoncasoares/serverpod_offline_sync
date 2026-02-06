import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';

void main() {
  group('Given CRDT with an existing canonical time', () {
    late OfflineSyncCrdt crdt;
    late CrdtDatabase crdtDb;
    late Hlc initialHlc;

    const otherNodeId = 'other';
    final initialDateTime = DateTime.now().toUtc();

    setUp(() async {
      (crdt, crdtDb, _) = database.crdtContext;

      await crdtDb.managers.crdtHlcStateTable.create(
        (t) => t(
          userId: crdt.userId,
          lastTimestamp: initialDateTime.millisecondsSinceEpoch,
          counter: 17,
        ),
      );

      initialHlc = await crdt.getCanonicalTime();
    });

    test('when merging an HLC with higher time and counter '
        'then the canonical time has the new HLC timestamp and counter.', () async {
      final newHlc = Hlc(initialDateTime.advance(), 18, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(newHlc.copyWith(nodeId: crdt.nodeId)));
    });

    test('when merging an HLC with higher time and lower counter '
        'then the canonical time has the new HLC timestamp and counter.', () async {
      final newHlc = Hlc(initialDateTime.advance(), 0, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(newHlc.copyWith(nodeId: crdt.nodeId)));
    });

    test('when merging an HLC with lower time and counter '
        'then the canonical time is the initial HLC.', () async {
      final newHlc = Hlc(initialDateTime.retreat(), 0, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(initialHlc));
    });

    test('when merging an HLC with lower time and higher counter '
        'then the canonical time is the initial HLC.', () async {
      final newHlc = Hlc(initialDateTime.retreat(), 18, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(initialHlc));
    });

    test('when merging an HLC with same time and higher counter '
        'then the canonical time has the higher counter.', () async {
      final newHlc = Hlc(initialDateTime, 18, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(newHlc.copyWith(nodeId: crdt.nodeId)));
    });

    test('when merging an HLC with same time and lower counter '
        'then the canonical time is the initial HLC.', () async {
      final newHlc = Hlc(initialDateTime, 0, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(initialHlc));
    });

    test('when merging an HLC with same time and counter '
        'then the canonical time is the initial HLC.', () async {
      final newHlc = Hlc(initialDateTime, 17, otherNodeId);

      await crdt.mergeCanonicalTime(newHlc);
      final canonicalTime = await crdt.getCanonicalTime();

      expect(canonicalTime, equals(initialHlc));
    });
  });
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
