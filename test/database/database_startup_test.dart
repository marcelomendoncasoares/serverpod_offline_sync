import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

import '../utils/database.dart';

void main() {
  group(
    'Given a non-opened CRDT-enabled user database and the CRDT database being opened first',
    () {
      late CrdtDatabase crdtDb;

      setUp(() async {
        final migrator = database.createMigrator();
        crdtDb = migrator.crdtDb;
        await crdtDb.managers.crdtControlTable.limit(1).get();
      });

      test(
        'when performing an operation on the user database '
        'then the user database is also opened and no missing table errors occur.',
        () async {
          await expectLater(
            database.managers.todosTable.limit(1).get(),
            completes,
          );
        },
      );

      test(
        'when getting the main record from the CRDT control table '
        'then the record exists as expected.',
        () async {
          final record = await crdtDb.managers.crdtControlTable.limit(1).get();

          expect(record, isNotEmpty);
          expect(record.first.userId, equals(crdtDb.userId));
          expect(record.first.nodeId, equals(crdtDb.nodeId));
          expect(record.first.crdtTriggersOn, isTrue);
          expect(record.first.schemaVersion, equals(crdtDb.schemaVersion));
        },
      );
    },
  );

  group(
    'Given a non-opened CRDT-enabled user database and the user database being opened first',
    () {
      late CrdtDatabase crdtDb;

      setUp(() async {
        final migrator = database.createMigrator();
        crdtDb = migrator.crdtDb;
        await database.managers.todosTable.limit(1).get();
      });

      test(
        'when performing an operation on the CRDT database '
        'then the CRDT database is also opened and no missing table errors occur.',
        () async {
          await expectLater(crdtDb.managers.crdtControlTable.limit(1).get(), completes);
        },
      );

      test(
        'when getting the main record from the CRDT control table '
        'then the record exists as expected.',
        () async {
          final record = await crdtDb.managers.crdtControlTable.limit(1).get();

          expect(record, isNotEmpty);
          expect(record.first.userId, equals(crdtDb.userId));
          expect(record.first.nodeId, equals(crdtDb.nodeId));
          expect(record.first.crdtTriggersOn, isTrue);
          expect(record.first.schemaVersion, equals(crdtDb.schemaVersion));
        },
      );
    },
  );
}
