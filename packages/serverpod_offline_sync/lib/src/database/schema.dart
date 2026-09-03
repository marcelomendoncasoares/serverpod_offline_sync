import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import 'merge_utils/database_helpers.dart';
import 'unique_index_utils.dart';

/// Thrown when CRDT schema reconciliation cannot be applied safely.
///
/// The registry and projection state are left unchanged. Each message names
/// the affected table and column and tells the developer how to convert data
/// and attest the new type identity on [CrdtSchemaColumn].
class CrdtSchemaReconciliationException implements Exception {
  /// Creates a [CrdtSchemaReconciliationException] from one or more failures.
  CrdtSchemaReconciliationException(this.failures)
    : assert(failures.isNotEmpty, 'At least one failure is required.');

  /// Actionable failure messages, one per blocked change.
  final List<String> failures;

  @override
  String toString() => 'CrdtSchemaReconciliationException: ${failures.join(' ')}';
}

/// Manages the CRDT schema for a database.
class CrdtSchemaRegistry {
  /// Creates a new instance of [CrdtSchemaRegistry].
  CrdtSchemaRegistry(
    this._session, {
    required this.syncTables,
    Iterable<TableDefinition>? tableDefinitions,
  }) {
    final tablesWithoutUuidPk = syncTables.where(
      (table) => table.id is! Column<UuidValue>,
    );
    if (tablesWithoutUuidPk.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize tables with a UUID primary key, but '
        '${tablesWithoutUuidPk.length} table(s) do not have a UUID primary key: '
        '${tablesWithoutUuidPk.map((t) => '"${t.tableName}"').join(', ')}',
      );
    }

