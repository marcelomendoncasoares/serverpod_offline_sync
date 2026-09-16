import 'dart:convert';
import 'dart:math' as math;

import 'dst_adversary.dart';
import 'dst_random.dart';
import 'dst_roundtrip.dart';
import 'dst_snapshot.dart';
import 'dst_workload.dart';
import 'dst_world.dart';

/// The shape of one simulated deployment.
class DstTopology {
  /// Creates a topology.
  const DstTopology({required this.spaceCount, required this.subscriptions});

  /// Two spaces, and three replicas whose subscription sets deliberately
  /// differ: two hold only one space each, one holds both.
  ///
  /// The overlap is the point. Observer independence is only falsifiable when
  /// some replica holds strictly more than another, because the claim is that
  /// the extra space changes nothing about the shared one.
  static const overlappingSpaces = DstTopology(
    spaceCount: 2,
    subscriptions: [
      [0],
      [1],
      [0, 1],
    ],
  );

  /// One space shared by every replica - the classic convergence shape.
  static const singleSpace = DstTopology(
    spaceCount: 1,
    subscriptions: [
      [0],
      [0],
      [0],
    ],
  );

  /// How many spaces exist.
  final int spaceCount;

  /// Which space indexes each replica holds.
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
    required this.appliedPaths,
    required this.attemptedPaths,
    required this.rounds,
    required this.profile,
    required this.graphWidth,
    required this.skipped,
    required this.setupAttempted,
    required this.scheduledCommitted,
    required this.coverage,
    required this.network,
  });

  final int rounds;
  final DstProfile profile;
  final int graphWidth;
  final int skipped;
  final int setupAttempted;
  final int scheduledCommitted;
  final Map<String, Object> coverage;
  final Map<String, int> network;
  int get attempted => attemptedPaths.values.fold(0, (sum, value) => sum + value);
  int get scheduledAttempted => attempted - setupAttempted;

  Map<String, Object> toJson() => {
    'seed': seed,
    'rounds': rounds,
    'profile': profile.name,
    'graphWidth': graphWidth,
    'attempted': attempted,
    'committed': applied,
    'rejected': rejected,
    'skipped': skipped,
    'setupAttempted': setupAttempted,
    'scheduledAttempted': scheduledAttempted,
    'scheduledCommitted': scheduledCommitted,
    'qualification': rounds >= 100 && scheduledCommitted >= 30 ? 'stress' : 'smoke',
    'appliedPaths': appliedPaths,
    'attemptedPaths': attemptedPaths,
    'coverage': coverage,
    'network': network,
  };

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

  final Map<String, int> appliedPaths;
  final Map<String, int> attemptedPaths;

  @override
  String toString() =>
      'seed=$seed merges=$merges applied=$applied rejected=$rejected '
      'visible=$visibleRows hidden=$hiddenRows paths=$appliedPaths';
}

