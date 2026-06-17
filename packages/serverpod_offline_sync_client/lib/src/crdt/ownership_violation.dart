import 'package:serverpod_database/serverpod_database.dart';

import '../protocol/protocol.dart';

/// Persists or updates the durable row for an ownership violation.
Future<CrdtSyncOwnershipViolation> recordCrdtOwnershipViolation(
  DatabaseSession session, {
  required CrdtSyncOwnershipViolation violation,
  Transaction? transaction,
}) async {
  final existing = await CrdtSyncOwnershipViolation.db.findFirstRow(
    session,
    where: (t) =>
        t.domainTableName.equals(violation.domainTableName) &
        t.uuidRowId.equals(violation.uuidRowId) &
        t.ownerScopeUuid.equals(violation.ownerScopeUuid) &
        t.incomingScopeUuid.equals(violation.incomingScopeUuid),
    transaction: transaction,
  );

  final now = DateTime.now().toUtc();
  final newViolation = existing != null
      ? existing.copyWith(
          operation: violation.operation,
          crdtDataRowId: violation.crdtDataRowId ?? existing.crdtDataRowId,
          uuidNodeId: violation.uuidNodeId ?? existing.uuidNodeId,
          hlcDatetime: violation.hlcDatetime,
          hlcCounter: violation.hlcCounter,
          lastSeenAt: now,
          occurrences: existing.occurrences + 1,
        )
      : violation.copyWith(
          firstSeenAt: now,
          lastSeenAt: now,
          occurrences: 1,
        );

  final persisted = await CrdtSyncOwnershipViolation.db.upsertRow(
    session,
    newViolation,
    conflictColumns: (t) => [
      t.domainTableName,
      t.uuidRowId,
      t.ownerScopeUuid,
      t.incomingScopeUuid,
    ],
    transaction: transaction,
  );

  return persisted!;
}
