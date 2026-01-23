import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
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

      changeset = todo.toCrdtDataEntry(nodeId);
    });

    test(
        'when merging a changeset '
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

      firstChangeset = todo.toCrdtDataEntry(nodeId);
      await crdt.merge(firstChangeset);

      lateOldChangeset = todo.toCrdtDataEntry(nodeId, hlc: Hlc.zero(nodeId));
    });

    test(
        'when merging a changeset with older HLC '
        'then no changes are saved to the database.', () async {
      await crdt.merge(lateOldChangeset);

      expect(await crdtDb.managers.crdtDataTable.get(), firstChangeset);
    });
  });

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

      firstChangeset = todo.toCrdtDataEntry(nodeId);
      await crdt.merge(firstChangeset);

      newerChangeset =
          todo.toCrdtDataEntry(nodeId).where((e) => e.columnName == 'content');
    });

    test(
        'when merging a changeset with some entries with newer HLC '
        'then the entries with newer HLC are saved to the database.', () async {
      await crdt.merge(newerChangeset);

      final expectedResultingChangeset = [
        for (final e in firstChangeset)
          if (e.columnName == 'content') newerChangeset.first else e,
      ];

      expect(await crdtDb.managers.crdtDataTable.get(), expectedResultingChangeset);
    });
  });
}

extension on TodoEntry {
  Iterable<CrdtDataEntry> toCrdtDataEntry(String nodeId, {Hlc? hlc}) {
    final hlcTimestamp = hlc ?? Hlc.now(nodeId);

    return database.todosTable.$columns.map(
      (c) => CrdtDataEntry(
        userId: 'test',
        tblName: 'todos',
        columnName: c.$name,
        rowId: id.toString(),
        rawValue: (toJson()[c.$name] as Object?)?.toDriftAny(),
        hlcTimestamp: hlcTimestamp,
      ),
    );
  }
}

extension on Object {
  DriftAny? toDriftAny() {
    return DriftAny(this);
  }
}
