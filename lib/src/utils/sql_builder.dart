import 'package:drift/drift.dart';

import '/src/database.dart';

/// Provides the base building blocks for SQL statements to interact with the
/// CRDT data table.
class CrdtDataSqlBuilder {
  /// Creates a new instance of [CrdtDataSqlBuilder].
  const CrdtDataSqlBuilder(this.crdtDb);

  /// The migrator instance to apply the CRDT schema to.
  final CrdtDatabase crdtDb;

  /// Prefix for all CRDT-related entities.
  String get prefix => '__crdt';

  /// Separator for joining primary key columns in the row ID.
  String get rowIdSeparator => '||';

  /// Name of the column that stores the information about whether the row is deleted.
  String get isDeletedColumnName => '${prefix}_is_deleted';

  /// Name of the CRDT data table.
  String get crdtDataTableName => crdtDb.crdtDataTable.actualTableName;

  /// The list of quoted column names in the CRDT data table.
  Iterable<String> get crdtDataAllColumns => crdtDb.crdtDataTable.$columns.quotedNames;

  /// The list of quoted primary key column names in the CRDT data table.
  Iterable<String> get crdtDataPrimaryKeyColumns =>
      crdtDb.crdtDataTable.$primaryKey.quotedNames;

  /// Returns an expression that uniquely identifies a row in the table.
  ///
  /// If the table has a single primary key column, the expression will be the
  /// column value. If it has multiple primary key columns, the values for all
  /// will be concatenated using the separator.
  String getUniqueRowId(TableInfo table, {required String tableAlias}) {
    if (table.$primaryKey.isEmpty) {
      throw StateError(
        'Table ${table.actualTableName} has no primary key and is therefore '
        'not supported to track changes to it.',
      );
    }
    if (table.$primaryKey.length == 1) {
      return '$tableAlias."${table.$primaryKey.first.$name}"';
    }
    final columnNames = table.$primaryKey
        .map((c) => '$tableAlias."${c.$name}"')
        .join(', ');
    return "CONCAT_WS('$rowIdSeparator', $columnNames)";
  }
}

/// Extension methods for the [Iterable<GeneratedColumn>] class to get the column names with quotes.
extension GetColumnNamesWithQuotes on Iterable<GeneratedColumn> {
  /// Returns the column names with quotes for safer SQL queries.
  Iterable<String> get quotedNames => map((c) => '"${c.$name}"');
}
