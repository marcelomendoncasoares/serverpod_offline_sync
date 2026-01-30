import 'package:drift/drift.dart' show Value;
import 'package:drift_offline_sync/drift_offline_sync.dart';
import 'package:drift_offline_sync/src/hlc/normalized.dart';
import 'package:test/test.dart';

import '../utils/crdt_test_helper.dart';
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
        late String isDeletedColumnName;
        late List<CrdtDataEntry> allCrdtDataEntries;
        late CrdtDatabase crdtDb;

        setUp(() async {
          final migrator = database.createMigrator();
          crdtDb = migrator.crdtDb;
          allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
          isDeletedColumnName = crdtDb.sqlBuilder.isDeletedColumnName;
        });

        test('has one entry for each column of the target table.', () async {
          final columnNames = await Future.wait(
            allCrdtDataEntries.map((e) => CrdtTestHelper.getColumnName(crdtDb, e)),
          );
          expect(
            columnNames.toSet(),
            equals(
              database.todosTable.$columns.map((c) => c.$name).toSet()
                ..add(isDeletedColumnName),
            ),
          );
        });

        test('has the raw values inserted correctly.', () async {
          final crdtData = await allCrdtDataEntries.getFieldAsync(
            crdtDb,
            rowId,
            'content',
          );
          expect(crdtData.unwrappedValue, targetContent);

          final targetDateCrdtData = await allCrdtDataEntries.getFieldAsync(
            crdtDb,
            rowId,
            'target_date',
          );
          expect(
            targetDateCrdtData.unwrappedValue,
            targetDate.toIso8600StringWithOffset(),
          );
        });

        test('has the same HLC timestamp for each inserted column.', () async {
          final targetHlc = await CrdtTestHelper.getHlc(
            crdtDb,
            allCrdtDataEntries.first,
          );

          final crdtData = await allCrdtDataEntries.getFieldAsync(
            crdtDb,
            rowId,
            'content',
          );
          final crdtDataHlc = await CrdtTestHelper.getHlc(crdtDb, crdtData);
          expect(crdtDataHlc, equals(targetHlc));

          final targetDateCrdtData = await allCrdtDataEntries.getFieldAsync(
            crdtDb,
            rowId,
            'target_date',
          );
          final targetDateHlc = await CrdtTestHelper.getHlc(crdtDb, targetDateCrdtData);
          expect(targetDateHlc, equals(targetHlc));
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
      rowId = createdRowId.toString();

      final migrator = database.createMigrator();
      final allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
      createdHlc = await CrdtTestHelper.getHlc(
        migrator.crdtDb,
        allCrdtDataEntries.first,
      );
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

      group(
        'then the trigger is executed and the updated row in the CRDT data table',
        () {
          late List<CrdtDataEntry> allCrdtDataEntries;
          late CrdtDatabase crdtDb;

          setUp(() async {
            final migrator = database.createMigrator();
            crdtDb = migrator.crdtDb;
            allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
          });

          test('has the raw values updated correctly.', () async {
            final crdtData = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              'content',
            );
            expect(crdtData.unwrappedValue, targetContent);

            final targetDateCrdtData = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              'target_date',
            );
            expect(
              targetDateCrdtData.unwrappedValue,
              targetDate.toIso8600StringWithOffset(),
            );
          });

          test('has the same HLC timestamp for each updated column.', () async {
            final updatedEntriesHlc = <Hlc>[];
            for (final entry in allCrdtDataEntries.where(
              (entry) => entry.rowId == rowId,
            )) {
              final columnName = await CrdtTestHelper.getColumnName(crdtDb, entry);
              if (updatedColumnNames.contains(columnName)) {
                final hlc = await CrdtTestHelper.getHlc(crdtDb, entry);
                updatedEntriesHlc.add(hlc);
              }
            }

            expect(updatedEntriesHlc.toSet(), hasLength(1));
          });

          test('has the updated HLC timestamp greater than the created.', () async {
            final updatedEntry = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              'content',
            );
            final updatedHlc = await CrdtTestHelper.getHlc(crdtDb, updatedEntry);
            expect(updatedHlc, greaterThan(createdHlc));
          });

          test('has not changed the HLC timestamp for non-updated columns.', () async {
            final otherEntriesHlc = <Hlc>[];
            for (final entry in allCrdtDataEntries.where(
              (entry) => entry.rowId == rowId,
            )) {
              final columnName = await CrdtTestHelper.getColumnName(crdtDb, entry);
              if (!updatedColumnNames.contains(columnName)) {
                final hlc = await CrdtTestHelper.getHlc(crdtDb, entry);
                otherEntriesHlc.add(hlc);
              }
            }

            expect(otherEntriesHlc, everyElement(equals(createdHlc)));
          });
        },
      );
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

      group(
        'then the trigger is executed and the updated row in the CRDT data table',
        () {
          late List<CrdtDataEntry> allCrdtDataEntries;
          late CrdtDatabase crdtDb;

          setUp(() async {
            final migrator = database.createMigrator();
            crdtDb = migrator.crdtDb;
            allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
          });

          test('has not changed the HLC timestamp for the updated column.', () async {
            final updatedEntry = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              'content',
            );
            final updatedHlc = await CrdtTestHelper.getHlc(crdtDb, updatedEntry);
            expect(updatedHlc, equals(createdHlc));
          });
        },
      );
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

      group(
        'then the trigger is executed and the deleted row in the CRDT data table',
        () {
          late List<CrdtDataEntry> allCrdtDataEntries;
          late String isDeletedColumnName;
          late CrdtDatabase crdtDb;

          setUp(() async {
            final migrator = database.createMigrator();
            crdtDb = migrator.crdtDb;
            allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
            isDeletedColumnName = crdtDb.sqlBuilder.isDeletedColumnName;
          });

          test('has the deleted flag column set to true.', () async {
            final crdtData = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              isDeletedColumnName,
            );
            expect(crdtData.unwrappedValue, 1);
          });

          test('has the deleted HLC timestamp greater than the created.', () async {
            final deletedEntry = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              isDeletedColumnName,
            );
            final deletedHlc = await CrdtTestHelper.getHlc(crdtDb, deletedEntry);
            expect(deletedHlc, greaterThan(createdHlc));
          });
        },
      );
    });
  });

  group('Given a database with a previously deleted row from a synchronized table', () {
    const initialContent = 'test';
    late String isDeletedColumnName;
    late int createdRowId;
    late Hlc deletedHlc;
    late String rowId;

    setUp(() async {
      createdRowId = await database.managers.todosTable.create(
        (t) => t(content: initialContent),
      );
      rowId = createdRowId.toString();

      final migrator = database.createMigrator();

      final deleted = await database.managers.todosTable
          .filter((t) => t.id.equals(RowId(createdRowId)))
          .delete();
      expect(deleted, equals(1));

      final allCrdtDataEntries = await migrator.crdtDb.managers.crdtDataTable.get();
      isDeletedColumnName = migrator.crdtDb.sqlBuilder.isDeletedColumnName;
      deletedHlc = await CrdtTestHelper.getHlc(
        migrator.crdtDb,
        await allCrdtDataEntries.getFieldAsync(
          migrator.crdtDb,
          rowId,
          isDeletedColumnName,
        ),
      );
    });

    group('when re-inserting the previously deleted row', () {
      setUp(() async {
        await database.managers.todosTable.create(
          (t) => t(
            id: Value(RowId(createdRowId)),
            content: initialContent,
          ),
        );
      });

      test(
        'then the row has been re-inserted in the target table with the same data.',
        () async {
          final row = await database.managers.todosTable.getSingle();

          expect(row, isNotNull);
          expect(row.id, equals(createdRowId));
          expect(row.content, initialContent);
        },
      );

      group(
        'then the trigger is executed and the re-inserted row in the CRDT data table',
        () {
          late List<CrdtDataEntry> allCrdtDataEntries;
          late CrdtDatabase crdtDb;

          setUp(() async {
            final migrator = database.createMigrator();
            crdtDb = migrator.crdtDb;
            allCrdtDataEntries = await crdtDb.managers.crdtDataTable.get();
            isDeletedColumnName = crdtDb.sqlBuilder.isDeletedColumnName;
          });

          test('has the deleted flag column set to false.', () async {
            final crdtData = await allCrdtDataEntries.getFieldAsync(
              crdtDb,
              rowId,
              isDeletedColumnName,
            );
            expect(crdtData.unwrappedValue, 0);
          });

          test(
            'has the deleted flag HLC timestamp greater than the deleted.',
            () async {
              final deletedEntry = await allCrdtDataEntries.getFieldAsync(
                crdtDb,
                rowId,
                isDeletedColumnName,
              );
              final deletedEntryHlc = await CrdtTestHelper.getHlc(crdtDb, deletedEntry);
              expect(deletedEntryHlc, greaterThan(deletedHlc));
            },
          );

          test(
            'has the HLC timestamp updated for newly inserted columns.',
            () async {
              final hlcs = await Future.wait(
                allCrdtDataEntries.map((e) => CrdtTestHelper.getHlc(crdtDb, e)),
              );
              expect(
                hlcs,
                everyElement(greaterThan(deletedHlc)),
              );
            },
          );
        },
      );
    });
  });
}

extension on Iterable<CrdtDataEntry> {
  Future<CrdtDataEntry> getFieldAsync(
    CrdtDatabase db,
    String rowId,
    String fieldName,
  ) async {
    for (final entry in this) {
      if (entry.rowId == rowId) {
        final columnName = await CrdtTestHelper.getColumnName(db, entry);
        if (columnName == fieldName) {
          return entry;
        }
      }
    }
    throw StateError('No entry found for rowId=$rowId, fieldName=$fieldName');
  }
}

extension on DateTime {
  String toIso8600StringWithOffset() {
    final offset = toLocal().timeZoneOffset.inHours;
    final sign = offset >= 0 ? '+' : '-';
    return '${toIso8601String()} $sign${offset.abs().toString().padLeft(2, '0')}:00';
  }
}
