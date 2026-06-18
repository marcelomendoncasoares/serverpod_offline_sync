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
