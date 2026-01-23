import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift_offline_first/drift_offline_first.dart';
import 'package:test/test.dart';

import '../utils/crdt_context.dart';
import '../utils/database.dart';
import '../utils/tables.dart';

void main() {
  group('Given CRDT database for a database with data with every column type', () {
    late CrdtDatabase crdtDb;
    late String rowId;
    late TableWithEveryColumnTypeData createdData;

    setUp(() async {
      final createdRowId = await database.managers.tableWithEveryColumnType.create(
        (t) => t(
          aBool: const Value(true),
          aDateTime: Value(DateTime.now()),
          aText: const Value('test'),
          anInt: const Value(1),
          anInt64: Value(BigInt.one),
          aReal: const Value(1.0),
          aBlob: Value(Uint8List.fromList([1, 2, 3])),
          anIntEnum: const Value(TodoStatus.open),
          aTextWithConverter: Value(MyCustomObject('test')),
          aUuid: Value(UuidValue.fromString('123e4567-e89b-12d3-a456-426614174000')),
        ),
      );

      (_, crdtDb, _) = database.crdtContext;
      rowId = createdRowId.toString();
      createdData = await database.managers.tableWithEveryColumnType.getSingle();
    });

    test(
        'when getting the data from the CRDT data table of the CRDT database '
        'then it rebuilds the data perfectly.', () async {
      final data = await crdtDb.getSingleFromCrdtData<TableWithEveryColumnType,
          TableWithEveryColumnTypeData>(rowId);

      expect(data, equals(createdData));
    });

    test(
        'when trying to get the data from the CRDT data table with a non-existent row id '
        'then it returns null.', () async {
      final data = await crdtDb.getSingleFromCrdtData<TableWithEveryColumnType,
          TableWithEveryColumnTypeData>('non-existent-row-id');

      expect(data, isNull);
    });

    test(
        'when trying to get the data from the CRDT data table with multiple row ids '
        'then it returns the data for the existing row ids.', () async {
      final data = await crdtDb
          .getFromCrdtData<TableWithEveryColumnType, TableWithEveryColumnTypeData>(
        [rowId, 'non-existent-row-id'],
      );

      expect(data, equals([createdData]));
    });

    test(
        'when trying to get the data from the CRDT data table for a non-synchronized table '
        'then it throws an error.', () async {
      expect(
        () => crdtDb.getFromCrdtData<TableWithoutPK, TableWithEveryColumnTypeData>(
          [rowId],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
