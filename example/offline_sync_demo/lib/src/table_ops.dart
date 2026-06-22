import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Table, TableRow;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    show IncludeTombstonedRows;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'models.dart';

typedef _RowFactory<T extends TableRow<UuidValue?>> =
    T? Function(UuidValue id, String label, Map<String, UuidValue> foreignKeys);

/// Generic, table-name keyed CRUD over the generated Serverpod models.
///
/// Database operations retain generated model instances. The only
/// serialization boundary is [updateFields], where a generic UI edit has to be
/// turned back into the concrete generated type; that conversion is delegated
/// to [Protocol].
class TableOps {
  TableOps({
    required this.table,
    required this.canCreateRoot,
    required this.createRow,
    required this.findAll,
    required this.findById,
    required this.insertRow,
    required this.updateFields,
    required this.deleteById,
  });

  /// The generated table metadata for this row type.
  final Table table;

  /// Database table name, e.g. `person`.
  String get name => table.tableName;

  /// Whether the generated constructor can build this row without a parent.
  final bool canCreateRoot;

  /// Builds a generated model, optionally assigning one foreign key.
  final TableRow<UuidValue?>? Function({
    required String label,
    String? foreignKeyColumn,
    UuidValue? foreignKeyValue,
  })
  createRow;

  /// Every row in the table. When [includeHidden] is true, CRDT-tombstoned
  /// (soft-deleted) rows are returned too.
  final Future<List<TableRow<UuidValue?>>> Function(
    DatabaseSession session, {
    bool includeHidden,
  })
  findAll;

  /// A single visible row by id, or null.
  final Future<TableRow<UuidValue?>?> Function(
    DatabaseSession session,
    UuidValue id,
  )
  findById;

  /// Inserts a generated row.
  final Future<void> Function(DatabaseSession session, TableRow<UuidValue?> row)
  insertRow;

  /// Applies JSON-shaped field values to a generated row and updates it.
  final Future<void> Function(
    DatabaseSession session,
    TableRow<UuidValue?> row,
    Map<String, dynamic> fields,
  )
  updateFields;

  /// Deletes the row with [id]; returns whether a row was found.
  final Future<bool> Function(DatabaseSession session, UuidValue id) deleteById;
}

