/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, no_leading_underscores_for_library_prefixes
// ignore_for_file: unnecessary_type_check

import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'data/deleted.dart' as _ixchaeer;
import 'data/deleted_reason.dart' as _i9ghhf3z;
import 'data/field.dart' as _iwcj1b8j;
import 'data/foreign_key.dart' as _isq49ibf;
import 'data/foreign_key_override_reason.dart' as _iettvg4j;
import 'data/row.dart' as _iokmrb1h;
import 'data/row_visibility.dart' as _ibzh2k8m;
import 'hlc/base.dart' as _ipogc60q;
import 'merge/change.dart' as _i0vvt7eq;
import 'node/node.dart' as _iyfv8jet;
import 'node/scope.dart' as _irlcm4ej;
import 'node/scope_member.dart' as _iqsssh9c;
import 'node/scope_node.dart' as _ig47m65z;
import 'node/scope_role.dart' as _ib0fag6l;
import 'schema/column.dart' as _iy534gq7;
import 'schema/table.dart' as _ik8xyqdv;
import 'sync/scope_grant.dart' as _io782kbc;
import 'sync/stream_event.dart' as _iimdylh8;
import 'sync/violation.dart' as _iucor0s6;
import 'sync/violation_operation.dart' as _ijw2vw1z;
import 'sync/violation_type.dart' as _itf31ci3;
export 'data/deleted.dart';
export 'data/deleted_reason.dart';
export 'data/field.dart';
export 'data/foreign_key.dart';
export 'data/foreign_key_override_reason.dart';
export 'data/row.dart';
export 'data/row_visibility.dart';
export 'merge/change.dart';
export 'hlc/base.dart';
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

