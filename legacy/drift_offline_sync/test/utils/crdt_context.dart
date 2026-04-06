import 'package:drift/drift.dart';
import 'package:drift_offline_sync/drift_offline_sync.dart';

/// Extensions for [GeneratedDatabase] to get the CRDT context for testing.
extension CrdtContextExtensions on GeneratedDatabase {
  (OfflineSyncCrdt crdt, CrdtDatabase crdtDb, String nodeId) get crdtContext {
    final migrator = createMigrator();
    if (migrator is! OfflineSyncMigrator) {
      throw StateError('Migrator is not an OfflineSyncMigrator');
    }
    return (migrator.crdt, migrator.crdtDb, migrator.nodeId);
  }
}
