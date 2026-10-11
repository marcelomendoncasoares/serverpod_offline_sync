// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'common.dart';
import 'options.dart';
import 'summary.dart';

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
              if (event['phase'] == 'close') closed = true;
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
      exited = code;
      record({
        'type': 'workerExit',
        'worker': index,
        'pid': process.pid,
        'exitCode': code,
      });
      // Any exit before the close phase completed is a failure, even between
      // phases, so the next command cannot wait for its whole deadline.
      if (!closed) {
        fail(
          StateError(
            'Worker $index exited with code $code before completing the close phase '
            '(last phase: ${pendingPhase ?? 'none'}).',
          ),
        );
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
  int? exited;
  bool closed = false;

  void fail(Object error) {
    failure ??= error;
    if (pending?.isCompleted == false) pending!.completeError(error);
  }

  Future<void> command(
    String phase,
    Map<String, dynamic> message,
    Duration timeout,
  ) async {
    if (failure != null) throw StateError(failure.toString());
    pendingPhase = phase;
    pending = Completer<void>();
    // Attach the timeout/error listener before writing to a possibly dead pipe.
    final result = pending!.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Worker $index did not finish $phase within ${timeout.inSeconds} s.',
        timeout,
      ),
    );
    process.stdin.writeln(jsonEncode({'phase': phase, 'worker': index, ...message}));
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

Duration phaseTimeout(String phase, ScaleOptions options) => Duration(
  seconds: switch (phase) {
    'init' || 'seed' => options.number('startup-timeout-seconds'),
    'exercise' => options.number('duration') + options.number('timeout-seconds'),
    // Workers stop retrying at the convergence deadline; leave room to report.
    'verify' => options.number('timeout-seconds') + 30,
    _ => options.number('timeout-seconds'),
  },
);

/// Rough per-device costs measured on Linux x64 with serverpod_database
/// 4.1.0-beta.3: SQLite opens a writer plus a reader pool per database.
const estimatedFdsPerDevice = 25;
const estimatedRssBytesPerDevice = 6 * 1024 * 1024;

List<String> resourceWarnings(ScaleOptions options) {
  final warnings = <String>[];
  if (!Platform.isLinux) return warnings;
  final perWorker = options.maxDevicesPerWorker;
  try {
    final limits = File('/proc/self/limits').readAsLinesSync();
    final line = limits.firstWhere((l) => l.startsWith('Max open files'));
    final soft = int.tryParse(line.split(RegExp(r'\s{2,}'))[1]);
    final needed = perWorker * estimatedFdsPerDevice + 64;
    if (soft != null && needed > soft) {
      warnings.add(
        'Up to $perWorker devices per worker need about $needed file descriptors '
        '(~$estimatedFdsPerDevice per device), above the soft limit of $soft. '
        'Raise `ulimit -n` or add workers.',
      );
    }
  } on Object catch (error) {
    warnings.add('Could not read the open file limit: $error');
  }
  try {
    final meminfo = File('/proc/meminfo').readAsStringSync();
    final match = RegExp(
      r'^MemAvailable:\s+(\d+) kB',
      multiLine: true,
    ).firstMatch(meminfo);
    final available = match == null ? null : int.parse(match.group(1)!) * 1024;
    final needed = options.totalDevices * estimatedRssBytesPerDevice;
    if (available != null && needed > available) {
      warnings.add(
        '${options.totalDevices} devices need roughly ${needed ~/ (1 << 20)} MiB of '
        'worker memory (~${estimatedRssBytesPerDevice ~/ (1 << 20)} MiB each), above '
        'the ${available ~/ (1 << 20)} MiB available.',
      );
    }
  } on Object catch (error) {
    warnings.add('Could not read available memory: $error');
  }
  return warnings;
}

bool _isLoopback(String host) =>
    host == 'localhost' || host == '::1' || host == '[::1]' || host.startsWith('127.');

