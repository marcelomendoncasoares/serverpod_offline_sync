import 'package:drift/drift.dart';

import '../utils/sql_builder.dart';
import 'tables/control.dart';
import 'tables/data.dart';
import 'tables/merge.dart';

part 'database.g.dart';

/// The main database class for CRDT synchronization.
@DriftDatabase(
  tables: [
    CrdtDataTable,
    CrdtControlTable,
    CrdtMergeHlcTable,
    CrdtSchemaTablesTable,
    CrdtSchemaColumnsTable,
    CrdtNodesTable,
  ],
)
class CrdtDatabase extends _$CrdtDatabase {
  /// Creates a new instance of [CrdtDatabase] with the provided [executor].
  CrdtDatabase(
    super.e, {
    required this.userId,
    required this.nodeId,
    required this.synchronizedTables,
  });

  /// The user ID for the CRDT system.
  final String userId;

  /// The node ID for the CRDT system.
  final String nodeId;

  /// Tables to be synchronized with CRDT.
  final List<TableInfo> synchronizedTables;

  /// The SQL builder for the CRDT data table.
  late final sqlBuilder = CrdtDataSqlBuilder(this);

  /// Cache for table name to ID mapping.
  final Map<String, int> _tableNameToIdCache = {};

  /// Cache for column name to ID mapping per table.
  final Map<int, Map<String, int>> _columnNameToIdCache = {};

  /// Cache for node ID string to integer ID mapping.
  final Map<String, int> _nodeIdCache = {};

  /// The normalized ID for the current node (always 1).
  int? _currentNodeId;

  /// Gets the current node's normalized ID (cached).
  Future<int> getCurrentNodeId() async {
    if (_currentNodeId != null) return _currentNodeId!;

    final result = await (select(crdtNodesTable)
          ..where((t) => t.nodeId.equals(nodeId)))
        .getSingleOrNull();

    if (result == null) {
      throw StateError(
        'Current node ID "$nodeId" not found in __crdt_nodes table. '
        'Ensure the database has been properly initialized.',
      );
    }

    _currentNodeId = result.id;
    return _currentNodeId!;
  }

  /// Gets the table ID for a table name, using cache.
  Future<int> getTableId(String tableName) async {
    if (_tableNameToIdCache.containsKey(tableName)) {
      return _tableNameToIdCache[tableName]!;
    }

    final result = await (select(crdtSchemaTablesTable)
          ..where((t) => t.tableName.equals(tableName)))
        .getSingleOrNull();

    if (result == null) {
      throw ArgumentError(
        'Table "$tableName" not found in schema cache. '
        'Ensure the schema has been populated.',
      );
    }

    _tableNameToIdCache[tableName] = result.id;
    return result.id;
  }

  /// Gets the column ID for a column name in a specific table, using cache.
  Future<int> getColumnId(int tableId, String columnName) async {
    final tableCache = _columnNameToIdCache.putIfAbsent(tableId, () => {});

    if (tableCache.containsKey(columnName)) {
      return tableCache[columnName]!;
    }

    final result = await (select(crdtSchemaColumnsTable)
          ..where((t) => t.tableId.equals(tableId) & t.columnName.equals(columnName)))
        .getSingleOrNull();

    if (result == null) {
      throw ArgumentError(
        'Column "$columnName" for table ID $tableId not found in schema cache. '
        'Ensure the schema has been populated.',
      );
    }

    tableCache[columnName] = result.id;
    return result.id;
  }

  /// Gets the node ID for a node string, using cache.
  Future<int> getNodeId(String nodeIdStr) async {
    if (_nodeIdCache.containsKey(nodeIdStr)) {
      return _nodeIdCache[nodeIdStr]!;
    }

    final result = await (select(crdtNodesTable)
          ..where((t) => t.nodeId.equals(nodeIdStr)))
        .getSingleOrNull();

    if (result == null) {
      throw ArgumentError(
        'Node ID "$nodeIdStr" not found in __crdt_nodes table. '
        'Ensure the node has been registered.',
      );
    }

    _nodeIdCache[nodeIdStr] = result.id;
    return result.id;
  }

  /// Clears all caches. Call this after schema changes or migrations.
  void clearSchemaCache() {
    _tableNameToIdCache.clear();
    _columnNameToIdCache.clear();
    _nodeIdCache.clear();
    _currentNodeId = null;
  }

  /// Whether the database is using the SQLite or Postgres dialect.
  bool get isPostgres => executor.dialect == SqlDialect.postgres;

  /// Not actually used, but required by the generated code. Will be ignored because
  /// the [CrdtDatabase] always receives an already opened executor. No migrations
  /// should ever be run on this database to avoid messing with the user schema.
  @override
  int schemaVersion = 1;
}

/// Extension methods for the [List<TableInfo>] class to find a synchronized table.
extension FindSynchronizedTable on List<TableInfo> {
  /// Gets the table names of the synchronized tables.
  Iterable<String> get tableNames => map((t) => t.actualTableName);

  /// Gets the synchronized table information for the given table name.
  ///
  /// If the table is not found, an [ArgumentError] is thrown.
  TableInfo find<T extends Insertable>([String? tableName]) {
    if (tableName == null && T == dynamic) {
      throw ArgumentError('Table name is required when T is dynamic.');
    }
    return firstWhere(
      (t) =>
          (tableName == null && t is TableInfo<Table, T>) ||
          t.actualTableName == tableName,
      orElse: () => throw ArgumentError(
        'Table ${tableName != null ? '"$tableName"' : 'for type "$T"'} not '
        'found in synchronized tables.',
      ),
    );
  }
}
