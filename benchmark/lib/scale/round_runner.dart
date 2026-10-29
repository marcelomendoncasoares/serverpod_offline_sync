// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'common.dart';
import 'elapsed_clock.dart';
import 'round_options.dart';
import 'runner.dart';

Map<String, dynamic> roundDistribution(Iterable<num> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return {'count': 0};
  num quantile(double fraction) =>
      sorted[max(0, (sorted.length * fraction).ceil() - 1)];
  return {
    'count': sorted.length,
    'meanMicros': sorted.reduce((a, b) => a + b) / sorted.length,
    'p50Micros': quantile(.50),
    'p95Micros': quantile(.95),
    'p99Micros': quantile(.99),
    'maxMicros': sorted.last,
  };
}

/// End-to-end round overlap, not simultaneous SQL execution or configured load.
Map<String, dynamic> roundConcurrency(
  Iterable<Map<String, dynamic>> rounds, {
  required int devicesPerUser,
}) {
  final boundaries = <({int time, int user, int delta})>[];
  for (final round in rounds) {
    final start = round['startedMicros'] as int?;
    final end = round['finishedMicros'] as int?;
    if (start == null || end == null) continue;
    if (end < start) throw StateError('A round ended before it started.');
    if (end == start) continue;
    final user = round['user'] as int;
    boundaries
      ..add((time: start, user: user, delta: 1))
      ..add((time: end, user: user, delta: -1));
  }
  boundaries.sort((a, b) {
    final time = a.time.compareTo(b.time);
    return time != 0 ? time : a.delta.compareTo(b.delta);
  });
  final activeUsers = <int, int>{};
  var count = 0;
  var peak = 0;
  var peakUsers = 0;
  var roundArea = 0;
  var userArea = 0;
  var previous = boundaries.isEmpty ? 0 : boundaries.first.time;
  for (final boundary in boundaries) {
    final duration = boundary.time - previous;
    roundArea += duration * count;
    userArea += duration * activeUsers.length;
    count += boundary.delta;
    final userCount = (activeUsers[boundary.user] ?? 0) + boundary.delta;
    if (userCount == 0) {
      activeUsers.remove(boundary.user);
    } else {
      activeUsers[boundary.user] = userCount;
    }
    peak = max(peak, count);
    peakUsers = max(peakUsers, activeUsers.length);
    previous = boundary.time;
  }
  final window = boundaries.isEmpty ? 0 : boundaries.last.time - boundaries.first.time;
  return {
    'peakInFlightRounds': peak,
    'peakParticipatingUsers': peakUsers,
    'peakParticipatingDevices': peakUsers * devicesPerUser,
    'windowMicros': window,
    'meanInFlightRounds': window == 0 ? 0 : roundArea / window,
    'meanParticipatingDevices': window == 0 ? 0 : userArea * devicesPerUser / window,
    'scope':
        'First local write through last round completion; includes peer delivery and queueing.',
  };
}

bool cleanRoundServer(Map<String, dynamic> metrics) =>
    (metrics['streams'] as Map)['open'] == 0 &&
    !((metrics['storage'] as Map)['connections'] as List? ?? []).any(
      (dynamic row) =>
          (row['state'] as String? ?? '').startsWith('idle in transaction'),
    );

/// Drain the head observed on the first page, not a head that keeps moving as
/// active streams append diagnostics. The next sample resumes at the cursor.
Future<void> collectDiagnosticSnapshot({
  required Map<String, int> cursors,
  required Future<Map<String, dynamic>> Function() readPage,
  required void Function(Map<String, dynamic>) record,
}) async {
  int? target;
  String? source;
  for (var page = 0; page < 64; page++) {
    final response = await readPage();
    final instance = response['instanceId'] as String;
    target ??= response['latestSequence'] as int;
    source ??= instance;
    if (source != instance) {
      throw StateError('Server instance changed while collecting diagnostics.');
    }
    final previous = cursors[instance] ?? 0;
    if (previous > 0 && (response['oldestSequence'] as int) > previous + 1) {
      throw StateError('Server diagnostic records were evicted before collection.');
    }
    for (final raw in response['records'] as List) {
      record(raw as Map<String, dynamic>);
    }
    cursors[instance] = response['nextSequence'] as int;
    if (cursors[instance]! >= target) return;
  }
  throw StateError('Could not drain the initial server diagnostic snapshot.');
}

