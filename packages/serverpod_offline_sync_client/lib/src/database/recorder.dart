import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../managers/hlc.dart';
import '../managers/user.dart';
import '../protocol/protocol.dart';
import 'database.dart';
import 'schema.dart';
import 'session.dart';

/// Persists additional CRDT rows after a mutating ORM operation completes.
///
/// Callbacks receive the underlying database (not the CRDT proxy) and the
/// active transaction. Use that database for follow-up inserts so work is not
/// wrapped again by the proxy.
class CrdtMutationRecorder {
  /// Creates a [CrdtMutationRecorder] instance.
  CrdtMutationRecorder(
    this._db, {
    required this.persistentUserId,
    required this.syncTables,
  }) : assert(
         _db is! CrdtDatabase,
         'The database must be the user database, not the CRDT database. '
         'Passing a CRDT database would cause an infinite recursion.',
       );

  final Database _db;

  late final _session = CrdtDatabaseSession(
    _db,
    syncTables: syncTables,
    persistentUserId: persistentUserId,
  );

  late Map<String, (int, Map<String, CrdtSchemaColumn>)> _schema;

  late final _tableDefinitionsByName = {
    for (final table in _db.serializationManager.getTargetTableDefinitions())
      table.name: table,
  };

  /// Initializes the CRDT recorder.
  ///
  /// Safe to call again after the database was wiped (e.g. test `tearDown`)
  /// for in-memory schema ids to match new rows.
  Future<void> initialize() async {
    final schemaRegistry = CrdtSchemaRegistry(_session, syncTables: syncTables);
    final (tableRows, columnRows) = await schemaRegistry.syncAndGetSchema();
    _schema = {
      for (final t in tableRows)
        t.name: (
          t.id!,
          {for (final c in columnRows.where((c) => c.tblId == t.id)) c.name: c},
        ),
    };
  }

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  /// The list of tables to sync with CRDT.
  final List<Table> syncTables;

  late final _syncTablesNames = syncTables.map((t) => t.tableName).toSet();

  /// Whether the given table is tracked by CRDT.
  bool isCrdtTracked<T extends TableRow>([Table? table]) {
    final targetTable = table ?? _db.serializationManager.getTableForType(T);
    if (targetTable == null) return false;
    return _isCrdtTrackedTableName(targetTable.tableName);
  }

  /// Whether the given table name is tracked by CRDT.
  bool _isCrdtTrackedTableName(String tableName) {
    return _syncTablesNames.contains(tableName);
  }

  /// Insert the CRDT metadata for the inserted rows.
  Future<void> afterInsert<T extends TableRow>(
    List<T> insertedRows,
    Transaction transaction,
  ) async {
    await _forTrackedRows(insertedRows, transaction, (
      tableName,
      rowIds,
      hlcManager,
    ) async {
      final (tableId, _) = _schema[tableName]!;

      await CrdtDataRow.db.insert(
        _session,
        [for (final rowId in rowIds) _newCrdtDataRow(tableId, rowId, hlcManager)],
        transaction: transaction,
        ignoreConflicts: true,
      );
    });
  }

  /// Records a row insertion that reused an existing tombstoned domain row.
  Future<void> afterReinsert<T extends TableRow>(
    List<T> reinsertedRows,
    Transaction transaction,
  ) async {
    await _forTrackedRows(reinsertedRows, transaction, (
      tableName,
      rowIds,
      hlcManager,
    ) async {
      final crdtDataRows = await _findRequiredCrdtRows(
        tableName,
        rowIds,
        'reinserted',
        transaction,
      );

      await _touchCrdtRows(crdtDataRows, hlcManager, transaction);
      await _markCrdtRowsDeleted(crdtDataRows, false, transaction);
      await _recordUpdatedFields(reinsertedRows, crdtDataRows, null, transaction);
    });
  }

