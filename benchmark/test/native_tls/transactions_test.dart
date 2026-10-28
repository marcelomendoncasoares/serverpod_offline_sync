import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart' as outcomes;
import 'package:postgres/postgres.dart';
// Observe actual wire exchanges in this isolated driver validation.
// ignore: implementation_imports
import 'package:postgres/src/v3/protocol.dart';
import 'package:postgres_tls/postgres_tls.dart';
import 'package:serverpod_embedded_postgres/serverpod_embedded_postgres.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  EmbeddedPostgres? database;
  Process? proxy;
  late Directory directory;
  late Endpoint endpoint;

  Future<Connection> connect({int depth = 8, _WireEvents? wire}) => Connection.open(
    endpoint,
    settings: ConnectionSettings(
      sslMode: SslMode.require,
      pipelineDepth: depth,
      transformer: wire?.transformer,
      tlsConnector: nativeTlsConnector,
      connectTimeout: const Duration(seconds: 5),
    ),
  );

  setUpAll(() async {
    directory = Directory.systemTemp.createTempSync('native-tls-check-');
    database = await EmbeddedPostgres.start(
      EmbeddedPostgresOptions(
        dataDir: Directory('${directory.path}/postgres'),
        databaseName: 'native_tls_check',
        transport: const TcpTransport(),
      ),
    );
    final certificate = '${directory.path}/certificate.pem';
    final key = '${directory.path}/key.pem';
    final generated = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-nodes',
      '-days',
      '1',
      '-keyout',
      key,
      '-out',
      certificate,
      '-subj',
      '/CN=localhost',
    ]);
    if (generated.exitCode != 0) throw StateError('Test certificate failed');

    final reservation = await ServerSocket.bind('127.0.0.1', 0);
    final port = reservation.port;
    await reservation.close();
    final pg = database!.tcpEndpoint!;
    // Run from benchmark/, as with dart test. Package URI lookup is not
    // available in the standalone AOT validation executable.
    final proxyPath = File('test/native_tls/src/tls_proxy.py').absolute.path;
    final runningProxy = await Process.start('python3', [
      proxyPath,
      '--listen-port',
      '$port',
      '--database-port',
      '${pg.port}',
      '--delay-ms',
      '0',
      '--cert',
      certificate,
      '--key',
      key,
    ]);
    proxy = runningProxy;
    unawaited(runningProxy.stderr.drain<void>());
    final lines = runningProxy.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    await lines.first.timeout(const Duration(seconds: 10));
    lines.listen((_) {});
    endpoint = Endpoint(
      host: '127.0.0.1',
      port: port,
      database: pg.database,
      username: pg.username,
      password: pg.password,
    );
  });

  tearDownAll(() async {
    try {
      if (proxy case final runningProxy?) {
        runningProxy.kill();
        await runningProxy.exitCode;
      }
    } finally {
      await database?.stop();
      directory.deleteSync(recursive: true);
    }
  });

  group('Given a native TLS connection configured with pipeline depth eight,', () {
    late Connection connection;
    late _WireEvents wire;

    setUpAll(() async {
      wire = _WireEvents();
      connection = await connect(wire: wire);
    });

    tearDownAll(() => connection.close());

    group('when sixteen reads are started together inside one transaction,', () {
      late List<int> values;
      late List<String> exchanges;

      setUpAll(() async {
        await connection.runTx((tx) async {
          wire.events.clear();
          final results = await Future.wait([
            for (var index = 0; index < 16; index++)
              tx.execute(
                r'SELECT pg_sleep(CASE WHEN $1::int = 0 THEN 0.1 ELSE 0 END), $1::int',
                parameters: [index],
              ),
          ]);
          values = [for (final row in results) row.single[1]! as int];
          exchanges = List.of(wire.events);
        });
      });

      test('then every future receives its own query result.', () {
        expect(values, List.generate(16, (index) => index));
      });

      test(
        'then eight exchanges are sent before an answer and the window stays bounded.',
        () {
          expect(exchanges.take(8), List.filled(8, 'sent'));
          expect(_maximumInFlight(exchanges), 8);
          expect(exchanges.where((event) => event == 'answered'), hasLength(16));
        },
      );
    });
  });

  test(
    'Given a native TLS connection configured with pipeline depth one, '
    'when reads are started together inside a transaction, '
    'then each answer precedes the next send.',
    () async {
      final wire = _WireEvents();
      final connection = await connect(depth: 1, wire: wire);
      addTearDown(connection.close);
      late List<String> exchanges;

      await connection.runTx((tx) async {
        wire.events.clear();
        await Future.wait([
          tx.execute('SELECT 1'),
          tx.execute('SELECT 2'),
          tx.execute('SELECT 3'),
        ]);
        exchanges = List.of(wire.events);
      });

      expect(exchanges, ['sent', 'answered', 'sent', 'answered', 'sent', 'answered']);
    },
  );

  group('Given a native TLS connection and an empty table,', () {
    late Connection connection;

    setUpAll(() async {
      connection = await connect();
      await connection.execute('CREATE TEMPORARY TABLE pipeline_failure (id int)');
    });

    tearDownAll(() => connection.close());

    group('when the middle of three pipelined inserts fails,', () {
      late List<outcomes.Result<Result>> results;
      late Object? error;
      late Object? count;
      late Object? reusable;

      setUpAll(() async {
        error = await connection
            .runTx((tx) async {
              results = await Future.wait([
                outcomes.Result.capture(
                  tx.execute('INSERT INTO pipeline_failure VALUES (1)'),
                ),
                outcomes.Result.capture(
                  tx.execute("INSERT INTO pipeline_failure VALUES ('invalid')"),
                ),
                outcomes.Result.capture(
                  tx.execute('INSERT INTO pipeline_failure VALUES (3)'),
                ),
              ]);
            })
            .then<Object?>((_) => null, onError: (Object error) => error);
        count = (await connection.execute(
          'SELECT count(*) FROM pipeline_failure',
        )).single.single;
        reusable = (await connection.execute('SELECT 99')).single.single;
      });

      test(
        'then every future settles with its corresponding success or SQL error.',
        () {
          expect(results[0].isValue, isTrue);
          expect(
            results[1].asError!.error,
            isA<ServerException>().having((e) => e.code, 'code', '22P02'),
          );
          expect(
            results[2].asError!.error,
            isA<ServerException>().having((e) => e.code, 'code', '25P02'),
          );
          expect(error, isA<ServerException>());
        },
      );

      test(
        'then the entire transaction rolls back and the connection can be reused.',
        () {
          expect(count, 0);
          expect(reusable, 99);
        },
      );
    });
  });

  test(
    'Given a slow native TLS query with another query already in flight, '
    'when its soft cancellation timer fires, '
    'then both queries settle without cancelling the following query.',
    () async {
      final connection = await connect();
      addTearDown(connection.close);

      final results = await Future.wait([
        outcomes.Result.capture(
          connection.execute(
            'SELECT pg_sleep(0.3)',
            timeout: const Duration(milliseconds: 50),
          ),
        ),
        outcomes.Result.capture(connection.execute('SELECT 2')),
      ]);

      expect(results[0].isValue, isTrue);
      expect(results[1].asValue!.value.single.single, 2);
    },
  );

  test('Given a native TLS PostgreSQL connection, '
      'when a binary payload spans many TLS records, '
      'then the exact bytes and Unicode text are returned.', () async {
    final connection = await connect();
    addTearDown(connection.close);
    final bytes = Uint8List.fromList(
      List.generate(1 << 20, (index) => index % 251),
    );

    final result = await connection.execute(
      r'SELECT $1::bytea, $2::text',
      parameters: [bytes, 'Olá 🌍'],
    );

    expect(result.single[0], bytes);
    expect(result.single[1], 'Olá 🌍');
  });

  group('Given a native TLS transaction holding a row lock,', () {
    late Connection holder;
    late Connection peer;
    late TxSession transaction;
    late Completer<void> entered;
    late Completer<void> releaseBody;
    late Future<Object?> running;

    setUpAll(() async {
      holder = await connect();
      peer = await connect();
      await holder.execute(
        'CREATE TABLE tls_rollback (id int PRIMARY KEY, value int)',
      );
      await holder.execute('INSERT INTO tls_rollback VALUES (1, 10)');
      entered = Completer<void>();
      releaseBody = Completer<void>();
      running = holder
          .runTx<Object?>((tx) async {
            transaction = tx;
            await tx.execute('UPDATE tls_rollback SET value = 20 WHERE id = 1');
            entered.complete();
            await releaseBody.future;
            return null;
          })
          .then<Object?>((_) => null, onError: (Object error) => error);
      await entered.future;
    });

    tearDownAll(() async {
      if (!releaseBody.isCompleted) releaseBody.complete();
      await running;
      await holder.close();
      await peer.close();
    });

    group(
      'when it is rolled back while its application callback is waiting,',
      () {
        late int visibleValue;
        late int reusableValue;

        setUpAll(() async {
          await transaction.rollback().timeout(const Duration(seconds: 5));
          final rows = await peer.execute(
            'SELECT value FROM tls_rollback WHERE id = 1 FOR UPDATE',
            timeout: const Duration(seconds: 2),
          );
          visibleValue = rows.single.single! as int;
          releaseBody.complete();
          await running;
          reusableValue = (await holder.execute('SELECT 99')).single.single! as int;
        });

        test(
          'then another connection acquires the lock and sees the original value.',
          () {
            expect(visibleValue, 10);
          },
        );

        test('then the original connection remains usable.', () {
          expect(reusableValue, 99);
        });
      },
    );
  });

  test('Given a native TLS connection running a slow query, '
      'when its deadline cancels the query, '
      'then the next query succeeds without a late cancellation.', () async {
    final connection = await connect();
    addTearDown(connection.close);
    Object? failure;

    try {
      await connection.execute(
        'SELECT pg_sleep(2)',
        timeout: const Duration(milliseconds: 50),
      );
    } on Object catch (error) {
      failure = error;
    }
    final next = await connection.execute('SELECT 42, pg_sleep(0.05)');

    expect(failure, isA<TimeoutException>());
    expect(next.single.first, 42);
  });

  test('Given eight native TLS PostgreSQL connections, '
      'when each performs twenty consecutive exchanges concurrently, '
      'then every query receives its exact result.', () async {
    final connections = await Future.wait(List.generate(8, (_) => connect()));
    addTearDown(() => Future.wait(connections.map((c) => c.close())));

    final results = await Future.wait([
      for (var index = 0; index < connections.length; index++)
        () async {
          final values = <int>[];
          for (var query = 0; query < 20; query++) {
            final result = await connections[index].execute(
              r'SELECT $1::int8',
              parameters: [index * 100 + query],
            );
            values.add(result.single.single! as int);
          }
          return values;
        }(),
    ]);

    expect(results, [
      for (var index = 0; index < 8; index++)
        List.generate(20, (query) => index * 100 + query),
    ]);
  });
}

class _WireEvents {
  final events = <String>[];

  StreamChannelTransformer<Message, Message> get transformer =>
      StreamChannelTransformer(
        StreamTransformer.fromHandlers(
          handleData: (message, sink) {
            if (message is ReadyForQueryMessage) events.add('answered');
            sink.add(message);
          },
        ),
        outcomes.StreamSinkTransformer.fromHandlers(
          handleData: (message, sink) {
            final messages = message is AggregatedClientMessage
                ? message.messages
                : [message];
            if (messages.any((item) => item is SyncMessage || item is QueryMessage)) {
              events.add('sent');
            }
            sink.add(message);
          },
        ),
      );
}

int _maximumInFlight(List<String> exchanges) {
  var current = 0;
  var maximum = 0;
  for (final event in exchanges) {
    current += event == 'sent' ? 1 : -1;
    if (current > maximum) maximum = current;
  }
  return maximum;
}
