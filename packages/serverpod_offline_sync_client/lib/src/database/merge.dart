part of 'recorder.dart';

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);

/// Adds merge-specific behavior to [CrdtMutationRecorder].
extension CrdtMergeRecorderExtension on CrdtMutationRecorder {
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
    final metadata = await _loadMergeMetadata(mergeSet, transaction);

    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.tableName)) {
        continue;
      }

      switch (operation) {
        case final CrdtMergeInsert insert:
          await _applyMergeInsert(
            insert,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case final CrdtMergeUpdate update:
          await _applyMergeUpdate(
            update,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case final CrdtMergeDelete delete:
          await _applyMergeDelete(
            delete,
            remoteNodes,
            metadata.rows,
            metadata.tombstones,
            transaction,
          );
      }
    }

    _updateHlcFromIncomingOperations(operations, transaction);
  }

  void _updateHlcFromIncomingOperations(
    List<CrdtMergeChange> operations,
    Transaction transaction,
  ) {
    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) =>
          current == null || change.hlc > current ? change.hlc : current,
    );
    if (maxIncomingHlc != null) {
      final hlcManager = _getHlcManager(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        if (maxIncomingHlc > hlcManager.lastHlc) {
          hlcManager.lastHlc = maxIncomingHlc;
        }
      } else {
        hlcManager.merge(maxIncomingHlc);
      }
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

  Future<
    ({
      Map<_MergeRowKey, CrdtDataRow> rows,
      Map<_MergeFieldKey, CrdtDataField> fields,
      Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    })
  >
  _loadMergeMetadata(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    final (:rowIdsByTable, :columnNamesByTable) = mergeSet.collectMetadataLookup(
      columnNamesByTableName: _syncedTableColumnNamesForMerge,
    );

    final rows = <_MergeRowKey, CrdtDataRow>{};
    final fields = <_MergeFieldKey, CrdtDataField>{};
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
      tombstones: tombstones,
    );
  }

  Future<void> _applyMergeInsert(
    CrdtMergeInsert insert,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Transaction transaction,
  ) async {
    final rowKey = (insert.tableName, insert.uuidRowId);
    final incomingHlc = insert.hlc;
    final remoteNode =
        remoteNodes[insert.uuidNodeId] ??
        (throw StateError(
          'Remote node ${insert.uuidNodeId} not found for merge.',
        ));

    final currentRow = rows[rowKey];
    final currentRowHlc = currentRow?.hlc;
    if (currentRowHlc != null && incomingHlc <= currentRowHlc) {
      return;
    }

    final data = _sanitizeMergeRowData(insert.tableName, insert.databaseColumns);
    final updatedColumns = <String>{};
    for (final columnName in data.keys) {
      final currentField = fields[(insert.tableName, insert.uuidRowId, columnName)];
      final currentColumnHlc = currentField?.hlc ?? currentRowHlc;
      if (currentColumnHlc == null || incomingHlc > currentColumnHlc) {
        updatedColumns.add(columnName);
      }
    }

    rows[rowKey] = await _upsertMergeRow(
      insert.tableName,
      insert.uuidRowId,
      remoteNode,
      incomingHlc,
      currentRow,
      transaction,
    );

    if (updatedColumns.isEmpty) return;

    final row = insert.data;
    if (row is! TableRow) {
      throw StateError(
        'Unsupported merge insert payload type for "${insert.tableName}": '
        '${row.runtimeType}. Expected subclass of TableRow.',
      );
    }

    try {
      await _db.updateRow(
        row,
        columns: _syncTableByName[insert.tableName]!.managedColumns
            .where((c) => updatedColumns.contains(c.columnName))
            .toList(),
        transaction: transaction,
      );
    } on DatabaseUpdateRowException {
      await _db.insertRow(row, transaction: transaction);
    }
  }

  Future<void> _applyMergeUpdate(
    CrdtMergeUpdate update,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Transaction transaction,
  ) async {
    final rowKey = (update.tableName, update.uuidRowId);
    final row = rows[rowKey];
    if (row == null) return;

    final (_, columnsByName) = _schema[update.tableName]!;
    final schemaColumn = columnsByName[update.columnName];
    if (schemaColumn == null) return;

    final incomingHlc = update.hlc;
    final fieldKey = (update.tableName, update.uuidRowId, update.columnName);
    final currentField = fields[fieldKey];
    final currentHlc = currentField?.hlc ?? row.hlc;
    if (incomingHlc <= currentHlc) {
      return;
    }

    await _updateDomainRows(
      update.tableName,
      {update.uuidRowId},
      {update.columnName: update.value},
      transaction,
    );

    final remoteNode =
        remoteNodes[update.uuidNodeId] ??
        (throw StateError(
          'Remote node ${update.uuidNodeId} not found for merge.',
        ));

    fields[fieldKey] = await _upsertMergeField(
      row,
      schemaColumn,
      remoteNode,
      incomingHlc,
      currentField,
      transaction,
    );
  }

  Future<void> _applyMergeDelete(
    CrdtMergeDelete delete,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction,
  ) async {
    final rowKey = (delete.tableName, delete.uuidRowId);
    final row = rows[rowKey];
    if (row == null) return;

    final incomingHlc = delete.hlc;
    final currentRowHlc = row.hlc;
    final currentTombstone = tombstones[rowKey];
    final currentTombstoneHlc = currentTombstone?.hlc;

    final currentVisibilityHlc =
        currentTombstoneHlc == null || currentRowHlc > currentTombstoneHlc
        ? currentRowHlc
        : currentTombstoneHlc;
    if (incomingHlc <= currentVisibilityHlc) {
      return;
    }

    final remoteNode =
        remoteNodes[delete.uuidNodeId] ??
        (throw StateError(
          'Remote node ${delete.uuidNodeId} not found for merge.',
        ));

    tombstones[rowKey] = await _upsertMergeTombstone(
      row,
      remoteNode,
      incomingHlc,
      delete.isDeleted,
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
    bool isDeleted,
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
          isDeleted: isDeleted,
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
      isDeleted: isDeleted,
    );

    await CrdtDataDeleted.db.update(
      _session,
      [updatedTombstone],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter, t.isDeleted],
      transaction: transaction,
    );

    return updatedTombstone;
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
