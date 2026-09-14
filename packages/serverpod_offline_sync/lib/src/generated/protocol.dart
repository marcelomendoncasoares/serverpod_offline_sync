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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'data/attempted_value.dart' as _ikikkl0e;
import 'data/deleted.dart' as _ixchaeer;
import 'data/deleted_reason.dart' as _i9ghhf3z;
import 'data/field.dart' as _iwcj1b8j;
import 'data/projection_reason.dart' as _ijcw1c9t;
import 'data/row.dart' as _iokmrb1h;
import 'data/row_visibility.dart' as _ibzh2k8m;
import 'hlc/base.dart' as _ipogc60q;
import 'merge/change.dart' as _i0vvt7eq;
import 'node/node.dart' as _iyfv8jet;
import 'node/space.dart' as _ifj6lhq8;
import 'node/space_member.dart' as _i75umry7;
import 'node/space_node.dart' as _it7grqg6;
import 'node/space_role.dart' as _ivdq6jvj;
import 'schema/column.dart' as _iy534gq7;
import 'schema/table.dart' as _ik8xyqdv;
import 'sync/space_grant.dart' as _ijw89gb9;
import 'sync/stream_event.dart' as _iimdylh8;
import 'sync/violation.dart' as _iucor0s6;
import 'sync/violation_operation.dart' as _ijw2vw1z;
import 'sync/violation_type.dart' as _itf31ci3;
export 'data/attempted_value.dart';
export 'data/deleted.dart';
export 'data/deleted_reason.dart';
export 'data/field.dart';
export 'data/projection_reason.dart';
export 'data/row.dart';
export 'data/row_visibility.dart';
export 'merge/change.dart';
export 'hlc/base.dart';
export 'node/node.dart';
export 'node/space.dart';
export 'node/space_member.dart';
export 'node/space_node.dart';
export 'node/space_role.dart';
export 'schema/column.dart';
export 'schema/table.dart';
export 'sync/space_grant.dart';
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
      name: 'crdt_data_attempted_value',
      dartName: 'CrdtDataAttemptedValue',
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
          name: 'value',
          columnType: _isd.ColumnType.jsonb,
          isNullable: false,
          dartType: 'dynamic',
        ),
        _isd.ColumnDefinition(
          name: 'projectionReason',
          columnType: _isd.ColumnType.bigint,
          isNullable: false,
          dartType: 'serverpod_offline_sync:CrdtProjectionReason',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'crdt_data_attempted_value_fk_0',
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
          indexName: 'crdt_data_attempted_value__fieldId__unique_idx',
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
          name: 'spaceId',
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
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
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
          indexName: 'crdt_data_rows_space_tbl_row_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spaceId',
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
      name: 'offline_sync_integrity_violations',
      dartName: 'OfflineSyncIntegrityViolation',
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
          dartType: 'serverpod_offline_sync:OfflineSyncViolationType',
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
          name: 'ownerSpaceUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isd.ColumnDefinition(
          name: 'incomingSpaceUuid',
          columnType: _isd.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isd.ColumnDefinition(
          name: 'operation',
          columnType: _isd.ColumnType.text,
          isNullable: false,
          dartType: 'serverpod_offline_sync:OfflineSyncViolationOperation',
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
          indexName: 'offline_sync_integrity_violations_key_idx',
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
              definition: 'ownerSpaceUuid',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'incomingSpaceUuid',
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
      name: 'offline_sync_space_members',
      dartName: 'OfflineSyncSpaceMember',
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
          name: 'spaceId',
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
          dartType: 'serverpod_offline_sync:OfflineSyncSpaceRole',
        ),
      ],
      foreignKeys: [
        _isd.ForeignKeyDefinition(
          constraintName: 'offline_sync_space_members_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isd.IndexDefinition(
          indexName: 'offline_sync_space_member_unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'userUuid',
            ),
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spaceId',
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
      name: 'offline_sync_space_nodes',
      dartName: 'OfflineSyncSpaceNode',
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
          name: 'spaceId',
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
          constraintName: 'offline_sync_space_nodes_fk_0',
          columns: ['spaceId'],
          referenceTable: 'offline_sync_spaces',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isd.ForeignKeyAction.noAction,
          onDelete: _isd.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isd.ForeignKeyDefinition(
          constraintName: 'offline_sync_space_nodes_fk_1',
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
          indexName: 'offline_sync_space_node_unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'spaceId',
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
      name: 'offline_sync_spaces',
      dartName: 'OfflineSyncSpace',
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
          name: 'uuidSpaceId',
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
          constraintName: 'offline_sync_spaces_fk_0',
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
          indexName: 'offline_sync_spaces__uuidSpaceId__unique_idx',
          tableSpace: null,
          elements: [
            _isd.IndexElementDefinition(
              type: _isd.IndexElementDefinitionType.column,
              definition: 'uuidSpaceId',
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
      } on _iss.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _ikikkl0e.CrdtDataAttemptedValue) {
      return _ikikkl0e.CrdtDataAttemptedValue.fromJson(data) as T;
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
    if (t == _ijcw1c9t.CrdtProjectionReason) {
      return _ijcw1c9t.CrdtProjectionReason.fromJson(data) as T;
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
    if (t == _ifj6lhq8.OfflineSyncSpace) {
      return _ifj6lhq8.OfflineSyncSpace.fromJson(data) as T;
    }
    if (t == _i75umry7.OfflineSyncSpaceMember) {
      return _i75umry7.OfflineSyncSpaceMember.fromJson(data) as T;
    }
    if (t == _it7grqg6.OfflineSyncSpaceNode) {
      return _it7grqg6.OfflineSyncSpaceNode.fromJson(data) as T;
    }
    if (t == _ivdq6jvj.OfflineSyncSpaceRole) {
      return _ivdq6jvj.OfflineSyncSpaceRole.fromJson(data) as T;
    }
    if (t == _iy534gq7.CrdtSchemaColumn) {
      return _iy534gq7.CrdtSchemaColumn.fromJson(data) as T;
    }
    if (t == _ik8xyqdv.CrdtSchemaTable) {
      return _ik8xyqdv.CrdtSchemaTable.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncClose) {
      return _iimdylh8.OfflineSyncClose.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncConnect) {
      return _iimdylh8.OfflineSyncConnect.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncEndOfBatch) {
      return _iimdylh8.OfflineSyncEndOfBatch.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncMergeChunk) {
      return _iimdylh8.OfflineSyncMergeChunk.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncSinceHlc) {
      return _iimdylh8.OfflineSyncSinceHlc.fromJson(data) as T;
    }
    if (t == _ijw89gb9.OfflineSyncSpaceGrant) {
      return _ijw89gb9.OfflineSyncSpaceGrant.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncSpaceSet) {
      return _iimdylh8.OfflineSyncSpaceSet.fromJson(data) as T;
    }
    if (t == _iimdylh8.OfflineSyncIdleTimeout) {
      return _iimdylh8.OfflineSyncIdleTimeout.fromJson(data) as T;
    }
    if (t == _iucor0s6.OfflineSyncIntegrityViolation) {
      return _iucor0s6.OfflineSyncIntegrityViolation.fromJson(data) as T;
    }
    if (t == _ijw2vw1z.OfflineSyncViolationOperation) {
      return _ijw2vw1z.OfflineSyncViolationOperation.fromJson(data) as T;
    }
    if (t == _itf31ci3.OfflineSyncViolationType) {
      return _itf31ci3.OfflineSyncViolationType.fromJson(data) as T;
    }
    if (t == _iss.getType<_ikikkl0e.CrdtDataAttemptedValue?>()) {
      return (data != null
              ? _ikikkl0e.CrdtDataAttemptedValue.fromJson(data)
              : null)
          as T;
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
    if (t == _iss.getType<_ijcw1c9t.CrdtProjectionReason?>()) {
      return (data != null
              ? _ijcw1c9t.CrdtProjectionReason.fromJson(data)
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
    if (t == _iss.getType<_ifj6lhq8.OfflineSyncSpace?>()) {
      return (data != null ? _ifj6lhq8.OfflineSyncSpace.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_i75umry7.OfflineSyncSpaceMember?>()) {
      return (data != null
              ? _i75umry7.OfflineSyncSpaceMember.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_it7grqg6.OfflineSyncSpaceNode?>()) {
      return (data != null
              ? _it7grqg6.OfflineSyncSpaceNode.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_ivdq6jvj.OfflineSyncSpaceRole?>()) {
      return (data != null
              ? _ivdq6jvj.OfflineSyncSpaceRole.fromJson(data)
              : null)
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
    if (t == _iss.getType<_iimdylh8.OfflineSyncClose?>()) {
      return (data != null ? _iimdylh8.OfflineSyncClose.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncConnect?>()) {
      return (data != null ? _iimdylh8.OfflineSyncConnect.fromJson(data) : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncEndOfBatch?>()) {
      return (data != null
              ? _iimdylh8.OfflineSyncEndOfBatch.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncMergeChunk?>()) {
      return (data != null
              ? _iimdylh8.OfflineSyncMergeChunk.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncSinceHlc?>()) {
      return (data != null
              ? _iimdylh8.OfflineSyncSinceHlc.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_ijw89gb9.OfflineSyncSpaceGrant?>()) {
      return (data != null
              ? _ijw89gb9.OfflineSyncSpaceGrant.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncSpaceSet?>()) {
      return (data != null
              ? _iimdylh8.OfflineSyncSpaceSet.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iimdylh8.OfflineSyncIdleTimeout?>()) {
      return (data != null
              ? _iimdylh8.OfflineSyncIdleTimeout.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_iucor0s6.OfflineSyncIntegrityViolation?>()) {
      return (data != null
              ? _iucor0s6.OfflineSyncIntegrityViolation.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_ijw2vw1z.OfflineSyncViolationOperation?>()) {
      return (data != null
              ? _ijw2vw1z.OfflineSyncViolationOperation.fromJson(data)
              : null)
          as T;
    }
    if (t == _iss.getType<_itf31ci3.OfflineSyncViolationType?>()) {
      return (data != null
              ? _itf31ci3.OfflineSyncViolationType.fromJson(data)
              : null)
          as T;
    }
    if (t == dynamic) {
      return deserializeDynamicFieldValue(data) as T;
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
    if (t == _iss.getType<_icw2tu00.Hlc?>()) {
      return (data != null ? _icw2tu00.Hlc.fromJson(data) : null) as T;
    }
    if (t == List<_icw2tu00.OfflineSyncSpaceNode>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.OfflineSyncSpaceNode>(e))
              .toList()
          as T;
    }
    if (t == _iss.getType<List<_icw2tu00.OfflineSyncSpaceNode>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_icw2tu00.OfflineSyncSpaceNode>(e))
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
    if (t == List<_icw2tu00.Hlc>) {
      return (data as List).map((e) => deserialize<_icw2tu00.Hlc>(e)).toList()
          as T;
    }
    if (t == _icw2tu00.Hlc) {
      return _icw2tu00.Hlc.fromJson(data) as T;
    }
    if (t == List<_icw2tu00.OfflineSyncSpaceGrant>) {
      return (data as List)
              .map((e) => deserialize<_icw2tu00.OfflineSyncSpaceGrant>(e))
              .toList()
          as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _ikikkl0e.CrdtDataAttemptedValue => 'CrdtDataAttemptedValue',
      _ixchaeer.CrdtDataDeleted => 'CrdtDataDeleted',
      _i9ghhf3z.CrdtDataDeletedReason => 'CrdtDataDeletedReason',
      _iwcj1b8j.CrdtDataField => 'CrdtDataField',
      _ijcw1c9t.CrdtProjectionReason => 'CrdtProjectionReason',
      _iokmrb1h.CrdtDataRow => 'CrdtDataRow',
      _ibzh2k8m.CrdtDataRowVisibility => 'CrdtDataRowVisibility',
      _i0vvt7eq.CrdtMergeDelete => 'CrdtMergeDelete',
      _i0vvt7eq.CrdtMergeInsert => 'CrdtMergeInsert',
      _i0vvt7eq.CrdtMergeUpdate => 'CrdtMergeUpdate',
      _ipogc60q.BaseHlc => 'BaseHlc',
      _iyfv8jet.CrdtNode => 'CrdtNode',
      _ifj6lhq8.OfflineSyncSpace => 'OfflineSyncSpace',
      _i75umry7.OfflineSyncSpaceMember => 'OfflineSyncSpaceMember',
      _it7grqg6.OfflineSyncSpaceNode => 'OfflineSyncSpaceNode',
      _ivdq6jvj.OfflineSyncSpaceRole => 'OfflineSyncSpaceRole',
      _iy534gq7.CrdtSchemaColumn => 'CrdtSchemaColumn',
      _ik8xyqdv.CrdtSchemaTable => 'CrdtSchemaTable',
      _iimdylh8.OfflineSyncClose => 'OfflineSyncClose',
      _iimdylh8.OfflineSyncConnect => 'OfflineSyncConnect',
      _iimdylh8.OfflineSyncEndOfBatch => 'OfflineSyncEndOfBatch',
      _iimdylh8.OfflineSyncMergeChunk => 'OfflineSyncMergeChunk',
      _iimdylh8.OfflineSyncSinceHlc => 'OfflineSyncSinceHlc',
      _ijw89gb9.OfflineSyncSpaceGrant => 'OfflineSyncSpaceGrant',
      _iimdylh8.OfflineSyncSpaceSet => 'OfflineSyncSpaceSet',
      _iimdylh8.OfflineSyncIdleTimeout => 'OfflineSyncIdleTimeout',
      _iucor0s6.OfflineSyncIntegrityViolation =>
        'OfflineSyncIntegrityViolation',
      _ijw2vw1z.OfflineSyncViolationOperation =>
        'OfflineSyncViolationOperation',
      _itf31ci3.OfflineSyncViolationType => 'OfflineSyncViolationType',
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
      case _ikikkl0e.CrdtDataAttemptedValue():
        return 'CrdtDataAttemptedValue';
      case _ixchaeer.CrdtDataDeleted():
        return 'CrdtDataDeleted';
      case _i9ghhf3z.CrdtDataDeletedReason():
        return 'CrdtDataDeletedReason';
      case _iwcj1b8j.CrdtDataField():
        return 'CrdtDataField';
      case _ijcw1c9t.CrdtProjectionReason():
        return 'CrdtProjectionReason';
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
      case _ifj6lhq8.OfflineSyncSpace():
        return 'OfflineSyncSpace';
      case _i75umry7.OfflineSyncSpaceMember():
        return 'OfflineSyncSpaceMember';
      case _it7grqg6.OfflineSyncSpaceNode():
        return 'OfflineSyncSpaceNode';
      case _ivdq6jvj.OfflineSyncSpaceRole():
        return 'OfflineSyncSpaceRole';
      case _iy534gq7.CrdtSchemaColumn():
        return 'CrdtSchemaColumn';
      case _ik8xyqdv.CrdtSchemaTable():
        return 'CrdtSchemaTable';
      case _iimdylh8.OfflineSyncClose():
        return 'OfflineSyncClose';
      case _iimdylh8.OfflineSyncConnect():
        return 'OfflineSyncConnect';
      case _iimdylh8.OfflineSyncEndOfBatch():
        return 'OfflineSyncEndOfBatch';
      case _iimdylh8.OfflineSyncMergeChunk():
        return 'OfflineSyncMergeChunk';
      case _iimdylh8.OfflineSyncSinceHlc():
        return 'OfflineSyncSinceHlc';
      case _ijw89gb9.OfflineSyncSpaceGrant():
        return 'OfflineSyncSpaceGrant';
      case _iimdylh8.OfflineSyncSpaceSet():
        return 'OfflineSyncSpaceSet';
      case _iimdylh8.OfflineSyncIdleTimeout():
        return 'OfflineSyncIdleTimeout';
      case _iucor0s6.OfflineSyncIntegrityViolation():
        return 'OfflineSyncIntegrityViolation';
      case _ijw2vw1z.OfflineSyncViolationOperation():
        return 'OfflineSyncViolationOperation';
      case _itf31ci3.OfflineSyncViolationType():
        return 'OfflineSyncViolationType';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'CrdtDataAttemptedValue') {
      return deserialize<_ikikkl0e.CrdtDataAttemptedValue>(data['data']);
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
    if (dataClassName == 'CrdtProjectionReason') {
      return deserialize<_ijcw1c9t.CrdtProjectionReason>(data['data']);
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
    if (dataClassName == 'OfflineSyncSpace') {
      return deserialize<_ifj6lhq8.OfflineSyncSpace>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSpaceMember') {
      return deserialize<_i75umry7.OfflineSyncSpaceMember>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSpaceNode') {
      return deserialize<_it7grqg6.OfflineSyncSpaceNode>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSpaceRole') {
      return deserialize<_ivdq6jvj.OfflineSyncSpaceRole>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaColumn') {
      return deserialize<_iy534gq7.CrdtSchemaColumn>(data['data']);
    }
    if (dataClassName == 'CrdtSchemaTable') {
      return deserialize<_ik8xyqdv.CrdtSchemaTable>(data['data']);
    }
    if (dataClassName == 'OfflineSyncClose') {
      return deserialize<_iimdylh8.OfflineSyncClose>(data['data']);
    }
    if (dataClassName == 'OfflineSyncConnect') {
      return deserialize<_iimdylh8.OfflineSyncConnect>(data['data']);
    }
    if (dataClassName == 'OfflineSyncEndOfBatch') {
      return deserialize<_iimdylh8.OfflineSyncEndOfBatch>(data['data']);
    }
    if (dataClassName == 'OfflineSyncMergeChunk') {
      return deserialize<_iimdylh8.OfflineSyncMergeChunk>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSinceHlc') {
      return deserialize<_iimdylh8.OfflineSyncSinceHlc>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSpaceGrant') {
      return deserialize<_ijw89gb9.OfflineSyncSpaceGrant>(data['data']);
    }
    if (dataClassName == 'OfflineSyncSpaceSet') {
      return deserialize<_iimdylh8.OfflineSyncSpaceSet>(data['data']);
    }
    if (dataClassName == 'OfflineSyncIdleTimeout') {
      return deserialize<_iimdylh8.OfflineSyncIdleTimeout>(data['data']);
    }
    if (dataClassName == 'OfflineSyncIntegrityViolation') {
      return deserialize<_iucor0s6.OfflineSyncIntegrityViolation>(data['data']);
    }
    if (dataClassName == 'OfflineSyncViolationOperation') {
      return deserialize<_ijw2vw1z.OfflineSyncViolationOperation>(data['data']);
    }
    if (dataClassName == 'OfflineSyncViolationType') {
      return deserialize<_itf31ci3.OfflineSyncViolationType>(data['data']);
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
        } on _iss.DeserializationClassNameNotFoundException catch (_) {}
      }
    }
    return deserializeByClassName(value);
  }

  @override
  _isd.Table? getTableForType(Type t) {
    switch (t) {
      case _ikikkl0e.CrdtDataAttemptedValue:
        return _ikikkl0e.CrdtDataAttemptedValue.t;
      case _ixchaeer.CrdtDataDeleted:
        return _ixchaeer.CrdtDataDeleted.t;
      case _iwcj1b8j.CrdtDataField:
        return _iwcj1b8j.CrdtDataField.t;
      case _iokmrb1h.CrdtDataRow:
        return _iokmrb1h.CrdtDataRow.t;
      case _iyfv8jet.CrdtNode:
        return _iyfv8jet.CrdtNode.t;
      case _ifj6lhq8.OfflineSyncSpace:
        return _ifj6lhq8.OfflineSyncSpace.t;
      case _i75umry7.OfflineSyncSpaceMember:
        return _i75umry7.OfflineSyncSpaceMember.t;
      case _it7grqg6.OfflineSyncSpaceNode:
        return _it7grqg6.OfflineSyncSpaceNode.t;
      case _iy534gq7.CrdtSchemaColumn:
        return _iy534gq7.CrdtSchemaColumn.t;
      case _ik8xyqdv.CrdtSchemaTable:
        return _ik8xyqdv.CrdtSchemaTable.t;
      case _iucor0s6.OfflineSyncIntegrityViolation:
        return _iucor0s6.OfflineSyncIntegrityViolation.t;
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
