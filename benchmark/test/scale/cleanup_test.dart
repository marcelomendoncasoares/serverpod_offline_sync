@TestOn('linux || mac-os')
@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory scratch;
  late String root;

  setUpAll(() async {
    scratch = await Directory.systemTemp.createTemp('scale-cleanup-test-');
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:serverpod_offline_sync_benchmark/scale/runner.dart'),
    );
    root = p.normalize(p.join(File.fromUri(library!).parent.path, '../../..'));
  });

  tearDownAll(() async {
    await scratch.delete(recursive: true);
  });

  group('Given a dedicated server that still owns a stream after workers close,', () {
    late _ScaleResult result;
    late Map<String, dynamic> Function(int) metrics;

    setUpAll(() {
      metrics = (sample) => {
        'open': sample == 1 ? 0 : 1,
      };
    });

    group('when the scale coordinator reaches its cleanup deadline,', () {
      setUpAll(() async {
        result = await _runScaleFixture(root, scratch, 'stream-leak', metrics);
      });

      test('then it fails despite successful verification and worker closure.', () {
        expect(result.exitCode, isNot(0));
        expect(result.summary['convergedUsers'], 1);
        expect(result.summary['status'], 'failed');
        expect(result.summary['failures'], contains(contains('Server cleanup failed')));
        expect(
          result.events.where((e) => e['type'] == 'workerExit').single['exitCode'],
          0,
        );
      });

      test('then the last observed open stream remains in the report.', () {
        final cleanup = (result.summary['server'] as Map)['cleanup'] as Map;

        expect((cleanup['streams'] as Map)['open'], 1);
      });
    });
  });

  group('Given a server with an aborted idle transaction after workers close,', () {
    late _ScaleResult result;
    late Map<String, dynamic> Function(int) metrics;

    setUpAll(() {
      metrics = (sample) => {
        'open': 0,
        'connections': [
          if (sample > 1) {'state': 'idle in transaction (aborted)', 'count': 1},
        ],
      };
    });

    group('when the scale coordinator reaches its cleanup deadline,', () {
      setUpAll(() async {
        result = await _runScaleFixture(root, scratch, 'transaction-leak', metrics);
      });

      test('then zero open streams are insufficient for a passing run.', () {
        expect(result.exitCode, isNot(0));
        expect(result.summary['status'], 'failed');
        expect(result.summary['failures'], contains(contains('Server cleanup failed')));
      });
    });
  });

  group('Given server cleanup that finishes after the first post-close sample,', () {
    late _ScaleResult result;
    late Map<String, dynamic> Function(int) metrics;

    setUpAll(() {
      metrics = (sample) => {
        'open': sample == 7 ? 1 : 0,
      };
    });

    group('when the scale coordinator observes the later clean sample,', () {
      setUpAll(() async {
        // Preflight plus five phase-boundary samples precede afterClose.
        result = await _runScaleFixture(root, scratch, 'eventual-cleanup', metrics);
      });

      test('then the run passes with the final clean metrics retained.', () {
        expect(result.exitCode, 0, reason: result.output);
        expect(result.summary['status'], 'passed');
        final cleanup = (result.summary['server'] as Map)['cleanup'] as Map;

        expect((cleanup['streams'] as Map)['open'], 0);
        expect(
          result.events.where(
            (e) => e['type'] == 'serverSample' && e['phase'] == 'afterClose',
          ),
          hasLength(2),
        );
      });
    });
  });

  group('Given an unavailable final sample with ordinary sample failures allowed,', () {
    late _ScaleResult result;
    late Map<String, dynamic> Function(int) metrics;

    setUpAll(() {
      metrics = (sample) => {
        'open': 0,
        'unavailable': sample >= 7,
      };
    });

    group('when the scale coordinator cannot verify server cleanup,', () {
      setUpAll(() async {
        result = await _runScaleFixture(root, scratch, 'unobserved-cleanup', metrics);
      });

      test('then cleanup uncertainty still fails the run.', () {
        expect(result.exitCode, isNot(0));
        expect(result.summary['status'], 'failed');
        expect(result.summary['failures'], contains(contains('Server cleanup failed')));
      });
    });
  });

  group('Given a target that already has an open stream,', () {
    late _ScaleResult result;
    late Map<String, dynamic> Function(int) metrics;

    setUpAll(() {
      metrics = (_) => {
        'open': 1,
      };
    });

    group('when the scale coordinator performs preflight,', () {
      setUpAll(() async {
        result = await _runScaleFixture(root, scratch, 'occupied-server', metrics);
      });

      test('then it rejects the target before starting workers.', () {
        expect(result.exitCode, isNot(0));
        expect(result.summary['status'], 'failed');
        expect(result.summary['failures'], contains(contains('dedicated server')));
        expect(result.events.where((e) => e['type'] == 'workerStarted'), isEmpty);
      });
    });
  });

  group(
    'Given a replacement server with clean metrics and sample failures allowed,',
    () {
      late _ScaleResult result;
      late Map<String, dynamic> Function(int) metrics;

      setUpAll(() {
        metrics = (sample) => {
          'open': 0,
          'instanceId': sample == 1 ? 'original-server' : 'replacement-server',
        };
      });

      group('when samples switch to the replacement instance,', () {
        setUpAll(() async {
          result = await _runScaleFixture(root, scratch, 'changed-instance', metrics);
        });

        test('then another instance cannot establish a passing cleanup result.', () {
          expect(result.exitCode, isNot(0));
          expect(result.summary['status'], 'failed');
          expect(
            result.summary['failures'],
            contains('Server instance changed during the run.'),
          );
        });
      });
    },
  );
}

