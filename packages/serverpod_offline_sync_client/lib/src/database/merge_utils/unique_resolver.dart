part of '../recorder.dart';

typedef _UniqueConflict = ({
  CrdtDataRow row,
  _UniqueIndexConflictRelease uniqueIndex,
});

/// Resolves unique constraint conflicts that appear while merging CRDT changes.
class CrdtUniqueConflictResolver {
  /// Creates a resolver for the merge recorder.
  CrdtUniqueConflictResolver(this._recorder);

  final CrdtMutationRecorder _recorder;

  /// Resolves unique conflicts for an incoming insert.
  Future<bool> _resolveForIncomingInsert(
    CrdtMergeInsert insert,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    Map<String, Object?> data,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Map<_MergeFieldKey, Hlc> incomingFieldHlcs,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction,
  ) async {
    final conflicts = await _findVisibleUniqueConflicts(
      tableName: insert.tableName,
      rowId: insert.uuidRowId,
      values: data,
      transaction: transaction,
    );

    for (final conflict in conflicts) {
      final incomingUniqueHlc = _incomingInsertUniqueIndexHlc(
        insert: insert,
        uniqueIndex: conflict.uniqueIndex,
        incomingFieldHlcs: incomingFieldHlcs,
      );
      final conflictUniqueHlc = await _uniqueIndexHlc(
        tableName: insert.tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: fields,
        transaction: transaction,
      );

      if (!_leftUniqueRowWins(
        leftRowId: insert.uuidRowId,
        leftHlc: incomingUniqueHlc,
        rightRowId: conflict.row.uuidRowId,
        rightHlc: conflictUniqueHlc,
      )) {
        rows[(
          insert.tableName,
          insert.uuidRowId,
        )] = await _applyMergeInsertForMissingUniqueLoser(
          insert,
          remoteNode,
          incomingHlc,
          data,
          tombstones,
          transaction,
        );
        return false;
      }
    }

    for (final conflict in conflicts) {
      await _hideUniqueLoser(
        insert.tableName,
        conflict.row,
        tombstones,
        transaction,
      );
    }

    return true;
  }

  Hlc _incomingInsertUniqueIndexHlc({
    required CrdtMergeInsert insert,
    required _UniqueIndexConflictRelease uniqueIndex,
    required Map<_MergeFieldKey, Hlc> incomingFieldHlcs,
  }) {
    var uniqueHlc = insert.hlc;
    for (final column in uniqueIndex.columns) {
      uniqueHlc = uniqueHlc.maxBetween(
        incomingFieldHlcs[(insert.tableName, insert.uuidRowId, column.columnName)],
      );
    }
    return uniqueHlc;
  }

  /// Resolves unique conflicts for a single incoming field update.
  Future<({bool rowStillVisible, Map<String, Object?> updates})>
  _resolveForIncomingUpdate(
    CrdtMergeUpdate update,
    CrdtDataRow row,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction,
  ) {
    return _resolveForIncomingUpdates(
      tableName: update.tableName,
      row: row,
      updates: {update.columnName: update.value},
      fields: fields,
      tombstones: tombstones,
      transaction: transaction,
    );
  }

  /// Resolves unique conflicts for one or more incoming field updates.
  Future<({bool rowStillVisible, Map<String, Object?> updates})>
  _resolveForIncomingUpdates({
    required String tableName,
    required CrdtDataRow row,
    required Map<String, Object?> updates,
    required Map<_MergeFieldKey, CrdtDataField> fields,
    required Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    required Transaction transaction,
  }) async {
    if (updates.keys.every(
      (columnName) => !_isUniqueIndexedColumn(tableName, columnName),
    )) {
      return (rowStillVisible: true, updates: updates);
    }

    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) {
      return (rowStillVisible: true, updates: updates);
    }

    final uniqueColumnNamesToRead = {
      for (final uniqueIndex in _recorder._uniqueIndexesForTable(tableDefinition))
        for (final column in uniqueIndex.columns) column.columnName,
    };
    if (uniqueColumnNamesToRead.isEmpty) {
      return (rowStillVisible: true, updates: updates);
    }

    final currentValues = await _recorder._readDomainColumnValues(
      tableName,
      {row.uuidRowId},
      uniqueColumnNamesToRead.toList(),
      transaction,
    );
    final values = {
      ...?currentValues[row.uuidRowId],
      ...updates,
    };

    final conflicts = await _findVisibleUniqueConflicts(
      tableName: tableName,
      rowId: row.uuidRowId,
      values: values,
      transaction: transaction,
    );

