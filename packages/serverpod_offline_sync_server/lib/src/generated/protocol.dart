/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/protocol.dart' as _i2;
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as _i23;

import 'data/deleted.dart' as _i3;
import 'data/deleted_reason.dart' as _i4;
import 'data/field.dart' as _i5;
import 'data/foreign_key.dart' as _i6;
import 'data/foreign_key_override_reason.dart' as _i7;
import 'data/row.dart' as _i8;
import 'data/row_visibility.dart' as _i9;
import 'merge/change.dart' as _i10;
import 'node/node.dart' as _i11;
import 'node/scope.dart' as _i12;
import 'node/scope_member.dart' as _i13;
import 'node/scope_node.dart' as _i14;
import 'node/scope_role.dart' as _i15;
import 'schema/column.dart' as _i16;
import 'schema/table.dart' as _i17;
import 'sync/scope_grant.dart' as _i19;
import 'sync/stream_event.dart' as _i18;
import 'sync/violation.dart' as _i20;
import 'sync/violation_operation.dart' as _i21;
import 'sync/violation_type.dart' as _i22;

export 'data/deleted.dart';
export 'data/deleted_reason.dart';
export 'data/field.dart';
export 'data/foreign_key.dart';
export 'data/foreign_key_override_reason.dart';
export 'data/row.dart';
export 'data/row_visibility.dart';
export 'merge/change.dart';
export 'node/node.dart';
export 'node/scope.dart';
export 'node/scope_member.dart';
export 'node/scope_node.dart';
export 'node/scope_role.dart';
export 'schema/column.dart';
export 'schema/table.dart';
export 'sync/scope_grant.dart';
export 'sync/stream_event.dart';
export 'sync/violation.dart';
export 'sync/violation_operation.dart';
export 'sync/violation_type.dart';

