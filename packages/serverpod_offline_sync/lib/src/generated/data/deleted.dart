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

/// CRDT visibility generation table.
///
/// This table stores materialized monotone CLFlag metadata after a visibility
/// change event has been recorded.
abstract class CrdtDataDeleted extends _icw2tu00.BaseHlc
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  CrdtDataDeleted._({
    this.id,
    required super.hlcDatetime,
    required super.hlcCounter,
    this.row,
    required this.rowId,
    required this.nodeId,
    this.node,
    required this.clFlag,
    required this.reason,
  });

  factory CrdtDataDeleted({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    _icw2tu00.CrdtDataRow? row,
    required int rowId,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    required int clFlag,
    required _icw2tu00.CrdtDataDeletedReason reason,
  }) = _CrdtDataDeletedImpl;

  factory CrdtDataDeleted.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataDeleted(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      row: jsonSerialization['row'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataRow>(
              jsonSerialization['row'],
            ),
      rowId: jsonSerialization['rowId'] as int,
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['node'],
            ),
      clFlag: jsonSerialization['clFlag'] as int,
      reason: _icw2tu00.CrdtDataDeletedReason.fromJson(
        (jsonSerialization['reason'] as int),
      ),
    );
  }

  static final t = CrdtDataDeletedTable();

  static const db = CrdtDataDeletedRepository._();

  @override
  int? id;

  /// Row whose visibility is tracked.
  _icw2tu00.CrdtDataRow? row;

  int rowId;

  int nodeId;

  /// The node that updated the field.
  _icw2tu00.CrdtNode? node;

  /// Monotone causal-length flag. Odd values are visible and even values are deleted.
  int clFlag;

  /// Why the row entered its current visibility generation.
  _icw2tu00.CrdtDataDeletedReason reason;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataDeleted]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtDataDeleted copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    _icw2tu00.CrdtDataRow? row,
    int? rowId,
    int? nodeId,
    _icw2tu00.CrdtNode? node,
    int? clFlag,
    _icw2tu00.CrdtDataDeletedReason? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataDeleted',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      if (row != null) 'row': row?.toJson(),
      'rowId': rowId,
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJson(),
      'clFlag': clFlag,
      'reason': reason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataDeleted',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      if (row != null) 'row': row?.toJsonForProtocol(),
      'rowId': rowId,
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJsonForProtocol(),
      'clFlag': clFlag,
      'reason': reason.toJson(),
    };
  }

  static CrdtDataDeletedInclude include({
    _icw2tu00.CrdtDataRowInclude? row,
    _icw2tu00.CrdtNodeInclude? node,
  }) {
    return CrdtDataDeletedInclude._(
      row: row,
      node: node,
    );
  }

  static CrdtDataDeletedIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    CrdtDataDeletedInclude? include,
  }) {
    return CrdtDataDeletedIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataDeletedImpl extends CrdtDataDeleted {
  _CrdtDataDeletedImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    _icw2tu00.CrdtDataRow? row,
    required int rowId,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    required int clFlag,
    required _icw2tu00.CrdtDataDeletedReason reason,
  }) : super._(
         id: id,
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         row: row,
         rowId: rowId,
         nodeId: nodeId,
         node: node,
         clFlag: clFlag,
         reason: reason,
       );

  /// Returns a shallow copy of this [CrdtDataDeleted]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtDataDeleted copyWith({
    Object? id = _Undefined,
    DateTime? hlcDatetime,
    int? hlcCounter,
    Object? row = _Undefined,
    int? rowId,
    int? nodeId,
    Object? node = _Undefined,
    int? clFlag,
    _icw2tu00.CrdtDataDeletedReason? reason,
  }) {
    return CrdtDataDeleted(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      row: row is _icw2tu00.CrdtDataRow? ? row : this.row?.copyWith(),
      rowId: rowId ?? this.rowId,
      nodeId: nodeId ?? this.nodeId,
      node: node is _icw2tu00.CrdtNode? ? node : this.node?.copyWith(),
      clFlag: clFlag ?? this.clFlag,
      reason: reason ?? this.reason,
    );
  }
}

