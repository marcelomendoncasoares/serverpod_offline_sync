import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';
import 'unique_index_utils.dart';

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

    final tablesWithoutScopeId = syncTables.where((table) {
      final scopeColumn = _scopeIdColumn(table);
      return scopeColumn == null || scopeColumn is! Column<int>;
    }).toList();
    if (tablesWithoutScopeId.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize tables with a nullable int scopeId column, '
        'but ${tablesWithoutScopeId.length} table(s) are missing it or declare '
        'it with the wrong type: '
        '${tablesWithoutScopeId.map((t) => '"${t.tableName}"').join(', ')}'
        '$_scopeIdFieldHelp',
      );
    }

    final tableDefinitionsByName = {
      for (final tableDefinition
          in tableDefinitions ??
              _session.db.serializationManager.getTargetTableDefinitions())
        tableDefinition.name: tableDefinition,
    };
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
        'nullable, but ${requiredFKeyUniqueColumns.length} required foreign key '
        'column(s) are not nullable: "${requiredFKeyUniqueColumns.join("', '")}". '
        'Make the relation optional/nullable.',
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

  late final _columnsPerTableName = {
    for (final table in syncTables)
      table.tableName: [
        for (final column in table.columns)
          if (column.columnName != 'scopeId') column.columnName,
      ],
  };

  /// Ensures that the CRDT schema is created for the database.
  Future<(List<CrdtSchemaTable>, List<CrdtSchemaColumn>)> syncAndGetSchema() async {
    return _session.db.transaction((transaction) async {
      final tableRows = await _syncTableSchemas(transaction);
      final columnRows = await _syncColumnSchemas(tableRows, transaction);
      return (tableRows, columnRows);
    });
  }

  /// Syncs the table schemas to the database.
  ///
  /// New tables are inserted and no longer present tables are deleted. Table
  /// renames are not taken into account. The returned list contains the
  /// [CrdtSchemaTable]s with their IDs.
  Future<List<CrdtSchemaTable>> _syncTableSchemas(Transaction transaction) async {
    await CrdtSchemaTable.db.insert(
      _session,
      _columnsPerTableName.keys.map((name) => CrdtSchemaTable(name: name)).toList(),
      transaction: transaction,
      ignoreConflicts: true,
    );

    final foundTableRows = await CrdtSchemaTable.db.find(
      _session,
      transaction: transaction,
    );

    final deletedTableRows = [
      for (final (ix, table) in foundTableRows.indexed.toList().reversed)
        if (!_columnsPerTableName.containsKey(table.name)) foundTableRows.removeAt(ix),
    ];

    await CrdtSchemaTable.db.delete(
      _session,
      deletedTableRows,
      transaction: transaction,
    );

    return foundTableRows;
  }

  /// Syncs the column schemas to the database.
  ///
  /// New columns are inserted and no longer present columns are deleted. Column
  /// renames are not taken into account yet. The returned list contains the
  /// [CrdtSchemaColumn]s with their IDs.
  Future<List<CrdtSchemaColumn>> _syncColumnSchemas(
    List<CrdtSchemaTable> tableRows,
    Transaction transaction,
  ) async {
    await CrdtSchemaColumn.db.insert(
      _session,
      [
        for (final table in tableRows)
          for (final column in _columnsPerTableName[table.name]!)
            CrdtSchemaColumn(tblId: table.id!, name: column),
      ],
      transaction: transaction,
      ignoreConflicts: true,
    );

    final columnsPerTableId = {
      for (final tableRow in tableRows)
        tableRow.id!: _columnsPerTableName[tableRow.name]!,
    };

    final foundColumnRows = await CrdtSchemaColumn.db.find(
      _session,
      transaction: transaction,
    );

    final deletedColumnRows = [
      for (final (ix, column) in foundColumnRows.indexed.toList().reversed)
        if (!columnsPerTableId.containsKey(column.tblId) ||
            !columnsPerTableId[column.tblId]!.contains(column.name))
          foundColumnRows.removeAt(ix),
    ];

    await CrdtSchemaColumn.db.delete(
      _session,
      deletedColumnRows,
      transaction: transaction,
    );

    return foundColumnRows;
  }
}

Column? _scopeIdColumn(Table table) {
  for (final column in table.columns) {
    if (column.columnName == 'scopeId') return column;
  }
  return null;
}

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
    (fk) =>
        fk.columns.length == 1 &&
        fk.columns.single == 'scopeId' &&
        fk.referenceTable == 'crdt_scopes' &&
        fk.referenceColumns.length == 1 &&
        fk.referenceColumns.single == 'id' &&
        fk.onDelete == ForeignKeyAction.cascade,
  );
}
