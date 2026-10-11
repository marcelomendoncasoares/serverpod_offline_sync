// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'common.dart';
import 'options.dart';
import 'verification.dart';

typedef Emit = void Function(Map<String, dynamic> event);

const states = ['active', 'idle', 'offline', 'closed'];
const writerStates = {'active', 'offline'};
const streamingStates = {'active', 'idle'};
const maxReconnectDelayMs = 30000;

class Device {
  Device(this.options, this.user, this.index, this.emit, {this.ordinal = 0})
    : random = Random(options.number('seed') + user * 104729 + index * 1009),
      reconnectRandom = Random(
        mixSeed([options.number('seed'), user, index, 0x726563]),
      ),
      userId = benchmarkId('${options.runId}/user/$user'),
      path = p.join(
        options.directory,
        'databases',
        'user-$user',
        'device-$index.sqlite',
      );

  final ScaleOptions options;
  final int user;
  final int index;

  /// Position within the worker; the network ramp starts devices in order.
  final int ordinal;
  final Emit emit;
  final Random random;
  final Random reconnectRandom;
  final UuidValue userId;
  final String path;

  /// Write journal: the exact rows this device authored.
  final receipts = <String, Map<String, Object?>>{};
  final towns = <String, Map<String, Object?>>{};

  /// City id to the last name this device wrote.
  final cityEdits = <String, String>{};

  Client? client;
  OfflineSyncDatabaseSession? session;
  OfflineSyncSubscription? subscription;
  Future<void>? observedDone;
  String state = 'closed';
  var transitioning = false;
  var sequence = 0;
  var stopping = false;

  /// Unexpected ends and errors, whether or not a reconnect followed.
  var unexpectedStreamEnds = 0;
  var streamErrors = 0;
  var reconnectsScheduled = 0;
  var reconnects = 0;
  var _generation = 0;
  var _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  Stopwatch? _downtime;
  var supervising = false;

  final residencyMicros = <String, int>{};
  final _residency = Stopwatch();
  var operationAttempts = 0;
  var writes = 0;

  int get startOffsetMs => ordinal * options.number('ramp-ms');

  void event(String type, Map<String, dynamic> data) =>
      emit({'type': type, 'user': user, 'device': index, ...data});

