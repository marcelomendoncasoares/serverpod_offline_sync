// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:math';

import 'common.dart';
import 'options.dart';

/// Heuristic thresholds for flagging the load generator. They indicate where to
/// look, not proof: a busy host, garbage collection or slow local storage all
/// show up the same way.
const lagSaturationMicros = 100000;
const shortfallRatio = 0.8;

/// Folds every recorded event into the run summary and judges run policies.
class SummaryBuilder {
  SummaryBuilder(this.options);

  final ScaleOptions options;
  final latencies = <String, Latencies>{};
  final phaseMicros = <String, int>{};
  final boundary = <String, Map<String, dynamic>>{};
  var convergedUsers = 0;
  var maxConvergenceMicros = 0;
  var maxConvergenceRounds = 0;
  var operationAttempts = 0;
  var reads = 0;
  final writesByState = <String, int>{};
  final initialAssignments = <String, int>{};
  final assignments = <String, int>{};
  final transitions = <String, int>{};
  final deviceSeconds = <String, double>{};
  final streamCounts = <String, int>{
    'unexpectedEnds': 0,
    'errors': 0,
    'reconnectsScheduled': 0,
    'reconnects': 0,
  };
  final samplesOk = <String, int>{'periodic': 0, 'boundary': 0};
  final samplesFailed = <String, int>{'periodic': 0, 'boundary': 0};
  var workerSampleErrors = 0;
  var workerSamplesOk = 0;
  String? lastSampleError;
  final generator = <int, Map<String, dynamic>>{};
  final peaks = <int, Map<String, int>>{};
  final baselines = <int, Map<String, dynamic>>{};
  Map<String, dynamic>? coordinatorLoopLag;
  Map<String, dynamic>? coordinatorExerciseLoopLag;

  void _count(String key) => streamCounts.update(key, (v) => v + 1);

  int get writes => writesByState.values.fold(0, (a, b) => a + b);

  int get unexpectedStreamEnds => streamCounts['unexpectedEnds']!;

  int get telemetryFailures =>
      samplesFailed.values.fold(0, (a, b) => a + b) + workerSampleErrors;

