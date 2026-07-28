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
import 'package:serverpod_database/serverpod_database.dart' as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import '../node/node.dart' as _i3;
import '../node/scope_node.dart' as _i4;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i5;

/// CRDT scopes table.
///
/// Normalized storage for scope IDs. The normalized data table references this
/// by integer id instead of storing the scope id string.
abstract class CrdtScope
    implements _i1.TableRow<int?>, _i2.ProtocolSerialization {
  CrdtScope._({
    this.id,
    _i2.UuidValue? uuidScopeId,
    this.currentNodeId,
    this.currentNode,
    this.nodes,
  }) : uuidScopeId = uuidScopeId ?? const _i2.Uuid().v7obj();

  factory CrdtScope({
    int? id,
    _i2.UuidValue? uuidScopeId,
    int? currentNodeId,
    _i3.CrdtNode? currentNode,
    List<_i4.CrdtScopeNode>? nodes,
  }) = _CrdtScopeImpl;

  factory CrdtScope.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtScope(
      id: jsonSerialization['id'] as int?,
      uuidScopeId: jsonSerialization['uuidScopeId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['uuidScopeId'],
            ),
      currentNodeId: jsonSerialization['currentNodeId'] as int?,
      currentNode: jsonSerialization['currentNode'] == null
          ? null
          : _i5.Protocol().deserialize<_i3.CrdtNode>(
              jsonSerialization['currentNode'],
            ),
      nodes: jsonSerialization['nodes'] == null
          ? null
          : _i5.Protocol().deserialize<List<_i4.CrdtScopeNode>>(
              jsonSerialization['nodes'],
            ),
    );
  }

  static final t = CrdtScopeTable();

  static const db = CrdtScopeRepository._();

  @override
  int? id;

  /// Scope identifier string.
  _i2.UuidValue uuidScopeId;

  int? currentNodeId;

  /// The current node id of the scope.
  _i3.CrdtNode? currentNode;

  /// The nodes associated with the scope and their per-scope checkpoints.
  List<_i4.CrdtScopeNode>? nodes;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtScope]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  CrdtScope copyWith({
    int? id,
    _i2.UuidValue? uuidScopeId,
    int? currentNodeId,
    _i3.CrdtNode? currentNode,
    List<_i4.CrdtScopeNode>? nodes,
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
    _i3.CrdtNodeInclude? currentNode,
    _i4.CrdtScopeNodeIncludeList? nodes,
  }) {
    return CrdtScopeInclude._(
      currentNode: currentNode,
      nodes: nodes,
    );
  }

  static CrdtScopeIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
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
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtScopeImpl extends CrdtScope {
  _CrdtScopeImpl({
    int? id,
    _i2.UuidValue? uuidScopeId,
    int? currentNodeId,
    _i3.CrdtNode? currentNode,
    List<_i4.CrdtScopeNode>? nodes,
  }) : super._(
         id: id,
         uuidScopeId: uuidScopeId,
         currentNodeId: currentNodeId,
         currentNode: currentNode,
         nodes: nodes,
       );

  /// Returns a shallow copy of this [CrdtScope]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtScope copyWith({
    Object? id = _Undefined,
    _i2.UuidValue? uuidScopeId,
    Object? currentNodeId = _Undefined,
    Object? currentNode = _Undefined,
    Object? nodes = _Undefined,
  }) {
    return CrdtScope(
      id: id is int? ? id : this.id,
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      currentNodeId: currentNodeId is int? ? currentNodeId : this.currentNodeId,
      currentNode: currentNode is _i3.CrdtNode?
          ? currentNode
          : this.currentNode?.copyWith(),
      nodes: nodes is List<_i4.CrdtScopeNode>?
          ? nodes
          : this.nodes?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class CrdtScopeUpdateTable extends _i1.UpdateTable<CrdtScopeTable> {
  CrdtScopeUpdateTable(super.table);

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> uuidScopeId(
    _i2.UuidValue value,
  ) => _i1.ColumnValue(
    table.uuidScopeId,
    value,
  );

  _i1.ColumnValue<int, int> currentNodeId(int? value) => _i1.ColumnValue(
    table.currentNodeId,
    value,
  );
}

class CrdtScopeTable extends _i1.Table<int?> {
  CrdtScopeTable({super.tableRelation}) : super(tableName: 'crdt_scopes') {
    updateTable = CrdtScopeUpdateTable(this);
    uuidScopeId = _i1.ColumnUuid(
      'uuidScopeId',
      this,
      hasDefault: true,
    );
    currentNodeId = _i1.ColumnInt(
      'currentNodeId',
      this,
    );
  }

  late final CrdtScopeUpdateTable updateTable;

  /// Scope identifier string.
  late final _i1.ColumnUuid uuidScopeId;

  late final _i1.ColumnInt currentNodeId;

  /// The current node id of the scope.
  _i3.CrdtNodeTable? _currentNode;

  /// The nodes associated with the scope and their per-scope checkpoints.
  _i4.CrdtScopeNodeTable? ___nodes;

  /// The nodes associated with the scope and their per-scope checkpoints.
  _i1.ManyRelation<_i4.CrdtScopeNodeTable>? _nodes;

  _i3.CrdtNodeTable get currentNode {
    if (_currentNode != null) return _currentNode!;
    _currentNode = _i1.createRelationTable(
      relationFieldName: 'currentNode',
      field: CrdtScope.t.currentNodeId,
      foreignField: _i3.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _currentNode!;
  }

  _i4.CrdtScopeNodeTable get __nodes {
    if (___nodes != null) return ___nodes!;
    ___nodes = _i1.createRelationTable(
      relationFieldName: '__nodes',
      field: CrdtScope.t.id,
      foreignField: _i4.CrdtScopeNode.t.scopeId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i4.CrdtScopeNodeTable(tableRelation: foreignTableRelation),
    );
    return ___nodes!;
  }

  _i1.ManyRelation<_i4.CrdtScopeNodeTable> get nodes {
    if (_nodes != null) return _nodes!;
    var relationTable = _i1.createRelationTable(
      relationFieldName: 'nodes',
      field: CrdtScope.t.id,
      foreignField: _i4.CrdtScopeNode.t.scopeId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i4.CrdtScopeNodeTable(tableRelation: foreignTableRelation),
    );
    _nodes = _i1.ManyRelation<_i4.CrdtScopeNodeTable>(
      tableWithRelations: relationTable,
      table: _i4.CrdtScopeNodeTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _nodes!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    uuidScopeId,
    currentNodeId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'currentNode') {
      return currentNode;
    }
    if (relationField == 'nodes') {
      return __nodes;
    }
    return null;
  }
}

class CrdtScopeInclude extends _i1.IncludeObject {
  CrdtScopeInclude._({
    _i3.CrdtNodeInclude? currentNode,
    _i4.CrdtScopeNodeIncludeList? nodes,
  }) {
    _currentNode = currentNode;
    _nodes = nodes;
  }

  _i3.CrdtNodeInclude? _currentNode;

  _i4.CrdtScopeNodeIncludeList? _nodes;

  @override
  Map<String, _i1.Include?> get includes => {
    'currentNode': _currentNode,
    'nodes': _nodes,
  };

  @override
  _i1.Table<int?> get table => CrdtScope.t;
}

class CrdtScopeIncludeList extends _i1.IncludeList {
  CrdtScopeIncludeList._({
    _i1.WhereExpressionBuilder<CrdtScopeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtScope.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtScope.t;
}

class CrdtScopeRepository {
  const CrdtScopeRepository._();

  final attach = const CrdtScopeAttachRepository._();

  final attachRow = const CrdtScopeAttachRowRepository._();

  final detach = const CrdtScopeDetachRepository._();

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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtScopeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtScopeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    CrdtScopeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    List<CrdtScope> rows, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtScope row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<CrdtScope> rows, {
    required _i1.ColumnSelections<CrdtScopeTable> conflictColumns,
    _i1.ColumnSelections<CrdtScopeTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtScopeTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtScope row, {
    required _i1.ColumnSelections<CrdtScopeTable> conflictColumns,
    _i1.ColumnSelections<CrdtScopeTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtScopeTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<CrdtScope> rows, {
    _i1.ColumnSelections<CrdtScopeTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtScope row, {
    _i1.ColumnSelections<CrdtScopeTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtScopeUpdateTable> columnValues,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtScopeUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<CrdtScopeTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<CrdtScope> rows, {
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtScope row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtScopeTable> where,
    _i1.OrderByBuilder<CrdtScopeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtScope>(
      where: where?.call(CrdtScope.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtScope] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtScopeTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
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
    _i1.DatabaseSession session,
    CrdtScope crdtScope,
    List<_i4.CrdtScopeNode> crdtScopeNode, {
    _i1.Transaction? transaction,
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
    await session.db.update<_i4.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_i4.CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }
}

class CrdtScopeAttachRowRepository {
  const CrdtScopeAttachRowRepository._();

  /// Creates a relation between the given [CrdtScope] and [CrdtNode]
  /// by setting the [CrdtScope]'s foreign key `currentNodeId` to refer to the [CrdtNode].
  Future<void> currentNode(
    _i1.DatabaseSession session,
    CrdtScope crdtScope,
    _i3.CrdtNode currentNode, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtScope crdtScope,
    _i4.CrdtScopeNode crdtScopeNode, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtScopeNode.id == null) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }
    if (crdtScope.id == null) {
      throw ArgumentError.notNull('crdtScope.id');
    }

    var $crdtScopeNode = crdtScopeNode.copyWith(scopeId: crdtScope.id);
    await session.db.updateRow<_i4.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_i4.CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }
}

class CrdtScopeDetachRepository {
  const CrdtScopeDetachRepository._();

  /// Detaches the relation between this [CrdtScope] and the given [CrdtScopeNode]
  /// by setting the [CrdtScopeNode]'s foreign key `scopeId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> nodes(
    _i1.DatabaseSession session,
    List<_i4.CrdtScopeNode> crdtScopeNode, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtScopeNode.any((e) => e.id == null)) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }

    var $crdtScopeNode = crdtScopeNode
        .map((e) => e.copyWith(scopeId: null))
        .toList();
    await session.db.update<_i4.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_i4.CrdtScopeNode.t.scopeId],
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
    _i1.DatabaseSession session,
    CrdtScope crdtScope, {
    _i1.Transaction? transaction,
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

  /// Detaches the relation between this [CrdtScope] and the given [CrdtScopeNode]
  /// by setting the [CrdtScopeNode]'s foreign key `scopeId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> nodes(
    _i1.DatabaseSession session,
    _i4.CrdtScopeNode crdtScopeNode, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtScopeNode.id == null) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }

    var $crdtScopeNode = crdtScopeNode.copyWith(scopeId: null);
    await session.db.updateRow<_i4.CrdtScopeNode>(
      $crdtScopeNode,
      columns: [_i4.CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }
}