class Protocol extends _isd.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  final Set<_iss.SerializationManager> _hostProtocols = {};

  static List<_isd.TableDefinition> get targetTableDefinitions => [
    _isd.TableDefinition(
      name: 'crdt_data_fields',
      dartName: 'CrdtDataField',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'rowId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'columnId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'nodeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_0',
          columns: ['rowId'],
          referenceTable: 'crdt_data_rows',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_1',
          columns: ['columnId'],
          referenceTable: 'crdt_schema_columns',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_fields_fk_2',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_data_fields_row_column_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'rowId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_data_foreign_key',
      dartName: 'CrdtDataForeignKey',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'fieldId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'attemptedValue',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'visibleValue',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'overrideReason',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'serverpod_offline_sync:CrdtForeignKeyOverrideReason?',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_foreign_key_fk_0',
          columns: ['fieldId'],
          referenceTable: 'crdt_data_fields',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_data_foreign_key_field_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_data_rows',
      dartName: 'CrdtDataRow',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'scopeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'tblId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'uuidRowId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'nodeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'visibility',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtDataRowVisibility',
          columnDefault: '0',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_1',
          columns: ['tblId'],
          referenceTable: 'crdt_schema_tables',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_rows_fk_2',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_data_rows_scope_tbl_row_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'tblId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_data_tombstone',
      dartName: 'CrdtDataDeleted',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'rowId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'nodeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'clFlag',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'reason',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtDataDeletedReason',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_tombstone_fk_0',
          columns: ['rowId'],
          referenceTable: 'crdt_data_rows',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_tombstone_fk_1',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_data_tombstone_row_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_nodes',
      dartName: 'CrdtNode',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'uuidNodeId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'lastHlc',
          columnType: _isd.ColumnType.jsonb,
          isNullable: true,
          dartType:
              'package:serverpod_offline_sync/serverpod_offline_sync.dart:Hlc?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_nodes__uuidNodeId__unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_schema_columns',
      dartName: 'CrdtSchemaColumn',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'tblId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'columnType',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'dartType',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'isNullable',
          columnType: _isd.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_schema_columns_fk_0',
          columns: ['tblId'],
          referenceTable: 'crdt_schema_tables',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_schema_columns_table_column_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'tblId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_schema_tables',
      dartName: 'CrdtSchemaTable',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'name',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_schema_tables__name__unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_scope_members',
      dartName: 'CrdtScopeMember',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'scopeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'userUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'role',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtScopeRole',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_scope_members_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_scope_member_unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'userUuid',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_scope_nodes',
      dartName: 'CrdtScopeNode',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'scopeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'nodeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isd.ColumnDefinition(
          name: 'lastReceivedHlc',
          columnType: _isd.ColumnType.jsonb,
          isNullable: true,
          dartType:
              'package:serverpod_offline_sync/serverpod_offline_sync.dart:Hlc?',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_scope_nodes_fk_0',
          columns: ['scopeId'],
          referenceTable: 'crdt_scopes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_scope_nodes_fk_1',
          columns: ['nodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_scope_node_unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'scopeId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_scopes',
      dartName: 'CrdtScope',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'uuidScopeId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
          columnDefault: 'random_v7',
        ),
        _isd.ColumnDefinition(
          name: 'currentNodeId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_scopes_fk_0',
          columns: ['currentNodeId'],
          referenceTable: 'crdt_nodes',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.noAction,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_scopes__uuidScopeId__unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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
    _isd.TableDefinition(
      name: 'crdt_sync_integrity_violations',
      dartName: 'CrdtSyncIntegrityViolation',
      schema: 'public',
      module: 'serverpod_offline_sync',
      columns: [
        _isd.ColumnDefinition(
          name: 'id',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isd.ColumnDefinition(
          name: 'type',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtSyncViolationType',
        ),
        _isd.ColumnDefinition(
          name: 'domainTableName',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isd.ColumnDefinition(
          name: 'uuidRowId',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'ownerScopeUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'incomingScopeUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'operation',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtSyncViolationOperation',
        ),
        _isd.ColumnDefinition(
          name: 'uuidNodeId',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'crdtDataRowId',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'hlcDatetime',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isd.ColumnDefinition(
          name: 'hlcCounter',
          columnType: _isd.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isd.ColumnDefinition(
          name: 'firstSeenAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'lastSeenAt',
          columnType: _isd.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isd.ColumnDefinition(
          name: 'occurrences',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'crdt_sync_integrity_violations_key_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'type',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'operation',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'domainTableName',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'uuidRowId',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'ownerScopeUuid',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
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

  void registerHostProtocol(
    String projectName,
    _iss.SerializationManager protocol,
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

    if (t == _ixchaeer.CrdtDataDeleted) {
      return _ixchaeer.CrdtDataDeleted.fromJson(data) as T;
    }
    if (t == _i9ghhf3z.CrdtDataDeletedReason) {
      return _i9ghhf3z.CrdtDataDeletedReason.fromJson(data) as T;
    }
    if (t == _iwcj1b8j.CrdtDataField) {
      return _iwcj1b8j.CrdtDataField.fromJson(data) as T;
    }
    if (t == _isq49ibf.CrdtDataForeignKey) {
      return _isq49ibf.CrdtDataForeignKey.fromJson(data) as T;
    }
    if (t == _iettvg4j.CrdtForeignKeyOverrideReason) {
      return _iettvg4j.CrdtForeignKeyOverrideReason.fromJson(data) as T;
    }
    if (t == _iokmrb1h.CrdtDataRow) {
      return _iokmrb1h.CrdtDataRow.fromJson(data) as T;
    }
    if (t == _ibzh2k8m.CrdtDataRowVisibility) {
      return _ibzh2k8m.CrdtDataRowVisibility.fromJson(data) as T;
    }
    if (t == _i0vvt7eq.CrdtMergeDelete) {
      return _i0vvt7eq.CrdtMergeDelete.fromJson(data) as T;
    }
    if (t == _i0vvt7eq.CrdtMergeInsert) {
      return _i0vvt7eq.CrdtMergeInsert.fromJson(data) as T;
    }
    if (t == _i0vvt7eq.CrdtMergeUpdate) {
      return _i0vvt7eq.CrdtMergeUpdate.fromJson(data) as T;
    }
    if (t == _ipogc60q.BaseHlc) {
      return _ipogc60q.BaseHlc.fromJson(data) as T;
    }
    if (t == _iyfv8jet.CrdtNode) {
      return _iyfv8jet.CrdtNode.fromJson(data) as T;
    }
    if (t == _irlcm4ej.CrdtScope) {
      return _irlcm4ej.CrdtScope.fromJson(data) as T;
    }
    if (t == _iqsssh9c.CrdtScopeMember) {
      return _iqsssh9c.CrdtScopeMember.fromJson(data) as T;
    }
    if (t == _ig47m65z.CrdtScopeNode) {
      return _ig47m65z.CrdtScopeNode.fromJson(data) as T;
    }
    if (t == _ib0fag6l.CrdtScopeRole) {
      return _ib0fag6l.CrdtScopeRole.fromJson(data) as T;
    }
    if (t == _iy534gq7.CrdtSchemaColumn) {
      return _iy534gq7.CrdtSchemaColumn.fromJson(data) as T;
    }
    if (t == _ik8xyqdv.CrdtSchemaTable) {
      return _ik8xyqdv.CrdtSchemaTable.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncClose) {
      return _iimdylh8.CrdtSyncClose.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncConnect) {
      return _iimdylh8.CrdtSyncConnect.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncEndOfBatch) {
      return _iimdylh8.CrdtSyncEndOfBatch.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncMergeChunk) {
      return _iimdylh8.CrdtSyncMergeChunk.fromJson(data) as T;
    }
    if (t == _io782kbc.CrdtScopeGrant) {
      return _io782kbc.CrdtScopeGrant.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncScopeSet) {
      return _iimdylh8.CrdtSyncScopeSet.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncSinceHlc) {
      return _iimdylh8.CrdtSyncSinceHlc.fromJson(data) as T;
    }
    if (t == _iimdylh8.CrdtSyncIdleTimeout) {
      return _iimdylh8.CrdtSyncIdleTimeout.fromJson(data) as T;
    }
    if (t == _iucor0s6.CrdtSyncIntegrityViolation) {
      return _iucor0s6.CrdtSyncIntegrityViolation.fromJson(data) as T;
    }
    if (t == _ijw2vw1z.CrdtSyncViolationOperation) {
      return _ijw2vw1z.CrdtSyncViolationOperation.fromJson(data) as T;
    }
    if (t == _itf31ci3.CrdtSyncViolationType) {
      return _itf31ci3.CrdtSyncViolationType.fromJson(data) as T;
    }
    if (t == _iss.getType<_ixchaeer.CrdtDataDeleted?>()) {
      return (data != null ? _ixchaeer.CrdtDataDeleted.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i9ghhf3z.CrdtDataDeletedReason?>()) {
      return (data != null
              ? _i9ghhf3z.CrdtDataDeletedReason.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iwcj1b8j.CrdtDataField?>()) {
      return (data != null ? _iwcj1b8j.CrdtDataField.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_isq49ibf.CrdtDataForeignKey?>()) {
      return (data != null ? _isq49ibf.CrdtDataForeignKey.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iettvg4j.CrdtForeignKeyOverrideReason?>()) {
      return (data != null
              ? _iettvg4j.CrdtForeignKeyOverrideReason.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iokmrb1h.CrdtDataRow?>()) {
      return (data != null ? _iokmrb1h.CrdtDataRow.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_ibzh2k8m.CrdtDataRowVisibility?>()) {
      return (data != null
              ? _ibzh2k8m.CrdtDataRowVisibility.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_i0vvt7eq.CrdtMergeDelete?>()) {
      return (data != null ? _i0vvt7eq.CrdtMergeDelete.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i0vvt7eq.CrdtMergeInsert?>()) {
      return (data != null ? _i0vvt7eq.CrdtMergeInsert.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i0vvt7eq.CrdtMergeUpdate?>()) {
      return (data != null ? _i0vvt7eq.CrdtMergeUpdate.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ipogc60q.BaseHlc?>()) {
      return (data != null ? _ipogc60q.BaseHlc.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iyfv8jet.CrdtNode?>()) {
      return (data != null ? _iyfv8jet.CrdtNode.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_irlcm4ej.CrdtScope?>()) {
      return (data != null ? _irlcm4ej.CrdtScope.fromJson(data) : null) as T;
    }
    if (t == _iss.getType<_iqsssh9c.CrdtScopeMember?>()) {
      return (data != null ? _iqsssh9c.CrdtScopeMember.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ig47m65z.CrdtScopeNode?>()) {
      return (data != null ? _ig47m65z.CrdtScopeNode.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ib0fag6l.CrdtScopeRole?>()) {
      return (data != null ? _ib0fag6l.CrdtScopeRole.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iy534gq7.CrdtSchemaColumn?>()) {
      return (data != null ? _iy534gq7.CrdtSchemaColumn.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_ik8xyqdv.CrdtSchemaTable?>()) {
      return (data != null ? _ik8xyqdv.CrdtSchemaTable.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncClose?>()) {
      return (data != null ? _iimdylh8.CrdtSyncClose.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncConnect?>()) {
      return (data != null ? _iimdylh8.CrdtSyncConnect.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncEndOfBatch?>()) {
      return (data != null ? _iimdylh8.CrdtSyncEndOfBatch.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncMergeChunk?>()) {
      return (data != null ? _iimdylh8.CrdtSyncMergeChunk.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_io782kbc.CrdtScopeGrant?>()) {
      return (data != null ? _io782kbc.CrdtScopeGrant.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncScopeSet?>()) {
      return (data != null ? _iimdylh8.CrdtSyncScopeSet.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncSinceHlc?>()) {
      return (data != null ? _iimdylh8.CrdtSyncSinceHlc.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.CrdtSyncIdleTimeout?>()) {
      return (data != null
              ? _iimdylh8.CrdtSyncIdleTimeout.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iucor0s6.CrdtSyncIntegrityViolation?>()) {
      return (data != null
              ? _iucor0s6.CrdtSyncIntegrityViolation.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_ijw2vw1z.CrdtSyncViolationOperation?>()) {
      return (data != null
              ? _ijw2vw1z.CrdtSyncViolationOperation.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_itf31ci3.CrdtSyncViolationType?>()) {
      return (data != null
              ? _itf31ci3.CrdtSyncViolationType.fromJson(data)
              : null)
          as T;
    }
    if (t == List<_icw2tu00.CrdtDataField>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.CrdtDataField>(e))
              .toList()
          as T;
    }
    if (t == _iss.getType<List<_icw2tu00.CrdtDataField>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_icw2tu00.CrdtDataField>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == dynamic) {
      return deserializeDynamicFieldValue(data) as T;
    }
    if (t == _iss.getType<_icw2tu00.Hlc?>()) {
      return (data != null ? _icw2tu00.Hlc.fromJson(data) : null) as T;
    }
    if (t == List<_icw2tu00.CrdtScopeNode>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.CrdtScopeNode>(e))
              .toList()
          as T;
    }
    if (t == _iss.getType<List<_icw2tu00.CrdtScopeNode>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_icw2tu00.CrdtScopeNode>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_icw2tu00.CrdtMergeChange>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.CrdtMergeChange>(e))
              .toList()
          as T;
    }
    if (t == List<_icw2tu00.CrdtScopeGrant>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.CrdtScopeGrant>(e))
              .toList()
          as T;
    }
    if (t == List<_icw2tu00.Hlc>) {
      return (data as List).map((e) => deserialize<_icw2tu00.Hlc>(e)).toList()
          as T;
    }
    if (t == _icw2tu00.Hlc) {
      return _icw2tu00.Hlc.fromJson(data) as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ixchaeer.CrdtDataDeleted => 'CrdtDataDeleted',
      _i9ghhf3z.CrdtDataDeletedReason => 'CrdtDataDeletedReason',
      _iwcj1b8j.CrdtDataField => 'CrdtDataField',
      _isq49ibf.CrdtDataForeignKey => 'CrdtDataForeignKey',
      _iettvg4j.CrdtForeignKeyOverrideReason => 'CrdtForeignKeyOverrideReason',
      _iokmrb1h.CrdtDataRow => 'CrdtDataRow',
      _ibzh2k8m.CrdtDataRowVisibility => 'CrdtDataRowVisibility',
      _i0vvt7eq.CrdtMergeDelete => 'CrdtMergeDelete',
      _i0vvt7eq.CrdtMergeInsert => 'CrdtMergeInsert',
      _i0vvt7eq.CrdtMergeUpdate => 'CrdtMergeUpdate',
      _ipogc60q.BaseHlc => 'BaseHlc',
      _iyfv8jet.CrdtNode => 'CrdtNode',
      _irlcm4ej.CrdtScope => 'CrdtScope',
      _iqsssh9c.CrdtScopeMember => 'CrdtScopeMember',
      _ig47m65z.CrdtScopeNode => 'CrdtScopeNode',
      _ib0fag6l.CrdtScopeRole => 'CrdtScopeRole',
      _iy534gq7.CrdtSchemaColumn => 'CrdtSchemaColumn',
      _ik8xyqdv.CrdtSchemaTable => 'CrdtSchemaTable',
      _iimdylh8.CrdtSyncClose => 'CrdtSyncClose',
      _iimdylh8.CrdtSyncConnect => 'CrdtSyncConnect',
      _iimdylh8.CrdtSyncEndOfBatch => 'CrdtSyncEndOfBatch',
      _iimdylh8.CrdtSyncMergeChunk => 'CrdtSyncMergeChunk',
      _io782kbc.CrdtScopeGrant => 'CrdtScopeGrant',
      _iimdylh8.CrdtSyncScopeSet => 'CrdtSyncScopeSet',
      _iimdylh8.CrdtSyncSinceHlc => 'CrdtSyncSinceHlc',
      _iimdylh8.CrdtSyncIdleTimeout => 'CrdtSyncIdleTimeout',
      _iucor0s6.CrdtSyncIntegrityViolation => 'CrdtSyncIntegrityViolation',
      _ijw2vw1z.CrdtSyncViolationOperation => 'CrdtSyncViolationOperation',
      _itf31ci3.CrdtSyncViolationType => 'CrdtSyncViolationType',
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
      case _ixchaeer.CrdtDataDeleted():
        return 'CrdtDataDeleted';
      case _i9ghhf3z.CrdtDataDeletedReason():
        return 'CrdtDataDeletedReason';
      case _iwcj1b8j.CrdtDataField():
        return 'CrdtDataField';
      case _isq49ibf.CrdtDataForeignKey():
        return 'CrdtDataForeignKey';
      case _iettvg4j.CrdtForeignKeyOverrideReason():
        return 'CrdtForeignKeyOverrideReason';
      case _iokmrb1h.CrdtDataRow():
        return 'CrdtDataRow';
      case _ibzh2k8m.CrdtDataRowVisibility():
        return 'CrdtDataRowVisibility';
      case _i0vvt7eq.CrdtMergeDelete():
        return 'CrdtMergeDelete';
      case _i0vvt7eq.CrdtMergeInsert():
        return 'CrdtMergeInsert';
      case _i0vvt7eq.CrdtMergeUpdate():
        return 'CrdtMergeUpdate';
      case _ipogc60q.BaseHlc():
        return 'BaseHlc';
      case _iyfv8jet.CrdtNode():
        return 'CrdtNode';
      case _irlcm4ej.CrdtScope():
        return 'CrdtScope';
      case _iqsssh9c.CrdtScopeMember():
        return 'CrdtScopeMember';
      case _ig47m65z.CrdtScopeNode():
        return 'CrdtScopeNode';
      case _ib0fag6l.CrdtScopeRole():
        return 'CrdtScopeRole';
      case _iy534gq7.CrdtSchemaColumn():
        return 'CrdtSchemaColumn';
      case _ik8xyqdv.CrdtSchemaTable():
        return 'CrdtSchemaTable';
      case _iimdylh8.CrdtSyncClose():
        return 'CrdtSyncClose';
      case _iimdylh8.CrdtSyncConnect():
        return 'CrdtSyncConnect';
      case _iimdylh8.CrdtSyncEndOfBatch():
        return 'CrdtSyncEndOfBatch';
      case _iimdylh8.CrdtSyncMergeChunk():
        return 'CrdtSyncMergeChunk';
      case _io782kbc.CrdtScopeGrant():
        return 'CrdtScopeGrant';
      case _iimdylh8.CrdtSyncScopeSet():
        return 'CrdtSyncScopeSet';
      case _iimdylh8.CrdtSyncSinceHlc():
        return 'CrdtSyncSinceHlc';
      case _iimdylh8.CrdtSyncIdleTimeout():
        return 'CrdtSyncIdleTimeout';
      case _iucor0s6.CrdtSyncIntegrityViolation():
        return 'CrdtSyncIntegrityViolation';
      case _ijw2vw1z.CrdtSyncViolationOperation():
        return 'CrdtSyncViolationOperation';
      case _itf31ci3.CrdtSyncViolationType():
        return 'CrdtSyncViolationType';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'CrdtDataDeleted') {
      return deserialize<_ixchaeer.CrdtDataDeleted>(data['data']);
    }
    if (dataClassName == 'CrdtDataDeletedReason') {
      return deserialize<_i9ghhf3z.CrdtDataDeletedReason>(data['data']);
    }
    if (dataClassName == 'CrdtDataField') {
      return deserialize<_iwcj1b8j.CrdtDataField>(data['data']);
    }
    if (dataClassName == 'CrdtDataForeignKey') {
      return deserialize<_isq49ibf.CrdtDataForeignKey>(data['data']);
    }
    if (dataClassName == 'CrdtForeignKeyOverrideReason') {
      return deserialize<_iettvg4j.CrdtForeignKeyOverrideReason>(data['data']);
    }
    if (dataClassName == 'CrdtDataRow') {
      return deserialize<_iokmrb1h.CrdtDataRow>(data['data']);
    }
    if (dataClassName == 'CrdtDataRowVisibility') {
      return deserialize<_ibzh2k8m.CrdtDataRowVisibility>(data['data']);
    }
    if (dataClassName == 'CrdtMergeDelete') {
      return deserialize<_i0vvt7eq.CrdtMergeDelete>(data['data']);
    }
    if (dataClassName == 'CrdtMergeInsert') {
      return deserialize<_i0vvt7eq.CrdtMergeInsert>(data['data']);
    }
    if (dataClassName == 'CrdtMergeUpdate') {
      return deserialize<_i0vvt7eq.CrdtMergeUpdate>(data['data']);
    }
    if (dataClassName == 'BaseHlc') {
      return deserialize<_ipogc60q.BaseHlc>(data['data']);
    }
    if (dataClassName == 'CrdtNode') {
      return deserialize<_iyfv8jet.CrdtNode>(data['data']);
    }
    if (dataClassName == 'CrdtScope') {
      return deserialize<_irlcm4ej.CrdtScope>(data['data']);
    }
    if (dataClassName == 'CrdtScopeMember') {
      return deserialize<_iqsssh9c.CrdtScopeMember>(data['data']);
    }
    if (dataClassName == 'CrdtScopeNode') {
      return deserialize<_ig47m65z.CrdtScopeNode>(data['data']);
    }
    if (dataClassName == 'CrdtScopeRole') {
      return deserialize<_ib0fag6l.CrdtScopeRole>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaColumn') {
      return deserialize<_iy534gq7.CrdtSchemaColumn>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaTable') {
      return deserialize<_ik8xyqdv.CrdtSchemaTable>(data['data']);
    }
    if (dataClassName == 'CrdtSyncClose') {
      return deserialize<_iimdylh8.CrdtSyncClose>(data['data']);
    }
    if (dataClassName == 'CrdtSyncConnect') {
      return deserialize<_iimdylh8.CrdtSyncConnect>(data['data']);
    }
    if (dataClassName == 'CrdtSyncEndOfBatch') {
      return deserialize<_iimdylh8.CrdtSyncEndOfBatch>(data['data']);
    }
    if (dataClassName == 'CrdtSyncMergeChunk') {
      return deserialize<_iimdylh8.CrdtSyncMergeChunk>(data['data']);
    }
    if (dataClassName == 'CrdtScopeGrant') {
      return deserialize<_io782kbc.CrdtScopeGrant>(data['data']);
    }
    if (dataClassName == 'CrdtSyncScopeSet') {
      return deserialize<_iimdylh8.CrdtSyncScopeSet>(data['data']);
    }
    if (dataClassName == 'CrdtSyncSinceHlc') {
      return deserialize<_iimdylh8.CrdtSyncSinceHlc>(data['data']);
    }
    if (dataClassName == 'CrdtSyncIdleTimeout') {
      return deserialize<_iimdylh8.CrdtSyncIdleTimeout>(data['data']);
    }
    if (dataClassName == 'CrdtSyncIntegrityViolation') {
      return deserialize<_iucor0s6.CrdtSyncIntegrityViolation>(data['data']);
    }
    if (dataClassName == 'CrdtSyncViolationOperation') {
      return deserialize<_ijw2vw1z.CrdtSyncViolationOperation>(data['data']);
    }
    if (dataClassName == 'CrdtSyncViolationType') {
      return deserialize<_itf31ci3.CrdtSyncViolationType>(data['data']);
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
          ? _iss.SerializationManager.toEncodableForProtocol(wrapped)
          : _iss.SerializationManager.toEncodable(wrapped);
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
  _isd.Table? getTableForType(Type t) {
    switch (t) {
      case _ixchaeer.CrdtDataDeleted:
        return _ixchaeer.CrdtDataDeleted.t;
      case _iwcj1b8j.CrdtDataField:
        return _iwcj1b8j.CrdtDataField.t;
      case _isq49ibf.CrdtDataForeignKey:
        return _isq49ibf.CrdtDataForeignKey.t;
      case _iokmrb1h.CrdtDataRow:
        return _iokmrb1h.CrdtDataRow.t;
      case _iyfv8jet.CrdtNode:
        return _iyfv8jet.CrdtNode.t;
      case _irlcm4ej.CrdtScope:
        return _irlcm4ej.CrdtScope.t;
      case _iqsssh9c.CrdtScopeMember:
        return _iqsssh9c.CrdtScopeMember.t;
      case _ig47m65z.CrdtScopeNode:
        return _ig47m65z.CrdtScopeNode.t;
      case _iy534gq7.CrdtSchemaColumn:
        return _iy534gq7.CrdtSchemaColumn.t;
      case _ik8xyqdv.CrdtSchemaTable:
        return _ik8xyqdv.CrdtSchemaTable.t;
      case _iucor0s6.CrdtSyncIntegrityViolation:
        return _iucor0s6.CrdtSyncIntegrityViolation.t;
    }
    return null;
  }

  @override
  List<_isd.TableDefinition> getTargetTableDefinitions() =>
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
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
