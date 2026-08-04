import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_runner.dart';

/// Deterministic simulation of replicas sharing one scope.
///
/// This is the classic convergence shape: the same facts reach every replica
/// in a different order, in different batches, sometimes twice, and the visible
/// databases must still agree. It exercises the idempotence, associativity, and
/// commutativity the engine claims, and checks that foreign-key and unique
/// invariants hold in the visible projection after every merge.
void main() {
  initTestClientSession();

  final config = DstConfig.fromEnvironment();

  group('Given replicas sharing a single scope,', () {
    for (final seed in config.seeds) {
      test(
        'when seed $seed reorders, delays, and repeats delivery, '
        'then the replicas converge with foreign key and unique invariants '
        'intact.',
        () async {
          final report = await runDstSimulation(
            seed: seed,
            rounds: config.rounds,
            topology: DstTopology.singleScope,
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
