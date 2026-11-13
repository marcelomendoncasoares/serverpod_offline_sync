@TestOn('linux || mac-os')
library;

import 'dart:async';
import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/runner.dart';
import 'package:test/test.dart';

const done = r'printf "@benchmark {\"type\":\"done\",\"phase\":\"%s\"}\n"';
const longTimeout = Duration(seconds: 60);

/// A shell stand-in for a worker process, driving the real coordinator side.
Future<(WorkerProcess, List<Map<String, dynamic>>)> fakeWorker(String script) async {
  final process = await Process.start('sh', ['-c', script]);
  final events = <Map<String, dynamic>>[];
  final worker = WorkerProcess(
    0,
    process,
    events.add,
    IOSink(StreamController<List<int>>().sink),
  );
  addTearDown(() async {
    process.kill(ProcessSignal.sigkill);
    await worker.exit;
  });
  return (worker, events);
}

void main() {
  test(
    'Given a worker that exits after finishing a phase, '
    'when the next phase is commanded, '
    'then it fails immediately with the exit code instead of waiting for the deadline.',
    () async {
      final (worker, events) = await fakeWorker('read line; $done init; exit 3');

      await worker.command('init', {}, longTimeout);
      await worker.exit;
      final timer = Stopwatch()..start();

      await expectLater(
        worker.command('seed', {}, longTimeout),
        throwsA(predicate((e) => '$e'.contains('exited with code 3'))),
      );
      expect(timer.elapsed, lessThan(const Duration(seconds: 5)));
      expect(events.last, containsPair('type', 'workerExit'));
    },
  );

  test('Given a worker that dies during a phase, '
      'when the coordinator waits on it, '
      'then the phase fails as soon as the process exits.', () async {
    final (worker, _) = await fakeWorker('read line; sleep 0.2; exit 137');
    final timer = Stopwatch()..start();

    await expectLater(
      worker.command('exercise', {}, longTimeout),
      throwsA(predicate((e) => '$e'.contains('exited with code 137'))),
    );
    expect(timer.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('Given a worker that reports a fatal error, '
      'when the phase is pending, '
      'then the error is surfaced.', () async {
    final (worker, _) = await fakeWorker(
      r'read line; printf "@benchmark {\"type\":\"fatal\",\"error\":\"boom\"}\n"; exec sleep 5',
    );

    await expectLater(
      worker.command('verify', {}, longTimeout),
      throwsA(predicate((e) => '$e'.contains('boom'))),
    );
  });

  test('Given a worker that never answers, '
      'when its phase deadline passes, '
      'then the timeout names the worker and phase.', () async {
    final (worker, _) = await fakeWorker('read line; exec sleep 30');

    await expectLater(
      worker.command('seed', {}, const Duration(milliseconds: 300)),
      throwsA(predicate((e) => '$e'.contains('did not finish seed'))),
    );
  });

  test('Given a worker that completes the close phase, '
      'when it exits normally, '
      'then no failure is recorded.', () async {
    final (worker, _) = await fakeWorker('read line; $done close; exit 0');

    await worker.command('close', {}, longTimeout);

    expect(await worker.exit, 0);
    expect(worker.failure, isNull);
  });
}
