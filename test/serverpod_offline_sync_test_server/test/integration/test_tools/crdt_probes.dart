import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'client_session.dart';

/// The HLC stamped on a row's CRDT metadata.
///
/// The node is included because reading the HLC back resolves the node's uuid
/// and throws without it.
Future<Hlc> rowHlc(
  UuidValue rowId, {
  OfflineSyncDatabaseSession? databaseSession,
}) async {
  final crdtRow = await CrdtDataRow.db.findFirstRow(
    databaseSession ?? session,
    where: (t) => t.uuidRowId.equals(rowId),
    include: CrdtDataRow.include(node: CrdtNode.include()),
  );

  return crdtRow!.hlc;
}

/// The authored value a column is holding back, or null when the domain row
/// holds what was authored.
Future<CrdtDataAttemptedValue?> attemptedValue({
  required UuidValue rowId,
  required String columnName,
  OfflineSyncDatabaseSession? databaseSession,
}) async {
  final field = await CrdtDataField.db.findFirstRow(
    databaseSession ?? session,
    where: (t) => t.row.uuidRowId.equals(rowId) & t.column.name.equals(columnName),
    include: CrdtDataField.include(
      attemptedValue: CrdtDataAttemptedValue.include(),
    ),
  );
  return field?.attemptedValue;
}

/// The clock last persisted by the local node of [userId] in the database of
/// [databaseSession].
Future<Hlc> persistedUserClock(
  DatabaseSession databaseSession,
  UuidValue userId,
) async {
  final node = await CrdtNode.db.findFirstRow(
    databaseSession,
    where: (t) => t.localUserUuid.equals(userId),
  );
  return node!.lastHlc!;
}
