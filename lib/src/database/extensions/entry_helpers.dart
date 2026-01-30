import 'package:crdt/crdt.dart';

import '../hlc/normalized.dart';
import 'database.dart';

/// Extension methods for working with normalized CrdtDataEntry.
///
/// These extensions provide convenient methods to reconstruct denormalized
/// data (like full HLC, table names, column names) from the normalized
/// integer references in CrdtDataEntry.
extension CrdtDataEntryHelpers on CrdtDataEntry {
  /// Reconstructs the full HLC from normalized components.
  ///
  /// Requires the database to look up the node ID string from the normalized ID.
  Future<Hlc> getHlc(CrdtDatabase db) async {
    // Query the node ID string
    final node = await (db.select(db.crdtNodesTable)
          ..where((t) => t.id.equals(hlcNodeId)))
        .getSingle();

    return NormalizedHlc.reconstruct(
      datetime: hlcDatetime,
      counter: hlcCounter,
      nodeId: node.nodeId,
    );
  }

  /// Gets the table name from the normalized table ID.
  ///
  /// Requires the database to look up the table name.
  Future<String> getTableName(CrdtDatabase db) async {
    final table = await (db.select(db.crdtSchemaTablesTable)
          ..where((t) => t.id.equals(tableId)))
        .getSingle();
    return table.tblName;
  }

  /// Gets the column name from the normalized column ID.
  ///
  /// Requires the database to look up the column name.
  Future<String> getColumnName(CrdtDatabase db) async {
    final column = await (db.select(db.crdtSchemaColumnsTable)
          ..where((t) => t.id.equals(columnId)))
        .getSingle();
    return column.columnName;
  }
}

/// Extension methods for collections of CrdtDataEntry.
extension CrdtDataEntryCollectionHelpers on Iterable<CrdtDataEntry> {
  /// Gets the set of affected table IDs.
  Iterable<int> get affectedTableIds => map((e) => e.tableId).toSet();

  /// Gets the set of affected row IDs.
  Iterable<String> get affectedRowIds => map((e) => e.rowId).toSet();

  /// Filters entries for a specific table ID.
  Iterable<CrdtDataEntry> forTableId(int tableId) =>
      where((e) => e.tableId == tableId);

  /// Creates a copy of all entries with updated HLC components.
  Iterable<CrdtDataEntry> withHlc({
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
