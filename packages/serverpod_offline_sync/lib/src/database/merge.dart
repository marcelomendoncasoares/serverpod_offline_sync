part of 'recorder.dart';

/// Field metadata for merged inserts, waiting to be written as one batch.
///
/// Every query behind [CrdtForeignKeyProjector.recordInsertAttempts] already
/// takes a set of row ids, so a batch of inserts into one table costs the same
/// as one insert. Rows are grouped by node as well as table because the merge
/// cache stores each field with the node that authored it.
class _PendingInsertAttempts {
  final Map<(String, int), ({Set<UuidValue> rowIds, CrdtNode node})> _byGroup =
      {};
  final Map<String, ProjectionAttemptsByField> _attemptsByTable = {};
  final Set<MergeRowKey> _rows = {};

  bool get isEmpty => _byGroup.isEmpty;

  /// Whether metadata for [rowKey] is still unwritten.
  bool holds(MergeRowKey rowKey) => _rows.contains(rowKey);

  void add({
    required String tableName,
    required UuidValue rowId,
    required CrdtNode node,
    required ProjectionAttemptsByField attempts,
  }) {
    _byGroup
        .putIfAbsent(
          (tableName, node.id!),
          () => (rowIds: <UuidValue>{}, node: node),
        )
        .rowIds
        .add(rowId);
    _rows.add((tableName, rowId));
    if (attempts.isEmpty) return;
    _attemptsByTable
        .putIfAbsent(tableName, () => <MergeFieldKey, ProjectionAttempt>{})
        .addAll(attempts);
  }

  /// Empties the collector and returns what it held.
  List<
    ({
      String tableName,
      Set<UuidValue> rowIds,
      CrdtNode node,
      ProjectionAttemptsByField attempts,
    })
  >
  take() {
    final groups = [
      for (final MapEntry(key: key, value: group) in _byGroup.entries)
        (
          tableName: key.$1,
          rowIds: group.rowIds,
          node: group.node,
          attempts:
              _attemptsByTable[key.$1] ??
              const <MergeFieldKey, ProjectionAttempt>{},
        ),
    ];
    _byGroup.clear();
    _attemptsByTable.clear();
    _rows.clear();
    return groups;
  }
}

/// Adds merge-specific behavior to [CrdtMutationRecorder].
extension CrdtMergeRecorderExtension on CrdtMutationRecorder {
  /// Locks the current user row so merges can serialize with other work.
  Future<void> lockCurrentUser(Transaction transaction) async {
    final user = _context.effectiveScopeFor(transaction);
    // Use a row lock without fetching the record since the merge path only
    // needs serialization against concurrent work for the same user.
    await CrdtScope.db.lockRows(
      _session,
      where: (t) => t.id.equals(user.id),
      transaction: transaction,
      lockMode: LockMode.forUpdate,
      lockBehavior: LockBehavior.wait,
    );
  }

  /// Merges remote CRDT changes into the current database.
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    if (mergeSet.isEmpty) return;

    final operations = mergeSet.causallyOrderedChanges;
    // Nothing in this batch touches a foreign key or a unique index, so no
    // projection decision can change: skip both passes instead of loading
    // state for tables that cannot produce a candidate or a conflict.
    final mayAffectProjection = _foreignKeyProjector
        .mergeOperationsMayAffectProjection(operations);
    final authoredOverlays = <MergeFieldKey, Object?>{};
    final currentUser = _context.effectiveScopeFor(transaction);
    final remoteNodes = await _findOrCreateNodesForMerge(
      currentUser.id!,
      {for (final change in operations) change.uuidNodeId},
      transaction,
    );
    final nodesByUuid = remoteNodes.nodesByUuid;
    final context = await _loadMergeContext(mergeSet, transaction);

