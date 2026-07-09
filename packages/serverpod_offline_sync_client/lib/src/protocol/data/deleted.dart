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
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart'
    as _i1;
import 'package:serverpod_database/serverpod_database.dart' as _i2;
import '../data/row.dart' as _i3;
import '../node/node.dart' as _i4;
import '../data/deleted_reason.dart' as _i5;
import 'package:serverpod_client/serverpod_client.dart' as _i6;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i7;

/// CRDT visibility generation table.
///
/// This table stores materialized monotone CLFlag metadata after a visibility
/// change event has been recorded.
abstract class CrdtDataDeleted extends _i1.BaseHlc
    implements _i2.TableRow<int?> {
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
    _i3.CrdtDataRow? row,
    required int rowId,
    required int nodeId,
    _i4.CrdtNode? node,
    required int clFlag,
    required _i5.CrdtDataDeletedReason reason,
  }) = _CrdtDataDeletedImpl;

  factory CrdtDataDeleted.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataDeleted(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _i6.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      row: jsonSerialization['row'] == null
          ? null
          : _i7.Protocol().deserialize<_i3.CrdtDataRow>(
              jsonSerialization['row'],
            ),
      rowId: jsonSerialization['rowId'] as int,
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _i7.Protocol().deserialize<_i4.CrdtNode>(jsonSerialization['node']),
      clFlag: jsonSerialization['clFlag'] as int,
      reason: _i5.CrdtDataDeletedReason.fromJson(
        (jsonSerialization['reason'] as int),
      ),
    );
  }

  static final t = CrdtDataDeletedTable();

  static const db = CrdtDataDeletedRepository._();

  @override
  int? id;

  /// Row whose visibility is tracked.
  _i3.CrdtDataRow? row;

  int rowId;

  int nodeId;

  /// The node that updated the field.
  _i4.CrdtNode? node;

  /// Monotone causal-length flag. Odd values are visible and even values are deleted.
  int clFlag;

  /// Why the row entered its current visibility generation.
  _i5.CrdtDataDeletedReason reason;

  @override
  _i2.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataDeleted]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i6.useResult
  CrdtDataDeleted copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    _i3.CrdtDataRow? row,
    int? rowId,
    int? nodeId,
    _i4.CrdtNode? node,
    int? clFlag,
    _i5.CrdtDataDeletedReason? reason,
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

  static CrdtDataDeletedInclude include({
    _i3.CrdtDataRowInclude? row,
    _i4.CrdtNodeInclude? node,
  }) {
    return CrdtDataDeletedInclude._(
      row: row,
      node: node,
    );
  }

  static CrdtDataDeletedIncludeList includeList({
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    CrdtDataDeletedInclude? include,
  }) {
    return CrdtDataDeletedIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i6.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataDeletedImpl extends CrdtDataDeleted {
  _CrdtDataDeletedImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    _i3.CrdtDataRow? row,
    required int rowId,
    required int nodeId,
    _i4.CrdtNode? node,
    required int clFlag,
    required _i5.CrdtDataDeletedReason reason,
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
  @_i6.useResult
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
    _i5.CrdtDataDeletedReason? reason,
  }) {
    return CrdtDataDeleted(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      row: row is _i3.CrdtDataRow? ? row : this.row?.copyWith(),
      rowId: rowId ?? this.rowId,
      nodeId: nodeId ?? this.nodeId,
      node: node is _i4.CrdtNode? ? node : this.node?.copyWith(),
      clFlag: clFlag ?? this.clFlag,
      reason: reason ?? this.reason,
    );
  }
}

class CrdtDataDeletedUpdateTable extends _i2.UpdateTable<CrdtDataDeletedTable> {
  CrdtDataDeletedUpdateTable(super.table);

  _i2.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _i2.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _i2.ColumnValue<int, int> hlcCounter(int value) => _i2.ColumnValue(
    table.hlcCounter,
    value,
  );

  _i2.ColumnValue<int, int> rowId(int value) => _i2.ColumnValue(
    table.rowId,
    value,
  );

  _i2.ColumnValue<int, int> nodeId(int value) => _i2.ColumnValue(
    table.nodeId,
    value,
  );

  _i2.ColumnValue<int, int> clFlag(int value) => _i2.ColumnValue(
    table.clFlag,
    value,
  );

  _i2.ColumnValue<_i5.CrdtDataDeletedReason, _i5.CrdtDataDeletedReason> reason(
    _i5.CrdtDataDeletedReason value,
  ) => _i2.ColumnValue(
    table.reason,
    value,
  );
}

class CrdtDataDeletedTable extends _i2.Table<int?> {
  CrdtDataDeletedTable({super.tableRelation})
    : super(tableName: 'crdt_data_tombstone') {
    updateTable = CrdtDataDeletedUpdateTable(this);
    hlcDatetime = _i2.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _i2.ColumnInt(
      'hlcCounter',
      this,
    );
    rowId = _i2.ColumnInt(
      'rowId',
      this,
    );
    nodeId = _i2.ColumnInt(
      'nodeId',
      this,
    );
    clFlag = _i2.ColumnInt(
      'clFlag',
      this,
    );
    reason = _i2.ColumnEnum(
      'reason',
      this,
      _i2.EnumSerialization.byIndex,
    );
  }

