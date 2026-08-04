import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/extensions.dart';
import '../../crdt/sync.dart';
import '../../generated/protocol.dart';
import '../../hlc/hlc.dart';
import 'database_helpers.dart';
import 'foreign_key_graph.dart';
import 'recorder_context.dart';
import 'types.dart';
import 'unique_resolver.dart';

typedef _ProjectedForeignKeyRow = ({
  MergeRowKey key,
  CrdtDataRow crdtRow,
  Map<String, Object?> values,
});

@internal
typedef ForeignKeyAttempt = ({
  UuidValue? value,
  CrdtForeignKeyOverrideReason? reason,
});

@internal
typedef ForeignKeyAttemptsByField = Map<MergeFieldKey, ForeignKeyAttempt>;

typedef _ForeignKeyProjectionState = ({
  Map<MergeRowKey, _ProjectedForeignKeyRow> rows,
  Map<String, List<_ProjectedForeignKeyRow>> rowsByTable,
  Map<MergeFieldKey, int> fieldIds,
  Map<MergeFieldKey, CrdtDataForeignKey> projections,
  Map<ForeignKeyValueKey, _ProjectedForeignKeyRow> parentRowsByReference,
  Map<ForeignKeyValueKey, List<_ProjectedForeignKeyRow>> childRowsByAttempt,
});

@internal
typedef SafeIncomingForeignKeyData = ({
  Map<String, Object?> data,
  ForeignKeyAttemptsByField attempts,
});

typedef _ForeignKeyDefaultProjection = ({bool valid, UuidValue? value});

typedef _DomainRowUpdatesByKey = Map<MergeRowKey, Map<String, Object?>>;

/// Computes and materializes the foreign key projection for CRDT rows.
///
/// Tracks the durable attempted foreign key values, repairs references to
/// hidden or missing parents according to the declared actions, and updates
/// row visibility for cascade/restrict semantics.
@internal
class CrdtForeignKeyProjector {
  /// Creates a projector over the given recorder context.
  CrdtForeignKeyProjector(
    this._context, {
    required CrdtForeignKeyGraph foreignKeys,
    required CrdtUniqueConflictResolver uniqueResolver,
  }) : _foreignKeys = foreignKeys,
       _uniqueResolver = uniqueResolver;

  final CrdtRecorderContext _context;
  final CrdtForeignKeyGraph _foreignKeys;
  final CrdtUniqueConflictResolver _uniqueResolver;

  Future<void> assertVisibleTargets<T extends TableRow>(
    List<T> rows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;

    final tableName = rows.first.table.tableName;
    if (!_context.isCrdtTrackedTableName(tableName)) return;
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return;

    final updatedColumnNames = columns?.map((column) => column.columnName).toSet();
    final foreignKeysToCheck = [
      for (final foreignKey in tableDefinition.foreignKeys)
        if (foreignKey.columns.length == 1 &&
            foreignKey.referenceColumns.length == 1 &&
            (updatedColumnNames == null ||
                updatedColumnNames.contains(foreignKey.columns.single)) &&
            _context.isCrdtTrackedTableName(foreignKey.referenceTable))
          foreignKey,
    ];
    if (foreignKeysToCheck.isEmpty) return;

    final invalid = await _context.findInvalidForeignKeyReference(
      childTableName: tableName,
      childRowIds: rows.uuidRowIds,
      foreignKeys: foreignKeysToCheck,
      transaction: transaction,
    );
    if (invalid == null) return;

    final foreignKey = foreignKeysToCheck[invalid.foreignKeyIndex];
    throw Exception(
      'Cannot reference deleted row ${foreignKey.referenceTable}.'
      '${foreignKey.referenceColumns.single} = ${invalid.value}.',
    );
  }

