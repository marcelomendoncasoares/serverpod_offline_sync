import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:postgres/postgres.dart';
import 'package:postgres_tls/postgres_tls.dart';
import 'package:serverpod_embedded_postgres/serverpod_embedded_postgres.dart';
import 'package:test/test.dart';

void main() {
  EmbeddedPostgres? database;
  Process? proxy;
  late Directory directory;
  late Endpoint endpoint;

  Future<Connection> connect() => Connection.open(
    endpoint,
    settings: const ConnectionSettings(
      sslMode: SslMode.require,
      tlsConnector: nativeTlsConnector,
      connectTimeout: Duration(seconds: 5),
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
