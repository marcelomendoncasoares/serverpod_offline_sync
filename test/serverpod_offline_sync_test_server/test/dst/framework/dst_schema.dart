import 'dart:typed_data';

import 'package:serverpod_database/serverpod_database.dart' as db;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as models;
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart'
    as shared;

/// Models whose domain rows the simulation authors and compares.
enum DstTable {
  types('types'),
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
  uniqueMixedFk('unique_mixed_fk'),
  organization('organization'),
  requiredCascadeChild('required_cascade_child'),
  requiredNoActionChild('required_no_action_child'),
  uniqueSetDefaultChild('unique_set_default_child'),
  uniqueCascadeReference('unique_cascade_reference'),
  restrictChild('restrict_child'),
  uniqueCascadeChild('unique_cascade_child'),
  fkChainRoot('fk_chain_root'),
  fkChainCascadeMiddle('fk_chain_cascade_middle'),
  fkChainRestrictBlocker('fk_chain_restrict_blocker'),
  fkChainMiddleCascadeChild('fk_chain_middle_cascade_child'),
  fkChainMiddleSetNullChild('fk_chain_middle_set_null_child'),
  fkChainSetNullMiddle('fk_chain_set_null_middle'),
  fkChainSetNullCascadeChild('fk_chain_set_null_cascade_child'),
  fkChainSetNullRestrictChild('fk_chain_set_null_restrict_child'),
  fkChainSetNullSetNullChild('fk_chain_set_null_set_null_child'),
  sharedParent('shared_parent'),
  sharedChild('shared_child');

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
    models.UuidValue? spaceUuid,
  }) => session.db.find<T>(
    where: spaceUuid == null
        ? (includeHidden ? table.includeHiddenRows : null)
        : includeHidden
        ? table.includeHiddenRows & table.spaceEquals(spaceUuid)
        : table.spaceEquals(spaceUuid),
    transaction: transaction,
  );

  Future<T> insert(db.DatabaseSession session, db.TableRow row, db.Transaction tx) =>
      session.db.insertRow<T>(row as T, transaction: tx);

  Future<T> update(
    db.DatabaseSession session,
    db.TableRow row,
    Set<String>? columns,
    db.Transaction tx,
  ) => session.db.updateRow<T>(
    row as T,
    columns: columns == null
        ? null
        : table.columns.where((column) => columns.contains(column.columnName)).toList(),
    transaction: tx,
  );

  Future<T> delete(db.DatabaseSession session, db.TableRow row, db.Transaction tx) =>
      session.db.deleteRow<T>(row as T, transaction: tx);
  Future<List<T>> insertBatch(
    db.DatabaseSession session,
    List<db.TableRow> rows,
    db.Transaction tx,
  ) => session.db.insert<T>(rows.cast<T>(), transaction: tx);

  Future<List<T>> updateBatch(
    db.DatabaseSession session,
    List<db.TableRow> rows,
    Set<String> columns,
    db.Transaction tx,
  ) => session.db.update<T>(
    rows.cast<T>(),
    columns: table.columns
        .where((column) => columns.contains(column.columnName))
        .toList(),
    transaction: tx,
  );

  Future<List<T>> deleteBatch(
    db.DatabaseSession session,
    List<db.TableRow> rows,
    db.Transaction tx,
  ) => session.db.delete<T>(rows.cast<T>(), transaction: tx);

  Future<T?> upsert(db.DatabaseSession session, db.TableRow row, db.Transaction tx) =>
      session.db.upsertRow<T>(row as T, conflictColumns: [table.id], transaction: tx);

  Future<List<T>> updateWhere(
    db.DatabaseSession session,
    Set<models.UuidValue> ids,
    Map<String, dynamic> values,
    db.Transaction tx,
  ) => session.db.updateWhere<T>(
    where: table.id.inSet(ids),
    columnValues: [
      for (final column in table.columns)
        if (values.containsKey(column.columnName))
          db.ColumnValue(
            column,
            _columnValue(column, values[column.columnName]),
          ),
    ],
    transaction: tx,
  );

  Future<List<T>> deleteWhere(
    db.DatabaseSession session,
    Set<models.UuidValue> ids,
    db.Transaction tx,
  ) => session.db.deleteWhere<T>(where: table.id.inSet(ids), transaction: tx);
}

