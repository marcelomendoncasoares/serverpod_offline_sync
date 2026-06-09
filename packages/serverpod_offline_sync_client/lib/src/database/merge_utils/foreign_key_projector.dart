part of '../recorder.dart';

typedef _ForeignKeyProjectionWrite = ({
  int fieldId,
  UuidValue? attemptedValue,
  UuidValue? visibleValue,
  bool hasOverride,
  CrdtForeignKeyOverrideReason? overrideReason,
});

class _ProjectedForeignKeyRow {
  _ProjectedForeignKeyRow({
    required this.key,
    required this.crdtRow,
    required this.crdtRowId,
    required this.isHidden,
    required this.visibility,
    required this.userHidden,
    required this.userDeletedReason,
    required this.values,
  });

  final _MergeRowKey key;
  final CrdtDataRow crdtRow;
  final int crdtRowId;
  final bool isHidden;
  final CrdtDataRowVisibility visibility;
  final bool userHidden;
  final CrdtDataDeletedReason? userDeletedReason;
  final Map<String, Object?> values;
}

class _ForeignKeyProjectionRow {
  _ForeignKeyProjectionRow({
    required this.id,
    required this.fieldId,
    required this.attemptedValue,
    required this.visibleValue,
    required this.hasOverride,
    required this.overrideReason,
  });

  final int? id;
  final int fieldId;
  final UuidValue? attemptedValue;
  final UuidValue? visibleValue;
  final bool hasOverride;
  final CrdtForeignKeyOverrideReason? overrideReason;
}

class _ForeignKeyProjectionState {
  _ForeignKeyProjectionState({
    required this.rows,
    required this.rowsByTable,
    required this.fieldIds,
    required this.projections,
    required this.parentRowsByReference,
    required this.childRowsByAttempt,
  });

  final Map<_MergeRowKey, _ProjectedForeignKeyRow> rows;
  final Map<String, List<_ProjectedForeignKeyRow>> rowsByTable;
  final Map<_MergeFieldKey, int> fieldIds;
  final Map<_MergeFieldKey, _ForeignKeyProjectionRow> projections;
  final Map<_ForeignKeyValueKey, _ProjectedForeignKeyRow> parentRowsByReference;
  final Map<_ForeignKeyValueKey, List<_ProjectedForeignKeyRow>> childRowsByAttempt;
}

extension _CrdtForeignKeyProjector on CrdtMutationRecorder {
  bool _tableColumnsMayAffectForeignKeys(
    String tableName,
    Set<String>? columnNames,
  ) {
    final childEdges =
        _foreignKeyEdgesByChildTable[tableName] ?? const <_ForeignKeyEdge>[];
    final parentEdges =
        _foreignKeyEdgesByParentTable[tableName] ?? const <_ForeignKeyEdge>[];
    if (childEdges.isEmpty && parentEdges.isEmpty) return false;
    if (columnNames == null) return true;

    return childEdges.any((edge) => columnNames.contains(edge.childColumn)) ||
        parentEdges.any(
          (edge) =>
              edge.parentColumn != 'id' && columnNames.contains(edge.parentColumn),
        );
  }

