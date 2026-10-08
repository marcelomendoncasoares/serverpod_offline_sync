import 'package:test/test.dart';

import 'framework/dst_random.dart';
import 'framework/dst_runner.dart';

void main() {
  test(
    'Given two node allocators with the same seed, '
    'when each assigns three identities to ordered clock slots, '
    'then the shuffled identity assignment replays exactly.',
    () {
      final first = DstIds(DstRandom(91)).nextShuffled(3);
      final second = DstIds(DstRandom(91)).nextShuffled(3);

      expect(first, second);
      expect(first.toSet(), hasLength(3));
    },
  );

  test(
    'Given node allocators with seeds 1 through 16, '
    'when each assigns three identities to ordered clock slots, '
    'then node tie-break ordering varies independently of the clock order.',
    () {
      final orders = <String>{};
      for (var seed = 1; seed <= 16; seed++) {
        final nodes = DstIds(DstRandom(seed)).nextShuffled(3);
        final ranked = nodes.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
        orders.add(nodes.map(ranked.indexOf).join());
      }

      expect(orders, containsAll(['012', '210']));
    },
  );

  test(
    'Given a property violation from seed 114 at 80 rounds, '
    'when its failure is reported, '
    'then the replay command preserves the seed, depth, profile, graph width, and delivery mode.',
    () {
      final failure = DstPropertyFailure(
        seed: 114,
        rounds: 80,
        profile: DstProfile.populated,
        graphWidth: 3,
        delivery: DstDeliveryMode.delta,
        violations: [(property: 'foreignKeyClosure', detail: 'orphan')],
      );

      final message = failure.toString();

      expect(
        message,
        'DST property failure (seed 114)\n'
        'Replay: DST_SEED_BASE=114 DST_SEEDS=1 DST_ROUNDS=80 DST_PROFILE=populated DST_GRAPH_WIDTH=3 DST_DELIVERY=delta dart test -P dst\n'
        '- foreignKeyClosure: orphan\n',
      );
    },
  );

  test(
    'Given an unexpected exception from seed 115 at 40 rounds, '
    'when its failure is reported, '
    'then the replay command preserves the seed, depth, profile, graph width, and delivery mode.',
    () async {
      final failure = await runWithSeedReported<Object>(
        index: 1,
        seed: 115,
        rounds: 40,
        run: () async => throw StateError('unexpected'),
      ).then<Object>((value) => value, onError: (Object error) => error);

      final message = failure.toString();

      expect(
        message,
        'Bad state: Simulation 1 (seed 115) failed\n'
        'Replay: DST_SEED_BASE=115 DST_SEEDS=1 DST_ROUNDS=40 DST_PROFILE=sparse DST_GRAPH_WIDTH=2 DST_DELIVERY=full dart test -P dst\n'
        'Bad state: unexpected',
      );
    },
  );
}
