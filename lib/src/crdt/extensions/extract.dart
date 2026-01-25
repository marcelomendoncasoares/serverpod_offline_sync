import 'package:drift/drift.dart';

import '../../database.dart';

/// Extensions for [CrdtDatabase] to extract data from the CRDT data table.
extension CrdtDatabaseExtractExtensions on CrdtDatabase {
  /// Gets a single data entry from the CRDT data table.
  Future<T?> getSingleFromCrdtData<T extends Insertable>({
    required String tableName,
    required String rowId,
  }) async {
    final data = await getFromCrdtData<T>(tableName: tableName, rowIds: [rowId]);
    return data.firstOrNull;
  }

  /// Gets a list of data entries from the CRDT data table.
  Future<List<T>> getFromCrdtData<T extends Insertable>({
    required String tableName,
    required Iterable<String> rowIds,
  }) async {
    final tableInfo = synchronizedTables.find(tableName);
    final crdtDataEntries = await managers.crdtDataTable
        .filter((o) => o.tblName.equals(tableName) & o.rowId.isIn(rowIds))
        .get();

    return crdtDataEntries.convert<T>(tableInfo);
  }
}

extension on List<CrdtDataEntry> {
  Future<List<T>> convert<T extends Insertable>(TableInfo tableInfo) async {
    final foundRowIds = map((e) => e.rowId).toSet();
    return [
      for (final rowId in foundRowIds)
        await tableInfo.map({
          for (final c in tableInfo.$columns)
            c.$name: firstWhere((e) => e.rowId == rowId && e.columnName == c.$name)
                .rawValue
                ?.rawSqlValue,
        }) as T,
    ];
  }
}
