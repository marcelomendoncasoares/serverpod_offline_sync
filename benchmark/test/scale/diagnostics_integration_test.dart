import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
// Serverpod's PostgreSQL schema renderer is not exported by its public barrel.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart' show DatabaseDefinition;
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/diagnostics.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_worker.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server_diagnostics.dart';
import 'package:serverpod_offline_sync_benchmark/scale/worker.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show OfflineSyncClientExtension;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:serverpod_offline_sync_test_server/src/generated/sync_tables.dart';
import 'package:test/test.dart';

const secret = 'local-diagnostics-test-secret';

// The PostgreSQL server and SQLite clients have separate isolate-local SQL
// encoders, just as they do in the deployed benchmark's separate processes.
Future<void> serveDiagnostics((String, SendPort) arguments) async {
  final (path, ready) = arguments;
  final directory = Directory(path);
  final commands = ReceivePort();
  try {
    final pod = Serverpod(
      ['--apply-migrations'],
      model.Protocol(),
      BenchmarkEndpoints(),
      serverDirectory: directory,
      config: ServerpodConfig(
        apiServer: ServerConfig(
          port: 0,
          publicHost: 'localhost',
          publicPort: 0,
          publicScheme: 'http',
        ),
        database: PostgresDatabaseConfig.embedded(
          dataPath: '${directory.path}/postgres',
          name: 'diagnostics',
          maxConnectionCount: 6,
        ),
        sessionLogs: SessionLogConfig(
          persistentEnabled: false,
          consoleEnabled: false,
          cleanupInterval: const Duration(days: 1),
          retentionPeriod: const Duration(days: 1),
          retentionCount: 100,
        ),
      ),
      authenticationHandler: benchmarkAuthentication(secret),
      databaseInterceptor: benchmarkDatabaseInterceptor,
    )..initializeOfflineSync(syncTables: syncTables, maxConcurrentMerges: 2);
    await pod.start();
    ready.send({
      'target': 'http://127.0.0.1:${pod.server.port}/',
      'commands': commands.sendPort,
    });

    await for (final message in commands) {
      final (action, reply) = message as (String, SendPort);
      try {
        if (action == 'gap') {
          late Map<String, dynamic> traceResult;
          late int idleTransactions;
          final session = await pod.createSession();
          final observer = await pod.createSession();
          final entered = Completer<void>();
          final release = Completer<void>();
          final trace = SyncTrace(
            side: 'server',
            requestId: 'idle-gap',
            runId: 'idle-gap',
            userId: 'test',
            deviceId: 'test',
            once: true,
            output: (e) {
              traceResult = e;
            },
          );
          final transaction = trace.run(
            () => session.db.transaction((tx) async {
              await session.db.unsafeQuery('SELECT 1', transaction: tx);
              entered.complete();
              await release.future;
              await session.db.unsafeQuery('SELECT 2', transaction: tx);
            }),
          );
          try {
            await entered.future;
            idleTransactions =
                (await observer.db.unsafeQuery(
                      "SELECT count(*)::int FROM pg_stat_activity WHERE datname = current_database() AND state = 'idle in transaction'",
                    )).single.single
                    as int;
          } finally {
            release.complete();
            await transaction;
            trace.finish(outcome: 'completed');
            await session.close();
            await observer.close();
          }
          reply.send({'trace': traceResult, 'idle': idleTransactions});
        } else {
          await serverDiagnostics.stop();
          await pod.shutdown(exitProcess: false);
          commands.close();
          reply.send(null);
        }
      } on Object catch (error, stack) {
        reply.send({'error': '$error', 'stack': '$stack'});
      }
    }
  } on Object catch (error, stack) {
    ready.send({'error': '$error', 'stack': '$stack'});
    commands.close();
  }
}

