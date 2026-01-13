import 'package:drift_offline_first/src/migrator.dart';
import 'package:drift_offline_first/src/triggers.dart';
import 'package:test/test.dart';

import '../utils/database.dart';

void main() {
  group('Given a SQLite3 database with a table', () {
    late OfflineSyncMigrator migrator;

    setUp(() async {
      migrator = database.createMigrator();
    });

    group('when generating trigger statements', () {
      late List<String> triggers;

      setUp(() async {
        final generator = Sqlite3OfflineSyncTriggers(migrator);
        triggers = generator.generateCreateTriggerStatements(database.todosTable);
      });

      test('then one trigger is created for each operation.', () {
        expect(triggers, hasLength(3));
        expect(triggers, anyElement(contains('AFTER INSERT ON "todos"')));
        expect(triggers, anyElement(contains('AFTER UPDATE ON "todos"')));
        expect(triggers, anyElement(contains('AFTER DELETE ON "todos"')));
      });

      test('then the insert trigger statement is correct.', () {
        final insertStatement = triggers
            .firstWhere((trigger) => trigger.contains('AFTER INSERT ON "todos"'));

        expect(
          insertStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS __crdt__todos__insert
AFTER INSERT ON "todos"
BEGIN
  INSERT OR REPLACE INTO __crdt_data (
    "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value", "value_changed"
  )
  SELECT
    'todos' AS "table_name",
    column_name,
    NEW."id" AS "row_id",
    "hlc_timestamp",
    raw_value,
    value_changed
  FROM (
    SELECT $nextHlcFunction('${migrator.nodeId}') AS "hlc_timestamp"
  ), (
    SELECT
      'id' AS "column_name",
      NEW."id" AS "raw_value",
      TRUE AS "value_changed"
    UNION ALL
    SELECT
      'title' AS "column_name",
      NEW."title" AS "raw_value",
      TRUE AS "value_changed"
    UNION ALL
    SELECT
      'content' AS "column_name",
      NEW."content" AS "raw_value",
      TRUE AS "value_changed"
    UNION ALL
    SELECT
      'target_date' AS "column_name",
      NEW."target_date" AS "raw_value",
      TRUE AS "value_changed"
    UNION ALL
    SELECT
      'category' AS "column_name",
      NEW."category" AS "raw_value",
      TRUE AS "value_changed"
    UNION ALL
    SELECT
      'status' AS "column_name",
      NEW."status" AS "raw_value",
      TRUE AS "value_changed"
  );
END;''',
        );
      });

      test('then the update trigger statement is correct.', () {
        final updateStatement = triggers
            .firstWhere((trigger) => trigger.contains('AFTER UPDATE ON "todos"'));

        expect(
          updateStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS __crdt__todos__update
AFTER UPDATE ON "todos"
BEGIN
  INSERT OR REPLACE INTO __crdt_data (
    "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value", "value_changed"
  )
  SELECT
    'todos' AS "table_name",
    column_name,
    OLD."id" AS "row_id",
    "hlc_timestamp",
    raw_value,
    value_changed
  FROM (
    SELECT $nextHlcFunction('${migrator.nodeId}') AS "hlc_timestamp"
  ), (
    SELECT
      'id' AS "column_name",
      NEW."id" AS "raw_value",
      NEW."id" IS NOT OLD."id" AS "value_changed"
    UNION ALL
    SELECT
      'title' AS "column_name",
      NEW."title" AS "raw_value",
      NEW."title" IS NOT OLD."title" AS "value_changed"
    UNION ALL
    SELECT
      'content' AS "column_name",
      NEW."content" AS "raw_value",
      NEW."content" IS NOT OLD."content" AS "value_changed"
    UNION ALL
    SELECT
      'target_date' AS "column_name",
      NEW."target_date" AS "raw_value",
      NEW."target_date" IS NOT OLD."target_date" AS "value_changed"
    UNION ALL
    SELECT
      'category' AS "column_name",
      NEW."category" AS "raw_value",
      NEW."category" IS NOT OLD."category" AS "value_changed"
    UNION ALL
    SELECT
      'status' AS "column_name",
      NEW."status" AS "raw_value",
      NEW."status" IS NOT OLD."status" AS "value_changed"
  )
  WHERE (value_changed = TRUE);
END;''',
        );
      });

      test('then the delete trigger statement is correct.', () {
        final deleteStatement = triggers
            .firstWhere((trigger) => trigger.contains('AFTER DELETE ON "todos"'));

        expect(
          deleteStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS __crdt__todos__delete
AFTER DELETE ON "todos"
BEGIN
  INSERT OR REPLACE INTO __crdt_data (
    "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value", "value_changed"
  )
  SELECT
    'todos' AS "table_name",
    column_name,
    OLD."id" AS "row_id",
    "hlc_timestamp",
    raw_value,
    value_changed
  FROM (
    SELECT $nextHlcFunction('${migrator.nodeId}') AS "hlc_timestamp"
  ), (
    SELECT
      '__crdt_is_deleted' AS "column_name",
      TRUE AS "raw_value",
      TRUE AS "value_changed"
  );
END;''',
        );
      });
    });
  });

  // TODO: Add a test for the case where a table has multiple primary key columns.
}