  void add(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'latency':
        final key = '${event['phase']}/${event['operation']}';
        (latencies[key] ??= Latencies()).add(
          event['micros'] as int,
          ok: event['ok'] as bool,
        );
      case 'phaseEnd':
        phaseMicros[event['phase'] as String] = event['micros'] as int;
      case 'convergence' when event['ok'] == true:
        convergedUsers++;
        maxConvergenceMicros = max(maxConvergenceMicros, event['micros'] as int);
        maxConvergenceRounds = max(maxConvergenceRounds, event['rounds'] as int);
      case 'operation':
        operationAttempts++;
        if (event['kind'] == 'read') {
          reads++;
        } else {
          writesByState.update(
            event['state'] as String,
            (v) => v + 1,
            ifAbsent: () => 1,
          );
        }
      case 'assignment':
        final state = event['state'] as String;
        assignments.update(state, (v) => v + 1, ifAbsent: () => 1);
        if (event['initial'] == true) {
          initialAssignments.update(state, (v) => v + 1, ifAbsent: () => 1);
        }
      case 'state':
        transitions.update(event['state'] as String, (v) => v + 1, ifAbsent: () => 1);
      case 'residency':
        for (final entry in (event['seconds'] as Map).entries) {
          deviceSeconds.update(
            entry.key as String,
            (v) => v + (entry.value as num),
            ifAbsent: () => (entry.value as num).toDouble(),
          );
        }
      // Stream counts come from the individual events, which exist even when
      // a device never reaches its residency report.
      case 'streamError':
        _count('errors');
        _count('unexpectedEnds');
      case 'streamEnded' when event['expected'] == false:
        _count('unexpectedEnds');
      case 'streamReconnectScheduled':
        _count('reconnectsScheduled');
      case 'streamStarted' when event['reconnect'] == true:
        _count('reconnects');
      case 'serverSample':
        samplesOk.update(event['sampleKind'] as String, (v) => v + 1);
        if (event['sampleKind'] == 'boundary') {
          boundary[event['phase'] as String] = event;
        }
      case 'serverSampleError':
        lastSampleError = event['error'] as String?;
        // A failed preflight aborts the run on its own.
        if (event['phase'] != 'preflight') {
          samplesFailed.update(event['sampleKind'] as String, (v) => v + 1);
        }
      case 'workerSample':
        workerSamplesOk++;
        final process = event['process'] as Map<String, dynamic>;
        final peak = peaks[event['worker'] as int] ??= {};
        for (final key in ['rssBytes', 'openFds', 'threads']) {
          if (process[key] is int) {
            peak.update(
              key,
              (v) => max(v, process[key] as int),
              ifAbsent: () => process[key] as int,
            );
          }
        }
      case 'workerSampleError':
        workerSampleErrors++;
      case 'workerBaseline':
        baselines[event['worker'] as int] = event['process'] as Map<String, dynamic>;
      case 'generatorExercise':
        generator[event['worker'] as int] = event;
      case 'coordinatorLoopLag':
        coordinatorLoopLag = event['loopLag'] as Map<String, dynamic>;
      case 'coordinatorExerciseLoopLag':
        coordinatorExerciseLoopLag = event['loopLag'] as Map<String, dynamic>;
    }
  }

  /// Run-level conditions beyond worker and phase failures.
  List<String> policyFailures() {
    final users = options.number('users');
    final maxStreamEnds = options.number('max-unexpected-stream-ends');
    final maxSampleFailures = options.number('max-sample-failures');
    final last = lastSampleError == null ? '' : ' (last: $lastSampleError)';
    final streams =
        '$unexpectedStreamEnds unexpected stream ends or errors exceed '
        '--max-unexpected-stream-ends $maxStreamEnds.';
    final telemetry =
        '$telemetryFailures failed samples exceed '
        '--max-sample-failures $maxSampleFailures$last.';
    return [
      if (phaseMicros.containsKey('verify') && convergedUsers != users)
        'Only $convergedUsers of $users users converged.',
      if (unexpectedStreamEnds > maxStreamEnds) streams,
      if (telemetryFailures > maxSampleFailures) telemetry,
    ];
  }

  double? _seconds(String phase) {
    final micros = phaseMicros[phase];
    return micros == null ? null : micros / 1e6;
  }

  /// Per-instance counters differenced between boundary samples taken at the
  /// end of [from] and the end of [to]. Exact row counts on both sides.
  Map<String, dynamic>? serverDelta(String from, String to) {
    final a = boundary[from];
    final b = boundary[to];
    if (a == null || b == null) return null;
    final instanceA = (a['server'] as Map?)?['instanceId'];
    if (instanceA == null || instanceA != (b['server'] as Map?)?['instanceId']) {
      return {
        'sameInstance': false,
        'note': 'Boundary samples came from different server instances.',
      };
    }
    // Rates use the samples' own interval: boundary samples are taken after
    // each phase ends, not at its start.
    final seconds =
        DateTime.parse(
          b['time'] as String,
        ).difference(DateTime.parse(a['time'] as String)).inMicroseconds /
        1e6;
    Map<String, num> diff(String key) {
      final before = a[key] as Map<String, dynamic>;
      final after = b[key] as Map<String, dynamic>;
      return {
        for (final entry in after.entries)
          if (entry.value is num && before[entry.key] is num)
            entry.key: (entry.value as num) - (before[entry.key] as num),
      };
    }

    // Cumulative counters only; open/active/idle are point-in-time gauges.
    final streams = diff('streams')
      ..remove('activityWindowMs')
      ..remove('open')
      ..remove('active')
      ..remove('idle');
    return {
      'sameInstance': true,
      'seconds': seconds,
      'streams': streams,
      'inboundChangesPerSecond': seconds <= 0
          ? null
          : (streams['inboundChanges'] ?? 0) / seconds,
      'outboundChangesPerSecond': seconds <= 0
          ? null
          : (streams['outboundChanges'] ?? 0) / seconds,
      'rowsAdded': diff('tables'),
      'storageBytesDelta': diff('storage'),
    };
  }

  Map<String, dynamic>? _lagSummary(Map<String, dynamic>? lag) =>
      lag == null ? null : {'p99Upper': lag['p99UpperMicros'], 'max': lag['maxMicros']};

  double? _perDevice(int? peak, Object? baseline, int devices) =>
      peak == null || baseline is! int ? null : (peak - baseline) / max(1, devices);

  Map<String, dynamic> _generator(double? nominal, int attempts) {
    final reasons = <String>[];
    final workers = <Map<String, dynamic>>[];
    for (final entry in (generator.keys.toList()..sort()).map(
      (w) => MapEntry(w, generator[w]!),
    )) {
      final lag = entry.value['loopLag'] as Map<String, dynamic>;
      final p99 = lag['p99UpperMicros'] as int?;
      final devices = entry.value['devices'] as int;
      final peak = peaks[entry.key] ?? {};
      if (p99 != null && p99 > lagSaturationMicros) {
        reasons.add('worker ${entry.key} event-loop lag p99 <= ${p99 ~/ 1000} ms');
      }
      workers.add({
        'worker': entry.key,
        'devices': devices,
        'cpuCores': entry.value['cpuCores'],
        'loopLagMicros': {
          'p50Upper': lag['p50UpperMicros'],
          'p99Upper': p99,
          'max': lag['maxMicros'],
        },
        'nominalOperationAttempts': entry.value['nominalOperationAttempts'],
        'operationAttempts': entry.value['operationAttempts'],
        'peakRssBytes': peak['rssBytes'],
        'peakOpenFds': peak['openFds'],
        'peakThreads': peak['threads'],
        'baselineRssBytes': baselines[entry.key]?['rssBytes'],
        'baselineOpenFds': baselines[entry.key]?['openFds'],
        // Marginal cost: peak minus the process before any device opened.
        'rssBytesPerDevice': _perDevice(
          peak['rssBytes'],
          baselines[entry.key]?['rssBytes'],
          devices,
        ),
        'openFdsPerDevice': _perDevice(
          peak['openFds'],
          baselines[entry.key]?['openFds'],
          devices,
        ),
      });
    }
    // Only the workload window is saturation evidence; whole-run lag also
    // covers setup, verification and report writing.
    final coordinatorP99 = coordinatorExerciseLoopLag?['p99UpperMicros'] as int?;
    if (coordinatorP99 != null && coordinatorP99 > lagSaturationMicros) {
      reasons.add('coordinator event-loop lag p99 <= ${coordinatorP99 ~/ 1000} ms');
    }
    final lagged = reasons.isNotEmpty;
    final expected = options.number('workers');
    final missing = expected - generator.length;
    if (missing > 0) {
      reasons.add('$missing of $expected workers reported no workload measurements');
    }
    final ratio = nominal == null || nominal == 0 ? null : attempts / nominal;
    final shortfall = ratio != null && ratio < shortfallRatio;
    return {
      'assessment': missing > 0
          ? 'insufficient measurements'
          : lagged
          ? 'possible generator saturation'
          : shortfall
          ? 'offered load shortfall'
          : 'no saturation signal',
      'reasons': [
        ...reasons,
        if (shortfall)
          'achieved ${(ratio * 100).toStringAsFixed(0)}% of nominal operation attempts',
      ],
      'thresholds': {
        'loopLagP99Micros': lagSaturationMicros,
        'achievedRatio': shortfallRatio,
      },
      'note':
          'Heuristic. Event-loop lag means the isolate running device logic was '
          'busy. cpuCores is whole-process CPU, including SQLite helper isolates '
          'and VM threads, so it is not saturation evidence by itself. A shortfall '
          'without lag usually means slow operations in the closed loop. '
          'Calibrate devices per worker before trusting latencies.',
      'workers': workers,
      'coordinatorWorkloadLoopLagMicros': _lagSummary(coordinatorExerciseLoopLag),
      // Informational: includes setup, verification and report writing.
      'coordinatorRunLoopLagMicros': _lagSummary(coordinatorLoopLag),
    };
  }

  Map<String, dynamic> build({
    required String status,
    required List<String> failures,
    required DateTime started,
  }) {
    final exerciseSeconds = _seconds('exercise');
    final nominal = generator.isEmpty
        ? null
        : generator.values.fold<double>(
            0,
            (sum, e) => sum + (e['nominalOperationAttempts'] as num),
          );
    final generatorAttempts = generator.values.fold<int>(
      0,
      (sum, e) => sum + (e['operationAttempts'] as int),
    );
    return {
      'schemaVersion': 2,
      'status': status,
      'failures': failures,
      'runId': options.runId,
      'started': started.toIso8601String(),
      'finished': DateTime.now().toUtc().toIso8601String(),
      'users': options.number('users'),
      'devices': options.totalDevices,
      'convergedUsers': convergedUsers,
      'convergence': {
        'maxMicros': convergedUsers == 0 ? null : maxConvergenceMicros,
        'maxRounds': convergedUsers == 0 ? null : maxConvergenceRounds,
      },
      'phaseMicros': phaseMicros,
      'operations': {
        'attempts': operationAttempts,
        'reads': reads,
        'localCommittedWrites': writes,
        'localCommittedWritesByState': writesByState,
        'localCommittedWritesPerSecond': exerciseSeconds == null
            ? null
            : writes / exerciseSeconds,
        'note':
            'Local SQLite commits during the workload. Offline writes reach the '
            'server only after a reconnect or verification; see server deltas.',
      },
      'server': {
        'workload': serverDelta('seed', 'exercise'),
        'verificationDrain': serverDelta('exercise', 'verify'),
      },
      'load': {
        'nominalOperationAttempts': nominal,
        'operationAttempts': generator.isEmpty ? null : generatorAttempts,
        'achievedRatio': nominal == null || nominal == 0
            ? null
            : generatorAttempts / nominal,
        'note':
            'Nominal attempts = writer-state residency / mean think time; the '
            'closed loop also spends time on operations and transitions.',
      },
      'generator': _generator(nominal, generatorAttempts),
      'deviceStates': {
        'initialAssignments': initialAssignments,
        'assignments': assignments,
        'transitions': transitions,
        'deviceSeconds': deviceSeconds,
      },
      'streams': {
        ...streamCounts,
        'maxUnexpectedStreamEnds': options.number('max-unexpected-stream-ends'),
      },
      'telemetry': {
        'serverSamplesOk': samplesOk,
        'serverSamplesFailed': samplesFailed,
        'workerSamplesOk': workerSamplesOk,
        'workerSampleErrors': workerSampleErrors,
        'maxSampleFailures': options.number('max-sample-failures'),
        'complete': telemetryFailures == 0,
      },
      'latencies': {
        for (final entry in latencies.entries) entry.key: entry.value.toJson(),
      },
    };
  }
}
