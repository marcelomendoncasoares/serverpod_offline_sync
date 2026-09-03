import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

@internal
typedef UniqueIndexConflictRelease = ({
  List<String> indexedColumns,
  List<UniqueColumnConflictRelease> releaseColumns,
  bool scoped,
});

@internal
typedef UniqueColumnConflictRelease = ({
  String columnName,
  CrdtUniqueConflictReleaseKind kind,
});

@internal
List<UniqueIndexConflictRelease> syncableUniqueIndexesForTable(
  TableDefinition table,
  Set<String> syncTableNames,
) {
  final columnsByName = {for (final column in table.columns) column.name: column};
  return [
    for (final index in crdtSyncableUniqueIndexesForTable(table, syncTableNames))
      uniqueIndexConflictReleaseForIndex(table, columnsByName, index),
  ];
}

@internal
UniqueIndexConflictRelease uniqueIndexConflictReleaseForIndex(
  TableDefinition table,
  Map<String, ColumnDefinition> columnsByName,
  IndexDefinition index,
) {
  final columnNames = index.elements.map((element) => element.definition).toList();
  final indexedColumns = [
    for (final columnName in columnNames)
      if (columnName != 'scopeId') columnName,
  ];
  final releaseColumns = <UniqueColumnConflictRelease>[];
  for (final columnName in indexedColumns) {
    final column = columnsByName[columnName];
    if (column == null) {
      throw StateError('No column definition found for ${table.name}.$columnName.');
    }
    final kind = crdtUniqueConflictReleaseKindForColumn(table, column);
    if (kind != null) {
      releaseColumns.add((columnName: columnName, kind: kind));
    }
  }

  return (
    scoped: columnNames.contains('scopeId'),
    indexedColumns: indexedColumns,
    releaseColumns: releaseColumns,
  );
}

@internal
bool isCrdtAllowedForeignKeyOnlyUniqueIndex(
  TableDefinition tableDefinition,
  IndexDefinition index,
  Set<String> syncTableNames,
) {
  return _foreignKeyOnlyUniqueIndexColumns(
        tableDefinition,
        index,
        syncTableNames,
      ) !=
      null;
}

List<String>? _foreignKeyOnlyUniqueIndexColumns(
  TableDefinition tableDefinition,
  IndexDefinition index,
  Set<String> syncTableNames,
) {
  final indexColumns = <String>[];
  for (final element in index.elements) {
    if (element.type != IndexElementDefinitionType.column) return null;
    indexColumns.add(element.definition);
  }
  if (indexColumns.isEmpty || indexColumns.length != indexColumns.toSet().length) {
    return null;
  }

  final indexColumnSet = indexColumns.toSet();
  final coveredForeignKeyColumns = <String>{};
  for (final foreignKey in tableDefinition.foreignKeys) {
    if (!syncTableNames.contains(foreignKey.referenceTable)) continue;
    final foreignKeyColumns = foreignKey.columns.toSet();
    if (foreignKeyColumns.isEmpty) continue;
    if (indexColumnSet.containsAll(foreignKeyColumns)) {
      coveredForeignKeyColumns.addAll(foreignKeyColumns);
    }
  }

  return indexColumns.every(coveredForeignKeyColumns.contains) ? indexColumns : null;
}

@internal
List<String> crdtRequiredForeignKeyOnlyUniqueColumnViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  final syncTableNames = {for (final table in syncTables) table.tableName};
  final violations = <String>{};

  for (final tableName in syncTableNames) {
    final table = tableDefinitionsByName[tableName];
    if (table == null) continue;

    final columnsByName = {for (final column in table.columns) column.name: column};
    for (final index in table.indexes) {
      if (!index.isUnique || index.isPrimary || isCrdtScopedUniqueIndex(index)) {
        continue;
      }

      final foreignKeyOnlyColumns = _foreignKeyOnlyUniqueIndexColumns(
        table,
        index,
        syncTableNames,
      );
      if (foreignKeyOnlyColumns == null) continue;

      for (final columnName in foreignKeyOnlyColumns) {
        final column = columnsByName[columnName];
        if (column == null) {
          throw StateError(
            'No column definition found for ${table.name}.$columnName.',
          );
        }
        if (!column.isNullable) violations.add('${table.name}.$columnName');
      }
    }
  }

  return violations.toList();
}

@internal
bool isCrdtScopedUniqueIndex(IndexDefinition index) {
  return index.elements.any(
    (element) =>
        element.type == IndexElementDefinitionType.column &&
        element.definition == 'scopeId',
  );
}

