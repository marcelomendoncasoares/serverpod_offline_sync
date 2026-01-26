import 'package:drift/drift.dart';

import '../../database.dart';

/// Extensions for [CrdtDatabase] to extract data from the CRDT data table.
extension CrdtDatabaseExtractExtensions on CrdtDatabase {
  /// Gets a single data entry from the CRDT data table.
  Future<T?> getSingleFromCrdtData<T extends Insertable>(String rowId) async {
    final data = await getFromCrdtData<T>([rowId]);
    return data.firstOrNull;
  }

  /// Gets a list of data entries from the CRDT data table.
  Future<Iterable<T>> getFromCrdtData<T extends Insertable>([
    Iterable<String>? rowIds,
  ]) async {
    final tableInfo = synchronizedTables.find<T>();
    final tableName = tableInfo.actualTableName;
    final crdtDataEntries = await managers.crdtDataTable.filter(
      (o) {
        var condition = o.tblName.equals(tableName);
        if (rowIds != null) {
          condition &= o.rowId.isIn(rowIds);
        }
        return condition;
      },
    ).get();

    return tableInfo.fromCrdtDataEntries<T>(crdtDataEntries);
  }
}

/// Extensions for [TableInfo] to convert [CrdtDataEntry] to [Insertable].
extension ConvertCrdtDataEntry on TableInfo {
  /// Converts [CrdtDataEntry] to [Insertable].
  Future<Iterable<T>> fromCrdtDataEntries<T extends Insertable>(
    Iterable<CrdtDataEntry> entries,
  ) async {
    final foundRowIds = entries.map((e) => e.rowId).toSet();
    return [
      for (final rowId in foundRowIds)
        await map({
          for (final c in $columns)
            c.$name: entries
                .firstWhere((e) => e.rowId == rowId && e.columnName == c.$name)
                .rawValue
                ?.rawSqlValue,
        }) as T,
    ];
  }
}
