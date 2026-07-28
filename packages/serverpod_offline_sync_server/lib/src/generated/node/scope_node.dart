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
import 'package:serverpod/serverpod.dart' as _i1;
import '../node/scope.dart' as _i2;
import '../node/node.dart' as _i3;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as _i4;
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart'
    as _i5;

/// A CRDT node's participation and checkpoint state within one scope.
abstract class CrdtScopeNode
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  CrdtScopeNode._({
    this.id,
    required this.scopeId,
    this.scope,
    required this.nodeId,
    this.node,
    this.lastReceivedHlc,
  });

  factory CrdtScopeNode({
    int? id,
    required int scopeId,
    _i2.CrdtScope? scope,
    required int nodeId,
    _i3.CrdtNode? node,
    _i4.Hlc? lastReceivedHlc,
  }) = _CrdtScopeNodeImpl;

  factory CrdtScopeNode.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtScopeNode(
      id: jsonSerialization['id'] as int?,
      scopeId: jsonSerialization['scopeId'] as int,
      scope: jsonSerialization['scope'] == null
          ? null
          : _i5.Protocol().deserialize<_i2.CrdtScope>(
              jsonSerialization['scope'],
            ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _i5.Protocol().deserialize<_i3.CrdtNode>(jsonSerialization['node']),
      lastReceivedHlc: jsonSerialization['lastReceivedHlc'] == null
          ? null
          : _i4.Hlc.fromJson(jsonSerialization['lastReceivedHlc']),
    );
  }

  static final t = CrdtScopeNodeTable();

  static const db = CrdtScopeNodeRepository._();

  @override
  int? id;

  int scopeId;

  /// Scope this participation row belongs to.
  _i2.CrdtScope? scope;

  int nodeId;

  /// Stable replica identity participating in the scope.
  _i3.CrdtNode? node;

  /// Latest HLC from this node acknowledged for this scope.
  _i4.Hlc? lastReceivedHlc;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtScopeNode]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CrdtScopeNode copyWith({
    int? id,
    int? scopeId,
    _i2.CrdtScope? scope,
    int? nodeId,
    _i3.CrdtNode? node,
    _i4.Hlc? lastReceivedHlc,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeNode',
      if (id != null) 'id': id,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJson(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJson(),
      if (lastReceivedHlc != null) 'lastReceivedHlc': lastReceivedHlc?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeNode',
      if (id != null) 'id': id,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJsonForProtocol(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJsonForProtocol(),
      if (lastReceivedHlc != null)
        'lastReceivedHlc':
            // ignore: unnecessary_type_check
            lastReceivedHlc is _i1.ProtocolSerialization
            ? (lastReceivedHlc as _i1.ProtocolSerialization).toJsonForProtocol()
            :
              // ignore: dead_code
              lastReceivedHlc?.toJson(),
    };
  }

  static CrdtScopeNodeInclude include({
    _i2.CrdtScopeInclude? scope,
    _i3.CrdtNodeInclude? node,
  }) {
    return CrdtScopeNodeInclude._(
      scope: scope,
      node: node,
    );
  }

  static CrdtScopeNodeIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    CrdtScopeNodeInclude? include,
  }) {
    return CrdtScopeNodeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtScopeNodeImpl extends CrdtScopeNode {
  _CrdtScopeNodeImpl({
    int? id,
    required int scopeId,
    _i2.CrdtScope? scope,
    required int nodeId,
    _i3.CrdtNode? node,
    _i4.Hlc? lastReceivedHlc,
  }) : super._(
         id: id,
         scopeId: scopeId,
         scope: scope,
         nodeId: nodeId,
         node: node,
         lastReceivedHlc: lastReceivedHlc,
       );

  /// Returns a shallow copy of this [CrdtScopeNode]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CrdtScopeNode copyWith({
    Object? id = _Undefined,
    int? scopeId,
    Object? scope = _Undefined,
    int? nodeId,
    Object? node = _Undefined,
    Object? lastReceivedHlc = _Undefined,
  }) {
    return CrdtScopeNode(
      id: id is int? ? id : this.id,
      scopeId: scopeId ?? this.scopeId,
      scope: scope is _i2.CrdtScope? ? scope : this.scope?.copyWith(),
      nodeId: nodeId ?? this.nodeId,
      node: node is _i3.CrdtNode? ? node : this.node?.copyWith(),
      lastReceivedHlc: lastReceivedHlc is _i4.Hlc?
          ? lastReceivedHlc
          : this.lastReceivedHlc?.copyWith(),
    );
  }
}

