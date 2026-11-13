part of 'recorder.dart';

/// Adds merge-specific behavior to [CrdtMutationRecorder].
extension CrdtMergeRecorderExtension on CrdtMutationRecorder {
  /// Merges remote CRDT changes into the current database.
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet,
    Transaction transaction, {
    int? receivedRevision,
  }) async {
    if (mergeSet.isEmpty) {
      await _context.persistMergeProgress(
        const [],
        transaction,
        receivedRevision: receivedRevision,
      );
      return;
    }

    OfflineSyncDiagnostics.event('merge.phase', {'phase': 'validateIncoming'});
    final operations = mergeSet.causallyOrderedChanges;
    // Validate remote facts before touching rows or progress, including stale
    // and repeated deliveries. Generated alternatives are never authored facts.
    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName) ||
          !_uniqueResolver.hasReservedUniqueColumns(operation.tableName)) {
        continue;
      }
      switch (operation) {
        case CrdtMergeInsert():
          for (final MapEntry(key: column, value: value)
              in operation.databaseColumns.entries) {
            _uniqueResolver.validateAuthoredValue(operation.tableName, column, value);
          }
        case CrdtMergeUpdate():
          _uniqueResolver.validateAuthoredValue(
            operation.tableName,
            operation.columnName,
            operation.value,
          );
        case CrdtMergeDelete():
          break;
      }
    }
    // Nothing in this batch touches a foreign key or a unique index, so no
    // projection decision can change: skip both passes instead of loading
    // state for tables that cannot produce a candidate or a conflict.
    final mayAffectProjection = _foreignKeyProjector.mergeOperationsMayAffectProjection(
      operations,
    );
    final authoredOverlays = <MergeFieldKey, Object?>{};
    OfflineSyncDiagnostics.event('merge.phase', {
      'phase': 'readNodesAndConflictMetadata',
    });
    final remoteNodes = await _findOrCreateNodesForMerge(
      _context.spaceIdFor(transaction),
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

    OfflineSyncDiagnostics.event('merge.phase', {
      'phase': 'planConflictsAndReferences',
    });
    final needsProjectionPass =
        mayAffectProjection &&
        !await _canLeaveMergeProjectionUnchanged(operations, context, transaction);
    final projectionReads = needsProjectionPass
        ? _foreignKeyProjector.createReadCache(transaction)
        : null;
    final batch = await _planBatchInserts(
      operations,
      nodesByUuid,
      context,
      touchedTables,
      touchedRows,
      transaction,
      projectionReads,
      projectInserts: needsProjectionPass,
    );
    // Every merged insert has to know whether the rows its foreign keys name
    // are there, which is one query per edge unless the batch resolves them
    // together and then keeps the answers current as it writes.
    final presence = batch.pending.isEmpty
        ? null
        : await _foreignKeyProjector.resolvePresenceForInserts(
            batch.pending,
            transaction,
          );

    final writes = _MergeWriteBatch(
      session: _session,
      projector: _foreignKeyProjector,
      rows: context.rows,
      fields: context.fields,
      transaction: transaction,
    );
    final deferredDeletes = <CrdtMergeDelete>[];

    OfflineSyncDiagnostics.event('merge.phase', {
      'phase': 'writeRowsAndChangeMetadata',
    });
    projectionReads?.invalidateRows(touchedRows);
    await writes.apply(
      operations.where(
        (operation) => _context.isCrdtTrackedTableName(operation.tableName),
      ),
      (operation) async {
        switch (operation) {
          case final CrdtMergeInsert insert:
            await _applyMergeInsert(
              insert,
              nodesByUuid,
              context,
              authoredOverlays,
              batch.plan,
              writes,
              presence,
              transaction,
            );
          case final CrdtMergeUpdate update:
            await _applyMergeUpdate(
              update,
              nodesByUuid,
              context,
              authoredOverlays,
              writes,
              transaction,
            );
          case final CrdtMergeDelete delete:
            // A higher delete/restore generation can have an older HLC than a
            // concurrent reinsertion. Bootstrap must retain it until this batch
            // has inserted the row it belongs to.
            if (!context.rows.containsKey((delete.tableName, delete.uuidRowId))) {
              deferredDeletes.add(delete);
              return;
            }
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
      },
      canBatchInsert: (insert) => _canBatchMergeInsert(insert, context),
      applyInserts: (inserts) => _applyMergeInsertsForMissingRows(
        inserts,
        nodesByUuid,
        context,
        batch.plan,
        writes,
        presence,
        transaction,
      ),
    );

    for (final delete in deferredDeletes) {
      await _applyMergeDelete(delete, nodesByUuid, context, transaction);
    }

    OfflineSyncDiagnostics.event('merge.phase', {'phase': 'projectConflicts'});
    if (needsProjectionPass) {
      await _foreignKeyProjector.project(
        transaction,
        authoredOverlays: authoredOverlays,
        seedTables: touchedTables,
        seedRows: touchedRows,
        readCache: projectionReads,
      );
    } else {
      // The pass is also what writes an update's value, so its authored
      // values still have to land when it is skipped.
      await _foreignKeyProjector.writeAuthoredValues(
        authoredOverlays,
        transaction,
      );
    }
    OfflineSyncDiagnostics.event('merge.phase', {'phase': 'writeReceivedCursors'});
    await _updateHlcFromIncomingOperations(
      operations,
      remoteNodes,
      transaction,
      receivedRevision: receivedRevision,
    );
  }

  /// The local insert proof also applies to new merge rows when no other
  /// operation can change a projection dependency. It checks live parents,
  /// existing children, attempted references and default targets in the same
  /// locked transaction. Reinserts, deletes and constrained edits retain both
  /// projection passes. Unique-bearing tables are deliberately excluded.
  Future<bool> _canLeaveMergeProjectionUnchanged(
    List<CrdtMergeChange> operations,
    MergeContext context,
    Transaction transaction,
  ) async {
    final insertsByTable = <String, List<TableRow>>{};
    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName)) continue;

      switch (operation) {
        case CrdtMergeInsert():
          if (context.rows.containsKey((operation.tableName, operation.uuidRowId)) ||
              _uniqueResolver.tableHasUniqueIndexes(operation.tableName)) {
            return false;
          }
          (insertsByTable[operation.tableName] ??= []).add(
            _requireMergeInsertTableRow(operation),
          );
        case CrdtMergeUpdate():
          if (_foreignKeyProjector.needsProjection(operation.tableName, {
            operation.columnName,
          })) {
            return false;
          }
        case CrdtMergeDelete():
          return false;
      }
    }
    if (insertsByTable.isEmpty) return false;

    for (final rows in insertsByTable.values) {
      if (!await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
        rows,
        transaction,
        inserting: true,
        persisted: false,
      )) {
        return false;
      }
    }
    return true;
  }

  Future<void> _updateHlcFromIncomingOperations(
    List<CrdtMergeChange> operations,
    MergeNodes remoteNodes,
    Transaction transaction, {
    int? receivedRevision,
  }) async {
    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) => change.hlc.maxBetween(current),
    );
    final spaceNodesToUpdate = <OfflineSyncSpaceNode>[];

    if (maxIncomingHlc != null) {
      // Incoming facts keep their source node and advance the applying clock.
      final hlcManager = _context.hlcManagerFor(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        hlcManager.observe(maxIncomingHlc);
      } else {
        hlcManager.merge(maxIncomingHlc);
      }
    }

    final maxIncomingHlcByNode = <UuidValue, Hlc>{};
    for (final operation in operations) {
      maxIncomingHlcByNode[operation.uuidNodeId] = operation.hlc.maxBetween(
        maxIncomingHlcByNode[operation.uuidNodeId],
      );
    }

    for (final MapEntry(key: nodeId, value: incomingHlc)
        in maxIncomingHlcByNode.entries) {
      final remoteNode = remoteNodes.spaceNodesByUuid[nodeId];
      if (remoteNode == null) continue;
      final previous = remoteNode.lastReceivedHlc;
      final updatedSpaceNode = remoteNode.copyWith(
        lastReceivedHlc: incomingHlc.maxBetween(
          previous?.nodeId == nodeId ? previous : null,
        ),
      );
      if (updatedSpaceNode.lastReceivedHlc == remoteNode.lastReceivedHlc) {
        continue;
      }

      spaceNodesToUpdate.add(updatedSpaceNode);
      remoteNodes.spaceNodesByUuid[nodeId] = updatedSpaceNode;
    }

    await _context.persistMergeProgress(
      spaceNodesToUpdate,
      transaction,
      receivedRevision: receivedRevision,
    );
  }

  Future<MergeNodes> _findOrCreateNodesForMerge(
    int spaceId,
    Set<UuidValue> nodeIds,
    Transaction transaction,
  ) async {
    if (nodeIds.isEmpty) {
      return (
        nodesByUuid: const <UuidValue, CrdtNode>{},
        spaceNodesByUuid: const <UuidValue, OfflineSyncSpaceNode>{},
      );
    }

    // `mergeChanges` committed these already; a missing one is created in UUID
    // order, so concurrent merges cannot deadlock on it.
    final nodesByUuid = {
      for (final uuidNodeId
          in nodeIds.toList()..sort((a, b) => a.uuid.compareTo(b.uuid)))
        uuidNodeId: await _context.findOrCreateNode(uuidNodeId, transaction),
    };

    final spaceNodesByUuid = {
      for (final entry in nodesByUuid.entries)
        entry.key: await _context.findOrCreateSpaceNode(
          spaceId,
          entry.value.id!,
          transaction,
        ),
    };

    return (
      nodesByUuid: nodesByUuid,
      spaceNodesByUuid: spaceNodesByUuid,
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
    // Owning space per row, snapshotted once so the per-operation ownership
    // checks never re-read the same immutable `spaceId`. Only rows that
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
          ['spaceId'],
          transaction,
        );
        for (final rowId in trackedRowIds) {
          final values = ownerValues[rowId];
          domainOwners[(tableName, rowId)] = values == null
              ? (exists: false, spaceId: null)
              : (exists: true, spaceId: values['spaceId'] as int?);
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
    CrdtProjectionReadCache? projectionReads, {
    required bool projectInserts,
  }) async {
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
    if (pending.isEmpty || !projectInserts) return (plan: null, pending: pending);

    return (
      plan: await _foreignKeyProjector.project(
        transaction,
        pendingInserts: pending,
        seedTables: seedTables,
        seedRows: seedRows,
        readCache: projectionReads,
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
    _MergeWriteBatch writes,
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

    final data = _sanitizeMergeRowData(insert.tableName, insert.databaseColumns);

    if (currentRow == null) {
      await _applyMergeInsertsForMissingRows(
        [insert],
        remoteNodes,
        context,
        batchPlan,
        writes,
        presence,
        transaction,
      );
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

  Future<void> _applyMergeUpdate(
    CrdtMergeUpdate update,
    Map<UuidValue, CrdtNode> remoteNodes,
    MergeContext context,
    Map<MergeFieldKey, Object?> authoredOverlays,
    _MergeWriteBatch writes,
    Transaction transaction,
  ) async {
    final rowKey = (update.tableName, update.uuidRowId);
    final row = context.rows[rowKey];
    if (row == null) return;
    final remoteNode = _requireRemoteNode(remoteNodes, update.uuidNodeId);
    if (!await _domainRowOwnedByEffectiveSpace(
      operation: OfflineSyncViolationOperation.mergeUpdate,
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
      writes: writes,
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
    if (!await _domainRowOwnedByEffectiveSpace(
      operation: OfflineSyncViolationOperation.mergeDelete,
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

  Future<CrdtDataField> _upsertMergeField(
    CrdtDataRow row,
    CrdtSchemaColumn column,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    CrdtDataField? currentField,
    Transaction transaction, {
    _MergeWriteBatch? writes,
  }) async {
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
      // Dependent metadata needs the field identity, so new fields cannot
      // wait in the batch of existing field-clock updates.
      final insertedField = await CrdtDataField.db.insertRow(
        _session,
        CrdtDataField(
          spaceId: row.spaceId,
          syncRevision: _context.revisionFor(transaction),
          sourcePeerId: _context.sourcePeerIdFor(transaction),
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
      syncRevision: _context.revisionFor(transaction),
      sourcePeerId: _context.sourcePeerIdFor(transaction),
      row: row,
      column: column,
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
    );

    if (writes != null) {
      writes.recordFieldUpdate(updatedField);
    } else {
      await CrdtDataField.db.update(
        _session,
        [updatedField],
        columns: (t) => [
          t.nodeId,
          t.hlcDatetime,
          t.hlcCounter,
          t.syncRevision,
          t.sourcePeerId,
        ],
        transaction: transaction,
      );
    }
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
          spaceId: row.spaceId,
          syncRevision: _context.revisionFor(transaction),
          sourcePeerId: _context.sourcePeerIdFor(transaction),
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
      syncRevision: _context.revisionFor(transaction),
      sourcePeerId: _context.sourcePeerIdFor(transaction),
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
      columns: (t) => [
        t.nodeId,
        t.hlcDatetime,
        t.hlcCounter,
        t.clFlag,
        t.reason,
        t.syncRevision,
        t.sourcePeerId,
      ],
      transaction: transaction,
    );

    return updatedTombstone;
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
    if (!await _domainRowOwnedByEffectiveSpace(
      operation: OfflineSyncViolationOperation.mergeInsert,
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
    _MergeWriteBatch? writes,
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
      writes: writes,
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
            columnName != 'spaceId' &&
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
      ['spaceId'],
      transaction,
    );
    final row = values[rowId];
    if (row == null) return (exists: false, spaceId: null);
    return (exists: true, spaceId: row['spaceId'] as int?);
  }

  /// Returns the owning space of [rowId] from the merge snapshot taken in
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

  Future<bool> _domainRowOwnedByEffectiveSpace({
    required OfflineSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required MergeContext context,
    required Transaction transaction,
    int? metadataRowId,
    CrdtNode? node,
    Hlc? hlc,
  }) async {
    final owner = await _resolveDomainOwner(context, tableName, rowId, transaction);
    final mergingSpace = _context.effectiveSpaceFor(transaction);
    if (owner.exists && owner.spaceId == mergingSpace.id) return true;
    if (!owner.exists) return false;

    await _throwOwnershipCollision(
      operation: operation,
      tableName: tableName,
      rowId: rowId,
      owningSpaceId: owner.spaceId,
      incomingSpace: mergingSpace,
      metadataRowId: metadataRowId,
      node: node,
      hlc: hlc,
      transaction: transaction,
    );
  }

  Future<Never> _throwOwnershipCollision({
    required OfflineSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required int? owningSpaceId,
    required OfflineSyncSpace incomingSpace,
    required int? metadataRowId,
    required Transaction transaction,
    CrdtNode? node,
    Hlc? hlc,
  }) async {
    final now = clock.now().toUtc();
    throw OfflineSyncIntegrityViolationException(
      OfflineSyncIntegrityViolation(
        type: OfflineSyncViolationType.ownershipCollision,
        domainTableName: tableName,
        uuidRowId: rowId,
        ownerSpaceUuid: await _spaceUuidForNormalizedId(owningSpaceId, transaction),
        incomingSpaceUuid: incomingSpace.uuidSpaceId,
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

  Future<UuidValue?> _spaceUuidForNormalizedId(
    int? spaceId,
    Transaction transaction,
  ) async {
    if (spaceId == null) return null;

    final space = await OfflineSyncSpace.db.findById(
      _session,
      spaceId,
      transaction: transaction,
    );
    return space?.uuidSpaceId;
  }
}