class _ScaleResult {
  _ScaleResult(this.exitCode, this.output, this.summary, this.events);

  final int exitCode;
  final String output;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> events;
}

/// Exercises the actual coordinator and HTTP client with deterministic server
/// metrics and real worker processes, without running a database workload.
Future<_ScaleResult> _runScaleFixture(
  String root,
  Directory scratch,
  String runId,
  Map<String, dynamic> Function(int sample) metrics,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var sample = 0;
  final serving = () async {
    await for (final request in server) {
      await request.drain<void>();
      final selected = metrics(++sample);
      request.response.headers.contentType = ContentType.json;
      if (selected['unavailable'] == true) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.write('Unavailable');
      } else {
        request.response.write(
          jsonEncode(
            jsonEncode({
              'server': {'instanceId': selected['instanceId'] ?? 'fixture-server'},
              'streams': {
                'open': selected['open'],
                'inboundChanges': 0,
                'outboundChanges': 0,
              },
              'tables': <String, dynamic>{},
              'storage': {'connections': selected['connections'] ?? <Object>[]},
            }),
          ),
        );
      }
      await request.response.close();
    }
  }();
  Process? coordinator;
  var exited = false;
  try {
    final process = coordinator = await Process.start(
      Platform.resolvedExecutable,
      [
        'run',
        'benchmark/test/scale/fixtures/scale_cleanup_driver.dart',
        '--target',
        'http://127.0.0.1:${server.port}/',
        '--data-dir',
        scratch.path,
        '--run-id',
        runId,
        '--users',
        '1',
        '--devices',
        '1',
        '--duration',
        '1',
        '--ramp-ms',
        '0',
        '--timeout-seconds',
        '1',
        '--sample-seconds',
        '3600',
        '--max-sample-failures',
        '100',
        '--no-sync-diagnostics',
      ],
      workingDirectory: root,
      environment: {'BENCHMARK_SECRET': 'cleanup-fixture-secret'},
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode.timeout(const Duration(minutes: 1));
    exited = true;
    final directory = p.join(scratch.path, runId);
    return _ScaleResult(
      code,
      '${await output}\n${await errors}',
      jsonDecode(await File(p.join(directory, 'summary.json')).readAsString())
          as Map<String, dynamic>,
      (await File(
        p.join(directory, 'events.jsonl'),
      ).readAsLines()).map((line) => jsonDecode(line) as Map<String, dynamic>).toList(),
    );
  } finally {
    if (!exited && coordinator != null) {
      coordinator.kill(ProcessSignal.sigterm);
      try {
        await coordinator.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        coordinator.kill(ProcessSignal.sigkill);
        await coordinator.exitCode;
      }
    }
    await server.close(force: true);
    await serving;
  }
}
