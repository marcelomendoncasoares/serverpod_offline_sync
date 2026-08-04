import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import '../protocol/client.dart';

/// Exposes CRDT sync helpers from a generated client.
extension CrdtSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  CrdtSyncClient get crdt => CrdtSyncClient(
    ({required changes, required once}) => Caller(this).crdtSync.sync(
      changes: changes,
      once: once,
    ),
  );
}
