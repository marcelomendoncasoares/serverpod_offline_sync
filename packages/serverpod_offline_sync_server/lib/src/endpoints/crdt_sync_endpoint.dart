import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';

/// Endpoint for CRDT-based offline-first synchronization.
class CrdtSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  UuidValue _userId(Session session) {
    return UuidValue.withValidation(session.authenticated!.userIdentifier);
  }

  /// Applies a one-way sync operation from the authenticated client.
  Future<void> syncOnce(
    Session session, {
    required String syncTablesHash,
    required UuidValue otherNodeId,
    required CrdtMergeSet changes,
  }) async {
    await CrdtSync.instance.syncOnce(
      session,
      userId: _userId(session),
      otherNodeId: otherNodeId,
      syncTablesHash: syncTablesHash,
      changes: changes,
    );
  }

  /// Streams server changes and then applies streamed client changes.
  Stream<CrdtMergeChange?> syncStream(
    Session session, {
    required String syncTablesHash,
    required UuidValue otherNodeId,
    required Stream<CrdtMergeChange?> changes,
  }) async* {
    yield* CrdtSync.instance.syncStream(
      session,
      userId: _userId(session),
      otherNodeId: otherNodeId,
      syncTablesHash: syncTablesHash,
      changes: changes,
    );
  }
}
