import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';
import '../utils/tables.dart';

void main() {
  group('Given a data object with every column type', () {
    late CrdtDatabase crdtDb;
    late TableWithEveryColumnTypeData createdData;
    late Hlc testHlc;

    setUp(() async {
      createdData = TableWithEveryColumnTypeData(
        id: const RowId(1),
        aBool: true,
        aDateTime: DateTime.now(),
        aText: 'test',
        anInt: 1,
        anInt64: BigInt.one,
        aReal: 1.0,
        aBlob: Uint8List.fromList([1, 2, 3]),
        anIntEnum: TodoStatus.open,
        aTextWithConverter: MyCustomObject('test'),
        aUuid: UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000'),
      );

      (_, crdtDb, _) = database.crdtContext;
      testHlc = Hlc.now(crdtDb.nodeId);
    });

    group('when converting the data to CRDT data entries', () {
      late Iterable<CrdtDataEntry> entries;

      setUp(() async {
        entries = createdData.toCrdtDataEntry(crdtDb, testHlc).toList();
      });

      test('then it creates an entry for each column.', () async {
        expect(
          entries.map((e) => e.columnName).toSet(),
          equals(
            database.tableWithEveryColumnType.$columns.map((c) => c.$name).toSet(),
          ),
        );
      });

      test('then each entry has the correct user ID.', () async {
        expect(entries.map((e) => e.userId), everyElement(equals(crdtDb.userId)));
      });

      test('then each entry has the correct table name.', () async {
        expect(
          entries.map((e) => e.tblName),
          everyElement(equals('table_with_every_column_type')),
        );
      });

      test('then each entry has the correct HLC timestamp.', () async {
        expect(entries.map((e) => e.hlcTimestamp), everyElement(equals(testHlc)));
      });

      test('then all entries have expected column names and values.', () async {
        final entriesMap = {
          for (final entry in entries) entry.columnName: entry.rawValue,
        };

        expect(entriesMap['a_bool'], equals(createdData.aBool?.driftAny));
        expect(entriesMap['a_date_time'], isNotNull);
        expect(entriesMap['a_text'], equals(createdData.aText?.driftAny));
        expect(entriesMap['an_int'], equals(createdData.anInt?.driftAny));
        expect(entriesMap['an_int64'], equals(createdData.anInt64?.driftAny));
        expect(entriesMap['a_real'], equals(createdData.aReal?.driftAny));
        expect(entriesMap['a_blob'], equals(createdData.aBlob?.driftAny));
        expect(
          entriesMap['an_int_enum'],
          equals(createdData.anIntEnum?.index.driftAny),
        );
        expect(
          // aTextWithConverter uses 'insert' as column name
          entriesMap['insert']?.rawSqlValue,
          equals(const DriftAny({'data': 'test'}).rawSqlValue),
        );
        expect(entriesMap['a_uuid'], createdData.aUuid?.driftAny);
      });
    });
  });
}

extension on Object {
  DriftAny? get driftAny => DriftAny(this);
}
