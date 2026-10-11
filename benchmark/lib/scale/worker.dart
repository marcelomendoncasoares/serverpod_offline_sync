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

typedef Emit = void Function(Map<String, dynamic> event);

class Device {
  Device(this.options, this.user, this.index, this.emit)
    : random = Random(options.number('seed') + user * 104729 + index * 1009),
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
  final Emit emit;
  final Random random;
  final UuidValue userId;
  final String path;
  final receipts = <String>[];
  final towns = <UuidValue>[];
  Client? client;
  OfflineSyncDatabaseSession? session;
  OfflineSyncSubscription? subscription;
  Future<void>? observedDone;
  String state = 'closed';
  var sequence = 0;
  var stopping = false;
  var streamFailures = 0;

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
    try {
      await subscription?.cancel();
      await observedDone;
    } finally {
      subscription = null;
      observedDone = null;
      stopping = false;
    }
  }

  void startStream() {
    final stream = client!.offlineSync.syncContinuously(
      session!,
      onMergeSuccess: (_, _) => event('merge', {}),
    );
    subscription = stream;
    observedDone = stream.done.then<void>(
      (_) {
        event('streamEnded', {'expected': stopping});
        if (!stopping) streamFailures++;
      },
      onError: (Object error, StackTrace stack) {
        streamFailures++;
        event('streamError', {'error': error.toString()});
      },
    );
    event('streamStarted', {});
  }

  Future<void> setState(String next, String secret) async {
    if (next == state) return;
    if (next == 'closed' || next == 'offline') await stopStream();
    if (next == 'closed') {
      await session?.close();
      session = null;
      client?.close();
      client = null;
    } else {
      await open(secret);
      if (next == 'active' || next == 'idle') {
        if (subscription == null) startStream();
      }
    }
    state = next;
    event('state', {'state': state});
  }

  Future<void> once(String secret) async {
    await stopStream();
    await open(secret);
    await measure('syncOnce', () => client!.offlineSync.syncOnce(session!));
  }

  UuidValue cityId(int city) => benchmarkId('${options.runId}/user/$user/city/$city');

  Future<void> seed() async {
    await measure('seed', () async {
      for (var i = 0; i < options.number('seed-rows'); i++) {
        await City.db.insertRow(session!, City(id: cityId(i), name: 'City $user/$i'));
      }
    });
  }

  Future<void> operate() async {
    final seq = sequence++;
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
    );
    final townId = benchmarkId('${options.runId}/user/$user/device/$index/town/$seq');
    final chosenTown = towns.isEmpty ? null : towns[random.nextInt(towns.length)];
    final selectedCity = cityId(random.nextInt(options.number('seed-rows')));
    final payload = 'x' * options.number('payload-bytes');
    await measure(kind, () async {
      if (kind == 'read') {
        await Town.db.find(session!, limit: 20, orderBy: (t) => t.id);
        return;
      }
      await session!.db.transactionForUser(userId, (transaction) async {
        switch (kind) {
          case 'insert':
            await Town.db.insertRow(
              session!,
              Town(id: townId, name: payload, cityId: selectedCity),
              transaction: transaction,
            );
          case 'updateShared':
            await City.db.updateById(
              session!,
              selectedCity,
              columnValues: (t) => [t.name('Edited $index/$seq')],
              transaction: transaction,
            );
          case 'update':
            await Town.db.updateById(
              session!,
              chosenTown!,
              columnValues: (t) => [t.name(payload), t.cityId(selectedCity)],
              transaction: transaction,
            );
          case 'delete':
            await Town.db.deleteWhere(
              session!,
              where: (t) => t.id.equals(chosenTown),
              transaction: transaction,
            );
        }
        // An immutable delivery receipt commits with each write. This prevents
        // matching empty/incomplete snapshots from masquerading as convergence.
        await Person.db.insertRow(
          session!,
          Person(id: receiptId, name: 'receipt:$user:$index:$seq', surname: kind),
          transaction: transaction,
        );
      });
    });
    if (kind == 'insert') towns.add(townId);
    if (kind == 'delete') towns.remove(chosenTown);
    if (kind != 'read') receipts.add(receiptId.toString());
    event('operation', {
      'sequence': seq,
      'kind': kind,
      'receiptId': kind == 'read' ? null : receiptId.toString(),
      'townId': kind == 'insert' ? townId.toString() : chosenTown?.toString(),
      'cityId': selectedCity.toString(),
      'state': state,
    });
  }

  Future<Map<String, dynamic>> snapshot() async => snapshotOf({
    'person': (await Person.db.find(session!)).map((r) => r.toJson()).toList(),
    'city': (await City.db.find(session!)).map((r) => r.toJson()).toList(),
    'town': (await Town.db.find(session!)).map((r) => r.toJson()).toList(),
  });

  Future<void> close() async {
    await stopStream();
    await session?.close();
    session = null;
    client?.close();
    client = null;
    state = 'closed';
  }
}