TableOps _ops<T extends TableRow<UuidValue?>>({
  _RowFactory<T>? create,
  bool canCreateRoot = true,
}) {
  final table = Protocol().getTableForType(T);
  if (table == null) {
    throw StateError('No table is registered for type $T.');
  }
  return TableOps(
    table: table,
    canCreateRoot: create != null && canCreateRoot,
    createRow: ({required label, foreignKeyColumn, foreignKeyValue}) {
      if (create == null) return null;
      return create(newId(), label, {
        if (foreignKeyColumn != null && foreignKeyValue != null)
          foreignKeyColumn: foreignKeyValue,
      });
    },
    findAll: (session, {includeHidden = false}) async {
      return session.db.find<T>(
        where: includeHidden ? table.includeHiddenRows : null,
      );
    },
    findById: (session, id) => session.db.findById<T>(id),
    insertRow: (session, row) async {
      await session.db.insertRow<T>(row as T);
    },
    updateFields: (session, row, fields) async {
      final json = Map<String, dynamic>.of(row.toJson() as Map<String, dynamic>)
        ..addAll(fields);
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

/// Every synced demo table, keyed by its database table name. The generated
/// constructors keep required fields, defaults, and Dart types in generated
/// code instead of reconstructing those rules from table metadata.
final Map<String, TableOps> demoTableOps = {
  for (final ops in <TableOps>[
    _ops<Person>(
      create: (id, label, foreignKeys) => Person(
        id: id,
        name: label,
        organizationId: foreignKeys['organizationId'],
        oldCompanyId: foreignKeys['oldCompanyId'],
      ),
    ),
    _ops<Address>(
      create: (id, label, foreignKeys) => Address(
        id: id,
        street: label,
        inhabitantId: foreignKeys['inhabitantId'],
      ),
    ),
    _ops<City>(
      create: (id, label, foreignKeys) => City(id: id, name: label),
    ),
    _ops<Town>(
      create: (id, label, foreignKeys) => Town(
        id: id,
        name: label,
        cityId: foreignKeys['cityId'],
        mayorId: foreignKeys['mayorId'],
      ),
    ),
    _ops<Organization>(
      create: (id, label, foreignKeys) =>
          Organization(id: id, name: label, cityId: foreignKeys['cityId']),
    ),
    _ops<Company>(
      create: (id, label, foreignKeys) =>
          Company(id: id, name: label, townId: foreignKeys['townId']),
    ),
    _ops<RestrictChild>(
      create: (id, label, foreignKeys) =>
          RestrictChild(id: id, name: label, parentId: foreignKeys['parentId']),
    ),
    _ops<RequiredSetNullChild>(
      canCreateRoot: false,
      create: (id, label, foreignKeys) {
        final parentId = foreignKeys['parentId'];
        if (parentId == null) return null;
        return RequiredSetNullChild(id: id, name: label, parentId: parentId);
      },
    ),
    _ops<Unique>(
      create: (id, label, foreignKeys) => Unique(id: id, name: label),
    ),
    _ops<UniqueUuid>(
      create: (id, label, foreignKeys) => UniqueUuid(id: id, value: newId()),
    ),
    _ops<UniqueComposite>(
      create: (id, label, foreignKeys) =>
          UniqueComposite(id: id, scope: label, value: label),
    ),
    _ops<UniqueSetNullChild>(
      create: (id, label, foreignKeys) => UniqueSetNullChild(
        id: id,
        name: label,
        parentId: foreignKeys['parentId'],
      ),
    ),
    _ops<Types>(canCreateRoot: false),
    _ops<FkChainRoot>(
      create: (id, label, foreignKeys) => FkChainRoot(id: id, name: label),
    ),
    _ops<FkChainCascadeMiddle>(
      create: (id, label, foreignKeys) => FkChainCascadeMiddle(
        id: id,
        name: label,
        rootId: foreignKeys['rootId'],
      ),
    ),
    _ops<FkChainRestrictBlocker>(
      create: (id, label, foreignKeys) => FkChainRestrictBlocker(
        id: id,
        name: label,
        cascadeMiddleId: foreignKeys['cascadeMiddleId'],
      ),
    ),
    _ops<FkChainMiddleSetNullChild>(
      create: (id, label, foreignKeys) => FkChainMiddleSetNullChild(
        id: id,
        name: label,
        restrictBlockerId: foreignKeys['restrictBlockerId'],
      ),
    ),
    _ops<FkChainMiddleCascadeChild>(
      create: (id, label, foreignKeys) => FkChainMiddleCascadeChild(
        id: id,
        name: label,
        restrictBlockerId: foreignKeys['restrictBlockerId'],
      ),
    ),
    _ops<FkChainSetNullMiddle>(
      create: (id, label, foreignKeys) => FkChainSetNullMiddle(
        id: id,
        name: label,
        cascadeMiddleId: foreignKeys['cascadeMiddleId'],
      ),
    ),
    _ops<FkChainSetNullCascadeChild>(
      create: (id, label, foreignKeys) => FkChainSetNullCascadeChild(
        id: id,
        name: label,
        setNullMiddleId: foreignKeys['setNullMiddleId'],
      ),
    ),
    _ops<FkChainSetNullRestrictChild>(
      create: (id, label, foreignKeys) => FkChainSetNullRestrictChild(
        id: id,
        name: label,
        setNullMiddleId: foreignKeys['setNullMiddleId'],
      ),
    ),
    _ops<FkChainSetNullSetNullChild>(
      create: (id, label, foreignKeys) => FkChainSetNullSetNullChild(
        id: id,
        name: label,
        setNullMiddleId: foreignKeys['setNullMiddleId'],
      ),
    ),
  ])
    ops.name: ops,
};

/// Tables synchronized by the demo, derived from [demoTableOps]. Mirrors the
/// server `demoSyncTables`.
final List<Table> demoSyncTables = [
  for (final ops in demoTableOps.values) ops.table,
];
