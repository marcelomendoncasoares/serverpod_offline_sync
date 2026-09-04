import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/extensions.dart';
import '../../crdt/merge.dart';
import '../../generated/protocol.dart';
import '../../hlc/hlc.dart';
import '../unique_index_utils.dart';
import 'database_helpers.dart';
import 'recorder_context.dart';
import 'types.dart';

typedef _UniqueConflict = ({
  CrdtDataRow row,
  UniqueIndexConflictRelease uniqueIndex,
});

@internal
/// Resolves unique constraint conflicts that appear while merging CRDT
/// changes or soft-deleting rows.
class CrdtUniqueConflictResolver {
  /// Creates a resolver over the given recorder context.
  CrdtUniqueConflictResolver(this._context);

  final CrdtRecorderContext _context;

  /// Resolves unique conflicts for an incoming insert.
  Future<({Map<String, Object?> data, bool changed})> resolveForIncomingInsert(
    CrdtMergeInsert insert,
    Map<String, Object?> data,
    MergeContext context,
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
      final incomingClaimHlc = _incomingInsertUniqueClaim(
        insert: insert,
        uniqueIndex: conflict.uniqueIndex,
        context: context,
      );
      final conflictClaimHlc = await _uniqueIndexHlc(
        tableName: insert.tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );

      if (incomingClaimHlc > conflictClaimHlc) {
        resolvedData.addAll(
          _uniqueConflictFreeValuesForData(
            insert.tableName,
            insert.uuidRowId,
            resolvedData,
            conflict.uniqueIndex,
          ),
        );
        changed = true;
      } else {
        await _releaseUniqueConflictForRow(
          tableName: insert.tableName,
          rowId: conflict.row.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          transaction: transaction,
        );
      }
    }

