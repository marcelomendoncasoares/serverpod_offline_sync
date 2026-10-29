// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'client_diagnostics.dart';
import 'common.dart';
import 'elapsed_clock.dart';
import 'round_client_profile.dart';
import 'round_options.dart';
import 'round_workload.dart';
import 'verification.dart';
import 'worker.dart';

/// Exact domain-value comparison, including ids and nullable relationship fields.
/// A matching row count or a merge callback alone cannot complete a round.
bool deliveredRows(
  String table,
  List<TableRow<UuidValue?>> actual,
  List<TableRow<UuidValue?>> expected,
) =>
    actual.length == expected.length &&
    projectionDigest(
          actual.map((r) => r.toJson() as Map<String, dynamic>),
          roundFields(table),
        ) ==
        projectionDigest(
          expected.map((r) => r.toJson() as Map<String, dynamic>),
          roundFields(table),
        );

class RoundObserver {
  RoundObserver(
    Device device,
    String table,
    List<TableRow<UuidValue?>> expected,
    ElapsedClock clock,
  ) {
    subscription =
        watchRoundRows(
          device.session!,
          table,
          expected.map((r) => r.id!).toSet(),
        ).listen(
          (rows) {
            if (!ready.isCompleted) ready.complete();
            if (deliveredRows(table, rows, expected) && !delivered.isCompleted) {
              delivered.complete(clock.elapsedMicroseconds);
            }
          },
          onError: (Object error, StackTrace stack) {
            failure = error;
            if (!ready.isCompleted) ready.complete();
            if (!delivered.isCompleted) delivered.complete(-1);
          },
        );
  }

  // Owned by the round and cancelled in its finally block.
  // ignore: cancel_subscriptions
  late final StreamSubscription<List<TableRow<UuidValue?>>> subscription;
  final ready = Completer<void>();
  final delivered = Completer<int>();
  Object? failure;
}

class RoundWorker {
  RoundWorker(this.options, this.index, this.emit, this.secret);

  final RoundOptions options;
  final int index;
  final Emit emit;
  final String secret;
  final groups = <int, List<Device>>{};
  final clientProfiles = <int, RoundClientProfile>{};
  final journals = <int, Map<String, List<TableRow<UuidValue?>>>>{};
  final lag = LoopLag();
  String phase = 'init';
  Timer? sampler;
  var closed = false;

  Iterable<Device> get devices => groups.values.expand((group) => group);

  Future<void> initialize() async {
    final admin = Client(options.scale.target)..authKeyProvider = BenchmarkAuth(secret);
    try {
      await forEachBounded(
        options.scale.usersOf(index),
        options.number('setup-concurrency'),
        (user) async {
          final group = [
            for (var d = 0; d < options.scale.devicesFor(user); d++)
              Device(options.scale, user, d, emit),
          ];
          groups[user] = group;
          journals[user] = {'person': [], 'city': [], 'town': []};
          await control(admin, {
            'action': 'provision',
            'userId': group.first.userId.toString(),
          });
        },
      );
      await forEachBounded(
        devices,
        options.number('setup-concurrency'),
        (d) => d.open(secret),
      );
      for (final device in devices) {
        if (device.user != options.values['client-profile-user']) continue;

        (device.client! as DiagnosticClient).onSyncFrame = (event, direction) {
          clientProfiles[device.user]?.observe(device.index, event, direction);
        };
      }
    } finally {
      admin.close();
    }
    lag.start();
    sampler = Timer.periodic(Duration(seconds: options.number('sample-seconds')), (_) {
      emit({
        'type': 'workerSample',
        'process': processSample(),
        'loopLag': lag.takeWindow(),
      });
    });
  }

  void ensureStreamsHealthy({Iterable<Device>? checking}) {
    for (final device in checking ?? devices) {
      if (device.unexpectedStreamEnds != 0 ||
          device.streamErrors != 0 ||
          (options.continuous && device.subscription == null)) {
        throw StateError(
          'Stream ended on ${device.user}/${device.index}; no automatic reconnects are allowed.',
        );
      }
    }
  }