  bool _mergeOperationsMayAffectForeignKeys(
    List<CrdtMergeChange> operations,
  ) {
    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.tableName)) continue;

      switch (operation) {
        case final CrdtMergeUpdate update:
          if (_tableColumnsMayAffectForeignKeys(
            update.tableName,
            {update.columnName},
          )) {
            return true;
          }
        case CrdtMergeInsert() || CrdtMergeDelete():
          if (_tableColumnsMayAffectForeignKeys(operation.tableName, null)) {
            return true;
          }
      }
    }

    return false;
  }

  Future<void> _recordForeignKeyAttemptsForRows(
    String tableName,
    Set<UuidValue> rowIds,
    Set<String>? columnNames,
    Transaction transaction, {
    Set<_MergeFieldKey> skippedFields = const {},
    Map<_MergeFieldKey, UuidValue?> attemptedValues = const {},
  }) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeyEdgesByChildTable[tableName] ?? const <_ForeignKeyEdge>[])
        if (columnNames == null || columnNames.contains(edge.childColumn))
          edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return;

    final valuesByRowId = await _readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    final fieldIds = await _findForeignKeyFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );

    final projectionWrites = <_ForeignKeyProjectionWrite>[];
    for (final rowId in rowIds) {
      final values = valuesByRowId[rowId];
      if (values == null) continue;

      for (final columnName in foreignKeyColumns) {
        final fieldId = fieldIds[(tableName, rowId, columnName)];
        if (fieldId == null) continue;
        if (skippedFields.contains((tableName, rowId, columnName))) continue;

        final fieldKey = (tableName, rowId, columnName);
        final visibleValue = _uuidValueFromDatabase(values[columnName]);
        final attemptedValue = attemptedValues.containsKey(fieldKey)
            ? attemptedValues[fieldKey]
            : visibleValue;
        final hasOverride = !_sameUuidValue(attemptedValue, visibleValue);
        projectionWrites.add((
          fieldId: fieldId,
          attemptedValue: attemptedValue,
          visibleValue: hasOverride ? visibleValue : null,
          hasOverride: hasOverride,
          overrideReason: null,
        ));
      }
    }

    await _upsertForeignKeyProjections(projectionWrites, transaction);
  }

  Future<void> _recordForeignKeyInsertAttempts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    Map<_MergeFieldKey, UuidValue?> attemptedValues,
  ) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeyEdgesByChildTable[tableName] ?? const <_ForeignKeyEdge>[])
        edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return;

    final visibleValuesByRowId = await _readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    final valuesByRowId = {
      for (final rowId in rowIds)
        rowId: {
          for (final columnName in foreignKeyColumns)
            columnName: attemptedValues.containsKey((tableName, rowId, columnName))
                ? attemptedValues[(tableName, rowId, columnName)]
                : visibleValuesByRowId[rowId]?[columnName],
        },
    };
    final attemptedColumns = <String>{};
    for (final values in valuesByRowId.values) {
      for (final columnName in foreignKeyColumns) {
        if (values[columnName] != null) {
          attemptedColumns.add(columnName);
        }
      }
    }
    if (attemptedColumns.isEmpty) return;

    final crdtRows = await _findCrdtRows(tableName, rowIds, transaction);
    if (crdtRows.isEmpty) return;

    final (_, columnsByName) = _schema[tableName]!;
    final columnIds = {
      for (final columnName in attemptedColumns)
        if (columnsByName[columnName]?.id != null)
          columnName: columnsByName[columnName]!.id!,
    };
    if (columnIds.isEmpty) return;

    final existingFields = await _findForeignKeyFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: columnIds.keys.toSet(),
      transaction: transaction,
    );
    final fieldsToInsert = <CrdtDataField>[];
    for (final crdtRow in crdtRows) {
      final values = valuesByRowId[crdtRow.uuidRowId];
      if (values == null) continue;

      for (final MapEntry(key: columnName, value: columnId) in columnIds.entries) {
        if (values[columnName] == null) continue;
        if (existingFields.containsKey((tableName, crdtRow.uuidRowId, columnName))) {
          continue;
        }

        fieldsToInsert.add(
          CrdtDataField(
            rowId: crdtRow.id!,
            columnId: columnId,
            nodeId: crdtRow.nodeId,
            hlcDatetime: crdtRow.hlcDatetime,
            hlcCounter: crdtRow.hlcCounter,
          ),
        );
      }
    }

    if (fieldsToInsert.isNotEmpty) {
      await CrdtDataField.db.insert(
        _session,
        fieldsToInsert,
        transaction: transaction,
      );
    }

    await _recordForeignKeyAttemptsForRows(
      tableName,
      rowIds,
      columnIds.keys.toSet(),
      transaction,
      attemptedValues: attemptedValues,
    );
  }

  Future<({Map<String, Object?> data, Map<_MergeFieldKey, UuidValue?> attempts})>
  _safeIncomingForeignKeyData(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
    Transaction transaction,
  ) async {
    final safeData = {...data};
    final attempts = <_MergeFieldKey, UuidValue?>{};

    for (final edge
        in _foreignKeyEdgesByChildTable[tableName] ?? const <_ForeignKeyEdge>[]) {
      if (!data.containsKey(edge.childColumn)) continue;

      final fieldKey = (tableName, rowId, edge.childColumn);
      final attemptedValue = _uuidValueFromDatabase(data[edge.childColumn]);
      attempts[fieldKey] = attemptedValue;
      if (attemptedValue == null) continue;

      if (await _foreignKeyTargetVisible(edge, attemptedValue, transaction)) {
        continue;
      }

      switch (edge.action) {
        case ForeignKeyAction.setNull:
          if (edge.childNullable) {
            safeData[edge.childColumn] = null;
          }
        case ForeignKeyAction.setDefault:
          final defaultProjection = await _defaultProjectionValueFromDatabase(
            edge,
            transaction,
          );
          if (defaultProjection.valid) {
            safeData[edge.childColumn] = defaultProjection.value;
          }
        case ForeignKeyAction.restrict:
        case ForeignKeyAction.noAction:
        case ForeignKeyAction.cascade:
          if (edge.childNullable) {
            safeData[edge.childColumn] = null;
          }
      }
    }

    return (data: safeData, attempts: attempts);
  }

  Future<Set<_MergeFieldKey>> _findImplicitForeignKeyRepairFields({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty) return const {};

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeyEdgesByChildTable[tableName] ?? const <_ForeignKeyEdge>[])
        edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return const {};

    final fieldIds = await _findForeignKeyFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );
    if (fieldIds.isEmpty) return const {};

    final projections = await _loadForeignKeyProjections(
      fieldIds.values.toSet(),
      transaction,
    );
    final activeOverrideFields = <_MergeFieldKey, _ForeignKeyProjectionRow>{};
    for (final MapEntry(key: fieldKey, value: fieldId) in fieldIds.entries) {
      final projection = projections[fieldId];
      if (projection == null || !projection.hasOverride) continue;
      activeOverrideFields[fieldKey] = projection;
    }
    if (activeOverrideFields.isEmpty) return const {};

    final valuesByRowId = await _readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    return {
      for (final MapEntry(key: fieldKey, value: projection)
          in activeOverrideFields.entries)
        if (_sameUuidValue(
          _uuidValueFromDatabase(valuesByRowId[fieldKey.$2]?[fieldKey.$3]),
          projection.visibleValue,
        ))
          fieldKey,
    };
  }

  /// Recomputes FK projection and materializes it into domain tables.
  ///
  /// Updates row visibility for cascade/restrict semantics, writes visible FK
  /// values to domain columns, and upserts [CrdtDataForeignKey] metadata with
  /// the durable attempted values. Called after inbound merge and local
  /// FK-affecting mutations.
  Future<void> _projectForeignKeys(Transaction transaction) async {
    if (_foreignKeyEdges.isEmpty) return;

    final state = await _loadForeignKeyProjectionState(transaction);
    if (state.rows.isEmpty) return;

    final currentHidden = {
      for (final row in state.rows.values)
        if (row.isHidden) row.key,
    };
    final userHidden = {
      for (final row in state.rows.values)
        if (row.userHidden) row.key,
    };
    final finalHidden = _computeForeignKeyHiddenRows(state, userHidden);

    await _materializeForeignKeyVisibility(
      state: state,
      currentHidden: currentHidden,
      finalHidden: finalHidden,
      transaction: transaction,
    );
    await _materializeForeignKeyValues(
      state: state,
      finalHidden: finalHidden,
      transaction: transaction,
    );
  }

  Future<_ForeignKeyProjectionState> _loadForeignKeyProjectionState(
    Transaction transaction,
  ) async {
    final rows = <_MergeRowKey, _ProjectedForeignKeyRow>{};
    final fieldIds = <_MergeFieldKey, int>{};
    final projections = <_MergeFieldKey, _ForeignKeyProjectionRow>{};
    final fkColumnsByTable = <String, Set<String>>{};

    for (final edge in _foreignKeyEdges) {
      fkColumnsByTable
          .putIfAbsent(edge.childTableName, () => {})
          .add(
            edge.childColumn,
          );
      if (edge.parentColumn != 'id') {
        fkColumnsByTable
            .putIfAbsent(edge.parentTableName, () => {})
            .add(
              edge.parentColumn,
            );
      }
    }

    for (final tableName in _syncTableByName.keys) {
      final (tableId, _) = _schema[tableName]!;
      final userId = _getHlcManager(transaction).normalizedUserId;
      final crdtRows = await CrdtDataRow.db.find(
        _session,
        where: (t) => t.userId.equals(userId) & t.tblId.equals(tableId),
        include: CrdtDataRow.include(deleted: CrdtDataDeleted.include()),
        orderBy: (t) => t.uuidRowId,
        transaction: transaction,
      );
      if (crdtRows.isEmpty) continue;

      final rowIds = {for (final row in crdtRows) row.uuidRowId};
      final columnNames = fkColumnsByTable[tableName] ?? const <String>{};
      final valuesByRowId = await _readDomainColumnValues(
        tableName,
        rowIds,
        columnNames.toList(),
        transaction,
      );

      for (final row in crdtRows) {
        final rowId = row.uuidRowId;
        final key = (tableName, rowId);
        rows[key] = _ProjectedForeignKeyRow(
          key: key,
          crdtRow: row,
          crdtRowId: row.id!,
          isHidden: row.isHidden,
          visibility: row.visibility,
          userHidden: row.deleted?.isDeleted ?? false,
          userDeletedReason: row.deleted?.reason,
          values: valuesByRowId[rowId] ?? const {},
        );
      }

      if (columnNames.isNotEmpty) {
        fieldIds.addAll(
          await _findForeignKeyFieldIds(
            tableName: tableName,
            rowIds: rowIds,
            columnNames: columnNames,
            transaction: transaction,
          ),
        );
      }
    }

    if (fieldIds.isNotEmpty) {
      final loadedProjections = await _loadForeignKeyProjections(
        fieldIds.values.toSet(),
        transaction,
      );
      for (final MapEntry(key: fieldKey, value: fieldId) in fieldIds.entries) {
        final projection = loadedProjections[fieldId];
        if (projection != null) {
          projections[fieldKey] = projection;
        }
      }
    }

    final rowsByTable = <String, List<_ProjectedForeignKeyRow>>{};
    for (final row in rows.values) {
      rowsByTable.putIfAbsent(row.key.$1, () => []).add(row);
    }

    final parentRowsByReference = <_ForeignKeyValueKey, _ProjectedForeignKeyRow>{};
    for (final edge in _foreignKeyEdges) {
      for (final parent
          in rowsByTable[edge.parentTableName] ?? const <_ProjectedForeignKeyRow>[]) {
        final value = _parentReferenceValue(parent, edge);
        if (value == null) continue;
        parentRowsByReference.putIfAbsent(
          (edge.parentTableName, edge.parentColumn, value.uuid),
          () => parent,
        );
      }
    }

    final childRowsByAttempt = <_ForeignKeyValueKey, List<_ProjectedForeignKeyRow>>{};
    for (final edge in _foreignKeyEdges) {
      for (final child
          in rowsByTable[edge.childTableName] ?? const <_ProjectedForeignKeyRow>[]) {
        final value = _attemptedForeignKeyValueFromProjections(
          child,
          edge,
          projections,
        );
        if (value == null) continue;
        childRowsByAttempt
            .putIfAbsent(
              (edge.childTableName, edge.childColumn, value.uuid),
              () => [],
            )
            .add(child);
      }
    }

    return _ForeignKeyProjectionState(
      rows: rows,
      rowsByTable: rowsByTable,
      fieldIds: fieldIds,
      projections: projections,
      parentRowsByReference: parentRowsByReference,
      childRowsByAttempt: childRowsByAttempt,
    );
  }

  Future<Map<_MergeFieldKey, int>> _findForeignKeyFieldIds({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Set<String> columnNames,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return {};

    final (tableId, _) = _schema[tableName]!;
    final userId = _getHlcManager(transaction).normalizedUserId;
    final fields = await CrdtDataField.db.find(
      _session,
      where: (t) =>
          t.row.userId.equals(userId) &
          t.row.tblId.equals(tableId) &
          t.row.uuidRowId.inSet(rowIds) &
          t.column.name.inSet(columnNames),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(),
        column: CrdtSchemaColumn.include(),
      ),
      transaction: transaction,
    );

    return {
      for (final field in fields)
        (
          tableName,
          field.row!.uuidRowId,
          field.column!.name,
        ): field.id!,
    };
  }

  Future<Map<int, _ForeignKeyProjectionRow>> _loadForeignKeyProjections(
    Set<int> fieldIds,
    Transaction transaction,
  ) async {
    if (fieldIds.isEmpty) return {};

    final projections = await CrdtDataForeignKey.db.find(
      _session,
      where: (t) => t.fieldId.inSet(fieldIds),
      transaction: transaction,
    );

    return {
      for (final projection in projections)
        projection.fieldId: _ForeignKeyProjectionRow(
          id: projection.id,
          fieldId: projection.fieldId,
          attemptedValue: projection.attemptedValue,
          visibleValue: projection.visibleValue,
          hasOverride: projection.hasOverride,
          overrideReason: projection.overrideReason,
        ),
    };
  }

  Set<_MergeRowKey> _computeForeignKeyHiddenRows(
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> userHidden,
  ) {
    final acceptedRoots = userHidden.toSet();

    while (true) {
      final closures = <_MergeRowKey, Set<_MergeRowKey>>{};
      final finalHidden = <_MergeRowKey>{};

      for (final root in acceptedRoots.toList()..sort(_compareRowKeys)) {
        if (finalHidden.contains(root)) continue;

        final closure = _cascadeClosureForDelete(root, state, <_MergeRowKey>{});
        closures[root] = closure;
        finalHidden.addAll(closure);
      }

      final missingParentHidden = _computeMissingParentHiddenRows(
        state,
        finalHidden,
      );
      final projectedHidden = {...finalHidden, ...missingParentHidden};

      final invalidRoots = <_MergeRowKey>{};
      for (final MapEntry(key: root, value: closure) in closures.entries) {
        if (_closureBlockedByForeignKeys(closure, state, projectedHidden)) {
          invalidRoots.add(root);
        }
      }

      if (invalidRoots.isEmpty) return projectedHidden;
      acceptedRoots.removeAll(invalidRoots);
    }
  }

  Set<_MergeRowKey> _computeMissingParentHiddenRows(
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> rootHidden,
  ) {
    final hidden = <_MergeRowKey>{};

    var changed = true;
    while (changed) {
      changed = false;

      for (final row in state.rows.values) {
        if (rootHidden.contains(row.key) || hidden.contains(row.key)) continue;

        if (_rowHasUnrepairableMissingParent(
          row,
          state,
          rootHidden,
          hidden,
        )) {
          hidden.add(row.key);
          changed = true;
        }
      }
    }

    return hidden;
  }

  bool _rowHasUnrepairableMissingParent(
    _ProjectedForeignKeyRow row,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> rootHidden,
    Set<_MergeRowKey> missingParentHidden,
  ) {
    for (final edge
        in _foreignKeyEdgesByChildTable[row.key.$1] ?? const <_ForeignKeyEdge>[]) {
      final attemptedValue = _attemptedForeignKeyValue(row, edge, state);
      if (attemptedValue == null) continue;

      final target = _parentRowForValue(edge, attemptedValue, state);
      final targetMissing = target == null;
      final targetHiddenByMissingParent =
          target != null && missingParentHidden.contains(target.key);
      if (!targetMissing && !targetHiddenByMissingParent) continue;

      if (!_canRepairForeignKey(edge, state, rootHidden, missingParentHidden)) {
        return true;
      }
    }

    return false;
  }

  bool _canRepairForeignKey(
    _ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> rootHidden,
    Set<_MergeRowKey> missingParentHidden,
  ) {
    switch (edge.action) {
      case ForeignKeyAction.setNull:
        return edge.childNullable;
      case ForeignKeyAction.setDefault:
        final defaultValue = _uuidValueFromDatabase(edge.defaultValue);
        if (defaultValue == null) return edge.childNullable;

        final target = _parentRowForValue(edge, defaultValue, state);
        return target != null &&
            !rootHidden.contains(target.key) &&
            !missingParentHidden.contains(target.key);
      case ForeignKeyAction.restrict:
      case ForeignKeyAction.noAction:
      case ForeignKeyAction.cascade:
        return false;
    }
  }

  Set<_MergeRowKey> _cascadeClosureForDelete(
    _MergeRowKey rowKey,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> stack,
  ) {
    if (stack.contains(rowKey)) return <_MergeRowKey>{};

    final row = state.rows[rowKey];
    if (row == null) return <_MergeRowKey>{};

    final closure = <_MergeRowKey>{rowKey};
    final nextStack = {...stack, rowKey};

    for (final edge
        in _foreignKeyEdgesByParentTable[rowKey.$1] ?? const <_ForeignKeyEdge>[]) {
      final parentValue = _parentReferenceValue(row, edge);
      if (parentValue == null) continue;

      final children = _childrenReferencingParent(
        edge,
        parentValue,
        state,
      );
      for (final child in children) {
        if (closure.contains(child.key)) continue;

        if (edge.action != ForeignKeyAction.cascade) continue;

        final childClosure = _cascadeClosureForDelete(
          child.key,
          state,
          nextStack,
        );
        closure.addAll(childClosure);
      }
    }

    return closure;
  }

  bool _closureBlockedByForeignKeys(
    Set<_MergeRowKey> closure,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> finalHidden,
  ) {
    for (final rowKey in closure) {
      final row = state.rows[rowKey];
      if (row == null) continue;

      for (final edge
          in _foreignKeyEdgesByParentTable[rowKey.$1] ?? const <_ForeignKeyEdge>[]) {
        final parentValue = _parentReferenceValue(row, edge);
        if (parentValue == null) continue;

        final children = _childrenReferencingParent(
          edge,
          parentValue,
          state,
        );
        for (final child in children) {
          if (finalHidden.contains(child.key)) continue;

          switch (edge.action) {
            case ForeignKeyAction.cascade:
              return true;
            case ForeignKeyAction.restrict:
            case ForeignKeyAction.noAction:
              return true;
            case ForeignKeyAction.setNull:
              if (!edge.childNullable) return true;
            case ForeignKeyAction.setDefault:
              if (!_defaultProjectionValue(edge, state, finalHidden).valid) {
                return true;
              }
          }
        }
      }
    }

    return false;
  }

  Future<void> _materializeForeignKeyVisibility({
    required _ForeignKeyProjectionState state,
    required Set<_MergeRowKey> currentHidden,
    required Set<_MergeRowKey> finalHidden,
    required Transaction transaction,
  }) async {
    final rowsToHide = finalHidden.difference(currentHidden);
    final rowsToShow = currentHidden.difference(finalHidden);

    await _setProjectedRowVisibility(
      rowsToHide,
      state: state,
      visibilityFor: (row) => row.userHidden
          ? (row.userDeletedReason == CrdtDataDeletedReason.userCascadeDelete)
                ? CrdtDataRowVisibility.userCascadeDelete
                : CrdtDataRowVisibility.userDelete
          : CrdtDataRowVisibility.foreignKeyCascade,
      transaction: transaction,
    );
    await _setProjectedRowVisibility(
      rowsToShow,
      state: state,
      visibilityFor: (row) => row.userHidden
          ? CrdtDataRowVisibility.foreignKeyRestrictRestore
          : CrdtDataRowVisibility.userInsert,
      transaction: transaction,
    );
  }

  Future<void> _setProjectedRowVisibility(
    Set<_MergeRowKey> rowKeys, {
    required _ForeignKeyProjectionState state,
    required CrdtDataRowVisibility Function(_ProjectedForeignKeyRow row) visibilityFor,
    required Transaction transaction,
  }) async {
    if (rowKeys.isEmpty) return;

    final toUpdate = <CrdtDataRow>[];
    for (final rowKey in rowKeys) {
      final projectedRow = state.rows[rowKey];
      if (projectedRow == null) continue;

      final visibility = visibilityFor(projectedRow);
      if (projectedRow.visibility == visibility) continue;

      toUpdate.add(projectedRow.crdtRow.copyWith(visibility: visibility));
    }

    if (toUpdate.isEmpty) return;

    await CrdtDataRow.db.update(
      _session,
      toUpdate,
      columns: (t) => [t.visibility],
      transaction: transaction,
    );
  }

  Future<void> _materializeForeignKeyValues({
    required _ForeignKeyProjectionState state,
    required Set<_MergeRowKey> finalHidden,
    required Transaction transaction,
  }) async {
    final changedUpdatesByRow = <_MergeRowKey, Map<String, Object?>>{};
    final projectionWrites = <_ForeignKeyProjectionWrite>[];

    for (final edge in _foreignKeyEdges) {
      for (final child
          in state.rowsByTable[edge.childTableName] ??
              const <_ProjectedForeignKeyRow>[]) {
        if (finalHidden.contains(child.key)) continue;

        final attemptedValue = _attemptedForeignKeyValue(child, edge, state);
        final currentVisibleValue = _uuidValueFromDatabase(
          child.values[edge.childColumn],
        );
        final projectionKey = (
          edge.childTableName,
          child.key.$2,
          edge.childColumn,
        );
        final existingProjection = state.projections[projectionKey];

        var desiredVisibleValue = attemptedValue;
        var hasOverride = false;
        CrdtForeignKeyOverrideReason? overrideReason;

        if (attemptedValue != null &&
            _foreignKeyTargetHiddenOrMissing(
              edge,
              attemptedValue,
              state,
              finalHidden,
            )) {
          switch (edge.action) {
            case ForeignKeyAction.setNull:
              if (edge.childNullable) {
                desiredVisibleValue = null;
                hasOverride = true;
                overrideReason = CrdtForeignKeyOverrideReason.setNull;
              }
            case ForeignKeyAction.setDefault:
              final defaultProjection = _defaultProjectionValue(
                edge,
                state,
                finalHidden,
              );
              if (defaultProjection.valid) {
                desiredVisibleValue = defaultProjection.value;
                hasOverride = true;
                overrideReason = CrdtForeignKeyOverrideReason.setDefault;
              }
            case ForeignKeyAction.restrict:
            case ForeignKeyAction.noAction:
            case ForeignKeyAction.cascade:
              break;
          }
        }

        if (!_sameUuidValue(currentVisibleValue, desiredVisibleValue)) {
          child.values[edge.childColumn] = desiredVisibleValue;
          changedUpdatesByRow.putIfAbsent(child.key, () => {})[edge.childColumn] =
              desiredVisibleValue;
        }

        final fieldId = state.fieldIds[projectionKey];
        if (fieldId == null || (!hasOverride && existingProjection == null)) {
          continue;
        }

        projectionWrites.add((
          fieldId: fieldId,
          attemptedValue: attemptedValue,
          visibleValue: hasOverride ? desiredVisibleValue : null,
          hasOverride: hasOverride,
          overrideReason: overrideReason,
        ));
      }
    }

    await _applyBatchedDomainRowUpdates(changedUpdatesByRow, transaction);
    await _upsertForeignKeyProjections(
      projectionWrites,
      transaction,
      existingProjections: {
        for (final projection in state.projections.values)
          projection.fieldId: projection,
      },
    );
    await _resolveUniqueConflictsAfterForeignKeyProjection(
      changedUpdatesByRow,
      transaction,
    );
  }

  Future<void> _applyBatchedDomainRowUpdates(
    Map<_MergeRowKey, Map<String, Object?>> updatesByRow,
    Transaction transaction,
  ) async {
    final grouped =
        <
          (String tableName, String signature),
          ({Map<String, Object?> updates, Set<UuidValue> rowIds})
        >{};

    for (final MapEntry(key: rowKey, value: updates) in updatesByRow.entries) {
      if (updates.isEmpty) continue;

      final sortedUpdates = Map<String, Object?>.fromEntries(
        updates.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      );
      final signature = sortedUpdates.entries
          .map((entry) => '${entry.key}:${_sqlLiteral(entry.value)}')
          .join('\x1f');
      final groupKey = (rowKey.$1, signature);

      final existing = grouped[groupKey];
      if (existing == null) {
        grouped[groupKey] = (updates: sortedUpdates, rowIds: {rowKey.$2});
      } else {
        existing.rowIds.add(rowKey.$2);
      }
    }

    for (final MapEntry(key: key, value: group) in grouped.entries) {
      await _updateDomainRows(
        key.$1,
        group.rowIds,
        group.updates,
        transaction,
      );
    }
  }

  Future<void> _resolveUniqueConflictsAfterForeignKeyProjection(
    Map<_MergeRowKey, Map<String, Object?>> changedUpdatesByRow,
    Transaction transaction,
  ) async {
    if (changedUpdatesByRow.isEmpty) return;

    final rowIdsByTable = <String, Set<UuidValue>>{};
    for (final rowKey in changedUpdatesByRow.keys) {
      rowIdsByTable.putIfAbsent(rowKey.$1, () => {}).add(rowKey.$2);
    }

    final rowsByKey = <_MergeRowKey, CrdtDataRow>{};
    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final crdtRows = await _findCrdtRows(tableName, rowIds, transaction);
      for (final row in crdtRows) {
        rowsByKey[(tableName, row.uuidRowId)] = row;
      }
    }

    final context = (
      rows: <_MergeRowKey, CrdtDataRow>{},
      fields: <_MergeFieldKey, CrdtDataField>{},
      incomingFieldHlcs: <_MergeFieldKey, Hlc>{},
      tombstones: <_MergeRowKey, CrdtDataDeleted>{},
    );

    for (final MapEntry(key: rowKey, value: updates) in changedUpdatesByRow.entries) {
      final row = rowsByKey[rowKey];
      if (row == null) continue;

      final resolvedUpdates = await _uniqueConflictResolver._resolveForIncomingUpdates(
        tableName: rowKey.$1,
        row: row,
        updates: updates,
        context: context,
        transaction: transaction,
      );
      if (resolvedUpdates == updates || resolvedUpdates.isEmpty) continue;

      await _updateDomainRows(
        rowKey.$1,
        {rowKey.$2},
        resolvedUpdates,
        transaction,
      );
    }
  }

  UuidValue? _attemptedForeignKeyValue(
    _ProjectedForeignKeyRow child,
    _ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
  ) {
    return _attemptedForeignKeyValueFromProjections(
      child,
      edge,
      state.projections,
    );
  }

  UuidValue? _attemptedForeignKeyValueFromProjections(
    _ProjectedForeignKeyRow child,
    _ForeignKeyEdge edge,
    Map<_MergeFieldKey, _ForeignKeyProjectionRow> projections,
  ) {
    final projection =
        projections[(
          edge.childTableName,
          child.key.$2,
          edge.childColumn,
        )];
    if (projection != null && projection.hasOverride) {
      return projection.attemptedValue;
    }

    return _uuidValueFromDatabase(child.values[edge.childColumn]);
  }

  bool _foreignKeyTargetHiddenOrMissing(
    _ForeignKeyEdge edge,
    UuidValue value,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> hidden,
  ) {
    final target = _parentRowForValue(edge, value, state);
    return target == null || hidden.contains(target.key);
  }

  ({bool valid, UuidValue? value}) _defaultProjectionValue(
    _ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
    Set<_MergeRowKey> hidden,
  ) {
    final defaultValue = _uuidValueFromDatabase(edge.defaultValue);
    if (defaultValue == null) {
      return (valid: edge.childNullable, value: null);
    }

    final target = _parentRowForValue(edge, defaultValue, state);
    if (target == null || hidden.contains(target.key)) {
      return (valid: false, value: null);
    }

    return (valid: true, value: defaultValue);
  }

  Future<bool> _foreignKeyTargetVisible(
    _ForeignKeyEdge edge,
    UuidValue value,
    Transaction transaction,
  ) async {
    final predicate = edge.parentColumn == 'id'
        ? 'd."id" = ${_sqlLiteral(value)}'
        : 'd."${_escapeIdentifier(edge.parentColumn)}" = ${_sqlLiteral(value)}';
    final rowIds = await _findVisibleDomainRowIdsWhere(
      tableName: edge.parentTableName,
      predicates: [predicate],
      transaction: transaction,
    );
    return rowIds.isNotEmpty;
  }

  Future<({bool valid, UuidValue? value})> _defaultProjectionValueFromDatabase(
    _ForeignKeyEdge edge,
    Transaction transaction,
  ) async {
    final defaultValue = _uuidValueFromDatabase(edge.defaultValue);
    if (defaultValue == null) {
      return (valid: edge.childNullable, value: null);
    }

    final targetVisible = await _foreignKeyTargetVisible(
      edge,
      defaultValue,
      transaction,
    );
    if (!targetVisible) return (valid: false, value: null);

    return (valid: true, value: defaultValue);
  }

  UuidValue? _parentReferenceValue(
    _ProjectedForeignKeyRow parent,
    _ForeignKeyEdge edge,
  ) {
    if (edge.parentColumn == 'id') return parent.key.$2;
    return _uuidValueFromDatabase(parent.values[edge.parentColumn]);
  }

  _ProjectedForeignKeyRow? _parentRowForValue(
    _ForeignKeyEdge edge,
    UuidValue value,
    _ForeignKeyProjectionState state,
  ) {
    return state.parentRowsByReference[(
      edge.parentTableName,
      edge.parentColumn,
      value.uuid,
    )];
  }

  List<_ProjectedForeignKeyRow> _childrenReferencingParent(
    _ForeignKeyEdge edge,
    UuidValue parentValue,
    _ForeignKeyProjectionState state,
  ) {
    return state.childRowsByAttempt[(
          edge.childTableName,
          edge.childColumn,
          parentValue.uuid,
        )] ??
        const <_ProjectedForeignKeyRow>[];
  }

  Future<void> _upsertForeignKeyProjections(
    List<_ForeignKeyProjectionWrite> writes,
    Transaction transaction, {
    Map<int, _ForeignKeyProjectionRow> existingProjections = const {},
  }) async {
    if (writes.isEmpty) return;

    final writeByFieldId = {
      for (final write in writes) write.fieldId: write,
    };
    var existingByFieldId = existingProjections;
    final missingFieldIds = writeByFieldId.keys
        .where((fieldId) => !existingByFieldId.containsKey(fieldId))
        .toSet();
    if (missingFieldIds.isNotEmpty) {
      existingByFieldId = {
        ...existingByFieldId,
        ...await _loadForeignKeyProjections(missingFieldIds, transaction),
      };
    }

    final toInsert = <CrdtDataForeignKey>[];
    final toUpdate = <CrdtDataForeignKey>[];

    for (final write in writeByFieldId.values) {
      final existing = existingByFieldId[write.fieldId];
      if (existing != null && _foreignKeyProjectionMatches(existing, write)) {
        continue;
      }

      final projection = CrdtDataForeignKey(
        id: existing?.id,
        fieldId: write.fieldId,
        attemptedValue: write.attemptedValue,
        visibleValue: write.visibleValue,
        hasOverride: write.hasOverride,
        overrideReason: write.overrideReason,
      );

      if (existing == null) {
        toInsert.add(projection);
      } else {
        toUpdate.add(projection);
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataForeignKey.db.insert(
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataForeignKey.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  bool _foreignKeyProjectionMatches(
    _ForeignKeyProjectionRow existing,
    _ForeignKeyProjectionWrite write,
  ) {
    return _sameUuidValue(existing.attemptedValue, write.attemptedValue) &&
        _sameUuidValue(existing.visibleValue, write.visibleValue) &&
        existing.hasOverride == write.hasOverride &&
        existing.overrideReason == write.overrideReason;
  }

  UuidValue? _uuidValueFromDatabase(Object? value) {
    if (value == null) return null;
    if (value is UuidValue) return value;
    if (value is String) return UuidValue.withValidation(value);
    return UuidValueJsonExtension.fromJson(value);
  }

  bool _sameUuidValue(UuidValue? left, UuidValue? right) {
    return left?.uuid == right?.uuid;
  }

  int _compareRowKeys(_MergeRowKey left, _MergeRowKey right) {
    final tableComparison = left.$1.compareTo(right.$1);
    if (tableComparison != 0) return tableComparison;
    return left.$2.uuid.compareTo(right.$2.uuid);
  }
}
