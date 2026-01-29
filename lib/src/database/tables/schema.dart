import 'package:drift/drift.dart';

/// CRDT schema tables table.
///
/// This table stores the normalized schema information for all synchronized
/// tables. Instead of storing table names as strings in every CRDT data row,
/// we store them once here and reference them by ID. This significantly
/// reduces storage overhead.
@DataClassName('CrdtSchemaTableEntry')
class CrdtSchemaTablesTable extends Table {
  @override
  String get tableName => '__crdt_schema_tables';

  @override
  bool get isStrict => true;

  /// Unique identifier for the table.
  late final id = integer().autoIncrement()();

  /// Name of the synchronized table.
  late final tblName = text().named('table_name').unique()();
}

/// CRDT schema columns table.
///
/// This table stores the normalized schema information for all columns in
/// synchronized tables. Instead of storing column names as strings in every
/// CRDT data row, we store them once here and reference them by ID. This
/// significantly reduces storage overhead.
@DataClassName('CrdtSchemaColumnEntry')
class CrdtSchemaColumnsTable extends Table {
  @override
  String get tableName => '__crdt_schema_columns';

  @override
  bool get isStrict => true;

  /// Unique identifier for the column.
  late final id = integer().autoIncrement()();

  /// Reference to the table this column belongs to.
  late final tableId = integer().named('table_id').references(
        CrdtSchemaTablesTable,
        #id,
      )();

  /// Name of the column.
  late final columnName = text().named('column_name')();

  @override
  List<Set<Column>> get uniqueKeys => [
        {tableId, columnName},
      ];
}

/// CRDT nodes table.
///
/// This table stores all node IDs that have been seen. The current node
/// is always stored with ID 1, which allows triggers to use a constant
/// value instead of passing the full node_id string. This significantly
/// reduces storage overhead as the node_id no longer needs to be repeated
/// in every CRDT data row.
@DataClassName('CrdtNodeEntry')
class CrdtNodesTable extends Table {
  @override
  String get tableName => '__crdt_nodes';

  @override
  bool get isStrict => true;

  /// Unique identifier for the node (current node always has ID 1).
  late final id = integer().autoIncrement()();

  /// Node identifier string.
  late final nodeId = text().named('node_id').unique()();
}
