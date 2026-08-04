import 'package:test/test.dart';

import '../integration/test_tools/client_session.dart';
import 'framework/dst_random.dart';
import 'framework/dst_runner.dart';

/// Deterministic simulation of replicas whose scope subscriptions overlap but
/// differ, which is the shape that can falsify the cross-scope design.
///
/// A synced row may only reference synced rows of its own scope
/// (`docs/row-ownership.md`), so a merged reference into another scope must be
/// repaired or the child hidden. That repair must not depend on which scopes
/// the merging replica happens to hold - otherwise visibility becomes a
/// function of the observer's subscription set and the merge stops being a
/// deterministic function of the facts.
void main() {
  initTestClientSession();

  final config = DstConfig.fromEnvironment();

  group('Given replicas with overlapping but unequal scope subscriptions,', () {
    for (final seed in config.seeds) {
      test(
        'when seed $seed drives random operations and adversarial delivery, '
        'then every scope looks identical to all replicas holding it and no '
        'foreign key links across scopes.',
        () async {
          final report = await runDstSimulation(
            seed: seed,
            rounds: config.rounds,
            topology: DstTopology.overlappingScopes,
          );

          // A run that merged nothing would pass every property vacuously.
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
