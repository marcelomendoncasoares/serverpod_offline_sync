import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension CrdtSyncInitialize on Serverpod {
  /// Configures the endpoint with the given sync tables.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization.
  void initializeCrdtSync({
    required List<Table> syncTables,
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,
  }) {
    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
    );
  }
}