  Future<void> warmup() async {
    // Every device authors a sentinel batch. Observing it on every peer proves
    // bidirectional connectivity before any measured round begins. Bound the
    // opening work per user as well as initialization, so steady-state capacity
    // can be measured independently of a simultaneous reconnect burst.
    await forEachBounded(
      groups.entries,
      options.number('setup-concurrency'),
      (entry) async {
        if (options.continuous) {
          for (final device in entry.value) {
            device.startStream();
          }
        }

        for (var d = 0; d < entry.value.length; d++) {
          await round(
            entry.key,
            d - entry.value.length,
            rows: options.updates ? options.number('rows') : 1,
            writerIndex: d,
          );
        }
      },
    );
    if (options.continuous) ensureStreamsHealthy();
    emit({'type': 'warmupComplete', 'devices': devices.length});
  }

  Future<void> syncOnce(
    Device device, {
    required int round,
    required String role,
    required int rows,
  }) async {
    final trace = device.trace(once: true);
    final clock = ElapsedClock()..start();
    // A new Client owns a new method-stream manager, hence cannot borrow an
    // existing WebSocket. SQLite remains open, as in an ordinary app session.
    final client = DiagnosticClient(
      options.scale.target,
      diagnosticsEnabled: options.scale.flag('sync-diagnostics'),
    )..authKeyProvider = BenchmarkAuth(userToken(secret, device.userId.toString()));
    var ok = false;
    try {
      await trace
          .run(() => client.offlineSync.syncOnce(device.session!))
          .timeout(options.timeout);
      ok = true;
    } finally {
      final micros = clock.elapsedMicroseconds;
      client.close();
      trace.finish(outcome: ok ? 'completed' : 'error');
      emit({
        'type': 'onceCall',
        'user': device.user,
        'device': device.index,
        'round': round,
        'role': role,
        'rows': rows,
        'micros': micros,
        'ok': ok,
        'freshClient': true,
        'retries': 0,
      });
    }
  }

