import 'package:test/test.dart';

import '../utils/executor.dart';
import '../utils/migration.dart';
import '../utils/user.dart';

void main() {
  group(
    'Given a non-opened CRDT-enabled user database with pending migrations and the CRDT database being opened first',
    () {
      late FirstDb firstDb;
      late SecondDb secondDb;
      late String fileName;

      setUp(() async {
        fileName = 'migration_test_$testNodeId.db';

        setTestFileExecutor(fileName);
        firstDb = FirstDb(testExecutor);
        await firstDb.managers.todosTable.limit(1).get();
        await firstDb.close();

        setTestFileExecutor(fileName);
        secondDb = SecondDb(testExecutor);

        final migrator = secondDb.createMigrator();
        await migrator.crdtDb.managers.crdtControlTable.limit(1).get();
      });

      tearDown(() async {
        await secondDb.close();
      });

      test(
        'when performing an operation on the user database after schema version upgrade '
        'then migrations were applied as expected.',
        () async {
          expect(secondDb.didUpgrade, isTrue);
          await expectLater(secondDb.managers.users.limit(1).get(), completes);
        },
      );

      test(
        'when getting the actual schema version of the user database after migrations were applied '
        'then the saved schema version is the same as the expected schema version.',
        () async {
          final pragma = await secondDb.customSelect('PRAGMA user_version').getSingle();
          expect(pragma.read<int>('user_version'), equals(2));
        },
      );

      group(
        'when opening the CRDT database after the second migration was applied',
        () {
          setUp(() async {
            await secondDb.close();
            setTestFileExecutor(fileName);
            secondDb = SecondDb(testExecutor);

            final migrator = secondDb.createMigrator();
            await migrator.crdtDb.managers.crdtControlTable.limit(1).get();
          });

          test('then no migrations were applied.', () async {
            expect(secondDb.didUpgrade, isFalse);
          });

          test('then the schema version is the expected schema version.', () async {
            final pragma = await secondDb
                .customSelect('PRAGMA user_version')
                .getSingle();
            expect(pragma.read<int>('user_version'), equals(2));
          });
        },
      );

      test(
        'when opening the user database after the second migration was applied '
        'then no migrations were applied.',
        () async {
          await secondDb.close();
          setTestFileExecutor(fileName);
          secondDb = SecondDb(testExecutor);

          await secondDb.managers.users.limit(1).get();

          expect(secondDb.didUpgrade, isFalse);
        },
      );
    },
  );
}
