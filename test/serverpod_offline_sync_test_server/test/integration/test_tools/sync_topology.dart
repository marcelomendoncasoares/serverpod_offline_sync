import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Table, TableRow;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    show UuidValue;

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
  final capture = await from.sync.captureChanges(
    from.raw,
    checkpointsBySpaceUuid: {testCrdtUserId: 0},
  );
  await deliverCapture(from, to, capture);
}

/// Authors a row on a disconnected peer and merges its complete export.
/// Conflicting claims must originate independently: a locally visible
/// duplicate is an ordinary constraint violation.
Future<void> mergeIndependentInsert<T extends TableRow>(
  OfflineSyncDatabaseSession target,
  T row, {
  required UuidValue space,
  required List<Table> tables,
}) async {
  final peer = await syncNode(await createAdditionalTestSession(), tables);
  await peer.offlineSync.db.transactionForUser(
    space,
    (tx) => peer.offlineSync.db.insertRow<T>(row, transaction: tx),
  );
  final changes = await peer.sync
      .collectPendingChanges(
        peer.raw,
        checkpointsBySpaceUuid: {space: 0},
      )
      .toList();
  await target.db.mergeChanges(changes, userId: space);
}

/// One client sync cycle: push local changes up, then merge the server's.
Future<void> syncWithServer(SyncNode client, SyncNode server) async {
  await pushChanges(client, server);
  await pushChanges(server, client);
}

/// The receiver's durable cursor for the sender's current database epoch.
Future<int> peerCheckpoint(SyncNode from, SyncNode to) async {
  final epoch = await from.offlineSync.db.currentNodeId(userId: testCrdtUserId);
  final receipt = await to.sync.createSyncSinceRevision(
    to.raw,
    userId: testCrdtUserId,
    spaceId: testCrdtUserId,
  );
  return receipt.nodeCheckpoints
          .where((checkpoint) => checkpoint.uuidNodeId == epoch)
          .firstOrNull
          ?.revision ??
      0;
}

/// Commits a complete production capture with its immediate sender identity.
Future<void> deliverCapture(
  SyncNode from,
  SyncNode to,
  OfflineSyncCapture capture,
) async {
  final epoch = await from.offlineSync.db.currentNodeId(userId: testCrdtUserId);
  final peer = await to.sync.resolvePeer(to.raw, testCrdtUserId, epoch);
  for (final checkpoint in capture.checkpoints) {
    await to.sync.mergeInboundBatch(
      to.raw,
      userId: testCrdtUserId,
      spaceId: checkpoint.uuidSpaceId,
      mergeSet: capture.changes
          .where((change) => change.uuidSpaceId == checkpoint.uuidSpaceId)
          .toList(),
      sourcePeerId: peer.id,
      receivedRevision: checkpoint.revision,
    );
  }
}