  Future<void> round(
    int user,
    int sequence, {
    required int rows,
    required int writerIndex,
    int scheduleLagMicros = 0,
  }) async {
    final preparation = ElapsedClock()..start();
    final group = groups[user]!;
    if (options.continuous) {
      ensureStreamsHealthy(checking: group);
    }
    final writer = group[writerIndex];
    final peers = group.where((d) => d != writer).toList();
    final table = roundTable(options);
    final expected = makeRoundRows(options, user, sequence, writerIndex, rows);
    final parents = sequence == -group.length
        ? roundParents(options, user)
        : <String, List<TableRow<UuidValue?>>>{};
    // The first warmup seeds stable rows; every later update changes both fields.
    final insert = !options.updates || sequence == -group.length;
    final clock = ElapsedClock();
    final clientProfile = user == options.values['client-profile-user']
        ? RoundClientProfile(
            round: sequence,
            writer: writerIndex,
            readMicros: () => clock.elapsedMicroseconds,
          )
        : null;
    final observers = [
      for (final peer in peers) RoundObserver(peer, table, expected, clock),
    ];
    var ok = false;
    var committed = 0;
    var prepared = 0;
    var delivered = <int>[];
    int? startedMicros;
    try {
      await Future.wait(observers.map((o) => o.ready.future)).timeout(options.timeout);
      for (final observer in observers) {
        if (observer.failure != null) throw StateError('${observer.failure}');
      }
      prepared = preparation.elapsedMicroseconds;
      startedMicros = ElapsedClock.timestampMicroseconds;
      clock.start();
      if (clientProfile != null) clientProfiles[user] = clientProfile;
      await writer.session!.db.transactionForUser(
        writer.userId,
        (tx) async {
          for (final entry in parents.entries) {
            await writeRoundRows(
              writer.session!,
              tx,
              entry.key,
              entry.value,
              insert: true,
            );
          }
          await writeRoundRows(writer.session!, tx, table, expected, insert: insert);
        },
      );
      committed = clock.elapsedMicroseconds;
      if (!insert) {
        final ids = {for (final row in expected) row.id};
        journals[user]![table]!.removeWhere((row) => ids.contains(row.id));
      }
      journals[user]![table]!.addAll(expected);
      for (final entry in parents.entries) {
        journals[user]![entry.key]!.addAll(entry.value);
      }
      if (!options.continuous) {
        await syncOnce(writer, round: sequence, role: 'push', rows: rows);
        await Future.wait(
          peers.map((d) => syncOnce(d, round: sequence, role: 'pull', rows: rows)),
        );
      }
      delivered = await Future.wait(
        observers.map((o) => o.delivered.future),
      ).timeout(options.timeout);
      for (final observer in observers) {
        if (observer.failure != null) throw StateError('${observer.failure}');
      }
      if (options.continuous) {
        ensureStreamsHealthy(checking: group);
      }
      ok = true;
    } finally {
      final completed = clock.elapsedMicroseconds;
      final finishedMicros = ElapsedClock.timestampMicroseconds;
      clientProfiles.remove(user);
      await Future.wait(observers.map((o) => o.subscription.cancel()));
      emit({
        'type': 'round',
        'elapsedClock': ElapsedClock.source,
        'mode': options.values['mode'],
        'writeMode': insert ? 'insert' : 'update',
        'workload': options.values['workload'],
        'table': table,
        'parentRows': parents.values.fold<int>(0, (sum, rows) => sum + rows.length),
        'user': user,
        'round': sequence,
        'startedMicros': startedMicros,
        'finishedMicros': finishedMicros,
        'writer': writerIndex,
        'rows': rows,
        'payloadBytes': expected.fold<int>(
          0,
          (n, row) =>
              n + utf8.encode(jsonEncode(row.toJson() as Map<String, dynamic>)).length,
        ),
        'peers': peers.length,
        'ok': ok,
        'dispatchLagMicros': scheduleLagMicros,
        'observerPreparationMicros': prepared,
        'scheduleLagMicros': scheduleLagMicros + prepared,
        'localCommitMicros': committed,
        if (clientProfile != null) 'clientProfile': clientProfile.toJson(),
        'completedMicros': completed,
        'writeToAllPeersMicros': delivered.isEmpty ? null : delivered.reduce(max),
        'commitToAllPeersMicros': delivered.isEmpty
            ? null
            : max(0, delivered.reduce(max) - committed),
        'peerAppliedMicros': [
          for (var i = 0; i < delivered.length; i++)
            {'device': peers[i].index, 'micros': delivered[i]},
        ],
        'scheduledToAllPeersMicros': delivered.isEmpty
            ? null
            : scheduleLagMicros + prepared + delivered.reduce(max),
        'retries': 0,
      });
    }
  }

  Future<void> exercise({int? startMicros}) async {
    final origin = startMicros ?? ElapsedClock.timestampMicroseconds;
    await ElapsedClock.waitUntil(origin);
    lag.marks['exercise'] = Latencies();
    final startCpu = cpuSeconds();
    final clock = ElapsedClock()..start();
    await Future.wait(
      groups.entries.where((entry) => entry.key < options.activeUsers).map((
        entry,
      ) async {
        final period = options.number('period-ms') * 1000;
        final offset = options.userOffsetMicros(entry.key);
        for (var r = 0; r < options.number('rounds'); r++) {
          final due = origin + offset + r * period;
          await ElapsedClock.waitUntil(due);
          await round(
            entry.key,
            r,
            rows: options.number('rows'),
            writerIndex: r % entry.value.length,
            scheduleLagMicros: max(0, ElapsedClock.timestampMicroseconds - due),
          );
        }
        emit({
          'type': 'userCompleted',
          'user': entry.key,
          'elapsedMicros': ElapsedClock.timestampMicroseconds - origin - offset,
          'budgetMicros': options.number('rounds') * period,
        });
      }),
    );
    await ElapsedClock.waitUntil(origin + options.exerciseMicros);
    if (options.continuous) ensureStreamsHealthy();
    final elapsed = clock.elapsedMicroseconds;
    final endCpu = cpuSeconds();
    emit({
      'type': 'workerExercise',
      'startedMicros': origin,
      'finishedMicros': ElapsedClock.timestampMicroseconds,
      'micros': elapsed,
      'cpuCores': startCpu == null || endCpu == null
          ? null
          : (endCpu - startCpu) * 1000000 / elapsed,
      'loopLag': lag.marks.remove('exercise')!.toJson(),
      'process': processSample(),
    });
  }

