import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../recorder.dart';

/// A foreign key pointing at a parent table, seen from the parent side.
@internal
typedef ReferencingForeignKey = ({
  String childTableName,
  String childColumn,
  String parentColumn,
  ForeignKeyAction action,
});

/// A foreign key between two CRDT-tracked tables, with repair metadata.
@internal
typedef ForeignKeyEdge = ({
  String childTableName,
  String childColumn,
  String parentTableName,
  String parentColumn,
  ForeignKeyAction action,
  bool childNullable,
  Object? defaultValue,
});

/// Identifies a foreign key value: `(tableName, columnName, value)`.
@internal
typedef ForeignKeyValueKey = (String tableName, String columnName, String value);

/// Foreign key relationships derived from the schema, indexed for lookups.
@internal
class CrdtForeignKeyGraph {
  /// Creates a [CrdtForeignKeyGraph] over the tables known to the context.
  CrdtForeignKeyGraph(this._context);

  final CrdtDatabaseContext _context;

  /// Foreign keys grouped by the table they reference.
  ///
  /// Covers all known tables, not only CRDT-tracked ones, and rejects
  /// composite foreign keys which soft deletes cannot handle.
  late final Map<String, List<ReferencingForeignKey>> referencingKeysByParentTable =
      () {
        final result = <String, List<ReferencingForeignKey>>{};
        for (final table in _context.tableDefinitionsByName.values) {
          final childTableName = table.name;
          // Untracked children have no CRDT schema rows and cannot be
          // soft-deleted; their physical rows keep referencing the (physically
          // preserved) soft-deleted parent, so no delete action applies.
          // Interim behavior: docs/sync-non-sync-relations.md forbids
          // non-synced -> synced relations outright, but its initialize()
          // validation is not implemented yet.
          if (!_context.isCrdtTrackedTableName(childTableName)) continue;
          for (final foreignKey in table.foreignKeys) {
            if (foreignKey.columns.length != 1 ||
                foreignKey.referenceColumns.length != 1) {
              throw StateError(
                'Composite foreign keys are not supported for CRDT soft deletes.',
              );
            }

            result.putIfAbsent(foreignKey.referenceTable, () => []).add((
              childTableName: childTableName,
              childColumn: foreignKey.columns.single,
              parentColumn: foreignKey.referenceColumns.single,
              action: foreignKey.onDelete ?? ForeignKeyAction.noAction,
            ));
          }
        }
        return result;
      }();

  /// Foreign key edges between CRDT-tracked tables.
  late final List<ForeignKeyEdge> edges = [
    for (final table in _context.tableDefinitionsByName.values)
      if (_context.isCrdtTrackedTableName(table.name))
        for (final foreignKey in table.foreignKeys)
          if (foreignKey.columns.length == 1 &&
              foreignKey.referenceColumns.length == 1 &&
              _context.isCrdtTrackedTableName(foreignKey.referenceTable))
            (
              childTableName: table.name,
              childColumn: foreignKey.columns.single,
              parentTableName: foreignKey.referenceTable,
              parentColumn: foreignKey.referenceColumns.single,
              action: foreignKey.onDelete ?? ForeignKeyAction.noAction,
              childNullable: _context
                  .columnsByTableAndName[table.name]![foreignKey.columns.single]!
                  .isNullable,
              defaultValue: _context.defaultValueForColumn(
                table.name,
                foreignKey.columns.single,
              ),
            ),
  ];

  /// [edges] grouped by their parent table name.
  late final Map<String, List<ForeignKeyEdge>> edgesByParentTable = {
    for (final tableName in _context.tableDefinitionsByName.keys)
      tableName: [
        for (final edge in edges)
          if (edge.parentTableName == tableName) edge,
      ],
  };

  /// [edges] grouped by their child table name.
  late final Map<String, List<ForeignKeyEdge>> edgesByChildTable = {
    for (final tableName in _context.tableDefinitionsByName.keys)
      tableName: [
        for (final edge in edges)
          if (edge.childTableName == tableName) edge,
      ],
  };

  /// Whether changing the given columns may affect foreign key projection.
  ///
  /// Pass null [columnNames] when all columns may change (inserts/deletes).
  bool columnsMayAffectForeignKeys(
    String tableName,
    Set<String>? columnNames,
  ) {
    final childEdges = edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[];
    final parentEdges = edgesByParentTable[tableName] ?? const <ForeignKeyEdge>[];
    if (childEdges.isEmpty && parentEdges.isEmpty) return false;
    if (columnNames == null) return true;

    return childEdges.any((edge) => columnNames.contains(edge.childColumn)) ||
        parentEdges.any(
          (edge) =>
              edge.parentColumn != 'id' && columnNames.contains(edge.parentColumn),
        );
  }

  /// Tables joined to [seedTables] by any chain of foreign keys.
  ///
  /// Projection resolves cascade and repair to a fixed point over the foreign
  /// key graph, so a row can only be affected by a change in a table its own
  /// table can reach. Unique conflicts are resolved within one table and never
  /// cross this boundary, so loading the seeds' connected components is enough
  /// to reproduce a full-graph pass.
  Set<String> connectedTables(Iterable<String> seedTables) {
    final reached = <String>{};
    final queue = [...seedTables];
    while (queue.isNotEmpty) {
      final tableName = queue.removeLast();
      if (!reached.add(tableName)) continue;
      for (final edge in edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[]) {
        queue.add(edge.parentTableName);
      }
      for (final edge in edgesByParentTable[tableName] ?? const <ForeignKeyEdge>[]) {
        queue.add(edge.childTableName);
      }
    }
    return reached;
  }

  /// The child column names of foreign keys outgoing from [tableName].
  ///
  /// When [columnNames] is provided, only edges whose child column is in the set
  /// are included; otherwise all outgoing FK columns are returned.
  Set<String> foreignKeyColumnsFor(
    String tableName, {
    Set<String>? columnNames,
  }) => {
    for (final edge in edgesByChildTable[tableName] ?? const <ForeignKeyEdge>[])
      if (columnNames == null || columnNames.contains(edge.childColumn))
        edge.childColumn,
  };
}
