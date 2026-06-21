import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

final _crdtSyncByServerpod = Expando<CrdtSync>('crdtSync');

/// Returns the CRDT sync configured for [pod].
CrdtSync crdtSyncForServerpod(Serverpod pod) {
  return _crdtSyncByServerpod[pod] ??
      (throw StateError(
        'The CrdtSync has not been initialized for this Serverpod instance. '
        'Call pod.initializeCrdtSync(...) during server startup to configure '
        'the CRDT sync.',
      ));
}

/// Intercepts each Serverpod session database with a CRDT-aware database once
/// [CrdtSyncInitialize.initializeCrdtSync] has configured sync.
Database crdtDatabaseInterceptor(Session session, Database inner) {
  return _crdtSyncByServerpod[session.server.serverpod]?.wrapDatabase(inner) ?? inner;
}

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension CrdtSyncInitialize on Serverpod {
  /// Configures the endpoint with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization.
  ///
  /// The [Serverpod] instance should be constructed with
  /// [crdtDatabaseInterceptor] as its `databaseInterceptor` so each ephemeral
  /// session database gets wrapped in a CRDT-aware database.
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
    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
    );

    _crdtSyncByServerpod[this] = CrdtSync.instance;
  }
}