    final tablesWithoutScopeId = syncTables
        .where((table) => table.crdtScopeIdColumn == null)
        .toList();
    if (tablesWithoutScopeId.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize tables with a nullable int scopeId column, '
        'but ${tablesWithoutScopeId.length} table(s) are missing it or declare '
        'it with the wrong type: '
        '${tablesWithoutScopeId.map((t) => '"${t.tableName}"').join(', ')}'
        '$_scopeIdFieldHelp',
      );
    }

    _tableDefinitionsByName = {
      for (final tableDefinition
          in _session.db.serializationManager.getTargetTableDefinitions())
        tableDefinition.name: tableDefinition,
      for (final tableDefinition in tableDefinitions ?? const <TableDefinition>[])
        tableDefinition.name: tableDefinition,
    };
    final tablesMissingDefinitions = [
      for (final table in syncTables)
        if (!_tableDefinitionsByName.containsKey(table.tableName)) table.tableName,
    ];
    if (tablesMissingDefinitions.isNotEmpty) {
      throw StateError(
        'CRDT requires a TableDefinition for every synced table, but '
        '${tablesMissingDefinitions.length} table(s) have none: '
        '${tablesMissingDefinitions.map((name) => '"$name"').join(', ')}.',
      );
    }
    final tableDefinitionsByName = _tableDefinitionsByName;
    final globalUniqueIndexes = _globalUniqueIndexViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (globalUniqueIndexes.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize tables with per-scope unique indexes, but '
        '${globalUniqueIndexes.length} unique index(es) do not include scopeId: '
        '${globalUniqueIndexes.join(', ')}. '
        'Add scopeId to the unique index fields. '
        'The only allowed global unique indexes are foreign-key-only indexes '
        'whose target tables are also synchronized.',
      );
    }

    final requiredFKeyUniqueColumns = crdtRequiredForeignKeyOnlyUniqueColumnViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (requiredFKeyUniqueColumns.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize 1:1 relations when the foreign key column is '
        'nullable, but the following foreign keys are non-nullable: '
        '"${requiredFKeyUniqueColumns.join("', '")}". '
        'Make the relation optional/nullable.',
      );
    }

    final jsonUniqueIndexes = crdtJsonUniqueIndexViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (jsonUniqueIndexes.isNotEmpty) {
      throw StateError(
        'CRDT cannot synchronize unique indexes that include json or jsonb '
        'columns, because sync does not define canonical cross-dialect JSON '
        'equality: ${jsonUniqueIndexes.join(', ')}. Remove those columns from '
        'the unique index.',
      );
    }

    final nonReleasableUniqueIndexes = crdtNonReleasableUniqueIndexViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (nonReleasableUniqueIndexes.isNotEmpty) {
      throw StateError(
        'CRDT unique conflict resolution requires at least one releasable '
        'non-scope column for ${nonReleasableUniqueIndexes.length} unique '
        'index(es): ${nonReleasableUniqueIndexes.join(', ')}. '
        'Only nullable, text, and non-FK UUID unique columns are supported.',
      );
    }

    final tablesMissingScopeIdRelation = _missingCrdtScopeRelations(
      syncTables,
      tableDefinitionsByName,
    );
    if (tablesMissingScopeIdRelation.isNotEmpty) {
      throw StateError(
        'CRDT synced tables must declare scopeId as a cascade relation to '
        'crdt_scopes, but ${tablesMissingScopeIdRelation.length} table(s) are '
        'missing this relation: '
        '${tablesMissingScopeIdRelation.map((t) => '"$t"').join(', ')}'
        '$_scopeIdFieldHelp',
      );
    }

    final nonDeferredForeignKeys = _nonDeferredForeignKeyViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (nonDeferredForeignKeys.isNotEmpty) {
      throw StateError(
        'CRDT requires deferred foreign keys for non-optional relations, but '
        '${nonDeferredForeignKeys.length} foreign key(s) are not deferred: '
        '${nonDeferredForeignKeys.map((fk) => '"$fk"').join(', ')}. Mark these '
        'as "deferred" or make the relation optional.',
      );
    }

    final restrictForeignKeys = _restrictForeignKeyViolations(
      syncTables,
      tableDefinitionsByName,
    );
    if (restrictForeignKeys.isNotEmpty) {
      throw StateError(
        'CRDT cannot synchronize tables with "onDelete=Restrict" foreign keys, '
        'but ${restrictForeignKeys.length} foreign key(s) use it: '
        '${restrictForeignKeys.map((fk) => '"$fk"').join(', ')}. Replace by '
        '"onDelete=NoAction" instead, which produces the same effect.',
      );
    }
  }

  /// Help text appended to schema validation errors that describes the required
  /// `scopeId` ownership field on every synced model.
  static const _scopeIdFieldHelp =
      '\n\n'
      'Add this field to every synced model:\n'
      'fields:\n'
      '  id: UuidValue?, defaultPersist=random_v7\n'
      '  ### Owner scope of this row. Maintained by the CRDT sync layer.\n'
      '  scopeId: int?, relation(parent=crdt_scopes, onDelete=Cascade)\n\n'
      'If the column is declared with scope=serverOnly, remove the scope; '
      'the column must exist on every database.';

  final DatabaseSession _session;

  /// The list of tables to sync with CRDT.
  final List<Table> syncTables;

  /// Whether the last [syncAndGetSchema] call inserted, updated, or deleted
  /// registry rows.
  bool get registryChanged => _registryChanged;
  var _registryChanged = false;

  /// Serverpod table definitions by table name.
  late final Map<String, TableDefinition> _tableDefinitionsByName;

  late final _columnsPerTableName = {
    for (final table in syncTables)
      table.tableName: [
        for (final column in table.columns)
          if (column.columnName != 'scopeId') column.columnName,
      ],
  };

  /// The target column definitions of every synced table, keyed by table and
  /// column name.
  late final _columnDefinitionsPerTableName = {
    for (final table in syncTables)
      table.tableName: {
        for (final column
            in _tableDefinitionsByName[table.tableName]?.columns ??
                const <ColumnDefinition>[])
          if (column.name != 'scopeId') column.name: column,
      },
  };

  /// Ensures that the CRDT schema is created for the database.
  ///
  /// Reconciliation plans every addition, drop, possible rename, and type or
  /// policy change before mutating. Failures throw
  /// [CrdtSchemaReconciliationException] without writing registry rows.
  Future<(List<CrdtSchemaTable>, List<CrdtSchemaColumn>)> syncAndGetSchema() async {
    return _session.db.transaction((transaction) async {
      final existingTables = await CrdtSchemaTable.db.find(
        _session,
        transaction: transaction,
      );
      final existingColumns = await CrdtSchemaColumn.db.find(
        _session,
        transaction: transaction,
      );
      final plan = await _planReconciliation(
        existingTables: existingTables,
        existingColumns: existingColumns,
        transaction: transaction,
      );
      if (plan.failures.isNotEmpty) {
        throw CrdtSchemaReconciliationException(plan.failures);
      }
      return _applyReconciliation(
        plan,
        existingTables: existingTables,
        existingColumns: existingColumns,
        transaction: transaction,
      );
    });
  }

  Future<_SchemaReconciliationPlan> _planReconciliation({
    required List<CrdtSchemaTable> existingTables,
    required List<CrdtSchemaColumn> existingColumns,
    required Transaction transaction,
  }) async {
    final existingTablesByName = {
      for (final table in existingTables) table.name: table,
    };
    final targetTableNames = _columnsPerTableName.keys.toSet();
    final tablesToInsert = [
      for (final name in targetTableNames)
        if (!existingTablesByName.containsKey(name)) name,
    ]..sort();
    final tablesToDelete = [
      for (final table in existingTables)
        if (!targetTableNames.contains(table.name)) table,
    ];

    final columnsByTableId = <int, Map<String, CrdtSchemaColumn>>{};
    for (final column in existingColumns) {
      columnsByTableId.putIfAbsent(column.tblId, () => {})[column.name] = column;
    }

    final columnsToInsert = <_PendingSchemaColumn>[];
    final columnsToUpdate = <CrdtSchemaColumn>[];
    final columnsToDelete = <CrdtSchemaColumn>[];
    final failures = <String>[];

    for (final tableName in targetTableNames) {
      final existingTable = existingTablesByName[tableName];
      final existingByName = existingTable == null
          ? const <String, CrdtSchemaColumn>{}
          : columnsByTableId[existingTable.id!] ?? const <String, CrdtSchemaColumn>{};
      final targetColumnNames = _columnsPerTableName[tableName]!;
      final addedColumnNames = [
        for (final columnName in targetColumnNames)
          if (!existingByName.containsKey(columnName)) columnName,
      ]..sort();
      final droppedColumns = [
        for (final column in existingByName.values)
          if (!targetColumnNames.contains(column.name)) column,
      ];

      if (addedColumnNames.isNotEmpty && droppedColumns.isNotEmpty) {
        final droppedWithMetadata = <String>[];
        for (final column in droppedColumns) {
          if (column.id != null &&
              await _hasFieldMetadata(column.id!, transaction)) {
            droppedWithMetadata.add('$tableName.${column.name}');
          }
        }
        if (droppedWithMetadata.isNotEmpty) {
          failures.add(
            'Cannot reconcile $tableName: columns '
            '${droppedWithMetadata.join(', ')} would be dropped while '
            '${addedColumnNames.map((name) => '$tableName.$name').join(', ')} '
            'would be added, and the dropped columns still have CRDT field '
            'metadata. Update CrdtSchemaColumn.name in a migration to rename, '
            'or explicitly delete the old schema column (cascading field '
            'metadata) for a real drop, then initialize again.',
          );
        }
      }

      for (final columnName in addedColumnNames) {
        columnsToInsert.add(
          (
            tableName: tableName,
            tblId: existingTable?.id,
            columnName: columnName,
          ),
        );
      }
      columnsToDelete.addAll(droppedColumns);

      for (final columnName in targetColumnNames) {
        final stored = existingByName[columnName];
        if (stored == null) continue;
        final definition = _requiredColumnDefinition(tableName, columnName);
        if (_typeIdentityMatches(stored, definition)) continue;

        if (stored.id != null &&
            await _hasAttemptedValueRows(stored.id!, transaction)) {
          failures.add(
            'Cannot change $tableName.$columnName type identity from '
            '${_formatTypeIdentity(stored)} to '
            '${_formatTypeIdentityFromDefinition(definition)}, because '
            'attempted-value rows still exist. Convert the domain column and '
            'every affected attempted-value envelope to the target types, then '
            'attest completion by updating CrdtSchemaColumn for '
            '$tableName.$columnName to '
            '${_formatTypeIdentityFromDefinition(definition)} as the final '
            'step of the same migration.',
          );
          continue;
        }

        columnsToUpdate.add(
          stored.copyWith(
            columnType: definition.columnType.name,
            dartType: definition.dartType ?? '',
            isNullable: definition.isNullable,
          ),
        );
      }
    }

    if (tablesToInsert.isNotEmpty && tablesToDelete.isNotEmpty) {
      final droppedTablesWithRows = <String>[];
      for (final table in tablesToDelete) {
        if (table.id != null && await _hasDataRows(table.id!, transaction)) {
          droppedTablesWithRows.add(table.name);
        }
      }
      if (droppedTablesWithRows.isNotEmpty) {
        failures.add(
          'Cannot reconcile schema: tables ${droppedTablesWithRows.join(', ')} '
          'would be dropped while ${tablesToInsert.join(', ')} would be added, '
          'and the dropped tables still have CRDT row metadata. Update '
          'CrdtSchemaTable.name in a migration to rename, or explicitly delete '
          'the old schema table (cascading metadata) for a real drop, then '
          'initialize again.',
        );
      }
    }

    return _SchemaReconciliationPlan(
      tablesToInsert: tablesToInsert,
      tablesToDelete: tablesToDelete,
      columnsToInsert: columnsToInsert,
      columnsToUpdate: columnsToUpdate,
      columnsToDelete: columnsToDelete,
      failures: failures,
    );
  }

  Future<(List<CrdtSchemaTable>, List<CrdtSchemaColumn>)> _applyReconciliation(
    _SchemaReconciliationPlan plan, {
    required List<CrdtSchemaTable> existingTables,
    required List<CrdtSchemaColumn> existingColumns,
    required Transaction transaction,
  }) async {
    _registryChanged = plan.hasMutations;

    // The registry is small but this runs on the path into the app, so the
    // result is folded from the rows already read plus what the writes return
    // rather than reading both tables a second time.
    final insertedTables = plan.tablesToInsert.isEmpty
        ? const <CrdtSchemaTable>[]
        : await CrdtSchemaTable.db.insert(
            _session,
            [for (final name in plan.tablesToInsert) CrdtSchemaTable(name: name)],
            transaction: transaction,
          );

    if (plan.columnsToDelete.isNotEmpty) {
      await CrdtSchemaColumn.db.delete(
        _session,
        plan.columnsToDelete,
        transaction: transaction,
      );
    }
    if (plan.tablesToDelete.isNotEmpty) {
      await CrdtSchemaTable.db.delete(
        _session,
        plan.tablesToDelete,
        transaction: transaction,
      );
    }

    // Deleted ids are only removed from rows read before the delete: the
    // database can hand a freed id straight back to a row inserted after it.
    final deletedTableIds = {for (final table in plan.tablesToDelete) table.id};
    final tableRows = [
      for (final table in existingTables)
        if (!deletedTableIds.contains(table.id) &&
            _columnsPerTableName.containsKey(table.name))
          table,
      for (final table in insertedTables)
        if (_columnsPerTableName.containsKey(table.name)) table,
    ];
    final tableIdByName = {for (final table in tableRows) table.name: table.id!};
    final tableNameById = {for (final table in tableRows) table.id!: table.name};

    final insertedColumns = plan.columnsToInsert.isEmpty
        ? const <CrdtSchemaColumn>[]
        : await CrdtSchemaColumn.db.insert(
            _session,
            [
              for (final pending in plan.columnsToInsert)
                _newSchemaColumn(
                  tableName: pending.tableName,
                  tblId: pending.tblId ?? tableIdByName[pending.tableName]!,
                  columnName: pending.columnName,
                ),
            ],
            transaction: transaction,
          );
    if (plan.columnsToUpdate.isNotEmpty) {
      await CrdtSchemaColumn.db.update(
        _session,
        plan.columnsToUpdate,
        columns: (t) => [t.columnType, t.dartType, t.isNullable],
        transaction: transaction,
      );
    }

    final deletedColumnIds = {for (final column in plan.columnsToDelete) column.id};
    final updatedColumnsById = {
      for (final column in plan.columnsToUpdate) column.id: column,
    };
    bool isTargetColumn(CrdtSchemaColumn column) {
      final tableName = tableNameById[column.tblId];
      if (tableName == null) return false;
      return (_columnsPerTableName[tableName] ?? const <String>[]).contains(
        column.name,
      );
    }

    final columnRows = [
      for (final stored in existingColumns)
        if (!deletedColumnIds.contains(stored.id))
          if (updatedColumnsById[stored.id] ?? stored case final column)
            if (isTargetColumn(column)) column,
      for (final column in insertedColumns)
        if (isTargetColumn(column)) column,
    ];

    return (tableRows, columnRows);
  }

  CrdtSchemaColumn _newSchemaColumn({
    required String tableName,
    required int tblId,
    required String columnName,
  }) {
    final definition = _requiredColumnDefinition(tableName, columnName);
    return CrdtSchemaColumn(
      tblId: tblId,
      name: columnName,
      columnType: definition.columnType.name,
      dartType: definition.dartType ?? '',
      isNullable: definition.isNullable,
    );
  }

  ColumnDefinition _requiredColumnDefinition(String tableName, String columnName) {
    final definition = _columnDefinitionsPerTableName[tableName]?[columnName];
    if (definition == null) {
      throw StateError(
        'No column definition found for $tableName.$columnName.',
      );
    }
    return definition;
  }

  bool _typeIdentityMatches(CrdtSchemaColumn stored, ColumnDefinition target) {
    return stored.columnType == target.columnType.name &&
        stored.dartType == (target.dartType ?? '') &&
        stored.isNullable == target.isNullable;
  }

  String _formatTypeIdentity(CrdtSchemaColumn stored) {
    return 'columnType=${stored.columnType} dartType=${stored.dartType} '
        'isNullable=${stored.isNullable}';
  }

  String _formatTypeIdentityFromDefinition(ColumnDefinition target) {
    return 'columnType=${target.columnType.name} '
        'dartType=${target.dartType ?? ''} isNullable=${target.isNullable}';
  }

  Future<bool> _hasAttemptedValueRows(int columnId, Transaction transaction) async {
    final row = await CrdtDataAttemptedValue.db.findFirstRow(
      _session,
      where: (t) => t.field.columnId.equals(columnId),
      transaction: transaction,
    );
    return row != null;
  }

  Future<bool> _hasFieldMetadata(int columnId, Transaction transaction) async {
    final row = await CrdtDataField.db.findFirstRow(
      _session,
      where: (t) => t.columnId.equals(columnId),
      transaction: transaction,
    );
    return row != null;
  }

  Future<bool> _hasDataRows(int tableId, Transaction transaction) async {
    final row = await CrdtDataRow.db.findFirstRow(
      _session,
      where: (t) => t.tblId.equals(tableId),
      transaction: transaction,
    );
    return row != null;
  }
}

