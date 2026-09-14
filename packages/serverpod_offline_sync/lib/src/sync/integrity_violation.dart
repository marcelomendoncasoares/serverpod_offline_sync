import 'package:clock/clock.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../generated/protocol.dart';

/// Persists or updates the durable row for an integrity violation.
Future<OfflineSyncIntegrityViolation> recordOfflineSyncIntegrityViolation(
  DatabaseSession session, {
  required OfflineSyncIntegrityViolation violation,
  Transaction? transaction,
}) async {
  final existing = await OfflineSyncIntegrityViolation.db.findFirstRow(
    session,
    where: (t) =>
        t.type.equals(violation.type) &
        t.operation.equals(violation.operation) &
        t.domainTableName.equals(violation.domainTableName) &
        t.uuidRowId.equals(violation.uuidRowId) &
        t.ownerSpaceUuid.equals(violation.ownerSpaceUuid) &
        t.incomingSpaceUuid.equals(violation.incomingSpaceUuid),
    transaction: transaction,
  );

  final now = clock.now().toUtc();
  final newViolation = existing != null
      ? existing.copyWith(
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

  final persisted = await OfflineSyncIntegrityViolation.db.upsertRow(
    session,
    newViolation,
    conflictColumns: (t) => [
      t.type,
      t.operation,
      t.domainTableName,
      t.uuidRowId,
      t.ownerSpaceUuid,
      t.incomingSpaceUuid,
    ],
    transaction: transaction,
  );

  return persisted!;
}