Future<void> runScale(ScaleOptions options) async {
  if (Platform.isWindows) {
    throw UnsupportedError(
      'Windows load generators are not supported. Linux is validated; macOS is untested.',
    );
  }
  final secret = requireSecret();
  final target = Uri.parse(options.target);
  if (target.scheme == 'http' && !_isLoopback(target.host)) {
    stderr.writeln(
      'Warning: BENCHMARK_SECRET is sent unencrypted to ${target.host}. Use https.',
    );
  }
  final directory = Directory(options.directory);
  if (directory.existsSync()) {
    throw StateError(
      'Run directory already exists: ${directory.path}. Choose a fresh --run-id.',
    );
  }
  await directory.create(recursive: true);
  // Exclusive ownership also rejects simultaneous invocations of the same ID.
  await File(p.join(directory.path, 'owner')).create(exclusive: true);
  final events = File(p.join(directory.path, 'events.jsonl')).openWrite();
  final diagnostics = File(p.join(directory.path, 'workers.log')).openWrite();
  final summary = SummaryBuilder(options);
  final workers = <WorkerProcess>[];
  final started = DateTime.now().toUtc();
  final admin = Client(options.target)..authKeyProvider = BenchmarkAuth(secret);
  final lag = LoopLag()..start();
  lag.marks['run'] = Latencies();
  var phase = 'preflight';
  final failures = <String>[];
  Timer? sampler;
  Future<void>? sampleInFlight;
  var interrupted = false;
  var preflightOk = false;
  final signals = <StreamSubscription<ProcessSignal>>[];

  void record(Map<String, dynamic> event) {
    final row = {
      'time': DateTime.now().toUtc().toIso8601String(),
      'runId': options.runId,
      'phase': phase,
      ...event,
    };
    events.writeln(jsonEncode(row));
    summary.add(row);
  }

  /// Server samples never throw: failures are recorded and judged by policy.
  /// Boundary samples count rows exactly; periodic ones use estimates.
  Future<Map<String, dynamic>?> sample({required bool boundary}) async {
    try {
      final metrics = await control(admin, {
        'action': 'metrics',
        'exact': boundary,
      }).timeout(Duration(seconds: options.number('timeout-seconds')));
      record({
        'type': 'serverSample',
        'sampleKind': boundary ? 'boundary' : 'periodic',
        ...metrics,
      });
      record({
        'type': 'coordinatorSample',
        'process': processSample(),
        'loopLag': lag.takeWindow(),
      });
      return metrics;
    } on Object catch (error) {
      record({
        'type': 'serverSampleError',
        'sampleKind': boundary ? 'boundary' : 'periodic',
        'error': error.toString(),
      });
      return null;
    }
  }

  try {
    final warnings = resourceWarnings(options);
    for (final warning in warnings) {
      stderr.writeln('Warning: $warning');
    }
    final preflight = await sample(boundary: true);
    preflightOk = preflight != null;
    if (preflight == null) {
      throw StateError(
        'Preflight metrics failed; check --target and BENCHMARK_SECRET: '
        '${summary.lastSampleError}',
      );
    }
    await File(p.join(directory.path, 'manifest.json')).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 2,
        'started': started.toIso8601String(),
        'options': options.values,
        'deviceCounts': {
          for (var u = 0; u < options.number('users'); u++) '$u': options.devicesFor(u),
        },
        'devicesPerWorker': [
          for (var w = 0; w < options.number('workers'); w++)
            options.devicesOfWorker(w),
        ],
        'dartVersion': Platform.version,
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'processors': Platform.numberOfProcessors,
        'loadGenerator': await executableIdentity(),
        // Only describes the directory the command ran in, which need not be
        // the checkout the load generator was built from.
        'invocationDirectory': await gitMetadata(Directory.current.path),
        'server': preflight['server'],
        'resourceWarnings': warnings,
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
      if (interrupted) throw StateError('Interrupted during worker startup.');
      final args = Platform.script.path.endsWith('.dart')
          ? [...Platform.executableArguments, Platform.script.toFilePath(), '--worker']
          : ['--worker'];
      final process = await Process.start(Platform.resolvedExecutable, args);
      workers.add(WorkerProcess(index, process, record, diagnostics));
      record({'type': 'workerStarted', 'worker': index, 'pid': process.pid});
    }
    sampler = Timer.periodic(Duration(seconds: options.number('sample-seconds')), (_) {
      if (sampleInFlight != null) return;
      sampleInFlight = sample(
        boundary: false,
      ).whenComplete(() => sampleInFlight = null);
    });

    for (final next in ['init', 'seed', 'exercise', 'verify', 'close']) {
      if (interrupted) throw StateError('Interrupted.');
      phase = next;
      final timer = Stopwatch()..start();
      stdout.writeln(
        '$next: ${options.number('users')} users, ${options.number('workers')} workers',
      );
      record({'type': 'phaseStart'});
      if (next == 'exercise') lag.marks['exercise'] = Latencies();
      await Future.wait(
        workers.map(
          (w) => w.command(next, {
            if (next == 'init') 'options': options.values,
          }, phaseTimeout(next, options)),
        ),
        eagerError: true,
      );
      record({'type': 'phaseEnd', 'micros': timer.elapsedMicroseconds});
      if (next == 'exercise') {
        record({
          'type': 'coordinatorExerciseLoopLag',
          'loopLag': lag.marks.remove('exercise')!.toJson(),
        });
      }
      await sample(boundary: true);
    }
    for (final worker in workers) {
      final code = await worker.exit.timeout(const Duration(seconds: 10));
      if (code != 0) throw StateError('Worker ${worker.index} exited with $code.');
    }
  } on Object catch (error, stack) {
    failures.add(error.toString());
    record({'type': 'failure', 'error': error.toString(), 'stack': stack.toString()});
  } finally {
    sampler?.cancel();
    // Stop the load before waiting on telemetry, which may take a full timeout.
    await Future.wait(workers.map((w) => w.terminate()));
    for (final signal in signals) {
      await signal.cancel();
    }
    await sampleInFlight;
    phase = 'afterClose';
    if (preflightOk) {
      // Streams of abruptly stopped workers take a moment to close server-side.
      if (workers.any((w) => !w.closed)) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await sample(boundary: true);
    }
    lag.stop();
    record({'type': 'coordinatorLoopLag', 'loopLag': lag.marks['run']!.toJson()});
    admin.close();
    await events.flush();
    await events.close();
    await diagnostics.flush();
    await diagnostics.close();
    failures.addAll(summary.policyFailures());
    final report = summary.build(
      status: failures.isEmpty ? 'passed' : 'failed',
      failures: failures,
      started: started,
    );
    await File(
      p.join(directory.path, 'summary.json'),
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    stdout.writeln(
      '${report['status']}: ${p.join(directory.path, 'summary.json')}',
    );
    final assessment = (report['generator'] as Map)['assessment'];
    if (assessment != 'no saturation signal') {
      stdout.writeln('Load generator: $assessment; see summary.generator.');
    }
  }
  if (failures.isNotEmpty) {
    throw StateError('Benchmark failed: ${failures.join('; ')}');
  }
}
