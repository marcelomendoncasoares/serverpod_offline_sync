import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/extensions.dart';
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

/// An authored value retained because projection materialized a different one,
/// together with the projector that selected the materialized value.
@internal
typedef ProjectionAttempt = ({
  Object? value,
  CrdtProjectionReason reason,
});

@internal
typedef ProjectionAttemptsByField = Map<MergeFieldKey, ProjectionAttempt>;

typedef _ForeignKeyProjectionState = ({
  Map<MergeRowKey, _ProjectedForeignKeyRow> rows,
  Map<String, List<_ProjectedForeignKeyRow>> rowsByTable,
  Map<MergeFieldKey, int> fieldIds,
  Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
  Map<MergeFieldKey, CrdtDataAttemptedValue> persistedAttempted,
  Map<MergeFieldKey, Hlc> fieldHlcs,
  Map<ForeignKeyValueKey, _ProjectedForeignKeyRow> parentRowsByReference,
  Map<ForeignKeyValueKey, List<_ProjectedForeignKeyRow>> childRowsByAttempt,
  Set<MergeRowKey> pendingInsertKeys,
  Map<MergeRowKey, Map<String, Object?>> originalDomain,
});

@internal
typedef SafeIncomingForeignKeyData = ({
  Map<String, Object?> data,
  ProjectionAttemptsByField attempts,
});

typedef _ForeignKeyDefaultProjection = ({bool valid, UuidValue? value});

typedef _DomainRowUpdatesByKey = Map<MergeRowKey, Map<String, Object?>>;

