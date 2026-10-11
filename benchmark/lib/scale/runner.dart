// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'common.dart';
import 'options.dart';

/// Bounded logarithmic histogram. Quantiles are bucket upper bounds, not exact
/// sample quantiles; the complete measurements remain in events.jsonl.
class Latencies {
  int count = 0;
  int failures = 0;
  int total = 0;
  int maximum = 0;
  final buckets = <int, int>{};

  void add(int micros, {required bool ok}) {
    count++;
    if (!ok) failures++;
    total += micros;
    maximum = max(maximum, micros);
    final bucket = micros <= 1 ? 1 : pow(1.1, (log(micros) / log(1.1)).ceil()).ceil();
    buckets.update(bucket, (v) => v + 1, ifAbsent: () => 1);
  }

  int quantile(double fraction) {
    final target = (count * fraction).ceil();
    var accumulated = 0;
    for (final bucket in buckets.keys.toList()..sort()) {
      accumulated += buckets[bucket]!;
      if (accumulated >= target) return bucket;
    }
    return 0;
  }

  Map<String, dynamic> toJson() => {
    'count': count,
    'failures': failures,
    'meanMicros': count == 0 ? 0 : total / count,
    'maxMicros': maximum,
    'p50UpperMicros': quantile(0.50),
    'p95UpperMicros': quantile(0.95),
    'p99UpperMicros': quantile(0.99),
  };
}

class WorkerProcess {
  WorkerProcess(this.index, this.process, this.record, this.diagnostics) {
    stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          if (!line.startsWith('@benchmark ')) {
            diagnostics.writeln('worker $index stdout: $line');
            return;
          }
          try {
            final event = jsonDecode(line.substring(11)) as Map<String, dynamic>;
            record({'worker': index, ...event});
            if (event['type'] == 'done' && event['phase'] == pendingPhase) {
              if (pending?.isCompleted == false) pending!.complete();
            } else if (event['type'] == 'fatal') {
              fail(StateError('Worker $index failed: ${event['error']}'));
            }
          } on Object catch (error) {
            fail(error);
          }
        });
    stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach((text) => diagnostics.write('worker $index stderr: $text'));
    exit = process.exitCode.then((code) async {
      await stdoutDone;
      if (pending?.isCompleted == false) {
        fail(StateError('Worker $index exited with $code during $pendingPhase.'));
      }
      return code;
    });
  }

  final int index;
  final Process process;
  final void Function(Map<String, dynamic>) record;
  final IOSink diagnostics;
  late final Future<void> stdoutDone;
  late final Future<void> stderrDone;
  late final Future<int> exit;
  Completer<void>? pending;
  String? pendingPhase;
  Object? failure;

  void fail(Object error) {
    failure ??= error;
    if (pending?.isCompleted == false) pending!.completeError(error);
  }

  Future<void> command(String phase, ScaleOptions options) async {
    if (failure != null) throw StateError(failure.toString());
    pendingPhase = phase;
    pending = Completer<void>();
    // Attach the timeout/error listener before writing to a possibly dead pipe.
    final result = pending!.future.timeout(
      Duration(
        seconds:
            options.number('timeout-seconds') +
            (phase == 'exercise' ? options.number('duration') : 0),
      ),
    );
    process.stdin.writeln(
      jsonEncode({
        'phase': phase,
        'worker': index,
        if (phase == 'init') 'options': options.values,
      }),
    );
    await result;
  }

  Future<void> terminate() async {
    process.kill(ProcessSignal.sigterm);
    try {
      await exit.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await exit;
    }
    await Future.wait([stdoutDone, stderrDone]);
  }
}

