import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';

import '../protocol/client.dart';

/// Exposes CRDT sync helpers from a generated client.
extension OfflineSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  OfflineSyncClient get offlineSync => OfflineSyncClient(
    ({required changes, required once}) => Caller(this).offlineSync.sync(
      changes: changes,
      once: once,
    ),
  );
}
