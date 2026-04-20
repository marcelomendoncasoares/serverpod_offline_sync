import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';

/// Manages the CRDT schema for a database.
class CrdtSchemaRegistry {
  /// Creates a new instance of [CrdtSchemaRegistry].
  CrdtSchemaRegistry(this._session, {required this.syncTables}) {
    final tablesWithoutUuidPk = syncTables.where(
      (table) => table.id is! Column<UuidValue>,
    );
    if (tablesWithoutUuidPk.isNotEmpty) {
      throw StateError(
        'CRDT can only synchronize tables with a UUID primary key, but '
        '${tablesWithoutUuidPk.length} table(s) do not have a UUID primary key: '
        '${tablesWithoutUuidPk.map((t) => '"${t.tableName}"').join(', ')}',
      );
    }
  }

  final DatabaseSession _session;

  /// The list of tables to sync with CRDT.
  final List<Table> syncTables;

  late final _columnsPerTableName = {
    for (final table in syncTables)
      table.tableName: [
        for (final column in table.columns) column.columnName,
      ],
  };

  /// Ensures that the CRDT schema is created for the database.
  Future<(List<CrdtSchemaTable>, List<CrdtSchemaColumn>)> syncAndGetSchema() async {
    return _session.db.transaction((transaction) async {
      final tableRows = await _syncTableSchemas(transaction);
      final columnRows = await _syncColumnSchemas(tableRows, transaction);
      return (tableRows, columnRows);
    });
  }

  /// Syncs the table schemas to the database.
  ///
  /// New tables are inserted and no longer present tables are deleted. Table
  /// renames are not taken into account. The returned list contains the
  /// [CrdtSchemaTable]s with their IDs.
  Future<List<CrdtSchemaTable>> _syncTableSchemas(Transaction transaction) async {
    await CrdtSchemaTable.db.insert(
      _session,
      _columnsPerTableName.keys.map((name) => CrdtSchemaTable(name: name)).toList(),
      transaction: transaction,
      ignoreConflicts: true,
    );

    final foundTableRows = await CrdtSchemaTable.db.find(
      _session,
      transaction: transaction,
    );

    final deletedTableRows = [
      for (final (ix, table) in foundTableRows.indexed.toList().reversed)
        if (!_columnsPerTableName.containsKey(table.name)) foundTableRows.removeAt(ix),
    ];

    await CrdtSchemaTable.db.delete(
      _session,
      deletedTableRows,
      transaction: transaction,
    );

    return foundTableRows;
  }

  /// Syncs the column schemas to the database.
  ///
  /// New columns are inserted and no longer present columns are deleted. Column
  /// renames are not taken into account yet. The returned list contains the
  /// [CrdtSchemaColumn]s with their IDs.
  Future<List<CrdtSchemaColumn>> _syncColumnSchemas(
    List<CrdtSchemaTable> tableRows,
    Transaction transaction,
  ) async {
    await CrdtSchemaColumn.db.insert(
      _session,
      [
        for (final table in tableRows)
          for (final column in _columnsPerTableName[table.name]!)
            CrdtSchemaColumn(tblId: table.id!, name: column),
      ],
      transaction: transaction,
      ignoreConflicts: true,
    );

    final columnsPerTableId = {
      for (final tableRow in tableRows)
        tableRow.id!: _columnsPerTableName[tableRow.name]!,
    };

    final foundColumnRows = await CrdtSchemaColumn.db.find(
      _session,
      transaction: transaction,
    );

    final deletedColumnRows = [
      for (final (ix, column) in foundColumnRows.indexed.toList().reversed)
        if (!columnsPerTableId.containsKey(column.tblId) ||
            !columnsPerTableId[column.tblId]!.contains(column.name))
          foundColumnRows.removeAt(ix),
    ];

    await CrdtSchemaColumn.db.delete(
      _session,
      deletedColumnRows,
      transaction: transaction,
    );

    return foundColumnRows;
  }
}
