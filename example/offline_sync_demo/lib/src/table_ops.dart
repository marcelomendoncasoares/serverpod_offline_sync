import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Table, TableRow;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show IncludeTombstonedRows;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

/// Generic, table-name keyed CRUD over the generated Serverpod models.
///
/// Each entry only needs its row type: the table name, the [Table] metadata, and
/// every operation are derived from `<T>` via `Protocol().getTableForType` and
/// the `session.db.<op><T>(...)` generics. All values cross the boundary as JSON
/// maps (the `toJson()` shape), keeping the rest of the demo free of model types.
///
/// Note: the per-type list below is irreducible — Dart cannot turn a runtime
/// [Table] into the compile-time `T` that `session.db.find<T>` requires — so the
/// types are listed once here and [demoSyncTables] is derived from them.
class TableOps {
  TableOps({
    required this.table,
    required this.findAll,
    required this.findByIdJson,
    required this.insertJson,
    required this.updateJson,
    required this.deleteById,
  });

  /// The generated table metadata for this row type.
  final Table table;

  /// Database table name, e.g. `person`.
  String get name => table.tableName;

  /// Every row in the table, as JSON, read through [session]. When
  /// [includeHidden] is true, CRDT-tombstoned (soft-deleted) rows are returned
  /// too, via the `t.includeHiddenRows` where-clause expression.
  final Future<List<Map<String, dynamic>>> Function(
    DatabaseSession session, {
    bool includeHidden,
  })
  findAll;

  /// A single visible row by id, or null, as JSON.
  final Future<Map<String, dynamic>?> Function(
    DatabaseSession session,
    UuidValue id,
  )
  findByIdJson;

  /// Inserts a row built from [json].
  final Future<void> Function(DatabaseSession session, Map<String, dynamic> json)
  insertJson;

  /// Updates the row described by [json] (must carry its id).
  final Future<void> Function(DatabaseSession session, Map<String, dynamic> json)
  updateJson;

  /// Deletes the row with [id]; returns whether a row was found.
  final Future<bool> Function(DatabaseSession session, UuidValue id) deleteById;
}

TableOps _ops<T extends TableRow>() {
  final table = Protocol().getTableForType(T);
  if (table == null) {
    throw StateError('No table is registered for type $T.');
  }
  return TableOps(
    table: table,
    findAll: (session, {includeHidden = false}) async {
      final rows = await session.db.find<T>(
        where: includeHidden ? table.includeHiddenRows : null,
      );
      return [for (final row in rows) row.toJson()];
    },
    findByIdJson: (session, id) async {
      final row = await session.db.findById<T>(id);
      return row?.toJson();
    },
    insertJson: (session, json) async {
      await session.db.insertRow<T>(Protocol().deserialize<T>(json));
    },
    updateJson: (session, json) async {
      await session.db.updateRow<T>(Protocol().deserialize<T>(json));
    },
    deleteById: (session, id) async {
      final row = await session.db.findById<T>(id);
      if (row == null) return false;
      await session.db.deleteRow<T>(row);
      return true;
    },
  );
}

/// Every synced demo table, keyed by its database table name. This list of row
/// types is the single source of truth; [demoSyncTables] is derived from it.
final Map<String, TableOps> demoTableOps = {
  for (final ops in <TableOps>[
    _ops<Person>(),
    _ops<Address>(),
    _ops<City>(),
    _ops<Town>(),
    _ops<Organization>(),
    _ops<Company>(),
    _ops<RestrictChild>(),
    _ops<RequiredSetNullChild>(),
    _ops<Unique>(),
    _ops<UniqueUuid>(),
    _ops<UniqueComposite>(),
    _ops<UniqueSetNullChild>(),
    _ops<Types>(),
    _ops<FkChainRoot>(),
    _ops<FkChainCascadeMiddle>(),
    _ops<FkChainRestrictBlocker>(),
    _ops<FkChainMiddleSetNullChild>(),
    _ops<FkChainMiddleCascadeChild>(),
    _ops<FkChainSetNullMiddle>(),
    _ops<FkChainSetNullCascadeChild>(),
    _ops<FkChainSetNullRestrictChild>(),
    _ops<FkChainSetNullSetNullChild>(),
  ])
    ops.name: ops,
};

/// Tables synchronized by the demo, derived from [demoTableOps]. Mirrors the
/// server `demoSyncTables`.
final List<Table> demoSyncTables = [
  for (final ops in demoTableOps.values) ops.table,
];
