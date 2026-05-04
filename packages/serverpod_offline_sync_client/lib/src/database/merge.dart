part of 'recorder.dart';

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);

/// Merge-specific behavior mixed into [CrdtMutationRecorder].
mixin CrdtMergeRecorderMixin {
  Database get _db;
  CrdtDatabaseSession get _session;
  Map<String, (int, Map<String, CrdtSchemaColumn>)> get _schema;
  Map<String, Map<String, ColumnDefinition>> get _columnsByTableAndName;

  bool _isCrdtTrackedTableName(String tableName);
  HlcManager _getHlcManager(Transaction transaction);
  CrdtUser _getEffectiveUser(Transaction transaction);
  Future<List<CrdtDataRow>> _findCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction, {
    CrdtDataRowInclude? include,
  });
  Future<void> _updateDomainRow(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> updates,
    Transaction transaction,
  );

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
        case CrdtMergeInsert insert:
          await _applyMergeInsert(
            insert,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeUpdate update:
          await _applyMergeUpdate(
            update,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeDelete delete:
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
      isTrackedTable: _isCrdtTrackedTableName,
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
          'Loaded ${loadedRows.length - rowPks.length} merge metadata rows '
          'for table $tableName without persisted identifiers.',
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
    final currentRowHlc = currentRow == null ? null : _rowHlc(currentRow);
    if (currentRowHlc != null && incomingHlc <= currentRowHlc) {
      return;
    }

    final data = _sanitizeMergeRowData(insert.tableName, insert.databaseColumns);
    final domainUpdates = <String, Object?>{};
    for (final MapEntry(key: columnName, value: value) in data.entries) {
      final currentField = fields[(insert.tableName, insert.uuidRowId, columnName)];
      final currentColumnHlc = currentField == null
          ? currentRowHlc
          : _fieldHlc(currentField);
      if (currentColumnHlc == null || incomingHlc > currentColumnHlc) {
        domainUpdates[columnName] = value;
      }
    }

    final persistedRow = await _upsertMergeRow(
      insert.tableName,
      insert.uuidRowId,
      remoteNode,
      incomingHlc,
      currentRow,
      transaction,
    );
    rows[rowKey] = persistedRow;

    if (domainUpdates.isEmpty) return;

    final rowExists = await _domainRowExists(
      insert.tableName,
      insert.uuidRowId,
      transaction,
    );
    if (rowExists) {
      await _updateDomainRow(
        insert.tableName,
        insert.uuidRowId,
        domainUpdates,
        transaction,
      );
      return;
    }

    await _insertDomainRow(
      insert.tableName,
      {
        'id': insert.uuidRowId,
        ...domainUpdates,
      },
      transaction,
    );
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
    final currentHlc = currentField == null ? _rowHlc(row) : _fieldHlc(currentField);
    if (incomingHlc <= currentHlc) {
      return;
    }

    await _updateDomainRow(
      update.tableName,
      update.uuidRowId,
      {update.columnName: update.value},
      transaction,
    );

    final remoteNode =
        remoteNodes[update.uuidNodeId] ??
        (throw StateError(
          'Remote node ${update.uuidNodeId} not found for merge.',
        ));
    final persistedField = await _upsertMergeField(
      row,
      schemaColumn,
      remoteNode,
      incomingHlc,
      currentField,
      transaction,
    );
    fields[fieldKey] = persistedField;
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
    final currentRowHlc = _rowHlc(row);
    final currentTombstone = tombstones[rowKey];
    final currentTombstoneHlc = currentTombstone == null
        ? null
        : _tombstoneHlc(currentTombstone);
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
    final persistedTombstone = await _upsertMergeTombstone(
      row,
      remoteNode,
      incomingHlc,
      delete.isDeleted,
      currentTombstone,
      transaction,
    );
    tombstones[rowKey] = persistedTombstone;
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

  Future<bool> _domainRowExists(
    String tableName,
    UuidValue rowId,
    Transaction transaction,
  ) async {
    final result = await _db.unsafeQuery(
      '''
SELECT 1
FROM "${_escapeIdentifier(tableName)}"
WHERE "id" = ${_sqlLiteral(rowId)}
LIMIT 1
''',
      transaction: transaction,
    );
    return result.isNotEmpty;
  }

  Future<void> _insertDomainRow(
    String tableName,
    Map<String, Object?> values,
    Transaction transaction,
  ) async {
    if (values.isEmpty) return;

    final columns = values.keys
        .map((columnName) => '"${_escapeIdentifier(columnName)}"')
        .join(', ');
    final sqlValues = values.values.map(_sqlLiteral).join(', ');

    await _db.unsafeExecute(
      '''
INSERT INTO "${_escapeIdentifier(tableName)}" ($columns)
VALUES ($sqlValues)
''',
      transaction: transaction,
    );
  }
}

Hlc _rowHlc(CrdtDataRow row) => row.toHlcForNode(row.node!.uuidNodeId);

Hlc _fieldHlc(CrdtDataField field) => field.toHlcForNode(field.node!.uuidNodeId);

Hlc _tombstoneHlc(CrdtDataDeleted tombstone) =>
    tombstone.toHlcForNode(tombstone.node!.uuidNodeId);