class _SchemaReconciliationPlan {
  _SchemaReconciliationPlan({
    required this.tablesToInsert,
    required this.tablesToDelete,
    required this.columnsToInsert,
    required this.columnsToUpdate,
    required this.columnsToDelete,
    required this.failures,
  });

  final List<String> tablesToInsert;
  final List<CrdtSchemaTable> tablesToDelete;
  final List<_PendingSchemaColumn> columnsToInsert;
  final List<CrdtSchemaColumn> columnsToUpdate;
  final List<CrdtSchemaColumn> columnsToDelete;
  final List<String> failures;

  bool get hasMutations =>
      tablesToInsert.isNotEmpty ||
      tablesToDelete.isNotEmpty ||
      columnsToInsert.isNotEmpty ||
      columnsToUpdate.isNotEmpty ||
      columnsToDelete.isNotEmpty;
}

typedef _PendingSchemaColumn = ({
  String tableName,
  int? tblId,
  String columnName,
});

List<String> _globalUniqueIndexViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  final syncTableNames = {for (final table in syncTables) table.tableName};
  return [
    for (final tableName in syncTableNames)
      for (final index
          in tableDefinitionsByName[tableName]?.indexes ?? const <IndexDefinition>[])
        if (_isForbiddenGlobalUniqueIndex(
          tableDefinitionsByName[tableName]!,
          index,
          syncTableNames,
        ))
          '$tableName.${index.indexName}',
  ];
}

