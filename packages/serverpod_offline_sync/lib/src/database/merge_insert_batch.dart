part of 'recorder.dart';

typedef _PlannedMergeInsert = ({
  CrdtMergeInsert change,
  CrdtNode node,
  TableRow<UuidValue?> row,
  List<Column> updateColumns,
  Set<String> explicitNulls,
  ProjectionAttemptsByField attempts,
});

extension on CrdtMutationRecorder {
  /// Fresh rows can share a write window until another operation needs their
  /// persisted state. Self-references retain their causal write boundaries.
  bool _canBatchMergeInsert(CrdtMergeInsert insert, MergeContext context) =>
      !context.rows.containsKey((insert.tableName, insert.uuidRowId)) &&
      !(_foreignKeys.edgesByChildTable[insert.tableName] ?? const <ForeignKeyEdge>[])
          .any((edge) => edge.parentTableName == insert.tableName);

  Future<void> _applyMergeInsertsForMissingRows(
    List<CrdtMergeInsert> inserts,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    ProjectionPlan? batchPlan,
    _MergeWriteBatch writes,
    CrdtForeignKeyPresenceCache? presence,
    Transaction transaction,
  ) async {
    final tableOrder = _mergeInsertTableOrder(inserts);
    if (tableOrder == null) {
      // Cycles and non-primary references can depend on intermediate writes.
      // Keep their original, consecutive table groups.
      var start = 0;
      while (start < inserts.length) {
        var end = start + 1;
        while (end < inserts.length &&
            inserts[end].tableName == inserts[start].tableName) {
          end++;
        }
        await _applyMergeInsertsForMissingRows(
          inserts.sublist(start, end),
          remoteNodes,
          context,
          batchPlan,
          writes,
          presence,
          transaction,
        );
        start = end;
      }
      return;
    }

    // Only primary-key target presence is cached. A non-primary reference
    // resolves through persisted trackers and must see earlier inserted rows.
    if (tableOrder.any(
      (table) => (_foreignKeys.edgesByChildTable[table] ?? const <ForeignKeyEdge>[])
          .any((edge) => edge.parentColumn != 'id'),
    )) {
      await writes.flushInsertedRows();
    }

    final spaceId = _context.spaceIdFor(transaction);
    final preparedByTable = <String, List<_PlannedMergeInsert>>{};
    for (final insert in inserts) {
      final tableName = insert.tableName;
      final data = _sanitizeMergeRowData(tableName, insert.databaseColumns);
      final planned = await _planMergeInsertValues(
        insert,
        data,
        batchPlan,
        presence,
        transaction,
      );
      final row = _withPlannedDomainValues(
        _requireMergeInsertTableRow(insert),
        planned.domain,
      ).copyWithSpaceId(spaceId);
      final columns = row.table.managedColumns
          .where((column) => planned.domain.containsKey(column.columnName))
          .toList();
      if (columns.isEmpty) {
        // Empty authored payloads still need a no-op conflict assignment.
        columns.add(row.table.offlineSyncSpaceIdColumn!);
      }
      (preparedByTable[tableName] ??= []).add((
        change: insert,
        node: _requireRemoteNode(remoteNodes, insert.uuidNodeId),
        row: row as TableRow<UuidValue?>,
        updateColumns: columns,
        explicitNulls: {
          for (final column in row.table.crdtSyncableColumns)
            if (column.hasDefault && planned.domain[column.columnName] == null)
              column.columnName,
        },
        attempts: planned.attempts,
      ));

      // Plan against the same parent presence that causal, individual writes
      // would expose. Physical writes follow only after every row is planned.
      // A later parent must not erase an earlier missing-reference attempt.
      presence?.markVisible((tableName, insert.uuidRowId));
    }

    final prepared = [
      for (final table in tableOrder) ...preparedByTable[table]!,
    ];
    var start = 0;
    while (start < prepared.length) {
      final first = prepared[start];
      final tableName = first.change.tableName;
      var end = start + 1;
      while (end < prepared.length &&
          prepared[end].change.tableName == tableName &&
          _sameMergeInsertShape(first, prepared[end])) {
        end++;
      }
      final group = prepared.sublist(start, end);
      final inserted = await _db.upsert<TableRow<UuidValue?>>(
        [
          for (final pending in group)
            withExplicitInsertNulls(pending.row, pending.explicitNulls),
        ],
        conflictColumns: [first.row.table.id],
        updateColumns: first.updateColumns,
        updateWhere: first.row.table.offlineSyncSpaceIdColumn!.equals(spaceId),
        transaction: transaction,
      );
      final insertedIds = {for (final row in inserted) row.id};
      for (final pending in group) {
        final insert = pending.change;
        if (!insertedIds.contains(insert.uuidRowId)) {
          final owner = await _readDomainRowOwner(
            tableName,
            insert.uuidRowId,
            transaction,
          );
          if (!owner.exists || owner.spaceId == spaceId) {
            throw DatabaseUnexpectedResultException(
              'Merge upsert returned no row without a foreign-space collision.',
            );
          }
          await _throwOwnershipCollision(
            operation: OfflineSyncViolationOperation.mergeInsert,
            tableName: tableName,
            rowId: insert.uuidRowId,
            owningSpaceId: owner.spaceId,
            incomingSpace: _context.effectiveSpaceFor(transaction),
            metadataRowId: null,
            node: pending.node,
            hlc: insert.hlc,
            transaction: transaction,
          );
        }

        final key = (tableName, insert.uuidRowId);
        writes.recordRowInsert(
          tableName,
          CrdtDataRow(
            syncRevision: _context.revisionFor(transaction),
            sourcePeerId: _context.sourcePeerIdFor(transaction),
            spaceId: spaceId,
            tblId: _context.schema[tableName]!.$1,
            uuidRowId: insert.uuidRowId,
            nodeId: pending.node.id!,
            node: pending.node,
            hlcDatetime: insert.hlcDatetime,
            hlcCounter: insert.hlcCounter,
          ),
        );
        context.domainOwners[key] = (exists: true, spaceId: spaceId);
        writes.recordInsertAttempts(
          tableName: tableName,
          rowId: insert.uuidRowId,
          node: pending.node,
          attempts: pending.attempts,
        );
        presence?.markVisible(key);
      }
      start = end;
    }
  }

