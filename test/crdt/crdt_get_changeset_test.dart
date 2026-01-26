import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';

void main() {
  group('Given CRDT for an empty database', () {
    late OfflineSyncCrdt crdt;

    setUp(() async {
      (crdt, _, _) = database.crdtContext;
    });

    test('when getting a changeset '
        'then it returns an empty changeset.', () async {
      final changeset = await crdt.getChangeset();

      expect(changeset, isEmpty);
    });

    test('when adding data to the database '
        'then the changeset contains the data.', () async {
      await database.managers.todosTable.create(
        (t) => t(content: 'test'),
      );

      final changeset = await crdt.getChangeset();
      expect(changeset, isNotEmpty);
    });
  });

  group('Given CRDT for a database with data', () {
    late OfflineSyncCrdt crdt;
    late CrdtDatabase crdtDb;
    late String nodeId;
    late String rowId;
    late Hlc createdHlc;
    late TodoEntry createdData;

    setUp(() async {
      final createdRowId = await database.managers.todosTable.create(
        (t) => t(content: 'test', targetDate: Value(DateTime.now())),
      );

      (crdt, crdtDb, nodeId) = database.crdtContext;

      final allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
      createdHlc = allCrdtDataEntries.first.hlcTimestamp;
      rowId = createdRowId.toString();
      createdData = await database.managers.todosTable.getSingle();
    });

    group('when getting a changeset', () {
      group('without any filters', () {
        test(
          'then it returns a changeset with one entry per column of the created data.',
          () async {
            final changeset = await crdt.getChangeset();
            final changesetColumns = changeset.map((e) => e.columnName).toSet();
            final expectedColumns = database.todosTable.$columns.map((c) => c.$name);

            expect(changeset.length, expectedColumns.length);
            expect(changesetColumns, equals(expectedColumns));
          },
        );

        test('then the raw values are set correctly.', () async {
          final changeset = await crdt.getChangeset();
          final rebuiltData = database.todosTable.map({
            for (final c in database.todosTable.$columns)
              c.$name: changeset
                  .firstWhere((e) => e.rowId == rowId && e.columnName == c.$name)
                  .rawValue
                  ?.rawSqlValue,
          });

          expect(rebuiltData, equals(createdData));
        });
      });

      test('with onlyNodeId set to the nodeId '
          'then it returns a changeset with the data for the nodeId.', () async {
        final changeset = await crdt.getChangeset(onlyNodeId: nodeId);
        final nodeIds = changeset.map((e) => e.hlcTimestamp.nodeId).toSet();

        expect(changeset, isNotEmpty);
        expect(nodeIds, equals({nodeId}));
      });

      test('with onlyNodeId set to a different nodeId '
          'then it returns an empty changeset.', () async {
        final changeset = await crdt.getChangeset(onlyNodeId: 'wrong-node');

        expect(changeset, isEmpty);
      });

      test('with exceptNodeId set to the nodeId '
          'then it returns an empty changeset.', () async {
        final changeset = await crdt.getChangeset(exceptNodeId: nodeId);

        expect(changeset, isEmpty);
      });

      test('with exceptNodeId set to a different nodeId '
          'then it returns a changeset with data from other nodes.', () async {
        const otherNodeId = 'other-node';
        final changeset = await crdt.getChangeset(exceptNodeId: otherNodeId);
        final nodeIds = changeset.map((e) => e.hlcTimestamp.nodeId).toSet();

        expect(changeset, isNotEmpty);
        expect(nodeIds, isNot(contains(otherNodeId)));
      });

      test(
        'with modifiedAfter set to a timestamp before the created data '
        'then it returns a changeset with the entries from the created data.',
        () async {
          final earlierHlc = Hlc.zero(nodeId);
          final changeset = await crdt.getChangeset(modifiedAfter: earlierHlc);

          expect(changeset, isNotEmpty);
          expect(changeset.map((e) => e.rowId).toSet(), equals({rowId}));
        },
      );

      test('with modifiedAfter set to a timestamp after the created data '
          'then it returns an empty changeset.', () async {
        final futureHlc = createdHlc.increment();
        final changeset = await crdt.getChangeset(modifiedAfter: futureHlc);

        expect(changeset, isEmpty);
      });
    });
  });
}
