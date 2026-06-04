part of 'recorder.dart';

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);
typedef _MergeContext = ({
  Map<_MergeRowKey, CrdtDataRow> rows,
  Map<_MergeFieldKey, CrdtDataField> fields,
  Map<_MergeFieldKey, Hlc> incomingFieldHlcs,
  Map<_MergeRowKey, CrdtDataDeleted> tombstones,
});

/// Adds merge-specific behavior to [CrdtMutationRecorder].
extension CrdtMergeRecorderExtension on CrdtMutationRecorder {
  CrdtUniqueConflictResolver get _uniqueConflictResolver =>
      CrdtUniqueConflictResolver(this);

  /// Locks the current user row so merges can serialize with other work.
  Future<void> lockCurrentUser(Transaction transaction) async {
    final user = _getEffectiveUser(transaction);
    // Use a row lock without fetching the record since the merge path only
    // needs serialization against concurrent work for the same user.
    await CrdtUser.db.lockRows(
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
    final currentUser = _getEffectiveUser(transaction);
    final remoteNodes = await _findOrCreateNodesForMerge(
      currentUser.id!,
      {for (final change in operations) change.uuidNodeId},
      transaction,
    );
    final context = await _loadMergeContext(mergeSet, transaction);

    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.tableName)) {
        continue;
      }

