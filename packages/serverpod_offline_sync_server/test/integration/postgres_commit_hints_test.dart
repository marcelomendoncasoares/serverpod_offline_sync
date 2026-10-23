import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/embedded.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late ResolvedEmbeddedPostgres database;
  late pg.Endpoint endpoint;
  late pg.Connection control;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sync-hints-test-');
    database = (await startOrAttachEmbeddedPostgres(
      PostgresDatabaseConfig.embedded(
        dataPath: '${directory.path}/postgres',
        name: 'hints',
      ),
    ))!;
    final config = database.connectivity;
    endpoint = pg.Endpoint(
      host: config.host,
      port: config.port,
      database: config.name,
      username: config.user,
      password: config.password,
      isUnixSocket: config.isUnixSocket,
    );
    control = await pg.Connection.open(
      endpoint,
      settings: const pg.ConnectionSettings(sslMode: pg.SslMode.disable),
    );
  });

  tearDownAll(() async {
    await control.close();
    await database.stop?.call();
    await directory.delete(recursive: true);
  });

  Future<PostgresSyncCommitHints> open(String channel, String name) async {
    final hints = PostgresSyncCommitHints(
      endpoint: endpoint,
      channel: channel,
      settings: pg.ConnectionSettings(
        sslMode: pg.SslMode.disable,
        applicationName: name,
        connectTimeout: const Duration(seconds: 2),
        queryTimeout: const Duration(seconds: 2),
      ),
    );
    addTearDown(hints.close);
    if (!hints.isConnected) {
      await hints.connectionChanges
          .firstWhere((connected) => connected)
          .timeout(
            const Duration(seconds: 10),
          );
    }
    return hints;
  }

  test(
    'Given two independent PostgreSQL listeners, '
    'when one publishes 130 committed space revisions, '
    'then every revision crosses bounded notification payloads.',
    () async {
      final channel = 'sync_${const Uuid().v4().replaceAll('-', '')}';
      final sender = await open(channel, '$channel-sender');
      final receiver = await open(channel, '$channel-receiver');
      final expected = {
        for (var i = 0; i < 130; i++) const Uuid().v7obj(): const Uuid().v7obj(),
      };
      final received = <UuidValue, UuidValue>{};
      final delivered = Completer<void>();
      final subscription = receiver.changes.listen((batch) {
        received.addAll(batch);
        if (received.length == expected.length) delivered.complete();
      });
      addTearDown(subscription.cancel);

      sender.publish(expected);
      await delivered.future.timeout(const Duration(seconds: 10));
      final idleTransactions = await control.execute(
        pg.Sql.named(
          'SELECT count(*)::int FROM pg_stat_activity '
          'WHERE application_name IN (@sender, @receiver) '
          "AND state = 'idle in transaction'",
        ),
        parameters: {'sender': '$channel-sender', 'receiver': '$channel-receiver'},
      );

      expect(received, expected);
      expect(sender.droppedRevisions, 0);
      expect(idleTransactions.single.single, 0);
    },
  );

  test(
    'Given a connected listener with a known database session, '
    'when PostgreSQL terminates that session and it reconnects, '
    'then new revisions arrive without replacing the transport.',
    () async {
      final channel = 'sync_${const Uuid().v4().replaceAll('-', '')}';
      final name = '$channel-receiver';
      final sender = await open(channel, '$channel-sender');
      final receiver = await open(channel, name);
      final disconnected = receiver.connectionChanges.firstWhere((value) => !value);
      final reconnected = receiver.connectionChanges.firstWhere((value) => value);

      final killed = await control.execute(
        pg.Sql.named(
          'SELECT pg_terminate_backend(pid) FROM pg_stat_activity '
          'WHERE application_name = @name',
        ),
        parameters: {'name': name},
      );
      await disconnected.timeout(const Duration(seconds: 10));
      await reconnected.timeout(const Duration(seconds: 10));
      final expected = {const Uuid().v7obj(): const Uuid().v7obj()};
      final delivered = receiver.changes.first;
      sender.publish(expected);
      final received = await delivered.timeout(const Duration(seconds: 10));

      expect(killed.single.single, isTrue);
      expect(received, expected);
      expect(receiver.isConnected, isTrue);
    },
  );

  test(
    'Given a listener receiving malformed external notifications, '
    'when a valid barrier revision follows them, '
    'then malformed data is ignored and delivery remains usable.',
    () async {
      final channel = 'sync_${const Uuid().v4().replaceAll('-', '')}';
      final receiver = await open(channel, '$channel-receiver');
      final expected = {const Uuid().v7obj(): const Uuid().v7obj()};
      final delivered = receiver.changes.first;

      for (final payload in [
        'invalid json',
        jsonEncode({
          'origin': 'external',
          'revisions': {'not a uuid': 'bad'},
        }),
        jsonEncode({
          'origin': 'external',
          'revisions': {
            for (final entry in expected.entries)
              entry.key.toString(): entry.value.toString(),
          },
        }),
      ]) {
        await control.execute(
          pg.Sql.named('SELECT pg_notify(@channel, @payload)'),
          parameters: {'channel': channel, 'payload': payload},
        );
      }
      final received = await delivered.timeout(const Duration(seconds: 10));

      expect(received, expected);
      expect(receiver.isConnected, isTrue);
    },
  );

  test(
    'Given a transport whose database port is unavailable, '
    'when it is closed during connection recovery, '
    'then its streams and retry loop close without a leaked listener.',
    () async {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final hints = PostgresSyncCommitHints(
        endpoint: pg.Endpoint(host: '127.0.0.1', port: port, database: 'unavailable'),
        settings: const pg.ConnectionSettings(
          sslMode: pg.SslMode.disable,
          connectTimeout: Duration(seconds: 1),
        ),
      );
      final finished = hints.changes.drain<void>();

      hints.publish({const Uuid().v7obj(): const Uuid().v7obj()});
      await hints.close().timeout(const Duration(seconds: 5));
      await finished;
      await hints.close();

      expect(hints.isConnected, isFalse);
      expect(hints.droppedRevisions, 1);
    },
  );
}