@internal
Iterable<IndexDefinition> crdtSyncableUniqueIndexesForTable(
  TableDefinition table,
  Set<String> syncTableNames,
) {
  return table.indexes.where(
    (index) =>
        index.isUnique &&
        !index.isPrimary &&
        index.elements.every(
          (element) => element.type == IndexElementDefinitionType.column,
        ) &&
        (isCrdtScopedUniqueIndex(index) ||
            isCrdtAllowedForeignKeyOnlyUniqueIndex(
              table,
              index,
              syncTableNames,
            )),
  );
}

@internal
bool isCrdtForeignKeyColumn(TableDefinition table, String columnName) {
  return table.foreignKeys.any(
    (fk) => fk.columns.length == 1 && fk.columns.single == columnName,
  );
}

/// How a unique-indexed column can be released to a conflict-free value, or
/// null when the column cannot be released deterministically.
@internal
enum CrdtUniqueConflictReleaseKind {
  setNull,
  textSuffix,
  syntheticUuid,
}

/// Whether [column] is a JSON-backed domain column that cannot participate in
/// a synchronized unique claim.
@internal
bool isCrdtUnsupportedJsonUniqueColumn(ColumnDefinition column) {
  return column.columnType == ColumnType.json ||
      column.columnType == ColumnType.jsonb;
}

@internal
CrdtUniqueConflictReleaseKind? crdtUniqueConflictReleaseKindForColumn(
  TableDefinition table,
  ColumnDefinition column,
) {
  if (isCrdtUnsupportedJsonUniqueColumn(column)) return null;
  if (column.isNullable) return CrdtUniqueConflictReleaseKind.setNull;
  if (column.columnType == ColumnType.text) {
    return CrdtUniqueConflictReleaseKind.textSuffix;
  }
  if (column.columnType == ColumnType.uuid &&
      !isCrdtForeignKeyColumn(table, column.name)) {
    return CrdtUniqueConflictReleaseKind.syntheticUuid;
  }
  return null;
}

/// Unique indexes that include a json or jsonb domain column.
///
/// Sync has no canonical cross-dialect JSON equality, so neither a nullable
/// JSON releasable candidate nor a non-nullable JSON fixed component is
/// supported.
@internal
List<String> crdtJsonUniqueIndexViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  final syncTableNames = {for (final table in syncTables) table.tableName};
  return [
    for (final tableName in syncTableNames)
      if (tableDefinitionsByName[tableName] case final table?)
        for (final index in crdtSyncableUniqueIndexesForTable(
          table,
          syncTableNames,
        ))
          if (_hasJsonUniqueColumn(table, index)) '$tableName.${index.indexName}',
  ];
}

bool _hasJsonUniqueColumn(TableDefinition table, IndexDefinition index) {
  final columnsByName = {
    for (final column in table.columns) column.name: column,
  };
  return index.elements.any(
    (element) =>
        element.type == IndexElementDefinitionType.column &&
        element.definition != 'scopeId' &&
        switch (columnsByName[element.definition]) {
          final column? => isCrdtUnsupportedJsonUniqueColumn(column),
          null => false,
        },
  );
}

@internal
List<String> crdtNonReleasableUniqueIndexViolations(
  List<Table> syncTables,
  Map<String, TableDefinition> tableDefinitionsByName,
) {
  final syncTableNames = {for (final table in syncTables) table.tableName};
  return [
    for (final tableName in syncTableNames)
      if (tableDefinitionsByName.containsKey(tableName))
        for (final index in crdtSyncableUniqueIndexesForTable(
          tableDefinitionsByName[tableName]!,
          syncTableNames,
        ))
          if (!_hasReleasableNonScopeUniqueColumn(
            tableDefinitionsByName[tableName]!,
            index,
          ))
            '$tableName.${index.indexName}',
  ];
}

bool _hasReleasableNonScopeUniqueColumn(
  TableDefinition table,
  IndexDefinition index,
) {
  final columnsByName = {
    for (final column in table.columns) column.name: column,
  };
  for (final element in index.elements) {
    if (element.type != IndexElementDefinitionType.column) continue;
    if (element.definition == 'scopeId') continue;
    final column = columnsByName[element.definition];
    if (column == null) {
      throw StateError(
        'No column definition found for ${table.name}.${element.definition}.',
      );
    }
    if (crdtUniqueConflictReleaseKindForColumn(table, column) != null) {
      return true;
    }
  }
  return false;
}
