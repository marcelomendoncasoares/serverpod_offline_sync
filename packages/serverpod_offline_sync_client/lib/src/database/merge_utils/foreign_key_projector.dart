part of '../recorder.dart';

class _ProjectedForeignKeyRow {
  _ProjectedForeignKeyRow({
    required this.key,
    required this.crdtRowId,
    required this.isHidden,
    required this.deletedReason,
    required this.preservedBaseDeletedReason,
    required this.values,
  });

  final _MergeRowKey key;
  final int crdtRowId;
  final bool isHidden;
  final CrdtDataDeletedReason? deletedReason;
  final CrdtDataDeletedReason? preservedBaseDeletedReason;
  final Map<String, Object?> values;
}

class _ForeignKeyProjectionRow {
  _ForeignKeyProjectionRow({
    required this.fieldId,
    required this.attemptedValue,
    required this.visibleValue,
    required this.hasOverride,
  });

  final int fieldId;
  final UuidValue? attemptedValue;
  final UuidValue? visibleValue;
  final bool hasOverride;
}

class _ForeignKeyProjectionState {
  _ForeignKeyProjectionState({
    required this.rows,
    required this.fieldIds,
    required this.projections,
  });

  final Map<_MergeRowKey, _ProjectedForeignKeyRow> rows;
  final Map<_MergeFieldKey, int> fieldIds;
  final Map<_MergeFieldKey, _ForeignKeyProjectionRow> projections;
}