Future<void> runScale(ScaleOptions options) async {
  final secret = requireSecret();
  final directory = Directory(options.directory);
  if (directory.existsSync()) {
    throw StateError(
      'Run directory already exists: ${directory.path}. Choose a fresh --run-id.',
    );
  }
  await directory.create(recursive: true);
  final events = File(p.join(directory.path, 'events.jsonl')).openWrite();
  final diagnostics = File(p.join(directory.path, 'workers.log')).openWrite();
  final latencies = <String, Latencies>{};
  final states = <String, int>{};
  var convergedUsers = 0;
  var writes = 0;
  var streamErrors = 0;
  final workers = <WorkerProcess>[];
  final started = DateTime.now().toUtc();
  final phaseTimes = <String, int>{};
  final admin = Client(options.target)..authKeyProvider = BenchmarkAuth(secret);
  var phase = 'preflight';
  var status = 'failed';
  Object? failure;
  Timer? sampler;
  Future<void>? sampleInFlight;
  Object? sampleError;
  final signals = <StreamSubscription<ProcessSignal>>[];

  void record(Map<String, dynamic> event) {
    final row = {
      'time': DateTime.now().toUtc().toIso8601String(),
      'runId': options.runId,
      'phase': phase,
      ...event,
    };
    events.writeln(jsonEncode(row));
    if (event['type'] == 'latency') {
      final key = '${event['phase'] ?? phase}/${event['operation']}';
      (latencies[key] ??= Latencies()).add(
        event['micros'] as int,
        ok: event['ok'] as bool,
      );
    }
    if (event['type'] == 'convergence' && event['ok'] == true) convergedUsers++;
    if (event['type'] == 'operation' && event['kind'] != 'read') writes++;
    if (event['type'] == 'streamError' ||
        event['type'] == 'streamEnded' && event['expected'] == false) {
      streamErrors++;
    }
    if (event['type'] == 'state') {
      states.update(event['state'] as String, (v) => v + 1, ifAbsent: () => 1);
    }
  }

  Future<void> sample() async {
    try {
      final metrics = await control(admin, {
        'action': 'metrics',
      }).timeout(Duration(seconds: options.number('timeout-seconds')));
      record({'type': 'serverSample', ...metrics});
      record({'type': 'coordinatorSample', 'process': processSample()});
    } on Object catch (error) {
      sampleError = error;
      record({'type': 'serverSampleError', 'error': error.toString()});
    }
  }

  try {
    final revision = await Process.run('git', ['rev-parse', 'HEAD']);
    final gitStatus = await Process.run('git', ['status', '--porcelain']);
    await File(p.join(directory.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 1,
        'started': started.toIso8601String(),
        'options': options.values,
        'deviceCounts': {
          for (var u = 0; u < options.number('users'); u++) '$u': options.devicesFor(u),
        },
        'dartVersion': Platform.version,
        'os': Platform.operatingSystem,
        'processors': Platform.numberOfProcessors,
        'revision': revision.exitCode == 0 ? revision.stdout.toString().trim() : null,
        'workingTreeDirty': gitStatus.exitCode == 0
            ? gitStatus.stdout.toString().isNotEmpty
            : null,
        'authentication': 'BENCHMARK_SECRET environment variable (not recorded)',
      }),
    );
    await sample();
    if (sampleError != null) throw StateError(sampleError.toString());

    for (var index = 0; index < options.number('workers'); index++) {
      final args = Platform.script.path.endsWith('.dart')
          ? [...Platform.executableArguments, Platform.script.toFilePath(), '--worker']
          : ['--worker'];
      final process = await Process.start(Platform.resolvedExecutable, args);
      workers.add(WorkerProcess(index, process, record, diagnostics));
      record({'type': 'workerStarted', 'worker': index, 'pid': process.pid});
    }
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      signals.add(
        signal.watch().listen((_) {
          for (final worker in workers) {
            worker.fail(StateError('Interrupted by $signal'));
            worker.process.kill(ProcessSignal.sigterm);
          }
        }),
      );
    }
    sampler = Timer.periodic(Duration(seconds: options.number('sample-seconds')), (_) {
      if (sampleInFlight != null) return;
      sampleInFlight = sample().whenComplete(() => sampleInFlight = null);
    });

    for (final next in ['init', 'seed', 'exercise', 'verify', 'close']) {
      phase = next;
      final timer = Stopwatch()..start();
      stdout.writeln(
        '$next: ${options.number('users')} users, ${options.number('workers')} workers',
      );
      record({'type': 'phaseStart'});
      await Future.wait(workers.map((w) => w.command(next, options)), eagerError: true);
      phaseTimes[next] = timer.elapsedMicroseconds;
      record({'type': 'phaseEnd', 'micros': timer.elapsedMicroseconds});
      if (sampleError != null) throw StateError(sampleError.toString());
    }
    for (final worker in workers) {
      final code = await worker.exit.timeout(const Duration(seconds: 10));
      if (code != 0) throw StateError('Worker ${worker.index} exited with $code.');
    }
    if (convergedUsers != options.number('users')) {
      throw StateError('Not every user was verified.');
    }
    status = 'passed';
  } on Object catch (error, stack) {
    failure = error;
    record({'type': 'failure', 'error': error.toString(), 'stack': stack.toString()});
  } finally {
    sampler?.cancel();
    await sampleInFlight;
    for (final signal in signals) {
      await signal.cancel();
    }
    await Future.wait(workers.map((w) => w.terminate()));
    phase = 'afterClose';
    await sample();
    if (sampleError != null) {
      status = 'failed';
      failure ??= sampleError;
    }
    admin.close();
    await events.flush();
    await events.close();
    await diagnostics.flush();
    await diagnostics.close();
    final summary = {
      'schemaVersion': 1,
      'status': status,
      'error': failure?.toString(),
      'runId': options.runId,
      'started': started.toIso8601String(),
      'finished': DateTime.now().toUtc().toIso8601String(),
      'users': options.number('users'),
      'devices': List.generate(
        options.number('users'),
        options.devicesFor,
      ).fold<int>(0, (a, b) => a + b),
      'convergedUsers': convergedUsers,
      'committedWrites': writes,
      'workloadWritesPerSecond': writes / ((phaseTimes['exercise'] ?? 1) / 1000000),
      'unexpectedStreamTerminations': streamErrors,
      'stateTransitions': states,
      'phaseMicros': phaseTimes,
      'latencies': {
        for (final entry in latencies.entries) entry.key: entry.value.toJson(),
      },
    };
    await File(
      p.join(directory.path, 'summary.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
    stdout.writeln('$status: ${p.join(directory.path, 'summary.json')}');
  }
  if (failure != null) throw StateError('Benchmark failed: $failure');
}
