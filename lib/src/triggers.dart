import 'package:drift/drift.dart';

import '/src/migrator.dart';

/// The name of the HLC function used in the database.
const nextHlcFunction = 'next_hlc_timestamp';

/// The operation that was performed on a row.
// ignore: public_member_api_docs
enum Operation { insert, update, delete }

// TODO: The [OfflineSyncTriggers] class should be reworked since the SQL statements
// now are no longer universal as the one developed originally.

/// Provides the CRDT control trigger statements for the database.
abstract class OfflineSyncTriggers {
  /// Creates a new instance of [OfflineSyncTriggers] with the provided [migrator].
  const OfflineSyncTriggers(this.migrator);

  /// The migrator instance to apply the CRDT schema to.
  final OfflineSyncMigrator migrator;

  /// Prefix for all CRDT-related entities.
  String get _prefix => '__crdt';

  /// Name of the column that stores the information about whether the row is deleted.
  String get isDeletedColumnName => '${_prefix}_is_deleted';

  /// Name of the CRDT data table.
  String get _crdtDataTableName => migrator.crdtDb.crdtDataTable.actualTableName;

  /// The list of columns in the CRDT data table.
  Iterable<String> get _crdtDataAllColumns =>
      migrator.crdtDb.crdtDataTable.$columns.quotedNames;

  /// Wraps the provided SQL statement as a CREATE TRIGGER statement.
  ///
  /// The received [innerSql] will be expected to go inside a BEGIN...END block.
  String wrapAsCreateTriggerStatement({
    required Operation operation,
    required String tableName,
    required String triggerName,
    required String innerSql,
  });

  /// Gets the name of the trigger for a specific operation on a table.
  String _getTriggerName(TableInfo<Table, Object?> table, Operation operation) =>
      '${_prefix}__${table.actualTableName}__${operation.name}';

  /// Returns the SQL statement to insert a new row into the CRDT data table.
  ///
  /// This statement is compatible with all major SQL dialects like SQLite,
  /// Postgres, MySQL, SQL Server, etc. So the dialect-specific subclass only
  /// needs to wrap it in the appropriate CREATE TRIGGER statement.
  ///
  /// For some dialects, it will only be needed to enable support for quoted
  /// identifiers that are used in the statement for maximum compatibility. On
  /// MySQL this is done by setting the `SQL_MODE` to `ANSI_QUOTES` and on SQL
  /// Server this is done by setting the `QUOTED_IDENTIFIER` option to `ON`.
  String _getInsertStatement({
    required TableInfo<Table, Object?> table,
    required Operation operation,
  }) {
    final tableName = table.actualTableName;

    final uniqueRowId =
        table.getUniqueRowId(tableAlias: operation == Operation.insert ? 'NEW' : 'OLD');

    final columnNamesWithoutPrimaryKey = operation == Operation.delete
        ? [isDeletedColumnName]
        : table.$columns
            .map((c) => c.$name)
            // MAYBE: If we remove the primary key columns from the list, some tables
            // might be completely ignored (like many-to-many relationship tables).
            // Do we really need them? Probably yes if we want to avoid deserializing
            // the split rowId into the original primary key columns, which can have
            // different types.
            // .where((c) => !table.$primaryKey.map((p) => p.$name).contains(c))
            .toList();

    final columnInserts = columnNamesWithoutPrimaryKey.map((c) {
      final rawValue = c == isDeletedColumnName ? 'TRUE' : 'NEW."$c"';
      final valueChanged =
          operation != Operation.update ? 'TRUE' : 'NEW."$c" IS NOT OLD."$c"';

      return '''
    SELECT
      '$c' AS "column_name",
      $rawValue AS "raw_value",
      $valueChanged AS "value_changed"''';
    });

    final whereClause =
        operation == Operation.update ? '\n  WHERE (value_changed = TRUE)' : '';

    return '''
  INSERT OR REPLACE INTO $_crdtDataTableName (
    ${_crdtDataAllColumns.join(', ')}
  )
  SELECT
    '$tableName' AS "table_name",
    column_name,
    $uniqueRowId AS "row_id",
    "hlc_timestamp",
    raw_value,
    value_changed
  FROM (
    SELECT $nextHlcFunction('${migrator.nodeId}') AS "hlc_timestamp"
  ), (
${columnInserts.join('\n    UNION ALL\n')}
  )$whereClause;''';
  }

  /// Returns the SQL statements to create the triggers for the changelog table.
  List<String> generateCreateTriggerStatements(TableInfo<Table, Object?> table) {
    return [
      for (final op in Operation.values)
        wrapAsCreateTriggerStatement(
          operation: op,
          tableName: table.actualTableName,
          triggerName: _getTriggerName(table, op),
          innerSql: _getInsertStatement(
            table: table,
            operation: op,
          ),
        ),
    ];
  }
}

/// Provides the CRDT control trigger statements for the SQLite3 database.
class Sqlite3OfflineSyncTriggers extends OfflineSyncTriggers {
  /// Creates a new instance of [Sqlite3OfflineSyncTriggers].
  Sqlite3OfflineSyncTriggers(super.migrator);

  @override
  String wrapAsCreateTriggerStatement({
    required Operation operation,
    required String tableName,
    required String triggerName,
    required String innerSql,
  }) =>
      '''
CREATE TRIGGER IF NOT EXISTS $triggerName
AFTER ${operation.name.toUpperCase()} ON "$tableName"
BEGIN
$innerSql
END;''';
}

extension on TableInfo {
  /// Returns an expression that uniquely identifies a row in the table.
  ///
  /// If the table has a single primary key column, the expression will be the
  /// column value. If it has multiple primary key columns, the values for all
  /// will be concatenated using the `_||_` operator.
  String getUniqueRowId({required String tableAlias}) {
    if ($primaryKey.isEmpty) {
      throw StateError('Table $actualTableName has no primary key and is therefore '
          'not supported to track changes to it.');
    }
    if ($primaryKey.length == 1) {
      return '$tableAlias."${$primaryKey.first.$name}"';
    }
    final columnNames = $primaryKey.map((c) => '$tableAlias."${c.$name}"').join(', ');
    return "CONCAT_WS('_||_', $columnNames)";
  }
}

extension on Iterable<GeneratedColumn> {
  /// Returns the column names with quotes for safer SQL queries.
  Iterable<String> get quotedNames => map((c) => '"${c.$name}"');
}

/// Extension methods for the [GeneratedDatabase] class to get the CRDT trigger names.
extension GetDatabaseCrdtTriggers on GeneratedDatabase {
  /// Returns the names of the CRDT triggers in the database.
  Future<List<String>> getCrdtTriggers() async {
    final result = await customSelect(
      '''\
SELECT type, name, sql
FROM sqlite_master
WHERE (type = "trigger")
  AND (name LIKE "%%__crdt__%%");''',
    ).get();

    return result.map((row) => row.read<String>('name')).toList();
  }
}
