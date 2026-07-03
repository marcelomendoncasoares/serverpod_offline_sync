part of 'recorder.dart';

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);
typedef _DomainOwner = ({bool exists, int? scopeId});
typedef _MergeContext = ({
  Map<_MergeRowKey, CrdtDataRow> rows,
  Map<_MergeFieldKey, CrdtDataField> fields,
  Map<_MergeFieldKey, Hlc> incomingFieldHlcs,
  Map<_MergeRowKey, CrdtDataDeleted> tombstones,
  Map<_MergeRowKey, _DomainOwner> domainOwners,
});
typedef _MergeNodes = ({
  Map<UuidValue, CrdtNode> nodesByUuid,
  Map<UuidValue, CrdtScopeNode> scopeNodesByUuid,
});

/// Adds merge-specific behavior to [CrdtMutationRecorder].
extension CrdtMergeRecorderExtension on CrdtMutationRecorder {
  CrdtUniqueConflictResolver get _uniqueConflictResolver =>
      CrdtUniqueConflictResolver(this);

  /// Locks the current user row so merges can serialize with other work.
  Future<void> lockCurrentUser(Transaction transaction) async {
    final user = _getEffectiveScope(transaction);
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
    final shouldProjectForeignKeys = _mergeOperationsMayAffectForeignKeys(
      operations,
    );
    final currentUser = _getEffectiveScope(transaction);
    final remoteNodes = await _findOrCreateNodesForMerge(
      currentUser.id!,
      {for (final change in operations) change.uuidNodeId},
      transaction,
    );
    final nodesByUuid = remoteNodes.nodesByUuid;
    final context = await _loadMergeContext(mergeSet, transaction);

    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.tableName)) {
        continue;
      }

      switch (operation) {
        case final CrdtMergeInsert insert:
          await _applyMergeInsert(
            insert,
            nodesByUuid,
            context,
            transaction,
          );
        case final CrdtMergeUpdate update:
          await _applyMergeUpdate(
            update,
            nodesByUuid,
            context,
            transaction,
          );
        case final CrdtMergeDelete delete:
          await _applyMergeDelete(
            delete,
            nodesByUuid,
            context,
            transaction,
          );
      }
    }

    if (shouldProjectForeignKeys) {
      await _projectForeignKeys(transaction);
    }
    await _updateHlcFromIncomingOperations(
      operations,
      remoteNodes,
      transaction,
    );
  }

  Future<void> _updateHlcFromIncomingOperations(
    List<CrdtMergeChange> operations,
    _MergeNodes remoteNodes,
    Transaction transaction,
  ) async {
    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) => change.hlc.maxBetween(current),
    );
    final scopeNodesToUpdate = <CrdtScopeNode>[];

    if (maxIncomingHlc != null) {
      final hlcManager = _getHlcManager(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        if (maxIncomingHlc > hlcManager.lastHlc) {
          hlcManager.lastHlc = maxIncomingHlc;
        }
      } else {
        hlcManager.merge(maxIncomingHlc);
      }

      await _persistCurrentNodeHlc(hlcManager, transaction);
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

  Future<_MergeNodes> _findOrCreateNodesForMerge(
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
        uuidNodeId: await _findOrCreateNode(uuidNodeId, transaction),
    };

    final scopeNodesByUuid = {
      for (final entry in nodesByUuid.entries)
        entry.key: await _findOrCreateScopeNode(
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

  Future<_MergeContext> _loadMergeContext(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    final (:rowIdsByTable, :columnNamesByTable) = mergeSet.collectMetadataLookup(
      columnNamesByTableName: _syncedTableColumnNamesForMerge,
    );

    final rows = <_MergeRowKey, CrdtDataRow>{};
    final fields = <_MergeFieldKey, CrdtDataField>{};
    final incomingFieldHlcs = {
      for (final update in mergeSet.whereType<CrdtMergeUpdate>())
        (update.tableName, update.uuidRowId, update.columnName): update.hlc,
    };
    final tombstones = <_MergeRowKey, CrdtDataDeleted>{};
    // Owning scope per row, snapshotted once so the per-operation ownership
    // checks never re-read the same immutable `scopeId`. Only rows that
    // already have a tracker are pre-read here — those are exactly the rows
    // whose ownership the update/delete/existing-insert paths verify. New
    // rows go through the insert path, which proves ownership at the physical
    // write and refreshes this entry afterwards.
    final domainOwners = <_MergeRowKey, _DomainOwner>{};

    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final loadedRows = await _findCrdtRows(
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
        final ownerValues = await _readDomainColumnValues(
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

      final columnIdsByName = _schemaColumnIds(_schema, tableName, columnNames);
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

  Future<void> _applyMergeInsert(
    CrdtMergeInsert insert,
    Map<UuidValue, CrdtNode> remoteNodes,
    _MergeContext context,
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
      final mergingScope = _getEffectiveScope(transaction);
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
            final resolvedInsert = await _uniqueConflictResolver
                ._resolveForIncomingInsert(insert, data, context, savepoint);

            final safeInsert = await _safeIncomingForeignKeyData(
              insert.tableName,
              insert.uuidRowId,
              resolvedInsert.data,
              savepoint,
            );

            final insertedRow = await _applyMergeInsertForMissingRow(
              insert,
              remoteNode,
              incomingHlc,
              safeInsert.data,
              savepoint,
            );
            await _recordForeignKeyInsertAttempts(
              insert.tableName,
              {insert.uuidRowId},
              savepoint,
              safeInsert.attempts,
            );
            return insertedRow;
          },
        );
        // The row is now owned by the merging scope (freshly inserted, or a
        // same-scope recovery), so same-merge field updates resolve ownership
        // from the cache instead of re-reading the domain row.
        context.domainOwners[rowKey] = (exists: true, scopeId: mergingScopeId);
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
        transaction,
      );
    }
  }

  Future<void> _applyMergeUpdate(
    CrdtMergeUpdate update,
    Map<UuidValue, CrdtNode> remoteNodes,
    _MergeContext context,
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

    final resolvedUpdates = await _uniqueConflictResolver._resolveForIncomingUpdate(
      update,
      row,
      context,
      transaction,
    );
    final safeUpdate = await _safeIncomingForeignKeyData(
      update.tableName,
      update.uuidRowId,
      resolvedUpdates,
      transaction,
    );
    await _updateDomainRows(
      update.tableName,
      {update.uuidRowId},
      safeUpdate.data,
      transaction,
    );
    await _recordForeignKeyAttemptsForRows(
      update.tableName,
      {update.uuidRowId},
      resolvedUpdates.keys.toSet(),
      transaction,
      attemptedValues: safeUpdate.attempts,
    );
  }

  Future<void> _applyMergeDelete(
    CrdtMergeDelete delete,
    Map<UuidValue, CrdtNode> remoteNodes,
    _MergeContext context,
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
      await _applyRowVisibilityFromUserTombstone(
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
      final (tableId, _) = _schema[tableName]!;
      final insertedRow = await CrdtDataRow.db.insertRow(
        _session,
        CrdtDataRow(
          scopeId: _getHlcManager(transaction).normalizedScopeId,
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
    if (currentField == null) {
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

    final updatedField = currentField.copyWith(
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
    final insertedCrdtRow = await _upsertMergeRow(
      insert.tableName,
      insert.uuidRowId,
      remoteNode,
      incomingHlc,
      null,
      transaction,
    );

    final tableRow = _requireMergeInsertTableRow(insert);
    final patchedRow = _db.serializationManager.patchTableRow(tableRow, data);
    final mergingScopeId = _getHlcManager(transaction).normalizedScopeId;
    final scopedRow = _withScopeId(patchedRow, mergingScopeId);
    try {
      // Insert first: the domain primary key resolves creation races
      // atomically. The inner savepoint keeps a violation from poisoning the
      // surrounding transaction so the recovery update below can still run.
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

    return insertedCrdtRow;
  }

  Future<void> _applyMergeInsertForExistingRow(
    CrdtMergeInsert insert,
    CrdtDataRow currentRow,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    Map<String, Object?> data,
    _MergeContext context,
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

    final (_, columnsByName) = _schema[insert.tableName]!;
    final updatedValues = <String, Object?>{};
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
      updatedValues[columnName] = data[columnName];
    }

    var updatesToApply = updatedValues;
    if (updatesToApply.isNotEmpty) {
      updatesToApply = await _uniqueConflictResolver._resolveForIncomingUpdates(
        tableName: insert.tableName,
        row: currentRow,
        updates: updatesToApply,
        context: context,
        transaction: transaction,
      );
    }

    if (updatesToApply.isNotEmpty) {
      final safeUpdate = await _safeIncomingForeignKeyData(
        insert.tableName,
        insert.uuidRowId,
        updatesToApply,
        transaction,
      );
      await _updateDomainRows(
        insert.tableName,
        {insert.uuidRowId},
        safeUpdate.data,
        transaction,
      );
      await _recordForeignKeyAttemptsForRows(
        insert.tableName,
        {insert.uuidRowId},
        updatesToApply.keys.toSet(),
        transaction,
        attemptedValues: safeUpdate.attempts,
      );
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
      await _applyRowVisibilityFromUserTombstone(
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
    required Map<_MergeFieldKey, CrdtDataField> fields,
    required Transaction transaction,
    CrdtSchemaColumn? schemaColumn,
  }) async {
    final resolvedSchemaColumn =
        schemaColumn ?? _schemaColumn(_schema, tableName, columnName);
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
    final columns = _context._columnsByTableAndName[tableName];
    if (columns == null) return {};

    return {
      for (final MapEntry(key: columnName, value: value) in data.entries)
        if (columnName != 'id' &&
            columnName != 'scopeId' &&
            columns.containsKey(columnName))
          columnName: columns[columnName]!.columnType == ColumnType.uuid
              ? _uuidValueFromDatabase(value)
              : value,
    };
  }

  Future<({bool exists, int? scopeId})> _readDomainRowOwner(
    String tableName,
    UuidValue rowId,
    Transaction transaction,
  ) async {
    final values = await _readDomainColumnValues(
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
  Future<_DomainOwner> _resolveDomainOwner(
    _MergeContext context,
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
    required _MergeContext context,
    required Transaction transaction,
    int? metadataRowId,
    CrdtNode? node,
    Hlc? hlc,
  }) async {
    final owner = await _resolveDomainOwner(context, tableName, rowId, transaction);
    final mergingScope = _getEffectiveScope(transaction);
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
    final now = DateTime.now().toUtc();
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

  T _withScopeId<T extends TableRow>(T row, int scopeId) {
    return (row as dynamic).copyWith(scopeId: scopeId) as T;
  }
}

/// Signals that a merge insert lost a primary-key race to a row owned by
/// another scope, so the savepoint around the insert application must be
/// rolled back before the sync violation is recorded and thrown.
class _ForeignScopeRowCollision implements Exception {
  _ForeignScopeRowCollision(this.owningScopeId);

  final int? owningScopeId;
}

extension on DatabaseSerializationManager {
  /// Patches a [TableRow] with the given data.
  T patchTableRow<T extends TableRow>(T row, Map<String, Object?> data) {
    final rowJson = Map<String, dynamic>.from(row.toJson() as Map);
    for (final column in row.table.managedColumns) {
      if (column.columnName != 'id' &&
          column.columnName != 'scopeId' &&
          data.containsKey(column.columnName)) {
        rowJson[column.fieldName] = data[column.columnName];
      }
    }
    return deserialize<T>(rowJson);
  }
}
