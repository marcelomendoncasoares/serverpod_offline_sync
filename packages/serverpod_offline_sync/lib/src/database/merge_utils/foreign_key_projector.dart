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

@internal
typedef ForeignKeyAttempt = ({
  Object? value,
  CrdtProjectionReason? reason,
});

@internal
typedef ForeignKeyAttemptsByField = Map<MergeFieldKey, ForeignKeyAttempt>;

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
  ForeignKeyAttemptsByField attempts,
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
        switch (reference.action) {
          case ForeignKeyAction.setNull:
          case ForeignKeyAction.setDefault:
            // Domain rewrites and attempted-value retention are projection.
            // Writing here would author a field HLC and destroy the attempted
            // parent id.
            continue;
          case ForeignKeyAction.restrict:
          case ForeignKeyAction.noAction:
          case ForeignKeyAction.cascade:
            break;
        }

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
          case ForeignKeyAction.setDefault:
            continue;
          case ForeignKeyAction.cascade:
            cascadeDeletes
                .putIfAbsent(reference.childTableName, () => {})
                .addAll(childIds);
        }
      }
    }

    return cascadeDeletes;
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
    ForeignKeyAttemptsByField attemptedValues = const {},
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
        final overrideReason = attempt?.reason;
        if (overrideReason == null) {
          throw StateError(
            'Projection override active for $tableName.$columnName '
            'on row $rowId but no reason was provided. All override-producing '
            'paths must supply a reason via safeIncomingData.',
          );
        }

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
    ForeignKeyAttemptsByField attemptedValues, {
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
    final attempts = <MergeFieldKey, ForeignKeyAttempt>{};

    for (final edge
        in _foreignKeys.edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[]) {
      if (!data.containsKey(edge.childColumn)) continue;

      final fieldKey = (tableName, rowId, edge.childColumn);
      final attemptedValue = data[edge.childColumn].toUuidValue();
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

    final fieldIds = await _findFieldIds(
      tableName: tableName,
      rowIds: rowIds,
      columnNames: foreignKeyColumns,
      transaction: transaction,
    );
    if (fieldIds.isEmpty) return const {};

    final attemptedValues = await _loadAttemptedValues(
      fieldIds.values.toSet(),
      transaction,
    );
    final activeOverrideFields = <MergeFieldKey, CrdtDataAttemptedValue>{};
    for (final MapEntry(key: fieldKey, value: fieldId) in fieldIds.entries) {
      final attempted = attemptedValues[fieldId];
      if (attempted == null) continue;
      activeOverrideFields[fieldKey] = attempted;
    }
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

  /// Fields whose domain value already equals the stored authored value.
  ///
  /// A tombstone restoration that writes the retained authored UUID is not a
  /// new unique claim; skip the field-HLC bump so winner selection keeps the
  /// original claim timestamp.
  Future<Set<MergeFieldKey>> findRestoredAuthoredFields({
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
    if (fields.isEmpty) return const {};

    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      rowIds,
      columnNames.toList(),
      transaction,
    );
    return {
      for (final field in fields)
        if (field.attemptedValue != null)
          if (projectionValuesEqual(
            valuesByRowId[field.row!.uuidRowId]?[field.column!.name],
            field.attemptedValue!.value,
          ))
            (tableName, field.row!.uuidRowId, field.column!.name),
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
  Future<Map<MergeRowKey, Map<String, Object?>>> project(
    Transaction transaction, {
    List<PendingProjectionRow> pendingInserts = const [],
    Map<MergeFieldKey, Object?> authoredOverlays = const {},
    bool materialize = true,
  }) async {
    final state = await _loadProjectionState(
      transaction,
      pendingInserts: pendingInserts,
      authoredOverlays: authoredOverlays,
    );
    if (state.rows.isEmpty) return const {};

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
  }) async {
    final rows = <MergeRowKey, _ProjectedForeignKeyRow>{};
    final fieldIds = <MergeFieldKey, int>{};
    final attemptedValues = <MergeFieldKey, CrdtDataAttemptedValue>{};
    final fieldHlcs = <MergeFieldKey, Hlc>{};
    final columnsByTable = <String, Set<String>>{};

    for (final edge in _foreignKeys.edges) {
      columnsByTable.putIfAbsent(edge.childTableName, () => {}).add(edge.childColumn);
      if (edge.parentColumn != 'id') {
        columnsByTable
            .putIfAbsent(edge.parentTableName, () => {})
            .add(edge.parentColumn);
      }
    }
    for (final tableName in _context.syncTableByName.keys) {
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

    for (final tableName in _context.syncTableByName.keys) {
      final (tableId, _) = _context.schema[tableName]!;
      final userId = _context.hlcManagerFor(transaction).normalizedScopeId;
      final crdtRows = await CrdtDataRow.db.find(
        _context.databaseSession,
        where: (t) => t.scopeId.equals(userId) & t.tblId.equals(tableId),
        include: CrdtDataRow.include(
          node: CrdtNode.include(),
          deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
        ),
        orderBy: (t) => t.uuidRowId,
        transaction: transaction,
      );
      if (crdtRows.isEmpty) continue;

      final rowIds = {for (final row in crdtRows) row.uuidRowId};
      final columnNames = columnsByTable[tableName] ?? const <String>{};
      final valuesByRowId = columnNames.isEmpty
          ? <UuidValue, Map<String, Object?>>{}
          : await _context.readDomainColumnValues(
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
          values: Map<String, Object?>.from(valuesByRowId[rowId] ?? const {}),
        );
      }

      if (columnNames.isNotEmpty) {
        final loadedFields = await _loadFields(
          tableName: tableName,
          rowIds: rowIds,
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

  Future<Map<MergeRowKey, Map<String, Object?>>> _materializeValues({
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

    return {
      for (final row in state.rows.values)
        row.key: Map<String, Object?>.from(row.values),
    };
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

      var fieldId = state.fieldIds[fieldKey];
      fieldId ??= await _ensureFieldId(fieldKey, state, transaction);
      final reason =
          reasons[fieldKey] ??
          (hidden.contains(rowKey)
              ? CrdtProjectionReason.hiddenUniqueRelease
              : CrdtProjectionReason.uniqueConflict);
      desired[fieldId] = (fieldId: fieldId, value: authored, reason: reason);
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

  Future<int> _ensureFieldId(
    MergeFieldKey fieldKey,
    _ForeignKeyProjectionState state,
    Transaction transaction,
  ) async {
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
    // The projector's state only holds fields it loaded for the columns and
    // scope of this pass, so a field for this row and column can already exist.
    // Reuse it instead of inserting a duplicate onto the row/column index.
    final existing = await CrdtDataField.db.findFirstRow(
      _context.databaseSession,
      where: (t) =>
          t.rowId.equals(row.crdtRow.id) & t.columnId.equals(columnId),
      transaction: transaction,
    );
    if (existing != null) {
      state.fieldIds[fieldKey] = existing.id!;
      return existing.id!;
    }

    final inserted = await CrdtDataField.db.insert(
      _context.databaseSession,
      [
        CrdtDataField(
          rowId: row.crdtRow.id!,
          columnId: columnId,
          nodeId: row.crdtRow.nodeId,
          hlcDatetime: row.crdtRow.hlcDatetime,
          hlcCounter: row.crdtRow.hlcCounter,
        ),
      ],
      transaction: transaction,
    );
    final fieldId = inserted.single.id!;
    state.fieldIds[fieldKey] = fieldId;
    return fieldId;
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

  int _compareRowKeys(MergeRowKey left, MergeRowKey right) {
    final tableComparison = left.$1.compareTo(right.$1);
    if (tableComparison != 0) return tableComparison;
    return left.$2.uuid.compareTo(right.$2.uuid);
  }
}
