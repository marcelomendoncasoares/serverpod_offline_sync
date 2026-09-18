import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import 'offline_sync_spaces.dart';

/// Callback reported to on the server after a sync session committed activity
/// for one space, with the [Session] that ran the sync session bound.
///
/// The session is valid while the callback runs and is closed with the sync
/// session afterwards, so work queued for later must open its own session and
/// carry the identifiers it needs from the [OfflineSyncMergeEvent].
typedef OfflineSyncServerOnMergeSuccess =
    FutureOr<void> Function(Session session, OfflineSyncMergeEvent event);

/// The CRDT sync configured per [Serverpod] instance.
///
/// Keyed by the [Serverpod] instance so each pod owns its own
/// [OfflineSyncService] (and the [OfflineSyncEngine] and
/// [OfflineSyncDatabaseContext] it carries) instead of sharing a single
/// process-wide singleton.
final _offlineSyncByServerpod = Expando<OfflineSyncService>('offlineSync');

/// Sentinel default for [OfflineSyncInitialize.configureOfflineSync], telling it
/// to keep the current registration. Passing `null` explicitly unregisters.
void _keepOnMergeSuccess(Session session, OfflineSyncMergeEvent event) {}

/// The offline sync configured for one [Serverpod] instance: the shared
/// [OfflineSyncEngine] every sync session of that pod runs on, plus the
/// server-wide configuration applications register with
/// [OfflineSyncInitialize.configureOfflineSync].
///
/// Created by [OfflineSyncInitialize.initializeOfflineSync] and mutated in
/// place afterwards, so configuring a running server never replaces the engine
/// or its database context.
class OfflineSyncService {
  /// Creates a service around the [engine] shared by one [Serverpod] instance.
  OfflineSyncService(this.engine);

  /// The CRDT engine every sync session of this [Serverpod] instance runs on.
  final OfflineSyncEngine engine;

  /// The server-wide merge handler, or `null` when none is registered.
  OfflineSyncServerOnMergeSuccess? onMergeSuccess;
}

/// Intercepts each Serverpod session database with a CRDT-aware database once
/// [OfflineSyncInitialize.initializeOfflineSync] has configured sync.
///
/// When sync has not been configured for the session's [Serverpod], the
/// original [inner] database is returned unchanged.
Database offlineSyncDatabaseInterceptor(Session session, Database inner) {
  final offlineSync = _offlineSyncByServerpod[session.server.serverpod];
  return offlineSync?.engine.wrapDatabase(inner) ?? inner;
}

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension OfflineSyncInitialize on Serverpod {
  /// Configures the CRDT sync with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization for this [Serverpod] instance,
  /// including anything registered with [configureOfflineSync].
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
    _offlineSyncByServerpod[this] = OfflineSyncService(
      OfflineSyncEngine(
        syncTables: syncTables,
        serializationManager: serializationManager,
        syncBatchSize: syncBatchSize,
        continuousSyncInterval: continuousSyncInterval,
      ),
    );
  }

  /// Configures the offline sync already initialized for this [Serverpod].
  ///
  /// The generated `Serverpod` subclass calls [initializeOfflineSync] with the
  /// generated sync tables while it is being constructed, so applications
  /// configure the running sync from ordinary startup code instead:
  ///
  /// ```dart
  /// final pod = Serverpod(args, Protocol(), Endpoints());
  ///
  /// pod.configureOfflineSync(
  ///   onMergeSuccess: (session, event) async {
  ///     if (event.receivedHlc == null) return;
  ///     await reactions.forUser(event.syncingUserId).handle(
  ///       session,
  ///       spaceUuid: event.spaceUuid,
  ///     );
  ///   },
  /// );
  ///
  /// await pod.start();
  /// ```
  ///
  /// [onMergeSuccess] is reported to after every sync cycle that committed
  /// activity for a space, whichever client ran it. It is the server-side
  /// notification a sync session produces: without it an application that shows
  /// one user's synced rows to another user (a live dashboard, a supervisor
  /// view) has no signal that anything changed and has to poll. Omitting the
  /// argument keeps the current registration; passing `null` unregisters.
  ///
  /// The handler does not replace a per-sync observer passed to
  /// [OfflineSyncSession.sync]: both receive the same event, and a handler that
  /// throws is logged on the session and isolated, so it neither fails the
  /// committed synchronization nor stops the other observer. Delivery is
  /// best-effort notification, not durable business-event delivery, so keep the
  /// handler cheap — posting on [Session.messages] or scheduling work, not
  /// running a query chain.
  ///
  /// Throws a [StateError] when sync was never initialized for this pod.
  void configureOfflineSync({
    OfflineSyncServerOnMergeSuccess? onMergeSuccess = _keepOnMergeSuccess,
  }) {
    final service = _requireOfflineSyncService(this);
    if (!identical(onMergeSuccess, _keepOnMergeSuccess)) {
      service.onMergeSuccess = onMergeSuccess;
    }
  }
}

