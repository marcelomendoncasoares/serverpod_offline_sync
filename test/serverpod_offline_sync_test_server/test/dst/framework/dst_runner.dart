import 'dst_adversary.dart';
import 'dst_random.dart';
import 'dst_roundtrip.dart';
import 'dst_snapshot.dart';
import 'dst_world.dart';

/// The shape of one simulated deployment.
class DstTopology {
  /// Creates a topology.
  const DstTopology({required this.scopeCount, required this.subscriptions});

  /// Two scopes, and three replicas whose subscription sets deliberately
  /// differ: two hold only one scope each, one holds both.
  ///
  /// The overlap is the point. Observer independence is only falsifiable when
  /// some replica holds strictly more than another, because the claim is that
  /// the extra scope changes nothing about the shared one.
  static const overlappingScopes = DstTopology(
    scopeCount: 2,
    subscriptions: [
      [0],
      [1],
      [0, 1],
    ],
  );

  /// One scope shared by every replica - the classic convergence shape.
  static const singleScope = DstTopology(
    scopeCount: 1,
    subscriptions: [
      [0],
      [0],
      [0],
    ],
  );

  /// How many scopes exist.
  final int scopeCount;

  /// Which scope indexes each replica holds.
  final List<List<int>> subscriptions;

  /// How many replicas the topology has.
  int get replicaCount => subscriptions.length;
}

/// What one simulation run observed, for reporting and for asserting that a
/// seed did meaningful work.
class DstRunReport {
  /// Creates a report.
  DstRunReport({
    required this.seed,
    required this.merges,
    required this.applied,
    required this.rejected,
    required this.visibleRows,
    required this.hiddenRows,
  });

  /// The seed that produced the run.
  final int seed;

  /// How many batches were merged.
  final int merges;

  /// How many generated operations committed.
  final int applied;

  /// How many the engine refused by design.
  final int rejected;

  /// Visible rows at quiescence, summed across replicas.
  final int visibleRows;

  /// Hidden rows at quiescence, summed across replicas.
  final int hiddenRows;

  @override
  String toString() =>
      'seed=$seed merges=$merges applied=$applied rejected=$rejected '
      'visible=$visibleRows hidden=$hiddenRows';
}

/// Runs one seeded simulation and checks every property.
///
/// Structural invariants run after each merge, so a violation is reported at
/// the moment it appears rather than at the end of the run. Agreement
/// properties run once, after the adversary has quiesced.
Future<DstRunReport> runDstSimulation({
  required int seed,
  required int rounds,
  DstTopology topology = DstTopology.overlappingScopes,
}) async {
  final random = DstRandom(seed);
  final ids = DstIds(random);
  final simulationClock = DstClock();

  final scopeUuids = [
    for (var index = 0; index < topology.scopeCount; index++) ids.next(),
  ];

  final replicas = <DstReplica>[];
  for (var index = 0; index < topology.replicaCount; index++) {
    replicas.add(
      await DstReplica.create(
        name: 'r$index',
        scopeUuids: [
          for (final scopeIndex in topology.subscriptions[index])
            scopeUuids[scopeIndex],
        ],
        nodeUuid: ids.next(),
        // Skew stays far below Hlc's one-minute drift limit so the simulation
        // exercises clock disagreement without tripping ClockDriftException.
        clock: simulationClock.skewed(Duration(milliseconds: index * 250)),
      ),
    );
  }

  final operations = DstOperations(random, ids);
  final adversary = DstAdversary(random, replicas);
  var applied = 0;

  final causalLength = DstCausalLength();

  Future<void> checkInvariants(DstReplica replica) async {
    final snapshot = await DstSnapshot.capture(replica);
    final violations = [
      ...DstOracle.invariants(snapshot),
      ...causalLength.observe(replica.name, snapshot),
    ];
    if (violations.isEmpty) return;
    throw DstPropertyFailure(
      seed: seed,
      replica: replica,
      violations: violations,
    );
  }

  for (var round = 0; round < rounds; round++) {
    for (final replica in replicas) {
      final scopeUuid = random.pickOrNull(replica.scopeUuids);
      if (scopeUuid == null) continue;
      final outcome = await operations.step(replica, scopeUuid);
      if (outcome == DstOperationOutcome.applied) applied++;
      simulationClock.advance(Duration(milliseconds: random.between(1, 40)));
    }
    await adversary.step(checkInvariants);
  }

  await adversary.quiesce(checkInvariants);

  final snapshots = <DstReplica, DstSnapshot>{
    for (final replica in replicas) replica: await DstSnapshot.capture(replica),
  };

  final violations = <DstViolation>[];
  for (final scopeUuid in scopeUuids) {
    violations.addAll(DstOracle.observerIndependence(snapshots, scopeUuid));
  }
  for (final entry in snapshots.entries) {
    violations.addAll(DstOracle.invariants(entry.value));
  }

  // Round trips run once the network is quiet, because each one builds a
  // replica and replays a whole scope into it.
  for (final entry in snapshots.entries) {
    violations.addAll(
      await exportRoundTrip(
        source: entry.key,
        expected: entry.value,
        ids: ids,
        clock: simulationClock.clock,
      ),
    );
  }
  if (violations.isNotEmpty) {
    throw DstPropertyFailure(seed: seed, violations: violations);
  }

  return DstRunReport(
    seed: seed,
    merges: adversary.mergeCount,
    applied: applied,
    rejected: operations.rejections.length,
    visibleRows: snapshots.values.fold(
      0,
      (sum, snapshot) => sum + snapshot.visibleRowCount,
    ),
    hiddenRows: snapshots.values.fold(
      0,
      (sum, snapshot) => sum + snapshot.hiddenRowCount,
    ),
  );
}

/// Runs [run], making sure any failure names the seed behind it.
///
/// Tests are named by position rather than by seed, because the seed changes
/// on every run. That keeps the suite stable but takes the seed out of the
/// failure header, so it is put back here: a [DstPropertyFailure] already
/// carries it, and anything else is wrapped so it does too. Without this an
/// unexpected exception would be unreplayable.
Future<T> runWithSeedReported<T>({
  required int index,
  required int seed,
  required Future<T> Function() run,
}) async {
  try {
    return await run();
  } on DstPropertyFailure {
    rethrow;
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(
      StateError(
        'Simulation $index (seed $seed) failed\n'
        'Replay: DST_SEED_BASE=$seed DST_SEEDS=1 dart test -P dst\n'
        '$error',
      ),
      stackTrace,
    );
  }
}

/// Raised when a simulation falsifies a property.
///
/// The message leads with the replay command, because the first thing anyone
/// does with a failing seed is run it again.
class DstPropertyFailure implements Exception {
  /// Creates a failure for [seed].
  DstPropertyFailure({
    required this.seed,
    required this.violations,
    this.replica,
  });

  /// The seed that produced the failure.
  final int seed;

  /// The violated properties.
  final List<DstViolation> violations;

  /// The replica whose state was checked, when the failure is replica-local.
  final DstReplica? replica;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('DST property failure (seed $seed)')
      ..writeln('Replay: DST_SEED_BASE=$seed DST_SEEDS=1 dart test -P dst');
    if (replica != null) buffer.writeln('Replica: $replica');
    for (final violation in violations) {
      buffer.writeln('- ${violation.property}: ${violation.detail}');
    }
    return buffer.toString();
  }
}