class CrdtScopeNodeUpdateTable extends _i1.UpdateTable<CrdtScopeNodeTable> {
  CrdtScopeNodeUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<int, int> nodeId(int value) => _i1.ColumnValue(
    table.nodeId,
    value,
  );

  _i1.ColumnValue<_i4.Hlc, _i4.Hlc> lastReceivedHlc(_i4.Hlc? value) =>
      _i1.ColumnValue(
        table.lastReceivedHlc,
        value,
      );
}

class CrdtScopeNodeTable extends _i1.Table<int?> {
  CrdtScopeNodeTable({super.tableRelation})
    : super(tableName: 'crdt_scope_nodes') {
    updateTable = CrdtScopeNodeUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    nodeId = _i1.ColumnInt(
      'nodeId',
      this,
    );
    lastReceivedHlc = _i1.ColumnStructured<_i4.Hlc>(
      'lastReceivedHlc',
      this,
    );
  }

  late final CrdtScopeNodeUpdateTable updateTable;

  late final _i1.ColumnInt scopeId;

  /// Scope this participation row belongs to.
  _i2.CrdtScopeTable? _scope;

  late final _i1.ColumnInt nodeId;

  /// Stable replica identity participating in the scope.
  _i3.CrdtNodeTable? _node;

  /// Latest HLC from this node acknowledged for this scope.
  late final _i1.ColumnStructured<_i4.Hlc> lastReceivedHlc;

  _i2.CrdtScopeTable get scope {
    if (_scope != null) return _scope!;
    _scope = _i1.createRelationTable(
      relationFieldName: 'scope',
      field: CrdtScopeNode.t.scopeId,
      foreignField: _i2.CrdtScope.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.CrdtScopeTable(tableRelation: foreignTableRelation),
    );
    return _scope!;
  }

  _i3.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _i1.createRelationTable(
      relationFieldName: 'node',
      field: CrdtScopeNode.t.nodeId,
      foreignField: _i3.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    nodeId,
    lastReceivedHlc,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'scope') {
      return scope;
    }
    if (relationField == 'node') {
      return node;
    }
    return null;
  }
}

class CrdtScopeNodeInclude extends _i1.IncludeObject {
  CrdtScopeNodeInclude._({
    _i2.CrdtScopeInclude? scope,
    _i3.CrdtNodeInclude? node,
  }) {
    _scope = scope;
    _node = node;
  }

  _i2.CrdtScopeInclude? _scope;

  _i3.CrdtNodeInclude? _node;

  @override
  Map<String, _i1.Include?> get includes => {
    'scope': _scope,
    'node': _node,
  };

  @override
  _i1.Table<int?> get table => CrdtScopeNode.t;
}

