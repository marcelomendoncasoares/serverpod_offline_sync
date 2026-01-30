import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import '../../lib/src/database/database.dart';
import '../../lib/src/hlc/normalized.dart';

/// Test utilities for creating normalized CrdtDataEntry objects.
///
/// Since the schema has been normalized, creating test data requires
/// proper table/column/node IDs. This utility class helps create
/// test entries with proper normalized references.
class CrdtTestHelper {
  /// Creates a CrdtDataEntry with the provided values, using normalized IDs.
  ///
  /// Requires the database to look up table/column/node IDs from the schema cache.
  static CrdtDataEntry createEntry({
    required CrdtDatabase db,
    required String userId,
    required String tableName,
    required String columnName,
    required String rowId,
    required Hlc hlc,
    Object? rawValue,
  }) {
    final tableId = db.schemaCache.getTableId(tableName);
    final columnId = db.schemaCache.getColumnId(tableId, columnName);
    final nodeId = db.schemaCache.getNodeId(hlc.nodeId);

    return CrdtDataEntry(
      userId: userId,
      tableId: tableId,
      columnId: columnId,
      rowId: rowId,
      hlcDatetime: NormalizedHlc.extractDatetime(hlc),
      hlcCounter: NormalizedHlc.extractCounter(hlc),
      hlcNodeId: nodeId,
      rawValue: rawValue != null ? DriftAny(rawValue) : null,
    );
  }

  /// Gets the table name from a CrdtDataEntry (requires database lookup).
  static Future<String> getTableName(CrdtDatabase db, CrdtDataEntry entry) async {
    final table = await (db.select(db.crdtSchemaTablesTable)
          ..where((t) => t.id.equals(entry.tableId)))
        .getSingle();
    return table.tblName;
  }

  /// Gets the column name from a CrdtDataEntry (requires database lookup).
  static Future<String> getColumnName(CrdtDatabase db, CrdtDataEntry entry) async {
    final column = await (db.select(db.crdtSchemaColumnsTable)
          ..where((t) => t.id.equals(entry.columnId)))
        .getSingle();
    return column.columnName;
  }

  /// Reconstructs the HLC from a CrdtDataEntry (requires database lookup).
  static Future<Hlc> getHlc(CrdtDatabase db, CrdtDataEntry entry) async {
    final node = await (db.select(db.crdtNodesTable)
          ..where((t) => t.id.equals(entry.hlcNodeId)))
        .getSingle();

    return NormalizedHlc.reconstruct(
      datetime: entry.hlcDatetime,
      counter: entry.hlcCounter,
      nodeId: node.nodeId,
    );
  }
}