      switch (operation) {
        case final CrdtMergeInsert insert:
          await _applyMergeInsert(
            insert,
            remoteNodes,
            context,
            transaction,
          );
        case final CrdtMergeUpdate update:
          await _applyMergeUpdate(
            update,
            remoteNodes,
            context,
            transaction,
          );
        case final CrdtMergeDelete delete:
          await _applyMergeDelete(
            delete,
            remoteNodes,
            context,
            transaction,
          );
      }
    }

    await _updateHlcFromIncomingOperations(
      operations,
      remoteNodes,
      transaction,
    );
  }

  Future<void> _updateHlcFromIncomingOperations(
    List<CrdtMergeChange> operations,
    Map<UuidValue, CrdtNode> remoteNodes,
    Transaction transaction,
  ) async {
    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) => change.hlc.maxBetween(current),
    );
    final nodesToUpdate = <CrdtNode>[];

    if (maxIncomingHlc != null) {
      final hlcManager = _getHlcManager(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        if (maxIncomingHlc > hlcManager.lastHlc) {
          hlcManager.lastHlc = maxIncomingHlc;
        }
      } else {
        hlcManager.merge(maxIncomingHlc);
      }

      nodesToUpdate.add(hlcManager.getNode());
    }

    final maxIncomingHlcByNode = <UuidValue, Hlc>{};
    for (final operation in operations) {
      maxIncomingHlcByNode[operation.uuidNodeId] = operation.hlc.maxBetween(
        maxIncomingHlcByNode[operation.uuidNodeId],
      );
    }

    for (final MapEntry(key: nodeId, value: incomingHlc)
        in maxIncomingHlcByNode.entries) {
      final remoteNode = remoteNodes[nodeId];
      if (remoteNode == null) continue;
      final updatedNode = remoteNode.copyWith(
        lastReceivedHlc: incomingHlc.maxBetween(remoteNode.lastReceivedHlc),
      );
      if (updatedNode.lastReceivedHlc == remoteNode.lastReceivedHlc) continue;

      nodesToUpdate.add(updatedNode);
      remoteNodes[nodeId] = updatedNode;
    }

    if (nodesToUpdate.isNotEmpty) {
      await CrdtNode.db.update(
        _session,
        nodesToUpdate,
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );
    }
  }

  Future<Map<UuidValue, CrdtNode>> _findOrCreateNodesForMerge(
    int userId,
    Set<UuidValue> nodeIds,
    Transaction transaction,
  ) async {
    if (nodeIds.isEmpty) return {};

    var nodes = await CrdtNode.db.find(
      _session,
      where: (t) => t.userId.equals(userId) & t.uuidNodeId.inSet(nodeIds),
      transaction: transaction,
    );
    final existingNodeIds = nodes.map((node) => node.uuidNodeId).toSet();
    final missingNodeIds = nodeIds.difference(existingNodeIds);

    if (missingNodeIds.isNotEmpty) {
      await CrdtNode.db.insert(
        _session,
        [
          for (final uuidNodeId in missingNodeIds)
            CrdtNode(
              userId: userId,
              uuidNodeId: uuidNodeId,
            ),
        ],
        transaction: transaction,
        ignoreConflicts: true,
      );

      nodes = await CrdtNode.db.find(
        _session,
        where: (t) => t.userId.equals(userId) & t.uuidNodeId.inSet(nodeIds),
        transaction: transaction,
      );
    }

    return {
      for (final node in nodes) node.uuidNodeId: node,
    };
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

      final columnNames = columnNamesByTable[tableName];
      if (columnNames == null || columnNames.isEmpty || loadedRows.isEmpty) continue;

      final rowPks = loadedRows.map((row) => row.id).whereType<int>().toSet();
      if (rowPks.length != loadedRows.length) {
        throw StateError(
          'Some merge metadata rows for table $tableName are missing '
          'persisted identifiers.',
        );
      }

      final (_, columnsByName) = _schema[tableName]!;
      final columnIds = <int>{
        for (final columnName in columnNames)
          if (columnsByName[columnName] != null) columnsByName[columnName]!.id!,
      };
      if (columnIds.isEmpty) continue;

      final loadedFields = await CrdtDataField.db.find(
        _session,
        where: (t) => t.rowId.inSet(rowPks) & t.columnId.inSet(columnIds),
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
      final incomingRowWins = await _uniqueConflictResolver._resolveForIncomingInsert(
        insert,
        remoteNode,
        incomingHlc,
        data,
        context,
        transaction,
      );
      if (!incomingRowWins) return;

      context.rows[rowKey] = await _applyMergeInsertForMissingRow(
        insert,
        remoteNode,
        incomingHlc,
        data,
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

    final shouldApply = await _shouldMergeFieldMetadataIfNewer(
      tableName: update.tableName,
      rowId: update.uuidRowId,
      columnName: update.columnName,
      row: row,
      remoteNode: _requireRemoteNode(remoteNodes, update.uuidNodeId),
      incomingHlc: update.hlc,
      fields: context.fields,
      transaction: transaction,
    );

    if (!shouldApply) return;

    final uniqueResolution = await _uniqueConflictResolver._resolveForIncomingUpdate(
      update,
      row,
      context,
      transaction,
    );

    await _updateDomainRows(
      update.tableName,
      {update.uuidRowId},
      uniqueResolution.updates,
      transaction,
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

    final currentTombstone = context.tombstones[rowKey];
    final currentClFlag = currentTombstone?.clFlag ?? 1;
    final currentHlc = currentTombstone?.hlc ?? row.hlc;
    if (delete.clFlag < currentClFlag) return;
    if (delete.clFlag == currentClFlag && delete.hlc <= currentHlc) return;

    context.tombstones[rowKey] = await _upsertMergeTombstone(
      row,
      _requireRemoteNode(remoteNodes, delete.uuidNodeId),
      delete.hlc,
      delete.clFlag,
      delete.reason,
      currentTombstone,
      transaction,
    );
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
          userId: _getHlcManager(transaction).normalizedUserId,
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

    final row = _requireMergeInsertTableRow(insert);
    try {
      await _db.updateRow(
        row,
        columns: row.table.managedColumns
            .where((c) => data.containsKey(c.columnName))
            .toList(),
        transaction: transaction,
      );
    } on DatabaseUpdateRowException {
      await _db.insertRow(row, transaction: transaction);
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

    var rowStillVisible = true;
    if (updatedValues.isNotEmpty) {
      final uniqueResolution = await _uniqueConflictResolver._resolveForIncomingUpdates(
        tableName: insert.tableName,
        row: currentRow,
        updates: updatedValues,
        context: context,
        transaction: transaction,
      );
      final resolvedUpdates = Map<String, Object?>.from(uniqueResolution.updates);
      rowStillVisible = uniqueResolution.rowStillVisible;
      updatedValues
        ..clear()
        ..addAll(resolvedUpdates);
    }

    if (updatedValues.isNotEmpty) {
      await _updateDomainRows(
        insert.tableName,
        {insert.uuidRowId},
        updatedValues,
        transaction,
      );
    }
    if (!rowStillVisible) return;

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
    final (_, columnsByName) = _schema[tableName]!;
    final resolvedSchemaColumn = schemaColumn ?? columnsByName[columnName];
    if (resolvedSchemaColumn == null) return false;

    final fieldKey = (tableName, rowId, columnName);
    var currentField = fields[fieldKey];
    if (currentField == null) {
      currentField = await CrdtDataField.db.findFirstRow(
        _session,
        where: (t) =>
            t.rowId.equals(row.id) & t.columnId.equals(resolvedSchemaColumn.id),
        include: CrdtDataField.include(node: CrdtNode.include()),
        transaction: transaction,
      );
      if (currentField != null) fields[fieldKey] = currentField;
    }

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
    final columns = _columnsByTableAndName[tableName];
    if (columns == null) return {};

    return {
      for (final MapEntry(key: columnName, value: value) in data.entries)
        if (columnName != 'id' && columns.containsKey(columnName)) columnName: value,
    };
  }
}
