import 'package:drift/drift.dart';

import '../../database.dart';
import '../../hlc/converter.dart';

/// Extensions for [Iterable<CrdtDataEntry>] to get the affected tables and row IDs.
extension CrdtDataEntryExtensions on Iterable<CrdtDataEntry> {
  /// Gets the affected tables.
  Iterable<String> get affectedTables => map((e) => e.tblName).toSet();

  /// Gets the affected row IDs.
  Iterable<String> get affectedRowIds => map((e) => e.rowId).toSet();

  /// Gets the entries for a given table.
  Iterable<CrdtDataEntry> forTable(String tableName) =>
      where((e) => e.tblName == tableName);
}

/// Extensions to convert Drift [Insertable] objects to [CrdtDataEntry].
extension CrdtDataEntryConversion<T extends DataClass> on Insertable<T> {
  /// Converts the [Insertable] object to a list of [CrdtDataEntry].
  ///
  /// Note that the generated entries will have the same HLC timestamp for all
  /// columns and will overwrite individual column updates if newer. The
  /// [database] parameter is required to find the table information to map
  /// the columns.
  ///
  /// Returns a list of [CrdtDataEntry].
  Iterable<CrdtDataEntry> toCrdtDataEntry(CrdtDatabase database, Hlc hlcTimestamp) {
    final json = (this as DataClass).toJson();

    final tableInfo =
        database.synchronizedTables.whereType<TableInfo<dynamic, T>>().single;

    final rowId = [
      for (final c in tableInfo.$primaryKey) json[c.$name],
    ].join(database.sqlBuilder.rowIdSeparator);

    return tableInfo.$columns.map(
      (c) => CrdtDataEntry(
        userId: database.userId,
        tblName: tableInfo.actualTableName,
        columnName: c.$name,
        rowId: rowId,
        rawValue: (json[c.$name] as Object?)?.toDriftAny(),
        hlcTimestamp: hlcTimestamp,
      ),
    );
  }
}

extension on Object {
  DriftAny? toDriftAny() => DriftAny(this);
}
