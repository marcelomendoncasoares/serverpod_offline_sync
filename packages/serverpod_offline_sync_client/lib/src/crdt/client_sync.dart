import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../database/session.dart';
import '../protocol/protocol.dart';
import 'merge.dart';

/// High-level client sync helpers built on top of the generated module caller.
class CrdtSyncClient {
  /// Creates a [CrdtSyncClient] for the provided module caller.
  CrdtSyncClient(this._caller);

  final Caller _caller;

  /// Pushes local pending changes for [session] to the remote peer once.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncOnce(
    DatabaseSession session, {
    required UuidValue otherNodeId,
  }) async {
    final crdtDb = session.crdtDb;
    final localNodeId = await crdtDb.currentNodeId();
    final pendingChanges = await crdtDb.collectPendingChanges(
      otherNodeId: otherNodeId,
    );

    await _caller.crdtSync.syncOnce(
      syncTablesHash: crdtDb.syncTablesHash,
      otherNodeId: localNodeId,
      changes: pendingChanges,
    );

    final syncedHlc = pendingChanges.maxHlc;
    if (syncedHlc != null) {
      await crdtDb.recordSyncCheckpoint(
        otherNodeId,
        syncedHlc,
      );
    }
  }

  /// Keeps synchronizing [session] with the remote peer until the stream closes.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncContinuously(
    DatabaseSession session, {
    required UuidValue otherNodeId,
  }) async {
    final crdtDb = session.crdtDb;
    final localNodeId = await crdtDb.currentNodeId();
    final outboundChanges = StreamController<CrdtMergeChange?>();
    var pendingLocalChanges = await crdtDb.collectPendingChanges(
      otherNodeId: otherNodeId,
    );
    Hlc? pendingAcknowledgedLocalHlc;

    try {
      final remoteStream = _caller.crdtSync.syncStream(
        syncTablesHash: crdtDb.syncTablesHash,
        otherNodeId: localNodeId,
        changes: outboundChanges.stream,
      );

      await for (final remoteBatch in collectMergeSetBatches(remoteStream)) {
        if (!remoteBatch.isEmpty) {
          await crdtDb.mergeChanges(remoteBatch);
        }

        final syncCheckpoint =
            pendingAcknowledgedLocalHlc?.maxBetween(remoteBatch.maxHlc) ??
            remoteBatch.maxHlc;
        if (syncCheckpoint != null) {
          await crdtDb.recordSyncCheckpoint(
            otherNodeId,
            syncCheckpoint,
          );
        }

        addMergeSetWithSentinel(outboundChanges.add, pendingLocalChanges);
        pendingAcknowledgedLocalHlc = pendingLocalChanges.maxHlc;
        pendingLocalChanges = await crdtDb.collectPendingChanges(
          otherNodeId: otherNodeId,
        );
      }
    } finally {
      await outboundChanges.close();
    }
  }
}

/// Exposes CRDT sync helpers from a generated client.
extension CrdtSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  CrdtSyncClient get crdt => CrdtSyncClient(Caller(this));
}
