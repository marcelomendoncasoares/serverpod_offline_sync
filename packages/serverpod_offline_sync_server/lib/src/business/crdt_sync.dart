import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension CrdtSyncInitialize on Serverpod {
  /// Configures the endpoint with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization.
  ///
  /// [syncBatchSize] controls the maximum number of merge changes carried by
  /// each sync stream chunk.
  ///
  /// [continuousSyncInterval] controls how long a continuous sync session waits
  /// after completing one sync round before checking for local changes again.
  ///
  /// [onUniqueConflicts] is called after a merge transaction commits and one or
  /// more unique conflicts were materialized.
  void initializeCrdtSync({
    required List<Table> syncTables,
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,
    Duration continuousSyncInterval = CrdtSync.defaultContinuousSyncInterval,
    CrdtUniqueConflictCallback? onUniqueConflicts,
  }) {
    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
      onUniqueConflicts: onUniqueConflicts,
    );
  }
}
