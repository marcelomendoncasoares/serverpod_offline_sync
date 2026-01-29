import 'package:drift/drift.dart';

import '../migrator.dart';
import '../utils/sql_builder.dart';

/// The name of the HLC function used in the database.
const nextHlcFunction = 'next_hlc_timestamp';

/// The operation that was performed on a row.
// ignore: public_member_api_docs
enum Operation { insert, update, delete }

// TODO: The [OfflineSyncTriggers] class should be reworked since the SQL statements
// now are no longer universal as the one developed originally.

/// Provides the CRDT control trigger statements for the database.
abstract class OfflineSyncTriggers extends CrdtDataSqlBuilder {
  /// Creates a new instance of [OfflineSyncTriggers].
  OfflineSyncTriggers(
    super.crdtDb, [
    this.conflictingBias = ConflictingBias.deleteWins,
  ]);

  /// The bias to use when conflicting operations are detected.
  final ConflictingBias conflictingBias;

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
      '${prefix}__${table.actualTableName}__${operation.name}';

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
  ///
  /// Now uses normalized schema with integer IDs for reduced storage footprint.
  Future<String> _getInsertStatement({
    required TableInfo<Table, Object?> table,
    required Operation operation,
  }) async {
    final tableName = table.actualTableName;

    // Get normalized IDs from cache
    final tableId = await crdtDb.getTableId(tableName);
    final currentNodeId = await crdtDb.getCurrentNodeId();

    final uniqueRowId = getUniqueRowId(
      table,
      tableAlias: operation == Operation.insert ? 'NEW' : 'OLD',
    );

    final columnNames = [
      if (operation != Operation.delete) ...table.nonGenerated,
      if (operation != Operation.update ||
          conflictingBias == ConflictingBias.updateWins)
        isDeletedColumnName,
    ];

    // Build column inserts with normalized column IDs
    final columnInserts = <String>[];
    for (final c in columnNames) {
      final columnId = await crdtDb.getColumnId(tableId, c);
      final columnValue = c == isDeletedColumnName
          ? operation == Operation.delete
                ? 'TRUE'
                : 'FALSE'
          : 'NEW."$c"';

      columnInserts.add('    SELECT\n${[
        '      $columnId AS "column_id"',
        '      $columnValue AS "raw_value"',
        if (operation == Operation.update) '      NEW."$c" IS NOT OLD."$c" AS "value_changed"',
      ].join(',\n')}');
    }

    final whereClause = operation == Operation.update
        ? '("value_changed" = TRUE)'
        : 'TRUE';

    // The next_hlc_timestamp function now returns "datetime|counter" as a delimited string
    // We call it once and parse the result to avoid multiple increments
    return '''
  INSERT INTO "$crdtDataTableName" (
    ${crdtDataAllColumns.join(', ')}
  )
  SELECT
    '${crdtDb.userId}' AS "user_id",
    $tableId AS "table_id",
    "column_id",
    $uniqueRowId AS "row_id",
    "hlc_datetime",
    "hlc_counter",
    $currentNodeId AS "hlc_node_id",
    raw_value
  FROM (
    SELECT 
      CAST(SUBSTR(hlc_result, 1, INSTR(hlc_result, '|') - 1) AS INTEGER) AS "hlc_datetime",
      CAST(SUBSTR(hlc_result, INSTR(hlc_result, '|') + 1) AS INTEGER) AS "hlc_counter"
    FROM (
      SELECT $nextHlcFunction('${crdtDb.userId}') AS hlc_result
    )
  ), (
${columnInserts.join('\n    UNION ALL\n')}
  )
  WHERE $whereClause
  ON CONFLICT (${crdtDataPrimaryKeyColumns.join(', ')})
  DO UPDATE SET
    "hlc_datetime" = EXCLUDED."hlc_datetime",
    "hlc_counter" = EXCLUDED."hlc_counter",
    "hlc_node_id" = EXCLUDED."hlc_node_id",
    "raw_value" = EXCLUDED."raw_value";''';
  }

  /// Returns the SQL statements to create the triggers for the changelog table.
  Future<List<String>> generateCreateTriggerStatements(TableInfo<Table, Object?> table) async {
    return [
      for (final op in Operation.values)
        wrapAsCreateTriggerStatement(
          operation: op,
          tableName: table.actualTableName,
          triggerName: _getTriggerName(table, op),
          innerSql: await _getInsertStatement(
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
  Sqlite3OfflineSyncTriggers(super.crdtDb, [super.conflictingBias]);

  @override
  String wrapAsCreateTriggerStatement({
    required Operation operation,
    required String tableName,
    required String triggerName,
    required String innerSql,
  }) =>
      '''
CREATE TRIGGER IF NOT EXISTS "$triggerName"
AFTER ${operation.name.toUpperCase()} ON "$tableName"
BEGIN
$innerSql
END;''';
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

extension on TableInfo {
  Iterable<String> get nonGenerated =>
      $columns.where((c) => c.generatedAs == null).map((c) => c.$name);
}
