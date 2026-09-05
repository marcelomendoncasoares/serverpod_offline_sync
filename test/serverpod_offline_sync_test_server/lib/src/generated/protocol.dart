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
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart'
    as _izehhkf5;
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart'
    as _i2ap9bqs;
import 'address.dart' as _ilb4pipw;
import 'city.dart' as _ior3absd;
import 'company.dart' as _i6pnc270;
import 'fk_chain/cascade_middle.dart' as _ivwxm81w;
import 'fk_chain/middle_cascade_child.dart' as _ih0wcufc;
import 'fk_chain/middle_set_null_child.dart' as _ifjezkfx;
import 'fk_chain/restrict_blocker.dart' as _i4k28i3g;
import 'fk_chain/root.dart' as _ifk56fcw;
import 'fk_chain/set_null_cascade_child.dart' as _ideurard;
import 'fk_chain/set_null_middle.dart' as _icv70ksq;
import 'fk_chain/set_null_restrict_child.dart' as _ix62gjf0;
import 'fk_chain/set_null_set_null_child.dart' as _ihkyqxiw;
import 'organization.dart' as _irjtvpke;
import 'person.dart' as _iensfz4m;
import 'required_set_null_child.dart' as _i1huw131;
import 'restrict_child.dart' as _isrf0aof;
import 'town.dart' as _iytblq2r;
import 'types.dart' as _iwxwszsz;
import 'types_enum.dart' as _ire5m5mj;
import 'unique.dart' as _ivpwn84u;
import 'unique_cascade_child.dart' as _ixnh46zn;
import 'unique_composite.dart' as _iv4klbbv;
import 'unique_discriminator.dart' as _ixfoa5hm;
import 'unique_no_release.dart' as _i91ey4jd;
import 'unique_set_null_child.dart' as _iy3qfphx;
import 'unique_uuid.dart' as _i5jtfsbn;
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
export 'unique_cascade_child.dart';
export 'unique_composite.dart';
export 'unique_discriminator.dart';
export 'unique_no_release.dart';
export 'unique_set_null_child.dart';
export 'unique_uuid.dart';
export 'sync_tables.dart';

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'address',
      dartName: 'Address',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'street',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'inhabitantId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'address_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'address_fk_1',
          columns: ['inhabitantId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'address__inhabitantId__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'city',
      dartName: 'City',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'city_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'company',
      dartName: 'Company',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'townId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: '\'550e8400-e29b-41d4-a716-446655440000\'',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'company_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'company_fk_1',
          columns: ['townId'],
          referenceTable: 'town',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setDefault,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_cascade_middle',
      dartName: 'FkChainCascadeMiddle',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'rootId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_cascade_middle_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_cascade_middle_fk_1',
          columns: ['rootId'],
          referenceTable: 'fk_chain_root',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_middle_cascade_child',
      dartName: 'FkChainMiddleCascadeChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'restrictBlockerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_cascade_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_cascade_child_fk_1',
          columns: ['restrictBlockerId'],
          referenceTable: 'fk_chain_restrict_blocker',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_middle_set_null_child',
      dartName: 'FkChainMiddleSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'restrictBlockerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_middle_set_null_child_fk_1',
          columns: ['restrictBlockerId'],
          referenceTable: 'fk_chain_restrict_blocker',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_restrict_blocker',
      dartName: 'FkChainRestrictBlocker',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'cascadeMiddleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_restrict_blocker_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_restrict_blocker_fk_1',
          columns: ['cascadeMiddleId'],
          referenceTable: 'fk_chain_cascade_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_root',
      dartName: 'FkChainRoot',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_root_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_set_null_cascade_child',
      dartName: 'FkChainSetNullCascadeChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_cascade_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_cascade_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_set_null_middle',
      dartName: 'FkChainSetNullMiddle',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'cascadeMiddleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_middle_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_middle_fk_1',
          columns: ['cascadeMiddleId'],
          referenceTable: 'fk_chain_cascade_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_set_null_restrict_child',
      dartName: 'FkChainSetNullRestrictChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_restrict_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_restrict_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'fk_chain_set_null_set_null_child',
      dartName: 'FkChainSetNullSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'setNullMiddleId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'fk_chain_set_null_set_null_child_fk_1',
          columns: ['setNullMiddleId'],
          referenceTable: 'fk_chain_set_null_middle',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'organization',
      dartName: 'Organization',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'cityId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'organization_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'organization_fk_1',
          columns: ['cityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'person',
      dartName: 'Person',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'surname',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'organizationId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'oldCompanyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'cityId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'person_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'person_fk_1',
          columns: ['organizationId'],
          referenceTable: 'organization',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'person_fk_2',
          columns: ['oldCompanyId'],
          referenceTable: 'company',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'person_fk_3',
          columns: ['cityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'required_set_null_child',
      dartName: 'RequiredSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'required_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'required_set_null_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'restrict_child',
      dartName: 'RestrictChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'restrict_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'restrict_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.noAction,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'town',
      dartName: 'Town',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'cityId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'mayorId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'town_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'town_fk_1',
          columns: ['cityId'],
          referenceTable: 'city',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'town_fk_2',
          columns: ['mayorId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'types',
      dartName: 'Types',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'aBool',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _isp.ColumnDefinition(
          name: 'aDateTime',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'aText',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'anInt',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'anInt64',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'BigInt',
        ),
        _isp.ColumnDefinition(
          name: 'aReal',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _isp.ColumnDefinition(
          name: 'aBlob',
          columnType: _isp.ColumnType.bytea,
          isNullable: false,
          dartType: 'dart:typed_data:ByteData',
        ),
        _isp.ColumnDefinition(
          name: 'anEnum',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:TypesEnum?',
        ),
        _isp.ColumnDefinition(
          name: 'optionalText',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'optionalUuid',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'types_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'types_a_text_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique',
      dartName: 'Unique',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique__scopeId__name__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_cascade_child',
      dartName: 'UniqueCascadeChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_cascade_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_cascade_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique_cascade_child__scopeId__name__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_composite',
      dartName: 'UniqueComposite',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'scope',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'value',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_composite_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique_composite__scopeId__scope__value__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scope',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_discriminator',
      dartName: 'UniqueDiscriminator',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'categoryId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_discriminator_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName:
              'unique_discriminator__scopeId__categoryId__name__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'categoryId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_no_release',
      dartName: 'UniqueNoRelease',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'categoryId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_no_release_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique_no_release__scopeId__categoryId__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_set_null_child',
      dartName: 'UniqueSetNullChild',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_set_null_child_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_set_null_child_fk_1',
          columns: ['parentId'],
          referenceTable: 'person',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
          deferrable: _isp.DeferrableConstraint.initiallyDeferred,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique_set_null_child__parentId__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    _isp.TableDefinition(
      name: 'unique_uuid',
      dartName: 'UniqueUuid',
      schema: 'public',
      module: 'serverpod_offline_sync_test',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'scopeId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'value',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'unique_uuid_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'unique_uuid__scopeId__value__unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
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
    ..._iacs.Protocol.targetTableDefinitions,
    ..._izehhkf5.Protocol.targetTableDefinitions,
    ..._i2ap9bqs.Protocol() is _is.DatabaseSerializationManager
        ? (_i2ap9bqs.Protocol() as _is.DatabaseSerializationManager)
              .getTargetTableDefinitions()
        : [],
    ..._isp.Protocol.targetTableDefinitions,
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
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _ilb4pipw.Address) {
      return _ilb4pipw.Address.fromJson(data) as T;
    }
    if (t == _ior3absd.City) {
      return _ior3absd.City.fromJson(data) as T;
    }
    if (t == _i6pnc270.Company) {
      return _i6pnc270.Company.fromJson(data) as T;
    }
    if (t == _ivwxm81w.FkChainCascadeMiddle) {
      return _ivwxm81w.FkChainCascadeMiddle.fromJson(data) as T;
    }
    if (t == _ih0wcufc.FkChainMiddleCascadeChild) {
      return _ih0wcufc.FkChainMiddleCascadeChild.fromJson(data) as T;
    }
    if (t == _ifjezkfx.FkChainMiddleSetNullChild) {
      return _ifjezkfx.FkChainMiddleSetNullChild.fromJson(data) as T;
    }
    if (t == _i4k28i3g.FkChainRestrictBlocker) {
      return _i4k28i3g.FkChainRestrictBlocker.fromJson(data) as T;
    }
    if (t == _ifk56fcw.FkChainRoot) {
      return _ifk56fcw.FkChainRoot.fromJson(data) as T;
    }
    if (t == _ideurard.FkChainSetNullCascadeChild) {
      return _ideurard.FkChainSetNullCascadeChild.fromJson(data) as T;
    }
    if (t == _icv70ksq.FkChainSetNullMiddle) {
      return _icv70ksq.FkChainSetNullMiddle.fromJson(data) as T;
    }
    if (t == _ix62gjf0.FkChainSetNullRestrictChild) {
      return _ix62gjf0.FkChainSetNullRestrictChild.fromJson(data) as T;
    }
    if (t == _ihkyqxiw.FkChainSetNullSetNullChild) {
      return _ihkyqxiw.FkChainSetNullSetNullChild.fromJson(data) as T;
    }
    if (t == _irjtvpke.Organization) {
      return _irjtvpke.Organization.fromJson(data) as T;
    }
    if (t == _iensfz4m.Person) {
      return _iensfz4m.Person.fromJson(data) as T;
    }
    if (t == _i1huw131.RequiredSetNullChild) {
      return _i1huw131.RequiredSetNullChild.fromJson(data) as T;
    }
    if (t == _isrf0aof.RestrictChild) {
      return _isrf0aof.RestrictChild.fromJson(data) as T;
    }
    if (t == _iytblq2r.Town) {
      return _iytblq2r.Town.fromJson(data) as T;
    }
    if (t == _iwxwszsz.Types) {
      return _iwxwszsz.Types.fromJson(data) as T;
    }
    if (t == _ire5m5mj.TypesEnum) {
      return _ire5m5mj.TypesEnum.fromJson(data) as T;
    }
    if (t == _ivpwn84u.Unique) {
      return _ivpwn84u.Unique.fromJson(data) as T;
    }
    if (t == _ixnh46zn.UniqueCascadeChild) {
      return _ixnh46zn.UniqueCascadeChild.fromJson(data) as T;
    }
    if (t == _iv4klbbv.UniqueComposite) {
      return _iv4klbbv.UniqueComposite.fromJson(data) as T;
    }
    if (t == _ixfoa5hm.UniqueDiscriminator) {
      return _ixfoa5hm.UniqueDiscriminator.fromJson(data) as T;
    }
    if (t == _i91ey4jd.UniqueNoRelease) {
      return _i91ey4jd.UniqueNoRelease.fromJson(data) as T;
    }
    if (t == _iy3qfphx.UniqueSetNullChild) {
      return _iy3qfphx.UniqueSetNullChild.fromJson(data) as T;
    }
    if (t == _i5jtfsbn.UniqueUuid) {
      return _i5jtfsbn.UniqueUuid.fromJson(data) as T;
    }
    if (t == _is.getType<_ilb4pipw.Address?>()) {
      return (data != null ? _ilb4pipw.Address.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ior3absd.City?>()) {
      return (data != null ? _ior3absd.City.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i6pnc270.Company?>()) {
      return (data != null ? _i6pnc270.Company.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ivwxm81w.FkChainCascadeMiddle?>()) {
      return (data != null
              ? _ivwxm81w.FkChainCascadeMiddle.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ih0wcufc.FkChainMiddleCascadeChild?>()) {
      return (data != null
              ? _ih0wcufc.FkChainMiddleCascadeChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ifjezkfx.FkChainMiddleSetNullChild?>()) {
      return (data != null
              ? _ifjezkfx.FkChainMiddleSetNullChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i4k28i3g.FkChainRestrictBlocker?>()) {
      return (data != null
              ? _i4k28i3g.FkChainRestrictBlocker.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ifk56fcw.FkChainRoot?>()) {
      return (data != null ? _ifk56fcw.FkChainRoot.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ideurard.FkChainSetNullCascadeChild?>()) {
      return (data != null
              ? _ideurard.FkChainSetNullCascadeChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_icv70ksq.FkChainSetNullMiddle?>()) {
      return (data != null
              ? _icv70ksq.FkChainSetNullMiddle.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ix62gjf0.FkChainSetNullRestrictChild?>()) {
      return (data != null
              ? _ix62gjf0.FkChainSetNullRestrictChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ihkyqxiw.FkChainSetNullSetNullChild?>()) {
      return (data != null
              ? _ihkyqxiw.FkChainSetNullSetNullChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_irjtvpke.Organization?>()) {
      return (data != null ? _irjtvpke.Organization.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iensfz4m.Person?>()) {
      return (data != null ? _iensfz4m.Person.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i1huw131.RequiredSetNullChild?>()) {
      return (data != null
              ? _i1huw131.RequiredSetNullChild.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_isrf0aof.RestrictChild?>()) {
      return (data != null ? _isrf0aof.RestrictChild.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iytblq2r.Town?>()) {
      return (data != null ? _iytblq2r.Town.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iwxwszsz.Types?>()) {
      return (data != null ? _iwxwszsz.Types.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ire5m5mj.TypesEnum?>()) {
      return (data != null ? _ire5m5mj.TypesEnum.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ivpwn84u.Unique?>()) {
      return (data != null ? _ivpwn84u.Unique.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ixnh46zn.UniqueCascadeChild?>()) {
      return (data != null ? _ixnh46zn.UniqueCascadeChild.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iv4klbbv.UniqueComposite?>()) {
      return (data != null ? _iv4klbbv.UniqueComposite.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ixfoa5hm.UniqueDiscriminator?>()) {
      return (data != null
              ? _ixfoa5hm.UniqueDiscriminator.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i91ey4jd.UniqueNoRelease?>()) {
      return (data != null ? _i91ey4jd.UniqueNoRelease.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iy3qfphx.UniqueSetNullChild?>()) {
      return (data != null ? _iy3qfphx.UniqueSetNullChild.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i5jtfsbn.UniqueUuid?>()) {
      return (data != null ? _i5jtfsbn.UniqueUuid.fromJson(data) : null) as T;
    }
    if (t == List<_iensfz4m.Person>) {
      return (data as List)
              .map((e) => deserialize<_iensfz4m.Person>(e))
              .toList()
          as T;
    }
    if (t == _is.getType<List<_iensfz4m.Person>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_iensfz4m.Person>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_irjtvpke.Organization>) {
      return (data as List)
              .map((e) => deserialize<_irjtvpke.Organization>(e))
              .toList()
          as T;
    }
    if (t == _is.getType<List<_irjtvpke.Organization>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_irjtvpke.Organization>(e))
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
      return _iacs.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _izehhkf5.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2ap9bqs.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ilb4pipw.Address => 'Address',
      _ior3absd.City => 'City',
      _i6pnc270.Company => 'Company',
      _ivwxm81w.FkChainCascadeMiddle => 'FkChainCascadeMiddle',
      _ih0wcufc.FkChainMiddleCascadeChild => 'FkChainMiddleCascadeChild',
      _ifjezkfx.FkChainMiddleSetNullChild => 'FkChainMiddleSetNullChild',
      _i4k28i3g.FkChainRestrictBlocker => 'FkChainRestrictBlocker',
      _ifk56fcw.FkChainRoot => 'FkChainRoot',
      _ideurard.FkChainSetNullCascadeChild => 'FkChainSetNullCascadeChild',
      _icv70ksq.FkChainSetNullMiddle => 'FkChainSetNullMiddle',
      _ix62gjf0.FkChainSetNullRestrictChild => 'FkChainSetNullRestrictChild',
      _ihkyqxiw.FkChainSetNullSetNullChild => 'FkChainSetNullSetNullChild',
      _irjtvpke.Organization => 'Organization',
      _iensfz4m.Person => 'Person',
      _i1huw131.RequiredSetNullChild => 'RequiredSetNullChild',
      _isrf0aof.RestrictChild => 'RestrictChild',
      _iytblq2r.Town => 'Town',
      _iwxwszsz.Types => 'Types',
      _ire5m5mj.TypesEnum => 'TypesEnum',
      _ivpwn84u.Unique => 'Unique',
      _ixnh46zn.UniqueCascadeChild => 'UniqueCascadeChild',
      _iv4klbbv.UniqueComposite => 'UniqueComposite',
      _ixfoa5hm.UniqueDiscriminator => 'UniqueDiscriminator',
      _i91ey4jd.UniqueNoRelease => 'UniqueNoRelease',
      _iy3qfphx.UniqueSetNullChild => 'UniqueSetNullChild',
      _i5jtfsbn.UniqueUuid => 'UniqueUuid',
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
      case _ilb4pipw.Address():
        return 'Address';
      case _ior3absd.City():
        return 'City';
      case _i6pnc270.Company():
        return 'Company';
      case _ivwxm81w.FkChainCascadeMiddle():
        return 'FkChainCascadeMiddle';
      case _ih0wcufc.FkChainMiddleCascadeChild():
        return 'FkChainMiddleCascadeChild';
      case _ifjezkfx.FkChainMiddleSetNullChild():
        return 'FkChainMiddleSetNullChild';
      case _i4k28i3g.FkChainRestrictBlocker():
        return 'FkChainRestrictBlocker';
      case _ifk56fcw.FkChainRoot():
        return 'FkChainRoot';
      case _ideurard.FkChainSetNullCascadeChild():
        return 'FkChainSetNullCascadeChild';
      case _icv70ksq.FkChainSetNullMiddle():
        return 'FkChainSetNullMiddle';
      case _ix62gjf0.FkChainSetNullRestrictChild():
        return 'FkChainSetNullRestrictChild';
      case _ihkyqxiw.FkChainSetNullSetNullChild():
        return 'FkChainSetNullSetNullChild';
      case _irjtvpke.Organization():
        return 'Organization';
      case _iensfz4m.Person():
        return 'Person';
      case _i1huw131.RequiredSetNullChild():
        return 'RequiredSetNullChild';
      case _isrf0aof.RestrictChild():
        return 'RestrictChild';
      case _iytblq2r.Town():
        return 'Town';
      case _iwxwszsz.Types():
        return 'Types';
      case _ire5m5mj.TypesEnum():
        return 'TypesEnum';
      case _ivpwn84u.Unique():
        return 'Unique';
      case _ixnh46zn.UniqueCascadeChild():
        return 'UniqueCascadeChild';
      case _iv4klbbv.UniqueComposite():
        return 'UniqueComposite';
      case _ixfoa5hm.UniqueDiscriminator():
        return 'UniqueDiscriminator';
      case _i91ey4jd.UniqueNoRelease():
        return 'UniqueNoRelease';
      case _iy3qfphx.UniqueSetNullChild():
        return 'UniqueSetNullChild';
      case _i5jtfsbn.UniqueUuid():
        return 'UniqueUuid';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _izehhkf5.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_offline_sync.$className';
    }
    className = _i2ap9bqs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_offline_sync_test_shared.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
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
      return deserialize<_ilb4pipw.Address>(data['data']);
    }
    if (dataClassName == 'City') {
      return deserialize<_ior3absd.City>(data['data']);
    }
    if (dataClassName == 'Company') {
      return deserialize<_i6pnc270.Company>(data['data']);
    }
    if (dataClassName == 'FkChainCascadeMiddle') {
      return deserialize<_ivwxm81w.FkChainCascadeMiddle>(data['data']);
    }
    if (dataClassName == 'FkChainMiddleCascadeChild') {
      return deserialize<_ih0wcufc.FkChainMiddleCascadeChild>(data['data']);
    }
    if (dataClassName == 'FkChainMiddleSetNullChild') {
      return deserialize<_ifjezkfx.FkChainMiddleSetNullChild>(data['data']);
    }
    if (dataClassName == 'FkChainRestrictBlocker') {
      return deserialize<_i4k28i3g.FkChainRestrictBlocker>(data['data']);
    }
    if (dataClassName == 'FkChainRoot') {
      return deserialize<_ifk56fcw.FkChainRoot>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullCascadeChild') {
      return deserialize<_ideurard.FkChainSetNullCascadeChild>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullMiddle') {
      return deserialize<_icv70ksq.FkChainSetNullMiddle>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullRestrictChild') {
      return deserialize<_ix62gjf0.FkChainSetNullRestrictChild>(data['data']);
    }
    if (dataClassName == 'FkChainSetNullSetNullChild') {
      return deserialize<_ihkyqxiw.FkChainSetNullSetNullChild>(data['data']);
    }
    if (dataClassName == 'Organization') {
      return deserialize<_irjtvpke.Organization>(data['data']);
    }
    if (dataClassName == 'Person') {
      return deserialize<_iensfz4m.Person>(data['data']);
    }
    if (dataClassName == 'RequiredSetNullChild') {
      return deserialize<_i1huw131.RequiredSetNullChild>(data['data']);
    }
    if (dataClassName == 'RestrictChild') {
      return deserialize<_isrf0aof.RestrictChild>(data['data']);
    }
    if (dataClassName == 'Town') {
      return deserialize<_iytblq2r.Town>(data['data']);
    }
    if (dataClassName == 'Types') {
      return deserialize<_iwxwszsz.Types>(data['data']);
    }
    if (dataClassName == 'TypesEnum') {
      return deserialize<_ire5m5mj.TypesEnum>(data['data']);
    }
    if (dataClassName == 'Unique') {
      return deserialize<_ivpwn84u.Unique>(data['data']);
    }
    if (dataClassName == 'UniqueCascadeChild') {
      return deserialize<_ixnh46zn.UniqueCascadeChild>(data['data']);
    }
    if (dataClassName == 'UniqueComposite') {
      return deserialize<_iv4klbbv.UniqueComposite>(data['data']);
    }
    if (dataClassName == 'UniqueDiscriminator') {
      return deserialize<_ixfoa5hm.UniqueDiscriminator>(data['data']);
    }
    if (dataClassName == 'UniqueNoRelease') {
      return deserialize<_i91ey4jd.UniqueNoRelease>(data['data']);
    }
    if (dataClassName == 'UniqueSetNullChild') {
      return deserialize<_iy3qfphx.UniqueSetNullChild>(data['data']);
    }
    if (dataClassName == 'UniqueUuid') {
      return deserialize<_i5jtfsbn.UniqueUuid>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_offline_sync.')) {
      data['className'] = dataClassName.substring(23);
      return _izehhkf5.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_offline_sync_test_shared.')) {
      data['className'] = dataClassName.substring(35);
      return _i2ap9bqs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iacs.Protocol().registerHostProtocol('serverpod_offline_sync_test', this);
    _izehhkf5.Protocol().registerHostProtocol(
      'serverpod_offline_sync_test',
      this,
    );
    _i2ap9bqs.Protocol().registerHostProtocol(
      'serverpod_offline_sync_test',
      this,
    );
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _izehhkf5.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var protocol = _i2ap9bqs.Protocol();
      var table = protocol is _is.DatabaseSerializationManager
          ? (protocol as _is.DatabaseSerializationManager).getTableForType(t)
          : null;
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _ilb4pipw.Address:
        return _ilb4pipw.Address.t;
      case _ior3absd.City:
        return _ior3absd.City.t;
      case _i6pnc270.Company:
        return _i6pnc270.Company.t;
      case _ivwxm81w.FkChainCascadeMiddle:
        return _ivwxm81w.FkChainCascadeMiddle.t;
      case _ih0wcufc.FkChainMiddleCascadeChild:
        return _ih0wcufc.FkChainMiddleCascadeChild.t;
      case _ifjezkfx.FkChainMiddleSetNullChild:
        return _ifjezkfx.FkChainMiddleSetNullChild.t;
      case _i4k28i3g.FkChainRestrictBlocker:
        return _i4k28i3g.FkChainRestrictBlocker.t;
      case _ifk56fcw.FkChainRoot:
        return _ifk56fcw.FkChainRoot.t;
      case _ideurard.FkChainSetNullCascadeChild:
        return _ideurard.FkChainSetNullCascadeChild.t;
      case _icv70ksq.FkChainSetNullMiddle:
        return _icv70ksq.FkChainSetNullMiddle.t;
      case _ix62gjf0.FkChainSetNullRestrictChild:
        return _ix62gjf0.FkChainSetNullRestrictChild.t;
      case _ihkyqxiw.FkChainSetNullSetNullChild:
        return _ihkyqxiw.FkChainSetNullSetNullChild.t;
      case _irjtvpke.Organization:
        return _irjtvpke.Organization.t;
      case _iensfz4m.Person:
        return _iensfz4m.Person.t;
      case _i1huw131.RequiredSetNullChild:
        return _i1huw131.RequiredSetNullChild.t;
      case _isrf0aof.RestrictChild:
        return _isrf0aof.RestrictChild.t;
      case _iytblq2r.Town:
        return _iytblq2r.Town.t;
      case _iwxwszsz.Types:
        return _iwxwszsz.Types.t;
      case _ivpwn84u.Unique:
        return _ivpwn84u.Unique.t;
      case _ixnh46zn.UniqueCascadeChild:
        return _ixnh46zn.UniqueCascadeChild.t;
      case _iv4klbbv.UniqueComposite:
        return _iv4klbbv.UniqueComposite.t;
      case _ixfoa5hm.UniqueDiscriminator:
        return _ixfoa5hm.UniqueDiscriminator.t;
      case _i91ey4jd.UniqueNoRelease:
        return _i91ey4jd.UniqueNoRelease.t;
      case _iy3qfphx.UniqueSetNullChild:
        return _iy3qfphx.UniqueSetNullChild.t;
      case _i5jtfsbn.UniqueUuid:
        return _i5jtfsbn.UniqueUuid.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
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
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _izehhkf5.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
