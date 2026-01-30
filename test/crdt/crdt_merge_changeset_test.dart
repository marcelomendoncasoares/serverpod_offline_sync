import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:drift_offline_sync/src/hlc/normalized.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/crdt_test_helper.dart';
import '../utils/database.dart';
import '../utils/tables.dart';

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

      expect(await crdtDb.managers.crdtDataTable.get(), changeset);
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

        expect(await crdtDb.managers.crdtDataTable.get(), firstChangeset);
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

        newerChangeset = await _filterByColumnName(
          crdtDb,
          crdtDb.convertToCrdtDataEntry(todo, Hlc.now(nodeId)),
          'content',
        );
      });

      test('when merging a changeset with some entries with newer HLC '
          'then the entries with newer HLC are saved to the database.', () async {
        await crdt.merge(newerChangeset);

        final expectedResultingChangeset = await Future.wait(
          firstChangeset.map((e) async {
            final columnName = await CrdtTestHelper.getColumnName(crdtDb, e);
            return columnName == 'content' ? newerChangeset.first : e;
          }),
        );

        expect(await crdtDb.managers.crdtDataTable.get(), expectedResultingChangeset);
      });
    },
  );
}

Future<Iterable<CrdtDataEntry>> _filterByColumnName(
  CrdtDatabase db,
  Iterable<CrdtDataEntry> entries,
  String columnName,
) async {
  final filtered = <CrdtDataEntry>[];
  for (final entry in entries) {
    final entryColumnName = await CrdtTestHelper.getColumnName(db, entry);
    if (entryColumnName == columnName) {
      filtered.add(entry);
    }
  }
  return filtered;
}
