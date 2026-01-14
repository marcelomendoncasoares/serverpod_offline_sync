import 'package:crdt/crdt.dart';

import 'database.dart';

/// Extension method to provide conversion utilities to [CrdtDataEntry] lists.
extension CrdtDataEntryListToChangesetExtension on List<CrdtDataEntry> {
  /// Converts a list of [CrdtDataEntry] to a [CrdtChangeset].
  CrdtChangeset toChangeset() {
    final changeset = CrdtChangeset();
    forEach(changeset.add);
    return changeset;
  }
}

/// Extension method to provide conversion utilities to [CrdtChangeset] objects.
extension CrdtChangesetExtension on CrdtChangeset {
  /// Adds a [CrdtDataEntry] to the [CrdtChangeset].
  void add(CrdtDataEntry entry) {
    final record = entry.toChangesetRecord();
    if (containsKey(entry.tblName)) {
      this[entry.tblName]!.add(record);
    } else {
      this[entry.tblName] = [record];
    }
  }

  /// Converts a [CrdtChangeset] to a list of [CrdtDataEntry].
  List<CrdtDataEntry> toCrdtDataEntries() => [
        for (final tableEntries in entries)
          for (final rowColumnValue in tableEntries.value)
            CrdtDataEntry.fromJson(rowColumnValue),
      ];
}

/// Extension method to provide conversion utilities to [CrdtDataEntry] objects.
extension CrdtDataEntryExtension on CrdtDataEntry {
  /// Returns the primary key for the [CrdtDataEntry] to be used in a [CrdtChangeset].
  String get changesetPrimaryKey => '${tblName}_${columnName}_$rowId';

  /// Converts a [CrdtDataEntry] to a record to be used in a [CrdtChangeset].
  Map<String, dynamic> toChangesetRecord() => {changesetPrimaryKey: toJson()};
}
