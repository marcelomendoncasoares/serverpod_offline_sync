import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

/// Stable test identity for CRDT user UUID (RFC 4122).
final testCrdtUserId = UuidValue.fromString('550e8400-e29b-41d4-a716-446655440001');

Future<void> clearDatabase(DatabaseSession session) async {
  await CrdtUser.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtSchemaTable.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtSchemaColumn.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataRow.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataField.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataDeleted.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtNode.db.deleteWhere(session, where: (t) => t.id >= 0);
}
