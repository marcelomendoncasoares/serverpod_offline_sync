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
    // Named by position rather than by seed. The seed changes every run, so
    // naming tests after it would rewrite the whole suite each time: a runner
    // that tracks tests by name would see a fresh set on every pass and could
    // never say a given simulation started or stopped failing. The seed is
    // reported on failure instead, where it is needed.
    for (final (index, seed) in config.seeds.indexed) {
      test(
        'when simulation $index drives random operations and adversarial '
        'delivery, then every scope looks identical to all replicas holding it '
        'and no foreign key links across scopes.',
        () async {
          final report = await runWithSeedReported(
            index: index,
            seed: seed,
            run: () => runDstSimulation(
              seed: seed,
              rounds: config.rounds,
              topology: DstTopology.overlappingScopes,
            ),
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
