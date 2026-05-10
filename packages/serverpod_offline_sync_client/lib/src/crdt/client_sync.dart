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
    UuidValue? userId,
  }) async {
    final crdtDb = session.crdtDb;
    final localNodeId = await crdtDb.currentNodeId(userId: userId);
    final pendingChanges = await crdtDb.collectPendingChanges(
      otherNodeId: otherNodeId,
      userId: userId,
    );
    if (pendingChanges.isEmpty) return;

    await _caller.callServerEndpoint<void>(
      'serverpod_offline_sync.crdtSync',
      'syncOnce',
      {
        'syncTablesHash': crdtDb.syncTablesHash,
        'otherNodeId': localNodeId,
        'changes': pendingChanges,
      },
    );

    final syncedHlc = pendingChanges.maxHlc;
    if (syncedHlc != null) {
      await crdtDb.recordSyncCheckpoint(
        otherNodeId,
        syncedHlc,
        userId: userId,
      );
    }
  }

  /// Keeps synchronizing [session] with the remote peer until the stream closes.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncContinuously(
    DatabaseSession session, {
    required UuidValue otherNodeId,
    UuidValue? userId,
  }) async {
    final crdtDb = session.crdtDb;
    final localNodeId = await crdtDb.currentNodeId(userId: userId);
    final outboundChanges = StreamController<CrdtMergeChange?>();
    var pendingLocalChanges = await crdtDb.collectPendingChanges(
      otherNodeId: otherNodeId,
      userId: userId,
    );
    Hlc? pendingAcknowledgedLocalHlc;

    try {
      final remoteStream =
          _caller.callStreamingServerEndpoint<CrdtMergeChange, CrdtMergeChange?>(
                'serverpod_offline_sync.crdtSync',
                'syncStream',
                {
                  'syncTablesHash': crdtDb.syncTablesHash,
                  'otherNodeId': localNodeId,
                },
                {'changes': outboundChanges.stream},
              )
              as Stream<CrdtMergeChange?>;

      await for (final remoteBatch in collectMergeSetBatches(remoteStream)) {
        if (!remoteBatch.isEmpty) {
          await crdtDb.mergeChanges(remoteBatch, userId: userId);
        }

        final syncCheckpoint =
            pendingAcknowledgedLocalHlc?.maxBetween(remoteBatch.maxHlc) ??
            remoteBatch.maxHlc;
        if (syncCheckpoint != null) {
          await crdtDb.recordSyncCheckpoint(
            otherNodeId,
            syncCheckpoint,
            userId: userId,
          );
        }

        addMergeSetWithSentinel(outboundChanges.add, pendingLocalChanges);
        pendingAcknowledgedLocalHlc = pendingLocalChanges.maxHlc;
        pendingLocalChanges = await crdtDb.collectPendingChanges(
          otherNodeId: otherNodeId,
          userId: userId,
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