typedef _AttemptedWrite = ({
  int fieldId,
  Object? value,
  CrdtProjectionReason reason,
});

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
    required this._foreignKeys,
    required this._uniqueResolver,
  });

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
            await _updateChildColumnTo(
              reference.childTableName,
              childIds,
              reference.childColumn,
              null,
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
            await _updateChildColumnTo(
              reference.childTableName,
              childIds,
              reference.childColumn,
              defaultValue,
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

  /// Applies a local `ON DELETE` action to a child column.
  ///
  /// A locally initiated `SET NULL` or `SET DEFAULT` is an authored CRDT fact,
  /// not projection: it is the observable consequence of the delete the user
  /// just performed, so it advances the child field HLC. The merge-triggered
  /// action is the projection case and is handled by the planner instead.
  Future<void> _updateChildColumnTo(
    String childTableName,
    Set<UuidValue> childIds,
    String childColumn,
    Object? value,
    Transaction transaction,
  ) async {
    await _context.updateDomainRows(
      childTableName,
      childIds,
      {childColumn: value},
      transaction,
    );
    await _context.recordFieldsUpdatedByTable(
      childTableName,
      childIds,
      [childColumn],
      transaction,
    );
  }

  bool mergeOperationsMayAffectProjection(
    List<CrdtMergeChange> operations,
  ) {
    for (final operation in operations) {
      if (!_context.isCrdtTrackedTableName(operation.tableName)) continue;

      switch (operation) {
        case final CrdtMergeUpdate update:
          if (needsProjection(update.tableName, {update.columnName})) {
            return true;
          }
        case CrdtMergeInsert() || CrdtMergeDelete():
          if (needsProjection(operation.tableName, null)) {
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
    ProjectionAttemptsByField attemptedValues = const {},
  }) async {
    if (rowIds.isEmpty) return;

    final columnsToRecord = {
      ..._foreignKeys.foreignKeyColumnsFor(
        tableName,
        columnNames: columnNames,
      ),
      for (final fieldKey in attemptedValues.keys)
        if (fieldKey.$1 == tableName && rowIds.contains(fieldKey.$2)) fieldKey.$3,
    };
    if (columnsToRecord.isEmpty) return;

    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      columnsToRecord.toList(),
      transaction,
    );
    final fieldIds = await _findFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: columnsToRecord,
      transaction: transaction,
    );

    final projectionWrites = <_AttemptedWrite>[];
    for (final rowId in rowIds) {
      final values = valuesByRowId[rowId];
      if (values == null) continue;

      for (final columnName in columnsToRecord) {
        final fieldId = fieldIds[(tableName, rowId, columnName)];
        if (fieldId == null) continue;
        if (skippedFields.contains((tableName, rowId, columnName))) continue;

        final fieldKey = (tableName, rowId, columnName);
        final visibleValue = values[columnName];
        final attempt = attemptedValues[fieldKey];
        final attemptedValue = attempt != null ? attempt.value : visibleValue;
        if (projectionValuesEqual(attemptedValue, visibleValue)) continue;
        final overrideReason = attempt!.reason;

        projectionWrites.add(
          (
            fieldId: fieldId,
            value: attemptedValue,
            reason: overrideReason,
          ),
        );
      }
    }

    await _upsertAttemptedWrites(projectionWrites, transaction);
  }

  /// Records the foreign key attempts carried by an incoming insert.
  ///
  /// Projected columns keep their authored value in [CrdtDataAttemptedValue],
  /// which hangs off a [CrdtDataField], so an insert has to materialize field
  /// metadata for them even though no update has happened yet.
  ///
  /// [mergeCache] is the merge context's field cache and the node authoring the
  /// batch. The cache is loaded once before a batch is applied, so without this
  /// it would not know about the fields created here, and a later change to the
  /// same column in the same batch would take the "no field yet" path and
  /// insert a second row for the same `(rowId, columnId)`.
  ///
  /// The local write path passes nothing: it has no batch to cache for.
  Future<void> recordInsertAttempts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    ProjectionAttemptsByField attemptedValues, {
    MergeFieldCache? mergeCache,
  }) async {
    if (rowIds.isEmpty) return;

    final foreignKeyColumns = _foreignKeys.foreignKeyColumnsFor(tableName);
    final columns = {
      ...foreignKeyColumns,
      for (final fieldKey in attemptedValues.keys)
        if (fieldKey.$1 == tableName && rowIds.contains(fieldKey.$2)) fieldKey.$3,
    };
    if (columns.isEmpty) return;

    final visibleValuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      columns.toList(),
      transaction,
    );
    final valuesByRowId = {
      for (final rowId in rowIds)
        rowId: {
          for (final columnName in columns)
            columnName: attemptedValues.containsKey((tableName, rowId, columnName))
                ? attemptedValues[(tableName, rowId, columnName)]!.value
                : visibleValuesByRowId[rowId]?[columnName],
        },
    };
    final attemptedColumns = <String>{};
    for (final rowId in rowIds) {
      final values = valuesByRowId[rowId]!;
      for (final columnName in columns) {
        if (attemptedValues.containsKey((tableName, rowId, columnName)) ||
            values[columnName] != null) {
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
    // Field and key travel together so the write-back cannot pair them up
    // wrongly; zipping two lists by index would quietly depend on `insert`
    // returning rows in the order it was given them.
    final pending = <({CrdtDataField field, MergeFieldKey key})>[];
    for (final crdtRow in crdtRows) {
      final values = valuesByRowId[crdtRow.uuidRowId];
      if (values == null) continue;

      for (final MapEntry(key: columnName, value: columnId) in columnIds.entries) {
        if (values[columnName] == null &&
            !attemptedValues.containsKey((
              tableName,
              crdtRow.uuidRowId,
              columnName,
            ))) {
          continue;
        }
        if (existingFields.containsKey((tableName, crdtRow.uuidRowId, columnName))) {
          continue;
        }

        pending.add((
          field: CrdtDataField(
            rowId: crdtRow.id!,
            columnId: columnId,
            nodeId: crdtRow.nodeId,
            hlcDatetime: crdtRow.hlcDatetime,
            hlcCounter: crdtRow.hlcCounter,
          ),
          key: (tableName, crdtRow.uuidRowId, columnName),
        ));
      }
    }

    if (pending.isNotEmpty) {
      final insertedFields = await CrdtDataField.db.insert(
        _context.databaseSession,
        [for (final entry in pending) entry.field],
        transaction: transaction,
      );
      if (mergeCache != null) {
        for (final (index, field) in insertedFields.indexed) {
          // The node is attached because a cached field is read back through
          // `CrdtDataField.hlc`, which resolves the node's uuid and throws
          // without it.
          mergeCache.fields[pending[index].key] = field.copyWith(
            node: mergeCache.node,
          );
        }
      }
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
    final attempts = <MergeFieldKey, ProjectionAttempt>{};

    for (final edge
        in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[]) {
      if (!data.containsKey(edge.childColumn)) continue;

      final fieldKey = (tableName, rowId, edge.childColumn);
      final attemptedValue = data[edge.childColumn].toUuidValue();
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
              reason: CrdtProjectionReason.foreignKeySetNull,
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
              reason: CrdtProjectionReason.foreignKeySetDefault,
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
            reason: CrdtProjectionReason.foreignKeyMissingParent,
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

    final foreignKeyColumns = _foreignKeys.foreignKeyColumnsFor(tableName);
    if (foreignKeyColumns.isEmpty) return const {};

    final fields = await _loadFields(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );
    final activeOverrideFields = <MergeFieldKey, CrdtDataAttemptedValue>{
      for (final field in fields)
        (tableName, field.row!.uuidRowId, field.column!.name): ?field.attemptedValue,
    };
    if (activeOverrideFields.isEmpty) return const {};

    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      foreignKeyColumns.toList(),
      transaction,
    );
    return {
      for (final MapEntry(key: fieldKey, value: attempted)
          in activeOverrideFields.entries)
        if (!projectionValuesEqual(
          valuesByRowId[fieldKey.$2]?[fieldKey.$3],
          attempted.value,
        ))
          fieldKey,
    };
  }

  /// Fields that currently carry a sparse attempted-value override.
  ///
  /// Reinsert must not bump these field HLCs: the authored fact is unchanged
  /// and the domain difference is projection.
  Future<Set<MergeFieldKey>> findActiveAttemptedFields({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty) return const {};

    final columnNames = {
      ..._foreignKeys.foreignKeyColumnsFor(tableName),
      ..._uniqueResolver.uniqueColumnNamesFor(tableName),
    };
    if (columnNames.isEmpty) return const {};

    final fields = await _loadFields(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: columnNames,
      transaction: transaction,
    );
    return {
      for (final field in fields)
        if (field.attemptedValue != null)
          (tableName, field.row!.uuidRowId, field.column!.name),
    };
  }

  /// Whether a mutation of [tableName] may require FK or unique projection.
  bool needsProjection(String tableName, Set<String>? columnNames) {
    if (_foreignKeys.columnsMayAffectForeignKeys(tableName, columnNames)) {
      return true;
    }
    if (!_uniqueResolver.tableHasUniqueIndexes(tableName)) return false;
    if (columnNames == null) return true;
    return columnNames.any(
      (columnName) => _uniqueResolver.isUniqueIndexedColumn(tableName, columnName),
    );
  }

  /// Recomputes FK candidates, unique claims, visibility, and attempted values.
  ///
  /// [pendingInserts] participate in planning but are not written; the returned
  /// map contains their planned domain values. [authoredOverlays] replace the
  /// authored value of existing rows before planning. When [materialize] is
  /// false, only the in-memory plan is computed so a later physical insert is
  /// not blocked by this rebuild.
  /// Recomputes projection and, unless [materialize] is false, writes it.
  ///
  /// [seedTables] names the tables this pass changed. Only their foreign key
  /// components are loaded, which is equivalent to a full pass because no
  /// projection decision crosses a component boundary. Pass null when the
  /// affected tables are unknown, such as a rebuild, to load every table.
  Future<ProjectionPlan> project(
    Transaction transaction, {
    List<PendingProjectionRow> pendingInserts = const [],
    Map<MergeFieldKey, Object?> authoredOverlays = const {},
    Set<String>? seedTables,
    Set<MergeRowKey>? seedRows,
    bool materialize = true,
  }) async {
    final state = await _loadProjectionState(
      transaction,
      pendingInserts: pendingInserts,
      authoredOverlays: authoredOverlays,
      seedTables: seedTables,
      seedRows: seedRows,
    );
    if (state.rows.isEmpty) {
      return (
        domain: const <MergeRowKey, Map<String, Object?>>{},
        reasons: const <MergeFieldKey, CrdtProjectionReason>{},
      );
    }

    final currentHidden = {
      for (final row in state.rows.values)
        if (row.crdtRow.isHidden) row.key,
    };
    final pendingHiddenKeys = {
      for (final pending in pendingInserts)
        if (pending.hidden) (pending.tableName, pending.rowId),
    };
    final userHidden = {
      for (final row in state.rows.values)
        if (row.crdtRow.deleted?.isDeleted ?? false) row.key,
      ...pendingHiddenKeys,
    };
    final finalHidden = _computeHiddenRows(state, userHidden);

    if (materialize) {
      await _materializeVisibility(
        state: state,
        currentHidden: currentHidden,
        finalHidden: finalHidden,
        transaction: transaction,
      );
    }
    return _materializeValues(
      state: state,
      finalHidden: finalHidden,
      authoredOverlays: authoredOverlays,
      materialize: materialize,
      transaction: transaction,
    );
  }

  Future<_ForeignKeyProjectionState> _loadProjectionState(
    Transaction transaction, {
    List<PendingProjectionRow> pendingInserts = const [],
    Map<MergeFieldKey, Object?> authoredOverlays = const {},
    Set<String>? seedTables,
    Set<MergeRowKey>? seedRows,
  }) async {
    final rows = <MergeRowKey, _ProjectedForeignKeyRow>{};
    final fieldIds = <MergeFieldKey, int>{};
    final attemptedValues = <MergeFieldKey, CrdtDataAttemptedValue>{};
    final fieldHlcs = <MergeFieldKey, Hlc>{};
    final columnsByTable = <String, Set<String>>{};

    final tablesToLoad = seedTables == null
        ? _context.syncTableByName.keys.toSet()
        : _foreignKeys
              .connectedTables({
                ...seedTables,
                for (final pending in pendingInserts) pending.tableName,
                for (final fieldKey in authoredOverlays.keys) fieldKey.$1,
              })
              .where(_context.syncTableByName.containsKey)
              .toSet();

    for (final edge in _foreignKeys.edges) {
      if (!tablesToLoad.contains(edge.childTableName)) continue;
      columnsByTable.putIfAbsent(edge.childTableName, () => {}).add(edge.childColumn);
      if (edge.parentColumn != 'id') {
        columnsByTable
            .putIfAbsent(edge.parentTableName, () => {})
            .add(edge.parentColumn);
      }
    }
    for (final tableName in tablesToLoad) {
      columnsByTable
          .putIfAbsent(tableName, () => {})
          .addAll(_uniqueResolver.uniqueColumnNamesFor(tableName));
    }
    for (final pending in pendingInserts) {
      columnsByTable.putIfAbsent(pending.tableName, () => {}).addAll(
        pending.authoredValues.keys,
      );
    }
    for (final fieldKey in authoredOverlays.keys) {
      columnsByTable.putIfAbsent(fieldKey.$1, () => {}).add(fieldKey.$3);
    }

    if (seedRows == null) {
      for (final tableName in tablesToLoad) {
        await _loadTableRowsInto(
          tableName: tableName,
          rowIds: null,
          columnNames: columnsByTable[tableName] ?? const <String>{},
          rows: rows,
          fieldIds: fieldIds,
          attemptedValues: attemptedValues,
          fieldHlcs: fieldHlcs,
          transaction: transaction,
        );
      }
    } else {
      await _loadRowClosureInto(
        tablesToLoad: tablesToLoad,
        seedRows: seedRows,
        pendingInserts: pendingInserts,
        authoredOverlays: authoredOverlays,
        columnsByTable: columnsByTable,
        rows: rows,
        fieldIds: fieldIds,
        attemptedValues: attemptedValues,
        fieldHlcs: fieldHlcs,
        transaction: transaction,
      );
    }

    final originalDomain = {
      for (final row in rows.values)
        row.key: Map<String, Object?>.from(row.values),
    };
    // Overlays hide attempted rows from planning so the new authored value is
    // used. Keep the persisted rows so sync can delete them when domain again
    // equals authored.
    final persistedAttempted = Map<MergeFieldKey, CrdtDataAttemptedValue>.from(
      attemptedValues,
    );

    final pendingInsertKeys = <MergeRowKey>{};
    for (final pending in pendingInserts) {
      final key = (pending.tableName, pending.rowId);
      if (rows.containsKey(key)) continue;
      pendingInsertKeys.add(key);
      final (tableId, _) = _context.schema[pending.tableName]!;
      final scopeId = _context.hlcManagerFor(transaction).normalizedScopeId;
      rows[key] = (
        key: key,
        crdtRow: CrdtDataRow(
          scopeId: scopeId,
          tblId: tableId,
          uuidRowId: pending.rowId,
          nodeId: pending.node.id!,
          hlcDatetime: pending.rowHlc.datetime,
          hlcCounter: pending.rowHlc.counter,
        ).copyWith(node: pending.node),
        values: Map<String, Object?>.from(pending.authoredValues),
      );
      for (final MapEntry(key: columnName, value: value)
          in pending.authoredValues.entries) {
        fieldHlcs[(pending.tableName, pending.rowId, columnName)] = pending.rowHlc;
        // Pending authored values overlay any stale attempted row.
        attemptedValues.remove((pending.tableName, pending.rowId, columnName));
        if (!projectionValuesEqual(
          value,
          rows[key]!.values[columnName],
        )) {
          // Domain equals authored until projection runs; keep as authored.
        }
      }
    }

    for (final MapEntry(key: fieldKey, value: overlay) in authoredOverlays.entries) {
      final row = rows[(fieldKey.$1, fieldKey.$2)];
      if (row == null) continue;
      row.values[fieldKey.$3] = overlay;
      attemptedValues.remove(fieldKey);
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
          attemptedValues,
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
      attemptedValues: attemptedValues,
      persistedAttempted: persistedAttempted,
      fieldHlcs: fieldHlcs,
      parentRowsByReference: parentRowsByReference,
      childRowsByAttempt: childRowsByAttempt,
      pendingInsertKeys: pendingInsertKeys,
      originalDomain: originalDomain,
    );
  }

  /// Loads [rowIds] of [tableName], or every row of it when [rowIds] is null.
  ///
  /// Returns the row ids that exist, so a closure pass can expand from them.
  Future<Set<UuidValue>> _loadTableRowsInto({
    required String tableName,
    required Set<UuidValue>? rowIds,
    required Set<String> columnNames,
    required Map<MergeRowKey, _ProjectedForeignKeyRow> rows,
    required Map<MergeFieldKey, int> fieldIds,
    required Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
    required Map<MergeFieldKey, Hlc> fieldHlcs,
    required Transaction transaction,
  }) async {
    if (rowIds != null && rowIds.isEmpty) return const {};

    final (tableId, _) = _context.schema[tableName]!;
    final userId = _context.hlcManagerFor(transaction).normalizedScopeId;
    final crdtRows = await CrdtDataRow.db.find(
      _context.databaseSession,
      where: (t) {
        final inScope = t.scopeId.equals(userId) & t.tblId.equals(tableId);
        return rowIds == null ? inScope : inScope & t.uuidRowId.inSet(rowIds);
      },
      include: CrdtDataRow.include(
        node: CrdtNode.include(),
        deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
      ),
      orderBy: (t) => t.uuidRowId,
      transaction: transaction,
    );
    if (crdtRows.isEmpty) return const {};

    final loadedIds = {for (final row in crdtRows) row.uuidRowId};
    final valuesByRowId = columnNames.isEmpty
        ? <UuidValue, Map<String, Object?>>{}
        : await _context.readDomainColumnValues(
            tableName,
            loadedIds,
            columnNames.toList(),
            transaction,
          );

    for (final row in crdtRows) {
      final key = (tableName, row.uuidRowId);
      rows[key] = (
        key: key,
        crdtRow: row,
        values: Map<String, Object?>.from(valuesByRowId[row.uuidRowId] ?? const {}),
      );
    }

    if (columnNames.isNotEmpty) {
      final loadedFields = await _loadFields(
        tableName: tableName,
        rowIds: loadedIds,
        columnNames: columnNames,
        transaction: transaction,
      );
      for (final field in loadedFields) {
        final fieldKey = (tableName, field.row!.uuidRowId, field.column!.name);
        fieldIds[fieldKey] = field.id!;
        fieldHlcs[fieldKey] = field.hlc;
        final attempted = field.attemptedValue;
        if (attempted != null) {
          attemptedValues[fieldKey] = attempted;
        }
      }
    }

    return loadedIds;
  }

  /// Loads the rows the seeds can reach instead of every row of their tables.
  ///
  /// Cascade, restrict and repair all travel along foreign key edges, and a
  /// row reached by no edge from a seed cannot change, so the closure is the
  /// seeds plus their foreign key component: children of a loaded row, because
  /// hiding or restoring a parent decides their fate, and parents of a loaded
  /// row, because an unloaded parent reads as a missing one. Rows holding an
  /// attempted value join the seeds: their domain column no longer names the
  /// parent they want, so no edge query would find them.
  ///
  /// Rows contesting a unique claim join the same walk, found through the
  /// table's own unique index rather than by loading the table.
  Future<void> _loadRowClosureInto({
    required Set<String> tablesToLoad,
    required Set<MergeRowKey> seedRows,
    required List<PendingProjectionRow> pendingInserts,
    required Map<MergeFieldKey, Object?> authoredOverlays,
    required Map<String, Set<String>> columnsByTable,
    required Map<MergeRowKey, _ProjectedForeignKeyRow> rows,
    required Map<MergeFieldKey, int> fieldIds,
    required Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
    required Map<MergeFieldKey, Hlc> fieldHlcs,
    required Transaction transaction,
  }) async {
    // A pending insert has no row yet, and an overlay's new value is applied
    // after loading, so neither is visible to an edge query. Both name the
    // parent the pass has to judge them against, so they seed the walk too.
    final unwrittenValues = <MergeRowKey, Map<String, Object?>>{};
    for (final pending in pendingInserts) {
      unwrittenValues[(pending.tableName, pending.rowId)] = {
        ...pending.authoredValues,
      };
    }
    for (final MapEntry(key: fieldKey, value: value)
        in authoredOverlays.entries) {
      unwrittenValues.putIfAbsent(
        (fieldKey.$1, fieldKey.$2),
        () => <String, Object?>{},
      )[fieldKey.$3] = value;
    }

    final requested = <String, Set<UuidValue>>{};
    var queued = <String, Set<UuidValue>>{};

    void enqueue(String tableName, Iterable<UuidValue> ids) {
      if (!tablesToLoad.contains(tableName)) return;
      final seen = requested.putIfAbsent(tableName, () => <UuidValue>{});
      for (final id in ids) {
        if (!seen.add(id)) continue;
        queued.putIfAbsent(tableName, () => <UuidValue>{}).add(id);
      }
    }

    final frontier = <String, Set<UuidValue>>{};

    for (final rowKey in seedRows) {
      enqueue(rowKey.$1, [rowKey.$2]);
    }
    for (final rowKey in unwrittenValues.keys) {
      if (!tablesToLoad.contains(rowKey.$1)) continue;
      enqueue(rowKey.$1, [rowKey.$2]);
      (frontier[rowKey.$1] ??= <UuidValue>{}).add(rowKey.$2);
    }
    for (final rowKey in await _rowKeysHoldingAttemptedValues(
      tablesToLoad,
      transaction,
    )) {
      enqueue(rowKey.$1, [rowKey.$2]);
    }
    // A set-default edge names its target in the schema, so no row points at
    // it until the repair runs.
    for (final edge in _foreignKeys.edges) {
      if (!tablesToLoad.contains(edge.childTableName)) continue;
      final defaultValue = edge.defaultValue.toUuidValue();
      if (defaultValue == null) continue;
      if (edge.parentColumn == 'id') {
        enqueue(edge.parentTableName, [defaultValue]);
        continue;
      }
      enqueue(
        edge.parentTableName,
        await _context.findDomainRowIdsWhereColumnIn(
          tableName: edge.parentTableName,
          columnName: edge.parentColumn,
          values: {defaultValue},
          transaction: transaction,
        ),
      );
    }

    while (queued.isNotEmpty || frontier.isNotEmpty) {
      final wave = queued;
      queued = <String, Set<UuidValue>>{};

      final loadedNow = <String, Set<UuidValue>>{};
      for (final MapEntry(key: tableName, value: ids) in wave.entries) {
        final loaded = await _loadTableRowsInto(
          tableName: tableName,
          rowIds: ids,
          columnNames: columnsByTable[tableName] ?? const <String>{},
          rows: rows,
          fieldIds: fieldIds,
          attemptedValues: attemptedValues,
          fieldHlcs: fieldHlcs,
          transaction: transaction,
        );
        if (loaded.isNotEmpty) loadedNow[tableName] = loaded;
      }

      for (final MapEntry(key: tableName, value: ids) in frontier.entries) {
        (loadedNow[tableName] ??= <UuidValue>{}).addAll(ids);
      }
      frontier.clear();
      if (loadedNow.isEmpty) break;

      await _expandRowClosure(
        loadedNow: loadedNow,
        tablesToLoad: tablesToLoad,
        rows: rows,
        unwrittenValues: unwrittenValues,
        attemptedValues: attemptedValues,
        enqueue: enqueue,
        transaction: transaction,
      );
    }
  }

  Future<void> _expandRowClosure({
    required Map<String, Set<UuidValue>> loadedNow,
    required Set<String> tablesToLoad,
    required Map<MergeRowKey, _ProjectedForeignKeyRow> rows,
    required Map<MergeRowKey, Map<String, Object?>> unwrittenValues,
    required Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
    required void Function(String tableName, Iterable<UuidValue> ids) enqueue,
    required Transaction transaction,
  }) async {
    // Both the stored and the unwritten value matter: the walk has to reach the
    // parent a row points at now and the one it is about to point at.
    Set<Object?> valuesFor(MergeRowKey rowKey, String columnName) {
      return <Object?>{
        rows[rowKey]?.values[columnName],
        if (unwrittenValues[rowKey]?.containsKey(columnName) ?? false)
          unwrittenValues[rowKey]![columnName],
      }..remove(null);
    }

    for (final edge in _foreignKeys.edges) {
      final parentIds = loadedNow[edge.parentTableName];
      if (parentIds != null &&
          parentIds.isNotEmpty &&
          tablesToLoad.contains(edge.childTableName)) {
        final references = <Object?>{};
        for (final parentId in parentIds) {
          if (edge.parentColumn == 'id') {
            references.add(parentId);
            continue;
          }
          references.addAll(
            valuesFor((edge.parentTableName, parentId), edge.parentColumn),
          );
        }
        if (references.isNotEmpty) {
          enqueue(
            edge.childTableName,
            await _context.findDomainRowIdsWhereColumnIn(
              tableName: edge.childTableName,
              columnName: edge.childColumn,
              values: references,
              transaction: transaction,
            ),
          );
        }
      }

      final childIds = loadedNow[edge.childTableName];
      if (childIds != null &&
          childIds.isNotEmpty &&
          tablesToLoad.contains(edge.parentTableName)) {
        final references = <UuidValue>{};
        for (final childId in childIds) {
          final rowKey = (edge.childTableName, childId);
          for (final value in valuesFor(rowKey, edge.childColumn)) {
            final reference = tryUuidValue(value);
            if (reference != null) references.add(reference);
          }
          final child = rows[rowKey];
          if (child == null) continue;
          // The attempted value names the parent a repair is waiting for.
          final attempted = _attemptedValueFromProjections(
            child,
            edge,
            attemptedValues,
          );
          if (attempted != null) references.add(attempted);
        }
        if (references.isEmpty) continue;

        if (edge.parentColumn == 'id') {
          enqueue(edge.parentTableName, references);
        } else {
          enqueue(
            edge.parentTableName,
            await _context.findDomainRowIdsWhereColumnIn(
              tableName: edge.parentTableName,
              columnName: edge.parentColumn,
              values: references,
              transaction: transaction,
            ),
          );
        }
      }
    }

    // A unique claim is contested by value, not along an edge: the row holding
    // the tuple this one wants can be any row of the table, so ask the table's
    // own unique index for it. A row that wants a value it does not hold is
    // already loaded, because holding a projection means holding an attempted
    // value.
    for (final MapEntry(key: tableName, value: rowIds) in loadedNow.entries) {
      for (final uniqueIndex in _uniqueResolver.uniqueIndexesFor(tableName)) {
        final claimedByColumn = <String, Set<Object?>>{};
        for (final rowId in rowIds) {
          final rowKey = (tableName, rowId);
          for (final columnName in uniqueIndex.indexedColumns) {
            final claims = <Object?>{
              ...valuesFor(rowKey, columnName),
              ?attemptedValues[(tableName, rowId, columnName)]?.value,
            }..remove(null);
            if (claims.isEmpty) continue;
            (claimedByColumn[columnName] ??= <Object?>{}).addAll(claims);
          }
        }
        if (claimedByColumn.length != uniqueIndex.indexedColumns.length) {
          continue;
        }

        enqueue(
          tableName,
          await _context.findDomainRowIdsWhereColumnsIn(
            tableName: tableName,
            valuesByColumn: claimedByColumn,
            transaction: transaction,
          ),
        );
      }
    }
  }

  /// Rows of [tableNames] that currently hold a sparse attempted value.
  Future<Set<MergeRowKey>> _rowKeysHoldingAttemptedValues(
    Set<String> tableNames,
    Transaction transaction,
  ) async {
    final tableNameById = <int, String>{
      for (final tableName in tableNames)
        if (_context.schema[tableName] case (final tableId, _))
          tableId: tableName,
    };
    if (tableNameById.isEmpty) return const {};

    final rowKeys = await _context.findRowKeysHoldingAttemptedValues(
      tableIds: tableNameById.keys.toSet(),
      transaction: transaction,
    );

    return {
      for (final (tableId, rowId) in rowKeys)
        if (tableNameById[tableId] case final tableName?) (tableName, rowId),
    };
  }

  Future<List<CrdtDataField>> _loadFields({
    required String tableName,
    required Set<UuidValue> rowIds,
    required Set<String> columnNames,
    required Transaction transaction,
  }) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return const [];

    final (tableId, _) = _context.schema[tableName]!;
    final userId = _context.hlcManagerFor(transaction).normalizedScopeId;
    return CrdtDataField.db.find(
      _context.databaseSession,
      where: (t) =>
          t.row.scopeId.equals(userId) &
          t.row.tblId.equals(tableId) &
          t.row.uuidRowId.inSet(rowIds) &
          t.column.name.inSet(columnNames),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
        attemptedValue: CrdtDataAttemptedValue.include(),
      ),
      transaction: transaction,
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

  Future<Map<int, CrdtDataAttemptedValue>> _loadAttemptedValues(
    Set<int> fieldIds,
    Transaction transaction,
  ) async {
    if (fieldIds.isEmpty) return {};

    final attemptedValues = await CrdtDataAttemptedValue.db.find(
      _context.databaseSession,
      where: (t) => t.fieldId.inSet(fieldIds),
      transaction: transaction,
    );

    return {
      for (final attempted in attemptedValues) attempted.fieldId: attempted,
    };
  }

  Set<MergeRowKey> _computeHiddenRows(
    _ForeignKeyProjectionState state,
    Set<MergeRowKey> userHidden,
  ) {
    final acceptedRoots = userHidden.toSet();

    while (true) {
      final closures = <MergeRowKey, Set<MergeRowKey>>{};
      final finalHidden = <MergeRowKey>{};

      for (final root in acceptedRoots.toList()..sort(compareMergeRowKeys)) {
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
        final defaultValue = edge.defaultValue.toUuidValue();
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
          ? row.crdtRow.deleted!.reason.toVisibility(isDeleted: true)
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
      if (projectedRow == null || projectedRow.crdtRow.id == null) continue;

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

  Future<ProjectionPlan> _materializeValues({
    required _ForeignKeyProjectionState state,
    required Set<MergeRowKey> finalHidden,
    required Map<MergeFieldKey, Object?> authoredOverlays,
    required bool materialize,
    required Transaction transaction,
  }) async {
    final authoredByField = <MergeFieldKey, Object?>{};
    for (final row in state.rows.values) {
      for (final MapEntry(key: columnName, value: domainValue) in row.values.entries) {
        final fieldKey = (row.key.$1, row.key.$2, columnName);
        if (authoredOverlays.containsKey(fieldKey)) {
          authoredByField[fieldKey] = canonicalDomainValue(
            authoredOverlays[fieldKey],
          );
        } else {
          authoredByField[fieldKey] = canonicalDomainValue(
            state.attemptedValues[fieldKey]?.value ?? domainValue,
          );
        }
      }
    }

    final fkReasons = <MergeFieldKey, CrdtProjectionReason>{};
    final fkCandidates = <MergeFieldKey, Object?>{};

    for (final edge in _foreignKeys.edges) {
      for (final child
          in state.rowsByTable[edge.childTableName] ??
              const <_ProjectedForeignKeyRow>[]) {
        final fieldKey = (
          edge.childTableName,
          child.key.$2,
          edge.childColumn,
        );
        final attemptedValue = _attemptedValue(child, edge, state);
        var desiredVisibleValue = attemptedValue;
        CrdtProjectionReason? overrideReason;

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
                overrideReason = CrdtProjectionReason.foreignKeySetNull;
              }
            case ForeignKeyAction.setDefault:
              final defaultProjection = _defaultProjectionValue(
                edge,
                state,
                finalHidden,
              );
              if (defaultProjection.valid) {
                desiredVisibleValue = defaultProjection.value;
                overrideReason = CrdtProjectionReason.foreignKeySetDefault;
              }
            case ForeignKeyAction.restrict:
            case ForeignKeyAction.noAction:
            case ForeignKeyAction.cascade:
              break;
          }
        }

        if (desiredVisibleValue != null &&
            _parentRowForValue(edge, desiredVisibleValue, state) == null) {
          // Physical FK cannot accept a UUID whose parent row is absent.
          final safeValue = edge.childNullable ? null : child.values[edge.childColumn];
          fkCandidates[fieldKey] = safeValue;
          child.values[edge.childColumn] = safeValue;
          fkReasons[fieldKey] = CrdtProjectionReason.foreignKeyMissingParent;
          continue;
        }

        fkCandidates[fieldKey] = desiredVisibleValue;
        child.values[edge.childColumn] = desiredVisibleValue;
        if (overrideReason != null) {
          fkReasons[fieldKey] = overrideReason;
        }
      }
    }

    final claimByField = <MergeFieldKey, Object?>{};
    for (final row in state.rows.values) {
      for (final columnName in row.values.keys) {
        final fieldKey = (row.key.$1, row.key.$2, columnName);
        claimByField[fieldKey] = fkCandidates.containsKey(fieldKey)
            ? fkCandidates[fieldKey]
            : authoredByField[fieldKey];
      }
    }

    final uniqueReasons = _uniqueResolver.planUniqueProjection(
      valuesByRow: {
        for (final row in state.rows.values) row.key: row.values,
      },
      crdtRows: {
        for (final row in state.rows.values) row.key: row.crdtRow,
      },
      hidden: finalHidden,
      authoredByField: authoredByField,
      claimByField: claimByField,
      fieldHlcs: state.fieldHlcs,
    );

    final terminalReasons = <MergeFieldKey, CrdtProjectionReason>{
      ...fkReasons,
      ...uniqueReasons,
    };

    // Pending inserts are visible to planning, but they are not domain rows
    // yet. Writing a child FK UUID that points at one fails the physical FK.
    for (final edge in _foreignKeys.edges) {
      for (final child
          in state.rowsByTable[edge.childTableName] ??
              const <_ProjectedForeignKeyRow>[]) {
        if (state.pendingInsertKeys.contains(child.key)) continue;
        final parentValue = tryUuidValue(child.values[edge.childColumn]);
        if (parentValue == null) continue;
        final parent = _parentRowForValue(edge, parentValue, state);
        if (parent == null || !state.pendingInsertKeys.contains(parent.key)) {
          continue;
        }
        child.values[edge.childColumn] =
            state.originalDomain[child.key]?[edge.childColumn];
      }
    }

    final finalDomain = {
      for (final row in state.rows.values) row.key: row.values,
    };
    if (materialize) {
      await _materializeDomainTwoPhase(
        originalDomain: state.originalDomain,
        finalDomain: finalDomain,
        skip: state.pendingInsertKeys,
        transaction: transaction,
      );
      await _syncAttemptedValues(
        state: state,
        authoredByField: authoredByField,
        finalDomain: finalDomain,
        reasons: terminalReasons,
        hidden: finalHidden,
        skip: state.pendingInsertKeys,
        transaction: transaction,
      );
    }

    return (
      domain: {
        for (final row in state.rows.values)
          row.key: Map<String, Object?>.from(row.values),
      },
      reasons: terminalReasons,
    );
  }

  Future<void> _materializeDomainTwoPhase({
    required Map<MergeRowKey, Map<String, Object?>> originalDomain,
    required Map<MergeRowKey, Map<String, Object?>> finalDomain,
    required Set<MergeRowKey> skip,
    required Transaction transaction,
  }) async {
    final changed = <MergeRowKey, Map<String, Object?>>{};
    for (final MapEntry(key: rowKey, value: finals) in finalDomain.entries) {
      if (skip.contains(rowKey)) continue;
      final original = originalDomain[rowKey] ?? const <String, Object?>{};
      final updates = <String, Object?>{};
      for (final MapEntry(key: columnName, value: value) in finals.entries) {
        if (!projectionValuesEqual(original[columnName], value)) {
          updates[columnName] = value;
        }
      }
      if (updates.isNotEmpty) changed[rowKey] = updates;
    }
    if (changed.isEmpty) return;

    final parkUpdates = <MergeRowKey, Map<String, Object?>>{};
    for (final MapEntry(key: rowKey, value: updates) in changed.entries) {
      final park = <String, Object?>{};
      for (final column in _uniqueResolver.uniqueReleaseColumnsFor(rowKey.$1)) {
        if (!updates.containsKey(column.columnName)) continue;
        park[column.columnName] = _context.conflictFreeValue(
          column,
          originalDomain[rowKey]?[column.columnName],
          rowKey.$1,
          rowKey.$2,
          'park',
        );
      }
      if (park.isNotEmpty) parkUpdates[rowKey] = park;
    }

    await _applyBatchedDomainRowUpdates(parkUpdates, transaction);
    await _applyBatchedDomainRowUpdates(changed, transaction);
  }

  Future<void> _syncAttemptedValues({
    required _ForeignKeyProjectionState state,
    required Map<MergeFieldKey, Object?> authoredByField,
    required Map<MergeRowKey, Map<String, Object?>> finalDomain,
    required Map<MergeFieldKey, CrdtProjectionReason> reasons,
    required Set<MergeRowKey> hidden,
    required Set<MergeRowKey> skip,
    required Transaction transaction,
  }) async {
    final desired = <int, _AttemptedWrite>{};
    final fieldIdsToDelete = <int>{};
    final pending = <MergeFieldKey, ProjectionAttempt>{};

    for (final MapEntry(key: fieldKey, value: authored) in authoredByField.entries) {
      final rowKey = (fieldKey.$1, fieldKey.$2);
      if (skip.contains(rowKey)) continue;
      final domain = finalDomain[rowKey]?[fieldKey.$3];
      final existing =
          state.persistedAttempted[fieldKey] ?? state.attemptedValues[fieldKey];
      if (projectionValuesEqual(domain, authored)) {
        if (existing != null) fieldIdsToDelete.add(existing.fieldId);
        continue;
      }

      final reason =
          reasons[fieldKey] ??
          (hidden.contains(rowKey)
              ? CrdtProjectionReason.hiddenUniqueRelease
              : CrdtProjectionReason.uniqueConflict);
      final fieldId = state.fieldIds[fieldKey];
      if (fieldId == null) {
        pending[fieldKey] = (value: authored, reason: reason);
        continue;
      }
      desired[fieldId] = (fieldId: fieldId, value: authored, reason: reason);
    }

    if (pending.isNotEmpty) {
      final fieldIds = await _ensureFieldIds(pending.keys, state, transaction);
      for (final MapEntry(key: fieldKey, value: attempt) in pending.entries) {
        final fieldId = fieldIds[fieldKey]!;
        desired[fieldId] = (
          fieldId: fieldId,
          value: attempt.value,
          reason: attempt.reason,
        );
      }
    }

    if (fieldIdsToDelete.isNotEmpty) {
      await CrdtDataAttemptedValue.db.deleteWhere(
        _context.databaseSession,
        where: (t) => t.fieldId.inSet(fieldIdsToDelete),
        transaction: transaction,
      );
    }
    await _upsertAttemptedWrites(
      desired.values.toList(),
      transaction,
      existingByFieldId: {
        for (final attempted in state.persistedAttempted.values)
          attempted.fieldId: attempted,
        for (final attempted in state.attemptedValues.values)
          attempted.fieldId: attempted,
      },
    );
  }

  /// Resolves the [CrdtDataField] id for every key, creating what is missing.
  ///
  /// Projection state only holds fields loaded for the columns and scope of
  /// this pass, so a field for a row and column can already be persisted.
  /// Adopt those in one query and insert the genuinely new ones in one batch,
  /// rather than a select-then-insert round trip per field.
  Future<Map<MergeFieldKey, int>> _ensureFieldIds(
    Iterable<MergeFieldKey> fieldKeys,
    _ForeignKeyProjectionState state,
    Transaction transaction,
  ) async {
    final rowsByKey = <MergeFieldKey, _ProjectedForeignKeyRow>{};
    final columnIdByKey = <MergeFieldKey, int>{};
    for (final fieldKey in fieldKeys) {
      final row = state.rows[(fieldKey.$1, fieldKey.$2)];
      if (row == null || row.crdtRow.id == null) {
        throw StateError(
          'Cannot persist an attempted value for ${fieldKey.$1}.${fieldKey.$3} '
          'on row ${fieldKey.$2} without CRDT field metadata.',
        );
      }
      final columnId = _context.schemaColumn(fieldKey.$1, fieldKey.$3)?.id;
      if (columnId == null) {
        throw StateError(
          'No CRDT schema column for ${fieldKey.$1}.${fieldKey.$3}.',
        );
      }
      rowsByKey[fieldKey] = row;
      columnIdByKey[fieldKey] = columnId;
    }
    if (rowsByKey.isEmpty) return const {};

    final keyByIdentity = {
      for (final MapEntry(key: fieldKey, value: row) in rowsByKey.entries)
        (row.crdtRow.id!, columnIdByKey[fieldKey]!): fieldKey,
    };
    // One query over the row/column ranges; the cross product is filtered back
    // down to the exact pairs this pass asked for.
    final existing = await CrdtDataField.db.find(
      _context.databaseSession,
      where: (t) =>
          t.rowId.inSet({for (final row in rowsByKey.values) row.crdtRow.id!}) &
          t.columnId.inSet(columnIdByKey.values.toSet()),
      transaction: transaction,
    );

    final resolved = <MergeFieldKey, int>{};
    for (final field in existing) {
      final fieldKey = keyByIdentity[(field.rowId, field.columnId)];
      if (fieldKey == null) continue;
      resolved[fieldKey] = field.id!;
      state.fieldIds[fieldKey] = field.id!;
    }

    final missing = [
      for (final fieldKey in rowsByKey.keys)
        if (!resolved.containsKey(fieldKey)) fieldKey,
    ];
    if (missing.isEmpty) return resolved;

    final inserted = await CrdtDataField.db.insert(
      _context.databaseSession,
      [
        for (final fieldKey in missing)
          CrdtDataField(
            rowId: rowsByKey[fieldKey]!.crdtRow.id!,
            columnId: columnIdByKey[fieldKey]!,
            nodeId: rowsByKey[fieldKey]!.crdtRow.nodeId,
            hlcDatetime: rowsByKey[fieldKey]!.crdtRow.hlcDatetime,
            hlcCounter: rowsByKey[fieldKey]!.crdtRow.hlcCounter,
          ),
      ],
      transaction: transaction,
    );
    for (final field in inserted) {
      final fieldKey = keyByIdentity[(field.rowId, field.columnId)]!;
      resolved[fieldKey] = field.id!;
      state.fieldIds[fieldKey] = field.id!;
    }
    return resolved;
  }

  /// Writes [authoredValues] straight to their domain rows.
  ///
  /// Only valid when nothing in the batch can affect projection: with no
  /// foreign key column and no unique column in play there is no candidate to
  /// compute and no claim to resolve, so a pass would materialize exactly the
  /// authored value. Skipping it avoids loading state to rediscover that.
  Future<void> writeAuthoredValues(
    Map<MergeFieldKey, Object?> authoredValues,
    Transaction transaction,
  ) async {
    if (authoredValues.isEmpty) return;

    final updatesByRow = <MergeRowKey, Map<String, Object?>>{};
    for (final MapEntry(key: fieldKey, value: value) in authoredValues.entries) {
      updatesByRow.putIfAbsent(
        (fieldKey.$1, fieldKey.$2),
        () => <String, Object?>{},
      )[fieldKey.$3] = value;
    }

    await _applyBatchedDomainRowUpdates(updatesByRow, transaction);
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
          .map((entry) => '${entry.key}:${entry.value.sqlLiteral()}')
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

  UuidValue? _attemptedValue(
    _ProjectedForeignKeyRow child,
    ForeignKeyEdge edge,
    _ForeignKeyProjectionState state,
  ) {
    return _attemptedValueFromProjections(
      child,
      edge,
      state.attemptedValues,
    );
  }

  UuidValue? _attemptedValueFromProjections(
    _ProjectedForeignKeyRow child,
    ForeignKeyEdge edge,
    Map<MergeFieldKey, CrdtDataAttemptedValue> attemptedValues,
  ) {
    final attempted =
        attemptedValues[(
          edge.childTableName,
          child.key.$2,
          edge.childColumn,
        )];
    if (attempted != null) {
      return tryUuidValue(attempted.value);
    }

    return tryUuidValue(child.values[edge.childColumn]);
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
    final defaultValue = edge.defaultValue.toUuidValue();
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
    final defaultValue = edge.defaultValue.toUuidValue();
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
    return parent.values[edge.parentColumn].toUuidValue();
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

  Future<void> _upsertAttemptedWrites(
    List<_AttemptedWrite> writes,
    Transaction transaction, {
    Map<int, CrdtDataAttemptedValue> existingByFieldId = const {},
  }) async {
    if (writes.isEmpty) return;

    final writeByFieldId = {
      for (final write in writes) write.fieldId: write,
    };
    var existing = existingByFieldId;
    final missingFieldIds = writeByFieldId.keys
        .where((fieldId) => !existing.containsKey(fieldId))
        .toSet();
    if (missingFieldIds.isNotEmpty) {
      existing = {
        ...existing,
        ...await _loadAttemptedValues(missingFieldIds, transaction),
      };
    }

    final toInsert = <CrdtDataAttemptedValue>[];
    final toUpdate = <CrdtDataAttemptedValue>[];

    for (final write in writeByFieldId.values) {
      final current = existing[write.fieldId];
      if (current != null &&
          projectionValuesEqual(current.value, write.value) &&
          current.projectionReason == write.reason) {
        continue;
      }

      final attempted = CrdtDataAttemptedValue(
        id: current?.id,
        fieldId: write.fieldId,
        value: canonicalDomainValue(write.value),
        projectionReason: write.reason,
      );
      if (current == null) {
        toInsert.add(attempted);
      } else {
        toUpdate.add(attempted);
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataAttemptedValue.db.insert(
        _context.databaseSession,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataAttemptedValue.db.update(
        _context.databaseSession,
        toUpdate,
        transaction: transaction,
      );
    }
  }

}
