import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/compression_probe.dart';
import 'package:serverpod_offline_sync_benchmark/scale/idle_connection.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_benchmark/scale/transport_probe.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:test/test.dart';

void main() {
  const secret = 'local-transport-capacity-test-secret';
  late Serverpod pod;
  late Directory directory;
  late String target;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('idle-streams-test-');
    pod = Serverpod(
      [],
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
        sessionLogs: SessionLogConfig(
          persistentEnabled: false,
          consoleEnabled: false,
          cleanupInterval: const Duration(days: 1),
          retentionPeriod: const Duration(days: 1),
          retentionCount: 100,
        ),
      ),
      authenticationHandler: benchmarkAuthentication(secret),
    );
    await pod.start();
    target = 'http://127.0.0.1:${pod.server.port}/';
  });

  tearDownAll(() async {
    await pod.shutdown(exitProcess: false);
    await directory.delete(recursive: true);
  });

  test(
    'Given an authenticated method stream and a server without a database, '
    'when it resumes after a quiet interval and closes, '
    'then both exact responses arrive and the server releases the stream.',
    () async {
      final api = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);
      final input = StreamController<String>();
      final failures = <Object>[];
      final connection = IdleConnection(
        responses:
            api.callStreamingServerEndpoint<Stream<String>, String>(
                  'benchmark',
                  'echo',
                  {},
                  {'messages': input.stream},
                )
                as Stream<String>,
        send: input.add,
        closeInput: input.close,
        closeClient: api.close,
        onFailure: failures.add,
        timeout: const Duration(seconds: 5),
      );
      final admin = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);

      await connection.exchange('connection-17/warmup');
      final held = await control(admin, {'action': 'transportMetrics'});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await connection.exchange('connection-17/resume');
      await connection.close();
      final closed = await control(admin, {'action': 'transportMetrics'});
      admin.close();

      expect(pod.config.database, isNull);
      expect((held['transport'] as Map)['open'], 1);
      expect((closed['transport'] as Map)['open'], 0);
      expect((closed['streams'] as Map)['open'], 0);
      expect(failures, isEmpty);
    },
  );

  test(
    'Given a database-free server and sixteen independent clients, '
    'when the complete idle benchmark runs in worker processes, '
    'then every connection opens resumes and closes with complete observations.',
    () async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse(
          'package:serverpod_offline_sync_benchmark/scale/idle_connection.dart',
        ),
      );
      final root = File.fromUri(library!).parent.parent.parent;
      final output = '${directory.path}/client-smoke';

      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          '${root.path}/bin/idle_streams.dart',
          '--target',
          target,
          '--output',
          output,
          '--run-id',
          'local-smoke',
          '--connections',
          '16',
          '--workers',
          '2',
          '--open-workers',
          '2',
          '--open-concurrency-per-worker',
          '2',
          '--idle-seconds',
          '1',
          '--settle-seconds',
          '1',
          '--sample-seconds',
          '1',
        ],
        environment: {...Platform.environment, 'BENCHMARK_SECRET': secret},
      );
      final summary =
          jsonDecode(await File('$output/summary.json').readAsString()) as Map;

      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(summary['status'], 'passed');
      expect(summary['opened'], 16);
      expect(summary['resumed'], 16);
      expect(summary['options']['open-concurrency-per-worker'], 2);
      expect(summary['cleanupVerified'], isTrue);
      expect(summary['sampleFailures'], 0);
      expect(summary['streamFailures'], 0);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'Given a stream requesting WebSocket compression, '
    'when it echoes a message through the ordinary Serverpod manager, '
    'then compression is negotiated and the exact message is delivered.',
    () async {
      final api = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);
      final input = StreamController<String>();
      final failures = <Object>[];
      final probe = CompressionProbe(
        target: target,
        compression: true,
        serializationManager: api.serializationManager,
        authKeyProvider: api.authKeyProvider!,
        input: input.stream,
        connectionTimeout: api.streamingConnectionTimeout,
      );
      final connection = IdleConnection(
        responses: probe.output.stream,
        send: input.add,
        closeInput: input.close,
        closeClient: api.close,
        onFailure: failures.add,
        timeout: const Duration(seconds: 5),
      );

      await connection.exchange('compressed-connection/exact-response');
      final extensions = probe.extensions;
      final httpStatusCode = probe.httpStatusCode;
      await connection.close();
      await probe.close();

      expect(extensions, contains('permessage-deflate'));
      expect(httpStatusCode, HttpStatus.switchingProtocols);
      expect(failures, isEmpty);
    },
  );

  test(
    'Given a stream disabling WebSocket compression, '
    'when it echoes a message through the ordinary Serverpod manager, '
    'then no compression is negotiated and the exact message is delivered.',
    () async {
      final api = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);
      final input = StreamController<String>();
      final failures = <Object>[];
      final probe = CompressionProbe(
        target: target,
        compression: false,
        serializationManager: api.serializationManager,
        authKeyProvider: api.authKeyProvider!,
        input: input.stream,
        connectionTimeout: api.streamingConnectionTimeout,
      );
      final connection = IdleConnection(
        responses: probe.output.stream,
        send: input.add,
        closeInput: input.close,
        closeClient: api.close,
        onFailure: failures.add,
        timeout: const Duration(seconds: 5),
      );

      await connection.exchange('uncompressed-connection/exact-response');
      final extensions = probe.extensions;
      await connection.close();
      await probe.close();

      expect(extensions, isEmpty);
      expect(failures, isEmpty);
    },
  );

  test(
    'Given an HTTP server rejecting a WebSocket upgrade, '
    'when the ordinary Serverpod manager tries to connect, '
    'then the probe preserves the HTTP status and reports the failed connection.',
    () async {
      final rejecting = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      rejecting.listen((request) async {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      });
      final api = client.Client(target)..authKeyProvider = BenchmarkAuth(secret);
      final input = StreamController<String>();
      final probe = CompressionProbe(
        target: 'http://127.0.0.1:${rejecting.port}/',
        compression: true,
        serializationManager: api.serializationManager,
        authKeyProvider: api.authKeyProvider!,
        input: input.stream,
        connectionTimeout: api.streamingConnectionTimeout,
      );

      try {
        await expectLater(probe.output.stream.first, throwsA(anything));
        expect(probe.httpStatusCode, HttpStatus.serviceUnavailable);
      } finally {
        await probe.close();
        unawaited(input.close());
        api.close();
        await rejecting.close(force: true);
      }
    },
  );

  test(
    'Given a method stream without credentials, '
    'when the client sends a warmup message, '
    'then the probe fails authentication instead of counting an open stream.',
    () async {
      final api = client.Client(target);
      final input = StreamController<String>();
      final failures = <Object>[];
      final connection = IdleConnection(
        responses:
            api.callStreamingServerEndpoint<Stream<String>, String>(
                  'benchmark',
                  'echo',
                  {},
                  {'messages': input.stream},
                )
                as Stream<String>,
        send: input.add,
        closeInput: input.close,
        closeClient: api.close,
        onFailure: failures.add,
        timeout: const Duration(seconds: 5),
      );

      await expectLater(connection.exchange('warmup'), throwsA(anything));
      api.close();
      await connection.subscription.cancel();
      unawaited(input.close());

      expect(failures, isNotEmpty);
    },
  );

  test(
    'Given an established echo stream, '
    'when its response contains a different connection identity, '
    'then the probe fails instead of accepting delivery.',
    () async {
      final responses = StreamController<String>();
      final failures = <Object>[];
      final connection = IdleConnection(
        responses: responses.stream,
        send: (_) => responses.add('another-connection/resume'),
        closeInput: responses.close,
        closeClient: () {},
        onFailure: failures.add,
        timeout: const Duration(seconds: 1),
      );

      await expectLater(
        connection.exchange('this-connection/resume'),
        throwsStateError,
      );
      await connection.close();

      expect(failures, hasLength(1));
    },
  );

  test(
    'Given an established stream with a successful warmup, '
    'when it ends during inactivity, '
    'then the failure is retained and the resume probe cannot succeed.',
    () async {
      final responses = StreamController<String>();
      final failures = <Object>[];
      final connection = IdleConnection(
        responses: responses.stream,
        send: responses.add,
        closeInput: responses.close,
        closeClient: () {},
        onFailure: failures.add,
        timeout: const Duration(seconds: 1),
      );
      await connection.exchange('warmup');

      await responses.close();
      await expectLater(connection.exchange('resume'), throwsStateError);
      await connection.close();

      expect(failures, hasLength(1));
    },
  );

  test(
    'Given an echo stream waiting for another message, '
    'when its subscriber cancels, '
    'then the server releases the idle stream without another input event.',
    () async {
      final probe = TransportProbe();
      final input = StreamController<String>();
      final received = Completer<void>();
      final subscription = probe.echo(input.stream).listen((_) => received.complete());
      input.add('warmup');
      await received.future;

      await subscription.cancel().timeout(const Duration(seconds: 1));
      await input.close();
      final sample = probe.sample();

      expect(sample['open'], 0);
      expect(sample['closedTotal'], 1);
    },
  );
}
