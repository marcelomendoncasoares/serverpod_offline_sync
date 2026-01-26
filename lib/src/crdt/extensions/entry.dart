import '../../database.dart';
import '../../hlc/converter.dart';

/// Extensions for the [CrdtDataEntry] class.
extension CrdtDataEntryUnwrapExtensions on CrdtDataEntry {
  /// Returns the unwrapped raw value, if any.
  Object? get unwrappedValue => rawValue?.rawSqlValue;
}

/// Extensions for an [Iterable] of [CrdtDataEntry].
extension CrdtDataEntryExtensions on Iterable<CrdtDataEntry> {
  /// Gets the affected tables.
  Iterable<String> get affectedTables => map((e) => e.tblName).toSet();

  /// Gets the affected row IDs.
  Iterable<String> get affectedRowIds => map((e) => e.rowId).toSet();

  /// Gets the entries for a given table.
  Iterable<CrdtDataEntry> forTable(String tableName) =>
      where((e) => e.tblName == tableName);

  /// Returns the entries with the HLC replaced by the [hlcTimestamp].
  Iterable<CrdtDataEntry> withHlc(Hlc hlcTimestamp) =>
      map((e) => e.copyWith(hlcTimestamp: hlcTimestamp));
}
