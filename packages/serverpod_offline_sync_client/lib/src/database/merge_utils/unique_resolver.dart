part of '../recorder.dart';

typedef _UniqueConflict = ({
  CrdtDataRow row,
  _UniqueIndexConflictRelease uniqueIndex,
});

typedef _UniqueClaim = ({
  UuidValue rowId,
  Hlc hlc,
});

/// Resolves unique constraint conflicts that appear while merging CRDT changes.
class CrdtUniqueConflictResolver {
  /// Creates a resolver for the merge recorder.
  CrdtUniqueConflictResolver(this._recorder);

  final CrdtMutationRecorder _recorder;

  /// Resolves unique conflicts for an incoming insert.
  Future<({Map<String, Object?> data, bool changed})> _resolveForIncomingInsert(
    CrdtMergeInsert insert,
    Map<String, Object?> data,
    _MergeContext context,
    Transaction transaction,
  ) async {
    final resolvedData = Map<String, Object?>.from(data);
    var changed = false;
    final conflicts = await _findVisibleUniqueConflicts(
      tableName: insert.tableName,
      rowId: insert.uuidRowId,
      values: data,
      transaction: transaction,
    );

    for (final conflict in conflicts) {
      final incomingClaim = _incomingInsertUniqueClaim(
        insert: insert,
        uniqueIndex: conflict.uniqueIndex,
        context: context,
      );
      final conflictClaim = await _rowUniqueClaim(
        tableName: insert.tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );

      if (!_leftUniqueClaimWins(incomingClaim, conflictClaim)) {
        final claimedValues = _uniqueIndexValues(resolvedData, conflict.uniqueIndex);
        final releasedValues = _uniqueConflictFreeValuesForData(
          insert.tableName,
          insert.uuidRowId,
          resolvedData,
          conflict.uniqueIndex,
        );
        resolvedData.addAll(releasedValues);
        final uniqueConflict = await _uniqueConflict(
          tableName: insert.tableName,
          losingRowId: insert.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          conflictingValues: claimedValues,
          replacementValues: releasedValues,
          losingRowData: resolvedData,
          existingRow: await _recorder._readRequiredDomainRow(
            insert.tableName,
            conflict.row.uuidRowId,
            transaction,
          ),
          transaction: transaction,
        );
        context.uniqueConflicts.add(uniqueConflict);
        changed = true;
      } else {
        final uniqueConflict = await _releaseUniqueConflictForRow(
          tableName: insert.tableName,
          rowId: conflict.row.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          existingRow: _recorder._domainRowFromData(
            insert.tableName,
            insert.uuidRowId,
            data,
          ),
          transaction: transaction,
        );
        if (uniqueConflict != null) {
          context.uniqueConflicts.add(uniqueConflict);
        }
      }
    }

    return (data: resolvedData, changed: changed);
  }

  _UniqueClaim _incomingInsertUniqueClaim({
    required CrdtMergeInsert insert,
    required _UniqueIndexConflictRelease uniqueIndex,
    required _MergeContext context,
  }) {
    var uniqueHlc = insert.hlc;
    for (final column in uniqueIndex.columns) {
      uniqueHlc = uniqueHlc.maxBetween(
        context.incomingFieldHlcs[(
          insert.tableName,
          insert.uuidRowId,
          column.columnName,
        )],
      );
    }
    return (rowId: insert.uuidRowId, hlc: uniqueHlc);
  }

  /// Resolves unique conflicts for a single incoming field update.
  Future<Map<String, Object?>> _resolveForIncomingUpdate(
    CrdtMergeUpdate update,
    CrdtDataRow row,
    _MergeContext context,
    Transaction transaction,
  ) {
    return _resolveForIncomingUpdates(
      tableName: update.tableName,
      row: row,
      updates: {update.columnName: update.value},
      context: context,
      transaction: transaction,
    );
  }

  /// Resolves unique conflicts for one or more incoming field updates.
  Future<Map<String, Object?>> _resolveForIncomingUpdates({
    required String tableName,
    required CrdtDataRow row,
    required Map<String, Object?> updates,
    required _MergeContext context,
    required Transaction transaction,
  }) async {
    if (updates.keys.every(
      (columnName) => !_isUniqueIndexedColumn(tableName, columnName),
    )) {
      return updates;
    }

    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) {
      return updates;
    }

