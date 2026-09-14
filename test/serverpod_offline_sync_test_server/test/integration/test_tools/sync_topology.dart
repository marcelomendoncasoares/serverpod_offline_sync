import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession, Table;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'client_session.dart';

/// One node in a sync topology: the raw session collection reads from, the
/// CRDT session used for reads and merges, and its own sync engine.
typedef SyncNode = ({
  DatabaseSession raw,
  OfflineSyncDatabaseSession offlineSync,
  OfflineSyncEngine sync,
});

/// Wraps [raw] as a node synchronizing [syncTables].
///
/// A convergence test names its own subset rather than reusing
/// [testSyncTables]: a table the engine is not tracking is the case an
/// all-tables configuration can never reach.
Future<SyncNode> syncNode(DatabaseSession raw, List<Table> syncTables) async {
  final offlineSync = OfflineSyncDatabaseSession.wraps(raw, syncTables: syncTables);
  await offlineSync.db.initialize();
  return (
    raw: raw,
    offlineSync: offlineSync,
    sync: OfflineSyncEngine(
      syncTables: syncTables,
      serializationManager: raw.db.serializationManager,
    ),
  );
}

/// Collects everything [from] has pending and merges it into [to].
Future<void> pushChanges(SyncNode from, SyncNode to) async {
  final changes = await from.sync
      .collectPendingChanges(
        from.raw,
        checkpointsBySpaceUuid: {testCrdtUserId: const []},
      )
      .toList();
  await to.offlineSync.db.mergeChanges(changes, spaceId: testCrdtUserId);
}

/// One client sync cycle: push local changes up, then merge the server's.
Future<void> syncWithServer(SyncNode client, SyncNode server) async {
  await pushChanges(client, server);
  await pushChanges(server, client);
}
