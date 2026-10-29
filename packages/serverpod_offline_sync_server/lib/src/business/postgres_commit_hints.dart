import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:postgres/postgres.dart' as pg;
import 'package:serverpod/serverpod.dart';

import 'commit_hints.dart';

/// PostgreSQL commit hints over one dedicated, reconnecting connection.
///
/// The endpoint must support session state: use a direct database endpoint or a
/// session pool, never transaction pooling. This connection remains outside
/// application transactions. Publishing is asynchronous after the original
/// commit, so a failed notification cannot roll back or stall that write.
class PostgresSyncCommitHints implements OfflineSyncCommitHints {
  /// Starts a connection in the background. Unavailable service drops hints;
  /// sync's durable polling continues until the connection recovers.
  PostgresSyncCommitHints({
    required this._endpoint,
    pg.ConnectionSettings? settings,
    String channel = 'serverpod_offline_sync_commits',
  }) : _settings =
           settings ??
           const pg.ConnectionSettings(
             connectTimeout: Duration(seconds: 5),
             queryTimeout: Duration(seconds: 5),
           ),
       _channel = channel {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,62}$').hasMatch(channel)) {
      throw ArgumentError.value(channel, 'channel', 'Invalid PostgreSQL channel');
    }
    _running = Zone.root.run(_run);
  }

  /// Uses the resolved server database settings. [host] may select an explicit
  /// direct endpoint when application queries use transaction pooling.
  factory PostgresSyncCommitHints.fromConfig(
    PostgresDatabaseConfig config, {
    String? host,
  }) => PostgresSyncCommitHints(
    endpoint: pg.Endpoint(
      host: host ?? config.host,
      port: config.port,
      database: config.name,
      username: config.user,
      password: config.password,
      isUnixSocket: host == null && config.isUnixSocket,
    ),
    settings: pg.ConnectionSettings(
      sslMode: config.requireSsl ? pg.SslMode.require : pg.SslMode.disable,
      connectTimeout: const Duration(seconds: 5),
      queryTimeout: const Duration(seconds: 5),
      applicationName: 'offline_sync_commit_hints',
    ),
  );

  final pg.Endpoint _endpoint;
  final pg.ConnectionSettings _settings;
  final String _channel;
  final _origin = const Uuid().v4();
  final _changes = StreamController<Map<UuidValue, int>>.broadcast();
  final _connections = StreamController<bool>.broadcast();
  final _closing = Completer<void>();
  final _pending = <UuidValue, int>{};
  late final Future<void> _running;
  pg.Connection? _connection;
  Future<void>? _flushing;
  Future<void>? _closeFuture;
  bool _connected = false;
  int _dropped = 0;

  /// Whether LISTEN has completed on the current connection.
  bool get isConnected => _connected;

  /// Connection transitions for operational monitoring and readiness barriers.
  Stream<bool> get connectionChanges => _connections.stream;

  /// Revisions dropped while disconnected or beyond the bounded hint queue.
  int get droppedRevisions => _dropped;

  @override
  Stream<Map<UuidValue, int>> get changes => _changes.stream;

  @override
  void publish(Map<UuidValue, int> revisions) {
    if (!_connected || _closing.isCompleted) {
      _dropped += revisions.length;
      return;
    }
    for (final entry in revisions.entries) {
      if (_pending.length < 1024 || _pending.containsKey(entry.key)) {
        _pending[entry.key] = entry.value;
      } else {
        _dropped++;
      }
    }
    _startFlush();
  }

  void _startFlush() {
    if (_connected && _flushing == null && _pending.isNotEmpty) {
      _flushing = Zone.root.run(() => _flush(_connection!)).whenComplete(() {
        _flushing = null;
        _startFlush();
      });
    }
  }

  Future<void> _flush(pg.Connection connection) async {
    try {
      while (_connected && !_closing.isCompleted && _pending.isNotEmpty) {
        // 64 space UUIDs and 64-bit revisions stay well below PostgreSQL's
        // 8000-byte payload limit. Coalescing never retains row payloads.
        final batch = Map.fromEntries(_pending.entries.take(64));
        _pending.removeWhere((space, _) => batch.containsKey(space));
        await connection.execute(
          pg.Sql.named('SELECT pg_notify(@channel, @payload)'),
          parameters: {
            'channel': _channel,
            'payload': jsonEncode({
              'origin': _origin,
              'revisions': {
                for (final entry in batch.entries) entry.key.toString(): entry.value,
              },
            }),
          },
        );
      }
    } on Object {
      // Recovery scans find the durable revision even if this send was lost.
      await _closeConnection(connection);
    }
  }

  void _receive(pg.Notification notification) {
    if (_closing.isCompleted || notification.channel != _channel) return;
    try {
      final message = jsonDecode(notification.payload) as Map<String, dynamic>;
      if (message['origin'] == _origin) return;
      final revisions = message['revisions'] as Map<String, dynamic>;
      if (revisions.isEmpty || revisions.length > 64) return;
      if (revisions.values.any((revision) => revision is! int || revision < 0)) {
        return;
      }
      _changes.add(
        Map.unmodifiable({
          for (final entry in revisions.entries)
            UuidValue.withValidation(entry.key): entry.value as int,
        }),
      );
    } on Object {
      // A malformed hint cannot affect data, membership or stream health.
    }
  }

  Future<void> _run() async {
    var retryMillis = 250;
    while (!_closing.isCompleted) {
      pg.Connection? connection;
      StreamSubscription<pg.Notification>? subscription;
      try {
        connection = await pg.Connection.open(_endpoint, settings: _settings);
        if (_closing.isCompleted) break;
        _connection = connection;
        subscription = connection.channels.all.listen(
          _receive,
          onError: (Object error, StackTrace stack) {
            unawaited(_closeConnection(connection!));
          },
        );
        await connection.execute('LISTEN "$_channel"');
        _connected = true;
        _connections.add(true);
        retryMillis = 250;
        await Future.any([connection.closed, _closing.future]);
      } on Object {
        // Reconnection is independent of request sessions and transactions.
      } finally {
        if (_connected) _connections.add(false);
        _connected = false;
        _connection = null;
        _dropped += _pending.length;
        _pending.clear();
        await subscription?.cancel();
        if (connection != null) await _closeConnection(connection);
        await _flushing;
      }
      if (_closing.isCompleted) break;
      final wake = Completer<void>();
      final timer = Timer(Duration(milliseconds: retryMillis), wake.complete);
      await Future.any([wake.future, _closing.future]);
      timer.cancel();
      retryMillis = min(30000, retryMillis * 2);
    }
  }

  Future<void> _closeConnection(pg.Connection connection) async {
    try {
      await connection.close();
    } on Object {
      // Transport teardown must remain best-effort after a socket failure.
    }
  }

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _closing.complete();
    await _running;
    await _changes.close();
    await _connections.close();
  }
}
