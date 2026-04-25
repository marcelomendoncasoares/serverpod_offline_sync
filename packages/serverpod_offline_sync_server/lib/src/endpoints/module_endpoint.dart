import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

// import '../generated/protocol.dart';

/// TODO: Create the classes.
abstract class CrdtDataEntry {}

/// Endpoint for the CRDT sync.
class SyncOfflineChangesEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  /// Syncs the offline changes between server and client.
  ///
  /// This endpoint is used to sync the offline changes between server and
  /// client. After a handshake on the [migrationVersion] to ensure that the
  /// merge can happen, the client will send all [offlineChanges] since the
  /// [lastSyncHlc] HLC and the server will send all online changes through
  /// the returning stream.
  ///
  /// The connection will be kept open until one end disconnects, forwarding
  /// the changes to the other end.
  Stream<CrdtDataEntry> syncOfflineChanges(
    Session session, {
    required String migrationVersion,
    required Hlc lastSyncHlc,

    /// TODO: Create the classes.
    /// CrdtDataEntry will be a sealed class with the changes.
    ///
    /// - CrdtDataRow: New rows inserted.
    /// - CrdtDataField: Fields updated.
    /// - CrdtDataDeleted: Rows deleted.
    required Stream<CrdtDataEntry> offlineChanges,
  }) async* {
    // TODO: Implement the business layer for the CRDT sync.
    // yield* CrdtSync.syncOfflineChanges(session);
  }
}