void main() {
  late Directory directory;
  late SendPort commands;
  late client.Client admin;
  late String target;
  Future<Map?> command(String name) async {
    final reply = ReceivePort();
    commands.send((name, reply.sendPort));
    final result = await reply.first as Map?;
    reply.close();
    if (result?['error'] != null) fail('${result!['error']}\n${result['stack']}');
    return result;
  }

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sync-diagnostics-pg-');
    final protocol = await Isolate.resolvePackageUri(
      Uri.parse(
        'package:serverpod_offline_sync_test_server/src/generated/protocol.dart',
      ),
    );
    final migrations = Directory(
      p.join(File.fromUri(protocol!).parent.path, '../../../migrations'),
    );
    final versions = await File(
      p.join(migrations.path, 'migration_registry.txt'),
    ).readAsLines();
    final version = versions.lastWhere((v) => v.trim().isNotEmpty);
    final output = Directory(p.join(directory.path, 'migrations', version));
    await output.create(recursive: true);
    await for (final file in Directory(p.join(migrations.path, version)).list()) {
      if (file is File) await file.copy(p.join(output.path, p.basename(file.path)));
    }
    final definition = DatabaseDefinition.fromJson(
      jsonDecode(
            await File(p.join(output.path, 'definition.json')).readAsString(),
          )
          as Map<String, dynamic>,
    );
    final sql = definition.toPgSql(installedModules: definition.installedModules);
    await File(p.join(output.path, 'definition.sql')).writeAsString(sql);
    await File(p.join(output.path, 'migration.sql')).writeAsString(sql);
    await File(
      p.join(directory.path, 'migrations/migration_registry.txt'),
    ).writeAsString('$version\n');
    final ready = ReceivePort();
    await Isolate.spawn(serveDiagnostics, (directory.path, ready.sendPort));
    final initialized = await ready.first as Map;
    ready.close();
    if (initialized['error'] != null) {
      fail('${initialized['error']}\n${initialized['stack']}');
    }
    target = initialized['target'] as String;
    commands = initialized['commands'] as SendPort;
    admin = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);
  });

  tearDownAll(() async {
    admin.close();
    await command('shutdown');
    await directory.delete(recursive: true);
  });

  group('Given two devices using the instrumented PostgreSQL server,', () {
    late List<Device> devices;
    late List<Map<String, dynamic>> events;
    late List<Map<String, dynamic>> serverEvents;
    late List<Map<String, dynamic>> snapshots;
    late int activeRequests;
    late Map<String, dynamic> databaseProfile;

    setUpAll(() async {
      events = [];
      final options = ScaleOptions.parse([
        '--target',
        target,
        '--data-dir',
        directory.path,
        '--run-id',
        'diagnostics-transport',
        '--seed-rows',
        '2',
      ]);
      devices = [Device(options, 0, 0, events.add), Device(options, 0, 1, events.add)];
      await control(admin, {
        'action': 'provision',
        'userId': devices.first.userId.toString(),
      });
      await Future.wait(devices.map((d) => d.open(secret)));
      await devices.first.seed();
    });

    tearDownAll(() async {
      await Future.wait(devices.map((d) => d.close()));
    });

    group('when both devices sync and a continuous stream is cancelled,', () {
      setUpAll(() async {
        await devices.first.once(secret);
        await devices.last.once(secret);
        snapshots = [for (final d in devices) (await d.snapshot()).summary];
        final merged = Completer<void>();
        final continuous = SyncTrace(
          side: 'client',
          requestId: 'cancel',
          runId: 'diagnostics-transport',
          userId: devices.first.userId.toString(),
          deviceId: '0/0',
          once: false,
          output: events.add,
        );
        final stream = continuous.run(
          () => devices.first.client!.offlineSync.syncContinuously(
            devices.first.session!,
            onMergeSuccess: (_, _) {
              if (!merged.isCompleted) merged.complete();
            },
          ),
        );
        // A complete once session already drained both queues; cancellation must
        // also work before any continuous callback or next incoming message.
        await stream.cancel().timeout(const Duration(seconds: 5));
        await stream.done;
        continuous.finish(outcome: 'cancelled');
        var diagnostics = await control(admin, {'action': 'diagnostics'});
        for (
          var attempt = 0;
          attempt < 50 && diagnostics['activeRequests'] != 0;
          attempt++
        ) {
          diagnostics = await control(admin, {'action': 'diagnostics'});
        }
        activeRequests = diagnostics['activeRequests'] as int;
        serverEvents = (diagnostics['records'] as List)
            .cast<Map<String, dynamic>>()
            .where((r) => r['runId'] == 'diagnostics-transport')
            .toList();
        databaseProfile = await control(admin, {
          'action': 'databaseDiagnostics',
          'enable': true,
        });
      });

      test('then request IDs correlate actual transport, merge and SQL timings.', () {
        final clients = events
            .where((e) => e['type'] == 'syncTrace' && e['once'] == true)
            .toList();
        final servers = serverEvents
            .where((e) => e['type'] == 'syncTrace' && e['once'] == true)
            .toList();
        expect(clients, hasLength(2));
        expect(servers, hasLength(2));
        expect(servers.every((e) => e['transport'] == 'stream'), isTrue);
        expect(
          servers.map((e) => e['requestId']),
          unorderedEquals(clients.map((e) => e['requestId'])),
        );
        final merge = serverEvents.firstWhere((e) => e['type'] == 'mergeTrace');
        expect(merge['queue'], containsPair('concurrencyLimit', 2));
        final tx = (merge['transactions'] as List).single as Map;
        expect(tx['statements'], greaterThan(0));
        expect(merge['commitNotifications'], isNotEmpty);
        expect(tx['bodyMicros'], greaterThanOrEqualTo(tx['sqlWallMicros'] as int));
        expect(servers.first['sql'] as List, isNotEmpty);
        expect((servers.first['wire'] as Map)['received'], containsPair('changes', 2));
      });

      test(
        'then completed batches have separate acknowledgement and worker timings.',
        () {
          final traces = serverEvents
              .where((e) => e['type'] == 'syncTrace' && e['once'] == true)
              .toList();
          final batches = serverEvents
              .where((e) => e['type'] == 'syncBatchTrace')
              .toList();

          expect(batches, isNotEmpty);
          expect(
            batches.every((e) => (e['acknowledgementWaitMicros'] as int) >= 0),
            isTrue,
          );
          expect(traces.every((e) => (e['pendingBatchIds'] as List).isEmpty), isTrue);
          expect(
            traces.every((e) => e['batchesSent'] == e['batchesCommitted']),
            isTrue,
          );
          expect(
            traces.every(
              (e) => (e['timings'] as Map).containsKey('sync.outboundCapture'),
            ),
            isTrue,
          );
          expect(
            traces.every((e) => (e['timings'] as Map).containsKey('sync.inboundBatch')),
            isTrue,
          );
        },
      );

      test('then the replicas converge and cancellation leaves no active request.', () {
        expect(snapshots.first, snapshots.last);
        expect(activeRequests, 0);
        expect(events.last['outcome'], 'cancelled');
      });

      test(
        'then hot queries have read-only execution plans and table scan statistics.',
        () {
          expect(databaseProfile['tables'], isNotEmpty);
          final plans = databaseProfile['plans'] as List;
          expect(plans, isNotEmpty);
          expect(
            plans.where((dynamic p) => (p as Map).containsKey('plan')),
            isNotEmpty,
          );
          expect(plans.where((dynamic p) => (p as Map).containsKey('error')), isEmpty);
        },
      );
    });
  });

  group('Given two devices with established continuous streams,', () {
    late RoundWorker worker;
    late List<Map<String, dynamic>> events;
    late Map<String, dynamic> before;

    setUpAll(() async {
      events = [];
      worker = RoundWorker(
        RoundOptions.parse([
          '--target',
          target,
          '--data-dir',
          directory.path,
          '--run-id',
          'rounds-continuous',
          '--users',
          '1',
          '--devices',
          '2',
          '--workers',
          '1',
          '--rounds',
          '3',
          '--rows',
          '2',
          '--period-ms',
          '50',
        ]),
        0,
        events.add,
        secret,
      );
      await worker.initialize();
      await worker.warmup();
      before = await control(admin, {'action': 'metrics'});
    });

    tearDownAll(() => worker.close());

    group('when alternating writers replicate three incremental batches,', () {
      late List<Map<String, dynamic>> rounds;
      late Map<String, dynamic> after;

      setUpAll(() async {
        await worker.exercise();
        await worker.verify();
        after = await control(admin, {'action': 'metrics'});
        rounds = events
            .where((e) => e['type'] == 'round' && (e['round'] as int) >= 0)
            .toList();
      });

      test('then every measured batch reaches the peer with exact values.', () {
        expect(rounds, hasLength(3));
        expect(rounds.map((r) => r['writer']), [0, 1, 0]);
        expect(rounds.every((r) => r['ok'] == true && r['rows'] == 2), isTrue);
        expect(rounds.every((r) => (r['writeToAllPeersMicros'] as int) > 0), isTrue);
        expect(events.where((e) => e['type'] == 'verified').single['rows'], 8);
      });

      test('then the same two streams remain open without any one-shot repair.', () {
        expect((before['streams'] as Map)['open'], 2);
        expect((after['streams'] as Map)['open'], 2);
        expect(
          (after['streams'] as Map)['openedTotal'],
          (before['streams'] as Map)['openedTotal'],
        );
        expect(events.where((e) => e['type'] == 'onceCall'), isEmpty);
      });
    });
  });

  group('Given two devices without continuous streams,', () {
    late RoundWorker worker;
    late List<Map<String, dynamic>> events;

    setUpAll(() async {
      events = [];
      worker = RoundWorker(
        RoundOptions.parse([
          '--target',
          target,
          '--data-dir',
          directory.path,
          '--run-id',
          'rounds-once',
          '--mode',
          'once',
          '--users',
          '1',
          '--devices',
          '2',
          '--workers',
          '1',
          '--rounds',
          '3',
          '--rows',
          '2',
          '--period-ms',
          '50',
        ]),
        0,
        events.add,
        secret,
      );
      await worker.initialize();
      await worker.warmup();
    });

    tearDownAll(() => worker.close());

    group('when three batches use fresh one-shot push and pull calls,', () {
      late List<Map<String, dynamic>> calls;

      setUpAll(() async {
        await worker.exercise();
        await worker.verify();
        calls = events
            .where((e) => e['type'] == 'onceCall' && (e['round'] as int) >= 0)
            .toList();
      });

      test('then push and pull durations exclude warmup and include every call.', () {
        expect(calls.map((c) => c['role']), [
          'push',
          'pull',
          'push',
          'pull',
          'push',
          'pull',
        ]);
        expect(
          calls.every(
            (c) => c['ok'] == true && c['freshClient'] == true && c['retries'] == 0,
          ),
          isTrue,
        );
        expect(calls.every((c) => (c['micros'] as int) > 0), isTrue);
      });

      test('then all replicas match the complete journal without continuous sync.', () {
        expect(events.where((e) => e['type'] == 'verified').single['rows'], 8);
        expect(events.where((e) => e['type'] == 'streamStarted'), isEmpty);
        expect(
          events
              .where((e) => e['type'] == 'round' && (e['round'] as int) >= 0)
              .map((e) => e['ok']),
          [true, true, true],
        );
      });
    });
  });

  group('Given two users with client diagnostics disabled and one sampled user,', () {
    late RoundWorker worker;
    late List<Map<String, dynamic>> events;
    late String selectedUser;
    late int cursor;
    late String diagnosticInstance;

    setUpAll(() async {
      events = [];
      selectedUser = benchmarkId('sampled-rounds/user/0').toString();
      final tail = await control(admin, {'action': 'diagnostics', 'tail': true});
      cursor = tail['latestSequence'] as int;
      diagnosticInstance = tail['instanceId'] as String;
      await control(admin, {
        'action': 'configureSampling',
        'runId': 'sampled-rounds',
        'userIds': [selectedUser],
      });
      worker = RoundWorker(
        RoundOptions.parse([
          '--target',
          target,
          '--data-dir',
          directory.path,
          '--run-id',
          'sampled-rounds',
          '--users',
          '2',
          '--devices',
          '2',
          '--workers',
          '1',
          '--rounds',
          '4',
          '--rows',
          '1',
          '--period-ms',
          '50',
          '--no-sync-diagnostics',
        ]),
        0,
        events.add,
        secret,
      );
      await worker.initialize();
    });

    tearDownAll(() async {
      await worker.close();
      await control(admin, {
        'action': 'configureSampling',
        'runId': 'disabled',
        'userIds': <String>[],
      });
    });

    group('when both devices exchange rounds and close their streams,', () {
      late List<Map<String, dynamic>> records;
      late Map<String, dynamic> cleanup;

      setUpAll(() async {
        await worker.warmup();
        await worker.exercise();
        await worker.verify();
        await worker.close();
        cleanup = await control(admin, {'action': 'metrics'});
        records = [];
        while (true) {
          final page = await control(admin, {
            'action': 'diagnostics',
            'cursors': {diagnosticInstance: cursor},
          });
          final rows = (page['records'] as List).cast<Map<String, dynamic>>();
          records.addAll(rows.where((r) => (r['sequence'] as int) > cursor));
          cursor = page['nextSequence'] as int;
          if (cursor >= (page['latestSequence'] as int)) break;
        }
        records = records.where((r) => r['runId'] == 'sampled-rounds').toList();
      });

      test('then both users converge while only the selected user is traced.', () {
        expect(events.where((e) => e['type'] == 'verified'), hasLength(2));
        expect(records, isNotEmpty);
        expect(records.every((r) => r['userId'] == selectedUser), isTrue);
        final streams = records.where((r) => r['type'] == 'syncTrace').toList();
        expect(streams, hasLength(2));
        expect(streams.map((r) => r['deviceId']).toSet(), hasLength(2));
        expect(streams.every((r) => r['sampled'] == true), isTrue);
        expect(cleanup['streams'], containsPair('open', 0));
      });

      test('then sampled SQL timings and complete spans survive stream closure.', () {
        final transactions = records.where((r) => r['type'] == 'syncTransaction');
        expect(transactions, isNotEmpty);
        expect(transactions.every((t) => t['ok'] == true), isTrue);
        expect(transactions.any((t) => (t['statements'] as int) > 0), isTrue);
        final timeline = records
            .where((r) => r['type'] == 'syncTimeline')
            .map((r) => r['event'] as Map);
        expect(timeline.any((e) => e['name'] == 'sync.batchSent'), isTrue);
        expect(
          timeline.where((e) => e['kind'] == 'start').length,
          timeline.where((e) => e['kind'] == 'end').length,
        );
        final streams = records.where((r) => r['type'] == 'syncTrace');
        expect(streams.every((r) => r['payloadBytesMeasured'] == false), isTrue);
        expect(streams.every((r) => r['droppedDetails'] == 0), isTrue);
        expect(streams.every((r) => (r['unfinishedSpans'] as List).isEmpty), isTrue);
        expect(
          streams.every(
            (r) => (r['sql'] as List).every(
              (dynamic sql) => sql['sqlId'] == 'aggregate' && sql['statement'] == null,
            ),
          ),
          isTrue,
        );
      });

      test(
        'then every sampled exercise round has matching numbered frames on both devices.',
        () {
          final frames = records.where((r) => r['type'] == 'syncFrame').toList();
          Set<int> rounds(String direction) => {
            for (final frame in frames)
              if (frame['direction'] == direction && frame['frame'] == 'chunk')
                for (final round in (frame['rounds'] as List).cast<Map>())
                  if ((round['round'] as int) >= 0) round['round'] as int,
          };

          expect(rounds('received'), {0, 1, 2, 3});
          expect(rounds('yielded'), {0, 1, 2, 3});
          expect(frames.every((f) => f['processMicros'] is int), isTrue);
          final merges = records.where((r) => r['type'] == 'mergeTrace');
          expect(merges.every((m) => m['batchId'] is int), isTrue);
          for (final merge in merges) {
            final incoming = frames
                .where(
                  (frame) =>
                      frame['requestId'] == merge['requestId'] &&
                      frame['batchId'] == merge['batchId'] &&
                      frame['direction'] == 'received' &&
                      frame['frame'] == 'end',
                )
                .single;
            final start =
                (merge['processOriginMicros'] as int) + (merge['startMicros'] as int);
            expect(start, greaterThanOrEqualTo(incoming['processMicros'] as int));
          }
        },
      );
    });
  });

  group('Given a transaction paused between SQL statements,', () {
    late Map<String, dynamic> traceResult;
    late int idleTransactions;

    group(
      'when PostgreSQL reports it idle in transaction and the await is released,',
      () {
        setUpAll(() async {
          final result = (await command('gap'))!;
          traceResult = result['trace'] as Map<String, dynamic>;
          idleTransactions = result['idle'] as int;
        });

        test(
          'then non-SQL transaction time is visible without counting it as SQL.',
          () {
            expect(idleTransactions, greaterThanOrEqualTo(1));
            final tx = (traceResult['transactions'] as List).single as Map;
            expect(tx['statements'], 2);
            expect(tx['unattributedBodyMicros'], greaterThan(0));
            expect(
              (tx['sqlWallMicros'] as int) + (tx['unattributedBodyMicros'] as int),
              tx['bodyMicros'],
            );
          },
        );
      },
    );
  });
}
