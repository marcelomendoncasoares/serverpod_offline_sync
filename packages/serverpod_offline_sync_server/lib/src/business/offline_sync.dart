import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import 'offline_sync_spaces.dart';

/// The CRDT sync configured per [Serverpod] instance.
///
/// Keyed by the [Serverpod] instance so each pod owns its own [OfflineSyncEngine] (and
/// the [OfflineSyncDatabaseContext] it carries) instead of sharing a single
/// process-wide singleton.
final _offlineSyncByServerpod = Expando<OfflineSyncEngine>('offlineSync');

/// The CRDT-aware database the interceptor built for each session.
///
/// [Session.db] is the database a session hands out, and it is normally the
/// wrapped instance itself. Under `serverpod_test` it is a proxy in front of
/// the wrapped instance, which hides it, so the interceptor remembers what it
/// wrapped and [OfflineSyncSessionDatabase.offlineSyncDb] falls back to it.
final _syncDatabaseBySession = Expando<OfflineSyncDatabase>(
  'offlineSyncDatabase',
);

/// Intercepts each Serverpod session database with a CRDT-aware database once
/// [OfflineSyncInitialize.initializeOfflineSync] has configured sync.
///
/// When sync has not been configured for the session's [Serverpod], the
/// original [inner] database is returned unchanged.
Database offlineSyncDatabaseInterceptor(Session session, Database inner) {
  final offlineSync = _offlineSyncByServerpod[session.server.serverpod];
  final wrapped = offlineSync?.wrapDatabase(inner);
  if (wrapped == null) return inner;
  _syncDatabaseBySession[session] = wrapped;
  return wrapped;
}

/// Access to the CRDT-aware database of a server [Session].
///
/// The database a session exposes as [Session.db] is typed [Database], so the
/// CRDT-only members — [OfflineSyncDatabase.transactionForUser] above all —
/// are not reachable from it. This resolves the wrapped instance instead:
///
/// ```dart
/// await session.offlineSyncDb.transactionForUser(userId, (tx) async {
///   await Turnover.db.insertRow(session, turnover, transaction: tx);
/// });
/// ```
///
/// Prefer this over [OfflineSyncDatabaseAccess.offlineSyncDb] on a plain
/// [DatabaseSession]: it also resolves under `serverpod_test`, where
/// [Session.db] is a proxy that hides the wrapped database.
extension OfflineSyncSessionDatabase on Session {
  /// The CRDT-aware database behind this session.
  ///
  /// Throws a [StateError] when the [Serverpod] instance was not constructed
  /// with [offlineSyncDatabaseInterceptor] as its `databaseInterceptor`, or
  /// when sync was not initialized before this session was created.
  OfflineSyncDatabase get offlineSyncDb {
    final database = db;
    if (database is OfflineSyncDatabase) return database;

    final intercepted = _syncDatabaseBySession[this];
    if (intercepted != null) return intercepted;

    throw StateError(
      'The database of this session is not CRDT-aware. Construct the Serverpod '
      'instance with `databaseInterceptor: offlineSyncDatabaseInterceptor` and '
      'call `pod.initializeOfflineSync(...)` before the session is created. In '
      'tests, pass the interceptor to `withServerpod` and initialize sync on '
      '`sessionBuilder.build().serverpod`.',
    );
  }
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
  void initializeOfflineSync({
    required List<Table> syncTables,
    int syncBatchSize = OfflineSyncEngine.defaultSyncBatchSize,
    Duration continuousSyncInterval = OfflineSyncEngine.defaultContinuousSyncInterval,
  }) {
    _offlineSyncByServerpod[this] = OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
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
