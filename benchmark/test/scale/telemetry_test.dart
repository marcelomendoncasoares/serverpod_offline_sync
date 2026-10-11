import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:serverpod/serverpod.dart' show UuidValue;
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_benchmark/scale/summary.dart';
import 'package:serverpod_offline_sync_benchmark/scale/worker.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

/// Creates and deletes a file until told to stop, like SQLite checkpointing.
Future<void> churnFile(List<Object> args) async {
  final path = args[0] as String;
  final ready = args[1] as SendPort;
  final stop = ReceivePort();
  ready.send(stop.sendPort);
  var running = true;
  stop.listen((_) => running = false);
  while (running) {
    File(path).writeAsBytesSync([1, 2, 3]);
    File(path).deleteSync();
    await Future<void>.delayed(Duration.zero);
  }
  stop.close();
}

CrdtMergeChange change() => CrdtMergeDelete(
  hlcDatetime: DateTime.utc(2026),
  hlcCounter: 0,
  uuidSpaceId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  tableName: 'town',
  uuidRowId: UuidValue.fromString('00000000-0000-4000-8000-000000000002'),
  uuidNodeId: UuidValue.fromString('00000000-0000-4000-8000-000000000003'),
  clFlag: 1,
  reason: CrdtDataDeletedReason.userDelete,
);

