import 'package:drift/drift.dart';

import '../../hlc/converter.dart';

// Required for the generated code to know the HLC and converters.
export '../../hlc/converter.dart';

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
/// Postgres server, the `user_id` and `table_name` columns are partition keys.
@TableIndex(
  name: 'idx_crdt_data_tbl_name_column_name_row_id',
  columns: {#userId, #tblName, #columnName, #rowId},
  unique: true,
)
@TableIndex(
  name: 'idx_crdt_data_hlc_timestamp',
  columns: {#userId, #hlcTimestamp},
)
@DataClassName('CrdtDataEntry')
class CrdtDataTable extends Table {
  @override
  String get tableName => '__crdt_data';

  @override
  bool get isStrict => true;

  /// Identifier for the user or client that owns the data.
  late final userId = text()();

  /// Name of the table that data belongs to.
  late final tblName = text().named('table_name')();

  /// Name of the column this data belongs to.
  late final columnName = text()();

  /// Unique identifier for the row in the table.
  late final rowId = text()();

  /// Hybrid Logical Clock timestamp of the data update.
  late final hlcTimestamp = text().map(hlcConverter)();

  /// Raw value of the data.
  late final rawValue = sqliteAny().nullable()();

  @override
  Set<Column> get primaryKey => {userId, tblName, columnName, rowId};

  /// Query to get the last HLC timestamp for each user.
  ///
  /// Declared here to ensure the query is synchronized with the table.
  static String getLastHlcTimestampQuery() {
    return '''
    SELECT user_id,
           max(hlc_timestamp) as last_hlc_timestamp
    FROM __crdt_data
    GROUP BY 1
  ''';
  }
}
