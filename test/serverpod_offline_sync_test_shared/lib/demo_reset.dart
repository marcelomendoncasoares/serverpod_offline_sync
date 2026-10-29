import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show Uuid, UuidValue;

/// Clears the demo user's personal space and replaces its local replica epoch.
///
/// Stop this user's sync streams and writes before calling this maintenance
/// operation. The epoch is shared across the user's spaces: retire only the old
/// node's local binding, preserving its UUID and every retained fact's author.
/// Deletion and epoch replacement commit atomically, then the calling wrapper's
/// caches are refreshed. Other wrappers for this user must be reopened.
Future<void> resetDemoSpace(DatabaseSession session, UuidValue userId) async {
  final db = session.offlineSyncDb;
  await db.initialize();
  await db.transaction((transaction) async {
    if (db.dialect == DatabaseDialect.sqlite) {
      await db.unsafeExecute(
        'PRAGMA defer_foreign_keys = ON',
        transaction: transaction,
      );
    }

    await CrdtNode.db.updateWhere(
      session,
      columnValues: (t) => [t.localUserUuid(null)],
      where: (t) => t.localUserUuid.equals(userId),
      transaction: transaction,
    );
    final epoch = const Uuid().v7obj();
    await CrdtNode.db.insertRow(
      session,
      CrdtNode(
        uuidNodeId: epoch,
        localUserUuid: userId,
        lastHlc: Hlc.zero(epoch),
      ),
      transaction: transaction,
    );
    await OfflineSyncSpace.db.deleteWhere(
      session,
      where: (t) => t.uuidSpaceId.equals(userId),
      transaction: transaction,
    );
  });

  await db.initialize();
}