    // Deletes carry no authored overlay but still change visibility, so the
    // seed is every touched row, not just the ones with overlays.
    final touchedTables = <String>{};
    final touchedRows = <MergeRowKey>{};
    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName)) continue;
      touchedTables.add(operation.tableName);
      touchedRows.add((operation.tableName, operation.uuidRowId));
    }

    final batch = mayAffectProjection
        ? await _planBatchInserts(
            operations,
            nodesByUuid,
            context,
            touchedTables,
            touchedRows,
            transaction,
          )
        : (plan: null, pending: const <PendingProjectionRow>[]);
    // Every merged insert has to know whether the rows its foreign keys name
    // are there, which is one query per edge unless the batch resolves them
    // together and then keeps the answers current as it writes.
    final presence = batch.pending.isEmpty
        ? null
        : await _foreignKeyProjector.resolvePresenceForInserts(
            batch.pending,
            transaction,
          );

    // Field metadata for merged inserts is recorded per table and node rather
    // than per row: every query behind it already takes a set of row ids.
    final pendingAttempts = _PendingInsertAttempts();

    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName)) {
        continue;
      }
      // A later operation on a row resolves its field metadata through the
      // merge cache, so anything still pending for that row is written first.
      if (pendingAttempts.holds((operation.tableName, operation.uuidRowId))) {
        await _flushInsertAttempts(pendingAttempts, context, transaction);
      }

      switch (operation) {
        case final CrdtMergeInsert insert:
          await _applyMergeInsert(
            insert,
            nodesByUuid,
            context,
            authoredOverlays,
            batch.plan,
            pendingAttempts,
            presence,
            transaction,
          );
        case final CrdtMergeUpdate update:
          await _applyMergeUpdate(
            update,
            nodesByUuid,
            context,
            authoredOverlays,
            transaction,
          );
        case final CrdtMergeDelete delete:
          await _applyMergeDelete(
            delete,
            nodesByUuid,
            context,
            transaction,
          );
          // A delete can hide the row, and a resurrecting one can bring it
          // back; either way what was known about it no longer holds.
          presence?.forget((delete.tableName, delete.uuidRowId));
      }
    }

    await _flushInsertAttempts(pendingAttempts, context, transaction);

    if (mayAffectProjection) {
      await _foreignKeyProjector.project(
        transaction,
        authoredOverlays: authoredOverlays,
        seedTables: touchedTables,
        seedRows: touchedRows,
      );
    } else {
      // The pass is also what writes an update's value, so its authored
      // values still have to land when it is skipped.
      await _foreignKeyProjector.writeAuthoredValues(
        authoredOverlays,
        transaction,
      );
    }
    await _updateHlcFromIncomingOperations(
      operations,
      remoteNodes,
      transaction,
    );
  }

  Future<void> _updateHlcFromIncomingOperations(
    List<CrdtMergeChange> operations,
    MergeNodes remoteNodes,
    Transaction transaction,
  ) async {
    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) => change.hlc.maxBetween(current),
    );
    final scopeNodesToUpdate = <CrdtScopeNode>[];

    if (maxIncomingHlc != null) {
      final hlcManager = _context.hlcManagerFor(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        if (maxIncomingHlc > hlcManager.lastHlc) {
          hlcManager.lastHlc = maxIncomingHlc;
        }
      } else {
        hlcManager.merge(maxIncomingHlc);
      }

      await _context.persistCurrentNodeHlc(hlcManager, transaction);
    }

    final maxIncomingHlcByNode = <UuidValue, Hlc>{};
    for (final operation in operations) {
      maxIncomingHlcByNode[operation.uuidNodeId] = operation.hlc.maxBetween(
        maxIncomingHlcByNode[operation.uuidNodeId],
      );
    }

    for (final MapEntry(key: nodeId, value: incomingHlc)
        in maxIncomingHlcByNode.entries) {
      final remoteNode = remoteNodes.scopeNodesByUuid[nodeId];
      if (remoteNode == null) continue;
      final updatedScopeNode = remoteNode.copyWith(
        lastReceivedHlc: incomingHlc.maxBetween(remoteNode.lastReceivedHlc),
      );
      if (updatedScopeNode.lastReceivedHlc == remoteNode.lastReceivedHlc) {
        continue;
      }

      scopeNodesToUpdate.add(updatedScopeNode);
      remoteNodes.scopeNodesByUuid[nodeId] = updatedScopeNode;
    }

    if (scopeNodesToUpdate.isNotEmpty) {
      await CrdtScopeNode.db.update(
        _session,
        scopeNodesToUpdate,
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );
    }
  }

  Future<MergeNodes> _findOrCreateNodesForMerge(
    int userId,
    Set<UuidValue> nodeIds,
    Transaction transaction,
  ) async {
    if (nodeIds.isEmpty) {
      return (
        nodesByUuid: const <UuidValue, CrdtNode>{},
        scopeNodesByUuid: const <UuidValue, CrdtScopeNode>{},
      );
    }

    final nodesByUuid = {
      for (final uuidNodeId in nodeIds)
        uuidNodeId: await _context.findOrCreateNode(uuidNodeId, transaction),
    };

    final scopeNodesByUuid = {
      for (final entry in nodesByUuid.entries)
        entry.key: await _context.findOrCreateScopeNode(
          userId,
          entry.value.id!,
          transaction,
        ),
    };

    return (
      nodesByUuid: nodesByUuid,
      scopeNodesByUuid: scopeNodesByUuid,
    );
  }

  Future<MergeContext> _loadMergeContext(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    final (:rowIdsByTable, :columnNamesByTable) = mergeSet.collectMetadataLookup(
      columnNamesByTableName: _context.syncedTableColumnNamesForMerge,
    );

    final rows = <MergeRowKey, CrdtDataRow>{};
    final fields = <MergeFieldKey, CrdtDataField>{};
    final incomingFieldHlcs = {
      for (final update in mergeSet.whereType<CrdtMergeUpdate>())
        (update.tableName, update.uuidRowId, update.columnName): update.hlc,
    };
    final tombstones = <MergeRowKey, CrdtDataDeleted>{};
    // Owning scope per row, snapshotted once so the per-operation ownership
    // checks never re-read the same immutable `scopeId`. Only rows that
    // already have a tracker are pre-read here — those are exactly the rows
    // whose ownership the update/delete/existing-insert paths verify. New
    // rows go through the insert path, which proves ownership at the physical
    // write and refreshes this entry afterwards.
    final domainOwners = <MergeRowKey, DomainRowOwner>{};

    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final loadedRows = await _context.findCrdtRows(
        tableName,
        rowIds,
        transaction,
        include: CrdtDataRow.include(
          node: CrdtNode.include(),
          deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
        ),
      );

      for (final row in loadedRows) {
        rows[(tableName, row.uuidRowId)] = row;
        if (row.deleted != null) {
          tombstones[(tableName, row.uuidRowId)] = row.deleted!;
        }
      }

      final trackedRowIds = loadedRows.map((row) => row.uuidRowId).toSet();
      if (trackedRowIds.isNotEmpty) {
        final ownerValues = await _context.readDomainColumnValues(
          tableName,
          trackedRowIds,
          ['scopeId'],
          transaction,
        );
        for (final rowId in trackedRowIds) {
          final values = ownerValues[rowId];
          domainOwners[(tableName, rowId)] = values == null
              ? (exists: false, scopeId: null)
              : (exists: true, scopeId: values['scopeId'] as int?);
        }
      }

      final columnNames = columnNamesByTable[tableName];
      if (columnNames == null || columnNames.isEmpty || loadedRows.isEmpty) continue;

      final rowPks = loadedRows.map((row) => row.id).whereType<int>().toSet();
      if (rowPks.length != loadedRows.length) {
        throw StateError(
          'Some merge metadata rows for table $tableName are missing '
          'persisted identifiers.',
        );
      }

      final columnIdsByName = _context.schemaColumnIds(tableName, columnNames);
      if (columnIdsByName.isEmpty) continue;

      final loadedFields = await CrdtDataField.db.find(
        _session,
        where: (t) =>
            t.rowId.inSet(rowPks) & t.columnId.inSet(columnIdsByName.values.toSet()),
        include: CrdtDataField.include(
          column: CrdtSchemaColumn.include(),
          node: CrdtNode.include(),
        ),
        transaction: transaction,
      );

      for (final field in loadedFields) {
        final row = loadedRows.firstWhere((loadedRow) => loadedRow.id == field.rowId);
        fields[(tableName, row.uuidRowId, field.column!.name)] = field;
      }
    }

    return (
      rows: rows,
      fields: fields,
      incomingFieldHlcs: incomingFieldHlcs,
      tombstones: tombstones,
      domainOwners: domainOwners,
    );
  }

  /// Plans every insert in the batch in one projection pass.
  ///
  /// The physical write of each insert has to be constraint safe before it
  /// runs, but that plan does not have to be recomputed per insert: one pass
  /// over all of them resolves the batch's claims against each other and
  /// against stored rows. The end-of-batch pass remains authoritative for what
  /// is finally materialized.
  Future<({ProjectionPlan? plan, List<PendingProjectionRow> pending})>
  _planBatchInserts(
    List<CrdtMergeChange> operations,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    Set<String> seedTables,
    Set<MergeRowKey> seedRows,
    Transaction transaction,
  ) async {
    final pending = <PendingProjectionRow>[];
    final seenRowKeys = <MergeRowKey>{};

    for (final operation in operations) {
      // An update or a delete only seeds the pass. Operations are causally
      // ordered, so an update newer than its insert is applied after it, and
      // the end-of-batch pass is what resolves the value it claims.
      if (operation is! CrdtMergeInsert) continue;
      if (!_context.isCrdtTrackedTableName(operation.tableName)) continue;

      // Only rows this merge will create need a pre-write plan, and only the
      // first insert for a row id takes that path.
      final rowKey = (operation.tableName, operation.uuidRowId);
      if (context.rows[rowKey] != null) continue;
      if (!seenRowKeys.add(rowKey)) continue;
      pending.add((
        tableName: operation.tableName,
        rowId: operation.uuidRowId,
        authoredValues: _sanitizeMergeRowData(
          operation.tableName,
          operation.databaseColumns,
        ),
        rowHlc: operation.hlc,
        node: _requireRemoteNode(remoteNodes, operation.uuidNodeId),
        hidden: false,
      ));
    }
    if (pending.isEmpty) return (plan: null, pending: pending);

    return (
      plan: await _foreignKeyProjector.project(
        transaction,
        pendingInserts: pending,
        seedTables: seedTables,
        seedRows: seedRows,
      ),
      pending: pending,
    );
  }

  Future<void> _applyMergeInsert(
    CrdtMergeInsert insert,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    Map<MergeFieldKey, Object?> authoredOverlays,
    ProjectionPlan? batchPlan,
    _PendingInsertAttempts pendingAttempts,
    CrdtForeignKeyPresenceCache? presence,
    Transaction transaction,
  ) async {
    final rowKey = (insert.tableName, insert.uuidRowId);
    final incomingHlc = insert.hlc;
    final remoteNode = _requireRemoteNode(remoteNodes, insert.uuidNodeId);

    final currentRow = context.rows[rowKey];
    if (currentRow != null && incomingHlc <= currentRow.hlc) {
      return;
    }

    // Set inside the savepoint and read after it, so a rolled back insert
    // records nothing.
    ProjectionAttemptsByField? pendingWrites;

    final data = _sanitizeMergeRowData(insert.tableName, insert.databaseColumns);

    if (currentRow == null) {
      final mergingScope = _context.effectiveScopeFor(transaction);
      final mergingScopeId = mergingScope.id!;
      try {
        // Insert-first inside a savepoint: the domain primary key resolves
        // creation races atomically, and `_applyMergeInsertForMissingRow`
        // raises `_ForeignScopeRowCollision` when the row turns out to be owned
        // by another scope. Rolling the savepoint back then leaves no CRDT
        // metadata, released unique values, or foreign key attempts behind.
        context.rows[rowKey] = await DatabaseUtil.runInTransactionOrSavepoint(
          _db,
          transaction,
          (savepoint) async {
            final planned = await _planMergeInsertValues(
              insert,
              data,
              batchPlan,
              presence,
              savepoint,
            );
            final insertedRow = await _applyMergeInsertForMissingRow(
              insert,
              remoteNode,
              incomingHlc,
              planned.domain,
              savepoint,
            );
            pendingWrites = planned.attempts;
            return insertedRow;
          },
        );
        // The row is now owned by the merging scope (freshly inserted, or a
        // same-scope recovery), so same-merge field updates resolve ownership
        // from the cache instead of re-reading the domain row.
        context.domainOwners[rowKey] = (exists: true, scopeId: mergingScopeId);
        pendingAttempts.add(
          tableName: insert.tableName,
          rowId: insert.uuidRowId,
          node: remoteNode,
          attempts: pendingWrites ?? const {},
        );
        // Written and visible, so the children arriving after it in this batch
        // can point at it without asking the database again.
        presence?.markVisible(rowKey);
      } on _ForeignScopeRowCollision catch (collision) {
        await _throwOwnershipCollision(
          operation: CrdtSyncViolationOperation.mergeInsert,
          tableName: insert.tableName,
          rowId: insert.uuidRowId,
          owningScopeId: collision.owningScopeId,
          incomingScope: mergingScope,
          metadataRowId: null,
          node: remoteNode,
          hlc: insert.hlc,
          transaction: transaction,
        );
      }
    } else {
      await _applyMergeInsertForExistingRow(
        insert,
        currentRow,
        remoteNode,
        incomingHlc,
        data,
        context,
        authoredOverlays,
        transaction,
      );
      // This one can resurrect a tombstoned row, so drop what was known.
      presence?.forget(rowKey);
    }
  }

  /// The domain values a merged insert can physically write, paired with the
  /// authored values projection displaced.
  ///
  /// The batch plan already resolved this row's claims against the rest of the
  /// batch. Foreign key safety is folded in after it, so where safety forces a
  /// null it is also the terminal cause for that column.
  Future<({Map<String, Object?> domain, ProjectionAttemptsByField attempts})>
  _planMergeInsertValues(
    CrdtMergeInsert insert,
    Map<String, Object?> data,
    ProjectionPlan? batchPlan,
    CrdtForeignKeyPresenceCache? presence,
    Transaction transaction,
  ) async {
    final fkSafe = await _foreignKeyProjector.safeIncomingData(
      insert.tableName,
      insert.uuidRowId,
      data,
      transaction,
      presence: presence,
    );
    final forcedNullColumns = {
      for (final MapEntry(key: columnName, value: value) in fkSafe.data.entries)
        if (value == null) columnName,
    };
    final plannedDomain = {
      ...data,
      ...?batchPlan?.domain[(insert.tableName, insert.uuidRowId)],
      for (final columnName in forcedNullColumns) columnName: null,
    };

    final attempts = <MergeFieldKey, ProjectionAttempt>{};
    for (final MapEntry(key: columnName, value: authored) in data.entries) {
      if (projectionValuesEqual(plannedDomain[columnName], authored)) continue;

      final fieldKey = (insert.tableName, insert.uuidRowId, columnName);
      final planReason = batchPlan?.reasons[fieldKey];
      final foreignKeyReason = fkSafe.attempts[fieldKey]?.reason;
      final reason = forcedNullColumns.contains(columnName)
          ? foreignKeyReason ?? planReason
          : planReason ?? foreignKeyReason;
      if (reason == null) {
        throw StateError(
          'Projection changed ${insert.tableName}.$columnName on row '
          '${insert.uuidRowId} without recording why.',
        );
      }
      attempts[fieldKey] = (value: authored, reason: reason);
    }

    return (domain: plannedDomain, attempts: attempts);
  }

  /// Writes the field metadata collected for merged inserts, one call per
  /// table and node.
  ///
  /// Grouped by node because the merge cache pairs every field it stores with
  /// the node that authored it, which is how the cached field resolves its own
  /// clock.
  Future<void> _flushInsertAttempts(
    _PendingInsertAttempts pending,
    MergeContext context,
    Transaction transaction,
  ) async {
    if (pending.isEmpty) return;

    final groups = pending.take();
    for (final group in groups) {
      await _foreignKeyProjector.recordInsertAttempts(
        group.tableName,
        group.rowIds,
        transaction,
        group.attempts,
        mergeCache: (fields: context.fields, node: group.node),
      );
    }
  }

  Future<void> _applyMergeUpdate(
    CrdtMergeUpdate update,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    Map<MergeFieldKey, Object?> authoredOverlays,
    Transaction transaction,
  ) async {
    final rowKey = (update.tableName, update.uuidRowId);
    final row = context.rows[rowKey];
    if (row == null) return;
    final remoteNode = _requireRemoteNode(remoteNodes, update.uuidNodeId);
    if (!await _domainRowOwnedByEffectiveScope(
      operation: CrdtSyncViolationOperation.mergeUpdate,
      tableName: update.tableName,
      rowId: update.uuidRowId,
      context: context,
      transaction: transaction,
      metadataRowId: row.id,
      node: remoteNode,
      hlc: update.hlc,
    )) {
      return;
    }

    final shouldApply = await _shouldMergeFieldMetadataIfNewer(
      tableName: update.tableName,
      rowId: update.uuidRowId,
      columnName: update.columnName,
      row: row,
      remoteNode: remoteNode,
      incomingHlc: update.hlc,
      fields: context.fields,
      transaction: transaction,
    );

    if (!shouldApply) return;

    authoredOverlays[(update.tableName, update.uuidRowId, update.columnName)] =
        update.value;
  }

  Future<void> _applyMergeDelete(
    CrdtMergeDelete delete,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    Transaction transaction,
  ) async {
    final rowKey = (delete.tableName, delete.uuidRowId);
    final row = context.rows[rowKey];
    if (row == null) return;
    if (!delete.reason.isSynced) return;
    final remoteNode = _requireRemoteNode(remoteNodes, delete.uuidNodeId);
    if (!await _domainRowOwnedByEffectiveScope(
      operation: CrdtSyncViolationOperation.mergeDelete,
      tableName: delete.tableName,
      rowId: delete.uuidRowId,
      context: context,
      transaction: transaction,
      metadataRowId: row.id,
      node: remoteNode,
      hlc: delete.hlc,
    )) {
      return;
    }

    final currentTombstone = context.tombstones[rowKey];
    final currentClFlag = currentTombstone?.clFlag ?? 1;
    final currentHlc = currentTombstone?.hlc ?? row.hlc;
    if (delete.clFlag < currentClFlag) return;
    if (delete.clFlag == currentClFlag && delete.hlc <= currentHlc) return;

    context.tombstones[rowKey] = await _upsertMergeTombstone(
      row,
      remoteNode,
      delete.hlc,
      delete.clFlag,
      delete.reason,
      currentTombstone,
      transaction,
    );

    if (delete.reason.isSynced) {
      await _context.applyRowVisibilityFromUserTombstone(
        row,
        context.tombstones[rowKey]!,
        transaction,
      );
    }
  }

  Future<CrdtDataRow> _upsertMergeRow(
    String tableName,
    UuidValue rowId,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    CrdtDataRow? currentRow,
    Transaction transaction,
  ) async {
    if (currentRow == null) {
      final (tableId, _) = _context.schema[tableName]!;
      final insertedRow = await CrdtDataRow.db.insertRow(
        _session,
        CrdtDataRow(
          scopeId: _context.hlcManagerFor(transaction).normalizedScopeId,
          tblId: tableId,
          uuidRowId: rowId,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
        ),
        transaction: transaction,
      );

      return insertedRow.copyWith(node: remoteNode);
    }

    final updatedRow = currentRow.copyWith(
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
    );

    await CrdtDataRow.db.update(
      _session,
      [updatedRow],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );

    return updatedRow;
  }

  Future<CrdtDataField> _upsertMergeField(
    CrdtDataRow row,
    CrdtSchemaColumn column,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    CrdtDataField? currentField,
    Transaction transaction,
  ) async {
    // Projection can create field metadata for a row this merge context loaded
    // before the row existed, so an unseen field may still be persisted. Adopt
    // it instead of inserting a second row onto the row/column unique index.
    final existingField =
        currentField ??
        await CrdtDataField.db.findFirstRow(
          _session,
          where: (t) => t.rowId.equals(row.id) & t.columnId.equals(column.id),
          transaction: transaction,
        );

    if (existingField == null) {
      final insertedField = await CrdtDataField.db.insertRow(
        _session,
        CrdtDataField(
          rowId: row.id!,
          columnId: column.id!,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
        ),
        transaction: transaction,
      );

      return insertedField.copyWith(
        row: row,
        column: column,
        node: remoteNode,
      );
    }

    final updatedField = existingField.copyWith(
      row: row,
      column: column,
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
    );

    await CrdtDataField.db.update(
      _session,
      [updatedField],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
    return updatedField;
  }

  Future<CrdtDataDeleted> _upsertMergeTombstone(
    CrdtDataRow row,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    int clFlag,
    CrdtDataDeletedReason reason,
    CrdtDataDeleted? currentTombstone,
    Transaction transaction,
  ) async {
    if (currentTombstone == null) {
      final insertedTombstone = await CrdtDataDeleted.db.insertRow(
        _session,
        CrdtDataDeleted(
          rowId: row.id!,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
          clFlag: clFlag,
          reason: reason,
        ),
        transaction: transaction,
      );

      return insertedTombstone.copyWith(
        row: row,
        node: remoteNode,
      );
    }

    final updatedTombstone = currentTombstone.copyWith(
      row: row,
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
      clFlag: clFlag,
      reason: reason,
    );

    await CrdtDataDeleted.db.update(
      _session,
      [updatedTombstone],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter, t.clFlag, t.reason],
      transaction: transaction,
    );

    return updatedTombstone;
  }

  Future<CrdtDataRow> _applyMergeInsertForMissingRow(
    CrdtMergeInsert insert,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    Map<String, Object?> data,
    Transaction transaction,
  ) async {
    final tableRow = _requireMergeInsertTableRow(insert);
    final patchedRow = _withPlannedDomainValues(tableRow, data);
    final mergingScopeId = _context.hlcManagerFor(transaction).normalizedScopeId;
    final scopedRow = patchedRow.copyWithScopeId(mergingScopeId);
    try {
      // Domain insert first. A CRDT tracker row for this id, written before
      // the domain row, made SQLite reject a later null unique-FK insert.
      await DatabaseUtil.runInTransactionOrSavepoint(
        _db,
        transaction,
        (savepoint) => _db.insertRow(scopedRow, transaction: savepoint),
      );
    } on DatabaseQueryException {
      final owner = await _readDomainRowOwner(
        insert.tableName,
        insert.uuidRowId,
        transaction,
      );
      // No row means the violation came from something other than the
      // primary key (e.g. a racing unique value); preserve the failure.
      if (!owner.exists) rethrow;
      if (owner.scopeId != mergingScopeId) {
        throw _ForeignScopeRowCollision(owner.scopeId);
      }

      // Same-scope recovery (a tracked row whose metadata was lost, or a
      // race between this scope's own merges). scopeId is immutable and rows
      // are only soft-deleted, so ownership observed here cannot change for
      // the rest of the transaction and the update is safe.
      await _db.updateRow(
        scopedRow,
        columns: scopedRow.table.managedColumns
            .where((c) => data.containsKey(c.columnName))
            .toList(),
        transaction: transaction,
      );
    }

    return _upsertMergeRow(
      insert.tableName,
      insert.uuidRowId,
      remoteNode,
      incomingHlc,
      null,
      transaction,
    );
  }

  Future<void> _applyMergeInsertForExistingRow(
    CrdtMergeInsert insert,
    CrdtDataRow currentRow,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    Map<String, Object?> data,
    MergeContext context,
    Map<MergeFieldKey, Object?> authoredOverlays,
    Transaction transaction,
  ) async {
    if (!await _domainRowOwnedByEffectiveScope(
      operation: CrdtSyncViolationOperation.mergeInsert,
      tableName: insert.tableName,
      rowId: insert.uuidRowId,
      context: context,
      transaction: transaction,
      metadataRowId: currentRow.id,
      node: remoteNode,
      hlc: insert.hlc,
    )) {
      return;
    }

    final (_, columnsByName) = _context.schema[insert.tableName]!;
    for (final MapEntry(key: columnName, value: schemaColumn)
        in columnsByName.entries) {
      if (columnName == 'id') continue;

      final shouldApply = await _shouldMergeFieldMetadataIfNewer(
        tableName: insert.tableName,
        rowId: insert.uuidRowId,
        columnName: columnName,
        row: currentRow,
        remoteNode: remoteNode,
        incomingHlc: incomingHlc,
        fields: context.fields,
        transaction: transaction,
        schemaColumn: schemaColumn,
      );

      if (!shouldApply) continue;
      authoredOverlays[(insert.tableName, insert.uuidRowId, columnName)] =
          data[columnName];
    }

    final rowKey = (insert.tableName, insert.uuidRowId);
    final currentTombstone = context.tombstones[rowKey];
    if ((currentTombstone?.clFlag ?? 1) == 1 &&
        incomingHlc > (currentTombstone?.hlc ?? currentRow.hlc)) {
      context.tombstones[rowKey] = await _upsertMergeTombstone(
        currentRow,
        remoteNode,
        incomingHlc,
        1,
        CrdtDataDeletedReason.userInsert,
        currentTombstone,
        transaction,
      );
      await _context.applyRowVisibilityFromUserTombstone(
        currentRow,
        context.tombstones[rowKey]!,
        transaction,
      );
    }
  }

  Future<bool> _shouldMergeFieldMetadataIfNewer({
    required String tableName,
    required UuidValue rowId,
    required String columnName,
    required CrdtDataRow row,
    required CrdtNode remoteNode,
    required Hlc incomingHlc,
    required Map<MergeFieldKey, CrdtDataField> fields,
    required Transaction transaction,
    CrdtSchemaColumn? schemaColumn,
  }) async {
    final resolvedSchemaColumn =
        schemaColumn ?? _context.schemaColumn(tableName, columnName);
    if (resolvedSchemaColumn == null) return false;

    final fieldKey = (tableName, rowId, columnName);
    final currentField = fields[fieldKey];
    final currentHlc = currentField?.hlc ?? row.hlc;
    if (incomingHlc <= currentHlc) return false;

    fields[fieldKey] = await _upsertMergeField(
      row,
      resolvedSchemaColumn,
      remoteNode,
      incomingHlc,
      currentField,
      transaction,
    );
    return true;
  }

  TableRow _requireMergeInsertTableRow(CrdtMergeInsert insert) {
    final row = insert.data;
    if (row is TableRow) return row;

    throw StateError(
      'Unsupported merge insert payload type for "${insert.tableName}": '
      '${row.runtimeType}. Expected subclass of TableRow.',
    );
  }

  CrdtNode _requireRemoteNode(
    Map<UuidValue, CrdtNode> remoteNodes,
    UuidValue uuidNodeId,
  ) {
    return remoteNodes[uuidNodeId] ??
        (throw StateError(
          'Remote node $uuidNodeId not found for merge.',
        ));
  }

  Map<String, Object?> _sanitizeMergeRowData(
    String tableName,
    Map<String, Object?> data,
  ) {
    final columns = _context.columnsByTableAndName[tableName];
    if (columns == null) return {};

    return {
      for (final MapEntry(key: columnName, value: value) in data.entries)
        if (columnName != 'id' &&
            columnName != 'scopeId' &&
            columns.containsKey(columnName))
          columnName: columns[columnName]!.columnType == ColumnType.uuid
              ? value.toUuidValue()
              : value,
    };
  }

  Future<DomainRowOwner> _readDomainRowOwner(
    String tableName,
    UuidValue rowId,
    Transaction transaction,
  ) async {
    final values = await _context.readDomainColumnValues(
      tableName,
      {rowId},
      ['scopeId'],
      transaction,
    );
    final row = values[rowId];
    if (row == null) return (exists: false, scopeId: null);
    return (exists: true, scopeId: row['scopeId'] as int?);
  }

  /// Returns the owning scope of [rowId] from the merge snapshot taken in
  /// [_loadMergeContext], reading the domain row only if it was not captured
  /// there (e.g. a row a concurrent operation added since the snapshot).
  Future<DomainRowOwner> _resolveDomainOwner(
    MergeContext context,
    String tableName,
    UuidValue rowId,
    Transaction transaction,
  ) async {
    final key = (tableName, rowId);
    final cached = context.domainOwners[key];
    if (cached != null) return cached;
    final owner = await _readDomainRowOwner(tableName, rowId, transaction);
    context.domainOwners[key] = owner;
    return owner;
  }

  Future<bool> _domainRowOwnedByEffectiveScope({
    required CrdtSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required MergeContext context,
    required Transaction transaction,
    int? metadataRowId,
    CrdtNode? node,
    Hlc? hlc,
  }) async {
    final owner = await _resolveDomainOwner(context, tableName, rowId, transaction);
    final mergingScope = _context.effectiveScopeFor(transaction);
    if (owner.exists && owner.scopeId == mergingScope.id) return true;
    if (!owner.exists) return false;

    await _throwOwnershipCollision(
      operation: operation,
      tableName: tableName,
      rowId: rowId,
      owningScopeId: owner.scopeId,
      incomingScope: mergingScope,
      metadataRowId: metadataRowId,
      node: node,
      hlc: hlc,
      transaction: transaction,
    );
  }

  Future<Never> _throwOwnershipCollision({
    required CrdtSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required int? owningScopeId,
    required CrdtScope incomingScope,
    required int? metadataRowId,
    required Transaction transaction,
    CrdtNode? node,
    Hlc? hlc,
  }) async {
    final now = clock.now().toUtc();
    throw CrdtSyncIntegrityViolationException(
      CrdtSyncIntegrityViolation(
        type: CrdtSyncViolationType.ownershipCollision,
        domainTableName: tableName,
        uuidRowId: rowId,
        ownerScopeUuid: await _scopeUuidForNormalizedId(owningScopeId, transaction),
        incomingScopeUuid: incomingScope.uuidScopeId,
        operation: operation,
        uuidNodeId: node?.uuidNodeId,
        crdtDataRowId: metadataRowId,
        hlcDatetime: hlc?.datetime,
        hlcCounter: hlc?.counter,
        firstSeenAt: now,
        lastSeenAt: now,
        occurrences: 1,
      ),
    );
  }

  Future<UuidValue?> _scopeUuidForNormalizedId(
    int? scopeId,
    Transaction transaction,
  ) async {
    if (scopeId == null) return null;

    final scope = await CrdtScope.db.findById(
      _session,
      scopeId,
      transaction: transaction,
    );
    return scope?.uuidScopeId;
  }
}

/// Signals that a merge insert lost a primary-key race to a row owned by
/// another scope, so the savepoint around the insert application must be
/// rolled back before the sync violation is recorded and thrown.
class _ForeignScopeRowCollision implements Exception {
  _ForeignScopeRowCollision(this.owningScopeId);

  final int? owningScopeId;
}