  Future<Map<String, Set<UuidValue>>> applyDeleteActions(
    String parentTableName,
    Set<UuidValue> parentIds,
    Transaction transaction,
    Set<String> processing,
  ) async {
    if (parentIds.isEmpty) return {};

    final cascadeDeletes = <String, Set<UuidValue>>{};
    final foreignKeys =
        _foreignKeys.referencingKeysByParentTable[parentTableName] ??
        const <ReferencingForeignKey>[];
    for (final reference in foreignKeys) {
      final parentValuesById = reference.parentColumn == 'id'
          ? null
          : await _context.readDomainColumnValues(
              parentTableName,
              parentIds,
              [reference.parentColumn],
              transaction,
            );

      for (final parentId in parentIds) {
        final referencedValue = reference.parentColumn == 'id'
            ? parentId
            : parentValuesById?[parentId]?[reference.parentColumn];
        final childIds = await _context.findVisibleReferencingRowIds(
          tableName: reference.childTableName,
          columnName: reference.childColumn,
          value: referencedValue,
          transaction: transaction,
        );
        if (childIds.isEmpty) continue;

        switch (reference.action) {
          case ForeignKeyAction.restrict:
          case ForeignKeyAction.noAction:
            throw Exception(
              'Cannot delete $parentTableName row because '
              '${reference.childTableName}.${reference.childColumn} references it.',
            );
          case ForeignKeyAction.setNull:
            await _context.updateDomainRows(
              reference.childTableName,
              childIds,
              {reference.childColumn: null},
              transaction,
            );
            await _context.recordFieldsUpdatedByTable(
              reference.childTableName,
              childIds,
              [reference.childColumn],
              transaction,
            );
          case ForeignKeyAction.setDefault:
            final defaultValue = _context.defaultValueForColumn(
              reference.childTableName,
              reference.childColumn,
            );
            if (defaultValue == null) {
              throw StateError(
                'No default value found for '
                '${reference.childTableName}.${reference.childColumn}.',
              );
            }
            await _context.updateDomainRows(
              reference.childTableName,
              childIds,
              {reference.childColumn: defaultValue},
              transaction,
            );
            await _context.recordFieldsUpdatedByTable(
              reference.childTableName,
              childIds,
              [reference.childColumn],
              transaction,
            );
          case ForeignKeyAction.cascade:
            cascadeDeletes
                .putIfAbsent(reference.childTableName, () => {})
                .addAll(childIds);
        }
      }
    }

    return cascadeDeletes;
  }

