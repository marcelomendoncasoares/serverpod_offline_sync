import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

/// Endpoint for CRDT-based offline-first synchronization.
class CrdtSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Applies a one-way sync operation from the authenticated client.
  Future<void> syncOnce(
    Session session, {
    required String syncTablesHash,
    required CrdtMergeSet changes,
  }) async {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    await CrdtSync.instance.syncOnce(
      session,
      userId: userId,
      syncTablesHash: syncTablesHash,
      changes: changes,
    );
  }

  /// Streams server changes and then applies streamed client changes.
  Stream<CrdtMergeChange?> syncStream(
    Session session, {
    required String syncTablesHash,
    required Hlc lastSyncHlc,
    required Stream<CrdtMergeChange?> changes,
  }) async* {
    final userId = UuidValue.withValidation(
      session.authenticated!.userIdentifier,
    );

    yield* CrdtSync.instance.syncStream(
      session,
      userId: userId,
      syncTablesHash: syncTablesHash,
      lastSyncHlc: lastSyncHlc,
      changes: changes,
    );
  }
}