  Future<T> measure<T>(String operation, Future<T> Function() action) async {
    final timer = Stopwatch()..start();
    try {
      final result = await action();
      event('latency', {
        'operation': operation,
        'micros': timer.elapsedMicroseconds,
        'ok': true,
      });
      return result;
    } catch (error) {
      event('latency', {
        'operation': operation,
        'micros': timer.elapsedMicroseconds,
        'ok': false,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<void> open(String secret) async {
    if (session != null) return;
    await Directory(p.dirname(path)).create(recursive: true);
    final newClient = Client(options.target)
      ..authKeyProvider = BenchmarkAuth(userToken(secret, userId.toString()));
    try {
      session = await measure(
        'openDatabase',
        () => newClient.createSyncSession(path, persistentUserId: userId),
      );
      client = newClient;
    } catch (_) {
      newClient.close();
      rethrow;
    }
  }

  Future<void> stopStream() async {
    stopping = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _downtime = null;
    try {
      await subscription?.cancel();
      await observedDone;
    } finally {
      subscription = null;
      observedDone = null;
      stopping = false;
    }
  }

  void startStream({bool reconnect = false}) {
    final generation = ++_generation;
    final started = Stopwatch()..start();
    var merged = false;
    final stream = client!.offlineSync.syncContinuously(
      session!,
      onMergeSuccess: (_, hlc) {
        if (generation != _generation) return;
        // The engine reports its checkpoint high-water mark after a merge
        // cycle, including cycles that only pushed. It is not the latency of
        // any particular change, and it is subject to clock skew.
        event('mergeReport', {
          'checkpointHlc': hlc.toString(),
          'checkpointAgeMs': DateTime.now()
              .toUtc()
              .difference(hlc.datetime)
              .inMilliseconds,
        });
        if (merged) return;
        merged = true;
        event('latency', {
          'operation': reconnect ? 'reconnectFirstMerge' : 'streamFirstMerge',
          'micros': started.elapsedMicroseconds,
          'ok': true,
        });
        final downtime = _downtime;
        if (downtime != null) {
          event('latency', {
            'operation': 'streamDowntime',
            'micros': downtime.elapsedMicroseconds,
            'ok': true,
          });
          _downtime = null;
        }
        _reconnectAttempt = 0;
      },
    );
    subscription = stream;
    observedDone = stream.done.then<void>(
      (_) => _streamStopped(generation, null),
      onError: (Object error, StackTrace stack) => _streamStopped(generation, error),
    );
    event('streamStarted', {'reconnect': reconnect, 'attempt': _reconnectAttempt});
  }

  void _streamStopped(int generation, Object? error) {
    if (error != null) {
      // An error is never an intentional stop, even while one is in progress.
      streamErrors++;
      unexpectedStreamEnds++;
      event('streamError', {'error': error.toString(), 'stopping': stopping});
    } else {
      event('streamEnded', {'expected': stopping});
      if (!stopping) unexpectedStreamEnds++;
    }
    if (stopping || generation != _generation) return;
    subscription = null;
    observedDone = null;
    _scheduleReconnect();
  }

  /// Bounded exponential backoff with seeded jitter, one pending timer per
  /// device. Only streaming states during the workload reconnect.
  void _scheduleReconnect() {
    if (!supervising || !streamingStates.contains(state)) return;
    final attempt = ++_reconnectAttempt;
    final ceiling = min(
      maxReconnectDelayMs,
      options.number('reconnect-ms') * pow(2, min(attempt - 1, 20)).toInt(),
    );
    final delayMs = ceiling ~/ 2 + reconnectRandom.nextInt(ceiling ~/ 2 + 1);
    _downtime ??= Stopwatch()..start();
    reconnectsScheduled++;
    event('streamReconnectScheduled', {'attempt': attempt, 'delayMs': delayMs});
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      _reconnectTimer = null;
      if (!supervising ||
          !streamingStates.contains(state) ||
          subscription != null ||
          session == null) {
        return;
      }
      reconnects++;
      startStream(reconnect: true);
    });
  }

  /// Credits time since the last call to [as], or to the current state.
  void _account([String? as]) {
    if (!_residency.isRunning) return;
    residencyMicros.update(
      as ?? state,
      (v) => v + _residency.elapsedMicroseconds,
      ifAbsent: () => _residency.elapsedMicroseconds,
    );
    _residency.reset();
  }

  void beginResidency() => _residency
    ..reset()
    ..start();

  void endResidency() {
    _account();
    _residency.stop();
  }

  /// Stopping streams and opening or closing databases is its own residency
  /// state: the device neither writes nor serves the old or new state then.
  Future<void> setState(String next, String secret) async {
    if (next == state) return;
    _account();
    transitioning = true;
    try {
      if (next == 'closed' || next == 'offline') await stopStream();
      if (next == 'closed') {
        await session?.close();
        session = null;
        client?.close();
        client = null;
      } else {
        await open(secret);
      }
    } finally {
      transitioning = false;
      _account('transition');
    }
    state = next;
    if (streamingStates.contains(next) && subscription == null) startStream();
    event('state', {'state': state});
  }

  Future<void> once(String secret) async {
    await stopStream();
    await open(secret);
    await measure('syncOnce', () => client!.offlineSync.syncOnce(session!));
  }

  UuidValue cityId(int city) => benchmarkId('${options.runId}/user/$user/city/$city');

  String seedCityName(int city) => 'City $user/$city';

  Future<void> seed() async {
    await measure('seed', () async {
      final count = options.number('seed-rows');
      for (var start = 0; start < count; start += 500) {
        final batch = [
          for (var i = start; i < min(count, start + 500); i++)
            City(id: cityId(i), name: seedCityName(i)),
        ];
        await session!.db.transactionForUser(
          userId,
          (transaction) => City.db.insert(session!, batch, transaction: transaction),
        );
      }
    });
  }

  String payload(int seq) => seededPayload(
    mixSeed([options.number('seed'), user, index, seq]),
    options.number('payload-bytes'),
    'u$user.d$index.s$seq:',
  );

  Future<void> operate() async {
    final seq = sequence++;
    operationAttempts++;
    final choice = random.nextInt(100);
    final kind = choice < 35
        ? 'insert'
        : choice < 60
        ? 'updateShared'
        : choice < 75 && towns.isNotEmpty
        ? 'update'
        : choice < 85 && towns.isNotEmpty
        ? 'delete'
        : 'read';
    final receiptId = benchmarkId(
      '${options.runId}/user/$user/device/$index/receipt/$seq',
    ).toString();
    final townIds = towns.keys.toList();
    final chosenTown = townIds.isEmpty ? null : townIds[random.nextInt(townIds.length)];
    final selectedCity = cityId(random.nextInt(options.number('seed-rows')));
    final townId = kind == 'insert'
        ? benchmarkId('${options.runId}/user/$user/device/$index/town/$seq').toString()
        : chosenTown;
    // A rename must change the stored value, even for one-byte payloads.
    final name = switch (kind) {
      'insert' => payload(seq),
      'update' => distinctFrom(towns[townId]!['name'] as String?, payload(seq)),
      _ => null,
    };
    final cityName = 'Edited $index/$seq';
    final receiptName = 'receipt:$user:$index:$seq';
    await measure(kind, () async {
      if (kind == 'read') {
        await Town.db.find(session!, limit: 20, orderBy: (t) => t.id);
        return;
      }
      await session!.db.transactionForUser(userId, (transaction) async {
        // Missing own rows mean local data loss; fail rather than journal a
        // write that never happened.
        switch (kind) {
          case 'insert':
            await Town.db.insertRow(
              session!,
              Town(
                id: UuidValue.withValidation(townId!),
                name: name!,
                cityId: selectedCity,
              ),
              transaction: transaction,
            );
          case 'updateShared':
            final updated = await City.db.updateById(
              session!,
              selectedCity,
              columnValues: (t) => [t.name(cityName)],
              transaction: transaction,
            );
            if (updated == null) throw StateError('City $selectedCity is missing.');
          case 'update':
            final updated = await Town.db.updateById(
              session!,
              UuidValue.withValidation(townId!),
              columnValues: (t) => [t.name(name!), t.cityId(selectedCity)],
              transaction: transaction,
            );
            if (updated == null) throw StateError('Own town $townId is missing.');
          case 'delete':
            final deleted = await Town.db.deleteWhere(
              session!,
              where: (t) => t.id.equals(UuidValue.withValidation(townId!)),
              transaction: transaction,
            );
            if (deleted.length != 1) throw StateError('Own town $townId is missing.');
        }
        // An immutable delivery receipt commits with each write. This prevents
        // matching empty/incomplete snapshots from masquerading as convergence.
        await Person.db.insertRow(
          session!,
          Person(
            id: UuidValue.withValidation(receiptId),
            name: receiptName,
            surname: kind,
          ),
          transaction: transaction,
        );
      });
    });
    switch (kind) {
      case 'insert' || 'update':
        towns[townId!] = {
          'name': name,
          'cityId': selectedCity.toString(),
          'mayorId': null,
        };
      case 'delete':
        towns.remove(townId);
      case 'updateShared':
        cityEdits[selectedCity.toString()] = cityName;
    }
    if (kind != 'read') {
      writes++;
      receipts[receiptId] = {'name': receiptName, 'surname': kind};
    }
    event('operation', {
      'sequence': seq,
      'kind': kind,
      'receiptId': kind == 'read' ? null : receiptId,
      'townId': kind == 'insert' || kind == 'update' || kind == 'delete'
          ? townId
          : null,
      'cityId': selectedCity.toString(),
      'state': state,
    });
  }

  Future<DeviceSnapshot> snapshot() async {
    final tables = {
      'person': (await Person.db.find(session!)).map((r) => r.toJson()).toList(),
      'city': (await City.db.find(session!)).map((r) => r.toJson()).toList(),
      'town': (await Town.db.find(session!)).map((r) => r.toJson()).toList(),
    };
    return DeviceSnapshot(snapshotOf(tables), tables['city']!, tables['town']!);
  }

  Future<void> close() async {
    supervising = false;
    await stopStream();
    await session?.close();
    session = null;
    client?.close();
    client = null;
    state = 'closed';
  }
}

class DeviceSnapshot {
  DeviceSnapshot(this.summary, this.cities, this.towns);

  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> cities;
  final List<Map<String, dynamic>> towns;
}

/// Seeds each user from its first device, which syncs before the others, with
/// every sync taking its own permit from the worker-wide [permits].
Future<void> seedGroups<D>(
  Iterable<List<D>> groups,
  Semaphore permits, {
  required Future<void> Function(D device) seedLocal,
  required Future<void> Function(D device) sync,
}) => Future.wait(
  groups.map((group) async {
    await seedLocal(group.first);
    await permits.run(() => sync(group.first));
    await Future.wait(group.skip(1).map((d) => permits.run(() => sync(d))));
  }),
);

class ScaleWorker {
  ScaleWorker(this.options, this.worker, this.emit, this.secret)
    : admin = Client(options.target)..authKeyProvider = BenchmarkAuth(secret);

  final ScaleOptions options;
  final int worker;
  final Emit emit;
  final String secret;
  final Client admin;
  final devices = <Device>[];
  final lag = LoopLag();
  String phase = 'init';
  Timer? sampler;
  bool closed = false;

  Iterable<int> get users => options.usersOf(worker);

  int get concurrency => options.number('setup-concurrency');

  /// One pool for every network call made during setup and verification, so
  /// the per-worker cap holds across users and their devices.
  late final syncPermits = Semaphore(concurrency);

  List<Device> devicesFor(int user) => devices.where((d) => d.user == user).toList();

  void sample() {
    try {
      emit({
        'type': 'workerSample',
        'process': processSample(),
        'loopLag': lag.takeWindow(),
        'states': {
          for (final state in states)
            state: devices.where((d) => !d.transitioning && d.state == state).length,
          'transition': devices.where((d) => d.transitioning).length,
        },
        'storage': {
          for (final key in ['databaseBytes', 'walBytes', 'shmBytes'])
            key: devices.fold<int>(0, (sum, d) => sum + sqliteFiles(d.path)[key]!),
        },
      });
    } on Object catch (error) {
      emit({'type': 'workerSampleError', 'error': error.toString()});
    }
  }

  Future<void> initialize() async {
    lag.start();
    // Before any device exists, so per-device costs can exclude the process.
    emit({'type': 'workerBaseline', 'process': processSample()});
    for (final user in users) {
      for (var index = 0; index < options.devicesFor(user); index++) {
        devices.add(Device(options, user, index, emit, ordinal: devices.length));
      }
    }
    await Future.wait(
      users.map(
        (user) => syncPermits.run(
          () => control(admin, {
            'action': 'provision',
            'userId': benchmarkId('${options.runId}/user/$user').toString(),
          }),
        ),
      ),
    );
    await forEachBounded(devices, concurrency, (device) async {
      await device.open(secret);
      device.state = 'offline';
      emit({
        'type': 'device',
        'user': device.user,
        'device': device.index,
        'ordinal': device.ordinal,
        'startOffsetMs': device.startOffsetMs,
        'churnOffsetMs': options.churnOffsetMs(device.user, device.index),
        'userId': device.userId.toString(),
        'databasePath': device.path,
      });
    });
    sampler = Timer.periodic(
      Duration(seconds: options.number('sample-seconds')),
      (_) => sample(),
    );
  }

  Future<void> seed() async {
    await seedGroups(
      [for (final user in users) devicesFor(user)],
      syncPermits,
      seedLocal: (device) => device.seed(),
      sync: (device) => device.once(secret),
    );
    emit({
      'type': 'syncPermits',
      'permits': syncPermits.permits,
      'peak': syncPermits.peak,
    });
  }

  Future<void> exercise() async {
    final watch = Stopwatch()..start();
    final durationMs = options.number('duration') * 1000;
    final cpuStart = cpuSeconds();
    lag.marks['exercise'] = Latencies();
    await Future.wait(
      devices.map((device) => _exerciseDevice(device, watch, durationMs)),
    );
    final exerciseLag = lag.marks.remove('exercise')!;
    final wallSeconds = watch.elapsedMicroseconds / 1e6;
    final cpuEnd = cpuSeconds();
    final nominal = devices.fold<double>(
      0,
      (sum, d) =>
          sum +
          writerStates.fold<int>(0, (s, state) => s + (d.residencyMicros[state] ?? 0)) /
              1000 /
              options.nominalCycleMs,
    );
    emit({
      'type': 'generatorExercise',
      'devices': devices.length,
      'wallSeconds': wallSeconds,
      'cpuSeconds': cpuStart == null ? null : cpuEnd! - cpuStart,
      'cpuCores': cpuStart == null ? null : (cpuEnd! - cpuStart) / wallSeconds,
      'loopLag': exerciseLag.toJson(),
      'nominalOperationAttempts': nominal,
      'operationAttempts': devices.fold<int>(0, (sum, d) => sum + d.operationAttempts),
      'process': processSample(),
    });
  }

  Future<void> _exerciseDevice(Device device, Stopwatch watch, int durationMs) async {
    final waitMs = device.startOffsetMs - watch.elapsedMilliseconds;
    if (waitMs > 0) await Future<void>.delayed(Duration(milliseconds: waitMs));
    final startedMs = watch.elapsedMilliseconds;
    device
      ..supervising = true
      ..beginResidency();
    var epoch = -1;
    while (watch.elapsedMilliseconds < durationMs) {
      final nextEpoch = options.epochAt(
        device.user,
        device.index,
        watch.elapsedMilliseconds,
      );
      if (epoch != nextEpoch) {
        final assigned = options.stateFor(device.user, device.index, nextEpoch);
        device.event('assignment', {
          'epoch': nextEpoch,
          'state': assigned,
          'previous': device.state,
          'initial': epoch == -1,
        });
        epoch = nextEpoch;
        await device.setState(assigned, secret);
      }
      if (writerStates.contains(device.state)) await device.operate();
      final jitter = device.random.nextInt(max(1, options.number('interval-ms') ~/ 4));
      await Future<void>.delayed(
        Duration(milliseconds: options.number('interval-ms') + jitter),
      );
    }
    device
      ..endResidency()
      ..supervising = false;
    await device.stopStream();
    device.event('residency', {
      'startedMs': startedMs,
      'seconds': {
        for (final entry in device.residencyMicros.entries)
          entry.key: entry.value / 1e6,
      },
      'operationAttempts': device.operationAttempts,
      'writes': device.writes,
      'unexpectedStreamEnds': device.unexpectedStreamEnds,
      'streamErrors': device.streamErrors,
      'reconnectsScheduled': device.reconnectsScheduled,
      'reconnects': device.reconnects,
    });
  }

  Future<void> verify() async {
    final deadline = DateTime.now().add(
      Duration(seconds: options.number('timeout-seconds')),
    );
    await Future.wait(users.map((user) => _verifyUser(user, deadline)));
    emit({
      'type': 'syncPermits',
      'permits': syncPermits.permits,
      'peak': syncPermits.peak,
    });
  }

  UserExpectation expectationFor(List<Device> group) {
    final cityEdits = <String, Set<String>>{};
    for (final device in group) {
      for (final entry in device.cityEdits.entries) {
        (cityEdits[entry.key] ??= {}).add(entry.value);
      }
    }
    final first = group.first;
    return UserExpectation(
      receipts: {for (final d in group) ...d.receipts},
      towns: {for (final d in group) ...d.towns},
      seedCities: {
        for (var i = 0; i < options.number('seed-rows'); i++)
          first.cityId(i).toString(): first.seedCityName(i),
      },
      cityEdits: cityEdits,
    );
  }

  Future<void> _verifyUser(int user, DateTime deadline) async {
    final group = devicesFor(user);
    final expectation = expectationFor(group);
    final timer = Stopwatch()..start();
    var rounds = 0;
    while (true) {
      rounds++;
      await Future.wait(group.map((d) => syncPermits.run(() => d.once(secret))));
      final server = await syncPermits.run(
        () => control(admin, {
          'action': 'snapshot',
          'userId': group.first.userId.toString(),
        }),
      );
      final snapshots = await Future.wait(group.map((d) => d.snapshot()));
      final problems = expectation.mismatches(
        server: server,
        replicas: [for (final s in snapshots) s.summary],
        replicaCities: snapshots.first.cities,
      );
      final report = {
        'type': 'convergence',
        'user': user,
        'ok': problems.isEmpty,
        'rounds': rounds,
        'micros': timer.elapsedMicroseconds,
        'expectedRows': expectation.rows,
        'server': server,
        'devices': [for (final s in snapshots) s.summary],
      };
      if (problems.isEmpty) {
        emit(report);
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        emit({
          ...report,
          'problems': problems,
          'expectedReceiptsDigest': expectation.receiptsDigest,
          'expectedTownsDigest': expectation.townsDigest,
          'townDiff': expectation.townDiff(snapshots.first.towns),
        });
        throw StateError(
          'User $user did not converge to its write journal: ${problems.join('; ')}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> close() async {
    if (closed) return;
    closed = true;
    sampler?.cancel();
    await Future.wait(devices.map((d) => d.close()));
    sample();
    lag.stop();
    for (final device in devices) {
      emit({
        'type': 'deviceStorage',
        'user': device.user,
        'device': device.index,
        'path': device.path,
        ...sqliteFiles(device.path),
      });
    }
    admin.close();
  }
}

Future<void> workerMain() async {
  ScaleWorker? worker;
  void emit(Map<String, dynamic> event) {
    stdout.writeln(
      '@benchmark ${jsonEncode({'time': DateTime.now().toUtc().toIso8601String(), 'phase': worker?.phase ?? 'init', ...event})}',
    );
  }

  try {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final command = jsonDecode(line) as Map<String, dynamic>;
      final phase = command['phase'] as String;
      if (phase == 'init') {
        worker = ScaleWorker(
          ScaleOptions(command['options'] as Map<String, dynamic>),
          command['worker'] as int,
          emit,
          requireSecret(),
        );
      }
      worker!.phase = phase;
      switch (phase) {
        case 'init':
          await worker.initialize();
        case 'seed':
          await worker.seed();
        case 'exercise':
          await worker.exercise();
        case 'verify':
          await worker.verify();
        case 'close':
          await worker.close();
      }
      emit({'type': 'done', 'phase': phase});
      if (phase == 'close') return;
    }
  } on Object catch (error, stack) {
    emit({'type': 'fatal', 'error': error.toString(), 'stack': stack.toString()});
    exitCode = 1;
  } finally {
    await worker?.close();
  }
}