void main() {
  test('Given SQLite WAL files that appear and vanish concurrently, '
      'when storage is sampled repeatedly, '
      'then missing files count as zero bytes instead of failing.', () async {
    final directory = await Directory.systemTemp.createTemp('scale-race-');
    final database = '${directory.path}/device.sqlite';
    final ready = ReceivePort();
    final exited = ReceivePort();
    await Isolate.spawn(
      churnFile,
      ['$database-wal', ready.sendPort],
      onExit: exited.sendPort,
    );
    final stop = await ready.first as SendPort;
    addTearDown(() async {
      // Isolate.kill is asynchronous: wait for the exit before deleting.
      stop.send(null);
      await exited.first;
      await directory.delete(recursive: true);
    });

    // A fixed number of samples: the old exists-then-length check failed about
    // 3% of the time here, independent of host speed.
    for (var i = 0; i < 3000; i++) {
      expect(sqliteFiles(database)['walBytes'], anyOf(0, 3));
      await Future<void>.delayed(Duration.zero);
    }

    expect(sqliteFiles('${directory.path}/missing'), {
      'databaseBytes': 0,
      'walBytes': 0,
      'shmBytes': 0,
    });
  });

  test('Given an event loop blocked by synchronous work, '
      'when lag is sampled, '
      'then the delay is visible.', () async {
    final lag = LoopLag(interval: const Duration(milliseconds: 20))..start();
    addTearDown(lag.stop);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final busy = Stopwatch()..start();
    while (busy.elapsedMilliseconds < 250) {}
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final window = lag.takeWindow();

    expect(window['maxMicros'], greaterThan(150000));
    expect(lag.takeWindow()['count'], lessThan(window['count'] as int));
  });

  test('Given an observed sync stream carrying merge chunks, '
      'when it runs, fails and ends, '
      'then changes, activity and failures are counted.', () async {
    var now = DateTime.utc(2026);
    final metrics = StreamMetrics(now: () => now);
    final inbound = StreamController<dynamic>();
    final outbound = StreamController<dynamic>();
    addTearDown(() async {
      await inbound.close();
      await outbound.close();
    });
    final events = <dynamic>[];
    final stream = metrics.observe((streams) {
      streams['changes']!.listen((_) {});
      return outbound.stream;
    }, {'changes': inbound.stream});
    final done = Completer<Object?>();
    stream.listen(
      events.add,
      onError: (Object error) => done.isCompleted ? null : done.complete(error),
      onDone: () => done.isCompleted ? null : done.complete(null),
    );
    await Future<void>.delayed(Duration.zero);

    inbound.add(OfflineSyncMergeChunk(changes: [change(), change()]));
    outbound
      ..add(OfflineSyncMergeChunk(changes: [change()]))
      ..add(OfflineSyncMergeChunk(changes: []));
    await Future<void>.delayed(Duration.zero);
    final active = metrics.sample();
    now = now.add(const Duration(seconds: 3));
    final idle = metrics.sample();
    outbound.addError(StateError('lost'));
    final error = await done.future;

    expect(events, hasLength(2));
    expect(active, containsPair('active', 1));
    expect(idle, containsPair('idle', 1));
    expect(error, isA<StateError>());
    expect(metrics.sample(), {
      'open': 0,
      'active': 0,
      'idle': 0,
      'activityWindowMs': 2000,
      'openedTotal': 1,
      'closedTotal': 1,
      'failedTotal': 1,
      'inboundChanges': 2,
      'outboundChanges': 1,
    });
  });

  test('Given seeded payloads, '
      'when generated for writes, '
      'then they are reproducible, distinct, exact-length and incompressible.', () {
    final first = seededPayload(mixSeed([1, 0, 0, 7]), 8192, 'u0.d0.s7:');
    final again = seededPayload(mixSeed([1, 0, 0, 7]), 8192, 'u0.d0.s7:');
    final next = seededPayload(mixSeed([1, 0, 0, 8]), 8192, 'u0.d0.s8:');

    expect(first, again);
    expect(first, isNot(next));
    expect(first.length, 8192);
    expect(seededPayload(1, 20, 'u0.d0.s7:'), isNot(startsWith('u0.')));
    expect(seededPayload(1, 25, 'u0.d0.s7:'), startsWith('u0.d0.s7:'));
    expect(gzip.encode(first.codeUnits).length, greaterThan(8192 * 0.7));
    expect(gzip.encode(('x' * 8192).codeUnits).length, lessThan(100));
  });

  test('Given one-byte town names, '
      'when a town is renamed to a seeded payload equal to its current name, '
      'then the rename still changes the stored value.', () {
    for (var seq = 0; seq < 200; seq++) {
      final previous = seededPayload(mixSeed([1, 0, 0, seq]), 1, 'u0.d0.s$seq:');
      final renamed = distinctFrom(previous, previous);

      expect(renamed, hasLength(1));
      expect(renamed, isNot(previous));
      expect(distinctFrom(previous, 'Q'), previous == 'Q' ? isNot('Q') : 'Q');
    }
  });

  test(
    'Given many users with many devices sharing one permit pool, '
    'when seed syncs are scheduled, '
    'then in-flight syncs never exceed the worker cap and each first device syncs first.',
    () async {
      final permits = Semaphore(3);
      var running = 0;
      var peak = 0;
      final order = <(int, int)>[];

      await seedGroups<(int, int)>(
        [
          for (var user = 0; user < 6; user++) [for (var d = 0; d < 5; d++) (user, d)],
        ],
        permits,
        seedLocal: (_) async {},
        sync: (device) async {
          running++;
          peak = running > peak ? running : peak;
          order.add(device);
          await Future<void>.delayed(const Duration(milliseconds: 2));
          running--;
        },
      );

      expect(order, hasLength(30));
      expect(peak, 3);
      expect(permits.peak, 3);
      for (var user = 0; user < 6; user++) {
        final mine = order.where((d) => d.$1 == user).toList();
        expect(mine.first, (user, 0));
      }
    },
  );

  test('Given bounded concurrency, '
      'when one item fails, '
      'then no more than the limit run at once and no new items start.', () async {
    var running = 0;
    var peak = 0;
    final started = <int>[];

    await expectLater(
      forEachBounded(List.generate(20, (i) => i), 3, (i) async {
        started.add(i);
        running++;
        peak = running > peak ? running : peak;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
        if (i == 4) throw StateError('item 4');
      }),
      throwsStateError,
    );

    expect(peak, 3);
    expect(started.length, lessThan(10));
  });

  group('Given recorded events', () {
    final options = ScaleOptions.parse([
      '--target',
      'https://example.test',
      '--users',
      '1',
      '--max-unexpected-stream-ends',
      '1',
      '--max-sample-failures',
      '1',
    ]);

    Map<String, dynamic> boundary(
      String phase,
      String instance,
      int inbound, {
      int second = 0,
    }) => {
      'type': 'serverSample',
      'sampleKind': 'boundary',
      'phase': phase,
      'time': DateTime.utc(2026, 1, 1, 0, 0, second).toIso8601String(),
      'server': {'instanceId': instance},
      'streams': {'inboundChanges': inbound, 'outboundChanges': 0, 'open': 3},
      'tables': {'person': inbound},
      'storage': {'databaseBytes': 1000 + inbound},
    };

    test('when every write was offline, '
        'then the summary separates local commits from server changes.', () {
      final summary = SummaryBuilder(options)
        ..add(boundary('seed', 'a', 5))
        ..add({'type': 'operation', 'kind': 'insert', 'state': 'offline'})
        ..add({'type': 'operation', 'kind': 'read', 'state': 'offline'})
        ..add({'type': 'phaseEnd', 'phase': 'exercise', 'micros': 2000000})
        ..add(boundary('exercise', 'a', 5, second: 4))
        ..add(boundary('verify', 'a', 77, second: 6));

      final report = summary.build(
        status: 'passed',
        failures: [],
        started: DateTime.now(),
      );
      final operations = report['operations'] as Map;
      final server = report['server'] as Map;

      expect(operations['localCommittedWritesByState'], {'offline': 1});
      expect(operations['localCommittedWritesPerSecond'], 0.5);
      expect((server['workload'] as Map)['streams'], {
        'inboundChanges': 0,
        'outboundChanges': 0,
      });
      expect((server['verificationDrain'] as Map)['rowsAdded'], {'person': 72});
      expect((server['verificationDrain'] as Map)['seconds'], 2);
      expect((server['verificationDrain'] as Map)['inboundChangesPerSecond'], 36);
    });

    test('when the workload phase never finished, '
        'then rates are null rather than divided by a placeholder.', () {
      final summary = SummaryBuilder(options)
        ..add({'type': 'operation', 'kind': 'insert', 'state': 'active'});

      final report = summary.build(
        status: 'failed',
        failures: [],
        started: DateTime.now(),
      );

      expect((report['operations'] as Map)['localCommittedWritesPerSecond'], isNull);
      expect((report['server'] as Map)['workload'], isNull);
    });

    test('when boundary samples come from different instances, '
        'then counters are not differenced.', () {
      final summary = SummaryBuilder(options)
        ..add(boundary('seed', 'a', 5))
        ..add(boundary('exercise', 'b', 9));

      expect(
        summary.serverDelta('seed', 'exercise'),
        containsPair('sameInstance', false),
      );
    });

    test('when stream ends and sample failures exceed their limits, '
        'then each policy fails the run.', () {
      final summary = SummaryBuilder(options)
        ..add({'type': 'streamError', 'error': 'lost'})
        ..add({'type': 'streamReconnectScheduled', 'attempt': 1})
        ..add({'type': 'streamStarted', 'reconnect': true})
        ..add({'type': 'streamEnded', 'expected': false})
        ..add({'type': 'streamEnded', 'expected': true})
        // Residency repeats per-device totals; it must not be counted again.
        ..add({
          'type': 'residency',
          'seconds': {'active': 1.0},
          'unexpectedStreamEnds': 2,
          'streamErrors': 1,
          'reconnectsScheduled': 1,
          'reconnects': 1,
        })
        ..add({
          'type': 'serverSampleError',
          'sampleKind': 'periodic',
          'phase': 'exercise',
        })
        ..add({'type': 'workerSampleError', 'error': 'x'});

      expect(summary.policyFailures(), [
        contains('2 unexpected stream ends'),
        contains('2 failed samples'),
      ]);
      expect(summary.streamCounts, {
        'unexpectedEnds': 2,
        'errors': 1,
        'reconnectsScheduled': 1,
        'reconnects': 1,
      });
    });

    test('when a worker stopped before reporting workload measurements, '
        'then the generator assessment says so instead of reporting no signal.', () {
      final summary = SummaryBuilder(options)
        ..add({'type': 'streamError', 'error': 'lost before residency'});

      final report = summary.build(
        status: 'failed',
        failures: [],
        started: DateTime.now(),
      );

      expect((report['generator'] as Map)['assessment'], 'insufficient measurements');
      expect((report['streams'] as Map)['errors'], 1);
    });

    test('when worker device logic lagged, '
        'then the generator is flagged without failing the run.', () {
      final summary = SummaryBuilder(options)
        ..add({
          'type': 'generatorExercise',
          'worker': 0,
          'devices': 4,
          'cpuCores': 0.9,
          'loopLag': {
            'p50UpperMicros': 1000,
            'p99UpperMicros': 400000,
            'maxMicros': 500000,
          },
          'nominalOperationAttempts': 100.0,
          'operationAttempts': 95,
        });

      final generator =
          summary.build(
                status: 'passed',
                failures: [],
                started: DateTime.now(),
              )['generator']
              as Map;

      expect(generator['assessment'], 'possible generator saturation');
      expect(summary.policyFailures(), isEmpty);
    });
  });
}
