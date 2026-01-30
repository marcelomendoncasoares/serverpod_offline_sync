import 'package:crdt/crdt.dart';
import 'package:drift/drift.dart';

import '../../hlc/normalized.dart';
import '../../utils/sql_builder.dart';
import '../database.dart';
import 'transactions.dart';

/// Extensions for [CrdtDatabase] to sync data to the target tables.
extension CrdtDatabaseSyncExtensions on CrdtDatabase {
  /// Upserts rows in the target table from the CRDT data table.
  ///
  /// This is the inverse operation of what CRDT triggers do. It reads from the
  /// CRDT data table and reconstructs rows to insert/update in the target table.
  /// Handles deletions and fields that are not changed in the filter criteria.
  ///
  /// Parameters:
  /// - [rowIdsPerTable]: Map of table names to row IDs to sync. If not provided,
  ///   all tables will be synchronized. Passing null for a table will synchronize
  ///   all rows in that table.
  /// - [sinceHlc]: Optional HLC timestamp to filter by. The filter is inclusive,
  ///   meaning that rows with the exact same HLC timestamp will also be included.
  Future<void> syncCrdtDataToTables({
    Map<String, Iterable<String>?>? rowIdsPerTable,
    Hlc? sinceHlc,
  }) async {
    return transactionWithDeferredConstraints(() async {
      final tableNames = rowIdsPerTable?.keys ?? synchronizedTables.tableNames;
      for (final tableName in tableNames) {
        await _syncCrdtDataToTable(
          tableName: tableName,
          rowIds: rowIdsPerTable?[tableName],
          sinceHlc: sinceHlc,
        );
      }
    });
  }

  /// Syncs the CRDT data to the target table.
  ///
  /// Must be called within a transaction with deferred constraints to ensure that
  /// the foreign key constraints are not violated. The transaction is not created
  /// by this method to allow grouping multiple table syncs into one transaction
  /// to avoid nested transactions.
  Future<void> _syncCrdtDataToTable({
    required String tableName,
    Iterable<String>? rowIds,
    Hlc? sinceHlc,
  }) async {
    final deleteSql = _getDeleteFromCrdtDataSql(
      tableName: tableName,
      rowIds: rowIds,
      sinceHlc: sinceHlc,
    );

    final upsertSql = _getSaveFromCrdtDataSql(
      tableName: tableName,
      rowIds: rowIds,
      sinceHlc: sinceHlc,
    );

    await customStatement(deleteSql);
    await customStatement(upsertSql);
  }

  /// Generates the SQL to delete rows in the target table from the CRDT data table.
  String _getDeleteFromCrdtDataSql({
    required String tableName,
    Iterable<String>? rowIds,
    Hlc? sinceHlc,
  }) {
    return '''
    DELETE FROM "$tableName"
    WHERE ${_getWhereClause(tableName, rowIds, sinceHlc, isDeleted: true)};''';
  }

  // TODO: Unify this with the SQL for the CRDT triggers.
  /// Generates SQL to upsert rows in the target table from the CRDT data table.
  String _getSaveFromCrdtDataSql({
    required String tableName,
    Iterable<String>? rowIds,
    Hlc? sinceHlc,
  }) {
    final tableInfo = synchronizedTables.find(tableName);
    final tableId = schemaCache.getTableId(tableName);

    final columnSelects = tableInfo.nonGenerated.map((column) {
      final columnId = schemaCache.getColumnId(tableId, column);
      final whereClause = 'WHERE c."column_id" = $columnId';
      return 'MAX(c."raw_value") FILTER ($whereClause) AS "$column"';
    });

    final updateSets = tableInfo.nonPrimaryKeyColumns.map((column) {
      final newField = 'EXCLUDED."$column"';
      final originalField = '"$tableName"."$column"';
      return '"$column" = COALESCE($newField, $originalField)';
    });

    final onConflict = updateSets.isEmpty
        ? 'DO NOTHING'
        : 'DO UPDATE\nSET ${updateSets.join(',\n    ')}';

    return '''
INSERT INTO "$tableName" (
  ${tableInfo.nonGenerated.map((c) => '"$c"').join(', ')}
)
SELECT ${columnSelects.join(',\n       ')}
FROM ${sqlBuilder.crdtDataTableName} AS c
WHERE ${_getWhereClause(tableName, rowIds, sinceHlc)}
GROUP BY c."row_id"
ON CONFLICT (${tableInfo.$primaryKey.quotedNames.join(', ')})
$onConflict;''';
  }

  String _getWhereClause(
    String tableName,
    Iterable<String>? rowIds,
    Hlc? sinceHlc, {
    bool isDeleted = false,
  }) {
    final tableId = schemaCache.getTableId(tableName);
    final isDeletedColumnId = schemaCache.getColumnId(
      tableId,
      sqlBuilder.isDeletedColumnName,
    );

    final whereConditions = <String>[
      '"user_id" = \'$userId\'',
      '"table_id" = $tableId',
      if (rowIds != null && rowIds.isNotEmpty)
        'row_id IN (${rowIds.map((id) => "'$id'").join(', ')})',
    ];

    // HLC comparison using tuple: (datetime, counter, node_id)
    if (sinceHlc != null) {
      final hlcDatetime = NormalizedHlc.extractDatetime(sinceHlc);
      final hlcCounter = NormalizedHlc.extractCounter(sinceHlc);
      whereConditions.add(
        '("hlc_datetime", "hlc_counter", "hlc_node_id") >= ($hlcDatetime, $hlcCounter, 0)',
      );
    }

    if (isDeleted) {
      whereConditions.add('"column_id" = $isDeletedColumnId AND "raw_value" = 1');
    }

    return whereConditions.join(' AND ');
  }
}

extension on TableInfo {
  Iterable<String> get nonGenerated =>
      $columns.where((c) => c.generatedAs == null).map((c) => c.$name);

  Iterable<String> get nonPrimaryKeyColumns =>
      nonGenerated.where((c) => !$primaryKey.map((p) => p.$name).contains(c));
}