bool _isForbiddenGlobalUniqueIndex(
  TableDefinition tableDefinition,
  IndexDefinition index,
  Set<String> syncTableNames,
) {
  if (!index.isUnique || index.isPrimary) return false;
  if (isCrdtScopedUniqueIndex(index)) return false;

  return !isCrdtAllowedForeignKeyOnlyUniqueIndex(
    tableDefinition,
    index,
    syncTableNames,
  );
}

List<String> _missingCrdtScopeRelations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  return [
    for (final table in syncTables)
      if (tableDefinitionsByName.containsKey(table.tableName) &&
          !_hasCrdtScopeRelation(tableDefinitionsByName[table.tableName]!))
        table.tableName,
  ];
}

bool _hasCrdtScopeRelation(TableDefinition tableDefinition) {
  return tableDefinition.foreignKeys.any(
    (fk) => _isCrdtScopeForeignKey(fk) && fk.onDelete == ForeignKeyAction.cascade,
  );
}

bool _isCrdtScopeForeignKey(ForeignKeyDefinition fk) {
  return fk.columns.length == 1 &&
      fk.columns.single == 'scopeId' &&
      fk.referenceTable == 'crdt_scopes' &&
      fk.referenceColumns.length == 1 &&
      fk.referenceColumns.single == 'id';
}

List<String> _nonDeferredForeignKeyViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  return [
    for (final table in syncTables)
      if (tableDefinitionsByName[table.tableName] case final tableDefinition?)
        for (final fk in tableDefinition.foreignKeys)
          if (!_isCrdtScopeForeignKey(fk) &&
              !_isRepairableByProjection(fk, tableDefinition) &&
              fk.deferrable != DeferrableConstraint.initiallyDeferred)
            '${table.tableName}.${fk.columns.join(',')}',
  ];
}

bool _isRepairableByProjection(
  ForeignKeyDefinition fk,
  TableDefinition tableDefinition,
) {
  if (fk.columns.length != 1) return false;
  for (final column in tableDefinition.columns) {
    if (column.name == fk.columns.single) return column.isNullable;
  }
  return false;
}

List<String> _restrictForeignKeyViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  return [
    for (final table in syncTables)
      if (tableDefinitionsByName.containsKey(table.tableName))
        for (final fk in tableDefinitionsByName[table.tableName]!.foreignKeys)
          if (!_isCrdtScopeForeignKey(fk) && fk.onDelete == ForeignKeyAction.restrict)
            '${table.tableName}.${fk.columns.join(',')}',
  ];
}
