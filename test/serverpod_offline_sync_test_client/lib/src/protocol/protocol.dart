/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_database/serverpod_database.dart' as _i1;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i2;
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart'
    as _i3;
import 'address.dart' as _i4;
import 'city.dart' as _i5;
import 'company.dart' as _i6;
import 'fk_chain/cascade_middle.dart' as _i7;
import 'fk_chain/middle_cascade_child.dart' as _i8;
import 'fk_chain/middle_set_null_child.dart' as _i9;
import 'fk_chain/restrict_blocker.dart' as _i10;
import 'fk_chain/root.dart' as _i11;
import 'fk_chain/set_null_cascade_child.dart' as _i12;
import 'fk_chain/set_null_middle.dart' as _i13;
import 'fk_chain/set_null_restrict_child.dart' as _i14;
import 'fk_chain/set_null_set_null_child.dart' as _i15;
import 'organization.dart' as _i16;
import 'person.dart' as _i17;
import 'required_set_null_child.dart' as _i18;
import 'restrict_child.dart' as _i19;
import 'town.dart' as _i20;
import 'types.dart' as _i21;
import 'types_enum.dart' as _i22;
import 'unique.dart' as _i23;
import 'unique_composite.dart' as _i24;
import 'unique_discriminator.dart' as _i25;
import 'unique_no_release.dart' as _i26;
import 'unique_set_null_child.dart' as _i27;
import 'unique_uuid.dart' as _i28;
import 'package:serverpod_client/serverpod_client.dart' as _i29;
export 'address.dart';
export 'city.dart';
export 'company.dart';
export 'fk_chain/cascade_middle.dart';
export 'fk_chain/middle_cascade_child.dart';
export 'fk_chain/middle_set_null_child.dart';
export 'fk_chain/restrict_blocker.dart';
export 'fk_chain/root.dart';
export 'fk_chain/set_null_cascade_child.dart';
export 'fk_chain/set_null_middle.dart';
export 'fk_chain/set_null_restrict_child.dart';
export 'fk_chain/set_null_set_null_child.dart';
export 'organization.dart';
export 'person.dart';
export 'required_set_null_child.dart';
export 'restrict_child.dart';
export 'town.dart';
export 'types.dart';
export 'types_enum.dart';
export 'unique.dart';
export 'unique_composite.dart';
export 'unique_discriminator.dart';
export 'unique_no_release.dart';
export 'unique_set_null_child.dart';
export 'unique_uuid.dart';
export 'client.dart';

