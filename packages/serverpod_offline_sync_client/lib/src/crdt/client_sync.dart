import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';

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
    final pendingChanges = await crdtDb.collectPendingChanges(
      otherNodeId: otherNodeId,
    );

    final localNodeId = await crdtDb.currentNodeId();
    final receivedChanges = await _caller.crdtSync.syncOnce(
      syncTablesHash: crdtDb.syncTablesHash,
      otherNodeId: localNodeId,
      changes: pendingChanges,
    );

    await _mergeAndRecordCheckpoint(session, receivedChanges, otherNodeId);
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

    try {
      final remoteStream = _caller.crdtSync.syncStream(
        syncTablesHash: crdtDb.syncTablesHash,
        otherNodeId: localNodeId,
        changes: outboundChanges.stream,
      );

      await for (final remoteBatch in remoteStream.collectMergeSets()) {
        final pendingLocalChanges = await crdtDb.collectPendingChanges(
          otherNodeId: otherNodeId,
        );
        pendingLocalChanges.streamTo(outboundChanges);
        await _mergeAndRecordCheckpoint(session, remoteBatch, otherNodeId);
      }
    } finally {
      await outboundChanges.close();
    }
  }

  Future<void> _mergeAndRecordCheckpoint(
    DatabaseSession session,
    CrdtMergeSet receivedChanges,
    UuidValue otherNodeId,
  ) async {
    final crdtDb = session.crdtDb;
    await crdtDb.mergeChanges(receivedChanges);

    final syncedHlc = receivedChanges.maxHlc;
    if (syncedHlc != null) {
      await crdtDb.recordSyncCheckpoint(
        otherNodeId,
        syncedHlc,
      );
    }
  }
}

/// Exposes CRDT sync helpers from a generated client.
extension CrdtSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  CrdtSyncClient get crdt => CrdtSyncClient(Caller(this));
}
