import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';
import '../utils/tables.dart';

void main() {
  late OfflineSyncCrdt crdt;
  late CrdtDatabase crdtDb;
  late String otherNodeId;

  group('Given CRDT for an empty database and a pending changeset', () {
    late Iterable<CrdtDataEntry> changeset;
    late Hlc lastHlc;

    setUp(() async {
      (crdt, crdtDb, _) = database.crdtContext;
      otherNodeId = const Uuid().v4();

      final todo = TodoEntry(
        id: const RowId(1),
        content: 'test',
        targetDate: DateTime.now(),
      );

      changeset = crdtDb.convertToCrdtDataEntry(todo, Hlc.now(otherNodeId));
      lastHlc = Hlc.now(otherNodeId);
    });

    group('when saving a changeset', () {
      setUp(() async {
        await crdt.saveChangeset(changeset, [lastHlc]);
      });

      test('then the changeset is saved to the database.', () async {
        final savedChangeset = await crdtDb.managers.crdtDataTable.get();
        expect(savedChangeset, changeset);
      });

      test('then the merged HLCs are saved to the database.', () async {
        final savedMergedHlcs = await crdtDb.managers.crdtMergeHlcTable.get();
        expect(savedMergedHlcs.map((e) => e.lastReceivedHlc).single, lastHlc);
      });
    });
  });

  group(
      'Given CRDT for a database with data and a pending changeset with conflicting data and older HLC',
      () {
    late Iterable<CrdtDataEntry> firstChangeset;
    late Iterable<CrdtDataEntry> lateOldChangeset;
    late Hlc lastHlc;
    late Hlc lateOldHlc;

    setUp(() async {
      (crdt, crdtDb, _) = database.crdtContext;
      otherNodeId = const Uuid().v4();

      final todo = TodoEntry(
        id: const RowId(1),
        content: 'test',
        targetDate: DateTime.now(),
      );

      lastHlc = Hlc.now(otherNodeId);
      firstChangeset = crdtDb.convertToCrdtDataEntry(todo, lastHlc);
      await crdt.saveChangeset(firstChangeset, [lastHlc]);

      lateOldHlc = Hlc.zero(otherNodeId);
      lateOldChangeset = crdtDb.convertToCrdtDataEntry(todo, lateOldHlc);
    });

    group('when saving a changeset with older HLC', () {
      setUp(() async {
        await crdt.saveChangeset(lateOldChangeset, [lateOldHlc]);
      });

      test('then no changes are saved to the database.', () async {
        final savedChangeset = await crdtDb.managers.crdtDataTable.get();
        expect(savedChangeset, firstChangeset);
      });

      test('then the last received HLC is not updated in the database.', () async {
        final savedMergedHlcs = await crdtDb.managers.crdtMergeHlcTable.get();
        expect(savedMergedHlcs.map((e) => e.lastReceivedHlc).single, lastHlc);
      });
    });
  });

  group(
      'Given CRDT for a database with data and a pending changeset with conflicting data and some entries with newer HLC',
      () {
    late Iterable<CrdtDataEntry> firstChangeset;
    late Iterable<CrdtDataEntry> newerChangeset;
    late Hlc lastHlc;
    late Hlc newerHlc;

    setUp(() async {
      (crdt, crdtDb, _) = database.crdtContext;
      otherNodeId = const Uuid().v4();

      final todo = TodoEntry(
        id: const RowId(1),
        content: 'test',
        targetDate: DateTime.now(),
      );

      lastHlc = Hlc.now(otherNodeId);
      firstChangeset = crdtDb.convertToCrdtDataEntry(todo, lastHlc);
      await crdt.saveChangeset(firstChangeset, [lastHlc]);

      newerHlc = Hlc.now(otherNodeId);
      newerChangeset = crdtDb
          .convertToCrdtDataEntry(todo, newerHlc)
          .where((e) => e.columnName == 'content');
    });

    group('when saving a changeset with some entries with newer HLC', () {
      setUp(() async {
        await crdt.saveChangeset(newerChangeset, [newerHlc]);
      });

      test('then the entries with newer HLC are saved to the database.', () async {
        final expectedResultingChangeset = [
          for (final e in firstChangeset)
            if (e.columnName == 'content') newerChangeset.first else e,
        ];

        expect(await crdtDb.managers.crdtDataTable.get(), expectedResultingChangeset);
      });

      test('then the last received HLC is updated in the database.', () async {
        final savedMergedHlcs = await crdtDb.managers.crdtMergeHlcTable.get();
        expect(savedMergedHlcs.map((e) => e.lastReceivedHlc).single, newerHlc);
      });
    });
  });
}
