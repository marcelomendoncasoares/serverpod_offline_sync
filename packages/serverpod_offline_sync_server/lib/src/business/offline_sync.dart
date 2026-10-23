import 'dart:async';
import 'dart:math';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import 'commit_hints.dart';
import 'offline_sync_spaces.dart';

/// The CRDT sync configured per [Serverpod] instance.
///
/// Keyed by the [Serverpod] instance so each pod owns its own [OfflineSyncEngine] (and
/// the [OfflineSyncDatabaseContext] it carries) instead of sharing a single
/// process-wide singleton.
final _offlineSyncByServerpod = Expando<OfflineSyncEngine>('offlineSync');
final _commitHintsByServerpod = Expando<_CommitHintBinding>('offlineSyncHints');
final _hintShutdownRegistered = Expando<bool>('offlineSyncHintShutdown');

class _CommitHintBinding {
  _CommitHintBinding(this.transport, OfflineSyncDatabaseContext context)
    : subscription = transport.changes.listen(
        context.receiveCommittedSpaces,
        onError: (Object error, StackTrace stack) {
          OfflineSyncDiagnostics.event('sync.hintReceptionFailed', {
            'type': error.runtimeType.toString(),
          });
        },
      );

  final OfflineSyncCommitHints transport;
  final StreamSubscription<Map<UuidValue, UuidValue>> subscription;

  Future<void> close({bool closeTransport = true}) async {
    await subscription.cancel();
    if (closeTransport) await transport.close();
  }
}

/// Intercepts each Serverpod session database with a CRDT-aware database once
/// [OfflineSyncInitialize.initializeOfflineSync] has configured sync.
///
/// When sync has not been configured for the session's [Serverpod], the
/// original [inner] database is returned unchanged.
Database offlineSyncDatabaseInterceptor(Session session, Database inner) {
  final offlineSync = _offlineSyncByServerpod[session.server.serverpod];
  return offlineSync?.wrapDatabase(inner) ?? inner;
}

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension OfflineSyncInitialize on Serverpod {
  /// Configures the CRDT sync with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization for this [Serverpod] instance.
  ///
  /// The [Serverpod] instance must be constructed with [offlineSyncDatabaseInterceptor]
  /// as its `databaseInterceptor`. Otherwise each session's [Session.db] stays a
  /// plain database and server-side ORM mutations on synced tables are not
  /// CRDT-tracked.
  ///
  /// [syncBatchSize] controls the maximum number of merge changes carried by
  /// each sync stream chunk.
  ///
  /// [continuousSyncInterval] controls how long a continuous sync session waits
  /// after completing one sync round before checking for local changes again.
  ///
  /// [maxConcurrentMerges] bounds merges using database connections. Merges that
  /// share a user clock or space queue before acquiring a connection. Defaults
  /// to half the configured pool size (at least one), or five for an unlimited
  /// pool. Transaction locks still serialize work across server instances.
  ///
  /// [commitHints] optionally wakes streams on other processes after commits.
  /// This Serverpod instance owns the transport and closes it on shutdown or
  /// replacement. Durable polling remains enabled for missed hints. A transport
  /// must not be shared by different Serverpod instances.
  void initializeOfflineSync({
    required List<Table> syncTables,
    int syncBatchSize = OfflineSyncEngine.defaultSyncBatchSize,
    Duration continuousSyncInterval = OfflineSyncEngine.defaultContinuousSyncInterval,
    int? maxConcurrentMerges,
    OfflineSyncCommitHints? commitHints,
  }) {
    final context = OfflineSyncDatabaseContext(
      syncTables: syncTables,
      serializationManager: serializationManager,
      onCommittedSpaces: commitHints?.publish,
      maxConcurrentMerges:
          maxConcurrentMerges ??
          max(1, (config.database?.maxConnectionCount ?? 10) ~/ 2),
    );
    final previous = _commitHintsByServerpod[this];
    _commitHintsByServerpod[this] = null;
    if (previous != null) {
      unawaited(
        previous
            .close(closeTransport: !identical(previous.transport, commitHints))
            .catchError((Object error) {
              OfflineSyncDiagnostics.event('sync.hintCloseFailed', {
                'type': error.runtimeType.toString(),
              });
            }),
      );
    }
    if (commitHints != null) {
      _commitHintsByServerpod[this] = _CommitHintBinding(commitHints, context);
      if (_hintShutdownRegistered[this] != true) {
        _hintShutdownRegistered[this] = true;
        experimental.shutdownTasks.addTask('offlineSyncCommitHints', () async {
          final binding = _commitHintsByServerpod[this];
          _commitHintsByServerpod[this] = null;
          await binding?.close();
        });
      }
    }
    _offlineSyncByServerpod[this] = OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
      databaseContext: context,
    );
  }
}

/// Session-bound CRDT services configured for a [Serverpod] instance.
///
/// This facade is ephemeral: each `Session.offlineSync` access creates a small wrapper
/// around the shared [OfflineSyncEngine] instance and the current [Session].
class OfflineSyncSession {
  /// Creates CRDT services bound to a session.
  OfflineSyncSession(this._session, this._sync);

  final Session _session;
  final OfflineSyncEngine _sync;

  /// Returns the server-side space management service.
  OfflineSyncSpaces get spaces => OfflineSyncSpaces(_session);

  /// Runs a CRDT sync session with this [OfflineSyncSession]'s [Session] bound.
  Stream<OfflineSyncStreamEvent> sync({
    required UuidValue userId,
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return _sync.sync(
      _session,
      userId: userId,
      inbound: inbound,
      once: once,
      mode: mode,
      onMergeSuccess: onMergeSuccess,
    );
  }
}

/// Extension to access CRDT services for [Session] from the [Serverpod] instance.
extension OfflineSyncSessionExtension on Session {
  /// Returns the CRDT services configured for this session.
  OfflineSyncSession get offlineSync {
    final sync = _offlineSyncByServerpod[server.serverpod];
    if (sync == null) {
      throw StateError(
        'The OfflineSyncEngine has not been initialized for this Serverpod instance. '
        'Call pod.initializeOfflineSync(...) during server startup to configure '
        'the CRDT sync.',
      );
    }
    return OfflineSyncSession(this, sync);
  }
}