class ScaleWorker {
  ScaleWorker(this.options, this.worker, this.emit, this.secret)
    : admin = Client(options.target)..authKeyProvider = BenchmarkAuth(secret);

  final ScaleOptions options;
  final int worker;
  final Emit emit;
  final String secret;
  final Client admin;
  final devices = <Device>[];
  String phase = 'init';
  Timer? sampler;

  Iterable<int> get users sync* {
    for (
      var user = worker;
      user < options.number('users');
      user += options.number('workers')
    ) {
      yield user;
    }
  }

  List<Device> devicesFor(int user) => devices.where((d) => d.user == user).toList();

  void sample() => emit({
    'type': 'workerSample',
    'process': processSample(),
    'states': {
      for (final state in ['active', 'idle', 'offline', 'closed'])
        state: devices.where((d) => d.state == state).length,
    },
    'storage': {
      for (final key in ['databaseBytes', 'walBytes', 'shmBytes'])
        key: devices.fold<int>(0, (sum, d) => sum + sqliteFiles(d.path)[key]!),
    },
  });

  Future<void> initialize() async {
    for (final user in users) {
      await control(admin, {
        'action': 'provision',
        'userId': benchmarkId('${options.runId}/user/$user').toString(),
      });
      for (var index = 0; index < options.devicesFor(user); index++) {
        final device = Device(options, user, index, emit);
        devices.add(device);
        await device.open(secret);
        device.state = 'offline';
        emit({
          'type': 'device',
          'user': user,
          'device': index,
          'userId': device.userId.toString(),
          'databasePath': device.path,
        });
        if (options.number('ramp-ms') > 0) {
          await Future<void>.delayed(Duration(milliseconds: options.number('ramp-ms')));
        }
      }
    }
    sampler = Timer.periodic(
      Duration(seconds: options.number('sample-seconds')),
      (_) => sample(),
    );
  }

  Future<void> seed() async {
    await Future.wait(
      users.map((user) async {
        final group = devicesFor(user);
        await group.first.seed();
        await group.first.once(secret);
        await Future.wait(group.skip(1).map((d) => d.once(secret)));
      }),
    );
  }

  Future<void> exercise() async {
    final watch = Stopwatch()..start();
    await Future.wait(
      devices.map((device) async {
        var epoch = -1;
        while (watch.elapsed.inSeconds < options.number('duration')) {
          final churn = options.number('churn-seconds');
          final nextEpoch = churn == 0 ? 0 : watch.elapsed.inSeconds ~/ churn;
          if (epoch != nextEpoch) {
            epoch = nextEpoch;
            await device.setState(
              options.stateFor(device.user, device.index, epoch),
              secret,
            );
          }
          if (device.state == 'active' || device.state == 'offline') {
            await device.operate();
          }
          final jitter = device.random.nextInt(
            max(1, options.number('interval-ms') ~/ 4),
          );
          await Future<void>.delayed(
            Duration(milliseconds: options.number('interval-ms') + jitter),
          );
        }
        await device.stopStream();
      }),
    );
  }

  Future<void> verify() async {
    await Future.wait(
      users.map((user) async {
        final group = devicesFor(user);
        final expectedReceipts = digestStrings(group.expand((d) => d.receipts));
        final expectedRows = {
          'person': group.fold<int>(0, (sum, d) => sum + d.receipts.length),
          'city': options.number('seed-rows'),
          'town': group.fold<int>(0, (sum, d) => sum + d.towns.length),
        };
        final timer = Stopwatch()..start();
        var rounds = 0;
        while (true) {
          rounds++;
          await Future.wait(group.map((d) => d.once(secret)));
          final server = await control(admin, {
            'action': 'snapshot',
            'userId': group.first.userId.toString(),
          });
          final snapshots = await Future.wait(group.map((d) => d.snapshot()));
          final matched =
              server['receiptsDigest'] == expectedReceipts &&
              jsonEncode(server['rows']) == jsonEncode(expectedRows) &&
              snapshots.every(
                (s) =>
                    s['digest'] == server['digest'] &&
                    s['receiptsDigest'] == expectedReceipts,
              );
          if (matched) {
            emit({
              'type': 'convergence',
              'user': user,
              'ok': true,
              'rounds': rounds,
              'micros': timer.elapsedMicroseconds,
              'expectedRows': expectedRows,
              'server': server,
              'devices': snapshots,
            });
            break;
          }
          if (timer.elapsed.inSeconds >= options.number('timeout-seconds') - 5) {
            emit({
              'type': 'convergence',
              'user': user,
              'ok': false,
              'rounds': rounds,
              'expectedRows': expectedRows,
              'expectedReceiptsDigest': expectedReceipts,
              'server': server,
              'devices': snapshots,
            });
            throw StateError(
              'User $user did not converge with all committed receipts.',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }),
    );
    if (devices.any((d) => d.streamFailures != 0)) {
      throw StateError('Unexpected stream termination occurred; see events.jsonl.');
    }
  }

  Future<void> close() async {
    sampler?.cancel();
    await Future.wait(devices.map((d) => d.close()));
    sample();
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
