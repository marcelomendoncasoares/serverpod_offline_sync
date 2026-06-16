import 'package:serverpod_database/serverpod_database.dart';

import '../protocol/protocol.dart';

/// Persists or updates the durable row for an ownership violation.
Future<CrdtSyncOwnershipViolation> recordCrdtOwnershipViolation(
  DatabaseSession session, {
  required CrdtSyncOwnershipViolation violation,
  Transaction? transaction,
}) async {
  final now = DateTime.now().toUtc();

  final tableId = violation.tblId == null
      ? null
      : (await CrdtSchemaTable.db.findById(
          session,
          violation.tblId!,
          transaction: transaction,
        ))?.id;
  final rowId = violation.rowId == null
      ? null
      : (await CrdtDataRow.db.findById(
          session,
          violation.rowId!,
          transaction: transaction,
        ))?.id;
  final nodeId = await _existingOrCreateNodeId(
    session,
    violation: violation,
    transaction: transaction,
  );

  Future<CrdtSyncOwnershipViolation?> findExisting() {
    return CrdtSyncOwnershipViolation.db.findFirstRow(
      session,
      where: (t) =>
          t.domainTableName.equals(violation.domainTableName) &
          t.uuidRowId.equals(violation.uuidRowId) &
          t.ownerScopeUuid.equals(violation.ownerScopeUuid) &
          t.incomingScopeUuid.equals(violation.incomingScopeUuid),
      transaction: transaction,
    );
  }

  Future<CrdtSyncOwnershipViolation> updateExisting(
    CrdtSyncOwnershipViolation existing,
  ) {
    return CrdtSyncOwnershipViolation.db.updateRow(
      session,
      existing.copyWith(
        tblId: tableId ?? existing.tblId,
        rowId: rowId ?? existing.rowId,
        operation: violation.operation,
        nodeId: nodeId,
        hlcDatetime: violation.hlcDatetime,
        hlcCounter: violation.hlcCounter,
        lastSeenAt: now,
        occurrences: existing.occurrences + 1,
      ),
      columns: (t) => [
        t.tblId,
        t.rowId,
        t.operation,
        t.nodeId,
        t.hlcDatetime,
        t.hlcCounter,
        t.lastSeenAt,
        t.occurrences,
      ],
      transaction: transaction,
    );
  }

  final existing = await findExisting();
  if (existing != null) return updateExisting(existing);

  try {
    return await CrdtSyncOwnershipViolation.db.insertRow(
      session,
      CrdtSyncOwnershipViolation(
        tblId: tableId,
        domainTableName: violation.domainTableName,
        rowId: rowId,
        uuidRowId: violation.uuidRowId,
        ownerScopeUuid: violation.ownerScopeUuid,
        incomingScopeUuid: violation.incomingScopeUuid,
        operation: violation.operation,
        nodeId: nodeId,
        hlcDatetime: violation.hlcDatetime,
        hlcCounter: violation.hlcCounter,
        firstSeenAt: now,
        lastSeenAt: now,
        occurrences: 1,
      ),
      transaction: transaction,
    );
  } on DatabaseQueryException {
    final concurrent = await findExisting();
    if (concurrent != null) return updateExisting(concurrent);
    rethrow;
  }
}

Future<int?> _existingOrCreateNodeId(
  DatabaseSession session, {
  required CrdtSyncOwnershipViolation violation,
  Transaction? transaction,
}) async {
  final nodeId = violation.nodeId;
  if (nodeId != null) {
    final node = await CrdtNode.db.findById(
      session,
      nodeId,
      transaction: transaction,
    );
    if (node != null) return node.id;
  }

  final nodeUuid = violation.node?.uuidNodeId;
  if (nodeUuid == null) return null;

  final scope = await CrdtScope.db.findFirstRow(
    session,
    where: (t) => t.uuidScopeId.equals(violation.incomingScopeUuid),
    transaction: transaction,
  );
  final scopeId = scope?.id;
  if (scopeId == null) return null;

  var node = await CrdtNode.db.findFirstRow(
    session,
    where: (t) => t.scopeId.equals(scopeId) & t.uuidNodeId.equals(nodeUuid),
    transaction: transaction,
  );
  if (node != null) return node.id;

  await CrdtNode.db.insert(
    session,
    [CrdtNode(scopeId: scopeId, uuidNodeId: nodeUuid)],
    transaction: transaction,
    ignoreConflicts: true,
  );

  node = await CrdtNode.db.findFirstRow(
    session,
    where: (t) => t.scopeId.equals(scopeId) & t.uuidNodeId.equals(nodeUuid),
    transaction: transaction,
  );
  return node?.id;
}