    for (final conflict in conflicts) {
      final rowUniqueHlc = await _uniqueIndexHlc(
        tableName: tableName,
        row: row,
        uniqueIndex: conflict.uniqueIndex,
        fields: fields,
        transaction: transaction,
      );
      final conflictUniqueHlc = await _uniqueIndexHlc(
        tableName: tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: fields,
        transaction: transaction,
      );

      if (!_leftUniqueRowWins(
        leftRowId: row.uuidRowId,
        leftHlc: rowUniqueHlc,
        rightRowId: conflict.row.uuidRowId,
        rightHlc: conflictUniqueHlc,
      )) {
        final releasedValues = _releaseUniqueValuesForData(
          tableName,
          row.uuidRowId,
          values,
        );
        final releasedUpdates = Map<String, Object?>.from(updates);
        for (final columnName in uniqueColumnNamesToRead) {
          if (releasedValues.containsKey(columnName)) {
            releasedUpdates[columnName] = releasedValues[columnName];
          }
        }

        await _hideUniqueLoser(
          tableName,
          row,
          tombstones,
          transaction,
          releaseUniqueValues: false,
        );

        return (rowStillVisible: false, updates: releasedUpdates);
      }
    }

    for (final conflict in conflicts) {
      await _hideUniqueLoser(tableName, conflict.row, tombstones, transaction);
    }