    final uniqueColumnNamesToRead = {
      for (final uniqueIndex in _recorder._uniqueIndexesForTable(tableDefinition))
        for (final column in uniqueIndex.columns) column.columnName,
    };
    if (uniqueColumnNamesToRead.isEmpty) {
      return updates;
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
    final rowData =
        await _recorder._readDomainRowData(
          tableName,
          row.uuidRowId,
          transaction,
        ) ??
        (throw StateError('Domain row $tableName.${row.uuidRowId} was not found.'));

    final conflicts = await _findVisibleUniqueConflicts(
      tableName: tableName,
      rowId: row.uuidRowId,
      values: values,
      transaction: transaction,
    );

    final resolvedUpdates = Map<String, Object?>.from(updates);
    for (final conflict in conflicts) {
      final rowClaim = await _rowUniqueClaim(
        tableName: tableName,
        row: row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );
      final conflictClaim = await _rowUniqueClaim(
        tableName: tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );

      if (!_leftUniqueClaimWins(rowClaim, conflictClaim)) {
        final claimedValues = _uniqueIndexValues(values, conflict.uniqueIndex);
        final releasedValues = _uniqueConflictFreeValuesForData(
          tableName,
          row.uuidRowId,
          values,
          conflict.uniqueIndex,
        );
        for (final columnName in _uniqueIndexColumnNames(conflict.uniqueIndex)) {
          if (releasedValues.containsKey(columnName)) {
            resolvedUpdates[columnName] = releasedValues[columnName];
            values[columnName] = releasedValues[columnName];
          }
        }
        final uniqueConflict = await _uniqueConflict(
          tableName: tableName,
          losingRowId: row.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          conflictingValues: claimedValues,
          replacementValues: releasedValues,
          losingRowData: {
            ...rowData,
            ...resolvedUpdates,
          },
          existingRow: await _recorder._readRequiredDomainRow(
            tableName,
            conflict.row.uuidRowId,
            transaction,
          ),
          transaction: transaction,
        );
        context.uniqueConflicts.add(uniqueConflict);
      } else {
        final uniqueConflict = await _releaseUniqueConflictForRow(
          tableName: tableName,
          rowId: conflict.row.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          existingRow: _recorder._domainRowFromData(
            tableName,
            row.uuidRowId,
            {
              ...rowData,
              ...updates,
            },
          ),
          transaction: transaction,
        );
        if (uniqueConflict != null) context.uniqueConflicts.add(uniqueConflict);
      }
    }

    return resolvedUpdates;
  }

  Map<String, Object?> _uniqueConflictFreeValuesForData(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
    _UniqueIndexConflictRelease uniqueIndex,
  ) {
    final tableDefinition = _recorder._tableDefinitionsByName[tableName];
    if (tableDefinition == null) return data;

    final released = Map<String, Object?>.from(data);
    final values = {
      for (final column in uniqueIndex.columns)
        column.columnName: released[column.columnName],
    };
    if (values.values.any((value) => value == null)) return released;

    for (final column in uniqueIndex.columns) {
      released[column.columnName] = _uniqueConflictFreeValue(
        column,
        values[column.columnName],
        tableDefinition.name,
        rowId,
      );
    }
    return released;
  }

  Future<UniqueConflictContext?> _releaseUniqueConflictForRow({
    required String tableName,
    required UuidValue rowId,
    required _UniqueIndexConflictRelease uniqueIndex,
    required TableRow existingRow,
    required Transaction transaction,
  }) async {
    final columnNames = _uniqueIndexColumnNames(uniqueIndex).toList();
    final valuesByRowId = await _recorder._readDomainColumnValues(
      tableName,
      {rowId},
      columnNames,
      transaction,
    );
    final values = valuesByRowId[rowId];
    if (values == null || values.values.any((value) => value == null)) return null;

    final releasedValues = _uniqueConflictFreeValuesForData(
      tableName,
      rowId,
      values,
      uniqueIndex,
    );
    await _recorder._updateDomainRows(tableName, {rowId}, releasedValues, transaction);
    await _recorder.recordFieldsUpdatedByTable(
      tableName,
      {rowId},
      columnNames,
      transaction,
    );
    return _uniqueConflict(
      tableName: tableName,
      losingRowId: rowId,
      uniqueIndex: uniqueIndex,
      conflictingValues: values,
      replacementValues: releasedValues,
      existingRow: existingRow,
      transaction: transaction,
    );
  }