  late final CrdtDataDeletedUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _i2.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _i2.ColumnInt hlcCounter;

  /// Row whose visibility is tracked.
  _i3.CrdtDataRowTable? _row;

  late final _i2.ColumnInt rowId;

  late final _i2.ColumnInt nodeId;

  /// The node that updated the field.
  _i4.CrdtNodeTable? _node;

  /// Monotone causal-length flag. Odd values are visible and even values are deleted.
  late final _i2.ColumnInt clFlag;

  /// Why the row entered its current visibility generation.
  late final _i2.ColumnEnum<_i5.CrdtDataDeletedReason> reason;

  _i3.CrdtDataRowTable get row {
    if (_row != null) return _row!;
    _row = _i2.createRelationTable(
      relationFieldName: 'row',
      field: CrdtDataDeleted.t.rowId,
      foreignField: _i3.CrdtDataRow.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _i4.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _i2.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataDeleted.t.nodeId,
      foreignField: _i4.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i4.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  @override
  List<_i2.Column> get columns => [
    id,
    hlcDatetime,
    hlcCounter,
    rowId,
    nodeId,
    clFlag,
    reason,
  ];

  @override
  _i2.Table? getRelationTable(String relationField) {
    if (relationField == 'row') {
      return row;
    }
    if (relationField == 'node') {
      return node;
    }
    return null;
  }
}

class CrdtDataDeletedInclude extends _i2.IncludeObject {
  CrdtDataDeletedInclude._({
    _i3.CrdtDataRowInclude? row,
    _i4.CrdtNodeInclude? node,
  }) {
    _row = row;
    _node = node;
  }

  _i3.CrdtDataRowInclude? _row;

  _i4.CrdtNodeInclude? _node;

  @override
  Map<String, _i2.Include?> get includes => {
    'row': _row,
    'node': _node,
  };

  @override
  _i2.Table<int?> get table => CrdtDataDeleted.t;
}

class CrdtDataDeletedIncludeList extends _i2.IncludeList {
  CrdtDataDeletedIncludeList._({
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataDeleted.t);
  }

  @override
  Map<String, _i2.Include?> get includes => include?.includes ?? {};

  @override
  _i2.Table<int?> get table => CrdtDataDeleted.t;
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
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? offset,
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataDeleted] by its [id] or null if no such row exists.
  Future<CrdtDataDeleted?> findById(
    _i2.DatabaseSession session,
    int id, {
    _i2.Transaction? transaction,
    CrdtDataDeletedInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
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
    _i2.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    CrdtDataDeleted row, {
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    required _i2.ColumnSelections<CrdtDataDeletedTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataDeletedTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? updateWhere,
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    CrdtDataDeleted row, {
    required _i2.ColumnSelections<CrdtDataDeletedTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataDeletedTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? updateWhere,
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _i2.ColumnSelections<CrdtDataDeletedTable>? columns,
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    CrdtDataDeleted row, {
    _i2.ColumnSelections<CrdtDataDeletedTable>? columns,
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    int id, {
    required _i2.ColumnValueListBuilder<CrdtDataDeletedUpdateTable>
    columnValues,
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session, {
    required _i2.ColumnValueListBuilder<CrdtDataDeletedUpdateTable>
    columnValues,
    required _i2.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataDeleted>(
      columnValues: columnValues(CrdtDataDeleted.t.updateTable),
      where: where(CrdtDataDeleted.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i2.DatabaseSession session,
    List<CrdtDataDeleted> rows, {
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataDeleted>(
      rows,
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataDeleted].
  Future<CrdtDataDeleted> deleteRow(
    _i2.DatabaseSession session,
    CrdtDataDeleted row, {
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    _i2.OrderByBuilder<CrdtDataDeletedTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i2.OrderByListBuilder<CrdtDataDeletedTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataDeleted>(
      where: where(CrdtDataDeleted.t),
      orderBy: orderBy?.call(CrdtDataDeleted.t),
      orderByList: orderByList?.call(CrdtDataDeleted.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataDeletedTable>? where,
    int? limit,
    _i2.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataDeleted>(
      where: where?.call(CrdtDataDeleted.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataDeleted] rows matching the [where] expression.
  Future<void> lockRows(
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataDeletedTable> where,
    required _i2.LockMode lockMode,
    required _i2.Transaction transaction,
    _i2.LockBehavior lockBehavior = _i2.LockBehavior.wait,
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
    _i2.DatabaseSession session,
    CrdtDataDeleted crdtDataDeleted,
    _i3.CrdtDataRow row, {
    _i2.Transaction? transaction,
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
    _i2.DatabaseSession session,
    CrdtDataDeleted crdtDataDeleted,
    _i4.CrdtNode node, {
    _i2.Transaction? transaction,
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
