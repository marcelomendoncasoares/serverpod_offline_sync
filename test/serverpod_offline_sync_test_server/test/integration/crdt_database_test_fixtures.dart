import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

/// Stable test identity for CRDT user UUID (RFC 4122).
final testCrdtUserId = UuidValue.fromString('550e8400-e29b-41d4-a716-446655440001');

/// Seeds CRDT prerequisites for mutating domain rows through [CrdtDatabase].
Future<void> seedCrdtUserAndPersonSchema(Session session) async {
  await CrdtUser.db.insertRow(session, CrdtUser(uuidUserId: testCrdtUserId));
  await CrdtSchemaTable.db.insertRow(session, CrdtSchemaTable(name: 'person'));
}

CrdtDatabase crdtDatabase(Session session) {
  return CrdtDatabase(
    session.db,
    persistentUserId: testCrdtUserId,
    recorder: (db) => CrdtMutationRecorder(db, persistentUserId: testCrdtUserId),
  );
}
