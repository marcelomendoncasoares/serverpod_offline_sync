import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

/// Stable test identity for CRDT user UUID (RFC 4122).
final testCrdtUserId = UuidValue.fromString('550e8400-e29b-41d4-a716-446655440001');

/// Seeds CRDT prerequisites for domain tests.
///
/// Pass the session from SessionBuilder.build before wrapping it in a CRDT test session,
/// because these rows use non-UUID primary keys and must not go through CrdtDatabase.
Future<void> seedCrdtUserAndPersonSchema(DatabaseSession session) async {
  await CrdtUser.db.insert(
    session,
    [CrdtUser(uuidUserId: testCrdtUserId)],
    ignoreConflicts: true,
  );
  await CrdtSchemaTable.db.insert(
    session,
    [CrdtSchemaTable(name: 'person')],
    ignoreConflicts: true,
  );
}

/// Registers Person column names in the CRDT schema table so per-field CRDT rows can be created for tests.
Future<void> seedCrdtSchemaColumnsForPerson(DatabaseSession session) async {
  final personTable = await CrdtSchemaTable.db.findFirstRow(
    session,
    where: (t) => t.name.equals('person'),
  );
  final tblId = personTable?.id;
  if (tblId == null) {
    throw StateError('CrdtSchemaTable person not seeded.');
  }
  await CrdtSchemaColumn.db.insert(session, [
    CrdtSchemaColumn(tblId: tblId, name: 'name'),
    CrdtSchemaColumn(tblId: tblId, name: 'organizationId'),
    CrdtSchemaColumn(tblId: tblId, name: 'oldCompanyId'),
  ], ignoreConflicts: true);
}

CrdtDatabase crdtDatabase(Session session) {
  return CrdtDatabase(
    session.db,
    persistentUserId: testCrdtUserId,
  );
}

Future<void> clearDatabase(DatabaseSession session) async {
  await CrdtUser.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtSchemaTable.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtSchemaColumn.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataRow.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataField.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtDataDeleted.db.deleteWhere(session, where: (t) => t.id >= 0);
  await CrdtNode.db.deleteWhere(session, where: (t) => t.id >= 0);
}
