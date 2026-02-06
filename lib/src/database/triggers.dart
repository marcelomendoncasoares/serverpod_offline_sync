import 'package:drift/drift.dart';

import '../migrator.dart';
import '../utils/sql_builder.dart';

/// The operation that was performed on a row.
// ignore: public_member_api_docs
enum Operation { insert, update, delete }

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
  String getInsertStatement({
    required TableInfo<Table, Object?> table,
    required Operation operation,
  });

  /// Returns the SQL statements to create the triggers for the changelog table.
  List<String> generateCreateTriggerStatements(TableInfo<Table, Object?> table) {
    return [
      for (final op in Operation.values)
        wrapAsCreateTriggerStatement(
          operation: op,
          tableName: table.actualTableName,
          triggerName: _getTriggerName(table, op),
          innerSql: getInsertStatement(
            table: table,
            operation: op,
          ),
        ),
    ];
  }

  /// Returns extra statements to execute once before the triggers are created.
  List<String> generateSetupStatements() => const [];
}

/// Provides the CRDT control trigger statements for the SQLite3 database.
class Sqlite3OfflineSyncTriggers extends OfflineSyncTriggers {
  /// Creates a new instance of [Sqlite3OfflineSyncTriggers].
  Sqlite3OfflineSyncTriggers(super.crdtDb, [super.conflictingBias]);

  /// Name of the view used to advance HLC via INSERT (INSTEAD OF trigger).
  static const hlcCanonicalViewName = '__hlc_canonical_view';

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
WHEN (
  SELECT MAX("crdt_triggers_on")
  FROM "__crdt_control"
  WHERE ("user_id" = '${crdtDb.userId}')
    AND ("node_id" = '${crdtDb.nodeId}')
) = TRUE
BEGIN
$innerSql
END;''';

  @override
  String getInsertStatement({
    required TableInfo<Table, Object?> table,
    required Operation operation,
  }) {
    final tableName = table.actualTableName;

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

    final columnInserts = columnNames.map((c) {
      final columnValue = c == isDeletedColumnName
          ? operation == Operation.delete
                ? 'TRUE'
                : 'FALSE'
          : 'NEW."$c"';

      return '    SELECT\n${[
        '      \'$c\' AS "column_name"',
        '      $columnValue AS "raw_value"',
        if (operation == Operation.update) '      NEW."$c" IS NOT OLD."$c" AS "value_changed"',
      ].join(',\n')}';
    });

    final whereClause = operation == Operation.update
        ? '("value_changed" = TRUE)'
        : 'TRUE';

    return '''
  INSERT INTO "$hlcCanonicalViewName" ("user_id")
  VALUES ('${crdtDb.userId}');

  INSERT INTO "$crdtDataTableName" (
    ${crdtDataAllColumns.join(', ')}
  )
  SELECT
    '${crdtDb.userId}' AS "user_id",
    '$tableName' AS "table_name",
    "column_name",
    $uniqueRowId AS "row_id",
    (
      SELECT (${_getHlcJsonExprSql()})
      FROM "$hlcStateTableName"
      WHERE "user_id" = '${crdtDb.userId}'
    ) AS "hlc_timestamp",
    raw_value
  FROM (
${columnInserts.join('\n    UNION ALL\n')}
  )
  WHERE $whereClause
  ON CONFLICT (${crdtDataPrimaryKeyColumns.join(', ')})
  DO UPDATE SET
    "hlc_timestamp" = EXCLUDED."hlc_timestamp",
    "raw_value" = EXCLUDED."raw_value";''';
  }

  /// Returns SQL fragment that formats (last_timestamp, counter, node_id) in the
  /// same format as the `hlcConverter.toSql` method.
  String _getHlcJsonExprSql() {
    return "printf('%015d', \"last_timestamp\") || '-' || "
        "printf('%05x', \"counter\") || '-' || "
        "'${crdtDb.nodeId}'";
  }

  /// Returns SQL statements to create the in-SQLite HLC view with "instead of"
  /// trigger that will act as a function to update the HLC on the HLC state table.
  /// This will be called from within trigger statements for the CRDT data table.
  @override
  List<String> generateSetupStatements() {
    return [
      '''
CREATE VIEW IF NOT EXISTS "$hlcCanonicalViewName" AS
SELECT CAST(NULL AS TEXT) AS "user_id"
WHERE FALSE;

CREATE TRIGGER IF NOT EXISTS "increment_canonical_hlc"
INSTEAD OF INSERT ON "$hlcCanonicalViewName"
BEGIN
  SELECT RAISE(ABORT, 'Clock drift exceeds 1 minute maximum.')
  FROM "$hlcStateTableName"
  WHERE "user_id" = NEW."user_id"
    AND "last_timestamp" > (unixepoch('now','subsec') + 60) * 1000;

  SELECT RAISE(ABORT, 'Timestamp counter overflow: 0xFFFF.')
  FROM "$hlcStateTableName"
  WHERE "user_id" = NEW."user_id"
    AND "counter" = 0xFFFF;

  INSERT INTO "$hlcStateTableName" ("user_id", "last_timestamp", "counter")
  SELECT NEW."user_id", ts, 0
  FROM (
    SELECT CAST(unixepoch('now','subsec') * 1000 AS INTEGER) AS ts
  )
  WHERE TRUE
  ON CONFLICT ("user_id") DO UPDATE SET
    "last_timestamp" = MAX("last_timestamp", EXCLUDED."last_timestamp"),
    "counter" = (
      CASE
        WHEN EXCLUDED."last_timestamp" > "last_timestamp" THEN 0
        ELSE "counter" + 1
      END
    );
END;''',
    ];
  }
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