class CrdtScopeNodeIncludeList extends _i1.IncludeList {
  CrdtScopeNodeIncludeList._({
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtScopeNode.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtScopeNode.t;
}

class CrdtScopeNodeRepository {
  const CrdtScopeNodeRepository._();

  final attachRow = const CrdtScopeNodeAttachRowRepository._();

  /// Returns a list of [CrdtScopeNode]s matching the given query parameters.
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
  Future<List<CrdtScopeNode>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtScopeNodeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtScopeNode>(
      where: where?.call(CrdtScopeNode.t),
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtScopeNode] matching the given query parameters.
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
  Future<CrdtScopeNode?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtScopeNodeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtScopeNode>(
      where: where?.call(CrdtScopeNode.t),
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtScopeNode] by its [id] or null if no such row exists.
  Future<CrdtScopeNode?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    CrdtScopeNodeInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtScopeNode>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtScopeNode]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtScopeNode]s will have their `id` fields set.
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
  Future<List<CrdtScopeNode>> insert(
    _i1.DatabaseSession session,
    List<CrdtScopeNode> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtScopeNode>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtScopeNode] and returns the inserted row.
  ///
  /// The returned [CrdtScopeNode] will have its `id` field set.
  Future<CrdtScopeNode> insertRow(
    _i1.DatabaseSession session,
    CrdtScopeNode row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtScopeNode>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtScopeNode]s in the list and returns the resulting rows.
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
  /// The returned [CrdtScopeNode]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeNode>> upsert(
    _i1.DatabaseSession session,
    List<CrdtScopeNode> rows, {
    required _i1.ColumnSelections<CrdtScopeNodeTable> conflictColumns,
    _i1.ColumnSelections<CrdtScopeNodeTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtScopeNode>(
      rows,
      conflictColumns: conflictColumns(CrdtScopeNode.t),
      updateColumns: updateColumns?.call(CrdtScopeNode.t),
      updateWhere: updateWhere?.call(CrdtScopeNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtScopeNode] and returns the resulting row.
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
  /// The returned [CrdtScopeNode] will have its `id` field set.
  Future<CrdtScopeNode?> upsertRow(
    _i1.DatabaseSession session,
    CrdtScopeNode row, {
    required _i1.ColumnSelections<CrdtScopeNodeTable> conflictColumns,
    _i1.ColumnSelections<CrdtScopeNodeTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtScopeNode>(
      row,
      conflictColumns: conflictColumns(CrdtScopeNode.t),
      updateColumns: updateColumns?.call(CrdtScopeNode.t),
      updateWhere: updateWhere?.call(CrdtScopeNode.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScopeNode]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeNode>> update(
    _i1.DatabaseSession session,
    List<CrdtScopeNode> rows, {
    _i1.ColumnSelections<CrdtScopeNodeTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtScopeNode>(
      rows,
      columns: columns?.call(CrdtScopeNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtScopeNode]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtScopeNode> updateRow(
    _i1.DatabaseSession session,
    CrdtScopeNode row, {
    _i1.ColumnSelections<CrdtScopeNodeTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtScopeNode>(
      row,
      columns: columns?.call(CrdtScopeNode.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtScopeNode] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtScopeNode?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtScopeNodeUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtScopeNode>(
      id,
      columnValues: columnValues(CrdtScopeNode.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScopeNode]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeNode>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtScopeNodeUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<CrdtScopeNodeTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtScopeNode>(
      columnValues: columnValues(CrdtScopeNode.t.updateTable),
      where: where(CrdtScopeNode.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtScopeNode]s in the list and returns the deleted rows.
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
  Future<List<CrdtScopeNode>> delete(
    _i1.DatabaseSession session,
    List<CrdtScopeNode> rows, {
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtScopeNode>(
      rows,
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtScopeNode].
  Future<CrdtScopeNode> deleteRow(
    _i1.DatabaseSession session,
    CrdtScopeNode row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtScopeNode>(
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
  Future<List<CrdtScopeNode>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtScopeNodeTable> where,
    _i1.OrderByBuilder<CrdtScopeNodeTable>? orderBy,
    _i1.OrderByListBuilder<CrdtScopeNodeTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtScopeNode>(
      where: where(CrdtScopeNode.t),
      orderBy: orderBy?.call(CrdtScopeNode.t),
      orderByList: orderByList?.call(CrdtScopeNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtScopeNodeTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtScopeNode>(
      where: where?.call(CrdtScopeNode.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtScopeNode] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtScopeNodeTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtScopeNode>(
      where: where(CrdtScopeNode.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtScopeNodeAttachRowRepository {
  const CrdtScopeNodeAttachRowRepository._();

  /// Creates a relation between the given [CrdtScopeNode] and [CrdtScope]
  /// by setting the [CrdtScopeNode]'s foreign key `scopeId` to refer to the [CrdtScope].
  Future<void> scope(
    _i1.DatabaseSession session,
    CrdtScopeNode crdtScopeNode,
    _i2.CrdtScope scope, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtScopeNode.id == null) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }
    if (scope.id == null) {
      throw ArgumentError.notNull('scope.id');
    }

    var $crdtScopeNode = crdtScopeNode.copyWith(scopeId: scope.id);
    await session.db.updateRow<CrdtScopeNode>(
      $crdtScopeNode,
      columns: [CrdtScopeNode.t.scopeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtScopeNode] and [CrdtNode]
  /// by setting the [CrdtScopeNode]'s foreign key `nodeId` to refer to the [CrdtNode].
  Future<void> node(
    _i1.DatabaseSession session,
    CrdtScopeNode crdtScopeNode,
    _i3.CrdtNode node, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtScopeNode.id == null) {
      throw ArgumentError.notNull('crdtScopeNode.id');
    }
    if (node.id == null) {
      throw ArgumentError.notNull('node.id');
    }

    var $crdtScopeNode = crdtScopeNode.copyWith(nodeId: node.id);
    await session.db.updateRow<CrdtScopeNode>(
      $crdtScopeNode,
      columns: [CrdtScopeNode.t.nodeId],
      transaction: transaction,
    );
  }
}