Future<void> runRounds(RoundOptions options) async {
  final secret = requireSecret();
  final directory = Directory(options.scale.directory);
  if (directory.existsSync()) {
    throw StateError('Run directory already exists: ${directory.path}');
  }
  await directory.create(recursive: true);
  await File(p.join(directory.path, 'owner')).create(exclusive: true);
  final events = File(p.join(directory.path, 'events.jsonl')).openWrite();
  final diagnostics = File(p.join(directory.path, 'workers.log')).openWrite();
  final admin = Client(options.scale.target)..authKeyProvider = BenchmarkAuth(secret);
  final workers = <WorkerProcess>[];
  final failures = <String>[];
  final measured = <Map<String, dynamic>>[];
  final calls = <Map<String, dynamic>>[];
  final workerMetrics = <Map<String, dynamic>>[];
  final completions = <Map<String, dynamic>>[];
  final serverSamples = <Map<String, dynamic>>[];
  final cursors = <String, int>{};
  final signals = <StreamSubscription<ProcessSignal>>[];
  final lag = LoopLag()..start();
  lag.marks['run'] = Latencies();
  var phase = 'preflight';
  var verified = 0;
  var measuredFailures = 0;
  var streamEnds = 0;
  var interrupted = false;
  Map<String, dynamic>? initial;
  Map<String, dynamic>? cleanup;
  Timer? sampler;
  Future<void>? sampleInFlight;

  void record(Map<String, dynamic> event) {
    final row = {
      'time': DateTime.now().toUtc().toIso8601String(),
      'runId': options.scale.runId,
      'phase': phase,
      ...event,
    };
    events.writeln(jsonEncode(row));
    if (row['type'] == 'round' && (row['round'] as int) >= 0) {
      measured.add(row);
      if (row['ok'] != true) measuredFailures++;
    }
    if (row['type'] == 'onceCall' && (row['round'] as int) >= 0) calls.add(row);
    if (row['type'] == 'workerExercise') workerMetrics.add(row);
    if (row['type'] == 'userCompleted') completions.add(row);
    if (row['type'] == 'verified') verified++;
    if (row['type'] == 'streamError' ||
        (row['type'] == 'streamEnded' && row['expected'] != true)) {
      streamEnds++;
    }
  }

  Future<void> collectDiagnostics({bool tail = false}) async {
    if (!options.scale.flag('sync-diagnostics')) return;
    await collectDiagnosticSnapshot(
      cursors: cursors,
      readPage: () => control(admin, {
        'action': 'diagnostics',
        'cursors': cursors,
        'tail': tail,
      }).timeout(const Duration(seconds: 30)),
      record: (event) {
        if (event['runId'] == options.scale.runId ||
            event['type'] == 'serverProcess' ||
            event['type'] == 'serverGc') {
          record(event);
        }
      },
    );
  }

  Future<Map<String, dynamic>> sample({bool exact = false}) async {
    final metrics = await control(admin, {
      'action': 'metrics',
      'exact': exact,
    }).timeout(const Duration(seconds: 30));
    final row = {'type': 'serverSample', 'phase': phase, ...metrics};
    serverSamples.add(row);
    record(row);
    if (initial != null &&
        (metrics['server'] as Map)['instanceId'] !=
            (initial['server'] as Map)['instanceId']) {
      throw StateError('Server instance changed during the run.');
    }
    return metrics;
  }

  try {
    initial = await sample(exact: true);
    if (!cleanRoundServer(initial)) {
      throw StateError('Server has existing streams or idle transactions.');
    }
    final actualSchema = (initial['server'] as Map)['benchmarkSchema'];
    if (actualSchema != options.values['schema']) {
      throw StateError(
        'Server schema $actualSchema differs from requested ${options.values['schema']}.',
      );
    }
    await collectDiagnostics(tail: true);
    await File(p.join(directory.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'options': options.values,
        'loadGenerator': await executableIdentity(),
        'server': initial['server'],
        'cpuCgroup': initial['cpuCgroup'],
        'workload':
            '${options.values['workload']} ${options.values['write-mode']}; '
            '${options.activeUsers} active users, ${options.number('users')} connected users.',
        'continuousBoundary':
            'Local transaction start to exact rows observed on every peer; warmup excluded.',
        'onceBoundary':
            'Fresh Client construction through syncOnce completion; SQLite stays open. Push then peer pulls.',
        'observer':
            'Public ORM watch, no throttle; includes local observation query overhead.',
        'schedule':
            '${options.values['schedule']} fixed-period schedule with a common worker origin; '
            'no overlapping rounds for one user; lateness retained.',
        'authentication': 'BENCHMARK_SECRET environment variable (not recorded)',
      }),
    );
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      signals.add(
        signal.watch().listen((_) {
          interrupted = true;
          for (final worker in workers) {
            worker.fail(StateError('Interrupted by $signal'));
            worker.process.kill(ProcessSignal.sigterm);
          }
        }),
      );
    }
    for (var index = 0; index < options.number('workers'); index++) {
      if (interrupted) throw StateError('Interrupted.');
      final args = Platform.script.path.endsWith('.dart')
          ? [...Platform.executableArguments, Platform.script.toFilePath(), '--worker']
          : ['--worker'];
      final process = await Process.start(Platform.resolvedExecutable, args);
      workers.add(WorkerProcess(index, process, record, diagnostics));
      record({'type': 'workerStarted', 'worker': index, 'pid': process.pid});
    }
    sampler = Timer.periodic(Duration(seconds: options.number('sample-seconds')), (_) {
      if (sampleInFlight != null) return;
      sampleInFlight = (() async {
        try {
          await sample();
          await collectDiagnostics();
        } on Object catch (error) {
          failures.add('Sampling failed: $error');
          record({'type': 'sampleError', 'error': '$error'});
        }
      })().whenComplete(() => sampleInFlight = null);
    });
    for (final next in ['init', 'warmup', 'exercise', 'probe', 'verify', 'close']) {
      if (interrupted) throw StateError('Interrupted.');
      phase = next;
      if (next == 'exercise') {
        await Future<void>.delayed(Duration(seconds: options.number('settle-seconds')));
      }
      record({'type': 'phaseStart'});
      stdout.writeln(
        '$phase: ${options.values['mode']}, ${options.scale.totalDevices} devices',
      );
      final deadline = next == 'exercise'
          ? max(
              options.number('idle-seconds') + 30,
              options.number('rounds') *
                      max<int>(
                        options.number('timeout-seconds') * 3,
                        (options.number('period-ms') / 1000).ceil(),
                      ) +
                  30,
            )
          : options.number('startup-timeout-seconds');
      final startMicros = next == 'exercise'
          ? ElapsedClock.timestampMicroseconds + 2000000
          : null;
      Future<void> dispatch(WorkerProcess worker) => worker.command(next, {
        if (next == 'init') 'options': options.values,
        'startMicros': ?startMicros,
      }, Duration(seconds: deadline));

      if (next == 'warmup') {
        await forEachBounded(workers, options.number('warmup-workers'), dispatch);
      } else {
        await Future.wait(workers.map(dispatch), eagerError: true);
      }
      record({'type': 'phaseEnd'});
      await sampleInFlight;
      final boundary = await sample();
      if (next == 'warmup' &&
          options.continuous &&
          (boundary['streams'] as Map)['open'] != options.scale.totalDevices) {
        throw StateError(
          'Expected ${options.scale.totalDevices} established streams: ${boundary['streams']}',
        );
      }
    }
    for (final worker in workers) {
      if (await worker.exit.timeout(const Duration(seconds: 10)) != 0) {
        throw StateError('Worker ${worker.index} exited unsuccessfully.');
      }
    }
  } on Object catch (error, stack) {
    failures.add('$error');
    record({'type': 'failure', 'error': '$error', 'stack': '$stack'});
  } finally {
    sampler?.cancel();
    await Future.wait(workers.map((w) => w.terminate()));
    for (final signal in signals) {
      await signal.cancel();
    }
    await sampleInFlight;
    phase = 'afterClose';
    try {
      final deadline = Stopwatch()..start();
      do {
        cleanup = await sample();
        if (cleanRoundServer(cleanup)) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      } while (deadline.elapsed < const Duration(seconds: 30));
      await collectDiagnostics();
      if (!cleanRoundServer(cleanup)) {
        failures.add('Server did not clean up within 30 seconds.');
      }
    } on Object catch (error) {
      failures.add('Cleanup observation failed: $error');
    }
    lag.stop();
    admin.close();
    if (verified != options.number('users')) {
      failures.add('Only $verified users passed exact verification.');
    }
    if (measured.length != options.activeUsers * options.number('rounds') ||
        measuredFailures > 0) {
      failures.add('Incomplete or failed measured rounds.');
    }
    if (streamEnds != 0) failures.add('$streamEnds unexpected stream ends.');
    final successes = measured.where((r) => r['ok'] == true).toList();
    final exerciseMicros = workerMetrics.isEmpty
        ? null
        : workerMetrics.map((worker) => worker['finishedMicros'] as int).reduce(max) -
              workerMetrics.map((worker) => worker['startedMicros'] as int).reduce(min);
    final completedRows = successes.fold<int>(
      0,
      (sum, round) => sum + (round['rows'] as int),
    );
    Map<String, dynamic> distribution(String key) =>
        roundDistribution(successes.map((r) => r[key] as num));
    final report = {
      'status': failures.isEmpty ? 'passed' : 'failed',
      'failures': failures,
      'options': options.values,
      'rounds': measured.length,
      'verifiedUsers': verified,
      'unexpectedStreamEnds': streamEnds,
      'writeToAllPeers': distribution('writeToAllPeersMicros'),
      'commitToAllPeers': distribution('commitToAllPeersMicros'),
      'localCommit': distribution('localCommitMicros'),
      'scheduleLag': distribution('scheduleLagMicros'),
      'scheduledToAllPeers': distribution('scheduledToAllPeersMicros'),
      'roundCompletion': distribution('completedMicros'),
      'concurrency': roundConcurrency(
        measured,
        devicesPerUser: options.number('devices-min'),
      ),
      'syncOnce': {
        for (final role in ['push', 'pull', 'all'])
          role: roundDistribution(
            calls
                .where((c) => c['ok'] == true && (role == 'all' || c['role'] == role))
                .map((c) => c['micros'] as num),
          ),
        'failures': calls.where((c) => c['ok'] != true).length,
      },
      'load': {
        'targetRoundsPerSecond':
            options.activeUsers * 1000 / options.number('period-ms'),
        'targetRowsPerSecond':
            options.activeUsers *
            options.number('rows') *
            1000 /
            options.number('period-ms'),
        'exerciseMicros': exerciseMicros,
        'completedRows': completedRows,
        'achievedRoundsPerSecond': exerciseMicros == null || exerciseMicros == 0
            ? null
            : successes.length * 1000000 / exerciseMicros,
        'achievedRowsPerSecond': exerciseMicros == null || exerciseMicros == 0
            ? null
            : completedRows * 1000000 / exerciseMicros,
        'domainPayloadBytes': successes.fold<int>(
          0,
          (sum, round) => sum + (round['payloadBytes'] as int),
        ),
        'connectedDevices': options.scale.totalDevices,
        'activeUsers': options.activeUsers,
        'participatingDevices': options.activeUsers * options.number('devices-min'),
        'schedule': options.values['schedule'],
        'keptUp':
            completions.length == options.activeUsers &&
            completions.every(
              (c) => (c['elapsedMicros'] as int) <= (c['budgetMicros'] as int),
            ),
        'users': completions,
      },
      'generator': {
        'workers': workerMetrics,
        'coordinatorLoopLag': lag.marks['run']!.toJson(),
      },
      'server': {
        'cpuCgroup': initial?['cpuCgroup'],
        'peakOpenStreams': serverSamples.isEmpty
            ? 0
            : serverSamples
                  .map((s) => (s['streams'] as Map)['open'] as int)
                  .reduce(max),
        'cleanup': cleanup,
      },
    };
    await events.flush();
    await events.close();
    await diagnostics.flush();
    await diagnostics.close();
    await File(
      p.join(directory.path, 'summary.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln('${report['status']}: ${p.join(directory.path, 'summary.json')}');
  }
  if (failures.isNotEmpty) throw StateError(failures.join('; '));
}
