import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

/// Generic, table-name keyed CRUD over the generated Serverpod models.
///
/// Every synced table is wrapped once with thin closures over its generated
/// `<Class>.db` repository, so the rest of the demo can create / read / update /
/// delete any row by table name without a giant per-table `switch`. All values
/// cross the boundary as JSON maps (the same shape `toJson()` produces), which
/// keeps the demo code free of concrete model types.
class TableOps {
  TableOps({
    required this.name,
    required this.findAll,
    required this.findByIdJson,
    required this.insertJson,
    required this.updateJson,
    required this.deleteById,
  });

  /// Database table name, e.g. `person`.
  final String name;

  /// Every row in the table, as JSON, read through [session].
  final Future<List<Map<String, dynamic>>> Function(DatabaseSession session)
  findAll;

  /// A single row by id, or null, as JSON.
  final Future<Map<String, dynamic>?> Function(
    DatabaseSession session,
    UuidValue id,
  )
  findByIdJson;

  /// Inserts a row built from [json].
  final Future<void> Function(
    DatabaseSession session,
    Map<String, dynamic> json,
  )
  insertJson;

  /// Updates the row described by [json] (must carry its id).
  final Future<void> Function(
    DatabaseSession session,
    Map<String, dynamic> json,
  )
  updateJson;

  /// Deletes the row with [id]; returns whether a row was found.
  final Future<bool> Function(DatabaseSession session, UuidValue id) deleteById;
}

TableOps _ops<T extends Object>(
  String name,
  Future<List<T>> Function(DatabaseSession) find,
  Future<T?> Function(DatabaseSession, UuidValue) findById,
  Future<T> Function(DatabaseSession, T) insertRow,
  Future<T> Function(DatabaseSession, T) updateRow,
  Future<T> Function(DatabaseSession, T) deleteRow,
  Map<String, dynamic> Function(T) toJson,
) {
  T fromJson(Map<String, dynamic> json) => Protocol().deserialize<T>(json);

  return TableOps(
    name: name,
    findAll: (session) async => [
      for (final row in await find(session)) toJson(row),
    ],
    findByIdJson: (session, id) async {
      final row = await findById(session, id);
      return row == null ? null : toJson(row);
    },
    insertJson: (session, json) async {
      await insertRow(session, fromJson(json));
    },
    updateJson: (session, json) async {
      await updateRow(session, fromJson(json));
    },
    deleteById: (session, id) async {
      final row = await findById(session, id);
      if (row == null) return false;
      await deleteRow(session, row);
      return true;
    },
  );
}