final dstModels = <DstTable, DstModel<db.TableRow<models.UuidValue?>>>{
  DstTable.sharedParent: DstModel<shared.SharedParent>(
    table: shared.SharedParent.t,
    fromJson: shared.SharedParent.fromJson,
  ),
  DstTable.sharedChild: DstModel<shared.SharedChild>(
    table: shared.SharedChild.t,
    fromJson: shared.SharedChild.fromJson,
  ),
  DstTable.types: DstModel<models.Types>(
    table: models.Types.t,
    fromJson: models.Types.fromJson,
  ),
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
  DstTable.organization: DstModel<models.Organization>(
    table: models.Organization.t,
    fromJson: models.Organization.fromJson,
  ),
  DstTable.requiredCascadeChild: DstModel<models.RequiredCascadeChild>(
    table: models.RequiredCascadeChild.t,
    fromJson: models.RequiredCascadeChild.fromJson,
  ),
  DstTable.requiredNoActionChild: DstModel<models.RequiredNoActionChild>(
    table: models.RequiredNoActionChild.t,
    fromJson: models.RequiredNoActionChild.fromJson,
  ),
  DstTable.uniqueSetDefaultChild: DstModel<models.UniqueSetDefaultChild>(
    table: models.UniqueSetDefaultChild.t,
    fromJson: models.UniqueSetDefaultChild.fromJson,
  ),
  DstTable.uniqueCascadeReference: DstModel<models.UniqueCascadeReference>(
    table: models.UniqueCascadeReference.t,
    fromJson: models.UniqueCascadeReference.fromJson,
  ),
  DstTable.restrictChild: DstModel<models.RestrictChild>(
    table: models.RestrictChild.t,
    fromJson: models.RestrictChild.fromJson,
  ),
  DstTable.uniqueCascadeChild: DstModel<models.UniqueCascadeChild>(
    table: models.UniqueCascadeChild.t,
    fromJson: models.UniqueCascadeChild.fromJson,
  ),
  DstTable.fkChainRoot: DstModel<models.FkChainRoot>(
    table: models.FkChainRoot.t,
    fromJson: models.FkChainRoot.fromJson,
  ),
  DstTable.fkChainCascadeMiddle: DstModel<models.FkChainCascadeMiddle>(
    table: models.FkChainCascadeMiddle.t,
    fromJson: models.FkChainCascadeMiddle.fromJson,
  ),
  DstTable.fkChainRestrictBlocker: DstModel<models.FkChainRestrictBlocker>(
    table: models.FkChainRestrictBlocker.t,
    fromJson: models.FkChainRestrictBlocker.fromJson,
  ),
  DstTable.fkChainMiddleCascadeChild: DstModel<models.FkChainMiddleCascadeChild>(
    table: models.FkChainMiddleCascadeChild.t,
    fromJson: models.FkChainMiddleCascadeChild.fromJson,
  ),
  DstTable.fkChainMiddleSetNullChild: DstModel<models.FkChainMiddleSetNullChild>(
    table: models.FkChainMiddleSetNullChild.t,
    fromJson: models.FkChainMiddleSetNullChild.fromJson,
  ),
  DstTable.fkChainSetNullMiddle: DstModel<models.FkChainSetNullMiddle>(
    table: models.FkChainSetNullMiddle.t,
    fromJson: models.FkChainSetNullMiddle.fromJson,
  ),
  DstTable.fkChainSetNullCascadeChild: DstModel<models.FkChainSetNullCascadeChild>(
    table: models.FkChainSetNullCascadeChild.t,
    fromJson: models.FkChainSetNullCascadeChild.fromJson,
  ),
  DstTable.fkChainSetNullRestrictChild: DstModel<models.FkChainSetNullRestrictChild>(
    table: models.FkChainSetNullRestrictChild.t,
    fromJson: models.FkChainSetNullRestrictChild.fromJson,
  ),
  DstTable.fkChainSetNullSetNullChild: DstModel<models.FkChainSetNullSetNullChild>(
    table: models.FkChainSetNullSetNullChild.t,
    fromJson: models.FkChainSetNullSetNullChild.fromJson,
  ),
};

