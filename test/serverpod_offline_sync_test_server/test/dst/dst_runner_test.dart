import 'package:test/test.dart';

import 'framework/dst_random.dart';
import 'framework/dst_runner.dart';

void main() {
  test(
    'Given a property violation from seed 114 at 80 rounds, '
    'when its failure is reported, '
    'then the replay command preserves the seed, depth, profile, and graph width.',
    () {
      final failure = DstPropertyFailure(
        seed: 114,
        rounds: 80,
        profile: DstProfile.populated,
        graphWidth: 3,
        violations: [(property: 'foreignKeyClosure', detail: 'orphan')],
      );

      final message = failure.toString();

      expect(
        message,
        'DST property failure (seed 114)\n'
        'Replay: DST_SEED_BASE=114 DST_SEEDS=1 DST_ROUNDS=80 DST_PROFILE=populated DST_GRAPH_WIDTH=3 dart test -P dst\n'
        '- foreignKeyClosure: orphan\n',
      );
    },
  );

  test(
    'Given an unexpected exception from seed 115 at 40 rounds, '
    'when its failure is reported, '
    'then the replay command preserves the seed, depth, profile, and graph width.',
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
        'Replay: DST_SEED_BASE=115 DST_SEEDS=1 DST_ROUNDS=40 DST_PROFILE=sparse DST_GRAPH_WIDTH=2 dart test -P dst\n'
        'Bad state: unexpected',
      );
    },
  );
}
