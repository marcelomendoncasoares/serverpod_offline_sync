part of 'recorder.dart';

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);

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
    await CrdtUser.db.findById(
      _session,
      user.id!,
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

    final currentUser = _getEffectiveUser(transaction);
    final remoteNodes = await _findOrCreateNodesForMerge(
      currentUser.id!,
      {
        for (final change in mergeSet.changes) change.mergeNodeId,
      },
      transaction,
    );
    final metadata = await _loadMergeMetadata(mergeSet, transaction);
    final operations = mergeSet.changes.toList()
      ..sort((left, right) => left.mergeHlc.compareTo(right.mergeHlc));

    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.mergeTableName) ||
          !_schema.containsKey(operation.mergeTableName)) {
        continue;
      }

      switch (operation) {
        case CrdtMergeInsert():
          await _applyMergeInsert(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeUpdate():
          await _applyMergeUpdate(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeDelete():
          await _applyMergeDelete(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.tombstones,
            transaction,
          );
      }
    }

    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) =>
          current == null || change.mergeHlc > current ? change.mergeHlc : current,
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
    final rowIdsByTable = <String, Set<UuidValue>>{};
    final columnNamesByTable = <String, Set<String>>{};

    for (final insert in mergeSet.inserts) {
      if (!_isCrdtTrackedTableName(insert.tableName) ||
          !_schema.containsKey(insert.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(insert.tableName, () => {}).add(insert.rowId);
      columnNamesByTable
          .putIfAbsent(insert.tableName, () => {})
          .addAll(
            insert.data.keys.where((columnName) => columnName != 'id'),
          );
    }

    for (final update in mergeSet.updates) {
      if (!_isCrdtTrackedTableName(update.tableName) ||
          !_schema.containsKey(update.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(update.tableName, () => {}).add(update.rowId);
      columnNamesByTable.putIfAbsent(update.tableName, () => {}).add(update.columnName);
    }

    for (final delete in mergeSet.deletes) {
      if (!_isCrdtTrackedTableName(delete.tableName) ||
          !_schema.containsKey(delete.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(delete.tableName, () => {}).add(delete.rowId);
    }

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
        final _MergeRowKey rowKey = (tableName, row.uuidRowId);
        rows[rowKey] = row;
        if (row.deleted != null) {
          tombstones[rowKey] = row.deleted!;
        }
      }

      final columnNames = columnNamesByTable[tableName];
      if (columnNames == null || columnNames.isEmpty || loadedRows.isEmpty) continue;

      final Set<int> rowPks = loadedRows.map((row) => row.id!).toSet();
      final (_, columnsByName) = _schema[tableName]!;
      final Set<int> columnIds = {
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
    final rowKey = (insert.tableName, insert.rowId);
    final incomingHlc = insert.hlc;
    final remoteNode =
        remoteNodes[insert.nodeId] ??
        (throw StateError('Remote node ${insert.nodeId} not found for merge.'));

    final currentRow = rows[rowKey];
    final currentRowHlc = currentRow == null ? null : _rowHlc(currentRow);
    if (currentRowHlc != null && incomingHlc <= currentRowHlc) {
      return;
    }

    final data = _sanitizeMergeRowData(insert.tableName, insert.data);
    final domainUpdates = <String, Object?>{};
    for (final MapEntry(key: columnName, value: value) in data.entries) {
      final currentField = fields[(insert.tableName, insert.rowId, columnName)];
      final currentColumnHlc = currentField == null
          ? currentRowHlc
          : _fieldHlc(currentField);
      if (currentColumnHlc == null || incomingHlc > currentColumnHlc) {
        domainUpdates[columnName] = value;
      }
    }

    final persistedRow = await _upsertMergeRow(
      insert.tableName,
      insert.rowId,
      remoteNode,
      incomingHlc,
      currentRow,
      transaction,
    );
    rows[rowKey] = persistedRow;

    if (domainUpdates.isEmpty) return;

    final rowExists = await _domainRowExists(
      insert.tableName,
      insert.rowId,
      transaction,
    );
    if (rowExists) {
      await _updateDomainRow(
        insert.tableName,
        insert.rowId,
        domainUpdates,
        transaction,
      );
      return;
    }

    await _insertDomainRow(
      insert.tableName,
      {
        'id': insert.rowId,
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
    final rowKey = (update.tableName, update.rowId);
    final row = rows[rowKey];
    if (row == null) return;

    final (_, columnsByName) = _schema[update.tableName]!;
    final schemaColumn = columnsByName[update.columnName];
    if (schemaColumn == null) return;

    final incomingHlc = update.hlc;
    final fieldKey = (update.tableName, update.rowId, update.columnName);
    final currentField = fields[fieldKey];
    final currentHlc = currentField == null ? _rowHlc(row) : _fieldHlc(currentField);
    if (incomingHlc <= currentHlc) {
      return;
    }

    await _updateDomainRow(
      update.tableName,
      update.rowId,
      {update.columnName: update.value},
      transaction,
    );

    final remoteNode =
        remoteNodes[update.nodeId] ??
        (throw StateError('Remote node ${update.nodeId} not found for merge.'));
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
    final rowKey = (delete.tableName, delete.rowId);
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
        remoteNodes[delete.nodeId] ??
        (throw StateError('Remote node ${delete.nodeId} not found for merge.'));
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
    Map<String, dynamic> data,
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
