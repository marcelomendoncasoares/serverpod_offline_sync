import 'package:drift/drift.dart';

import 'schema.dart';

// Required for the generated code to export schema tables.
export 'schema.dart';

/// CRDT data table.
///
/// This table stores the actual data encoded as JSON strings and all CRDT required
/// metadata to perform conflict resolution and synchronization. Schema is designed
/// to be generic enough to support various data types and structures. Stores the
/// data for all tables that are registered for CRDT synchronization, simplifying
/// the process of conflict resolution and data merging.
///
/// This same schema will be used on a client and server, with the difference that
/// the client will have the `user_id` column with a single value, while the server
/// will have all users' data in the same table. To avoid performance issues, on a
/// Postgres server, the `user_id` and `table_id` columns are partition keys.
///
/// The schema has been normalized to reduce storage footprint:
/// - Table and column names are stored as integer IDs referencing schema tables
/// - HLC is split into three integer columns (datetime, counter, node_id)
/// - Node IDs are stored as integer IDs referencing the nodes table
@TableIndex(
  name: 'idx_crdt_data_table_column_row',
  columns: {#userId, #tableId, #columnId, #rowId},
  unique: true,
)
@TableIndex(
  name: 'idx_crdt_data_hlc',
  columns: {#userId, #hlcDatetime, #hlcCounter, #hlcNodeId},
)
@DataClassName('CrdtDataEntry')
class CrdtDataTable extends Table {
  @override
  String get tableName => '__crdt_data';

  @override
  bool get isStrict => true;

  /// Identifier for the user or client that owns the data.
  late final userId = text()();

  /// Reference to the table this data belongs to (normalized).
  late final tableId = integer().named('table_id').references(
        CrdtSchemaTablesTable,
        #id,
      )();

  /// Reference to the column this data belongs to (normalized).
  late final columnId = integer().named('column_id').references(
        CrdtSchemaColumnsTable,
        #id,
      )();

  /// Unique identifier for the row in the table.
  late final rowId = text()();

  /// HLC datetime component as Unix timestamp in microseconds.
  late final hlcDatetime = integer().named('hlc_datetime')();

  /// HLC counter component.
  late final hlcCounter = integer().named('hlc_counter')();

  /// HLC node ID reference (normalized).
  late final hlcNodeId = integer().named('hlc_node_id').references(
        CrdtNodesTable,
        #id,
      )();

  /// Raw value of the data.
  late final rawValue = sqliteAny().nullable()();

  @override
  Set<Column> get primaryKey => {userId, tableId, columnId, rowId};

  /// Query to get the last HLC timestamp for each user and node.
  ///
  /// Declared here to ensure the query is synchronized with the table.
  /// Returns the maximum HLC for each user-node combination, reconstructing
  /// the HLC from the normalized components.
  static String getLastHlcTimestampQuery() {
    return '''
    SELECT d.user_id,
           d.hlc_datetime,
           d.hlc_counter,
           n.node_id
    FROM __crdt_data d
    INNER JOIN __crdt_nodes n ON d.hlc_node_id = n.id
    WHERE (d.user_id, d.hlc_datetime, d.hlc_counter) IN (
      SELECT user_id,
             MAX(hlc_datetime) as hlc_datetime,
             MAX(hlc_counter) as hlc_counter
      FROM __crdt_data
      GROUP BY user_id, hlc_node_id
    )
  ''';
  }
}