class Protocol extends _i1.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'crdt_data_fields',
      dartName: 'CrdtDataField',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'rowId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'columnId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'nodeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_0',
          columns: ['rowId'],
          referenceTable: 'crdt_data_rows',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_1',
          columns: ['columnId'],
          referenceTable: 'crdt_schema_columns',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_2',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_data_fields_row_column_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'columnId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_data_foreign_key',
      dartName: 'CrdtDataForeignKey',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'fieldId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'attemptedValue',
          columnType: _i2.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i2.ColumnDefinition(
          name: 'visibleValue',
          columnType: _i2.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i2.ColumnDefinition(
          name: 'overrideReason',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:CrdtForeignKeyOverrideReason?',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_foreign_key_fk_0',
          columns: ['fieldId'],
          referenceTable: 'crdt_data_fields',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_data_foreign_key_field_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'fieldId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_data_rows',
      dartName: 'CrdtDataRow',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'scopeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'tblId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'uuidRowId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'nodeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'visibility',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'protocol:CrdtDataRowVisibility',
          columnDefault: '0',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_1',
          columns: ['tblId'],
          referenceTable: 'crdt_schema_tables',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_2',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_data_rows_scope_tbl_row_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tblId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'uuidRowId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_data_tombstone',
      dartName: 'CrdtDataDeleted',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'rowId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'nodeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'clFlag',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'reason',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'protocol:CrdtDataDeletedReason',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_tombstone_fk_0',
          columns: ['rowId'],
          referenceTable: 'crdt_data_rows',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_data_tombstone_fk_1',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_data_tombstone_row_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_nodes',
      dartName: 'CrdtNode',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'uuidNodeId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _i2.ColumnDefinition(
          name: 'lastHlc',
          columnType: _i2.ColumnType.jsonb,
          isNullable: true,
          dartType:
              'package:serverpod_offline_sync/serverpod_offline_sync.dart:Hlc?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_nodes__uuidNodeId__unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'uuidNodeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_schema_columns',
      dartName: 'CrdtSchemaColumn',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'tblId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_schema_columns_fk_0',
          columns: ['tblId'],
          referenceTable: 'crdt_schema_tables',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_schema_columns_table_column_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'tblId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
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
    _i2.TableDefinition(
      name: 'crdt_schema_tables',
      dartName: 'CrdtSchemaTable',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_schema_tables__name__unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
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
    _i2.TableDefinition(
      name: 'crdt_scope_members',
      dartName: 'CrdtScopeMember',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'scopeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'userUuid',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'role',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:CrdtScopeRole',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_scope_members_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_scope_member_unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'userUuid',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_scope_nodes',
      dartName: 'CrdtScopeNode',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'scopeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'nodeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'lastReceivedHlc',
          columnType: _i2.ColumnType.jsonb,
          isNullable: true,
          dartType:
              'package:serverpod_offline_sync/serverpod_offline_sync.dart:Hlc?',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_scope_nodes_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_scope_nodes_fk_1',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_scope_node_unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'nodeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_scopes',
      dartName: 'CrdtScope',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'uuidScopeId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _i2.ColumnDefinition(
          name: 'currentNodeId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
      ],
      foreignKeys: [
        _i2.ForeignKeyDefinition(
          constraintName: 'crdt_scopes_fk_0',
          columns: ['currentNodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _i2.ForeignKeyAction.noAction,
          onDelete: _i2.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_scopes__uuidScopeId__unique_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'uuidScopeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'crdt_sync_integrity_violations',
      dartName: 'CrdtSyncIntegrityViolation',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _i2.ColumnDefinition(
          name: 'type',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:CrdtSyncViolationType',
        ),
        _i2.ColumnDefinition(
          name: 'domainTableName',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'uuidRowId',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'ownerScopeUuid',
          columnType: _i2.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i2.ColumnDefinition(
          name: 'incomingScopeUuid',
          columnType: _i2.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _i2.ColumnDefinition(
          name: 'operation',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:CrdtSyncViolationOperation',
        ),
        _i2.ColumnDefinition(
          name: 'uuidNodeId',
          columnType: _i2.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _i2.ColumnDefinition(
          name: 'crdtDataRowId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'firstSeenAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'lastSeenAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _i2.ColumnDefinition(
          name: 'occurrences',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'crdt_sync_integrity_violations_key_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'type',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'operation',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'domainTableName',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'uuidRowId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'ownerScopeUuid',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'incomingScopeUuid',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
  ];

  final Set<_i1.SerializationManager> _hostProtocols = {};

  void registerHostProtocol(
    String projectName,
    _i1.SerializationManager protocol,
  ) {
    _hostProtocols.add(protocol);
  }

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    if (className == null) return null;
    if (!className.startsWith('serverpod_offline_sync.')) return className;
    return className.substring(23);
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

    if (t == _i3.CrdtDataDeleted) {
      return _i3.CrdtDataDeleted.fromJson(data) as T;
    }
    if (t == _i4.CrdtDataDeletedReason) {
      return _i4.CrdtDataDeletedReason.fromJson(data) as T;
    }
    if (t == _i5.CrdtDataField) {
      return _i5.CrdtDataField.fromJson(data) as T;
    }
    if (t == _i6.CrdtDataForeignKey) {
      return _i6.CrdtDataForeignKey.fromJson(data) as T;
    }
    if (t == _i7.CrdtForeignKeyOverrideReason) {
      return _i7.CrdtForeignKeyOverrideReason.fromJson(data) as T;
    }
    if (t == _i8.CrdtDataRow) {
      return _i8.CrdtDataRow.fromJson(data) as T;
    }
    if (t == _i9.CrdtDataRowVisibility) {
      return _i9.CrdtDataRowVisibility.fromJson(data) as T;
    }
    if (t == _i10.CrdtMergeDelete) {
      return _i10.CrdtMergeDelete.fromJson(data) as T;
    }
    if (t == _i10.CrdtMergeInsert) {
      return _i10.CrdtMergeInsert.fromJson(data) as T;
    }
    if (t == _i10.CrdtMergeUpdate) {
      return _i10.CrdtMergeUpdate.fromJson(data) as T;
    }
    if (t == _i11.CrdtNode) {
      return _i11.CrdtNode.fromJson(data) as T;
    }
    if (t == _i12.CrdtScope) {
      return _i12.CrdtScope.fromJson(data) as T;
    }
    if (t == _i13.CrdtScopeMember) {
      return _i13.CrdtScopeMember.fromJson(data) as T;
    }
    if (t == _i14.CrdtScopeNode) {
      return _i14.CrdtScopeNode.fromJson(data) as T;
    }
    if (t == _i15.CrdtScopeRole) {
      return _i15.CrdtScopeRole.fromJson(data) as T;
    }
    if (t == _i16.CrdtSchemaColumn) {
      return _i16.CrdtSchemaColumn.fromJson(data) as T;
    }
    if (t == _i17.CrdtSchemaTable) {
      return _i17.CrdtSchemaTable.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncClose) {
      return _i18.CrdtSyncClose.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncConnect) {
      return _i18.CrdtSyncConnect.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncEndOfBatch) {
      return _i18.CrdtSyncEndOfBatch.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncMergeChunk) {
      return _i18.CrdtSyncMergeChunk.fromJson(data) as T;
    }
    if (t == _i19.CrdtScopeGrant) {
      return _i19.CrdtScopeGrant.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncScopeSet) {
      return _i18.CrdtSyncScopeSet.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncSinceHlc) {
      return _i18.CrdtSyncSinceHlc.fromJson(data) as T;
    }
    if (t == _i18.CrdtSyncIdleTimeout) {
      return _i18.CrdtSyncIdleTimeout.fromJson(data) as T;
    }
    if (t == _i20.CrdtSyncIntegrityViolation) {
      return _i20.CrdtSyncIntegrityViolation.fromJson(data) as T;
    }
    if (t == _i21.CrdtSyncViolationOperation) {
      return _i21.CrdtSyncViolationOperation.fromJson(data) as T;
    }
    if (t == _i22.CrdtSyncViolationType) {
      return _i22.CrdtSyncViolationType.fromJson(data) as T;
    }
    if (t == _i1.getType<_i3.CrdtDataDeleted?>()) {
      return (data != null ? _i3.CrdtDataDeleted.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.CrdtDataDeletedReason?>()) {
      return (data != null ? _i4.CrdtDataDeletedReason.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i5.CrdtDataField?>()) {
      return (data != null ? _i5.CrdtDataField.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.CrdtDataForeignKey?>()) {
      return (data != null ? _i6.CrdtDataForeignKey.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.CrdtForeignKeyOverrideReason?>()) {
      return (data != null
              ? _i7.CrdtForeignKeyOverrideReason.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i8.CrdtDataRow?>()) {
      return (data != null ? _i8.CrdtDataRow.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.CrdtDataRowVisibility?>()) {
      return (data != null ? _i9.CrdtDataRowVisibility.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i10.CrdtMergeDelete?>()) {
      return (data != null ? _i10.CrdtMergeDelete.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.CrdtMergeInsert?>()) {
      return (data != null ? _i10.CrdtMergeInsert.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.CrdtMergeUpdate?>()) {
      return (data != null ? _i10.CrdtMergeUpdate.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.CrdtNode?>()) {
      return (data != null ? _i11.CrdtNode.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.CrdtScope?>()) {
      return (data != null ? _i12.CrdtScope.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.CrdtScopeMember?>()) {
      return (data != null ? _i13.CrdtScopeMember.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.CrdtScopeNode?>()) {
      return (data != null ? _i14.CrdtScopeNode.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.CrdtScopeRole?>()) {
      return (data != null ? _i15.CrdtScopeRole.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.CrdtSchemaColumn?>()) {
      return (data != null ? _i16.CrdtSchemaColumn.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i17.CrdtSchemaTable?>()) {
      return (data != null ? _i17.CrdtSchemaTable.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncClose?>()) {
      return (data != null ? _i18.CrdtSyncClose.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncConnect?>()) {
      return (data != null ? _i18.CrdtSyncConnect.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncEndOfBatch?>()) {
      return (data != null ? _i18.CrdtSyncEndOfBatch.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncMergeChunk?>()) {
      return (data != null ? _i18.CrdtSyncMergeChunk.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i19.CrdtScopeGrant?>()) {
      return (data != null ? _i19.CrdtScopeGrant.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncScopeSet?>()) {
      return (data != null ? _i18.CrdtSyncScopeSet.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncSinceHlc?>()) {
      return (data != null ? _i18.CrdtSyncSinceHlc.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i18.CrdtSyncIdleTimeout?>()) {
      return (data != null ? _i18.CrdtSyncIdleTimeout.fromJson(data) : null)
          as T;
    }
    if (t == _i1.getType<_i20.CrdtSyncIntegrityViolation?>()) {
      return (data != null
              ? _i20.CrdtSyncIntegrityViolation.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i21.CrdtSyncViolationOperation?>()) {
      return (data != null
              ? _i21.CrdtSyncViolationOperation.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i22.CrdtSyncViolationType?>()) {
      return (data != null ? _i22.CrdtSyncViolationType.fromJson(data) : null)
          as T;
    }
    if (t == List<_i5.CrdtDataField>) {
      return (data as List)
              .map((e) => deserialize<_i5.CrdtDataField>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i5.CrdtDataField>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i5.CrdtDataField>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == dynamic) {
      return deserializeDynamicFieldValue(data) as T;
    }
    if (t == _i1.getType<_i23.Hlc?>()) {
      return (data != null ? _i23.Hlc.fromJson(data) : null) as T;
    }
    if (t == List<_i14.CrdtScopeNode>) {
      return (data as List)
              .map((e) => deserialize<_i14.CrdtScopeNode>(e))
              .toList()
          as T;
    }
    if (t == _i1.getType<List<_i14.CrdtScopeNode>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i14.CrdtScopeNode>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i10.CrdtMergeChange>) {
      return (data as List)
              .map((e) => deserialize<_i10.CrdtMergeChange>(e))
              .toList()
          as T;
    }
    if (t == List<_i19.CrdtScopeGrant>) {
      return (data as List)
              .map((e) => deserialize<_i19.CrdtScopeGrant>(e))
              .toList()
          as T;
    }
    if (t == List<_i23.Hlc>) {
      return (data as List).map((e) => deserialize<_i23.Hlc>(e)).toList() as T;
    }
    if (t == _i23.Hlc) {
      return _i23.Hlc.fromJson(data) as T;
    }
    if (t == _i1.getType<_i23.Hlc?>()) {
      return (data != null ? _i23.Hlc.fromJson(data) : null) as T;
    }
    try {
      return _i23.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i23.Hlc => 'Hlc',
      _i3.CrdtDataDeleted => 'CrdtDataDeleted',
      _i4.CrdtDataDeletedReason => 'CrdtDataDeletedReason',
      _i5.CrdtDataField => 'CrdtDataField',
      _i6.CrdtDataForeignKey => 'CrdtDataForeignKey',
      _i7.CrdtForeignKeyOverrideReason => 'CrdtForeignKeyOverrideReason',
      _i8.CrdtDataRow => 'CrdtDataRow',
      _i9.CrdtDataRowVisibility => 'CrdtDataRowVisibility',
      _i10.CrdtMergeDelete => 'CrdtMergeDelete',
      _i10.CrdtMergeInsert => 'CrdtMergeInsert',
      _i10.CrdtMergeUpdate => 'CrdtMergeUpdate',
      _i11.CrdtNode => 'CrdtNode',
      _i12.CrdtScope => 'CrdtScope',
      _i13.CrdtScopeMember => 'CrdtScopeMember',
      _i14.CrdtScopeNode => 'CrdtScopeNode',
      _i15.CrdtScopeRole => 'CrdtScopeRole',
      _i16.CrdtSchemaColumn => 'CrdtSchemaColumn',
      _i17.CrdtSchemaTable => 'CrdtSchemaTable',
      _i18.CrdtSyncClose => 'CrdtSyncClose',
      _i18.CrdtSyncConnect => 'CrdtSyncConnect',
      _i18.CrdtSyncEndOfBatch => 'CrdtSyncEndOfBatch',
      _i18.CrdtSyncMergeChunk => 'CrdtSyncMergeChunk',
      _i19.CrdtScopeGrant => 'CrdtScopeGrant',
      _i18.CrdtSyncScopeSet => 'CrdtSyncScopeSet',
      _i18.CrdtSyncSinceHlc => 'CrdtSyncSinceHlc',
      _i18.CrdtSyncIdleTimeout => 'CrdtSyncIdleTimeout',
      _i20.CrdtSyncIntegrityViolation => 'CrdtSyncIntegrityViolation',
      _i21.CrdtSyncViolationOperation => 'CrdtSyncViolationOperation',
      _i22.CrdtSyncViolationType => 'CrdtSyncViolationType',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'serverpod_offline_sync.',
        '',
      );
    }

    switch (data) {
      case _i23.Hlc():
        return 'Hlc';
      case _i3.CrdtDataDeleted():
        return 'CrdtDataDeleted';
      case _i4.CrdtDataDeletedReason():
        return 'CrdtDataDeletedReason';
      case _i5.CrdtDataField():
        return 'CrdtDataField';
      case _i6.CrdtDataForeignKey():
        return 'CrdtDataForeignKey';
      case _i7.CrdtForeignKeyOverrideReason():
        return 'CrdtForeignKeyOverrideReason';
      case _i8.CrdtDataRow():
        return 'CrdtDataRow';
      case _i9.CrdtDataRowVisibility():
        return 'CrdtDataRowVisibility';
      case _i10.CrdtMergeDelete():
        return 'CrdtMergeDelete';
      case _i10.CrdtMergeInsert():
        return 'CrdtMergeInsert';
      case _i10.CrdtMergeUpdate():
        return 'CrdtMergeUpdate';
      case _i11.CrdtNode():
        return 'CrdtNode';
      case _i12.CrdtScope():
        return 'CrdtScope';
      case _i13.CrdtScopeMember():
        return 'CrdtScopeMember';
      case _i14.CrdtScopeNode():
        return 'CrdtScopeNode';
      case _i15.CrdtScopeRole():
        return 'CrdtScopeRole';
      case _i16.CrdtSchemaColumn():
        return 'CrdtSchemaColumn';
      case _i17.CrdtSchemaTable():
        return 'CrdtSchemaTable';
      case _i18.CrdtSyncClose():
        return 'CrdtSyncClose';
      case _i18.CrdtSyncConnect():
        return 'CrdtSyncConnect';
      case _i18.CrdtSyncEndOfBatch():
        return 'CrdtSyncEndOfBatch';
      case _i18.CrdtSyncMergeChunk():
        return 'CrdtSyncMergeChunk';
      case _i19.CrdtScopeGrant():
        return 'CrdtScopeGrant';
      case _i18.CrdtSyncScopeSet():
        return 'CrdtSyncScopeSet';
      case _i18.CrdtSyncSinceHlc():
        return 'CrdtSyncSinceHlc';
      case _i18.CrdtSyncIdleTimeout():
        return 'CrdtSyncIdleTimeout';
      case _i20.CrdtSyncIntegrityViolation():
        return 'CrdtSyncIntegrityViolation';
      case _i21.CrdtSyncViolationOperation():
        return 'CrdtSyncViolationOperation';
      case _i22.CrdtSyncViolationType():
        return 'CrdtSyncViolationType';
    }
    className = _i23.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_offline_sync.$className';
    }
    className = _i2.Protocol().getClassNameForObject(data);
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
    if (dataClassName == 'Hlc') {
      return deserialize<_i23.Hlc>(data['data']);
    }
    if (dataClassName == 'CrdtDataDeleted') {
      return deserialize<_i3.CrdtDataDeleted>(data['data']);
    }
    if (dataClassName == 'CrdtDataDeletedReason') {
      return deserialize<_i4.CrdtDataDeletedReason>(data['data']);
    }
    if (dataClassName == 'CrdtDataField') {
      return deserialize<_i5.CrdtDataField>(data['data']);
    }
    if (dataClassName == 'CrdtDataForeignKey') {
      return deserialize<_i6.CrdtDataForeignKey>(data['data']);
    }
    if (dataClassName == 'CrdtForeignKeyOverrideReason') {
      return deserialize<_i7.CrdtForeignKeyOverrideReason>(data['data']);
    }
    if (dataClassName == 'CrdtDataRow') {
      return deserialize<_i8.CrdtDataRow>(data['data']);
    }
    if (dataClassName == 'CrdtDataRowVisibility') {
      return deserialize<_i9.CrdtDataRowVisibility>(data['data']);
    }
    if (dataClassName == 'CrdtMergeDelete') {
      return deserialize<_i10.CrdtMergeDelete>(data['data']);
    }
    if (dataClassName == 'CrdtMergeInsert') {
      return deserialize<_i10.CrdtMergeInsert>(data['data']);
    }
    if (dataClassName == 'CrdtMergeUpdate') {
      return deserialize<_i10.CrdtMergeUpdate>(data['data']);
    }
    if (dataClassName == 'CrdtNode') {
      return deserialize<_i11.CrdtNode>(data['data']);
    }
    if (dataClassName == 'CrdtScope') {
      return deserialize<_i12.CrdtScope>(data['data']);
    }
    if (dataClassName == 'CrdtScopeMember') {
      return deserialize<_i13.CrdtScopeMember>(data['data']);
    }
    if (dataClassName == 'CrdtScopeNode') {
      return deserialize<_i14.CrdtScopeNode>(data['data']);
    }
    if (dataClassName == 'CrdtScopeRole') {
      return deserialize<_i15.CrdtScopeRole>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaColumn') {
      return deserialize<_i16.CrdtSchemaColumn>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaTable') {
      return deserialize<_i17.CrdtSchemaTable>(data['data']);
    }
    if (dataClassName == 'CrdtSyncClose') {
      return deserialize<_i18.CrdtSyncClose>(data['data']);
    }
    if (dataClassName == 'CrdtSyncConnect') {
      return deserialize<_i18.CrdtSyncConnect>(data['data']);
    }
    if (dataClassName == 'CrdtSyncEndOfBatch') {
      return deserialize<_i18.CrdtSyncEndOfBatch>(data['data']);
    }
    if (dataClassName == 'CrdtSyncMergeChunk') {
      return deserialize<_i18.CrdtSyncMergeChunk>(data['data']);
    }
    if (dataClassName == 'CrdtScopeGrant') {
      return deserialize<_i19.CrdtScopeGrant>(data['data']);
    }
    if (dataClassName == 'CrdtSyncScopeSet') {
      return deserialize<_i18.CrdtSyncScopeSet>(data['data']);
    }
    if (dataClassName == 'CrdtSyncSinceHlc') {
      return deserialize<_i18.CrdtSyncSinceHlc>(data['data']);
    }
    if (dataClassName == 'CrdtSyncIdleTimeout') {
      return deserialize<_i18.CrdtSyncIdleTimeout>(data['data']);
    }
    if (dataClassName == 'CrdtSyncIntegrityViolation') {
      return deserialize<_i20.CrdtSyncIntegrityViolation>(data['data']);
    }
    if (dataClassName == 'CrdtSyncViolationOperation') {
      return deserialize<_i21.CrdtSyncViolationOperation>(data['data']);
    }
    if (dataClassName == 'CrdtSyncViolationType') {
      return deserialize<_i22.CrdtSyncViolationType>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_offline_sync.')) {
      data['className'] = dataClassName.substring(30);
      return _i23.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  Object? dynamicFieldToJson(
    Object? object, {
    bool forProtocol = false,
  }) {
    if ((object is List || object is Set || object is Map) ||
        getClassNameForObject(object) != null) {
      return super.dynamicFieldToJson(object, forProtocol: forProtocol);
    }
    for (final protocol in _hostProtocols) {
      final className = protocol.getClassNameForObject(object);
      if (className == null) continue;
      final host = protocol.getModuleName();
      final wrapped = {
        'className': className.contains('.') ? className : '$host.$className',
        'data': object,
      };
      return forProtocol
          ? _i1.SerializationManager.toEncodableForProtocol(wrapped)
          : _i1.SerializationManager.toEncodable(wrapped);
    }
    return super.dynamicFieldToJson(object, forProtocol: forProtocol);
  }

  @override
  dynamic deserializeDynamicFieldValue(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic> || value['className'] is! String) {
      throw FormatException(
        'Dynamic fields are encoded as a Map with className and data, but got '
        '${value.runtimeType} instead.',
      );
    }
    final className = value['className'] as String;
    for (final protocol in _hostProtocols) {
      final host = protocol.getModuleName();
      final hostPrefix = '$host.';
      if (className.startsWith(hostPrefix)) {
        final strippedClassName = className.substring(hostPrefix.length);
        if (strippedClassName.contains('.')) {
          throw FormatException(
            'Dynamic field className must not use multiple prefixes: $className',
          );
        }
        final hostData = Map<String, dynamic>.from(value);
        hostData['className'] = strippedClassName;
        return protocol.deserializeByClassName(hostData);
      }
    }
    if (className.contains('.')) {
      for (final protocol in _hostProtocols) {
        try {
          return protocol.deserializeByClassName(value);
        } on FormatException catch (_) {}
      }
    }
    return deserializeByClassName(value);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i3.CrdtDataDeleted:
        return _i3.CrdtDataDeleted.t;
      case _i5.CrdtDataField:
        return _i5.CrdtDataField.t;
      case _i6.CrdtDataForeignKey:
        return _i6.CrdtDataForeignKey.t;
      case _i8.CrdtDataRow:
        return _i8.CrdtDataRow.t;
      case _i11.CrdtNode:
        return _i11.CrdtNode.t;
      case _i12.CrdtScope:
        return _i12.CrdtScope.t;
      case _i13.CrdtScopeMember:
        return _i13.CrdtScopeMember.t;
      case _i14.CrdtScopeNode:
        return _i14.CrdtScopeNode.t;
      case _i16.CrdtSchemaColumn:
        return _i16.CrdtSchemaColumn.t;
      case _i17.CrdtSchemaTable:
        return _i17.CrdtSchemaTable.t;
      case _i20.CrdtSyncIntegrityViolation:
        return _i20.CrdtSyncIntegrityViolation.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'serverpod_offline_sync';

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
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
