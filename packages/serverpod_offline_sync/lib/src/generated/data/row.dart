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
// ignore_for_file: unnecessary_null_comparison

import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// CRDT data rows table.
///
/// This table stores the data for all tables that are registered for CRDT
/// synchronization. It is used to interact with the CRDT data.
///
/// The row is also the HLC timestamp for when it was inserted. This is used to
/// avoid creating one entry per field until a field is updated.
abstract class CrdtDataRow extends _icw2tu00.BaseHlc
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
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
    _icw2tu00.CrdtDataRowVisibility? visibility,
    this.deleted,
    this.fields,
  }) : visibility = visibility ?? _icw2tu00.CrdtDataRowVisibility.userInsert;

  factory CrdtDataRow({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int scopeId,
    _icw2tu00.CrdtScope? scope,
    required int tblId,
    _icw2tu00.CrdtSchemaTable? tbl,
    required _iss.UuidValue uuidRowId,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataRowVisibility? visibility,
    _icw2tu00.CrdtDataDeleted? deleted,
    List<_icw2tu00.CrdtDataField>? fields,
  }) = _CrdtDataRowImpl;

  factory CrdtDataRow.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataRow(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      scopeId: jsonSerialization['scopeId'] as int,
      scope: jsonSerialization['scope'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtScope>(
              jsonSerialization['scope'],
            ),
      tblId: jsonSerialization['tblId'] as int,
      tbl: jsonSerialization['tbl'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtSchemaTable>(
              jsonSerialization['tbl'],
            ),
      uuidRowId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['node'],
            ),
      visibility: jsonSerialization['visibility'] == null
          ? null
          : _icw2tu00.CrdtDataRowVisibility.fromJson(
              (jsonSerialization['visibility'] as int),
            ),
      deleted: jsonSerialization['deleted'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataDeleted>(
              jsonSerialization['deleted'],
            ),
      fields: jsonSerialization['fields'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<List<_icw2tu00.CrdtDataField>>(
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
  _icw2tu00.CrdtScope? scope;

  int tblId;

  /// Reference to the table this row belongs to.
  _icw2tu00.CrdtSchemaTable? tbl;

  /// Row identifier.
  _iss.UuidValue uuidRowId;

  int nodeId;

  /// The node that inserted the row with the HLC timestamp.
  _icw2tu00.CrdtNode? node;

  /// Materialized visibility state for domain queries.
  ///
  /// Updated by user tombstone writes and foreign key projection. Visible
  /// states are listed before hidden states in CrdtDataRowVisibility.
  _icw2tu00.CrdtDataRowVisibility visibility;

  /// The synced user tombstone for this row.
  ///
  /// Only present after the first user visibility change event has been recorded.
  /// Projection may keep a visible [visibility] while a user delete tombstone exists.
  _icw2tu00.CrdtDataDeleted? deleted;

  /// The fields for this row.
  List<_icw2tu00.CrdtDataField>? fields;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataRow]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtDataRow copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? scopeId,
    _icw2tu00.CrdtScope? scope,
    int? tblId,
    _icw2tu00.CrdtSchemaTable? tbl,
    _iss.UuidValue? uuidRowId,
    int? nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataRowVisibility? visibility,
    _icw2tu00.CrdtDataDeleted? deleted,
    List<_icw2tu00.CrdtDataField>? fields,
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
    _icw2tu00.CrdtScopeInclude? scope,
    _icw2tu00.CrdtSchemaTableInclude? tbl,
    _icw2tu00.CrdtNodeInclude? node,
    _icw2tu00.CrdtDataDeletedInclude? deleted,
    _icw2tu00.CrdtDataFieldIncludeList? fields,
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
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
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
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataRowImpl extends CrdtDataRow {
  _CrdtDataRowImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int scopeId,
    _icw2tu00.CrdtScope? scope,
    required int tblId,
    _icw2tu00.CrdtSchemaTable? tbl,
    required _iss.UuidValue uuidRowId,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataRowVisibility? visibility,
    _icw2tu00.CrdtDataDeleted? deleted,
    List<_icw2tu00.CrdtDataField>? fields,
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
  @_iss.useResult
  @override
  CrdtDataRow copyWith({
    Object? id = _Undefined,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? scopeId,
    Object? scope = _Undefined,
    int? tblId,
    Object? tbl = _Undefined,
    _iss.UuidValue? uuidRowId,
    int? nodeId,
    Object? node = _Undefined,
    _icw2tu00.CrdtDataRowVisibility? visibility,
    Object? deleted = _Undefined,
    Object? fields = _Undefined,
  }) {
    return CrdtDataRow(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      scopeId: scopeId ?? this.scopeId,
      scope: scope is _icw2tu00.CrdtScope? ? scope : this.scope?.copyWith(),
      tblId: tblId ?? this.tblId,
      tbl: tbl is _icw2tu00.CrdtSchemaTable? ? tbl : this.tbl?.copyWith(),
      uuidRowId: uuidRowId ?? this.uuidRowId,
      nodeId: nodeId ?? this.nodeId,
      node: node is _icw2tu00.CrdtNode? ? node : this.node?.copyWith(),
      visibility: visibility ?? this.visibility,
      deleted: deleted is _icw2tu00.CrdtDataDeleted?
          ? deleted
          : this.deleted?.copyWith(),
      fields: fields is List<_icw2tu00.CrdtDataField>?
          ? fields
          : this.fields?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class CrdtDataRowUpdateTable extends _isd.UpdateTable<CrdtDataRowTable> {
  CrdtDataRowUpdateTable(super.table);

  _isd.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _isd.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _isd.ColumnValue<int, int> hlcCounter(int value) => _isd.ColumnValue(
    table.hlcCounter,
    value,
  );

  _isd.ColumnValue<int, int> scopeId(int value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<int, int> tblId(int value) => _isd.ColumnValue(
    table.tblId,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> uuidRowId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.uuidRowId,
    value,
  );

  _isd.ColumnValue<int, int> nodeId(int value) => _isd.ColumnValue(
    table.nodeId,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.CrdtDataRowVisibility,
    _icw2tu00.CrdtDataRowVisibility
  >
  visibility(_icw2tu00.CrdtDataRowVisibility value) => _isd.ColumnValue(
    table.visibility,
    value,
  );
}

class CrdtDataRowTable extends _isd.Table<int?> {
  CrdtDataRowTable({super.tableRelation}) : super(tableName: 'crdt_data_rows') {
    updateTable = CrdtDataRowUpdateTable(this);
    hlcDatetime = _isd.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _isd.ColumnInt(
      'hlcCounter',
      this,
    );
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    tblId = _isd.ColumnInt(
      'tblId',
      this,
    );
    uuidRowId = _isd.ColumnUuid(
      'uuidRowId',
      this,
    );
    nodeId = _isd.ColumnInt(
      'nodeId',
      this,
    );
    visibility = _isd.ColumnEnum(
      'visibility',
      this,
      _isd.EnumSerialization.byIndex,
      hasDefault: true,
    );
  }

  late final CrdtDataRowUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _isd.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _isd.ColumnInt hlcCounter;

  late final _isd.ColumnInt scopeId;

  /// Identifier for the scope that owns the data.
  _icw2tu00.CrdtScopeTable? _scope;

  late final _isd.ColumnInt tblId;

  /// Reference to the table this row belongs to.
  _icw2tu00.CrdtSchemaTableTable? _tbl;

  /// Row identifier.
  late final _isd.ColumnUuid uuidRowId;

  late final _isd.ColumnInt nodeId;

  /// The node that inserted the row with the HLC timestamp.
  _icw2tu00.CrdtNodeTable? _node;

  /// Materialized visibility state for domain queries.
  ///
  /// Updated by user tombstone writes and foreign key projection. Visible
  /// states are listed before hidden states in CrdtDataRowVisibility.
  late final _isd.ColumnEnum<_icw2tu00.CrdtDataRowVisibility> visibility;

  /// The synced user tombstone for this row.
  ///
  /// Only present after the first user visibility change event has been recorded.
  /// Projection may keep a visible [visibility] while a user delete tombstone exists.
  _icw2tu00.CrdtDataDeletedTable? _deleted;

  /// The fields for this row.
  _icw2tu00.CrdtDataFieldTable? ___fields;

  /// The fields for this row.
  _isd.ManyRelation<_icw2tu00.CrdtDataFieldTable>? _fields;

  _icw2tu00.CrdtScopeTable get scope {
    if (_scope != null) return _scope!;
    _scope = _isd.createRelationTable(
      relationFieldName: 'scope',
      field: CrdtDataRow.t.scopeId,
      foreignField: _icw2tu00.CrdtScope.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtScopeTable(tableRelation: foreignTableRelation),
    );
    return _scope!;
  }

  _icw2tu00.CrdtSchemaTableTable get tbl {
    if (_tbl != null) return _tbl!;
    _tbl = _isd.createRelationTable(
      relationFieldName: 'tbl',
      field: CrdtDataRow.t.tblId,
      foreignField: _icw2tu00.CrdtSchemaTable.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtSchemaTableTable(tableRelation: foreignTableRelation),
    );
    return _tbl!;
  }

  _icw2tu00.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _isd.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataRow.t.nodeId,
      foreignField: _icw2tu00.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  _icw2tu00.CrdtDataDeletedTable get deleted {
    if (_deleted != null) return _deleted!;
    _deleted = _isd.createRelationTable(
      relationFieldName: 'deleted',
      field: CrdtDataRow.t.id,
      foreignField: _icw2tu00.CrdtDataDeleted.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataDeletedTable(tableRelation: foreignTableRelation),
    );
    return _deleted!;
  }

  _icw2tu00.CrdtDataFieldTable get __fields {
    if (___fields != null) return ___fields!;
    ___fields = _isd.createRelationTable(
      relationFieldName: '__fields',
      field: CrdtDataRow.t.id,
      foreignField: _icw2tu00.CrdtDataField.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    return ___fields!;
  }

  _isd.ManyRelation<_icw2tu00.CrdtDataFieldTable> get fields {
    if (_fields != null) return _fields!;
    var relationTable = _isd.createRelationTable(
      relationFieldName: 'fields',
      field: CrdtDataRow.t.id,
      foreignField: _icw2tu00.CrdtDataField.t.rowId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    _fields = _isd.ManyRelation<_icw2tu00.CrdtDataFieldTable>(
      tableWithRelations: relationTable,
      table: _icw2tu00.CrdtDataFieldTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _fields!;
  }

  @override
  List<_isd.Column> get columns => [
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
  _isd.Table? getRelationTable(String relationField) {
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

class CrdtDataRowInclude extends _isd.IncludeObject {
  CrdtDataRowInclude._({
    _icw2tu00.CrdtScopeInclude? scope,
    _icw2tu00.CrdtSchemaTableInclude? tbl,
    _icw2tu00.CrdtNodeInclude? node,
    _icw2tu00.CrdtDataDeletedInclude? deleted,
    _icw2tu00.CrdtDataFieldIncludeList? fields,
  }) {
    _scope = scope;
    _tbl = tbl;
    _node = node;
    _deleted = deleted;
    _fields = fields;
  }

  _icw2tu00.CrdtScopeInclude? _scope;

  _icw2tu00.CrdtSchemaTableInclude? _tbl;

  _icw2tu00.CrdtNodeInclude? _node;

  _icw2tu00.CrdtDataDeletedInclude? _deleted;

  _icw2tu00.CrdtDataFieldIncludeList? _fields;

  @override
  Map<String, _isd.Include?> get includes => {
    'scope': _scope,
    'tbl': _tbl,
    'node': _node,
    'deleted': _deleted,
    'fields': _fields,
  };

  @override
  _isd.Table<int?> get table => CrdtDataRow.t;
}

class CrdtDataRowIncludeList extends _isd.IncludeList {
  CrdtDataRowIncludeList._({
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataRow.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtDataRow.t;
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtDataRowInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataRow> rows, {
    required _isd.ColumnSelections<CrdtDataRowTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataRowTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow row, {
    required _isd.ColumnSelections<CrdtDataRowTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataRowTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _isd.ColumnSelections<CrdtDataRowTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow row, {
    _isd.ColumnSelections<CrdtDataRowTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtDataRowUpdateTable> columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtDataRowUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CrdtDataRowTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataRow> rows, {
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataRowTable> where,
    _isd.OrderByBuilder<CrdtDataRowTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataRowTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataRowTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataRow>(
      where: where?.call(CrdtDataRow.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataRow] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataRowTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
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
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    List<_icw2tu00.CrdtDataField> crdtDataField, {
    _isd.Transaction? transaction,
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
    await session.db.update<_icw2tu00.CrdtDataField>(
      $crdtDataField,
      columns: [_icw2tu00.CrdtDataField.t.rowId],
      transaction: transaction,
    );
  }
}

class CrdtDataRowAttachRowRepository {
  const CrdtDataRowAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataRow] and [CrdtScope]
  /// by setting the [CrdtDataRow]'s foreign key `scopeId` to refer to the [CrdtScope].
  Future<void> scope(
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _icw2tu00.CrdtScope scope, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _icw2tu00.CrdtSchemaTable tbl, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _icw2tu00.CrdtNode node, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _icw2tu00.CrdtDataDeleted deleted, {
    _isd.Transaction? transaction,
  }) async {
    if (deleted.id == null) {
      throw ArgumentError.notNull('deleted.id');
    }
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }

    var $deleted = deleted.copyWith(rowId: crdtDataRow.id);
    await session.db.updateRow<_icw2tu00.CrdtDataDeleted>(
      $deleted,
      columns: [_icw2tu00.CrdtDataDeleted.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between this [CrdtDataRow] and the given [CrdtDataField]
  /// by setting the [CrdtDataField]'s foreign key `rowId` to refer to this [CrdtDataRow].
  Future<void> fields(
    _isd.DatabaseSession session,
    CrdtDataRow crdtDataRow,
    _icw2tu00.CrdtDataField crdtDataField, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (crdtDataRow.id == null) {
      throw ArgumentError.notNull('crdtDataRow.id');
    }

    var $crdtDataField = crdtDataField.copyWith(rowId: crdtDataRow.id);
    await session.db.updateRow<_icw2tu00.CrdtDataField>(
      $crdtDataField,
      columns: [_icw2tu00.CrdtDataField.t.rowId],
      transaction: transaction,
    );
  }
}
