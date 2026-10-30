import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/compression_probe.dart';
import 'package:serverpod_offline_sync_benchmark/scale/elapsed_clock.dart';
import 'package:serverpod_offline_sync_benchmark/scale/idle_connection.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runner.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--worker')) {
    await runWorker();
    return;
  }
  final parser = ArgParser()
    ..addOption('target', mandatory: true)
    ..addOption('output', mandatory: true)
    ..addOption('run-id', mandatory: true)
    ..addOption(
      'transport-compression',
      allowed: ['sdk', 'enabled', 'disabled'],
      defaultsTo: Platform.environment['BENCHMARK_WEBSOCKET_COMPRESSION'] ?? 'sdk',
    )
    ..addOption('connections', defaultsTo: '64')
    ..addOption('workers', defaultsTo: '8')
    ..addOption('open-workers', defaultsTo: '4')
    ..addOption('open-concurrency-per-worker', defaultsTo: '1')
    ..addOption('idle-seconds', defaultsTo: '45')
    ..addOption('settle-seconds', defaultsTo: '5')
    ..addOption('timeout-seconds', defaultsTo: '30')
    ..addOption('phase-timeout-seconds', defaultsTo: '3600')
    ..addOption('payload-bytes', defaultsTo: '128')
    ..addOption('sample-seconds', defaultsTo: '5');
  final parsed = parser.parse(args);
  if (parsed.rest.isNotEmpty) throw ArgumentError('Unexpected arguments.');
  final options = <String, dynamic>{};
  for (final key in parser.options.keys) {
    if (['target', 'output', 'run-id', 'transport-compression'].contains(key)) {
      options[key] = parsed[key] as String;
    } else {
      final value = int.parse(parsed[key] as String);
      if (value < 1) throw ArgumentError('$key must be positive.');
      options[key] = value;
    }
  }
  options['workers'] = min(options['connections'] as int, options['workers'] as int);
  await runCoordinator(options);
}

Future<void> runWorker() async {
  final connections = <int, IdleConnection>{};
  var phase = 'init';
  var options = <String, dynamic>{};
  final failures = <String>[];
  final lag = LoopLag()..start();
  Timer? sampler;

  void emit(Map<String, dynamic> event) {
    stdout.writeln(
      '@benchmark ${jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'phase': phase,
        ...event,
      })}',
    );
  }

  String payload(int id, String stage) {
    final prefix = '${options['run-id']}/$id/$stage/';
    return prefix.padRight(options['payload-bytes'] as int, 'x');
  }

  try {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final command = jsonDecode(line) as Map<String, dynamic>;
      phase = command['phase'] as String;
      switch (phase) {
        case 'init':
          options = command['options'] as Map<String, dynamic>;
          sampler = Timer.periodic(
            Duration(seconds: options['sample-seconds'] as int),
            (_) {
              emit({
                'type': 'workerSample',
                'process': processSample(),
                'loopLag': lag.takeWindow(),
              });
            },
          );
        case 'open':
          final index = command['worker'] as int;
          final workers = options['workers'] as int;
          final identities = [
            for (var id = index; id < (options['connections'] as int); id += workers)
              id,
          ];
          await forEachBounded(
            identities,
            options['open-concurrency-per-worker'] as int,
            (id) async {
              if (failures.isNotEmpty) throw StateError(failures.first);
              final client = Client(options['target'] as String)
                ..authKeyProvider = BenchmarkAuth(requireSecret());
              final input = StreamController<String>();
              final compression = options['transport-compression'] as String;
              final probe = compression == 'sdk'
                  ? null
                  : CompressionProbe(
                      target: options['target'] as String,
                      compression: compression == 'enabled',
                      serializationManager: client.serializationManager,
                      authKeyProvider: client.authKeyProvider!,
                      input: input.stream,
                      connectionTimeout: client.streamingConnectionTimeout,
                    );
              final responses =
                  probe?.output.stream ??
                  client.callStreamingServerEndpoint<Stream<String>, String>(
                        'benchmark',
                        'echo',
                        {},
                        {'messages': input.stream},
                      )
                      as Stream<String>;
              final connection = connections[id] = IdleConnection(
                responses: responses,
                send: input.add,
                closeInput: input.close,
                closeClient: () {
                  client.close();
                  if (probe != null) {
                    unawaited(
                      probe.close().catchError((Object error) {
                        failures.add('$id: $error');
                        emit({
                          'type': 'streamFailure',
                          'connection': id,
                          'error': '$error',
                        });
                      }),
                    );
                  }
                },
                timeout: Duration(seconds: options['timeout-seconds'] as int),
                onFailure: (error) {
                  failures.add('$id: $error');
                  emit({
                    'type': 'streamFailure',
                    'connection': id,
                    'error': '$error',
                    if (probe != null) 'upgradeHttpStatus': probe.httpStatusCode,
                  });
                },
              );
              final micros = await connection.exchange(payload(id, 'warmup'));
              emit({
                'type': 'opened',
                'connection': id,
                'micros': micros,
                'compressionMode': compression,
                if (probe != null) 'negotiatedExtensions': probe.extensions,
                if (probe != null) 'upgradeHttpStatus': probe.httpStatusCode,
              });
            },
          );
        case 'idle':
          final origin = command['startMicros'] as int;
          await ElapsedClock.waitUntil(origin);
          final startCpu = cpuSeconds();
          final clock = ElapsedClock()..start();
          await ElapsedClock.waitUntil(
            origin + (options['idle-seconds'] as int) * 1000000,
          );
          final endCpu = cpuSeconds();
          emit({
            'type': 'workerIdle',
            'micros': clock.elapsedMicroseconds,
            'cpuCores': startCpu == null || endCpu == null
                ? null
                : (endCpu - startCpu) * 1000000 / clock.elapsedMicroseconds,
            'process': processSample(),
            'loopLag': lag.takeWindow(),
          });
        case 'probe':
          for (final entry in connections.entries) {
            final micros = await entry.value.exchange(payload(entry.key, 'resume'));
            emit({'type': 'probe', 'connection': entry.key, 'micros': micros});
          }
        case 'close':
          // Bound shutdown independently of the resident connection count.
          await forEachBounded(
            connections.values,
            8,
            (connection) => connection.close(),
          );
          sampler?.cancel();
          lag.stop();
      }
      if (failures.isNotEmpty) throw StateError(failures.first);
      emit({'type': 'done'});
      if (phase == 'close') return;
    }
  } on Object catch (error, stack) {
    emit({'type': 'fatal', 'error': '$error', 'stack': '$stack'});
    sampler?.cancel();
    lag.stop();
    for (final connection in connections.values) {
      connection.closeClient();
    }
    exitCode = 1;
  }
}

