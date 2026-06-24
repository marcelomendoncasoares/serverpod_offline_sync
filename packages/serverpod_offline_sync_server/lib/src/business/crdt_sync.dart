import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

/// The CRDT sync configured per [Serverpod] instance.
///
/// Keyed by the [Serverpod] instance so each pod owns its own [CrdtSync] (and
/// the [CrdtDatabaseContext] it carries) instead of sharing a single
/// process-wide singleton.
final _crdtSyncByServerpod = Expando<CrdtSync>('crdtSync');

/// Intercepts each Serverpod session database with a CRDT-aware database once
/// [CrdtSyncInitialize.initializeCrdtSync] has configured sync.
///
/// When sync has not been configured for the session's [Serverpod], the
/// original [inner] database is returned unchanged.
Database crdtDatabaseInterceptor(Session session, Database inner) {
  final crdtSync = _crdtSyncByServerpod[session.server.serverpod];
  return crdtSync?.wrapDatabase(inner) ?? inner;
}

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension CrdtSyncInitialize on Serverpod {
  /// Configures the CRDT sync with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization for this [Serverpod] instance.
  ///
  /// The [Serverpod] instance must be constructed with [crdtDatabaseInterceptor]
  /// as its `databaseInterceptor`. Otherwise each session's [Session.db] stays a
  /// plain database and server-side ORM mutations on synced tables are not
  /// CRDT-tracked.
  ///
  /// [syncBatchSize] controls the maximum number of merge changes carried by
  /// each sync stream chunk.
  ///
  /// [continuousSyncInterval] controls how long a continuous sync session waits
  /// after completing one sync round before checking for local changes again.
  void initializeCrdtSync({
    required List<Table> syncTables,
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,
    Duration continuousSyncInterval = CrdtSync.defaultContinuousSyncInterval,
  }) {
    _crdtSyncByServerpod[this] = CrdtSync(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
    );
  }
}

/// Extension to access the CRDT sync for [Session] from the [Serverpod] instance.
extension CrdtSessionExtension on Session {
  /// Returns the CRDT sync configured for this session.
  CrdtSync get crdt =>
      _crdtSyncByServerpod[server.serverpod] ??
      (throw StateError(
        'The CrdtSync has not been initialized for this Serverpod instance. '
        'Call pod.initializeCrdtSync(...) during server startup to configure '
        'the CRDT sync.',
      ));
}