/// Session-bound CRDT services configured for a [Serverpod] instance.
///
/// This facade is ephemeral: each `Session.offlineSync` access creates a small wrapper
/// around the shared [OfflineSyncService] instance and the current [Session].
class OfflineSyncSession {
  /// Creates CRDT services bound to a session.
  OfflineSyncSession(this._session, this._service);

  final Session _session;
  final OfflineSyncService _service;

  /// Returns the server-side space management service.
  OfflineSyncSpaces get spaces => OfflineSyncSpaces(_session);

  /// Runs a CRDT sync session with this [OfflineSyncSession]'s [Session] bound.
  ///
  /// Every committed cycle is reported to the server-wide handler registered
  /// with [OfflineSyncInitialize.configureOfflineSync] and, when given, to
  /// [onMergeSuccess]. The per-sync observer is an addition, never a
  /// replacement: `OfflineSyncEndpoint` passes none and the server-wide handler
  /// still runs. An observer that throws is logged on this session and
  /// isolated from the sync session and from the other observer.
  Stream<OfflineSyncStreamEvent> sync({
    required UuidValue userId,
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) {
    return _service.engine.sync(
      _session,
      userId: userId,
      inbound: inbound,
      once: once,
      mode: mode,
      onMergeSuccess: _observeMerges(onMergeSuccess),
    );
  }

  /// Fans one event out to the server-wide handler and [perSync], isolating and
  /// reporting a failure of either.
  ///
  /// The server-wide handler is read per event rather than captured when the
  /// session starts, so configuring a running server also reaches the sync
  /// sessions already streaming on it.
  OfflineSyncOnMergeSuccess _observeMerges(OfflineSyncOnMergeSuccess? perSync) {
    return (event) async {
      final serverWide = _service.onMergeSuccess;
      if (serverWide != null) {
        await _runObserver(
          'server-wide offline sync merge handler',
          () => serverWide(_session, event),
          event,
        );
      }
      if (perSync != null) {
        await _runObserver(
          'per-sync offline sync merge observer',
          () => perSync(event),
          event,
        );
      }
    };
  }

  Future<void> _runObserver(
    String description,
    FutureOr<void> Function() run,
    OfflineSyncMergeEvent event,
  ) async {
    try {
      await run();
    } on Object catch (error, stackTrace) {
      _session.log(
        'The $description threw for $event. The synchronization already '
        'committed and is not affected.',
        level: LogLevel.error,
        exception: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// Extension to access CRDT services for [Session] from the [Serverpod] instance.
extension OfflineSyncSessionExtension on Session {
  /// Returns the CRDT services configured for this session.
  OfflineSyncSession get offlineSync =>
      OfflineSyncSession(this, _requireOfflineSyncService(server.serverpod));
}

OfflineSyncService _requireOfflineSyncService(Serverpod serverpod) {
  final service = _offlineSyncByServerpod[serverpod];
  if (service == null) {
    throw StateError(
      'The OfflineSyncEngine has not been initialized for this Serverpod instance. '
      'Call pod.initializeOfflineSync(...) during server startup to configure '
      'the CRDT sync.',
    );
  }
  return service;
}