  Object? _uniqueConflictFreeValue(
    _UniqueColumnConflictRelease column,
    Object? value,
    String tableName,
    UuidValue conflictingId,
  ) {
    switch (column.kind) {
      case _UniqueConflictReleaseKind.setNull:
        return null;
      case _UniqueConflictReleaseKind.textSuffix:
        if (value is String) {
          return '${value}__conflict__${conflictingId.uuid}';
        }
      case _UniqueConflictReleaseKind.syntheticUuid:
        if (value != null) {
          return _syntheticUniqueConflictUuid(
            tableName,
            column.columnName,
            UuidValueJsonExtension.fromJson(value),
            conflictingId,
          );
        }
    }

    throw StateError(
      'Unexpected value for $tableName.${column.columnName} while making '
      'unique conflict value conflict-free: ${value.runtimeType}.',
    );
  }

  Future<UniqueConflictContext> _uniqueConflict({
    required String tableName,
    required UuidValue losingRowId,
    required _UniqueIndexConflictRelease uniqueIndex,
    required Map<String, Object?> conflictingValues,
    required Map<String, Object?> replacementValues,
    required Transaction transaction,
    required TableRow existingRow,
    Map<String, Object?>? losingRowData,
  }) async {
    final columnNames = _uniqueIndexColumnNames(uniqueIndex).toList();
    final row = losingRowData == null
        ? await _recorder._readRequiredDomainRow(tableName, losingRowId, transaction)
        : _recorder._domainRowFromData(tableName, losingRowId, losingRowData);

    return UniqueConflictContext(
      row: row,
      conflictingValues: {
        for (final columnName in columnNames) columnName: conflictingValues[columnName],
      },
      replacementValues: {
        for (final columnName in columnNames) columnName: replacementValues[columnName],
      },
      existingRow: existingRow,
    );
  }

  Map<String, Object?> _uniqueIndexValues(
    Map<String, Object?> values,
    _UniqueIndexConflictRelease uniqueIndex,
  ) {
    return {
      for (final columnName in _uniqueIndexColumnNames(uniqueIndex))
        columnName: values[columnName],
    };
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

    final uniqueIndexesByConflictId = <UuidValue, Set<_UniqueIndexConflictRelease>>{};
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
      for (final conflictId in uniqueConflictIds) {
        uniqueIndexesByConflictId.putIfAbsent(conflictId, () => {}).add(uniqueIndex);
      }
    }

    if (uniqueIndexesByConflictId.isEmpty) return const [];
    final conflictRows = await _recorder._findCrdtRows(
      tableName,
      uniqueIndexesByConflictId.keys.toSet(),
      transaction,
      include: CrdtDataRow.include(
        node: CrdtNode.include(),
        deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
      ),
    );
    return [
      for (final conflictRow in conflictRows)
        for (final uniqueIndex in uniqueIndexesByConflictId[conflictRow.uuidRowId]!)
          (
            row: conflictRow,
            uniqueIndex: uniqueIndex,
          ),
    ];
  }

  Future<_UniqueClaim> _rowUniqueClaim({
    required String tableName,
    required CrdtDataRow row,
    required _UniqueIndexConflictRelease uniqueIndex,
    required Map<_MergeFieldKey, CrdtDataField> fields,
    required Transaction transaction,
  }) async {
    return (
      rowId: row.uuidRowId,
      hlc: await _uniqueIndexHlc(
        tableName: tableName,
        row: row,
        uniqueIndex: uniqueIndex,
        fields: fields,
        transaction: transaction,
      ),
    );
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

  bool _leftUniqueClaimWins(_UniqueClaim left, _UniqueClaim right) {
    return _leftUniqueRowWins(
      leftRowId: left.rowId,
      leftHlc: left.hlc,
      rightRowId: right.rowId,
      rightHlc: right.hlc,
    );
  }

  Set<String> _uniqueIndexColumnNames(_UniqueIndexConflictRelease uniqueIndex) {
    return {
      for (final column in uniqueIndex.columns) column.columnName,
    };
  }
}