/// Runs one seeded simulation and checks every property.
///
/// Structural invariants run after each local commit and merge, so a violation is reported at
/// the moment it appears rather than at the end of the run. Agreement
/// properties run once, after the adversary has quiesced.
Future<DstRunReport> runDstSimulation({
  required int seed,
  required int rounds,
  DstTopology topology = DstTopology.overlappingSpaces,
  DstProfile profile = DstProfile.sparse,
  int graphWidth = 2,
}) async {
  if (rounds < 1 || graphWidth < 2) {
    throw ArgumentError('rounds >= 1 and graphWidth >= 2 required');
  }
  final resolvedProfile = profile == DstProfile.mixed
      ? (seed.isEven ? DstProfile.populated : DstProfile.sparse)
      : profile;
  final random = DstRandom(seed);
  final ids = DstIds(random);
  final simulationClock = DstClock();

  final spaceUuids = [
    for (var index = 0; index < topology.spaceCount; index++) ids.next(),
  ];

  final replicas = <DstReplica>[];
  for (var index = 0; index < topology.replicaCount; index++) {
    replicas.add(
      await DstReplica.create(
        name: 'r$index',
        spaceUuids: [
          for (final spaceIndex in topology.subscriptions[index])
            spaceUuids[spaceIndex],
        ],
        nodeUuid: ids.next(),
        // Skew stays far below Hlc's one-minute drift limit so the simulation
        // exercises clock disagreement without tripping ClockDriftException.
        clock: simulationClock.skewed(Duration(milliseconds: index * 250)),
      ),
    );
  }

  // company.townId repairs onto this well-known town. Inserted once, in one
  // space, because row ids are globally unique; other spaces exercise the
  // unrepairable set-default path instead.
  await replicas.first.seedDefaultTown(replicas.first.spaceUuids.first);

  final operations = DstOperations(random, ids);
  operations.oracle.accept(await DstSnapshot.capture(replicas.first));
  final adversary = DstAdversary(random, replicas);
  var schedulingStarted = false;
  var setupAttempted = 0;
  var setupCommitted = 0;

  Future<void> checkInvariants(DstReplica replica) async {
    final snapshot = await DstSnapshot.capture(replica);
    final violations = operations.observe(replica, snapshot);
    if (violations.isEmpty) return;
    throw DstPropertyFailure(
      seed: seed,
      rounds: rounds,
      profile: profile,
      graphWidth: graphWidth,
      replica: replica,
      violations: violations,
    );
  }

  try {
    if (resolvedProfile == DstProfile.populated) {
      for (final space in spaceUuids) {
        final author = replicas.firstWhere(
          (replica) => replica.spaceUuids.contains(space),
        );
        await populateDstSpace(
          replica: author,
          space: space,
          operations: operations,
          ids: ids,
          width: graphWidth,
        );
      }
      // Start scheduled conflicts from shared, populated graphs. Full collector
      // batches are merged; no causal batch is split to manufacture disorder.
      await adversary.quiesce(checkInvariants);
    }
    setupAttempted = operations.attempted;
    setupCommitted = operations.committed;
    schedulingStarted = true;

    for (var round = 0; round < rounds; round++) {
      for (final replica in replicas) {
        final spaceUuid = random.pickOrNull(replica.spaceUuids);
        if (spaceUuid == null) continue;
        await operations.step(replica, spaceUuid);
        simulationClock.advance(Duration(milliseconds: random.between(1, 40)));
      }
      await adversary.step(checkInvariants);
    }

    await adversary.quiesce(checkInvariants);

    final snapshots = <DstReplica, DstSnapshot>{
      for (final replica in replicas) replica: await DstSnapshot.capture(replica),
    };

    final violations = <DstViolation>[];
    for (final spaceUuid in spaceUuids) {
      violations.addAll(DstOracle.observerIndependence(snapshots, spaceUuid));
    }
    for (final entry in snapshots.entries) {
      violations.addAll(DstOracle.invariants(entry.value));
      for (final space in entry.key.spaceUuids) {
        violations.addAll(operations.oracle.validate(entry.value, space));
      }
    }

    // Round trips run once the network is quiet, because each one builds a
    // replica and replays a whole space into it.
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
      throw DstPropertyFailure(
        seed: seed,
        rounds: rounds,
        profile: profile,
        graphWidth: graphWidth,
        violations: violations,
      );
    }

    final report = DstRunReport(
      seed: seed,
      merges: adversary.mergeCount,
      applied: operations.committed,
      rounds: rounds,
      profile: resolvedProfile,
      graphWidth: graphWidth,
      skipped: operations.skipped,
      setupAttempted: setupAttempted,
      scheduledCommitted: operations.committed - setupCommitted,
      coverage: operations.coverage.toJson(),
      network: adversary.metrics,
      rejected: operations.rejections.length,
      visibleRows: snapshots.values.fold(
        0,
        (sum, snapshot) => sum + snapshot.visibleRowCount,
      ),
      appliedPaths: Map.unmodifiable(operations.appliedPaths),
      attemptedPaths: Map.unmodifiable(operations.attemptedPaths),
      hiddenRows: snapshots.values.fold(
        0,
        (sum, snapshot) => sum + snapshot.hiddenRowCount,
      ),
    );
    final requiredCommits = math.min(rounds >= 100 ? 30 : 3, rounds * replicas.length);
    if (report.scheduledCommitted < requiredCommits || report.merges == 0) {
      throw StateError(
        'Insufficient scheduled activity: required $requiredCommits commits; ${report.toJson()}',
      );
    }
    if (resolvedProfile == DstProfile.populated) {
      final transitions = operations.coverage.transitions;
      final missing = [
        for (final kind in [
          'authoredCycle',
          'restore',
          'redelete',
          'fkRetarget',
          'fkDetach',
          'uniqueConflict',
          'uniqueSwap',
          'constrainedRejection',
        ])
          if ((transitions[kind] ?? 0) == 0) kind,
        if (operations.coverage.foreignKeys.length != dstForeignKeys.length)
          'all declared FK edges',
      ];
      if (missing.isNotEmpty) throw StateError('Populated workload missed $missing');
    }
    return report;
  } finally {
    // Emit aggregate observations on passing and failing runs. Setup progress
    // remains distinct from random scheduled commits, and failures retain the
    // profile/width/depth needed to replay the workload.
    // ignore: avoid_print
    print(
      'DST_METRICS ${jsonEncode({
        'seed': seed,
        'rounds': rounds,
        'profile': resolvedProfile.name,
        'requestedProfile': profile.name,
        'graphWidth': graphWidth,
        'attempted': operations.attempted,
        'committed': operations.committed,
        'rejected': operations.rejections.length,
        'skipped': operations.skipped,
        'unexpectedFailures': operations.unexpected,
        'committedValidationFailures': operations.validationFailures,
        'setupAttempted': schedulingStarted ? setupAttempted : operations.attempted,
        'scheduledAttempted': schedulingStarted ? operations.attempted - setupAttempted : 0,
        'scheduledCommitted': schedulingStarted ? operations.committed - setupCommitted : 0,
        'attemptedPaths': operations.attemptedPaths,
        'appliedPaths': operations.appliedPaths,
        'skippedPaths': operations.skippedPaths,
        'coverage': operations.coverage.toJson(),
        'network': adversary.metrics,
      })}',
    );
  }
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
  required int rounds,
  required Future<T> Function() run,
  DstProfile profile = DstProfile.sparse,
  int graphWidth = 2,
}) async {
  try {
    return await run();
  } on DstPropertyFailure {
    rethrow;
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(
      StateError(
        'Simulation $index (seed $seed) failed\n'
        'Replay: DST_SEED_BASE=$seed DST_SEEDS=1 DST_ROUNDS=$rounds DST_PROFILE=${profile.name} DST_GRAPH_WIDTH=$graphWidth dart test -P dst\n'
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
    required this.rounds,
    required this.violations,
    this.replica,
    this.profile = DstProfile.sparse,
    this.graphWidth = 2,
  });

  final DstProfile profile;
  final int graphWidth;

  /// The seed that produced the failure.
  final int seed;

  /// The round count that produced the failure.
  final int rounds;

  /// The violated properties.
  final List<DstViolation> violations;

  /// The replica whose state was checked, when the failure is replica-local.
  final DstReplica? replica;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..writeln('DST property failure (seed $seed)')
      ..writeln(
        'Replay: DST_SEED_BASE=$seed DST_SEEDS=1 DST_ROUNDS=$rounds DST_PROFILE=${profile.name} DST_GRAPH_WIDTH=$graphWidth dart test -P dst',
      );
    if (replica != null) buffer.writeln('Replica: $replica');
    for (final violation in violations) {
      buffer.writeln('- ${violation.property}: ${violation.detail}');
    }
    return buffer.toString();
  }
}