class Protocol extends _i1.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static List<_i1.TableDefinition> get targetTableDefinitions => [
    _i1.TableDefinition(
      name: 'address',
      dartName: 'Address',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'street',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'inhabitantId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'address_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'address_fk_1',
          columns: ['inhabitantId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.restrict,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'address__inhabitantId__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'inhabitantId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'city',
      dartName: 'City',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'city_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'company',
      dartName: 'Company',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'townId',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: '\'550e8400-e29b-41d4-a716-446655440000\'',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'company_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'company_fk_1',
          columns: ['townId'],
          referenceTable: 'town',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setDefault,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_cascade_middle',
      dartName: 'FkChainCascadeMiddle',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'rootId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_cascade_middle_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_cascade_middle_fk_1',
          columns: ['rootId'],
          referenceTable: 'fk_chain_root',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_middle_cascade_child',
      dartName: 'FkChainMiddleCascadeChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'restrictBlockerId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_cascade_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_cascade_child_fk_1',
          columns: ['restrictBlockerId'],
          referenceTable: 'fk_chain_restrict_blocker',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_middle_set_null_child',
      dartName: 'FkChainMiddleSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'restrictBlockerId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_set_null_child_fk_1',
          columns: ['restrictBlockerId'],
          referenceTable: 'fk_chain_restrict_blocker',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_restrict_blocker',
      dartName: 'FkChainRestrictBlocker',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'cascadeMiddleId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_restrict_blocker_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_restrict_blocker_fk_1',
          columns: ['cascadeMiddleId'],
          referenceTable: 'fk_chain_cascade_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.restrict,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_root',
      dartName: 'FkChainRoot',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_root_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_set_null_cascade_child',
      dartName: 'FkChainSetNullCascadeChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_cascade_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_cascade_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_set_null_middle',
      dartName: 'FkChainSetNullMiddle',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'cascadeMiddleId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_middle_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_middle_fk_1',
          columns: ['cascadeMiddleId'],
          referenceTable: 'fk_chain_cascade_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_set_null_restrict_child',
      dartName: 'FkChainSetNullRestrictChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_restrict_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_restrict_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.restrict,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'fk_chain_set_null_set_null_child',
      dartName: 'FkChainSetNullSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_set_null_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'organization',
      dartName: 'Organization',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'cityId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'organization_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'organization_fk_1',
          columns: ['cityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'person',
      dartName: 'Person',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'surname',
          columnType: _i1.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i1.ColumnDefinition(
          name: 'organizationId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i1.ColumnDefinition(
          name: 'oldCompanyId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i1.ColumnDefinition(
          name: '_cityCitizensCityId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'person_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'person_fk_1',
          columns: ['organizationId'],
          referenceTable: 'organization',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'person_fk_2',
          columns: ['oldCompanyId'],
          referenceTable: 'company',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'person_fk_3',
          columns: ['_cityCitizensCityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'required_set_null_child',
      dartName: 'RequiredSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'parentId',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'required_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'required_set_null_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'restrict_child',
      dartName: 'RestrictChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'parentId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'restrict_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'restrict_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.restrict,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'town',
      dartName: 'Town',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'cityId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i1.ColumnDefinition(
          name: 'mayorId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'town_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'town_fk_1',
          columns: ['cityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'town_fk_2',
          columns: ['mayorId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'types',
      dartName: 'Types',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'aBool',
          columnType: _i1.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i1.ColumnDefinition(
          name: 'aDateTime',
          columnType: _i1.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i1.ColumnDefinition(
          name: 'aText',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'anInt',
          columnType: _i1.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i1.ColumnDefinition(
          name: 'anInt64',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'BigInt',
        ),
        _i1.ColumnDefinition(
          name: 'aReal',
          columnType: _i1.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i1.ColumnDefinition(
          name: 'aBlob',
          columnType: _i1.ColumnType.bytea,
          isNullable: false,
          dartType: 'dart:typed_data:ByteData',
        ),
        _i1.ColumnDefinition(
          name: 'anEnum',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:TypesEnum?',
        ),
        _i1.ColumnDefinition(
          name: 'optionalText',
          columnType: _i1.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i1.ColumnDefinition(
          name: 'optionalUuid',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'types_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'types_a_text_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'aText',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique',
      dartName: 'Unique',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'unique__scopeId__name__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'name',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique_composite',
      dartName: 'UniqueComposite',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'scope',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'value',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_composite_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'unique_composite__scopeId__scope__value__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scope',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'value',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique_discriminator',
      dartName: 'UniqueDiscriminator',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'categoryId',
          columnType: _i1.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_discriminator_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName:
              'unique_discriminator__scopeId__categoryId__name__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'categoryId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'name',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique_no_release',
      dartName: 'UniqueNoRelease',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'categoryId',
          columnType: _i1.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_no_release_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'unique_no_release__scopeId__categoryId__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'categoryId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique_set_null_child',
      dartName: 'UniqueSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'name',
          columnType: _i1.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i1.ColumnDefinition(
          name: 'parentId',
          columnType: _i1.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_set_null_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'unique_set_null_child__parentId__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'parentId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i1.TableDefinition(
      name: 'unique_uuid',
      dartName: 'UniqueUuid',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _i1.ColumnDefinition(
          name: 'id',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _i1.ColumnDefinition(
          name: 'scopeId',
          columnType: _i1.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i1.ColumnDefinition(
          name: 'value',
          columnType: _i1.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
      ],
      foreignKeys: [
        _i1.ForeignKeyDefinition(
          constraintName: 'unique_uuid_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i1.ForeignKeyAction.noAction,
          onDelete: _i1.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i1.IndexDefinition(
          indexName: 'unique_uuid__scopeId__value__unique_idx',
          tableSpace: null,
          elements: [
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i1.IndexElementDefinition(
              type: _i1.IndexElementDefinitionType.column,
              definition: 'value',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._i2.Protocol() is _i1.DatabaseSerializationManager
        ? (_i2.Protocol() as _i1.DatabaseSerializationManager)
              .getTargetTableDefinitions()
        : [],
    ..._i3.Protocol() is _i1.DatabaseSerializationManager
        ? (_i3.Protocol() as _i1.DatabaseSerializationManager)
              .getTargetTableDefinitions()
        : [],
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i4.Address) {
      return _i4.Address.fromJson(data) as T;
    }
    if (t == _i5.City) {
      return _i5.City.fromJson(data) as T;
    }
    if (t == _i6.Company) {
      return _i6.Company.fromJson(data) as T;
    }
    if (t == _i7.FkChainCascadeMiddle) {
      return _i7.FkChainCascadeMiddle.fromJson(data) as T;
    }
    if (t == _i8.FkChainMiddleCascadeChild) {
      return _i8.FkChainMiddleCascadeChild.fromJson(data) as T;
    }
    if (t == _i9.FkChainMiddleSetNullChild) {
      return _i9.FkChainMiddleSetNullChild.fromJson(data) as T;
    }
    if (t == _i10.FkChainRestrictBlocker) {
      return _i10.FkChainRestrictBlocker.fromJson(data) as T;
    }
    if (t == _i11.FkChainRoot) {
      return _i11.FkChainRoot.fromJson(data) as T;
    }
    if (t == _i12.FkChainSetNullCascadeChild) {
      return _i12.FkChainSetNullCascadeChild.fromJson(data) as T;
    }
    if (t == _i13.FkChainSetNullMiddle) {
      return _i13.FkChainSetNullMiddle.fromJson(data) as T;
    }
    if (t == _i14.FkChainSetNullRestrictChild) {
      return _i14.FkChainSetNullRestrictChild.fromJson(data) as T;
    }
    if (t == _i15.FkChainSetNullSetNullChild) {
      return _i15.FkChainSetNullSetNullChild.fromJson(data) as T;
    }
    if (t == _i16.Organization) {
      return _i16.Organization.fromJson(data) as T;
    }
    if (t == _i17.Person) {
      return _i17.Person.fromJson(data) as T;
    }
    if (t == _i18.RequiredSetNullChild) {
      return _i18.RequiredSetNullChild.fromJson(data) as T;
    }
    if (t == _i19.RestrictChild) {
      return _i19.RestrictChild.fromJson(data) as T;
    }
    if (t == _i20.Town) {
      return _i20.Town.fromJson(data) as T;
    }
    if (t == _i21.Types) {
      return _i21.Types.fromJson(data) as T;
    }
    if (t == _i22.TypesEnum) {
      return _i22.TypesEnum.fromJson(data) as T;
    }
    if (t == _i23.Unique) {
      return _i23.Unique.fromJson(data) as T;
    }
    if (t == _i24.UniqueComposite) {
      return _i24.UniqueComposite.fromJson(data) as T;
    }
    if (t == _i25.UniqueDiscriminator) {
      return _i25.UniqueDiscriminator.fromJson(data) as T;
    }
    if (t == _i26.UniqueNoRelease) {
      return _i26.UniqueNoRelease.fromJson(data) as T;
    }
    if (t == _i27.UniqueSetNullChild) {
      return _i27.UniqueSetNullChild.fromJson(data) as T;
    }
    if (t == _i28.UniqueUuid) {
      return _i28.UniqueUuid.fromJson(data) as T;
    }
    if (t == _i29.getType<_i4.Address?>()) {
      return (data != null ? _i4.Address.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i5.City?>()) {
      return (data != null ? _i5.City.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i6.Company?>()) {
      return (data != null ? _i6.Company.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i7.FkChainCascadeMiddle?>()) {
      return (data != null ? _i7.FkChainCascadeMiddle.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i8.FkChainMiddleCascadeChild?>()) {
      return (data != null
              ? _i8.FkChainMiddleCascadeChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _i29.getType<_i9.FkChainMiddleSetNullChild?>()) {
      return (data != null
              ? _i9.FkChainMiddleSetNullChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _i29.getType<_i10.FkChainRestrictBlocker?>()) {
      return (data != null ? _i10.FkChainRestrictBlocker.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i11.FkChainRoot?>()) {
      return (data != null ? _i11.FkChainRoot.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i12.FkChainSetNullCascadeChild?>()) {
      return (data != null
              ? _i12.FkChainSetNullCascadeChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _i29.getType<_i13.FkChainSetNullMiddle?>()) {
      return (data != null ? _i13.FkChainSetNullMiddle.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i14.FkChainSetNullRestrictChild?>()) {
      return (data != null
              ? _i14.FkChainSetNullRestrictChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _i29.getType<_i15.FkChainSetNullSetNullChild?>()) {
      return (data != null
              ? _i15.FkChainSetNullSetNullChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _i29.getType<_i16.Organization?>()) {
      return (data != null ? _i16.Organization.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i17.Person?>()) {
      return (data != null ? _i17.Person.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i18.RequiredSetNullChild?>()) {
      return (data != null ? _i18.RequiredSetNullChild.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i19.RestrictChild?>()) {
      return (data != null ? _i19.RestrictChild.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i20.Town?>()) {
      return (data != null ? _i20.Town.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i21.Types?>()) {
      return (data != null ? _i21.Types.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i22.TypesEnum?>()) {
      return (data != null ? _i22.TypesEnum.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i23.Unique?>()) {
      return (data != null ? _i23.Unique.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i24.UniqueComposite?>()) {
      return (data != null ? _i24.UniqueComposite.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i25.UniqueDiscriminator?>()) {
      return (data != null ? _i25.UniqueDiscriminator.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i26.UniqueNoRelease?>()) {
      return (data != null ? _i26.UniqueNoRelease.fromJson(data) : null) as T;
    }
    if (t == _i29.getType<_i27.UniqueSetNullChild?>()) {
      return (data != null ? _i27.UniqueSetNullChild.fromJson(data) : null)
          as T;
    }
    if (t == _i29.getType<_i28.UniqueUuid?>()) {
      return (data != null ? _i28.UniqueUuid.fromJson(data) : null) as T;
    }
    if (t == List<_i17.Person>) {
      return (data as List).map((e) => deserialize<_i17.Person>(e)).toList()
          as T;
    }
    if (t == _i29.getType<List<_i17.Person>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<_i17.Person>(e)).toList()
              : null)
          as T;
    }
    if (t == List<_i16.Organization>) {
      return (data as List)
              .map((e) => deserialize<_i16.Organization>(e))
              .toList()
          as T;
    }
    if (t == _i29.getType<List<_i16.Organization>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i16.Organization>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<dynamic>) {
      return (data as List).map((e) => deserialize<dynamic>(e)).toList() as T;
    }
    if (t == dynamic) {
      return deserializeDynamicFieldValue(data) as T;
    }
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i29.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i29.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i4.Address => 'Address',
      _i5.City => 'City',
      _i6.Company => 'Company',
      _i7.FkChainCascadeMiddle => 'FkChainCascadeMiddle',
      _i8.FkChainMiddleCascadeChild => 'FkChainMiddleCascadeChild',
      _i9.FkChainMiddleSetNullChild => 'FkChainMiddleSetNullChild',
      _i10.FkChainRestrictBlocker => 'FkChainRestrictBlocker',
      _i11.FkChainRoot => 'FkChainRoot',
      _i12.FkChainSetNullCascadeChild => 'FkChainSetNullCascadeChild',
      _i13.FkChainSetNullMiddle => 'FkChainSetNullMiddle',
      _i14.FkChainSetNullRestrictChild => 'FkChainSetNullRestrictChild',
      _i15.FkChainSetNullSetNullChild => 'FkChainSetNullSetNullChild',
      _i16.Organization => 'Organization',
      _i17.Person => 'Person',
      _i18.RequiredSetNullChild => 'RequiredSetNullChild',
      _i19.RestrictChild => 'RestrictChild',
      _i20.Town => 'Town',
      _i21.Types => 'Types',
      _i22.TypesEnum => 'TypesEnum',
      _i23.Unique => 'Unique',
      _i24.UniqueComposite => 'UniqueComposite',
      _i25.UniqueDiscriminator => 'UniqueDiscriminator',
      _i26.UniqueNoRelease => 'UniqueNoRelease',
      _i27.UniqueSetNullChild => 'UniqueSetNullChild',
      _i28.UniqueUuid => 'UniqueUuid',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'serverpod_offline_sync_test.',
        '',
      );
    }

    switch (data) {
      case _i4.Address():
        return 'Address';
      case _i5.City():
        return 'City';
      case _i6.Company():
        return 'Company';
      case _i7.FkChainCascadeMiddle():
        return 'FkChainCascadeMiddle';
      case _i8.FkChainMiddleCascadeChild():
        return 'FkChainMiddleCascadeChild';
      case _i9.FkChainMiddleSetNullChild():
        return 'FkChainMiddleSetNullChild';
      case _i10.FkChainRestrictBlocker():
        return 'FkChainRestrictBlocker';
      case _i11.FkChainRoot():
        return 'FkChainRoot';
      case _i12.FkChainSetNullCascadeChild():
        return 'FkChainSetNullCascadeChild';
      case _i13.FkChainSetNullMiddle():
        return 'FkChainSetNullMiddle';
      case _i14.FkChainSetNullRestrictChild():
        return 'FkChainSetNullRestrictChild';
      case _i15.FkChainSetNullSetNullChild():
        return 'FkChainSetNullSetNullChild';
      case _i16.Organization():
        return 'Organization';
      case _i17.Person():
        return 'Person';
      case _i18.RequiredSetNullChild():
        return 'RequiredSetNullChild';
      case _i19.RestrictChild():
        return 'RestrictChild';
      case _i20.Town():
        return 'Town';
      case _i21.Types():
        return 'Types';
      case _i22.TypesEnum():
        return 'TypesEnum';
      case _i23.Unique():
        return 'Unique';
      case _i24.UniqueComposite():
        return 'UniqueComposite';
      case _i25.UniqueDiscriminator():
        return 'UniqueDiscriminator';
      case _i26.UniqueNoRelease():
        return 'UniqueNoRelease';
      case _i27.UniqueSetNullChild():
        return 'UniqueSetNullChild';
      case _i28.UniqueUuid():
        return 'UniqueUuid';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_offline_sync.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'Address') {
      return deserialize<_i4.Address>(data['data']);
    }
    if (dataClassName == 'City') {
      return deserialize<_i5.City>(data['data']);
    }
    if (dataClassName == 'Company') {
      return deserialize<_i6.Company>(data['data']);
    }
    if (dataClassName == 'FkChainCascadeMiddle') {
      return deserialize<_i7.FkChainCascadeMiddle>(data['data']);
    }
    if (dataClassName == 'FkChainMiddleCascadeChild') {
      return deserialize<_i8.FkChainMiddleCascadeChild>(data['data']);
    }
    if (dataClassName == 'FkChainMiddleSetNullChild') {
      return deserialize<_i9.FkChainMiddleSetNullChild>(data['data']);
    }
    if (dataClassName == 'FkChainRestrictBlocker') {
      return deserialize<_i10.FkChainRestrictBlocker>(data['data']);
    }
    if (dataClassName == 'FkChainRoot') {
      return deserialize<_i11.FkChainRoot>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullCascadeChild') {
      return deserialize<_i12.FkChainSetNullCascadeChild>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullMiddle') {
      return deserialize<_i13.FkChainSetNullMiddle>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullRestrictChild') {
      return deserialize<_i14.FkChainSetNullRestrictChild>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullSetNullChild') {
      return deserialize<_i15.FkChainSetNullSetNullChild>(data['data']);
    }
    if (dataClassName == 'Organization') {
      return deserialize<_i16.Organization>(data['data']);
    }
    if (dataClassName == 'Person') {
      return deserialize<_i17.Person>(data['data']);
    }
    if (dataClassName == 'RequiredSetNullChild') {
      return deserialize<_i18.RequiredSetNullChild>(data['data']);
    }
    if (dataClassName == 'RestrictChild') {
      return deserialize<_i19.RestrictChild>(data['data']);
    }
    if (dataClassName == 'Town') {
      return deserialize<_i20.Town>(data['data']);
    }
    if (dataClassName == 'Types') {
      return deserialize<_i21.Types>(data['data']);
    }
    if (dataClassName == 'TypesEnum') {
      return deserialize<_i22.TypesEnum>(data['data']);
    }
    if (dataClassName == 'Unique') {
      return deserialize<_i23.Unique>(data['data']);
    }
    if (dataClassName == 'UniqueComposite') {
      return deserialize<_i24.UniqueComposite>(data['data']);
    }
    if (dataClassName == 'UniqueDiscriminator') {
      return deserialize<_i25.UniqueDiscriminator>(data['data']);
    }
    if (dataClassName == 'UniqueNoRelease') {
      return deserialize<_i26.UniqueNoRelease>(data['data']);
    }
    if (dataClassName == 'UniqueSetNullChild') {
      return deserialize<_i27.UniqueSetNullChild>(data['data']);
    }
    if (dataClassName == 'UniqueUuid') {
      return deserialize<_i28.UniqueUuid>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_offline_sync.')) {
      data['className'] = dataClassName.substring(23);
      return _i3.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _i2.Protocol().registerHostProtocol('serverpod_offline_sync_test', this);
    _i3.Protocol().registerHostProtocol('serverpod_offline_sync_test', this);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var protocol = _i2.Protocol();
      var table = protocol is _i1.DatabaseSerializationManager
          ? (protocol as _i1.DatabaseSerializationManager).getTableForType(t)
          : null;
      if (table != null) {
        return table;
      }
    }
    {
      var protocol = _i3.Protocol();
      var table = protocol is _i1.DatabaseSerializationManager
          ? (protocol as _i1.DatabaseSerializationManager).getTableForType(t)
          : null;
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i4.Address:
        return _i4.Address.t;
      case _i5.City:
        return _i5.City.t;
      case _i6.Company:
        return _i6.Company.t;
      case _i7.FkChainCascadeMiddle:
        return _i7.FkChainCascadeMiddle.t;
      case _i8.FkChainMiddleCascadeChild:
        return _i8.FkChainMiddleCascadeChild.t;
      case _i9.FkChainMiddleSetNullChild:
        return _i9.FkChainMiddleSetNullChild.t;
      case _i10.FkChainRestrictBlocker:
        return _i10.FkChainRestrictBlocker.t;
      case _i11.FkChainRoot:
        return _i11.FkChainRoot.t;
      case _i12.FkChainSetNullCascadeChild:
        return _i12.FkChainSetNullCascadeChild.t;
      case _i13.FkChainSetNullMiddle:
        return _i13.FkChainSetNullMiddle.t;
      case _i14.FkChainSetNullRestrictChild:
        return _i14.FkChainSetNullRestrictChild.t;
      case _i15.FkChainSetNullSetNullChild:
        return _i15.FkChainSetNullSetNullChild.t;
      case _i16.Organization:
        return _i16.Organization.t;
      case _i17.Person:
        return _i17.Person.t;
      case _i18.RequiredSetNullChild:
        return _i18.RequiredSetNullChild.t;
      case _i19.RestrictChild:
        return _i19.RestrictChild.t;
      case _i20.Town:
        return _i20.Town.t;
      case _i21.Types:
        return _i21.Types.t;
      case _i23.Unique:
        return _i23.Unique.t;
      case _i24.UniqueComposite:
        return _i24.UniqueComposite.t;
      case _i25.UniqueDiscriminator:
        return _i25.UniqueDiscriminator.t;
      case _i26.UniqueNoRelease:
        return _i26.UniqueNoRelease.t;
      case _i27.UniqueSetNullChild:
        return _i27.UniqueSetNullChild.t;
      case _i28.UniqueUuid:
        return _i28.UniqueUuid.t;
    }
    return null;
  }

  @override
  List<_i1.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'serverpod_offline_sync_test';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i2.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
