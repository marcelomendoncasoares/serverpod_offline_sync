import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as models;

/// Models whose domain rows the simulation authors and compares.
enum DstTable {
  city('city'),
  person('person'),
  town('town'),
  company('company'),
  address('address'),
  unique('unique'),
  uniqueSetNullChild('unique_set_null_child'),
  uniqueUuid('unique_uuid'),
  uniqueComposite('unique_composite'),
  uniqueDiscriminator('unique_discriminator'),
  uniqueNullable('unique_nullable'),
  uniqueOverlapping('unique_overlapping'),
  uniqueFkPair('unique_fk_pair'),
  uniqueMixedFk('unique_mixed_fk');

  const DstTable(this.tableName);
  final String tableName;
  DstModel<db.TableRow<models.UuidValue?>> get model => dstModels[this]!;
  db.TableDefinition get definition => dstTableDefinitions[tableName]!;
}

/// Retains each generated model's runtime type at the ordinary ORM boundary.
/// All data and scenario choices remain in the operation generator.
class DstModel<T extends db.TableRow<models.UuidValue?>> {
  DstModel({required this.table, required this.fromJson});
  final db.Table<models.UuidValue?> table;
  final T Function(Map<String, dynamic>) fromJson;

  Future<List<T>> find(
    db.DatabaseSession session, {
    db.Transaction? transaction,
    bool includeHidden = false,
  }) => session.db.find<T>(
    where: includeHidden ? table.includeHiddenRows : null,
    transaction: transaction,
  );

  Future<T> insert(db.DatabaseSession session, db.TableRow row, db.Transaction tx) =>
      session.db.insertRow<T>(row as T, transaction: tx);

  Future<T> update(
    db.DatabaseSession session,
    db.TableRow row,
    Set<String> columns,
    db.Transaction tx,
  ) => session.db.updateRow<T>(
    row as T,
    columns: table.columns
        .where((column) => columns.contains(column.columnName))
        .toList(),
    transaction: tx,
  );

  Future<T> delete(db.DatabaseSession session, db.TableRow row, db.Transaction tx) =>
      session.db.deleteRow<T>(row as T, transaction: tx);
}

final dstModels = <DstTable, DstModel<db.TableRow<models.UuidValue?>>>{
  DstTable.city: DstModel<models.City>(
    table: models.City.t,
    fromJson: models.City.fromJson,
  ),
  DstTable.person: DstModel<models.Person>(
    table: models.Person.t,
    fromJson: models.Person.fromJson,
  ),
  DstTable.town: DstModel<models.Town>(
    table: models.Town.t,
    fromJson: models.Town.fromJson,
  ),
  DstTable.company: DstModel<models.Company>(
    table: models.Company.t,
    fromJson: models.Company.fromJson,
  ),
  DstTable.address: DstModel<models.Address>(
    table: models.Address.t,
    fromJson: models.Address.fromJson,
  ),
  DstTable.unique: DstModel<models.Unique>(
    table: models.Unique.t,
    fromJson: models.Unique.fromJson,
  ),
  DstTable.uniqueSetNullChild: DstModel<models.UniqueSetNullChild>(
    table: models.UniqueSetNullChild.t,
    fromJson: models.UniqueSetNullChild.fromJson,
  ),
  DstTable.uniqueUuid: DstModel<models.UniqueUuid>(
    table: models.UniqueUuid.t,
    fromJson: models.UniqueUuid.fromJson,
  ),
  DstTable.uniqueComposite: DstModel<models.UniqueComposite>(
    table: models.UniqueComposite.t,
    fromJson: models.UniqueComposite.fromJson,
  ),
  DstTable.uniqueDiscriminator: DstModel<models.UniqueDiscriminator>(
    table: models.UniqueDiscriminator.t,
    fromJson: models.UniqueDiscriminator.fromJson,
  ),
  DstTable.uniqueNullable: DstModel<models.UniqueNullable>(
    table: models.UniqueNullable.t,
    fromJson: models.UniqueNullable.fromJson,
  ),
  DstTable.uniqueOverlapping: DstModel<models.UniqueOverlapping>(
    table: models.UniqueOverlapping.t,
    fromJson: models.UniqueOverlapping.fromJson,
  ),
  DstTable.uniqueFkPair: DstModel<models.UniqueFkPair>(
    table: models.UniqueFkPair.t,
    fromJson: models.UniqueFkPair.fromJson,
  ),
  DstTable.uniqueMixedFk: DstModel<models.UniqueMixedFk>(
    table: models.UniqueMixedFk.t,
    fromJson: models.UniqueMixedFk.fromJson,
  ),
};

const dstAdditionalUniqueTables = [
  DstTable.uniqueUuid,
  DstTable.uniqueComposite,
  DstTable.uniqueDiscriminator,
  DstTable.uniqueNullable,
  DstTable.uniqueOverlapping,
  DstTable.uniqueFkPair,
  DstTable.uniqueMixedFk,
];

/// A small, deterministic claim alphabet, independent of row identity.
const dstUniqueValues = [
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440000'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440001'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440002'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440003'),
];

/// Every declared unique index, retaining tuple components and scope semantics.
final dstUniqueIndexes = [
  for (final table in DstTable.values)
    for (final index in table.definition.indexes)
      if (index.isUnique && !index.isPrimary)
        (
          table: table,
          name: index.indexName,
          columns: [for (final element in index.elements) element.definition],
        ),
];

final dstTableDefinitions = {
  for (final definition in models.Protocol.targetTableDefinitions)
    definition.name: definition,
};
