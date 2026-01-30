import 'package:drift/drift.dart';

import 'database.dart';

/// Manages the schema cache for normalized CRDT data storage.
///
/// This class handles loading and caching of normalized schema information
/// (table names, column names, and node IDs) to avoid repeated database lookups.
/// All lookups are synchronous after initialization, improving performance in
/// trigger generation and data operations.
class CrdtSchemaCache {
  /// Creates a new schema cache for the given database.
  CrdtSchemaCache(this._db);

  final CrdtDatabase _db;

  /// Cache for table name to ID mapping.
  final Map<String, int> _tableNameToId = {};

  /// Cache for column name to ID mapping per table.
  final Map<int, Map<String, int>> _columnNameToId = {};

  /// Cache for node ID string to integer ID mapping.
  final Map<String, int> _nodeIdToInt = {};

  /// The normalized ID for the current node (always 1).
  int? _currentNodeId;

  /// Whether the schema cache has been initialized.
  bool _initialized = false;

  /// Initializes the schema cache by loading all schema information from the database.
  ///
  /// This method must be called after schema tables are populated but before
  /// any schema lookups are performed. It loads all tables, columns, and nodes
  /// into memory for fast synchronous access.
  Future<void> initialize() async {
    if (_initialized) return;

    // Load all tables
    final tables = await _db.select(_db.crdtSchemaTablesTable).get();
    for (final table in tables) {
      _tableNameToId[table.tblName] = table.id;
    }

    // Load all columns grouped by table
    final columns = await _db.select(_db.crdtSchemaColumnsTable).get();
    for (final column in columns) {
      final tableCache = _columnNameToId.putIfAbsent(column.tableId, () => {});
      tableCache[column.columnName] = column.id;
    }

    // Load all nodes
    final nodes = await _db.select(_db.crdtNodesTable).get();
    for (final node in nodes) {
      _nodeIdToInt[node.nodeId] = node.id;
      if (node.nodeId == _db.nodeId) {
        _currentNodeId = node.id;
      }
    }

    _initialized = true;
  }

  /// Gets the current node's normalized ID.
  ///
  /// Returns the integer ID for the current node, which should always be 1.
  /// Throws [StateError] if not initialized or node not found.
  int get currentNodeId {
    _ensureInitialized();
    if (_currentNodeId == null) {
      throw StateError(
        'Current node ID "${_db.nodeId}" not found in cache. '
        'Ensure the node has been registered in __crdt_nodes table.',
      );
    }
    return _currentNodeId!;
  }

  /// Gets the table ID for a table name.
  ///
  /// Returns the integer ID for the given table name.
  /// Throws [ArgumentError] if the table is not found in cache.
  int getTableId(String tableName) {
    _ensureInitialized();
    final id = _tableNameToId[tableName];
    if (id == null) {
      throw ArgumentError(
        'Table "$tableName" not found in schema cache. '
        'Available tables: ${_tableNameToId.keys.join(", ")}',
      );
    }
    return id;
  }

  /// Gets the column ID for a column name in a specific table.
  ///
  /// Returns the integer ID for the given column name within the specified table.
  /// Throws [ArgumentError] if the table or column is not found in cache.
  int getColumnId(int tableId, String columnName) {
    _ensureInitialized();
    final tableCache = _columnNameToId[tableId];
    if (tableCache == null) {
      throw ArgumentError(
        'Table ID $tableId not found in schema cache. '
        'Ensure the schema has been populated.',
      );
    }

    final columnId = tableCache[columnName];
    if (columnId == null) {
      throw ArgumentError(
        'Column "$columnName" for table ID $tableId not found in schema cache. '
        'Available columns: ${tableCache.keys.join(", ")}',
      );
    }
    return columnId;
  }

  /// Gets the node ID for a node string.
  ///
  /// Returns the integer ID for the given node ID string.
  /// Throws [ArgumentError] if the node is not found in cache.
  int getNodeId(String nodeIdStr) {
    _ensureInitialized();
    final id = _nodeIdToInt[nodeIdStr];
    if (id == null) {
      throw ArgumentError(
        'Node ID "$nodeIdStr" not found in cache. '
        'Ensure the node has been registered in __crdt_nodes table.',
      );
    }
    return id;
  }

  /// Clears all caches and marks as uninitialized.
  ///
  /// Call this after schema changes or migrations to force a reload on next access.
  void clear() {
    _tableNameToId.clear();
    _columnNameToId.clear();
    _nodeIdToInt.clear();
    _currentNodeId = null;
    _initialized = false;
  }

  /// Ensures the cache has been initialized before use.
  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'Schema cache has not been initialized. '
        'Call initialize() before accessing schema information.',
      );
    }
  }
}
