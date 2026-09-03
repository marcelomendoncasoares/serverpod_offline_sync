import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Table;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'client_session.dart';

/// One node in a sync topology: the raw session collection reads from, the
/// CRDT session used for reads and merges, and its own sync engine.
typedef SyncNode = ({DatabaseSession raw, CrdtDatabaseSession crdt, CrdtSync sync});

/// Wraps [raw] as a node synchronizing [syncTables].
///
/// A convergence test names its own subset rather than reusing
/// [testSyncTables]: a table the engine is not tracking is the case an
/// all-tables configuration can never reach.
Future<SyncNode> syncNode(DatabaseSession raw, List<Table> syncTables) async {
  final crdt = CrdtDatabaseSession.wraps(raw, syncTables: syncTables);
  await crdt.db.initialize();
  return (
    raw: raw,
    crdt: crdt,
    sync: CrdtSync(
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
        checkpointsByScopeUuid: {testCrdtUserId: const []},
      )
      .toList();
  await to.crdt.db.mergeChanges(changes, scopeId: testCrdtUserId);
}

/// One client sync cycle: push local changes up, then merge the server's.
Future<void> syncWithServer(SyncNode client, SyncNode server) async {
  await pushChanges(client, server);
  await pushChanges(server, client);
}
