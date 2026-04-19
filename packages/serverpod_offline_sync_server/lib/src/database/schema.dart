import 'package:serverpod/protocol.dart';

import '../generated/protocol.dart';
import 'upsert.dart';

/// Manages the CRDT schema for a database.
class CrdtSchema {
  /// Creates a new instance of [CrdtSchema].
  CrdtSchema(this._session, this._syncTables);

  final DatabaseSession _session;
  final List<TableDefinition> _syncTables;

  late final _syncTableNames = _syncTables.map((table) => table.name).toSet();

  late final _currentTables = _session.db.serializationManager
      .getTargetTableDefinitions()
      .where((table) => _syncTableNames.isEmpty || _syncTableNames.contains(table.name))
      .toMap();

  /// Ensures that the CRDT schema is created for the database.
  Future<(List<CrdtSchemaTable>, List<CrdtSchemaColumn>)> ensureCreated() async {
    return _session.db.transaction((transaction) async {
      final tableRows = await _session.db.upsert(
        _currentTables.keys.map((name) => CrdtSchemaTable(name: name)),
        transaction: transaction,
      );

      final columnRows = await _session.db.upsert(
        [
          for (final table in tableRows)
            for (final column in _currentTables[table.name]!)
              CrdtSchemaColumn(tblId: table.id!, name: column.name),
        ],
        transaction: transaction,
      );

      return (tableRows, columnRows);
    });
  }
}

extension on Iterable<TableDefinition> {
  Map<String, List<ColumnDefinition>> toMap() {
    return {
      for (final table in this) table.name: table.columns,
    };
  }
}