extension _CrdtForeignKeyProjector on CrdtMutationRecorder {
  Future<void> _recordForeignKeyAttemptsForRows(
    String tableName,
    Set<UuidValue> rowIds,
    Set<String>? columnNames,
    Transaction transaction, {
    Set<_MergeFieldKey> skippedFields = const {},
  }) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge in _foreignKeyEdges)
        if (edge.childTableName == tableName &&
            (columnNames == null || columnNames.contains(edge.childColumn)))
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

    for (final rowId in rowIds) {
      final values = valuesByRowId[rowId];
      if (values == null) continue;

      for (final columnName in foreignKeyColumns) {
        final fieldId = fieldIds[(tableName, rowId, columnName)];
        if (fieldId == null) continue;
        if (skippedFields.contains((tableName, rowId, columnName))) continue;

        final attemptedValue = _uuidValueFromDatabase(values[columnName]);
        await _upsertForeignKeyProjection(
          fieldId: fieldId,
          attemptedValue: attemptedValue,
          visibleValue: attemptedValue,
          hasOverride: false,
          overrideReason: null,
          transaction: transaction,
        );
      }
    }
  }

  Future<void> _recordForeignKeyInsertAttempts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge in _foreignKeyEdges)
        if (edge.childTableName == tableName) edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return;

    final valuesByRowId = await _readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
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
    );
  }

  Future<Set<_MergeFieldKey>> _findImplicitForeignKeyRepairFields({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty) return const {};

    final foreignKeyColumns = {
      for (final edge in _foreignKeyEdges)
        if (edge.childTableName == tableName) edge.childColumn,
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

  Future<void> _projectForeignKeys(Transaction transaction) async {
    if (_foreignKeyEdges.isEmpty) return;

    final state = await _loadForeignKeyProjectionState(transaction);
    if (state.rows.isEmpty) return;

    final currentHidden = {
      for (final row in state.rows.values)
        if (row.isHidden) row.key,
    };
    final baseHidden = {
      for (final row in state.rows.values)
        if (_isBaseHiddenRow(row, state)) row.key,
    };
    final finalHidden = _computeForeignKeyHiddenRows(state, baseHidden);

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
        include: CrdtDataRow.include(
          deleted: CrdtDataDeleted.include(),
          foreignKeyBaseTombstone: CrdtDataForeignKeyBaseTombstone.include(),
        ),
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
          crdtRowId: row.id!,
          isHidden: row.deleted?.isDeleted ?? false,
          deletedReason: row.deleted?.reason,
          preservedBaseDeletedReason: row.foreignKeyBaseTombstone?.reason,
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

    return _ForeignKeyProjectionState(
      rows: rows,
      fieldIds: fieldIds,
      projections: projections,
    );
  }

  bool _isBaseHiddenRow(
    _ProjectedForeignKeyRow row,
    _ForeignKeyProjectionState state,
  ) {
    final preservedBaseReason = _projectionRestoredBaseReason(row);
    if (preservedBaseReason != null) {
      if (preservedBaseReason != CrdtDataDeletedReason.cascadeDelete) return true;
      return !_hasCascadeParentReference(row, state);
    }

    if (!row.isHidden) return false;
    if (row.deletedReason != CrdtDataDeletedReason.cascadeDelete) return true;
    return !_hasCascadeParentReference(row, state);
  }

  CrdtDataDeletedReason? _projectionRestoredBaseReason(
    _ProjectedForeignKeyRow row,
  ) {
    if (row.isHidden) return null;
    if (row.deletedReason != CrdtDataDeletedReason.restrictRestore) return null;
    return row.preservedBaseDeletedReason;
  }

  bool _hasCascadeParentReference(
    _ProjectedForeignKeyRow row,
    _ForeignKeyProjectionState state,
  ) {
    for (final edge in _foreignKeyEdges.where(
      (edge) =>
          edge.action == ForeignKeyAction.cascade && edge.childTableName == row.key.$1,
    )) {
      final attemptedValue = _attemptedForeignKeyValue(row, edge, state);
      if (attemptedValue == null) continue;
      if (_parentRowForValue(edge, attemptedValue, state) != null) {
        return true;
      }
    }
    return false;
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
          fieldId: projection.fieldId,
          attemptedValue: projection.attemptedValue,
          visibleValue: projection.visibleValue,
          hasOverride: projection.hasOverride,
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

      final invalidRoots = <_MergeRowKey>{};
      for (final MapEntry(key: root, value: closure) in closures.entries) {
        if (_closureBlockedByForeignKeys(closure, state, finalHidden)) {
          invalidRoots.add(root);
        }
      }

      if (invalidRoots.isEmpty) return finalHidden;
      acceptedRoots.removeAll(invalidRoots);
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

    for (final edge in _foreignKeyEdges.where(
      (edge) => edge.parentTableName == rowKey.$1,
    )) {
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

      for (final edge in _foreignKeyEdges.where(
        (edge) => edge.parentTableName == rowKey.$1,
      )) {
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
    final rowsToRestore = currentHidden.difference(finalHidden);
    final rowsToRestoreWithBase = <_MergeRowKey>{};
    for (final rowKey in rowsToRestore) {
      final row = state.rows[rowKey];
      if (row != null && _isBaseHiddenRow(row, state)) {
        rowsToRestoreWithBase.add(rowKey);
      }
    }
    final rowsToHideByReason = <CrdtDataDeletedReason, Set<_MergeRowKey>>{};
    for (final rowKey in rowsToHide) {
      final row = state.rows[rowKey];
      final reason = row == null ? null : _projectionRestoredBaseReason(row);
      rowsToHideByReason
          .putIfAbsent(reason ?? CrdtDataDeletedReason.cascadeDelete, () => {})
          .add(rowKey);
    }

    await _preserveBaseTombstones(rowsToRestoreWithBase, transaction);
    for (final MapEntry(key: reason, value: rowKeys) in rowsToHideByReason.entries) {
      await _markProjectionRowsDeleted(
        rowKeys,
        isDeleted: true,
        reason: reason,
        transaction: transaction,
      );
    }
    await _deletePreservedBaseTombstones(rowsToHide, transaction);
    await _markProjectionRowsDeleted(
      rowsToRestore,
      isDeleted: false,
      reason: CrdtDataDeletedReason.restrictRestore,
      transaction: transaction,
    );
  }

  Future<void> _preserveBaseTombstones(
    Set<_MergeRowKey> rowKeys,
    Transaction transaction,
  ) async {
    if (rowKeys.isEmpty) return;

    final rowIdsByTable = <String, Set<UuidValue>>{};
    for (final rowKey in rowKeys) {
      rowIdsByTable.putIfAbsent(rowKey.$1, () => {}).add(rowKey.$2);
    }

    final toInsert = <CrdtDataForeignKeyBaseTombstone>[];
    final toUpdate = <CrdtDataForeignKeyBaseTombstone>[];

    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final crdtRows = await _findCrdtRows(
        tableName,
        rowIds,
        transaction,
        include: CrdtDataRow.include(deleted: CrdtDataDeleted.include()),
      );
      if (crdtRows.isEmpty) continue;

      final rowPks = crdtRows.map((row) => row.id!).toSet();
      final existingByRowId = {
        for (final tombstone in await CrdtDataForeignKeyBaseTombstone.db.find(
          _session,
          where: (t) => t.rowId.inSet(rowPks),
          transaction: transaction,
        ))
          tombstone.rowId: tombstone,
      };

      for (final row in crdtRows) {
        final tombstone = row.deleted;
        if (tombstone == null) continue;

        final candidate = CrdtDataForeignKeyBaseTombstone(
          rowId: row.id!,
          nodeId: tombstone.nodeId,
          hlcDatetime: tombstone.hlcDatetime,
          hlcCounter: tombstone.hlcCounter,
          clFlag: tombstone.clFlag,
          reason: tombstone.reason,
        );
        final existing = existingByRowId[row.id];
        if (existing == null) {
          toInsert.add(candidate);
          continue;
        }

        if (existing.nodeId != candidate.nodeId ||
            existing.hlcDatetime != candidate.hlcDatetime ||
            existing.hlcCounter != candidate.hlcCounter ||
            existing.clFlag != candidate.clFlag ||
            existing.reason != candidate.reason) {
          toUpdate.add(candidate.copyWith(id: existing.id));
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataForeignKeyBaseTombstone.db.insert(
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataForeignKeyBaseTombstone.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  Future<void> _deletePreservedBaseTombstones(
    Set<_MergeRowKey> rowKeys,
    Transaction transaction,
  ) async {
    if (rowKeys.isEmpty) return;

    final rowIdsByTable = <String, Set<UuidValue>>{};
    for (final rowKey in rowKeys) {
      rowIdsByTable.putIfAbsent(rowKey.$1, () => {}).add(rowKey.$2);
    }

    final toDelete = <CrdtDataForeignKeyBaseTombstone>[];
    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final crdtRows = await _findCrdtRows(tableName, rowIds, transaction);
      if (crdtRows.isEmpty) continue;

      final rowPks = crdtRows.map((row) => row.id!).toSet();
      toDelete.addAll(
        await CrdtDataForeignKeyBaseTombstone.db.find(
          _session,
          where: (t) => t.rowId.inSet(rowPks),
          transaction: transaction,
        ),
      );
    }

    if (toDelete.isNotEmpty) {
      await CrdtDataForeignKeyBaseTombstone.db.delete(
        _session,
        toDelete,
        transaction: transaction,
      );
    }
  }

  Future<void> _markProjectionRowsDeleted(
    Set<_MergeRowKey> rowKeys, {
    required bool isDeleted,
    required CrdtDataDeletedReason reason,
    required Transaction transaction,
  }) async {
    if (rowKeys.isEmpty) return;

    final rowIdsByTable = <String, Set<UuidValue>>{};
    for (final rowKey in rowKeys) {
      rowIdsByTable.putIfAbsent(rowKey.$1, () => {}).add(rowKey.$2);
    }

    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final crdtRows = await _findCrdtRows(
        tableName,
        rowIds,
        transaction,
        include: CrdtDataRow.include(deleted: CrdtDataDeleted.include()),
      );
      final rowsToUpdate = crdtRows
          .where((row) => row.deleted?.isDeleted != isDeleted)
          .toList();
      await _markCrdtRowsDeleted(rowsToUpdate, isDeleted, reason, transaction);
    }
  }

  Future<void> _materializeForeignKeyValues({
    required _ForeignKeyProjectionState state,
    required Set<_MergeRowKey> finalHidden,
    required Transaction transaction,
  }) async {
    final changedUpdatesByRow = <_MergeRowKey, Map<String, Object?>>{};

    for (final edge in _foreignKeyEdges) {
      for (final child in state.rows.values.where(
        (row) => row.key.$1 == edge.childTableName,
      )) {
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
          await _updateDomainRows(
            edge.childTableName,
            {child.key.$2},
            {edge.childColumn: desiredVisibleValue},
            transaction,
          );
          child.values[edge.childColumn] = desiredVisibleValue;
          changedUpdatesByRow.putIfAbsent(child.key, () => {})[edge.childColumn] =
              desiredVisibleValue;
        }

        final fieldId = state.fieldIds[projectionKey];
        if (fieldId == null || (!hasOverride && existingProjection == null)) {
          continue;
        }

        await _upsertForeignKeyProjection(
          fieldId: fieldId,
          attemptedValue: attemptedValue,
          visibleValue: desiredVisibleValue,
          hasOverride: hasOverride,
          overrideReason: overrideReason,
          transaction: transaction,
        );
      }
    }

    await _resolveUniqueConflictsAfterForeignKeyProjection(
      changedUpdatesByRow,
      transaction,
    );
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
    final projection =
        state.projections[(
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
    for (final row in state.rows.values) {
      if (row.key.$1 != edge.parentTableName) continue;
      final parentValue = _parentReferenceValue(row, edge);
      if (_sameUuidValue(parentValue, value)) return row;
    }

    return null;
  }

  List<_ProjectedForeignKeyRow> _childrenReferencingParent(
    _ForeignKeyEdge edge,
    UuidValue parentValue,
    _ForeignKeyProjectionState state,
  ) {
    return [
      for (final row in state.rows.values)
        if (row.key.$1 == edge.childTableName &&
            _sameUuidValue(
              _attemptedForeignKeyValue(row, edge, state),
              parentValue,
            ))
          row,
    ];
  }

  Future<void> _upsertForeignKeyProjection({
    required int fieldId,
    required UuidValue? attemptedValue,
    required UuidValue? visibleValue,
    required bool hasOverride,
    required CrdtForeignKeyOverrideReason? overrideReason,
    required Transaction transaction,
  }) async {
    final existing = await CrdtDataForeignKey.db.findFirstRow(
      _session,
      where: (t) => t.fieldId.equals(fieldId),
      transaction: transaction,
    );

    final projection = CrdtDataForeignKey(
      fieldId: fieldId,
      attemptedValue: attemptedValue,
      visibleValue: visibleValue,
      hasOverride: hasOverride,
      overrideReason: overrideReason,
    );

    if (existing == null) {
      await CrdtDataForeignKey.db.insertRow(
        _session,
        projection,
        transaction: transaction,
      );
      return;
    }

    if (_sameUuidValue(existing.attemptedValue, attemptedValue) &&
        _sameUuidValue(existing.visibleValue, visibleValue) &&
        existing.hasOverride == hasOverride &&
        existing.overrideReason == overrideReason) {
      return;
    }

    await CrdtDataForeignKey.db.updateRow(
      _session,
      projection.copyWith(id: existing.id),
      transaction: transaction,
    );
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