class CrdtDataDeletedUpdateTable
    extends _isd.UpdateTable<CrdtDataDeletedTable> {
  CrdtDataDeletedUpdateTable(super.table);

  _isd.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _isd.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _isd.ColumnValue<int, int> hlcCounter(int value) => _isd.ColumnValue(
    table.hlcCounter,
    value,
  );

  _isd.ColumnValue<int, int> rowId(int value) => _isd.ColumnValue(
    table.rowId,
    value,
  );

  _isd.ColumnValue<int, int> nodeId(int value) => _isd.ColumnValue(
    table.nodeId,
    value,
  );

  _isd.ColumnValue<int, int> clFlag(int value) => _isd.ColumnValue(
    table.clFlag,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.CrdtDataDeletedReason,
    _icw2tu00.CrdtDataDeletedReason
  >
  reason(_icw2tu00.CrdtDataDeletedReason value) => _isd.ColumnValue(
    table.reason,
    value,
  );
}

class CrdtDataDeletedTable extends _isd.Table<int?> {
  CrdtDataDeletedTable({super.tableRelation})
    : super(tableName: 'crdt_data_tombstone') {
    updateTable = CrdtDataDeletedUpdateTable(this);
    hlcDatetime = _isd.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _isd.ColumnInt(
      'hlcCounter',
      this,
    );
    rowId = _isd.ColumnInt(
      'rowId',
      this,
    );
    nodeId = _isd.ColumnInt(
      'nodeId',
      this,
    );
    clFlag = _isd.ColumnInt(
      'clFlag',
      this,
    );
    reason = _isd.ColumnEnum(
      'reason',
      this,
      _isd.EnumSerialization.byIndex,
    );
  }

  late final CrdtDataDeletedUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _isd.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _isd.ColumnInt hlcCounter;

  /// Row whose visibility is tracked.
  _icw2tu00.CrdtDataRowTable? _row;

  late final _isd.ColumnInt rowId;

  late final _isd.ColumnInt nodeId;

  /// The node that updated the field.
  _icw2tu00.CrdtNodeTable? _node;

  /// Monotone causal-length flag. Odd values are visible and even values are deleted.
  late final _isd.ColumnInt clFlag;

  /// Why the row entered its current visibility generation.
  late final _isd.ColumnEnum<_icw2tu00.CrdtDataDeletedReason> reason;

  _icw2tu00.CrdtDataRowTable get row {
    if (_row != null) return _row!;
    _row = _isd.createRelationTable(
      relationFieldName: 'row',
      field: CrdtDataDeleted.t.rowId,
      foreignField: _icw2tu00.CrdtDataRow.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _icw2tu00.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _isd.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataDeleted.t.nodeId,
      foreignField: _icw2tu00.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    hlcDatetime,
    hlcCounter,
    rowId,
    nodeId,
    clFlag,
    reason,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'row') {
      return row;
    }
    if (relationField == 'node') {
      return node;
    }
    return null;
  }
}

class CrdtDataDeletedInclude extends _isd.IncludeObject {
  CrdtDataDeletedInclude._({
    _icw2tu00.CrdtDataRowInclude? row,
    _icw2tu00.CrdtNodeInclude? node,
  }) {
    _row = row;
    _node = node;
  }

  _icw2tu00.CrdtDataRowInclude? _row;

  _icw2tu00.CrdtNodeInclude? _node;

  @override
  Map<String, _isd.Include?> get includes => {
    'row': _row,
    'node': _node,
  };

  @override
  _isd.Table<int?> get table => CrdtDataDeleted.t;
}

class CrdtDataDeletedIncludeList extends _isd.IncludeList {
  CrdtDataDeletedIncludeList._({
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataDeleted.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtDataDeleted.t;
}

class CrdtDataDeletedRepository {
  const CrdtDataDeletedRepository._();

  final attachRow = const CrdtDataDeletedAttachRowRepository._();

  /// Returns a list of [CrdtDataDeleted]s matching the given query parameters.
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
  Future<List<CrdtDataDeleted>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtDataDeleted] matching the given query parameters.
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
  Future<CrdtDataDeleted?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataDeleted] by its [id] or null if no such row exists.
  Future<CrdtDataDeleted?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtDataDeleted>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtDataDeleted]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtDataDeleted]s will have their `id` fields set.
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
  Future<List<CrdtDataDeleted>> insert(
    _isd.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtDataDeleted>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtDataDeleted] and returns the inserted row.
  ///
  /// The returned [CrdtDataDeleted] will have its `id` field set.
  Future<CrdtDataDeleted> insertRow(
    _isd.DatabaseSession session,
    CrdtDataDeleted row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtDataDeleted>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtDataDeleted]s in the list and returns the resulting rows.
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
  /// The returned [CrdtDataDeleted]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataDeleted>> upsert(
    _isd.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    required _isd.ColumnSelections<CrdtDataDeletedTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataDeletedTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtDataDeleted>(
      rows,
      conflictColumns: conflictColumns(CrdtDataDeleted.t),
      updateColumns: updateColumns?.call(CrdtDataDeleted.t),
      updateWhere: updateWhere?.call(CrdtDataDeleted.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtDataDeleted] and returns the resulting row.
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
  /// The returned [CrdtDataDeleted] will have its `id` field set.
  Future<CrdtDataDeleted?> upsertRow(
    _isd.DatabaseSession session,
    CrdtDataDeleted row, {
    required _isd.ColumnSelections<CrdtDataDeletedTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataDeletedTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtDataDeleted>(
      row,
      conflictColumns: conflictColumns(CrdtDataDeleted.t),
      updateColumns: updateColumns?.call(CrdtDataDeleted.t),
      updateWhere: updateWhere?.call(CrdtDataDeleted.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataDeleted]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataDeleted>> update(
    _isd.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _isd.ColumnSelections<CrdtDataDeletedTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtDataDeleted>(
      rows,
      columns: columns?.call(CrdtDataDeleted.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtDataDeleted]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtDataDeleted> updateRow(
    _isd.DatabaseSession session,
    CrdtDataDeleted row, {
    _isd.ColumnSelections<CrdtDataDeletedTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtDataDeleted>(
      row,
      columns: columns?.call(CrdtDataDeleted.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtDataDeleted] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtDataDeleted?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtDataDeletedUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtDataDeleted>(
      id,
      columnValues: columnValues(CrdtDataDeleted.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataDeleted]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataDeleted>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtDataDeletedUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataDeleted>(
      columnValues: columnValues(CrdtDataDeleted.t.updateTable),
      where: where(CrdtDataDeleted.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtDataDeleted]s in the list and returns the deleted rows.
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
  Future<List<CrdtDataDeleted>> delete(
    _isd.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataDeleted>(
      rows,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataDeleted].
  Future<CrdtDataDeleted> deleteRow(
    _isd.DatabaseSession session,
    CrdtDataDeleted row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtDataDeleted>(
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
  Future<List<CrdtDataDeleted>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    _isd.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataDeleted>(
      where: where(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataDeleted] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtDataDeleted>(
      where: where(CrdtDataDeleted.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtDataDeletedAttachRowRepository {
  const CrdtDataDeletedAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataDeleted] and [CrdtDataRow]
  /// by setting the [CrdtDataDeleted]'s foreign key `rowId` to refer to the [CrdtDataRow].
  Future<void> row(
    _isd.DatabaseSession session,
    CrdtDataDeleted crdtDataDeleted,
    _icw2tu00.CrdtDataRow row, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtDataDeleted.id == null) {
      throw ArgumentError.notNull('crdtDataDeleted.id');
    }
    if (row.id == null) {
      throw ArgumentError.notNull('row.id');
    }

    var $crdtDataDeleted = crdtDataDeleted.copyWith(rowId: row.id);
    await session.db.updateRow<CrdtDataDeleted>(
      $crdtDataDeleted,
      columns: [CrdtDataDeleted.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataDeleted] and [CrdtNode]
  /// by setting the [CrdtDataDeleted]'s foreign key `nodeId` to refer to the [CrdtNode].
  Future<void> node(
    _isd.DatabaseSession session,
    CrdtDataDeleted crdtDataDeleted,
    _icw2tu00.CrdtNode node, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtDataDeleted.id == null) {
      throw ArgumentError.notNull('crdtDataDeleted.id');
    }
    if (node.id == null) {
      throw ArgumentError.notNull('node.id');
    }

    var $crdtDataDeleted = crdtDataDeleted.copyWith(nodeId: node.id);
    await session.db.updateRow<CrdtDataDeleted>(
      $crdtDataDeleted,
      columns: [CrdtDataDeleted.t.nodeId],
      transaction: transaction,
    );
  }
}
