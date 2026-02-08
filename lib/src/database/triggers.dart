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
  )${operation == Operation.update ? '\n  WHERE ("value_changed" = TRUE)' : ''};''';
  }

  /// Returns SQL fragment that formats (last_timestamp, counter, node_id) in the
  /// same format as the `hlcConverter.toSql` method.
  String _getHlcJsonExprSql() {
    return "printf('%015d', \"last_timestamp\") || '-' || "
        "printf('%04X', \"counter\") || '-' || "
        "'${crdtDb.nodeId}'";
  }

  /// Returns SQL fragment that combines the split HLC columns (hlc_timestamp,
  /// hlc_counter, hlc_node_id) back into a single text field. The counter is
  /// stored as a 4-digit uppercase hex string (e.g., "0000", "001A").
  String _getHlcCombineExprSql() {
    return "printf('%015d', \"hlc_timestamp\") || '-' || "
        '"hlc_counter" || \'-\' || '
        '"hlc_node_id"';
  }

  /// Returns SQL statements to create the CRDT data view and its INSTEAD OF
  /// triggers, and the HLC canonical view with its INSTEAD OF trigger.
  ///
  /// The CRDT data view exposes the crdt data table schema reading from the
  /// normalized table. Conflict resolution (newer HLC wins) is done in the
  /// INSTEAD OF INSERT trigger so that callers can use pure INSERT.
  ///
  /// The INSTEAD OF trigger for the HLC canonical view will be used to update
  /// the HLC on the HLC state table. This will be called from within trigger
  /// statements for the CRDT data table.
  @override
  List<String> generateSetupStatements() => [
    ..._createCrdtDataViewSetupStatements(),
    _createHlcCanonicalViewStatement(),
    _createIncrementCanonicalHlcTriggerStatement(),
  ];

  /// CRDT data view scope: view name, normalized table, and derived SQL
  /// fragments. Returns the CREATE VIEW and the three INSTEAD OF triggers.
  List<String> _createCrdtDataViewSetupStatements() {
    return [
      _createCrdtDataViewStatement(),
      _createCrdtDataInsteadOfInsertTriggerStatement(),
      _createCrdtDataInsteadOfUpdateTriggerStatement(),
      _createCrdtDataInsteadOfDeleteTriggerStatement(),
    ];
  }

  String get _normalizedTableName => crdtDb.crdtNormalizedDataTable.actualTableName;

  /// CREATE VIEW for the CRDT data view: combines the split HLC columns from
  /// the normalized table back into a single hlc_timestamp text field.
  String _createCrdtDataViewStatement() =>
      '''
CREATE VIEW IF NOT EXISTS "$crdtDataTableName" AS
SELECT 
  "user_id",
  "table_name",
  "column_name",
  "row_id",
  ${_getHlcCombineExprSql()} AS "hlc_timestamp",
  "raw_value"
FROM "$_normalizedTableName";''';

  /// INSTEAD OF INSERT on the CRDT data view: insert into the normalized table,
  /// splitting the hlc_timestamp text into 3 columns, and on conflict update
  /// only when the new row has a greater hlc_timestamp.
  String _createCrdtDataInsteadOfInsertTriggerStatement() =>
      '''
CREATE TRIGGER IF NOT EXISTS "${crdtDataTableName}__instead_of_insert"
INSTEAD OF INSERT ON "$crdtDataTableName"
BEGIN
  INSERT INTO "$_normalizedTableName" (
    "user_id", "table_name", "column_name", "row_id",
    "hlc_timestamp", "hlc_counter", "hlc_node_id", "raw_value"
  )
  SELECT
    NEW."user_id",
    NEW."table_name",
    NEW."column_name",
    NEW."row_id",
    CAST(SUBSTR(NEW."hlc_timestamp", 1, 15) AS INTEGER),
    SUBSTR(NEW."hlc_timestamp", 17, 4),
    SUBSTR(NEW."hlc_timestamp", 22),
    NEW."raw_value"
  ON CONFLICT ("user_id", "table_name", "column_name", "row_id") DO UPDATE SET
    "hlc_timestamp" = excluded."hlc_timestamp",
    "hlc_counter" = excluded."hlc_counter",
    "hlc_node_id" = excluded."hlc_node_id",
    "raw_value" = excluded."raw_value"
  WHERE "hlc_timestamp" < excluded."hlc_timestamp"
     OR ("hlc_timestamp" = excluded."hlc_timestamp" AND "hlc_counter" < excluded."hlc_counter");
END;''';

  /// INSTEAD OF UPDATE on the CRDT data view: apply the new values to the
  /// matching row in the normalized table (by primary key), splitting the
  /// hlc_timestamp text into 3 columns.
  String _createCrdtDataInsteadOfUpdateTriggerStatement() =>
      '''
CREATE TRIGGER IF NOT EXISTS "${crdtDataTableName}__instead_of_update"
INSTEAD OF UPDATE ON "$crdtDataTableName"
BEGIN
  UPDATE "$_normalizedTableName"
  SET 
    "user_id" = NEW."user_id",
    "table_name" = NEW."table_name",
    "column_name" = NEW."column_name",
    "row_id" = NEW."row_id",
    "hlc_timestamp" = CAST(SUBSTR(NEW."hlc_timestamp", 1, 15) AS INTEGER),
    "hlc_counter" = SUBSTR(NEW."hlc_timestamp", 17, 4),
    "hlc_node_id" = SUBSTR(NEW."hlc_timestamp", 22),
    "raw_value" = NEW."raw_value"
  WHERE "user_id" = OLD."user_id"
    AND "table_name" = OLD."table_name"
    AND "column_name" = OLD."column_name"
    AND "row_id" = OLD."row_id";
END;''';

  /// INSTEAD OF DELETE on the CRDT data view: delete the matching row from the
  /// normalized table (by primary key).
  String _createCrdtDataInsteadOfDeleteTriggerStatement() =>
      '''
CREATE TRIGGER IF NOT EXISTS "${crdtDataTableName}__instead_of_delete"
INSTEAD OF DELETE ON "$crdtDataTableName"
BEGIN
  DELETE FROM "$_normalizedTableName"
  WHERE "user_id" = OLD."user_id"
    AND "table_name" = OLD."table_name"
    AND "column_name" = OLD."column_name"
    AND "row_id" = OLD."row_id";
END;''';

  /// CREATE VIEW for the HLC canonical view: an empty view (WHERE FALSE) used
  /// only as a target for INSTEAD OF INSERT to advance the HLC.
  String _createHlcCanonicalViewStatement() =>
      '''
CREATE VIEW IF NOT EXISTS "$hlcCanonicalViewName" AS
SELECT CAST(NULL AS TEXT) AS "user_id"
WHERE FALSE;''';

  /// INSTEAD OF INSERT on the HLC canonical view: validates clock and counter,
  /// then upserts the HLC state row (advancing timestamp/counter on conflict).
  String _createIncrementCanonicalHlcTriggerStatement() =>
      '''
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
