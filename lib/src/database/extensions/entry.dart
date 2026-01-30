import '../database.dart';

/// Extensions for the [CrdtDataEntry] class.
extension CrdtDataEntryUnwrapExtensions on CrdtDataEntry {
  /// Returns the unwrapped raw value, if any.
  Object? get unwrappedValue => rawValue?.rawSqlValue;
}

/// Extensions for an [Iterable] of [CrdtDataEntry].
extension CrdtDataEntryExtensions on Iterable<CrdtDataEntry> {
  /// Gets the affected table IDs (normalized).
  Iterable<int> get affectedTableIds => map((e) => e.tableId).toSet();

  /// Gets the affected row IDs.
  Iterable<String> get affectedRowIds => map((e) => e.rowId).toSet();

  /// Gets the entries for a given table ID.
  Iterable<CrdtDataEntry> forTableId(int tableId) =>
      where((e) => e.tableId == tableId);

  /// Gets the entries for a given table name (requires schema cache).
  Iterable<CrdtDataEntry> forTable(String tableName, CrdtDatabase db) {
    final tableId = db.schemaCache.getTableId(tableName);
    return forTableId(tableId);
  }

  /// Returns the entries with the HLC components replaced.
  Iterable<CrdtDataEntry> withHlcComponents({
    required int datetime,
    required int counter,
    required int nodeId,
  }) =>
      map((e) => e.copyWith(
            hlcDatetime: datetime,
            hlcCounter: counter,
            hlcNodeId: nodeId,
          ));
}