/// updateWhere accepts Dart values, whereas generated model maps contain JSON.
Object? _columnValue(db.Column column, Object? value) {
  if (value == null) return null;
  return switch (column) {
    db.ColumnUuid() => models.UuidValueJsonExtension.fromJson(value),
    db.ColumnDateTime() => models.DateTimeJsonExtension.fromJson(value),
    db.ColumnBigInt() => models.BigIntJsonExtension.fromJson(value),
    db.ColumnByteData() => models.ByteDataJsonExtension.fromJson(value),
    db.ColumnEnum<models.TypesEnum>() => models.TypesEnum.fromJson(value as int),
    db.ColumnEnum<shared.SharedFlavor>() => shared.SharedFlavor.fromJson(
      value as String,
    ),
    db.ColumnSerializable() ||
    db.ColumnStructured() => models.Protocol().deserialize<dynamic>(value, column.type),
    _ => value,
  };
}

/// JSON inputs for the remaining typed columns in the generated model catalog.
/// Finite reals, UTC instants, wide integers, and variable-size binary values
/// exercise ordinary persisted values without adding invalid ORM inputs.
Object dstTypedScalarJson(String? dartType, int sample) =>
    switch (dartType?.replaceAll('?', '')) {
      'bool' => sample.isEven,
      'DateTime' => DateTime.utc(
        2026,
        1,
        1,
      ).add(Duration(milliseconds: sample * 1001)).toIso8601String(),
      'BigInt' => (BigInt.parse('9007199254740993') + BigInt.from(sample)).toString(),
      'double' => (sample - 500) / 8.0,
      'dart:typed_data:ByteData' => models.ByteDataJsonExtension(
        ByteData.sublistView(
          Uint8List.fromList([
            for (var index = 0; index < sample % 17; index++) (sample + index) % 256,
          ]),
        ),
      ).toJson(),
      'protocol:TypesEnum' => sample % models.TypesEnum.values.length,
      'serverpod_offline_sync_test_shared:SharedFlavor' =>
        shared.SharedFlavor.values[sample % shared.SharedFlavor.values.length].toJson(),
      'protocol:SyncDocument' => models.SyncDocument(
        title: 'document-$sample',
        enabled: sample.isEven,
        numbers: [sample, -sample],
      ).toJson(),
      'List<int>' => [sample, -sample],
      _ => throw StateError('No DST scalar value for $dartType'),
    };

/// Text claims remain text even when they resemble UUIDs. Letter case is
/// significant for the generated SQLite TEXT unique indexes.
const dstUniqueTextValues = [
  'claim-0',
  'claim-1',
  'claim-2',
  'claim-3',
  '550e8400-e29b-41d4-a716-446655440111',
  '550E8400-E29B-41D4-A716-446655440111',
];

/// A small, deterministic UUID claim alphabet, independent of row identity.
const dstUniqueValues = [
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440000'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440001'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440002'),
  models.UuidValue.raw('660e8400-e29b-41d4-a716-446655440003'),
];

/// Every declared unique index, retaining tuple components and space semantics.
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

/// The complete outbound FK population of the simulated schema. Space metadata
/// belongs to the engine and is not an authored domain relation.
final dstForeignKeys = [
  for (final child in DstTable.values)
    for (final key in child.definition.foreignKeys)
      if (!key.columns.contains('spaceId'))
        (
          child: child,
          column: key.columns.single,
          parent: DstTable.values.firstWhere(
            (table) => table.tableName == key.referenceTable,
          ),
          parentColumn: key.referenceColumns.single,
          action: (key.onDelete ?? db.ForeignKeyAction.noAction).name,
          nullable: child.definition.columns
              .firstWhere((column) => column.name == key.columns.single)
              .isNullable,
          defaultValue: _foreignKeyDefault(
            child.definition.columns
                .firstWhere((column) => column.name == key.columns.single)
                .columnDefault,
          ),
        ),
];

typedef DstForeignKey = ({
  DstTable child,
  String column,
  DstTable parent,
  String parentColumn,
  String action,
  bool nullable,
  models.UuidValue? defaultValue,
});

models.UuidValue? _foreignKeyDefault(String? value) {
  if (value == null || value.toLowerCase() == 'null') return null;
  return models.UuidValue.withValidation(value.replaceAll("'", ''));
}
