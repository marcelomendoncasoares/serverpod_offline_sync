import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

/// Endpoint for CRDT-based offline-first synchronization.
///
/// Call `pod.initializeCrdtSync(...)` once during server startup so this
/// endpoint can load the CRDT sync configuration from the shared singleton.
class CrdtSyncEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Synchronizes CRDT changes between the server and an authenticated client.
  ///
  /// First validates [syncTablesHash] against the server's configured tables.
  /// If the hashes differ, a [SyncTablesHashMismatchException] is thrown,
  /// telling the client to migrate its schema first.
  ///
  /// The server then streams all changes since [lastSyncHlc] to the caller,
  /// followed by a null value as sentinel. The caller should stream its own
  /// changes in the [changes] stream and close with its own null sentinel.
  /// Once the null sentinel is received the server merges all accumulated
  /// client changes atomically.
  Stream<CrdtMergeChange?> syncNode(
    Session session, {
    required String syncTablesHash,
    required Hlc lastSyncHlc,
    required Stream<CrdtMergeChange?> changes,
  }) async* {
    final authInfo = session.authenticated!;

    yield* CrdtSync.instance.syncNodeForUser(
      session,
      userId: UuidValue.withValidation(authInfo.userIdentifier),
      syncTablesHash: syncTablesHash,
      lastSyncHlc: lastSyncHlc,
      changes: changes,
    );
  }
}