  /// Parents must be persisted before their children. Within each table the
  /// causal order and explicit-null/default shape boundaries stay unchanged.
  /// Only primary-key references can use the causal presence snapshot above.
  List<String>? _mergeInsertTableOrder(List<CrdtMergeInsert> inserts) {
    final remaining = {for (final insert in inserts) insert.tableName};
    if (remaining.length == 1) return remaining.toList();

    final parents = <String, Set<String>>{};
    for (final table in remaining) {
      final edges = _foreignKeys.edgesByChildTable[table] ?? const <ForeignKeyEdge>[];
      if (edges.any((edge) => edge.parentColumn != 'id')) return null;

      parents[table] = {
        for (final edge in edges)
          if (remaining.contains(edge.parentTableName)) edge.parentTableName,
      };
    }

    final ordered = <String>[];
    while (remaining.isNotEmpty) {
      final ready = remaining
          .where((table) => !parents[table]!.any(remaining.contains))
          .toList();
      if (ready.isEmpty) return null;

      ordered.addAll(ready);
      remaining.removeAll(ready);
    }
    return ordered;
  }
}

/// The ORM takes insert defaults and conflict assignments from the first row.
/// Different projected nulls or authored column sets require separate writes.
bool _sameMergeInsertShape(_PlannedMergeInsert left, _PlannedMergeInsert right) {
  if (left.explicitNulls.length != right.explicitNulls.length ||
      !left.explicitNulls.containsAll(right.explicitNulls) ||
      left.updateColumns.length != right.updateColumns.length) {
    return false;
  }
  for (var index = 0; index < left.updateColumns.length; index++) {
    if (left.updateColumns[index].columnName != right.updateColumns[index].columnName) {
      return false;
    }
  }
  return true;
}