  /// Records CRDT field metadata for updated rows.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    await _forTrackedRows(updatedRows, transaction, (
      tableName,
      rowIds,
      _,
    ) async {
      final crdtDataRows = await _findRequiredCrdtRows(
        tableName,
        rowIds,
        'updated',
        transaction,
      );
      await _recordUpdatedFields(updatedRows, crdtDataRows, columns, transaction);
    });
  }

  Future<void> _forTrackedRows<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
    Future<void> Function(
      String tableName,
      Set<UuidValue> rowIds,
      HlcManager hlcManager,
    )
    record,
  ) async {
    if (rows.isEmpty) return;
    if (!isCrdtTracked<T>(rows.first.table)) return;

    await record(
      rows.first.table.tableName,
      rows.uuidRowIds,
      _getHlcManager(transaction),
    );
  }

  CrdtDataRow _newCrdtDataRow(
    int tableId,
    UuidValue rowId,
    HlcManager hlcManager,
  ) {
    final hlc = hlcManager.increment();

    return CrdtDataRow(
      userId: hlcManager.normalizedUserId,
      tblId: tableId,
      uuidRowId: rowId,
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  Future<List<CrdtDataRow>> _findRequiredCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    String operation,
    Transaction transaction, {
    bool includeDeleted = false,
  }) async {
    final crdtDataRows = await _findCrdtRows(
      tableName,
      rowIds,
      transaction,
      include: includeDeleted
          ? CrdtDataRow.include(deleted: CrdtDataDeleted.include())
          : null,
    );
    if (crdtDataRows.length != rowIds.length) {
      final found = crdtDataRows.map((e) => e.uuidRowId).toSet();
      final missing = rowIds.difference(found);
      throw StateError(
        'Missing CRDT rows for ${missing.length} $operation domain rows:\n'
        '${missing.map((id) => '  - $id').join('\n')}',
      );
    }
    return crdtDataRows;
  }

  Future<void> _touchCrdtRows(
    List<CrdtDataRow> rows,
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;

    await CrdtDataRow.db.update(
      _session,
      [for (final row in rows) _withNextHlc(row, hlcManager)],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
  }

  Future<void> _recordUpdatedFields<T extends TableRow>(
    List<T> updatedRows,
    List<CrdtDataRow> crdtDataRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    if (updatedRows.isEmpty || crdtDataRows.isEmpty) return;

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final table = updatedRows.first.table;
    final updatedColumnList = (columns ?? table.managedColumns)
        .where((c) => c.columnName != 'id')
        .toList();

    final existingFields = await CrdtDataField.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      include: CrdtDataField.include(
        column: CrdtSchemaColumn.include(),
      ),
      transaction: transaction,
    );

    final fieldByRowAndColumn = {
      for (final f in existingFields) (f.rowId, f.columnId): f,
    };

    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataField>[];
    final toUpdate = <CrdtDataField>[];
    for (final row in updatedRows) {
      final crdtDataRow = crdtDataRowByUuid[row.id as UuidValue]!;
      final (_, colMap) = _schema[row.table.tableName]!;

      for (final column in updatedColumnList) {
        final schemaCol = colMap[column.columnName];
        if (schemaCol == null) {
          throw StateError(
            'No CRDT schema column for ${row.table.tableName}.${column.columnName}',
          );
        }

        final hlc = hlcManager.increment();
        final rowPk = crdtDataRow.id!;
        final colPk = schemaCol.id!;
        final existing = fieldByRowAndColumn[(rowPk, colPk)];

        if (existing == null) {
          toInsert.add(
            CrdtDataField(
              rowId: rowPk,
              columnId: colPk,
              nodeId: crdtDataRow.nodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        } else {
          toUpdate.add(
            existing.copyWith(
              nodeId: crdtDataRow.nodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataField.db.insert(
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataField.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  /// Soft-deletes rows by recording a tombstone instead of removing them.
  ///
  /// Expects a matching [CrdtDataRow] per domain row (`uuidRowId` = domain id).
  Future<void> insteadOfDelete<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {
    if (deletedRows.isEmpty) return;
    if (!isCrdtTracked<T>(deletedRows.first.table)) return;
    await _softDeleteRowsByTable(
      deletedRows.first.table.tableName,
      deletedRows.uuidRowIds,
      transaction,
      null,
    );
  }

  Future<void> _softDeleteRowsByTable(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    Set<String>? processedRowIds,
  ) async {
    if (rowIds.isEmpty) return;
    if (!_isCrdtTrackedTableName(tableName)) return;

    final processing = processedRowIds ?? {};
    final unprocessedRowIds = rowIds
        .where((rowId) => processing.add('$tableName:$rowId'))
        .toSet();

    if (unprocessedRowIds.isEmpty) return;

    final crdtDataRows = await _findRequiredCrdtRows(
      tableName,
      unprocessedRowIds,
      'deleted',
      transaction,
      includeDeleted: true,
    );

    try {
      final visibleCrdtRows = crdtDataRows
          .where((row) => row.deleted?.isDeleted != true)
          .toList();

      if (visibleCrdtRows.isEmpty) return;
      final visibleRowIds = visibleCrdtRows.map((row) => row.uuidRowId).toSet();

      await _applyForeignKeyDeleteActions(
        tableName,
        visibleRowIds,
        transaction,
        processing,
      );
      await _releaseUniqueConflicts(tableName, visibleRowIds, transaction);
      await _markCrdtRowsDeleted(visibleCrdtRows, true, transaction);
    } finally {
      for (final rowId in unprocessedRowIds) {
        processing.remove('$tableName:$rowId');
      }
    }
  }

  /// Records field updates by table name and UUID ids.
  Future<void> recordFieldsUpdatedByTable(
    String tableName,
    Set<UuidValue> rowIds,
    List<String> columnNames,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return;
    if (!_isCrdtTrackedTableName(tableName)) return;

    final crdtDataRows = await _findCrdtRows(tableName, rowIds, transaction);
    if (crdtDataRows.isEmpty) return;

    final existingFields = await CrdtDataField.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      transaction: transaction,
    );
    final fieldByRowAndColumn = {
      for (final f in existingFields) (f.rowId, f.columnId): f,
    };

    final (_, colMap) = _schema[tableName]!;
    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataField>[];
    final toUpdate = <CrdtDataField>[];

    for (final row in crdtDataRows) {
      for (final columnName in columnNames) {
        final schemaCol = colMap[columnName];
        if (schemaCol == null) continue;

        final hlc = hlcManager.increment();
        final existing = fieldByRowAndColumn[(row.id!, schemaCol.id!)];
        if (existing == null) {
          toInsert.add(
            CrdtDataField(
              rowId: row.id!,
              columnId: schemaCol.id!,
              nodeId: hlcManager.normalizedNodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        } else {
          toUpdate.add(
            existing.copyWith(
              nodeId: hlcManager.normalizedNodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataField.db.insert(_session, toInsert, transaction: transaction);
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataField.db.update(_session, toUpdate, transaction: transaction);
    }
  }

  Future<void> _markCrdtRowsDeleted(
    List<CrdtDataRow> crdtDataRows,
    bool isDeleted,
    Transaction transaction,
  ) async {
    final existingTombs = await CrdtDataDeleted.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      transaction: transaction,
    );
    final tombByCrdtRowPk = {for (final t in existingTombs) t.rowId: t};

    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataDeleted>[];
    final toUpdate = <CrdtDataDeleted>[];

    for (final row in crdtDataRows) {
      final rowPk = row.id!;
      final hlc = hlcManager.increment();
      final existing = tombByCrdtRowPk[rowPk];

      if (existing == null) {
        toInsert.add(
          CrdtDataDeleted(
            rowId: rowPk,
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            isDeleted: isDeleted,
          ),
        );
      } else {
        toUpdate.add(
          existing.copyWith(
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            isDeleted: isDeleted,
          ),
        );
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataDeleted.db.insert(
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataDeleted.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  /// Whether the given row is soft-deleted.
  Future<bool> isDeleted<T extends TableRow>(
    T row,
    Transaction transaction,
  ) async {
    if (!isCrdtTracked<T>(row.table)) return false;
    if (row.id is! UuidValue) return false;

    final crdtRows = await _findCrdtRows(
      row.table.tableName,
      {row.id as UuidValue},
      transaction,
    );
    if (crdtRows.isEmpty) return false;

    final tombstone = await CrdtDataDeleted.db.findFirstRow(
      _session,
      where: (t) => t.rowId.equals(crdtRows.single.id),
      transaction: transaction,
    );
    return tombstone?.isDeleted ?? false;
  }

  Future<List<CrdtDataRow>> _findCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction, {
    CrdtDataRowInclude? include,
  }) {
    final (tableId, _) = _schema[tableName]!;
    return CrdtDataRow.db.find(
      _session,
      where: (t) => t.tblId.equals(tableId) & t.uuidRowId.inSet(rowIds),
      include: include,
      transaction: transaction,
    );
  }

  Future<void> _applyForeignKeyDeleteActions(
    String parentTableName,
    Set<UuidValue> parentIds,
    Transaction transaction,
    Set<String> processing,
  ) async {
    if (parentIds.isEmpty) return;

    final referencingTables = _tableDefinitionsByName.values.where(
      (table) => table.foreignKeys.any(
        (foreignKey) => foreignKey.referenceTable == parentTableName,
      ),
    );

    for (final childTable in referencingTables) {
      for (final foreignKey in childTable.foreignKeys.where(
        (foreignKey) => foreignKey.referenceTable == parentTableName,
      )) {
        if (foreignKey.columns.length != 1 || foreignKey.referenceColumns.length != 1) {
          throw StateError(
            'Composite foreign keys are not supported for CRDT soft deletes.',
          );
        }

        final childColumn = foreignKey.columns.single;
        final parentColumn = foreignKey.referenceColumns.single;
        final action = foreignKey.onDelete ?? ForeignKeyAction.noAction;

        for (final parentId in parentIds) {
          final referencedValue = parentColumn == 'id'
              ? parentId
              : await _readDomainColumnValue(
                  parentTableName,
                  parentId,
                  parentColumn,
                  transaction,
                );
          final childIds = await _findVisibleReferencingRowIds(
            tableName: childTable.name,
            columnName: childColumn,
            value: referencedValue,
            transaction: transaction,
          );
          if (childIds.isEmpty) continue;

          switch (action) {
            case ForeignKeyAction.restrict:
            case ForeignKeyAction.noAction:
              throw Exception(
                'Cannot delete $parentTableName row because '
                '${childTable.name}.$childColumn references it.',
              );
            case ForeignKeyAction.setNull:
              for (final childId in childIds) {
                await _updateDomainRow(
                  childTable.name,
                  childId,
                  {childColumn: null},
                  transaction,
                );
              }
              await recordFieldsUpdatedByTable(
                childTable.name,
                childIds,
                [childColumn],
                transaction,
              );
            case ForeignKeyAction.setDefault:
              final defaultValue = _defaultValueForColumn(
                childTable.name,
                childColumn,
              );
              if (defaultValue == null) {
                throw StateError(
                  'No default value found for ${childTable.name}.$childColumn.',
                );
              }
              for (final childId in childIds) {
                await _updateDomainRow(
                  childTable.name,
                  childId,
                  {childColumn: defaultValue},
                  transaction,
                );
              }
              await recordFieldsUpdatedByTable(
                childTable.name,
                childIds,
                [childColumn],
                transaction,
              );
            case ForeignKeyAction.cascade:
              await _softDeleteRowsByTable(
                childTable.name,
                childIds,
                transaction,
                processing,
              );
          }
        }
      }
    }
  }

  Future<void> _releaseUniqueConflicts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
  ) async {
    final tableDefinition = _tableDefinitionsByName[tableName];
    if (tableDefinition == null) return;

    final uniqueIndexes = tableDefinition.indexes.where(
      (index) =>
          index.isUnique &&
          !index.isPrimary &&
          index.elements.every(
            (element) => element.type == IndexElementDefinitionType.column,
          ),
    );

    for (final index in uniqueIndexes) {
      final columnNames = index.elements.map((e) => e.definition).toList();
      for (final rowId in rowIds) {
        final values = <String, Object?>{};
        for (final columnName in columnNames) {
          values[columnName] = await _readDomainColumnValue(
            tableName,
            rowId,
            columnName,
            transaction,
          );
        }
        if (values.values.any((value) => value == null)) continue;

        final updates = <String, Object?>{};
        for (final columnName in columnNames) {
          updates[columnName] = _conflictFreeValue(
            tableDefinition,
            columnName,
            values[columnName],
            rowId,
          );
        }

        await _updateDomainRow(tableName, rowId, updates, transaction);
        await recordFieldsUpdatedByTable(
          tableName,
          {rowId},
          columnNames,
          transaction,
        );
      }
    }
  }

  Future<Set<UuidValue>> _findVisibleReferencingRowIds({
    required String tableName,
    required String columnName,
    required Object? value,
    required Transaction transaction,
  }) async {
    final (tableId, _) = _schema[tableName]!;
    final result = await _db.unsafeQuery(
      '''
SELECT d."id"
FROM "${_escapeIdentifier(tableName)}" d
LEFT JOIN "crdt_data_rows" r
  ON r."uuidRowId" = d."id" AND r."tblId" = $tableId
LEFT JOIN "crdt_data_tombstone" tomb
  ON tomb."rowId" = r."id"
WHERE d."${_escapeIdentifier(columnName)}" = ${_sqlLiteral(value)}
  AND (tomb."id" IS NULL OR tomb."isDeleted" = 0)
''',
      transaction: transaction,
    );
    return {
      for (final row in result) _uuidFromDatabase(row[0]),
    };
  }

  Future<void> _updateDomainRow(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> updates,
    Transaction transaction,
  ) async {
    if (updates.isEmpty) return;

    final assignments = updates.entries
        .map(
          (entry) => '"${_escapeIdentifier(entry.key)}" = ${_sqlLiteral(entry.value)}',
        )
        .join(', ');

    await _db.unsafeExecute(
      '''
UPDATE "${_escapeIdentifier(tableName)}"
SET $assignments
WHERE "id" = ${_sqlLiteral(rowId)}
''',
      transaction: transaction,
    );
  }

  Future<Object?> _readDomainColumnValue(
    String tableName,
    UuidValue rowId,
    String columnName,
    Transaction transaction,
  ) async {
    final result = await _db.unsafeQuery(
      '''
SELECT "${_escapeIdentifier(columnName)}"
FROM "${_escapeIdentifier(tableName)}"
WHERE "id" = ${_sqlLiteral(rowId)}
LIMIT 1
''',
      transaction: transaction,
    );

    if (result.isEmpty) return null;
    return result.first[0];
  }

  Object? _defaultValueForColumn(String tableName, String columnName) {
    final tableDefinition = _tableDefinitionsByName[tableName];
    if (tableDefinition == null) return null;
    final column = tableDefinition.columns.firstWhere(
      (column) => column.name == columnName,
    );
    final defaultValue = column.columnDefault;
    if (defaultValue == null) return null;
    if (column.columnType == ColumnType.uuid) {
      final unquoted = defaultValue.replaceAll("'", '');
      if (unquoted == 'random' || unquoted == 'random_v7') return null;
      return UuidValue.withValidation(unquoted);
    }
    return defaultValue.replaceAll("'", '');
  }

  Object? _conflictFreeValue(
    TableDefinition tableDefinition,
    String columnName,
    Object? value,
    UuidValue conflictingId,
  ) {
    final column = tableDefinition.columns.firstWhere(
      (column) => column.name == columnName,
    );
    if (column.columnType == ColumnType.text && value is String) {
      return '${value}__deleted__${conflictingId.uuid}';
    }
    throw StateError(
      'Cannot make tombstoned unique value conflict-free for '
      '${tableDefinition.name}.$columnName.',
    );
  }

  CrdtDataRow _withNextHlc(CrdtDataRow row, HlcManager hlcManager) {
    final hlc = hlcManager.increment();
    return row.copyWith(
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  HlcManager _getHlcManager(Transaction transaction) {
    final user = _getEffectiveUser(transaction);
    return HlcManager.forUser(user);
  }

  CrdtUser _getEffectiveUser(Transaction transaction) {
    final user = userForTransaction[transaction];
    if (user != null) return user;
    if (persistentUserId == null) {
      throw StateError('No user ID found for transaction or persistent user ID.');
    }
    return CrdtUserManager.getCached(persistentUserId!);
  }
}

String _escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

String _sqlLiteral(Object? value) {
  if (value == null) return 'NULL';
  if (value is UuidValue) {
    return "X'${value.uuid.replaceAll('-', '').toLowerCase()}'";
  }
  if (value is String) return "'${value.replaceAll("'", "''")}'";
  if (value is bool) return value ? '1' : '0';
  if (value is DateTime) return value.millisecondsSinceEpoch.toString();
  if (value is num) return value.toString();
  throw StateError('Unsupported SQL literal type: ${value.runtimeType}.');
}

UuidValue _uuidFromDatabase(Object? value) {
  if (value is UuidValue) return value;
  if (value is Uint8List) return UuidValue.fromByteList(value);
  if (value is List<int>) return UuidValue.fromByteList(Uint8List.fromList(value));
  return UuidValue.withValidation(value! as String);
}

extension on List<TableRow> {
  Set<UuidValue> get uuidRowIds {
    if (isEmpty) return {};
    if (first.id == null) throw StateError('Row IDs must be non-null.');
    if (first.id is! UuidValue) throw StateError('Row IDs must be UuidValue.');
    return {for (final row in this) row.id as UuidValue};
  }
}