    return (rowStillVisible: true, updates: updates);
  }

  Future<CrdtDataRow> _applyMergeInsertForMissingUniqueLoser(
    CrdtMergeInsert insert,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    Map<String, Object?> data,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction,
  ) async {
    final insertedCrdtRow = await _recorder._upsertMergeRow(
      insert.tableName,
      insert.uuidRowId,
      remoteNode,
      incomingHlc,
      null,
      transaction,
    );

    await _insertDomainRowFromValues(
      insert.tableName,
      insert.uuidRowId,
      _releaseUniqueValuesForData(insert.tableName, insert.uuidRowId, data),
      transaction,
    );

    await _hideUniqueLoser(
      insert.tableName,
      insertedCrdtRow,
      tombstones,
      transaction,
      releaseUniqueValues: false,
    );

    return insertedCrdtRow;
  }

  Future<void> _insertDomainRowFromValues(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
    Transaction transaction,
  ) async {
    final columns = ['id', ...data.keys];
    final escapedColumns = columns
        .map((columnName) => '"${_escapeIdentifier(columnName)}"')
        .join(', ');
    final values = [
      _sqlLiteral(rowId),
      for (final columnName in data.keys) _sqlLiteral(data[columnName]),
    ].join(', ');

    await _recorder._db.unsafeExecute(
      '''
INSERT INTO "${_escapeIdentifier(tableName)}" ($escapedColumns)
VALUES ($values)
''',
      transaction: transaction,
    );
  }

  Map<String, Object?> _releaseUniqueValuesForData(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
  ) {
    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) return data;

    final released = Map<String, Object?>.from(data);
    for (final uniqueIndex in _recorder._uniqueIndexesForTable(tableDefinition)) {
      final values = {
        for (final column in uniqueIndex.columns)
          column.columnName: released[column.columnName],
      };
      if (values.values.any((value) => value == null)) continue;

      for (final column in uniqueIndex.columns) {
        released[column.columnName] = _recorder._conflictFreeValue(
          column,
          values[column.columnName],
          tableDefinition.name,
          rowId,
        );
      }
    }
    return released;
  }

  Future<void> _hideUniqueLoser(
    String tableName,
    CrdtDataRow loser,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction, {
    bool releaseUniqueValues = true,
  }) async {
    if (loser.deleted?.isDeleted ?? false) return;

    if (releaseUniqueValues) {
      await _recorder._releaseUniqueConflicts(
        tableName,
        {loser.uuidRowId},
        transaction,
      );
    }

    await _recorder._markCrdtRowsDeleted(
      [loser],
      true,
      CrdtDataDeletedReason.uniqueLoser,
      transaction,
    );

    final tombstone = await CrdtDataDeleted.db.findFirstRow(
      _recorder._session,
      where: (t) => t.rowId.equals(loser.id),
      include: CrdtDataDeleted.include(node: CrdtNode.include()),
      transaction: transaction,
    );
    if (tombstone != null) {
      tombstones[(tableName, loser.uuidRowId)] = tombstone;
    }
  }

  Future<List<_UniqueConflict>> _findVisibleUniqueConflicts({
    required String tableName,
    required UuidValue rowId,
    required Map<String, Object?> values,
    required Transaction transaction,
  }) async {
    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) return const [];

    final uniqueIndexes = _recorder._uniqueIndexesForTable(tableDefinition);
    if (uniqueIndexes.isEmpty) return const [];

    final conflictIds = <UuidValue>{};
    final uniqueIndexesByConflictId = <UuidValue, _UniqueIndexConflictRelease>{};
    for (final uniqueIndex in uniqueIndexes) {
      final columnValues = {
        for (final column in uniqueIndex.columns)
          if (values.containsKey(column.columnName))
            column.columnName: values[column.columnName],
      };
      if (columnValues.length != uniqueIndex.columns.length) continue;
      if (columnValues.values.any((value) => value == null)) continue;

      final uniqueConflictIds = await _findVisibleRowsByUniqueValues(
        tableName: tableName,
        rowId: rowId,
        values: columnValues,
        transaction: transaction,
      );
      conflictIds.addAll(uniqueConflictIds);
      for (final conflictId in uniqueConflictIds) {
        uniqueIndexesByConflictId[conflictId] = uniqueIndex;
      }
    }

    if (conflictIds.isEmpty) return const [];
    final conflictRows = await _recorder._findCrdtRows(
      tableName,
      conflictIds,
      transaction,
      include: CrdtDataRow.include(
        node: CrdtNode.include(),
        deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
      ),
    );
    return [
      for (final conflictRow in conflictRows)
        (
          row: conflictRow,
          uniqueIndex: uniqueIndexesByConflictId[conflictRow.uuidRowId]!,
        ),
    ];
  }

  Future<Hlc> _uniqueIndexHlc({
    required String tableName,
    required CrdtDataRow row,
    required _UniqueIndexConflictRelease uniqueIndex,
    required Map<_MergeFieldKey, CrdtDataField> fields,
    required Transaction transaction,
  }) async {
    final (_, columnsByName) = _recorder._schema[tableName]!;
    final uniqueColumnNames = {
      for (final column in uniqueIndex.columns) column.columnName,
    };
    final missingColumnIds = <int>{};
    final maxFieldHlc = <Hlc>[];
    for (final columnName in uniqueColumnNames) {
      final field = fields[(tableName, row.uuidRowId, columnName)];
      if (field == null) {
        final columnId = columnsByName[columnName]?.id;
        if (columnId != null) missingColumnIds.add(columnId);
        continue;
      }

      maxFieldHlc.add(field.hlc);
    }

    if (missingColumnIds.isNotEmpty && row.id != null) {
      final loadedFields = await CrdtDataField.db.find(
        _recorder._session,
        where: (t) => t.rowId.equals(row.id) & t.columnId.inSet(missingColumnIds),
        include: CrdtDataField.include(
          column: CrdtSchemaColumn.include(),
          node: CrdtNode.include(),
        ),
        transaction: transaction,
      );

      for (final field in loadedFields) {
        final columnName = field.column?.name;
        if (columnName == null) continue;
        fields[(tableName, row.uuidRowId, columnName)] = field;
        maxFieldHlc.add(field.hlc);
      }
    }

    if (maxFieldHlc.isEmpty) return row.hlc;
    return maxFieldHlc.reduce((left, right) => left.maxBetween(right));
  }

  Future<Set<UuidValue>> _findVisibleRowsByUniqueValues({
    required String tableName,
    required UuidValue rowId,
    required Map<String, Object?> values,
    required Transaction transaction,
  }) async {
    return _recorder._findVisibleDomainRowIdsWhere(
      tableName: tableName,
      predicates: [
        for (final MapEntry(key: columnName, value: value) in values.entries)
          'd."${_escapeIdentifier(columnName)}" = ${_sqlLiteral(value)}',
        'd."id" <> ${_sqlLiteral(rowId)}',
      ],
      transaction: transaction,
    );
  }

  bool _isUniqueIndexedColumn(String tableName, String columnName) {
    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) return false;

    return _recorder
        ._uniqueIndexesForTable(tableDefinition)
        .any(
          (index) => index.columns.any((column) => column.columnName == columnName),
        );
  }

  bool _leftUniqueRowWins({
    required UuidValue leftRowId,
    required Hlc leftHlc,
    required UuidValue rightRowId,
    required Hlc rightHlc,
  }) {
    final hlcComparison = leftHlc.compareTo(rightHlc);
    if (hlcComparison != 0) return hlcComparison < 0;
    return leftRowId.uuid.compareTo(rightRowId.uuid) < 0;
  }
}
