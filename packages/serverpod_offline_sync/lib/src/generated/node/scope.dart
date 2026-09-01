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

/// CRDT scopes table.
///
/// Normalized storage for scope IDs. The normalized data table references this
/// by integer id instead of storing the scope id string.
abstract class CrdtScope
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  CrdtScope._({
    this.id,
    _iss.UuidValue? uuidScopeId,
    this.currentNodeId,
    this.currentNode,
    this.nodes,
  }) : uuidScopeId = uuidScopeId ?? const _iss.Uuid().v7obj();

  factory CrdtScope({
    int? id,
    _iss.UuidValue? uuidScopeId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.CrdtScopeNode>? nodes,
  }) = _CrdtScopeImpl;

  factory CrdtScope.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtScope(
      id: jsonSerialization['id'] as int?,
      uuidScopeId: jsonSerialization['uuidScopeId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['uuidScopeId'],
            ),
      currentNodeId: jsonSerialization['currentNodeId'] as int?,
      currentNode: jsonSerialization['currentNode'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['currentNode'],
            ),
      nodes: jsonSerialization['nodes'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<List<_icw2tu00.CrdtScopeNode>>(
              jsonSerialization['nodes'],
            ),
    );
  }

  static final t = CrdtScopeTable();

  static const db = CrdtScopeRepository._();

  @override
  int? id;

  /// Scope identifier string.
  _iss.UuidValue uuidScopeId;

  int? currentNodeId;

  /// The current node id of the scope.
  _icw2tu00.CrdtNode? currentNode;

  /// The nodes associated with the scope and their per-scope checkpoints.
  List<_icw2tu00.CrdtScopeNode>? nodes;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtScope]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtScope copyWith({
    int? id,
    _iss.UuidValue? uuidScopeId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.CrdtScopeNode>? nodes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScope',
      if (id != null) 'id': id,
      'uuidScopeId': uuidScopeId.toJson(),
      if (currentNodeId != null) 'currentNodeId': currentNodeId,
      if (currentNode != null) 'currentNode': currentNode?.toJson(),
      if (nodes != null) 'nodes': nodes?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScope',
      if (id != null) 'id': id,
      'uuidScopeId': uuidScopeId.toJson(),
      if (currentNodeId != null) 'currentNodeId': currentNodeId,
      if (currentNode != null) 'currentNode': currentNode?.toJsonForProtocol(),
      if (nodes != null)
        'nodes': nodes?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  static CrdtScopeInclude include({
    _icw2tu00.CrdtNodeInclude? currentNode,
    _icw2tu00.CrdtScopeNodeIncludeList? nodes,
  }) {
    return CrdtScopeInclude._(
      currentNode: currentNode,
      nodes: nodes,
    );
  }

  static CrdtScopeIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    CrdtScopeInclude? include,
  }) {
    return CrdtScopeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtScopeImpl extends CrdtScope {
  _CrdtScopeImpl({
    int? id,
    _iss.UuidValue? uuidScopeId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.CrdtScopeNode>? nodes,
  }) : super._(
         id: id,
         uuidScopeId: uuidScopeId,
         currentNodeId: currentNodeId,
         currentNode: currentNode,
         nodes: nodes,
       );

  /// Returns a shallow copy of this [CrdtScope]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtScope copyWith({
    Object? id = _Undefined,
    _iss.UuidValue? uuidScopeId,
    Object? currentNodeId = _Undefined,
    Object? currentNode = _Undefined,
    Object? nodes = _Undefined,
  }) {
    return CrdtScope(
      id: id is int? ? id : this.id,
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      currentNodeId: currentNodeId is int? ? currentNodeId : this.currentNodeId,
      currentNode: currentNode is _icw2tu00.CrdtNode?
          ? currentNode
          : this.currentNode?.copyWith(),
      nodes: nodes is List<_icw2tu00.CrdtScopeNode>?
          ? nodes
          : this.nodes?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class CrdtScopeUpdateTable extends _isd.UpdateTable<CrdtScopeTable> {
  CrdtScopeUpdateTable(super.table);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> uuidScopeId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.uuidScopeId,
    value,
  );

  _isd.ColumnValue<int, int> currentNodeId(int? value) => _isd.ColumnValue(
    table.currentNodeId,
    value,
  );
}

class CrdtScopeTable extends _isd.Table<int?> {
  CrdtScopeTable({super.tableRelation}) : super(tableName: 'crdt_scopes') {
    updateTable = CrdtScopeUpdateTable(this);
    uuidScopeId = _isd.ColumnUuid(
      'uuidScopeId',
      this,
      hasDefault: true,
    );
    currentNodeId = _isd.ColumnInt(
      'currentNodeId',
      this,
    );
  }

  late final CrdtScopeUpdateTable updateTable;

  /// Scope identifier string.
  late final _isd.ColumnUuid uuidScopeId;

  late final _isd.ColumnInt currentNodeId;

  /// The current node id of the scope.
  _icw2tu00.CrdtNodeTable? _currentNode;

  /// The nodes associated with the scope and their per-scope checkpoints.
  _icw2tu00.CrdtScopeNodeTable? ___nodes;

  /// The nodes associated with the scope and their per-scope checkpoints.
  _isd.ManyRelation<_icw2tu00.CrdtScopeNodeTable>? _nodes;

  _icw2tu00.CrdtNodeTable get currentNode {
    if (_currentNode != null) return _currentNode!;
    _currentNode = _isd.createRelationTable(
      relationFieldName: 'currentNode',
      field: CrdtScope.t.currentNodeId,
      foreignField: _icw2tu00.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _currentNode!;
  }

  _icw2tu00.CrdtScopeNodeTable get __nodes {
    if (___nodes != null) return ___nodes!;
    ___nodes = _isd.createRelationTable(
      relationFieldName: '__nodes',
      field: CrdtScope.t.id,
      foreignField: _icw2tu00.CrdtScopeNode.t.scopeId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtScopeNodeTable(tableRelation: foreignTableRelation),
    );
    return ___nodes!;
  }

  _isd.ManyRelation<_icw2tu00.CrdtScopeNodeTable> get nodes {
    if (_nodes != null) return _nodes!;
    var relationTable = _isd.createRelationTable(
      relationFieldName: 'nodes',
      field: CrdtScope.t.id,
      foreignField: _icw2tu00.CrdtScopeNode.t.scopeId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtScopeNodeTable(tableRelation: foreignTableRelation),
    );
    _nodes = _isd.ManyRelation<_icw2tu00.CrdtScopeNodeTable>(
      tableWithRelations: relationTable,
      table: _icw2tu00.CrdtScopeNodeTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _nodes!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    uuidScopeId,
    currentNodeId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'currentNode') {
      return currentNode;
    }
    if (relationField == 'nodes') {
      return __nodes;
    }
    return null;
  }
}

class CrdtScopeInclude extends _isd.IncludeObject {
  CrdtScopeInclude._({
    _icw2tu00.CrdtNodeInclude? currentNode,
    _icw2tu00.CrdtScopeNodeIncludeList? nodes,
  }) {
    _currentNode = currentNode;
    _nodes = nodes;
  }

  _icw2tu00.CrdtNodeInclude? _currentNode;

  _icw2tu00.CrdtScopeNodeIncludeList? _nodes;

  @override
  Map<String, _isd.Include?> get includes => {
    'currentNode': _currentNode,
    'nodes': _nodes,
  };

  @override
  _isd.Table<int?> get table => CrdtScope.t;
}

class CrdtScopeIncludeList extends _isd.IncludeList {
  CrdtScopeIncludeList._({
    _isd.WhereExpressionBuilder<CrdtScopeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtScope.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtScope.t;
}

class CrdtScopeRepository {
  const CrdtScopeRepository._();

  final attach = const CrdtScopeAttachRepository._();

  final attachRow = const CrdtScopeAttachRowRepository._();

  final detachRow = const CrdtScopeDetachRowRepository._();

  /// Returns a list of [CrdtScope]s matching the given query parameters.
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
  Future<List<CrdtScope>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtScopeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtScope>(
      where: where?.call(CrdtScope.t),
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtScope] matching the given query parameters.
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
  Future<CrdtScope?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtScopeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtScope>(
      where: where?.call(CrdtScope.t),
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtScope] by its [id] or null if no such row exists.
  Future<CrdtScope?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtScopeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtScope>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtScope]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtScope]s will have their `id` fields set.
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
  Future<List<CrdtScope>> insert(
    _isd.DatabaseSession session,
    List<CrdtScope> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtScope>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtScope] and returns the inserted row.
  ///
  /// The returned [CrdtScope] will have its `id` field set.
  Future<CrdtScope> insertRow(
    _isd.DatabaseSession session,
    CrdtScope row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtScope>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtScope]s in the list and returns the resulting rows.
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
  /// The returned [CrdtScope]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScope>> upsert(
    _isd.DatabaseSession session,
    List<CrdtScope> rows, {
    required _isd.ColumnSelections<CrdtScopeTable> conflictColumns,
    _isd.ColumnSelections<CrdtScopeTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtScopeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtScope>(
      rows,
      conflictColumns: conflictColumns(CrdtScope.t),
      updateColumns: updateColumns?.call(CrdtScope.t),
      updateWhere: updateWhere?.call(CrdtScope.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtScope] and returns the resulting row.
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
  /// The returned [CrdtScope] will have its `id` field set.
  Future<CrdtScope?> upsertRow(
    _isd.DatabaseSession session,
    CrdtScope row, {
    required _isd.ColumnSelections<CrdtScopeTable> conflictColumns,
    _isd.ColumnSelections<CrdtScopeTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtScopeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtScope>(
      row,
      conflictColumns: conflictColumns(CrdtScope.t),
      updateColumns: updateColumns?.call(CrdtScope.t),
      updateWhere: updateWhere?.call(CrdtScope.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScope]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScope>> update(
    _isd.DatabaseSession session,
    List<CrdtScope> rows, {
    _isd.ColumnSelections<CrdtScopeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtScope>(
      rows,
      columns: columns?.call(CrdtScope.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtScope]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtScope> updateRow(
    _isd.DatabaseSession session,
    CrdtScope row, {
    _isd.ColumnSelections<CrdtScopeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtScope>(
      row,
      columns: columns?.call(CrdtScope.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtScope] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtScope?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtScopeUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtScope>(
      id,
      columnValues: columnValues(CrdtScope.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScope]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScope>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtScopeUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CrdtScopeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtScope>(
      columnValues: columnValues(CrdtScope.t.updateTable),
      where: where(CrdtScope.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtScope]s in the list and returns the deleted rows.
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
  Future<List<CrdtScope>> delete(
    _isd.DatabaseSession session,
    List<CrdtScope> rows, {
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtScope>(
      rows,
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtScope].
  Future<CrdtScope> deleteRow(
    _isd.DatabaseSession session,
    CrdtScope row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtScope>(
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
  Future<List<CrdtScope>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtScopeTable> where,
    _isd.OrderByBuilder<CrdtScopeTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtScope>(
      where: where(CrdtScope.t),
      orderBy: orderBy?.call(CrdtScope.t),
      orderByList: orderByList?.call(CrdtScope.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtScope>(
      where: where?.call(CrdtScope.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtScope] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtScopeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtScope>(
      where: where(CrdtScope.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtScopeAttachRepository {
  const CrdtScopeAttachRepository._();

  /// Creates a relation between this [CrdtScope] and the given [CrdtScopeNode]s
  /// by setting each [CrdtScopeNode]'s foreign key `scopeId` to refer to this [CrdtScope].
  Future<void> nodes(
    _isd.DatabaseSession session,
    CrdtScope crdtScope,
    List<_icw2tu00.CrdtScopeNode> crdtScopeNode, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtScopeNode.any((e) => e.id == null)) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }
    if (crdtScope.id == null) {
      throw ArgumentError.notNull('crdtScope.id');
    }

    var $crdtScopeNode = crdtScopeNode
        .map((e) => e.copyWith(scopeId: crdtScope.id))
        .toList();
    await session.db.update<_icw2tu00.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_icw2tu00.CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }
}

class CrdtScopeAttachRowRepository {
  const CrdtScopeAttachRowRepository._();

  /// Creates a relation between the given [CrdtScope] and [CrdtNode]
  /// by setting the [CrdtScope]'s foreign key `currentNodeId` to refer to the [CrdtNode].
  Future<void> currentNode(
    _isd.DatabaseSession session,
    CrdtScope crdtScope,
    _icw2tu00.CrdtNode currentNode, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtScope.id == null) {
      throw ArgumentError.notNull('crdtScope.id');
    }
    if (currentNode.id == null) {
      throw ArgumentError.notNull('currentNode.id');
    }

    var $crdtScope = crdtScope.copyWith(currentNodeId: currentNode.id);
    await session.db.updateRow<CrdtScope>(
      $crdtScope,
      columns: [CrdtScope.t.currentNodeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between this [CrdtScope] and the given [CrdtScopeNode]
  /// by setting the [CrdtScopeNode]'s foreign key `scopeId` to refer to this [CrdtScope].
  Future<void> nodes(
    _isd.DatabaseSession session,
    CrdtScope crdtScope,
    _icw2tu00.CrdtScopeNode crdtScopeNode, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtScopeNode.id == null) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }
    if (crdtScope.id == null) {
      throw ArgumentError.notNull('crdtScope.id');
    }

    var $crdtScopeNode = crdtScopeNode.copyWith(scopeId: crdtScope.id);
    await session.db.updateRow<_icw2tu00.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_icw2tu00.CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }
}

class CrdtScopeDetachRowRepository {
  const CrdtScopeDetachRowRepository._();

  /// Detaches the relation between this [CrdtScope] and the [CrdtNode] set in `currentNode`
  /// by setting the [CrdtScope]'s foreign key `currentNodeId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> currentNode(
    _isd.DatabaseSession session,
    CrdtScope crdtScope, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtScope.id == null) {
      throw ArgumentError.notNull('crdtScope.id');
    }

    var $crdtScope = crdtScope.copyWith(currentNodeId: null);
    await session.db.updateRow<CrdtScope>(
      $crdtScope,
      columns: [CrdtScope.t.currentNodeId],
      transaction: transaction,
    );
  }
}
