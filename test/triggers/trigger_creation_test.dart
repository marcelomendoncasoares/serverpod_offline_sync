import 'package:drift_offline_first/src/triggers.dart';
import 'package:test/test.dart';

import '../utils/database.dart';

void main() {
  group('Given a database with an OfflineSyncMigrator', () {
    group('when running the migration', () {
      setUp(() async {
        // Insert a new row to trigger the migration.
        await database.managers.todosTable.create(
          (t) => t(content: 'test'),
        );
      });

      test('then the triggers are created for every synchronized table.', () async {
        final allTriggerNames = await database.getCrdtTriggers();

        for (final table in database.createMigrator().synchronizedTables) {
          final triggerNames = allTriggerNames
              .where((name) => name.startsWith('__crdt__${table.actualTableName}__'))
              .toList();

          expect(triggerNames, contains('__crdt__${table.actualTableName}__insert'));
          expect(triggerNames, contains('__crdt__${table.actualTableName}__update'));
          expect(triggerNames, contains('__crdt__${table.actualTableName}__delete'));
        }
      });
    });
  });

  // TODO: Add a test for the case where a table has no primary key.
  // TODO: Add a test for the case where a table has multiple primary key columns.
  // TODO: Add a test for the case where a table has only primary key columns.
}
