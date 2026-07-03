import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

@internal
bool isCrdtAllowedForeignKeyOnlyUniqueIndex(
  TableDefinition tableDefinition,
  IndexDefinition index,
  Set<String> syncTableNames,
) {
  final indexColumns = <String>[];
  for (final element in index.elements) {
    if (element.type != IndexElementDefinitionType.column) return false;
    indexColumns.add(element.definition);
  }
  if (indexColumns.isEmpty || indexColumns.length != indexColumns.toSet().length) {
    return false;
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

  return indexColumns.every(coveredForeignKeyColumns.contains);
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

@internal
CrdtUniqueConflictReleaseKind? crdtUniqueConflictReleaseKindForColumn(
  TableDefinition table,
  ColumnDefinition column,
) {
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