/// Every synced demo table, keyed by its database table name.
final Map<String, TableOps> demoTableOps = {
  for (final ops in <TableOps>[
    _ops<Person>(
      'person',
      Person.db.find,
      Person.db.findById,
      Person.db.insertRow,
      Person.db.updateRow,
      Person.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Address>(
      'address',
      Address.db.find,
      Address.db.findById,
      Address.db.insertRow,
      Address.db.updateRow,
      Address.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<City>(
      'city',
      City.db.find,
      City.db.findById,
      City.db.insertRow,
      City.db.updateRow,
      City.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Town>(
      'town',
      Town.db.find,
      Town.db.findById,
      Town.db.insertRow,
      Town.db.updateRow,
      Town.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Organization>(
      'organization',
      Organization.db.find,
      Organization.db.findById,
      Organization.db.insertRow,
      Organization.db.updateRow,
      Organization.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Company>(
      'company',
      Company.db.find,
      Company.db.findById,
      Company.db.insertRow,
      Company.db.updateRow,
      Company.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<RestrictChild>(
      'restrict_child',
      RestrictChild.db.find,
      RestrictChild.db.findById,
      RestrictChild.db.insertRow,
      RestrictChild.db.updateRow,
      RestrictChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<RequiredSetNullChild>(
      'required_set_null_child',
      RequiredSetNullChild.db.find,
      RequiredSetNullChild.db.findById,
      RequiredSetNullChild.db.insertRow,
      RequiredSetNullChild.db.updateRow,
      RequiredSetNullChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Unique>(
      'unique',
      Unique.db.find,
      Unique.db.findById,
      Unique.db.insertRow,
      Unique.db.updateRow,
      Unique.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<UniqueUuid>(
      'unique_uuid',
      UniqueUuid.db.find,
      UniqueUuid.db.findById,
      UniqueUuid.db.insertRow,
      UniqueUuid.db.updateRow,
      UniqueUuid.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<UniqueComposite>(
      'unique_composite',
      UniqueComposite.db.find,
      UniqueComposite.db.findById,
      UniqueComposite.db.insertRow,
      UniqueComposite.db.updateRow,
      UniqueComposite.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<UniqueSetNullChild>(
      'unique_set_null_child',
      UniqueSetNullChild.db.find,
      UniqueSetNullChild.db.findById,
      UniqueSetNullChild.db.insertRow,
      UniqueSetNullChild.db.updateRow,
      UniqueSetNullChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<Types>(
      'types',
      Types.db.find,
      Types.db.findById,
      Types.db.insertRow,
      Types.db.updateRow,
      Types.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainRoot>(
      'fk_chain_root',
      FkChainRoot.db.find,
      FkChainRoot.db.findById,
      FkChainRoot.db.insertRow,
      FkChainRoot.db.updateRow,
      FkChainRoot.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainCascadeMiddle>(
      'fk_chain_cascade_middle',
      FkChainCascadeMiddle.db.find,
      FkChainCascadeMiddle.db.findById,
      FkChainCascadeMiddle.db.insertRow,
      FkChainCascadeMiddle.db.updateRow,
      FkChainCascadeMiddle.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainRestrictBlocker>(
      'fk_chain_restrict_blocker',
      FkChainRestrictBlocker.db.find,
      FkChainRestrictBlocker.db.findById,
      FkChainRestrictBlocker.db.insertRow,
      FkChainRestrictBlocker.db.updateRow,
      FkChainRestrictBlocker.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainMiddleSetNullChild>(
      'fk_chain_middle_set_null_child',
      FkChainMiddleSetNullChild.db.find,
      FkChainMiddleSetNullChild.db.findById,
      FkChainMiddleSetNullChild.db.insertRow,
      FkChainMiddleSetNullChild.db.updateRow,
      FkChainMiddleSetNullChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainMiddleCascadeChild>(
      'fk_chain_middle_cascade_child',
      FkChainMiddleCascadeChild.db.find,
      FkChainMiddleCascadeChild.db.findById,
      FkChainMiddleCascadeChild.db.insertRow,
      FkChainMiddleCascadeChild.db.updateRow,
      FkChainMiddleCascadeChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainSetNullMiddle>(
      'fk_chain_set_null_middle',
      FkChainSetNullMiddle.db.find,
      FkChainSetNullMiddle.db.findById,
      FkChainSetNullMiddle.db.insertRow,
      FkChainSetNullMiddle.db.updateRow,
      FkChainSetNullMiddle.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainSetNullCascadeChild>(
      'fk_chain_set_null_cascade_child',
      FkChainSetNullCascadeChild.db.find,
      FkChainSetNullCascadeChild.db.findById,
      FkChainSetNullCascadeChild.db.insertRow,
      FkChainSetNullCascadeChild.db.updateRow,
      FkChainSetNullCascadeChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainSetNullRestrictChild>(
      'fk_chain_set_null_restrict_child',
      FkChainSetNullRestrictChild.db.find,
      FkChainSetNullRestrictChild.db.findById,
      FkChainSetNullRestrictChild.db.insertRow,
      FkChainSetNullRestrictChild.db.updateRow,
      FkChainSetNullRestrictChild.db.deleteRow,
      (r) => r.toJson(),
    ),
    _ops<FkChainSetNullSetNullChild>(
      'fk_chain_set_null_set_null_child',
      FkChainSetNullSetNullChild.db.find,
      FkChainSetNullSetNullChild.db.findById,
      FkChainSetNullSetNullChild.db.insertRow,
      FkChainSetNullSetNullChild.db.updateRow,
      FkChainSetNullSetNullChild.db.deleteRow,
      (r) => r.toJson(),
    ),
  ])
    ops.name: ops,
};
