import 'package:drift_offline_sync/drift_offline_sync.dart';

extension CrdtDataEntryListExtensions on List<CrdtDataEntry> {
  CrdtDataEntry removeEntry(String columnName) {
    final entry = firstWhere((e) => e.columnName == columnName);
    remove(entry);
    return entry;
  }
}

/// Test helpers for CRDT tests.
///
/// Use [sortedEntries] when comparing [CrdtDataEntry] lists, since entry order
/// is not guaranteed by the API or database.
extension CrdtDataEntryTestExtensions on Iterable<CrdtDataEntry> {
  /// Returns a list of entries sorted by (tblName, rowId, columnName) for
  /// order-independent comparison in tests.
  List<CrdtDataEntry> get sortedEntries {
    return toList()..sort((a, b) {
      final c = a.tblName.compareTo(b.tblName);
      if (c != 0) return c;
      final r = a.rowId.compareTo(b.rowId);
      if (r != 0) return r;
      return a.columnName.compareTo(b.columnName);
    });
  }
}