  Future<void> probeIdleUsers() async {
    await forEachBounded(
      groups.entries.where((entry) => entry.key >= options.activeUsers),
      options.number('setup-concurrency'),
      (entry) => round(
        entry.key,
        -entry.value.length - 1,
        rows: 1,
        writerIndex: 0,
      ),
    );
  }

  Future<void> verify() async {
    if (options.continuous) ensureStreamsHealthy();
    // No repair sync is allowed here: the timed rounds must already have
    // delivered every row. Check the entire journal on server and all peers.
    final admin = Client(options.scale.target)..authKeyProvider = BenchmarkAuth(secret);
    try {
      await forEachBounded(groups.keys, options.number('setup-concurrency'), (
        user,
      ) async {
        final group = groups[user]!;
        final expected = journals[user]!;
        final server = await control(admin, {
          'action': 'snapshot',
          'userId': group.first.userId.toString(),
        });
        final expectedSnapshot = snapshotOf({
          for (final entry in expected.entries)
            entry.key: entry.value
                .map((row) => row.toJson() as Map<String, dynamic>)
                .toList(),
        });
        if (server['digest'] != expectedSnapshot['digest'] ||
            jsonEncode(server['rows']) != jsonEncode(expectedSnapshot['rows'])) {
          throw StateError(
            'Server does not match the complete journal for user $user.',
          );
        }
        for (final device in group) {
          final snapshot = await device.snapshot();
          if (snapshot.summary['digest'] != server['digest']) {
            throw StateError('Device $user/${device.index} does not match the server.');
          }
        }
        emit({
          'type': 'verified',
          'user': user,
          'rows': expected.values.fold<int>(0, (sum, rows) => sum + rows.length),
          'devices': group.length,
        });
      });
    } finally {
      admin.close();
    }
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    sampler?.cancel();
    lag.stop();
    await Future.wait(devices.map((d) => d.close()));
  }
}

Future<void> roundWorkerMain() async {
  RoundWorker? worker;
  void emit(Map<String, dynamic> event) {
    stdout.writeln(
      '@benchmark ${jsonEncode({
        'time': DateTime.now().toUtc().toIso8601String(),
        'phase': worker?.phase ?? 'init',
        ...event,
      })}',
    );
  }

  try {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final command = jsonDecode(line) as Map<String, dynamic>;
      final phase = command['phase'] as String;
      if (phase == 'init') {
        worker = RoundWorker(
          RoundOptions(command['options'] as Map<String, dynamic>),
          command['worker'] as int,
          emit,
          requireSecret(),
        );
      }
      worker!.phase = phase;
      switch (phase) {
        case 'init':
          await worker.initialize();
        case 'warmup':
          await worker.warmup();
        case 'exercise':
          await worker.exercise(startMicros: command['startMicros'] as int?);
        case 'probe':
          await worker.probeIdleUsers();
        case 'verify':
          await worker.verify();
        case 'close':
          await worker.close();
        default:
          throw ArgumentError('Unknown phase $phase');
      }
      emit({'type': 'done', 'phase': phase});
      if (phase == 'close') return;
    }
  } on Object catch (error, stack) {
    emit({'type': 'fatal', 'error': '$error', 'stack': '$stack'});
    exitCode = 1;
  } finally {
    await worker?.close();
  }
}
