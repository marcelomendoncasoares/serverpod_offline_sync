@Tags(['dst'])
library;

import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_runner.dart';

/// Deterministic simulation of replicas sharing one space.
///
/// This is the classic convergence shape: the same facts reach every replica
/// in a different order, in different batches, sometimes twice, and the visible
/// databases must still agree. It exercises the idempotence, associativity, and
/// commutativity the engine claims, and checks that foreign-key and unique
/// invariants hold in the visible projection after every merge.
void main() {
  initTestClientSession();

  final config = DstConfig.fromEnvironment();

  group('Given replicas sharing a single space,', () {
    // Named by position rather than by seed; see dst_cross_space_test.dart.
    for (final (index, seed) in config.seeds.indexed) {
      test(
        'when simulation $index reorders, delays, and repeats delivery, '
        'then the replicas converge with foreign key and unique invariants intact.',
        () async {
          final report = await runWithSeedReported(
            index: index,
            seed: seed,
            rounds: config.rounds,
            run: () => runDstSimulation(
              seed: seed,
              rounds: config.rounds,
              topology: DstTopology.singleSpace,
            ),
          );

          expect(
            report.merges,
            greaterThan(0),
            reason: 'seed $seed exercised no merges: $report',
          );
          expect(
            report.applied,
            greaterThan(0),
            reason: 'seed $seed applied no operations: $report',
          );
        },
      );
    }
  });
}