  bool mergeOperationsMayAffectForeignKeys(
    List<CrdtMergeChange> operations,
  ) {
    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName)) continue;

      switch (operation) {
        case final CrdtMergeUpdate update:
          if (_foreignKeys.columnsMayAffectForeignKeys(
            update.tableName,
            {update.columnName},
          )) {
            return true;
          }
        case CrdtMergeInsert() || CrdtMergeDelete():
          if (_foreignKeys.columnsMayAffectForeignKeys(operation.tableName, null)) {
            return true;
          }
      }
    }

    return false;
  }

  Future<void> recordAttemptsForRows(
    String tableName,
    Set<UuidValue> rowIds,
    Set<String>? columnNames,
    Transaction transaction, {
    Set<MergeFieldKey> skippedFields = const {},
    ForeignKeyAttemptsByField attemptedValues = const {},
  }) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[])
        if (columnNames == null || columnNames.contains(edge.childColumn))
          edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return;

    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    final fieldIds = await _findFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );

    final projectionWrites = <CrdtDataForeignKey>[];
    for (final rowId in rowIds) {
      final values = valuesByRowId[rowId];
      if (values == null) continue;

      for (final columnName in foreignKeyColumns) {
        final fieldId = fieldIds[(tableName, rowId, columnName)];
        if (fieldId == null) continue;
        if (skippedFields.contains((tableName, rowId, columnName))) continue;

        final fieldKey = (tableName, rowId, columnName);
        final visibleValue = uuidValueFromDatabase(values[columnName]);
        final attempt = attemptedValues[fieldKey];
        final attemptedValue = attempt != null ? attempt.value : visibleValue;
        final overrideActive = !sameUuidValue(attemptedValue, visibleValue);

        CrdtForeignKeyOverrideReason? overrideReason;
        if (overrideActive) {
          overrideReason = attempt?.reason;
          if (overrideReason == null) {
            throw StateError(
              'FK projection override active for $tableName.$columnName '
              'on row $rowId but no reason was provided. All override-producing '
              'paths must supply a reason via safeIncomingData.',
            );
          }
        }

        projectionWrites.add(
          CrdtDataForeignKey(
            fieldId: fieldId,
            attemptedValue: attemptedValue,
            visibleValue: overrideActive ? visibleValue : null,
            overrideReason: overrideReason,
          ),
        );
      }
    }

    await _upsertProjections(projectionWrites, transaction);
  }

  Future<void> recordInsertAttempts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    ForeignKeyAttemptsByField attemptedValues,
  ) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[])
        edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return;

    final visibleValuesByRowId = await _context.readDomainColumnValues(
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
                ? attemptedValues[(tableName, rowId, columnName)]!.value
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

    final crdtRows = await _context.findCrdtRows(tableName, rowIds, transaction);
    if (crdtRows.isEmpty) return;

    final columnIds = _context.schemaColumnIds(tableName, attemptedColumns);
    if (columnIds.isEmpty) return;

    final existingFields = await _findFieldIds(
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
        _context.databaseSession,
        fieldsToInsert,
        transaction: transaction,
      );
    }

    await recordAttemptsForRows(
      tableName,
      rowIds,
      columnIds.keys.toSet(),
      transaction,
      attemptedValues: attemptedValues,
    );
  }

  Future<SafeIncomingForeignKeyData> safeIncomingData(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
    Transaction transaction,
  ) async {
    final safeData = {...data};
    final attempts = <MergeFieldKey, ForeignKeyAttempt>{};

    for (final edge
        in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[]) {
      if (!data.containsKey(edge.childColumn)) continue;

      final fieldKey = (tableName, rowId, edge.childColumn);
      final attemptedValue = uuidValueFromDatabase(data[edge.childColumn]);
      attempts[fieldKey] = (value: attemptedValue, reason: null);
      if (attemptedValue == null) continue;

      final targetPresence = await _context.lookupForeignKeyTargetPresence(
        parentTableName: edge.parentTableName,
        parentColumn: edge.parentColumn,
        value: attemptedValue,
        transaction: transaction,
      );
      if (targetPresence == ForeignKeyTargetPresence.visible ||
          (targetPresence == ForeignKeyTargetPresence.hidden &&
              edge.action == ForeignKeyAction.cascade)) {
        continue;
      }

      switch (edge.action) {
        case ForeignKeyAction.setNull:
          if (edge.childNullable) {
            safeData[edge.childColumn] = null;
            attempts[fieldKey] = (
              value: attemptedValue,
              reason: CrdtForeignKeyOverrideReason.setNull,
            );
          }
        case ForeignKeyAction.setDefault:
          final defaultProjection = await _defaultProjectionValueFromDatabase(
            edge,
            transaction,
          );
          if (defaultProjection.valid) {
            safeData[edge.childColumn] = defaultProjection.value;
            attempts[fieldKey] = (
              value: attemptedValue,
              reason: CrdtForeignKeyOverrideReason.setDefault,
            );
          }
        case ForeignKeyAction.restrict:
        case ForeignKeyAction.noAction:
        case ForeignKeyAction.cascade:
          if (edge.childNullable) {
            safeData[edge.childColumn] = null;
          }
          attempts[fieldKey] = (
            value: attemptedValue,
            reason: CrdtForeignKeyOverrideReason.missingParent,
          );
      }
    }

    return (data: safeData, attempts: attempts);
  }

  Future<Set<MergeFieldKey>> findImplicitRepairFields({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty) return const {};

    final foreignKeyColumns = {
      for (final edge
          in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[])
        edge.childColumn,
    };
    if (foreignKeyColumns.isEmpty) return const {};

    final fieldIds = await _findFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );
    if (fieldIds.isEmpty) return const {};

    final projections = await _loadProjections(
      fieldIds.values.toSet(),
      transaction,
    );
    final activeOverrideFields = <MergeFieldKey, CrdtDataForeignKey>{};
    for (final MapEntry(key: fieldKey, value: fieldId) in fieldIds.entries) {
      final projection = projections[fieldId];
      if (projection == null || !projection.hasOverride) continue;
      activeOverrideFields[fieldKey] = projection;
    }
    if (activeOverrideFields.isEmpty) return const {};

    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    return {
      for (final MapEntry(key: fieldKey, value: projection)
          in activeOverrideFields.entries)
        if (sameUuidValue(
          uuidValueFromDatabase(valuesByRowId[fieldKey.$2]?[fieldKey.$3]),
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
  Future<void> project(Transaction transaction) async {
    if (_foreignKeys.edges.isEmpty) return;

    final state = await _loadProjectionState(transaction);
    if (state.rows.isEmpty) return;

    final currentHidden = {
      for (final row in state.rows.values)
        if (row.crdtRow.isHidden) row.key,
    };
    final userHidden = {
      for (final row in state.rows.values)
        if (row.crdtRow.deleted?.isDeleted ?? false) row.key,
    };
    final finalHidden = _computeHiddenRows(state, userHidden);

    await _materializeVisibility(
      state: state,
      currentHidden: currentHidden,
      finalHidden: finalHidden,
      transaction: transaction,
    );
    await _materializeValues(
      state: state,
      finalHidden: finalHidden,
      transaction: transaction,
    );
  }

  Future<_ForeignKeyProjectionState> _loadProjectionState(
    Transaction transaction,
  ) async {
    final rows = <MergeRowKey, _ProjectedForeignKeyRow>{};
    final fieldIds = <MergeFieldKey, int>{};
    final projections = <MergeFieldKey, CrdtDataForeignKey>{};
    final fkColumnsByTable = <String, Set<String>>{};

    for (final edge in _foreignKeys.edges) {
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

    for (final tableName in _context.syncTableByName.keys) {
      final (tableId, _) = _context.schema[tableName]!;
      final userId = _context.hlcManagerFor(transaction).normalizedScopeId;
      final crdtRows = await CrdtDataRow.db.find(
        _context.databaseSession,
        where: (t) => t.scopeId.equals(userId) & t.tblId.equals(tableId),
        include: CrdtDataRow.include(deleted: CrdtDataDeleted.include()),
        orderBy: (t) => t.uuidRowId,
        transaction: transaction,
      );
      if (crdtRows.isEmpty) continue;

      final rowIds = {for (final row in crdtRows) row.uuidRowId};
      final columnNames = fkColumnsByTable[tableName] ?? const <String>{};
      final valuesByRowId = await _context.readDomainColumnValues(
        tableName,
        rowIds,
        columnNames.toList(),
        transaction,
      );

      for (final row in crdtRows) {
        final rowId = row.uuidRowId;
        final key = (tableName, rowId);
        rows[key] = (
          key: key,
          crdtRow: row,
          values: valuesByRowId[rowId] ?? const {},
        );
      }

      if (columnNames.isNotEmpty) {
        fieldIds.addAll(
          await _findFieldIds(
            tableName: tableName,
            rowIds: rowIds,
            columnNames: columnNames,
            transaction: transaction,
          ),
        );
      }
    }

    if (fieldIds.isNotEmpty) {
      final loadedProjections = await _loadProjections(
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

    final parentRowsByReference = <ForeignKeyValueKey, _ProjectedForeignKeyRow>{};
    for (final edge in _foreignKeys.edges) {
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

    final childRowsByAttempt = <ForeignKeyValueKey, List<_ProjectedForeignKeyRow>>{};
    for (final edge in _foreignKeys.edges) {
      for (final child
          in rowsByTable[edge.childTableName] ?? const <_ProjectedForeignKeyRow>[]) {
        final value = _attemptedValueFromProjections(
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

    return (
      rows: rows,
      rowsByTable: rowsByTable,
      fieldIds: fieldIds,
      projections: projections,
      parentRowsByReference: parentRowsByReference,
      childRowsByAttempt: childRowsByAttempt,
    );
  }

  Future<Map<MergeFieldKey, int>> _findFieldIds({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Set<String> columnNames,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return {};

    final (tableId, _) = _context.schema[tableName]!;
    final userId = _context.hlcManagerFor(transaction).normalizedScopeId;
    final fields = await CrdtDataField.db.find(
      _context.databaseSession,
      where: (t) =>
          t.row.scopeId.equals(userId) &
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

  Future<Map<int, CrdtDataForeignKey>> _loadProjections(
    Set<int> fieldIds,
    Transaction transaction,
  ) async {
    if (fieldIds.isEmpty) return {};

    final projections = await CrdtDataForeignKey.db.find(
      _context.databaseSession,
      where: (t) => t.fieldId.inSet(fieldIds),
      transaction: transaction,
    );

    return {for (final projection in projections) projection.fieldId: projection};
  }

  Set<MergeRowKey> _computeHiddenRows(
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> userHidden,
  ) {
    final acceptedRoots = userHidden.toSet();

    while (true) {
      final closures = <MergeRowKey, Set<MergeRowKey>>{};
      final finalHidden = <MergeRowKey>{};

      for (final root in acceptedRoots.toList()..sort(_compareRowKeys)) {
        if (finalHidden.contains(root)) continue;

        final closure = _cascadeClosureForDelete(root, state, <MergeRowKey>{});
        closures[root] = closure;
        finalHidden.addAll(closure);
      }

      final missingParentHidden = _computeMissingParentHiddenRows(
        state,
        finalHidden,
      );
      final projectedHidden = {...finalHidden, ...missingParentHidden};

      final invalidRoots = <MergeRowKey>{};
      for (final MapEntry(key: root, value: closure) in closures.entries) {
        if (_closureBlockedByForeignKeys(closure, state, projectedHidden)) {
          invalidRoots.add(root);
        }
      }

      if (invalidRoots.isEmpty) return projectedHidden;
      acceptedRoots.removeAll(invalidRoots);
    }
  }

  Set<MergeRowKey> _computeMissingParentHiddenRows(
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> rootHidden,
  ) {
    final hidden = <MergeRowKey>{};

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
    Set<MergeRowKey> rootHidden,
    Set<MergeRowKey> missingParentHidden,
  ) {
    for (final edge
        in _foreignKeys.edgesByChildTable[row.key.$1] ?? const <ForeignKeyEdge>[]) {
      final attemptedValue = _attemptedValue(row, edge, state);
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
    ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> rootHidden,
    Set<MergeRowKey> missingParentHidden,
  ) {
    switch (edge.action) {
      case ForeignKeyAction.setNull:
        return edge.childNullable;
      case ForeignKeyAction.setDefault:
        final defaultValue = uuidValueFromDatabase(edge.defaultValue);
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

  Set<MergeRowKey> _cascadeClosureForDelete(
    MergeRowKey rowKey,
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> stack,
  ) {
    if (stack.contains(rowKey)) return <MergeRowKey>{};

    final row = state.rows[rowKey];
    if (row == null) return <MergeRowKey>{};

    final closure = <MergeRowKey>{rowKey};
    final nextStack = {...stack, rowKey};

    for (final edge
        in _foreignKeys.edgesByParentTable[rowKey.$1] ?? const <ForeignKeyEdge>[]) {
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
    Set<MergeRowKey> closure,
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> finalHidden,
  ) {
    for (final rowKey in closure) {
      final row = state.rows[rowKey];
      if (row == null) continue;

      for (final edge
          in _foreignKeys.edgesByParentTable[rowKey.$1] ?? const <ForeignKeyEdge>[]) {
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

  Future<void> _materializeVisibility({
    required _ForeignKeyProjectionState state,
    required Set<MergeRowKey> currentHidden,
    required Set<MergeRowKey> finalHidden,
    required Transaction transaction,
  }) async {
    final rowsToHide = finalHidden.difference(currentHidden);
    final rowsToShow = currentHidden.difference(finalHidden);

    await _setProjectedRowVisibility(
      rowsToHide,
      state: state,
      visibilityFor: (row) => (row.crdtRow.deleted?.isDeleted ?? false)
          ? (row.crdtRow.deleted?.reason == CrdtDataDeletedReason.userCascadeDelete)
                ? CrdtDataRowVisibility.userCascadeDelete
                : CrdtDataRowVisibility.userDelete
          : CrdtDataRowVisibility.foreignKeyCascade,
      transaction: transaction,
    );
    await _setProjectedRowVisibility(
      rowsToShow,
      state: state,
      visibilityFor: (row) => (row.crdtRow.deleted?.isDeleted ?? false)
          ? CrdtDataRowVisibility.foreignKeyRestrictRestore
          : CrdtDataRowVisibility.userInsert,
      transaction: transaction,
    );
  }

  Future<void> _setProjectedRowVisibility(
    Set<MergeRowKey> rowKeys, {
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
      if (projectedRow.crdtRow.visibility == visibility) continue;

      toUpdate.add(projectedRow.crdtRow.copyWith(visibility: visibility));
    }

    if (toUpdate.isEmpty) return;

    await CrdtDataRow.db.update(
      _context.databaseSession,
      toUpdate,
      columns: (t) => [t.visibility],
      transaction: transaction,
    );
  }

  Future<void> _materializeValues({
    required _ForeignKeyProjectionState state,
    required Set<MergeRowKey> finalHidden,
    required Transaction transaction,
  }) async {
    final changedUpdatesByRow = <MergeRowKey, Map<String, Object?>>{};
    final projectionWrites = <CrdtDataForeignKey>[];

    for (final edge in _foreignKeys.edges) {
      for (final child
          in state.rowsByTable[edge.childTableName] ??
              const <_ProjectedForeignKeyRow>[]) {
        if (finalHidden.contains(child.key)) continue;

        final attemptedValue = _attemptedValue(child, edge, state);
        final currentVisibleValue = uuidValueFromDatabase(
          child.values[edge.childColumn],
        );
        final projectionKey = (
          edge.childTableName,
          child.key.$2,
          edge.childColumn,
        );
        final existingProjection = state.projections[projectionKey];

        var desiredVisibleValue = attemptedValue;
        CrdtForeignKeyOverrideReason? overrideReason;

        if (attemptedValue != null &&
            _targetHiddenOrMissing(
              edge,
              attemptedValue,
              state,
              finalHidden,
            )) {
          switch (edge.action) {
            case ForeignKeyAction.setNull:
              if (edge.childNullable) {
                desiredVisibleValue = null;
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
                overrideReason = CrdtForeignKeyOverrideReason.setDefault;
              }
            case ForeignKeyAction.restrict:
            case ForeignKeyAction.noAction:
            case ForeignKeyAction.cascade:
              break;
          }
        }

        if (!sameUuidValue(currentVisibleValue, desiredVisibleValue)) {
          child.values[edge.childColumn] = desiredVisibleValue;
          changedUpdatesByRow.putIfAbsent(child.key, () => {})[edge.childColumn] =
              desiredVisibleValue;
        }

        final fieldId = state.fieldIds[projectionKey];
        if (fieldId == null || (overrideReason == null && existingProjection == null)) {
          continue;
        }

        projectionWrites.add(
          CrdtDataForeignKey(
            fieldId: fieldId,
            attemptedValue: attemptedValue,
            visibleValue: overrideReason != null ? desiredVisibleValue : null,
            overrideReason: overrideReason,
          ),
        );
      }
    }

    await _applyBatchedDomainRowUpdates(changedUpdatesByRow, transaction);
    await _upsertProjections(
      projectionWrites,
      transaction,
      existingProjections: {
        for (final projection in state.projections.values)
          projection.fieldId: projection,
      },
    );
    await _resolveUniqueConflictsAfterProjection(
      changedUpdatesByRow,
      transaction,
    );
  }

  Future<void> _applyBatchedDomainRowUpdates(
    _DomainRowUpdatesByKey updatesByRow,
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
          .map((entry) => '${entry.key}:${sqlLiteral(entry.value)}')
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
      await _context.updateDomainRows(
        key.$1,
        group.rowIds,
        group.updates,
        transaction,
      );
    }
  }

  Future<void> _resolveUniqueConflictsAfterProjection(
    _DomainRowUpdatesByKey changedUpdatesByRow,
    Transaction transaction,
  ) async {
    if (changedUpdatesByRow.isEmpty) return;

    final rowIdsByTable = <String, Set<UuidValue>>{};
    for (final rowKey in changedUpdatesByRow.keys) {
      rowIdsByTable.putIfAbsent(rowKey.$1, () => {}).add(rowKey.$2);
    }

    final rowsByKey = <MergeRowKey, CrdtDataRow>{};
    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final crdtRows = await _context.findCrdtRows(tableName, rowIds, transaction);
      for (final row in crdtRows) {
        rowsByKey[(tableName, row.uuidRowId)] = row;
      }
    }

    final context = (
      rows: <MergeRowKey, CrdtDataRow>{},
      fields: <MergeFieldKey, CrdtDataField>{},
      incomingFieldHlcs: <MergeFieldKey, Hlc>{},
      tombstones: <MergeRowKey, CrdtDataDeleted>{},
      domainOwners: <MergeRowKey, DomainRowOwner>{},
    );

    for (final MapEntry(key: rowKey, value: updates) in changedUpdatesByRow.entries) {
      final row = rowsByKey[rowKey];
      if (row == null) continue;

      final resolvedUpdates = await _uniqueResolver.resolveForIncomingUpdates(
        tableName: rowKey.$1,
        row: row,
        updates: updates,
        context: context,
        transaction: transaction,
      );
      if (resolvedUpdates == updates || resolvedUpdates.isEmpty) continue;

      await _context.updateDomainRows(
        rowKey.$1,
        {rowKey.$2},
        resolvedUpdates,
        transaction,
      );
    }
  }

  UuidValue? _attemptedValue(
    _ProjectedForeignKeyRow child,
    ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
  ) {
    return _attemptedValueFromProjections(
      child,
      edge,
      state.projections,
    );
  }

  UuidValue? _attemptedValueFromProjections(
    _ProjectedForeignKeyRow child,
    ForeignKeyEdge edge,
    Map<MergeFieldKey, CrdtDataForeignKey> projections,
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

    return uuidValueFromDatabase(child.values[edge.childColumn]);
  }

  bool _targetHiddenOrMissing(
    ForeignKeyEdge edge,
    UuidValue value,
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> hidden,
  ) {
    final target = _parentRowForValue(edge, value, state);
    return target == null || hidden.contains(target.key);
  }

  _ForeignKeyDefaultProjection _defaultProjectionValue(
    ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> hidden,
  ) {
    final defaultValue = uuidValueFromDatabase(edge.defaultValue);
    if (defaultValue == null) {
      return (valid: edge.childNullable, value: null);
    }

    final target = _parentRowForValue(edge, defaultValue, state);
    if (target == null || hidden.contains(target.key)) {
      return (valid: false, value: null);
    }

    return (valid: true, value: defaultValue);
  }

  Future<_ForeignKeyDefaultProjection> _defaultProjectionValueFromDatabase(
    ForeignKeyEdge edge,
    Transaction transaction,
  ) async {
    final defaultValue = uuidValueFromDatabase(edge.defaultValue);
    if (defaultValue == null) {
      return (valid: edge.childNullable, value: null);
    }

    final targetVisible = await _context.lookupForeignKeyTargetPresence(
      parentTableName: edge.parentTableName,
      parentColumn: edge.parentColumn,
      value: defaultValue,
      transaction: transaction,
    );
    if (targetVisible == ForeignKeyTargetPresence.visible) {
      return (valid: true, value: defaultValue);
    }
    return (valid: false, value: null);
  }

  UuidValue? _parentReferenceValue(
    _ProjectedForeignKeyRow parent,
    ForeignKeyEdge edge,
  ) {
    if (edge.parentColumn == 'id') return parent.key.$2;
    return uuidValueFromDatabase(parent.values[edge.parentColumn]);
  }

  _ProjectedForeignKeyRow? _parentRowForValue(
    ForeignKeyEdge edge,
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
    ForeignKeyEdge edge,
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

  Future<void> _upsertProjections(
    List<CrdtDataForeignKey> writes,
    Transaction transaction, {
    Map<int, CrdtDataForeignKey> existingProjections = const {},
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
        ...await _loadProjections(missingFieldIds, transaction),
      };
    }

    final toInsert = <CrdtDataForeignKey>[];
    final toUpdate = <CrdtDataForeignKey>[];

    for (final write in writeByFieldId.values) {
      final existing = existingByFieldId[write.fieldId];
      if (existing != null && _projectionMatches(existing, write)) {
        continue;
      }

      final projection = CrdtDataForeignKey(
        id: existing?.id,
        fieldId: write.fieldId,
        attemptedValue: write.attemptedValue,
        visibleValue: write.visibleValue,
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
        _context.databaseSession,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataForeignKey.db.update(
        _context.databaseSession,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  bool _projectionMatches(
    CrdtDataForeignKey existing,
    CrdtDataForeignKey write,
  ) {
    return sameUuidValue(existing.attemptedValue, write.attemptedValue) &&
        sameUuidValue(existing.visibleValue, write.visibleValue) &&
        existing.overrideReason == write.overrideReason;
  }

  bool sameUuidValue(UuidValue? left, UuidValue? right) {
    return left?.uuid == right?.uuid;
  }

  int _compareRowKeys(MergeRowKey left, MergeRowKey right) {
    final tableComparison = left.$1.compareTo(right.$1);
    if (tableComparison != 0) return tableComparison;
    return left.$2.uuid.compareTo(right.$2.uuid);
  }
}
