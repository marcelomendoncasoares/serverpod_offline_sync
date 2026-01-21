import 'package:drift/drift.dart' show Value;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

import '../utils/database.dart';
import '../utils/tables.dart';

void main() {
  group('Given a database with an empty synchronized table', () {
    group('when inserting a new row on a synchronized table', () {
      const targetContent = 'test';
      final targetDate = DateTime(2026, 1, 13);
      late int createdRowId;
      late String rowId;

      setUp(() async {
        createdRowId = await database.managers.todosTable.create(
          (t) => t(
            content: targetContent,
            targetDate: Value(targetDate),
          ),
        );

        rowId = createdRowId.toString();
      });

      test('then the row exists in the target table.', () async {
        final row = await database.managers.todosTable.getSingle();

        expect(row, isNotNull);
        expect(row.content, targetContent);
        expect(row.targetDate, targetDate);
      });

      group('then the trigger is executed and the CRDT data table', () {
        late List<CrdtDataEntry> allCrdtDataEntries;

        setUp(() async {
          final migrator = database.createMigrator();
          allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
        });

        // test('has no entries for the primary key columns.', () async {
        //   final columnNames = allCrdtDataEntries.map((e) => e.columnName);
        //   final primaryKeys = database.todosTable.$primaryKey.map((p) => p.$name);
        //
        //   expect(columnNames, isNot(containsAll(primaryKeys)));
        // });

        test('has one entry for each column of the target table.', () async {
          expect(
            allCrdtDataEntries.map((e) => e.columnName).toSet(),
            equals(database.todosTable.$columns.map((c) => c.$name).toSet()),
          );
        });

        test('has the raw values inserted correctly.', () async {
          final crdtData = allCrdtDataEntries.getField(rowId, 'content');
          expect(
            crdtData.rawValue?.rawSqlValue,
            targetContent,
          );

          final targetDateCrdtData = allCrdtDataEntries.getField(rowId, 'target_date');
          expect(
            targetDateCrdtData.rawValue?.rawSqlValue,
            targetDate.toIso8600StringWithOffset(),
          );
        });

        test('has the same HLC timestamp for each inserted column.', () async {
          final targetHlc = allCrdtDataEntries.first.hlcTimestamp;

          final crdtData = allCrdtDataEntries.getField(rowId, 'content');
          expect(crdtData.hlcTimestamp, equals(targetHlc));

          final targetDateCrdtData = allCrdtDataEntries.getField(rowId, 'target_date');
          expect(targetDateCrdtData.hlcTimestamp, equals(targetHlc));
        });
      });
    });
  });

  group('Given a database with a synchronized table with a row', () {
    const initialContent = 'test';
    late int createdRowId;
    late Hlc createdHlc;
    late String rowId;

    setUp(() async {
      createdRowId = await database.managers.todosTable.create(
        (t) => t(content: initialContent),
      );

      final migrator = database.createMigrator();
      final allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
      createdHlc = allCrdtDataEntries.first.hlcTimestamp;
      rowId = createdRowId.toString();
    });

    group('when updating the existing row with a different value', () {
      const targetContent = 'test2';
      final targetDate = DateTime(2026, 1, 13);
      const updatedColumnNames = ['content', 'target_date'];

      setUp(() async {
        await database.managers.todosTable.update(
          (t) => t(
            id: Value(RowId(createdRowId)),
            content: const Value(targetContent),
            targetDate: Value(targetDate),
          ),
        );
      });

      test('then the row has been updated in the target table.', () async {
        final row = await database.managers.todosTable.getSingle();

        expect(row, isNotNull);
        expect(row.content, targetContent);
        expect(row.targetDate, targetDate);
      });

      group('then the trigger is executed and the updated row in the CRDT data table',
          () {
        late List<CrdtDataEntry> allCrdtDataEntries;

        setUp(() async {
          final migrator = database.createMigrator();
          allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
        });

        test('has the raw values updated correctly.', () async {
          final crdtData = allCrdtDataEntries.getField(rowId, 'content');
          expect(
            crdtData.rawValue?.rawSqlValue,
            targetContent,
          );

          final targetDateCrdtData = allCrdtDataEntries.getField(rowId, 'target_date');
          expect(
            targetDateCrdtData.rawValue?.rawSqlValue,
            targetDate.toIso8600StringWithOffset(),
          );
        });

        test('has the same HLC timestamp for each updated column.', () async {
          final updatedEntriesHlc = allCrdtDataEntries
              .where((entry) => entry.rowId == rowId)
              .where((entry) => updatedColumnNames.contains(entry.columnName))
              .map((entry) => entry.hlcTimestamp);

          expect(updatedEntriesHlc.toSet(), hasLength(1));
        });

        test('has the updated HLC timestamp greater than the created.', () async {
          final updatedEntry = allCrdtDataEntries.getField(rowId, 'content');
          expect(updatedEntry.hlcTimestamp, greaterThan(createdHlc));
        });

        test('has not changed the HLC timestamp for non-updated columns.', () async {
          final otherEntriesHlc = allCrdtDataEntries
              .where((entry) => entry.rowId == rowId)
              .where((entry) => !updatedColumnNames.contains(entry.columnName))
              .map((entry) => entry.hlcTimestamp);

          expect(otherEntriesHlc, everyElement(equals(createdHlc)));
        });
      });
    });

    group('when updating the existing row with the same value', () {
      setUp(() async {
        await database.managers.todosTable.update(
          (t) => t(
            id: Value(RowId(createdRowId)),
            content: const Value(initialContent),
          ),
        );
      });

      group('then the trigger is executed and the updated row in the CRDT data table',
          () {
        late List<CrdtDataEntry> allCrdtDataEntries;

        setUp(() async {
          final migrator = database.createMigrator();
          allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
        });

        test('has not changed the HLC timestamp for the updated column.', () async {
          final updatedEntry = allCrdtDataEntries.getField(rowId, 'content');
          expect(updatedEntry.hlcTimestamp, equals(createdHlc));
        });
      });
    });

    group('when deleting the existing row', () {
      setUp(() async {
        await database.managers.todosTable
            .filter((t) => t.id.equals(RowId(createdRowId)))
            .delete();
      });

      test('then the row has been deleted in the target table.', () async {
        final row = await database.managers.todosTable.getSingleOrNull();

        expect(row, isNull);
      });

      group('then the trigger is executed and the deleted row in the CRDT data table',
          () {
        late List<CrdtDataEntry> allCrdtDataEntries;
        late String rowId;

        setUp(() async {
          final migrator = database.createMigrator();
          allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();

          rowId = createdRowId.toString();
        });

        test('has the deleted flag column set to true.', () async {
          final crdtData = allCrdtDataEntries.getField(rowId, '__crdt_is_deleted');
          expect(crdtData.rawValue?.rawSqlValue, 1);
        });

        test('has the deleted HLC timestamp greater than the created.', () async {
          final deletedEntry = allCrdtDataEntries.getField(rowId, '__crdt_is_deleted');
          expect(deletedEntry.hlcTimestamp, greaterThan(createdHlc));
        });
      });
    });
  });
}

extension on Iterable<CrdtDataEntry> {
  CrdtDataEntry getField(String rowId, String fieldName) {
    return firstWhere((entry) => entry.rowId == rowId && entry.columnName == fieldName);
  }
}

extension on DateTime {
  String toIso8600StringWithOffset() {
    final offset = toLocal().timeZoneOffset.inHours;
    final sign = offset >= 0 ? '+' : '-';
    return '${toIso8601String()} $sign${offset.abs().toString().padLeft(2, '0')}:00';
  }
}
