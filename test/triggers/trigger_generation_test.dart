import 'package:drift_offline_sync/src/database/triggers.dart';
import 'package:drift_offline_sync/src/migrator.dart';
import 'package:test/test.dart';

import '../utils/database.dart';
import '../utils/user.dart';

void main() {
  group('Given a SQLite3 database with a table', () {
    late OfflineSyncMigrator migrator;

    setUp(() {
      migrator = database.createMigrator();
    });

    group('when generating trigger statements', () {
      late List<String> triggers;

      setUp(() {
        final generator = Sqlite3OfflineSyncTriggers(migrator.crdtDb);
        triggers = generator.generateCreateTriggerStatements(database.todosTable);
      });

      test('then one trigger is created for each operation.', () {
        expect(triggers, hasLength(3));
        expect(triggers, anyElement(contains('AFTER INSERT ON "todos"')));
        expect(triggers, anyElement(contains('AFTER UPDATE ON "todos"')));
        expect(triggers, anyElement(contains('AFTER DELETE ON "todos"')));
      });

      test('then the insert trigger statement is correct.', () {
        final insertStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER INSERT ON "todos"'),
        );

        expect(
          insertStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS "__crdt__todos__insert"
AFTER INSERT ON "todos"
WHEN (
  SELECT MAX("crdt_triggers_on")
  FROM "__crdt_control"
  WHERE ("user_id" = '${migrator.userId}')
    AND ("node_id" = '${migrator.nodeId}')
) = TRUE
BEGIN
  INSERT INTO "__crdt_data" (
    "user_id", "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value"
  )
  SELECT
    '${migrator.userId}' AS "user_id",
    'todos' AS "table_name",
    "column_name",
    NEW."id" AS "row_id",
    "hlc_timestamp",
    raw_value
  FROM (
    SELECT $nextHlcFunction('${migrator.userId}', '${migrator.nodeId}') AS "hlc_timestamp"
  ), (
    SELECT
      'id' AS "column_name",
      NEW."id" AS "raw_value"
    UNION ALL
    SELECT
      'title' AS "column_name",
      NEW."title" AS "raw_value"
    UNION ALL
    SELECT
      'content' AS "column_name",
      NEW."content" AS "raw_value"
    UNION ALL
    SELECT
      'target_date' AS "column_name",
      NEW."target_date" AS "raw_value"
    UNION ALL
    SELECT
      'category' AS "column_name",
      NEW."category" AS "raw_value"
    UNION ALL
    SELECT
      'status' AS "column_name",
      NEW."status" AS "raw_value"
    UNION ALL
    SELECT
      '__crdt_is_deleted' AS "column_name",
      FALSE AS "raw_value"
  )
  WHERE TRUE
  ON CONFLICT ("user_id", "table_name", "column_name", "row_id")
  DO UPDATE SET
    "hlc_timestamp" = EXCLUDED."hlc_timestamp",
    "raw_value" = EXCLUDED."raw_value";
END;''',
        );
      });

      test('then the update trigger statement is correct.', () {
        final updateStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER UPDATE ON "todos"'),
        );

        expect(
          updateStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS "__crdt__todos__update"
AFTER UPDATE ON "todos"
WHEN (
  SELECT MAX("crdt_triggers_on")
  FROM "__crdt_control"
  WHERE ("user_id" = '${migrator.userId}')
    AND ("node_id" = '${migrator.nodeId}')
) = TRUE
BEGIN
  INSERT INTO "__crdt_data" (
    "user_id", "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value"
  )
  SELECT
    '${migrator.userId}' AS "user_id",
    'todos' AS "table_name",
    "column_name",
    OLD."id" AS "row_id",
    "hlc_timestamp",
    raw_value
  FROM (
    SELECT $nextHlcFunction('${migrator.userId}', '${migrator.nodeId}') AS "hlc_timestamp"
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
  WHERE ("value_changed" = TRUE)
  ON CONFLICT ("user_id", "table_name", "column_name", "row_id")
  DO UPDATE SET
    "hlc_timestamp" = EXCLUDED."hlc_timestamp",
    "raw_value" = EXCLUDED."raw_value";
END;''',
        );
      });

      test('then the delete trigger statement is correct.', () {
        final deleteStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER DELETE ON "todos"'),
        );

        expect(
          deleteStatement,
          '''\
CREATE TRIGGER IF NOT EXISTS "__crdt__todos__delete"
AFTER DELETE ON "todos"
WHEN (
  SELECT MAX("crdt_triggers_on")
  FROM "__crdt_control"
  WHERE ("user_id" = '${migrator.userId}')
    AND ("node_id" = '${migrator.nodeId}')
) = TRUE
BEGIN
  INSERT INTO "__crdt_data" (
    "user_id", "table_name", "column_name", "row_id", "hlc_timestamp", "raw_value"
  )
  SELECT
    '${migrator.userId}' AS "user_id",
    'todos' AS "table_name",
    "column_name",
    OLD."id" AS "row_id",
    "hlc_timestamp",
    raw_value
  FROM (
    SELECT $nextHlcFunction('${migrator.userId}', '${migrator.nodeId}') AS "hlc_timestamp"
  ), (
    SELECT
      '__crdt_is_deleted' AS "column_name",
      TRUE AS "raw_value"
  )
  WHERE TRUE
  ON CONFLICT ("user_id", "table_name", "column_name", "row_id")
  DO UPDATE SET
    "hlc_timestamp" = EXCLUDED."hlc_timestamp",
    "raw_value" = EXCLUDED."raw_value";
END;''',
        );
      });
    });
  });

  test('Given a SQLite3 database with a table that has only primary key columns '
      'when generating trigger statements '
      'then the triggers are generated with success.', () {
    final migrator = database.createMigrator();
    final generator = Sqlite3OfflineSyncTriggers(migrator.crdtDb);
    final triggers = generator.generateCreateTriggerStatements(database.pureDefaults);

    expect(triggers, hasLength(3));
  });

  group(
    'Given a SQLite3 database with a table that has multiple primary key columns',
    () {
      late OfflineSyncMigrator migrator;

      setUp(() {
        migrator = database.createMigrator();
      });

      group('when generating trigger statements', () {
        late List<String> triggers;

        setUp(() {
          final generator = Sqlite3OfflineSyncTriggers(migrator.crdtDb);
          triggers = generator.generateCreateTriggerStatements(database.sharedTodos);
        });

        test('then the triggers are generated with success.', () {
          expect(triggers, hasLength(3));
        });

        group('then the insert trigger', () {
          late final insertStatement = triggers.firstWhere(
            (trigger) => trigger.contains('AFTER INSERT ON "shared_todos"'),
          );

          test(
            'has the "row_id" as a "CONCAT_WS" of all primary key columns.',
            () {
              expect(
                insertStatement,
                contains("CONCAT_WS('||', NEW.\"todo\", NEW.\"user\") AS \"row_id\""),
              );
            },
          );

          test('has the primary key columns also present as individual entries.', () {
            expect(insertStatement, contains("'todo' AS \"column_name\""));
            expect(insertStatement, contains("'user' AS \"column_name\""));
          });
        });

        group('then the update trigger', () {
          late final updateStatement = triggers.firstWhere(
            (trigger) => trigger.contains('AFTER UPDATE ON "shared_todos"'),
          );

          test('has the "row_id" as a "CONCAT_WS" of all primary key columns.', () {
            expect(
              updateStatement,
              contains("CONCAT_WS('||', OLD.\"todo\", OLD.\"user\") AS \"row_id\""),
            );
          });

          test('has the primary key columns also present as individual entries.', () {
            expect(updateStatement, contains("'todo' AS \"column_name\""));
            expect(updateStatement, contains("'user' AS \"column_name\""));
          });
        });

        test(
          'then the delete trigger has the "row_id" as a "CONCAT_WS" of all primary key columns.',
          () {
            final deleteStatement = triggers.firstWhere(
              (trigger) => trigger.contains('AFTER DELETE ON "shared_todos"'),
            );

            expect(
              deleteStatement,
              contains("CONCAT_WS('||', OLD.\"todo\", OLD.\"user\") AS \"row_id\""),
            );
          },
        );
      });
    },
  );

  group('Given a SQLite3 database with a table that has generated columns', () {
    late OfflineSyncMigrator migrator;

    setUp(() {
      migrator = database.createMigrator();
    });

    group('when generating trigger statements', () {
      late List<String> triggers;

      setUp(() {
        final generator = Sqlite3OfflineSyncTriggers(migrator.crdtDb);
        triggers = generator.generateCreateTriggerStatements(database.categories);

        // Pin the column name to avoid having the `isNot(contains())` tests passing
        // with no real test if the column is removed or renamed.
        expect(
          database.categories.descriptionInUpperCase.$name,
          'description_in_upper_case',
        );
      });

      test('then the insert trigger excludes generated columns.', () {
        final insertStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER INSERT ON "categories"'),
        );

        expect(insertStatement, isNot(contains("'description_in_upper_case'")));
      });

      test('then the update trigger excludes generated columns.', () {
        final updateStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER UPDATE ON "categories"'),
        );

        expect(updateStatement, isNot(contains("'description_in_upper_case'")));
      });
    });
  });

  // This test assures that the above tests are for [ConflictingBias.deleteWins]
  // and avoids the need for duplicating all tests.
  test('Given a SQLite3 migrator with no specified conflicting bias '
      'then it generates the triggers with the deleteWins conflicting bias.', () {
    final migrator = database.createMigrator();
    expect(migrator.conflictingBias, ConflictingBias.deleteWins);
  });

  group('Given a SQLite3 database with a table and updateWins conflicting bias', () {
    late OfflineSyncMigrator migrator;
    late String isDeletedColumnName;

    setUp(() {
      migrator = OfflineSyncMigrator(
        database,
        userId: testUserId,
        nodeId: testNodeId,
        conflictingBias: ConflictingBias.updateWins,
        synchronizedTables: [
          database.todosTable,
        ],
      );

      isDeletedColumnName = migrator.crdtDb.sqlBuilder.isDeletedColumnName;
    });

    group('when generating trigger statements', () {
      late List<String> triggers;

      setUp(() {
        final generator = Sqlite3OfflineSyncTriggers(
          migrator.crdtDb,
          ConflictingBias.updateWins,
        );
        triggers = generator.generateCreateTriggerStatements(database.todosTable);
      });

      test('then the update trigger includes the deleted flag column.', () {
        final updateStatement = triggers.firstWhere(
          (trigger) => trigger.contains('AFTER UPDATE ON "todos"'),
        );

        expect(
          updateStatement,
          contains('''
    UNION ALL
    SELECT
      '$isDeletedColumnName' AS "column_name",
      FALSE AS "raw_value",
      NEW."__crdt_is_deleted" IS NOT OLD."__crdt_is_deleted" AS "value_changed"
  '''),
        );
      });
    });
  });
}