Map<String, dynamic>? distribution(Iterable<int> samples) {
  final values = samples.toList()..sort();
  if (values.isEmpty) return null;
  return {
    'count': values.length,
    'minMs': values.first / 1000,
    'medianMs':
        (values.length.isOdd
            ? values[values.length ~/ 2].toDouble()
            : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2) /
        1000,
    'meanMs': values.reduce((a, b) => a + b) / values.length / 1000,
    'p95Ms': values[(values.length * .95).ceil() - 1] / 1000,
    'maxMs': values.last / 1000,
  };
}

Future<void> runCoordinator(Map<String, dynamic> options) async {
  final directory = Directory(options['output'] as String);
  if (directory.existsSync()) throw StateError('Choose a fresh output directory.');
  await directory.create(recursive: true);
  final events = File('${directory.path}/events.jsonl').openWrite();
  final logs = File('${directory.path}/workers.log').openWrite();
  final admin = Client(options['target'] as String)
    ..authKeyProvider = BenchmarkAuth(requireSecret());
  final workers = <WorkerProcess>[];
  final failures = <String>[];
  final opened = <int>{};
  final probes = <int>{};
  final openTimes = <int>[];
  final probeTimes = <int>[];
  final boundaries = <String, Map<String, dynamic>>{};
  final phaseSeconds = <String, double>{};
  final started = DateTime.now().toUtc();
  var phase = 'preflight';
  String? failurePhase;
  String? instanceId;
  var streamFailures = 0;
  var sampleFailures = 0;
  var idleCompleted = false;
  var cleanupVerified = false;
  Timer? sampler;
  Future<void>? sampling;

  void record(Map<String, dynamic> event) {
    final row = {
      'time': DateTime.now().toUtc().toIso8601String(),
      'phase': phase,
      ...event,
    };
    events.writeln(jsonEncode(row));
    if (row['type'] == 'streamFailure') streamFailures++;
    if (row['type'] == 'opened') {
      if (!opened.add(row['connection'] as int)) {
        failures.add('Duplicate open receipt.');
      }
      openTimes.add(row['micros'] as int);
    }
    if (row['type'] == 'probe') {
      if (!probes.add(row['connection'] as int)) {
        failures.add('Duplicate probe receipt.');
      }
      probeTimes.add(row['micros'] as int);
    }
  }

  Future<Map<String, dynamic>> sample() async {
    final result = await control(admin, {
      'action': 'transportMetrics',
    }).timeout(const Duration(seconds: 30));
    record({'type': 'serverSample', ...result});
    final id = (result['server'] as Map)['instanceId'] as String;
    instanceId ??= id;
    if (instanceId != id) throw StateError('Server instance changed during the case.');
    if ((result['streams'] as Map)['open'] != 0) {
      throw StateError('Offline Sync streams are active during the transport control.');
    }
    return result;
  }

  try {
    final before = boundaries['before'] = await sample();
    if ((before['transport'] as Map)['open'] != 0) {
      throw StateError('Prior streams remain.');
    }
    for (var index = 0; index < (options['workers'] as int); index++) {
      final args = Platform.script.path.endsWith('.dart')
          ? [...Platform.executableArguments, Platform.script.toFilePath(), '--worker']
          : ['--worker'];
      final process = await Process.start(Platform.resolvedExecutable, args);
      workers.add(WorkerProcess(index, process, record, logs));
    }
    sampler = Timer.periodic(Duration(seconds: options['sample-seconds'] as int), (_) {
      if (sampling != null) return;
      sampling = (() async {
        try {
          await sample();
        } on Object catch (error) {
          sampleFailures++;
          failures.add('Sampling failed: $error');
          record({'type': 'sampleFailure', 'error': '$error'});
        }
      })().whenComplete(() => sampling = null);
    });
    for (final next in ['init', 'open', 'idle', 'probe', 'close']) {
      phase = next;
      if (next == 'idle') {
        await ElapsedClock.waitUntil(
          ElapsedClock.timestampMicroseconds +
              (options['settle-seconds'] as int) * 1000000,
        );
      }
      record({'type': 'phaseStart'});
      stdout.writeln('$phase: ${options['connections']} streams');
      final clock = ElapsedClock()..start();
      final startMicros = ElapsedClock.timestampMicroseconds + 1000000;
      Future<void> dispatch(WorkerProcess worker) => worker.command(next, {
        if (next == 'init') 'options': options,
        if (next == 'idle') 'startMicros': startMicros,
      }, Duration(seconds: options['phase-timeout-seconds'] as int));
      if (next == 'open') {
        await forEachBounded(workers, options['open-workers'] as int, dispatch);
      } else {
        await Future.wait(workers.map(dispatch), eagerError: true);
      }
      phaseSeconds[next] = clock.elapsedMicroseconds / 1000000;
      record({'type': 'phaseEnd'});
      await sampling;
      final boundary = boundaries[next] = await sample();
      if (next == 'open' || next == 'idle' || next == 'probe') {
        if ((boundary['transport'] as Map)['open'] != options['connections']) {
          throw StateError('The requested number of streams is not established.');
        }
      }
      if (failures.isNotEmpty || streamFailures != 0) {
        throw StateError('Observation or stream failure.');
      }
      if (next == 'idle') idleCompleted = true;
    }
    for (final worker in workers) {
      if (await worker.exit.timeout(const Duration(seconds: 10)) != 0) {
        throw StateError('Worker exited unsuccessfully.');
      }
    }
  } on Object catch (error, stack) {
    failurePhase = phase;
    failures.add('$error');
    record({'type': 'failure', 'error': '$error', 'stack': '$stack'});
  } finally {
    sampler?.cancel();
    await Future.wait(workers.map((worker) => worker.terminate()));
    await sampling;
    phase = 'cleanup';
    try {
      final deadline = ElapsedClock.timestampMicroseconds + 60000000;
      while (true) {
        final result = boundaries['cleanup'] = await sample();
        if ((result['transport'] as Map)['open'] == 0) {
          cleanupVerified = true;
          break;
        }
        if (ElapsedClock.timestampMicroseconds >= deadline) {
          throw StateError('Server streams did not drain in 60 seconds.');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } on Object catch (error) {
      failures.add('Cleanup observation failed: $error');
    }
    admin.close();
    if (opened.length != options['connections']) {
      failures.add('Not every stream opened.');
    }
    if (probes.length != options['connections']) {
      failures.add('Not every stream resumed.');
    }
    if (streamFailures != 0) failures.add('$streamFailures stream failures.');
    if (!idleCompleted) failures.add('Idle interval did not complete.');
    final expected = Set<int>.from(
      List.generate(options['connections'] as int, (id) => id),
    );
    if (!opened.containsAll(expected) || !probes.containsAll(expected)) {
      failures.add('Connection identities are incomplete.');
    }
    final report = {
      'status': failures.isEmpty ? 'passed' : 'failed',
      'startedAt': started.toIso8601String(),
      'finishedAt': DateTime.now().toUtc().toIso8601String(),
      'options': options,
      'failurePhase': failurePhase,
      'failures': failures,
      'opened': opened.length,
      'resumed': probes.length,
      'idleCompleted': idleCompleted,
      'streamFailures': streamFailures,
      'sampleFailures': sampleFailures,
      'cleanupVerified': cleanupVerified,
      'openLatency': distribution(openTimes),
      'probeLatency': distribution(probeTimes),
      'phaseSeconds': phaseSeconds,
      'boundaries': boundaries,
      'elapsedClock': ElapsedClock.source,
      'semantics':
          'One authenticated Serverpod echo method stream per Client/WebSocket; '
          'no Offline Sync session, SQLite, application SQL, reconnects or retries. '
          'Every connection echoes a unique warmup and resume payload. '
          'Probe concurrency is one per worker; close concurrency is eight per worker. '
          'Admin authentication avoids database lookup. Server diagnostics remain enabled.',
    };
    await File('${directory.path}/summary.json').writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    await events.close();
    await logs.close();
    stdout.writeln(
      jsonEncode({
        'status': report['status'],
        'opened': opened.length,
        'resumed': probes.length,
        'failurePhase': failurePhase,
      }),
    );
    if (failures.isNotEmpty) exitCode = 1;
  }
}
