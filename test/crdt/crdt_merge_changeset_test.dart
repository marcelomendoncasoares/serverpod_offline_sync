import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';
import '../utils/tables.dart';
import 'crdt_test_utils.dart';

void main() {
  late OfflineSyncCrdt crdt;
  late CrdtDatabase crdtDb;
  late String nodeId;

  group('Given CRDT for an empty database and a pending changeset', () {
    late Iterable<CrdtDataEntry> changeset;

    setUp(() async {
      (crdt, crdtDb, nodeId) = database.crdtContext;

      final todo = TodoEntry(
        id: const RowId(1),
        content: 'test',
        targetDate: DateTime.now(),
      );

      changeset = crdtDb.convertToCrdtDataEntry(todo, Hlc.now(nodeId));
    });

    test('when merging a changeset '
        'then the changeset is saved to the database.', () async {
      await crdt.merge(changeset);

      final savedChangeset = await crdtDb.managers.crdtDataTable.get();
      expect(savedChangeset.sortedEntries, changeset.sortedEntries);
    });
  });

  group(
    'Given CRDT for a database with data and a pending changeset with conflicting data and older HLC',
    () {
      late Iterable<CrdtDataEntry> firstChangeset;
      late Iterable<CrdtDataEntry> lateOldChangeset;

      setUp(() async {
        (crdt, crdtDb, nodeId) = database.crdtContext;

        final todo = TodoEntry(
          id: const RowId(1),
          content: 'test',
          targetDate: DateTime.now(),
        );

        firstChangeset = crdtDb.convertToCrdtDataEntry(todo, Hlc.now(nodeId));
        await crdt.merge(firstChangeset);

        lateOldChangeset = crdtDb.convertToCrdtDataEntry(todo, Hlc.zero(nodeId));
      });

      test('when merging a changeset with older HLC '
          'then no changes are saved to the database.', () async {
        await crdt.merge(lateOldChangeset);

        final savedChangeset = await crdtDb.managers.crdtDataTable.get();
        expect(savedChangeset.sortedEntries, firstChangeset.sortedEntries);
      });
    },
  );

  group(
    'Given CRDT for a database with data and a pending changeset with conflicting data and some entries with newer HLC',
    () {
      late Iterable<CrdtDataEntry> firstChangeset;
      late Iterable<CrdtDataEntry> newerChangeset;

      setUp(() async {
        (crdt, crdtDb, nodeId) = database.crdtContext;

        final todo = TodoEntry(
          id: const RowId(1),
          content: 'test',
          targetDate: DateTime.now(),
        );

        firstChangeset = crdtDb.convertToCrdtDataEntry(todo, Hlc.now(nodeId));
        await crdt.merge(firstChangeset);

        newerChangeset = crdtDb
            .convertToCrdtDataEntry(todo, Hlc.now(nodeId))
            .where((e) => e.columnName == 'content');
      });

      test('when merging a changeset with some entries with newer HLC '
          'then the entries with newer HLC are saved to the database.', () async {
        await crdt.merge(newerChangeset);

        final expectedChangeset = [
          for (final e in firstChangeset)
            if (e.columnName == 'content') newerChangeset.first else e,
        ];

        final savedChangeset = await crdtDb.managers.crdtDataTable.get();
        expect(savedChangeset.sortedEntries, expectedChangeset.sortedEntries);
      });
    },
  );
}
