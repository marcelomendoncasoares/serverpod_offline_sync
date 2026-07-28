/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as _i1;
import 'package:serverpod_database/serverpod_database.dart' as _i2;
import 'package:serverpod_client/serverpod_client.dart' as _i3;
import '../data/row_visibility.dart' as _i4;
import '../node/scope.dart' as _i5;
import '../schema/table.dart' as _i6;
import '../node/node.dart' as _i7;
import '../data/deleted.dart' as _i8;
import '../data/field.dart' as _i9;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i10;

/// CRDT data rows table.
///
/// This table stores the data for all tables that are registered for CRDT
/// synchronization. It is used to interact with the CRDT data.
///
/// The row is also the HLC timestamp for when it was inserted. This is used to
/// avoid creating one entry per field until a field is updated.
abstract class CrdtDataRow extends _i1.BaseHlc
    implements _i2.TableRow<int?>, _i3.ProtocolSerialization {
  CrdtDataRow._({
    this.id,
    required super.hlcDatetime,
    required super.hlcCounter,
    required this.scopeId,
    this.scope,
    required this.tblId,
    this.tbl,
    required this.uuidRowId,
    required this.nodeId,
    this.node,
    _i4.CrdtDataRowVisibility? visibility,
    this.deleted,
    this.fields,
  }) : visibility = visibility ?? _i4.CrdtDataRowVisibility.userInsert;

  factory CrdtDataRow({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int scopeId,
    _i5.CrdtScope? scope,
    required int tblId,
    _i6.CrdtSchemaTable? tbl,
    required _i3.UuidValue uuidRowId,
    required int nodeId,
    _i7.CrdtNode? node,
    _i4.CrdtDataRowVisibility? visibility,
    _i8.CrdtDataDeleted? deleted,
    List<_i9.CrdtDataField>? fields,
  }) = _CrdtDataRowImpl;

  factory CrdtDataRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataRow(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _i3.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      scopeId: jsonSerialization['scopeId'] as int,
      scope: jsonSerialization['scope'] == null
          ? null
          : _i10.Protocol().deserialize<_i5.CrdtScope>(
              jsonSerialization['scope'],
            ),
      tblId: jsonSerialization['tblId'] as int,
      tbl: jsonSerialization['tbl'] == null
          ? null
          : _i10.Protocol().deserialize<_i6.CrdtSchemaTable>(
              jsonSerialization['tbl'],
            ),
      uuidRowId: _i3.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _i10.Protocol().deserialize<_i7.CrdtNode>(
              jsonSerialization['node'],
            ),
      visibility: jsonSerialization['visibility'] == null
          ? null
          : _i4.CrdtDataRowVisibility.fromJson(
              (jsonSerialization['visibility'] as int),
            ),
      deleted: jsonSerialization['deleted'] == null
          ? null
          : _i10.Protocol().deserialize<_i8.CrdtDataDeleted>(
              jsonSerialization['deleted'],
            ),
      fields: jsonSerialization['fields'] == null
          ? null
          : _i10.Protocol().deserialize<List<_i9.CrdtDataField>>(
              jsonSerialization['fields'],
            ),
    );
  }

  static final t = CrdtDataRowTable();

  static const db = CrdtDataRowRepository._();

  @override
  int? id;

  int scopeId;

  /// Identifier for the scope that owns the data.
  _i5.CrdtScope? scope;

  int tblId;

  /// Reference to the table this row belongs to.
  _i6.CrdtSchemaTable? tbl;

  /// Row identifier.
  _i3.UuidValue uuidRowId;

  int nodeId;

  /// The node that inserted the row with the HLC timestamp.
  _i7.CrdtNode? node;

  /// Materialized visibility state for domain queries.
  ///
  /// Updated by user tombstone writes and foreign key projection. Visible
  /// states are listed before hidden states in CrdtDataRowVisibility.
  _i4.CrdtDataRowVisibility visibility;

  /// The synced user tombstone for this row.
  ///
  /// Only present after the first user visibility change event has been recorded.
  /// Projection may keep a visible [visibility] while a user delete tombstone exists.
  _i8.CrdtDataDeleted? deleted;

  /// The fields for this row.
  List<_i9.CrdtDataField>? fields;

  @override
  _i2.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataRow]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i3.useResult
  CrdtDataRow copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? scopeId,
    _i5.CrdtScope? scope,
    int? tblId,
    _i6.CrdtSchemaTable? tbl,
    _i3.UuidValue? uuidRowId,
    int? nodeId,
    _i7.CrdtNode? node,
    _i4.CrdtDataRowVisibility? visibility,
    _i8.CrdtDataDeleted? deleted,
    List<_i9.CrdtDataField>? fields,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataRow',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJson(),
      'tblId': tblId,
      if (tbl != null) 'tbl': tbl?.toJson(),
      'uuidRowId': uuidRowId.toJson(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJson(),
      'visibility': visibility.toJson(),
      if (deleted != null) 'deleted': deleted?.toJson(),
      if (fields != null)
        'fields': fields?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataRow',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJsonForProtocol(),
      'tblId': tblId,
      if (tbl != null) 'tbl': tbl?.toJsonForProtocol(),
      'uuidRowId': uuidRowId.toJson(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJsonForProtocol(),
      'visibility': visibility.toJson(),
      if (deleted != null) 'deleted': deleted?.toJsonForProtocol(),
      if (fields != null)
        'fields': fields?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  static CrdtDataRowInclude include({
    _i5.CrdtScopeInclude? scope,
    _i6.CrdtSchemaTableInclude? tbl,
    _i7.CrdtNodeInclude? node,
    _i8.CrdtDataDeletedInclude? deleted,
    _i9.CrdtDataFieldIncludeList? fields,
  }) {
    return CrdtDataRowInclude._(
      scope: scope,
      tbl: tbl,
      node: node,
      deleted: deleted,
      fields: fields,
    );
  }

  static CrdtDataRowIncludeList includeList({
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    CrdtDataRowInclude? include,
  }) {
    return CrdtDataRowIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i3.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataRowImpl extends CrdtDataRow {
  _CrdtDataRowImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int scopeId,
    _i5.CrdtScope? scope,
    required int tblId,
    _i6.CrdtSchemaTable? tbl,
    required _i3.UuidValue uuidRowId,
    required int nodeId,
    _i7.CrdtNode? node,
    _i4.CrdtDataRowVisibility? visibility,
    _i8.CrdtDataDeleted? deleted,
    List<_i9.CrdtDataField>? fields,
  }) : super._(
         id: id,
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         scopeId: scopeId,
         scope: scope,
         tblId: tblId,
         tbl: tbl,
         uuidRowId: uuidRowId,
         nodeId: nodeId,
         node: node,
         visibility: visibility,
         deleted: deleted,
         fields: fields,
       );

  /// Returns a shallow copy of this [CrdtDataRow]
  /// with some or all fields replaced by the given arguments.
  @_i3.useResult
  @override
  CrdtDataRow copyWith({
    Object? id = _Undefined,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? scopeId,
    Object? scope = _Undefined,
    int? tblId,
    Object? tbl = _Undefined,
    _i3.UuidValue? uuidRowId,
    int? nodeId,
    Object? node = _Undefined,
    _i4.CrdtDataRowVisibility? visibility,
    Object? deleted = _Undefined,
    Object? fields = _Undefined,
  }) {
    return CrdtDataRow(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      scopeId: scopeId ?? this.scopeId,
      scope: scope is _i5.CrdtScope? ? scope : this.scope?.copyWith(),
      tblId: tblId ?? this.tblId,
      tbl: tbl is _i6.CrdtSchemaTable? ? tbl : this.tbl?.copyWith(),
      uuidRowId: uuidRowId ?? this.uuidRowId,
      nodeId: nodeId ?? this.nodeId,
      node: node is _i7.CrdtNode? ? node : this.node?.copyWith(),
      visibility: visibility ?? this.visibility,
      deleted: deleted is _i8.CrdtDataDeleted?
          ? deleted
          : this.deleted?.copyWith(),
      fields: fields is List<_i9.CrdtDataField>?
          ? fields
          : this.fields?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class CrdtDataRowUpdateTable extends _i2.UpdateTable<CrdtDataRowTable> {
  CrdtDataRowUpdateTable(super.table);

  _i2.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _i2.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _i2.ColumnValue<int, int> hlcCounter(int value) => _i2.ColumnValue(
    table.hlcCounter,
    value,
  );

  _i2.ColumnValue<int, int> scopeId(int value) => _i2.ColumnValue(
    table.scopeId,
    value,
  );

  _i2.ColumnValue<int, int> tblId(int value) => _i2.ColumnValue(
    table.tblId,
    value,
  );

  _i2.ColumnValue<_i3.UuidValue, _i3.UuidValue> uuidRowId(
    _i3.UuidValue value,
  ) => _i2.ColumnValue(
    table.uuidRowId,
    value,
  );

  _i2.ColumnValue<int, int> nodeId(int value) => _i2.ColumnValue(
    table.nodeId,
    value,
  );

  _i2.ColumnValue<_i4.CrdtDataRowVisibility, _i4.CrdtDataRowVisibility>
  visibility(_i4.CrdtDataRowVisibility value) => _i2.ColumnValue(
    table.visibility,
    value,
  );
}

class CrdtDataRowTable extends _i2.Table<int?> {
  CrdtDataRowTable({super.tableRelation}) : super(tableName: 'crdt_data_rows') {
    updateTable = CrdtDataRowUpdateTable(this);
    hlcDatetime = _i2.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _i2.ColumnInt(
      'hlcCounter',
      this,
    );
    scopeId = _i2.ColumnInt(
      'scopeId',
      this,
    );
    tblId = _i2.ColumnInt(
      'tblId',
      this,
    );
    uuidRowId = _i2.ColumnUuid(
      'uuidRowId',
      this,
    );
    nodeId = _i2.ColumnInt(
      'nodeId',
      this,
    );
    visibility = _i2.ColumnEnum(
      'visibility',
      this,
      _i2.EnumSerialization.byIndex,
      hasDefault: true,
    );
  }

  late final CrdtDataRowUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _i2.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _i2.ColumnInt hlcCounter;

  late final _i2.ColumnInt scopeId;

  /// Identifier for the scope that owns the data.
  _i5.CrdtScopeTable? _scope;

  late final _i2.ColumnInt tblId;

  /// Reference to the table this row belongs to.
  _i6.CrdtSchemaTableTable? _tbl;

  /// Row identifier.
  late final _i2.ColumnUuid uuidRowId;

  late final _i2.ColumnInt nodeId;

  /// The node that inserted the row with the HLC timestamp.
  _i7.CrdtNodeTable? _node;

  /// Materialized visibility state for domain queries.
  ///
  /// Updated by user tombstone writes and foreign key projection. Visible
  /// states are listed before hidden states in CrdtDataRowVisibility.
  late final _i2.ColumnEnum<_i4.CrdtDataRowVisibility> visibility;

  /// The synced user tombstone for this row.
  ///
  /// Only present after the first user visibility change event has been recorded.
  /// Projection may keep a visible [visibility] while a user delete tombstone exists.
  _i8.CrdtDataDeletedTable? _deleted;

  /// The fields for this row.
  _i9.CrdtDataFieldTable? ___fields;

  /// The fields for this row.
  _i2.ManyRelation<_i9.CrdtDataFieldTable>? _fields;

  _i5.CrdtScopeTable get scope {
    if (_scope != null) return _scope!;
    _scope = _i2.createRelationTable(
      relationFieldName: 'scope',
      field: CrdtDataRow.t.scopeId,
      foreignField: _i5.CrdtScope.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i5.CrdtScopeTable(tableRelation: foreignTableRelation),
    );
    return _scope!;
  }

  _i6.CrdtSchemaTableTable get tbl {
    if (_tbl != null) return _tbl!;
    _tbl = _i2.createRelationTable(
      relationFieldName: 'tbl',
      field: CrdtDataRow.t.tblId,
      foreignField: _i6.CrdtSchemaTable.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i6.CrdtSchemaTableTable(tableRelation: foreignTableRelation),
    );
    return _tbl!;
  }

  _i7.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _i2.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataRow.t.nodeId,
      foreignField: _i7.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i7.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  _i8.CrdtDataDeletedTable get deleted {
    if (_deleted != null) return _deleted!;
    _deleted = _i2.createRelationTable(
      relationFieldName: 'deleted',
      field: CrdtDataRow.t.id,
      foreignField: _i8.CrdtDataDeleted.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i8.CrdtDataDeletedTable(tableRelation: foreignTableRelation),
    );
    return _deleted!;
  }

  _i9.CrdtDataFieldTable get __fields {
    if (___fields != null) return ___fields!;
    ___fields = _i2.createRelationTable(
      relationFieldName: '__fields',
      field: CrdtDataRow.t.id,
      foreignField: _i9.CrdtDataField.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i9.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    return ___fields!;
  }

  _i2.ManyRelation<_i9.CrdtDataFieldTable> get fields {
    if (_fields != null) return _fields!;
    var relationTable = _i2.createRelationTable(
      relationFieldName: 'fields',
      field: CrdtDataRow.t.id,
      foreignField: _i9.CrdtDataField.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i9.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    _fields = _i2.ManyRelation<_i9.CrdtDataFieldTable>(
      tableWithRelations: relationTable,
      table: _i9.CrdtDataFieldTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _fields!;
  }

  @override
  List<_i2.Column> get columns => [
    id,
    hlcDatetime,
    hlcCounter,
    scopeId,
    tblId,
    uuidRowId,
    nodeId,
    visibility,
  ];

  @override
  _i2.Table? getRelationTable(String relationField) {
    if (relationField == 'scope') {
      return scope;
    }
    if (relationField == 'tbl') {
      return tbl;
    }
    if (relationField == 'node') {
      return node;
    }
    if (relationField == 'deleted') {
      return deleted;
    }
    if (relationField == 'fields') {
      return __fields;
    }
    return null;
  }
}

class CrdtDataRowInclude extends _i2.IncludeObject {
  CrdtDataRowInclude._({
    _i5.CrdtScopeInclude? scope,
    _i6.CrdtSchemaTableInclude? tbl,
    _i7.CrdtNodeInclude? node,
    _i8.CrdtDataDeletedInclude? deleted,
    _i9.CrdtDataFieldIncludeList? fields,
  }) {
    _scope = scope;
    _tbl = tbl;
    _node = node;
    _deleted = deleted;
    _fields = fields;
  }

  _i5.CrdtScopeInclude? _scope;

  _i6.CrdtSchemaTableInclude? _tbl;

  _i7.CrdtNodeInclude? _node;

  _i8.CrdtDataDeletedInclude? _deleted;

  _i9.CrdtDataFieldIncludeList? _fields;

  @override
  Map<String, _i2.Include?> get includes => {
    'scope': _scope,
    'tbl': _tbl,
    'node': _node,
    'deleted': _deleted,
    'fields': _fields,
  };

  @override
  _i2.Table<int?> get table => CrdtDataRow.t;
}

class CrdtDataRowIncludeList extends _i2.IncludeList {
  CrdtDataRowIncludeList._({
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataRow.t);
  }

  @override
  Map<String, _i2.Include?> get includes => include?.includes ?? {};

  @override
  _i2.Table<int?> get table => CrdtDataRow.t;
}

class CrdtDataRowRepository {
  const CrdtDataRowRepository._();

  final attach = const CrdtDataRowAttachRepository._();

  final attachRow = const CrdtDataRowAttachRowRepository._();

  /// Returns a list of [CrdtDataRow]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<CrdtDataRow>> find(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataRowInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataRow>(
      where: where?.call(CrdtDataRow.t),
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtDataRow] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<CrdtDataRow?> findFirstRow(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? offset,
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataRowInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataRow>(
      where: where?.call(CrdtDataRow.t),
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataRow] by its [id] or null if no such row exists.
  Future<CrdtDataRow?> findById(
    _i2.DatabaseSession session,
    int id, {
    _i2.Transaction? transaction,
    CrdtDataRowInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtDataRow>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtDataRow]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtDataRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> insert(
    _i2.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _i2.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtDataRow>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtDataRow] and returns the inserted row.
  ///
  /// The returned [CrdtDataRow] will have its `id` field set.
  Future<CrdtDataRow> insertRow(
    _i2.DatabaseSession session,
    CrdtDataRow row, {
    _i2.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtDataRow>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtDataRow]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [CrdtDataRow]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> upsert(
    _i2.DatabaseSession session,
    List<CrdtDataRow> rows, {
    required _i2.ColumnSelections<CrdtDataRowTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataRowTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? updateWhere,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtDataRow>(
      rows,
      conflictColumns: conflictColumns(CrdtDataRow.t),
      updateColumns: updateColumns?.call(CrdtDataRow.t),
      updateWhere: updateWhere?.call(CrdtDataRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtDataRow] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [CrdtDataRow] will have its `id` field set.
  Future<CrdtDataRow?> upsertRow(
    _i2.DatabaseSession session,
    CrdtDataRow row, {
    required _i2.ColumnSelections<CrdtDataRowTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataRowTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? updateWhere,
    _i2.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtDataRow>(
      row,
      conflictColumns: conflictColumns(CrdtDataRow.t),
      updateColumns: updateColumns?.call(CrdtDataRow.t),
      updateWhere: updateWhere?.call(CrdtDataRow.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataRow]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> update(
    _i2.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _i2.ColumnSelections<CrdtDataRowTable>? columns,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtDataRow>(
      rows,
      columns: columns?.call(CrdtDataRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtDataRow]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtDataRow> updateRow(
    _i2.DatabaseSession session,
    CrdtDataRow row, {
    _i2.ColumnSelections<CrdtDataRowTable>? columns,
    _i2.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtDataRow>(
      row,
      columns: columns?.call(CrdtDataRow.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtDataRow] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtDataRow?> updateById(
    _i2.DatabaseSession session,
    int id, {
    required _i2.ColumnValueListBuilder<CrdtDataRowUpdateTable> columnValues,
    _i2.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtDataRow>(
      id,
      columnValues: columnValues(CrdtDataRow.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataRow]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> updateWhere(
    _i2.DatabaseSession session, {
    required _i2.ColumnValueListBuilder<CrdtDataRowUpdateTable> columnValues,
    required _i2.WhereExpressionBuilder<CrdtDataRowTable> where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataRow>(
      columnValues: columnValues(CrdtDataRow.t.updateTable),
      where: where(CrdtDataRow.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtDataRow]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> delete(
    _i2.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataRow>(
      rows,
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataRow].
  Future<CrdtDataRow> deleteRow(
    _i2.DatabaseSession session,
    CrdtDataRow row, {
    _i2.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtDataRow>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataRow>> deleteWhere(
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataRowTable> where,
    _i2.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataRow>(
      where: where(CrdtDataRow.t),
      orderBy: orderBy?.call(CrdtDataRow.t),
      orderByList: orderByList?.call(CrdtDataRow.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    _i2.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataRow>(
      where: where?.call(CrdtDataRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataRow] rows matching the [where] expression.
  Future<void> lockRows(
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataRowTable> where,
    required _i2.LockMode lockMode,
    required _i2.Transaction transaction,
    _i2.LockBehavior lockBehavior = _i2.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtDataRow>(
      where: where(CrdtDataRow.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtDataRowAttachRepository {
  const CrdtDataRowAttachRepository._();

  /// Creates a relation between this [CrdtDataRow] and the given [CrdtDataField]s
  /// by setting each [CrdtDataField]'s foreign key `rowId` to refer to this [CrdtDataRow].
  Future<void> fields(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    List<_i9.CrdtDataField> crdtDataField, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataField.any((e) => e.id == null)) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }

    var $crdtDataField = crdtDataField
        .map((e) => e.copyWith(rowId: crdtDataRow.id))
        .toList();
    await session.db.update<_i9.CrdtDataField>(
      $crdtDataField,
      columns: [_i9.CrdtDataField.t.rowId],
      transaction: transaction,
    );
  }
}

class CrdtDataRowAttachRowRepository {
  const CrdtDataRowAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataRow] and [CrdtScope]
  /// by setting the [CrdtDataRow]'s foreign key `scopeId` to refer to the [CrdtScope].
  Future<void> scope(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _i5.CrdtScope scope, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }
    if (scope.id == null) {
      throw ArgumentError.notNull('scope.id');
    }

    var $crdtDataRow = crdtDataRow.copyWith(scopeId: scope.id);
    await session.db.updateRow<CrdtDataRow>(
      $crdtDataRow,
      columns: [CrdtDataRow.t.scopeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataRow] and [CrdtSchemaTable]
  /// by setting the [CrdtDataRow]'s foreign key `tblId` to refer to the [CrdtSchemaTable].
  Future<void> tbl(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _i6.CrdtSchemaTable tbl, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }
    if (tbl.id == null) {
      throw ArgumentError.notNull('tbl.id');
    }

    var $crdtDataRow = crdtDataRow.copyWith(tblId: tbl.id);
    await session.db.updateRow<CrdtDataRow>(
      $crdtDataRow,
      columns: [CrdtDataRow.t.tblId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataRow] and [CrdtNode]
  /// by setting the [CrdtDataRow]'s foreign key `nodeId` to refer to the [CrdtNode].
  Future<void> node(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _i7.CrdtNode node, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }
    if (node.id == null) {
      throw ArgumentError.notNull('node.id');
    }

    var $crdtDataRow = crdtDataRow.copyWith(nodeId: node.id);
    await session.db.updateRow<CrdtDataRow>(
      $crdtDataRow,
      columns: [CrdtDataRow.t.nodeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataRow] and [CrdtDataDeleted]
  /// by setting the [CrdtDataRow]'s foreign key `id` to refer to the [CrdtDataDeleted].
  Future<void> deleted(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _i8.CrdtDataDeleted deleted, {
    _i2.Transaction? transaction,
  }) async {
    if (deleted.id == null) {
      throw ArgumentError.notNull('deleted.id');
    }
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }

    var $deleted = deleted.copyWith(rowId: crdtDataRow.id);
    await session.db.updateRow<_i8.CrdtDataDeleted>(
      $deleted,
      columns: [_i8.CrdtDataDeleted.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between this [CrdtDataRow] and the given [CrdtDataField]
  /// by setting the [CrdtDataField]'s foreign key `rowId` to refer to this [CrdtDataRow].
  Future<void> fields(
    _i2.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _i9.CrdtDataField crdtDataField, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }

    var $crdtDataField = crdtDataField.copyWith(rowId: crdtDataRow.id);
    await session.db.updateRow<_i9.CrdtDataField>(
      $crdtDataField,
      columns: [_i9.CrdtDataField.t.rowId],
      transaction: transaction,
    );
  }
}