    return (data: resolvedData, changed: changed);
  }

  Hlc _incomingInsertUniqueClaim({
    required CrdtMergeInsert insert,
    required UniqueIndexConflictRelease uniqueIndex,
    required MergeContext context,
  }) {
    var uniqueHlc = insert.hlc;
    for (final columnName in uniqueIndex.indexedColumns) {
      uniqueHlc = uniqueHlc.maxBetween(
        context.incomingFieldHlcs[(
          insert.tableName,
          insert.uuidRowId,
          columnName,
        )],
      );
    }
    return uniqueHlc;
  }

  /// Resolves unique conflicts for a single incoming field update.
  Future<Map<String, Object?>> resolveForIncomingUpdate(
    CrdtMergeUpdate update,
    CrdtDataRow row,
    MergeContext context,
    Transaction transaction,
  ) {
    return resolveForIncomingUpdates(
      tableName: update.tableName,
      row: row,
      updates: {update.columnName: update.value},
      context: context,
      transaction: transaction,
    );
  }

  /// Resolves unique conflicts for one or more incoming field updates.
  Future<Map<String, Object?>> resolveForIncomingUpdates({
    required String tableName,
    required CrdtDataRow row,
    required Map<String, Object?> updates,
    required MergeContext context,
    required Transaction transaction,
  }) async {
    if (updates.keys.every(
      (columnName) => !_isUniqueIndexedColumn(tableName, columnName),
    )) {
      return updates;
    }

    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) {
      return updates;
    }

    final uniqueColumnNamesToRead = {
      for (final uniqueIndex in _context.uniqueIndexesForTable(tableDefinition))
        ...uniqueIndex.indexedColumns,
    };
    if (uniqueColumnNamesToRead.isEmpty) {
      return updates;
    }

    final currentValues = await _context.readDomainColumnValues(
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

    final resolvedUpdates = Map<String, Object?>.from(updates);
    for (final conflict in conflicts) {
      final rowClaimHlc = await _uniqueIndexHlc(
        tableName: tableName,
        row: row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );
      final conflictClaimHlc = await _uniqueIndexHlc(
        tableName: tableName,
        row: conflict.row,
        uniqueIndex: conflict.uniqueIndex,
        fields: context.fields,
        transaction: transaction,
      );

      if (rowClaimHlc > conflictClaimHlc) {
        final releasedValues = _uniqueConflictFreeValuesForData(
          tableName,
          row.uuidRowId,
          values,
          conflict.uniqueIndex,
        );
        for (final columnName in conflict.uniqueIndex.releaseColumnNames) {
          if (releasedValues.containsKey(columnName)) {
            resolvedUpdates[columnName] = releasedValues[columnName];
            values[columnName] = releasedValues[columnName];
          }
        }
      } else {
        await _releaseUniqueConflictForRow(
          tableName: tableName,
          rowId: conflict.row.uuidRowId,
          uniqueIndex: conflict.uniqueIndex,
          transaction: transaction,
        );
      }
    }

    return resolvedUpdates;
  }

  Map<String, Object?> _uniqueConflictFreeValuesForData(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> data,
    UniqueIndexConflictRelease uniqueIndex,
  ) {
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return data;

    final released = Map<String, Object?>.from(data);
    final values = {
      for (final columnName in uniqueIndex.indexedColumns)
        columnName: released[columnName],
    };
    if (values.values.any((value) => value == null)) return released;

    for (final column in uniqueIndex.releaseColumns) {
      released[column.columnName] = _context.conflictFreeValue(
        column,
        values[column.columnName],
        tableName,
        rowId,
        'conflict',
      );
    }
    return released;
  }

  Future<void> _releaseUniqueConflictForRow({
    required String tableName,
    required UuidValue rowId,
    required UniqueIndexConflictRelease uniqueIndex,
    required Transaction transaction,
  }) async {
    final valuesByRowId = await _context.readDomainColumnValues(
      tableName,
      {rowId},
      uniqueIndex.indexedColumns,
      transaction,
    );
    final values = valuesByRowId[rowId];
    if (values == null || values.values.any((value) => value == null)) return;

    final releasedValues = _uniqueConflictFreeValuesForData(
      tableName,
      rowId,
      values,
      uniqueIndex,
    );
    await _context.updateDomainRows(tableName, {rowId}, releasedValues, transaction);
  }

  Future<List<_UniqueConflict>> _findVisibleUniqueConflicts({
    required String tableName,
    required UuidValue rowId,
    required Map<String, Object?> values,
    required Transaction transaction,
  }) async {
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return const [];

    final uniqueIndexes = _context.uniqueIndexesForTable(tableDefinition);
    if (uniqueIndexes.isEmpty) return const [];

    final uniqueIndexesByConflictId = <UuidValue, Set<UniqueIndexConflictRelease>>{};
    for (final uniqueIndex in uniqueIndexes) {
      final columnValues = {
        for (final columnName in uniqueIndex.indexedColumns)
          if (values.containsKey(columnName)) columnName: values[columnName],
      };
      if (uniqueIndex.scoped) {
        columnValues['scopeId'] = _context.hlcManagerFor(transaction).normalizedScopeId;
      }
      final expectedValueCount =
          uniqueIndex.indexedColumns.length + (uniqueIndex.scoped ? 1 : 0);
      if (columnValues.length != expectedValueCount) continue;
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
    final conflictRows = await _context.findCrdtRows(
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

  /// Returns the HLC for this row's current claim on [uniqueIndex].
  ///
  /// Composite indexes use the newest field HLC among their columns; rows with
  /// no field metadata fall back to the row insert HLC. Missing field metadata
  /// is loaded lazily because conflicting rows may not be part of the preloaded
  /// merge context.
  Future<Hlc> _uniqueIndexHlc({
    required String tableName,
    required CrdtDataRow row,
    required UniqueIndexConflictRelease uniqueIndex,
    required Map<MergeFieldKey, CrdtDataField> fields,
    required Transaction transaction,
  }) async {
    final uniqueColumnNames = {
      ...uniqueIndex.indexedColumns,
    };
    final missingColumnIds = <int>{};
    final maxFieldHlc = <Hlc>[];
    for (final columnName in uniqueColumnNames) {
      final field = fields[(tableName, row.uuidRowId, columnName)];
      if (field == null) {
        final columnId = _context.schemaColumn(tableName, columnName)?.id;
        if (columnId != null) missingColumnIds.add(columnId);
        continue;
      }

      maxFieldHlc.add(field.hlc);
    }

    if (missingColumnIds.isNotEmpty && row.id != null) {
      final loadedFields = await CrdtDataField.db.find(
        _context.databaseSession,
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
    return _context.findVisibleDomainRowIdsWhere(
      tableName: tableName,
      predicates: [
        for (final MapEntry(key: columnName, value: value) in values.entries)
          domainColumnPredicate(columnName, value),
        domainColumnNotPredicate('id', rowId),
      ],
      transaction: transaction,
    );
  }

  /// Whether [columnName] participates in any unique index of [tableName].
  ///
  /// Foreign key projection needs this to know when materializing a value onto
  /// a hidden row would occupy the physical unique index.
  bool isUniqueIndexedColumn(String tableName, String columnName) =>
      _isUniqueIndexedColumn(tableName, columnName);

  bool _isUniqueIndexedColumn(String tableName, String columnName) {
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return false;
    return _context
        .uniqueIndexesForTable(tableDefinition)
        .any((i) => i.indexedColumns.contains(columnName));
  }

  Future<void> releaseOnDelete(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
  ) async {
    final tableDefinition = _context.tableDefinitionsByName[tableName];
    if (tableDefinition == null) return;

    final uniqueIndexes = _context.uniqueIndexesForTable(tableDefinition);
    for (final uniqueIndex in uniqueIndexes) {
      final releaseColumnNames = uniqueIndex.releaseColumnNames.toList();

      final valuesByRowId = await _context.readDomainColumnValues(
        tableName,
        rowIds,
        uniqueIndex.indexedColumns,
        transaction,
      );
      final updatedRowIds = <UuidValue>{};

      for (final MapEntry(key: rowId, value: values) in valuesByRowId.entries) {
        if (values.values.any((value) => value == null)) continue;

        final updates = <String, Object?>{};
        for (final column in uniqueIndex.releaseColumns) {
          updates[column.columnName] = _context.conflictFreeValue(
            column,
            values[column.columnName],
            tableDefinition.name,
            rowId,
            'deleted',
          );
        }

        await _context.updateDomainRows(tableName, {rowId}, updates, transaction);
        updatedRowIds.add(rowId);
      }

      if (updatedRowIds.isNotEmpty) {
        await _context.recordFieldsUpdatedByTable(
          tableName,
          updatedRowIds,
          releaseColumnNames,
          transaction,
        );
      }
    }
  }
}
