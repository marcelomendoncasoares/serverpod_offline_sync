import 'package:drift/drift.dart';

import '../../hlc/converter.dart';

// Required for the generated code to know the HLC and converters.
export '../../hlc/converter.dart';

/// CRDT data table.
///
/// This table stores all CRDT required metadata to perform conflict resolution
/// and synchronization. The schema is designed to be generic enough to support
/// various data types and structures. It stores the data for all tables that are
/// registered for CRDT synchronization, simplifying the process of conflict
/// resolution and data merging.
///
/// This same schema will be used on a client and server, with the difference
/// that the client will have the `user_id` column with a single value, while
/// the server will have all users' data in the same table.
///
/// This table is used to interact with the CRDT data, but won't exist in the
/// database. On runtime, it will be replaced by a view with INSTEAD OF triggers
/// that will persist the data to the normalized data table.
@DataClassName('CrdtDataEntry')
class CrdtDataTable extends Table {
  @override
  String get tableName => '__crdt_data';

  @override
  bool get withoutRowId => true;

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
}

/// CRDT normalized data table.
///
/// This will be the actual table that will be used to store the data. See the
/// [CrdtDataTable] class to better understand the schema.
@DataClassName('CrdtNormalizedDataEntry')
class CrdtNormalizedDataTable extends Table {
  @override
  String get tableName => '__crdt_normalized_data';

  @override
  bool get withoutRowId => true;

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
}
