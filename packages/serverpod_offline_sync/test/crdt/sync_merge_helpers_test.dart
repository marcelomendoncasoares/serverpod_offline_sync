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
}
