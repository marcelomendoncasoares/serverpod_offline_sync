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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A CRDT node's participation and checkpoint state within one space.
abstract class OfflineSyncSpaceNode
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncSpaceNode._({
    this.id,
    required this.spaceId,
    this.space,
    required this.nodeId,
    this.node,
    this.lastReceivedHlc,
  });

  factory OfflineSyncSpaceNode({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.Hlc? lastReceivedHlc,
  }) = _OfflineSyncSpaceNodeImpl;

  factory OfflineSyncSpaceNode.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncSpaceNode(
      id: jsonSerialization['id'] as int?,
      spaceId: jsonSerialization['spaceId'] as int,
      space: jsonSerialization['space'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.OfflineSyncSpace>(
              jsonSerialization['space'],
            ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['node'],
            ),
      lastReceivedHlc: jsonSerialization['lastReceivedHlc'] == null
          ? null
          : _icw2tu00.Hlc.fromJson(jsonSerialization['lastReceivedHlc']),
    );
  }

  static final t = OfflineSyncSpaceNodeTable();

  static const db = OfflineSyncSpaceNodeRepository._();

  @override
  int? id;

  int spaceId;

  /// Space this participation row belongs to.
  _icw2tu00.OfflineSyncSpace? space;

  int nodeId;

  /// Stable replica identity participating in the space.
  _icw2tu00.CrdtNode? node;

  /// Latest HLC from this node acknowledged for this space.
  _icw2tu00.Hlc? lastReceivedHlc;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncSpaceNode]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncSpaceNode copyWith({
    int? id,
    int? spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    int? nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.Hlc? lastReceivedHlc,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceNode',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJson(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJson(),
      if (lastReceivedHlc != null) 'lastReceivedHlc': lastReceivedHlc?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceNode',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJsonForProtocol(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJsonForProtocol(),
      if (lastReceivedHlc != null)
        'lastReceivedHlc':
            // ignore: unnecessary_type_check
            lastReceivedHlc is _iss.ProtocolSerialization
            ? (lastReceivedHlc as _iss.ProtocolSerialization)
                  .toJsonForProtocol()
            :
              // ignore: dead_code
              lastReceivedHlc?.toJson(),
    };
  }

  static OfflineSyncSpaceNodeInclude include({
    _icw2tu00.OfflineSyncSpaceInclude? space,
    _icw2tu00.CrdtNodeInclude? node,
  }) {
    return OfflineSyncSpaceNodeInclude._(
      space: space,
      node: node,
    );
  }

  static OfflineSyncSpaceNodeIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    OfflineSyncSpaceNodeInclude? include,
  }) {
    return OfflineSyncSpaceNodeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OfflineSyncSpaceNodeImpl extends OfflineSyncSpaceNode {
  _OfflineSyncSpaceNodeImpl({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.Hlc? lastReceivedHlc,
  }) : super._(
         id: id,
         spaceId: spaceId,
         space: space,
         nodeId: nodeId,
         node: node,
         lastReceivedHlc: lastReceivedHlc,
       );

  /// Returns a shallow copy of this [OfflineSyncSpaceNode]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpaceNode copyWith({
    Object? id = _Undefined,
    int? spaceId,
    Object? space = _Undefined,
    int? nodeId,
    Object? node = _Undefined,
    Object? lastReceivedHlc = _Undefined,
  }) {
    return OfflineSyncSpaceNode(
      id: id is int? ? id : this.id,
      spaceId: spaceId ?? this.spaceId,
      space: space is _icw2tu00.OfflineSyncSpace?
          ? space
          : this.space?.copyWith(),
      nodeId: nodeId ?? this.nodeId,
      node: node is _icw2tu00.CrdtNode? ? node : this.node?.copyWith(),
      lastReceivedHlc: lastReceivedHlc is _icw2tu00.Hlc?
          ? lastReceivedHlc
          : this.lastReceivedHlc?.copyWith(),
    );
  }
}

class OfflineSyncSpaceNodeUpdateTable
    extends _isd.UpdateTable<OfflineSyncSpaceNodeTable> {
  OfflineSyncSpaceNodeUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<int, int> nodeId(int value) => _isd.ColumnValue(
    table.nodeId,
    value,
  );

  _isd.ColumnValue<_icw2tu00.Hlc, _icw2tu00.Hlc> lastReceivedHlc(
    _icw2tu00.Hlc? value,
  ) => _isd.ColumnValue(
    table.lastReceivedHlc,
    value,
  );
}

class OfflineSyncSpaceNodeTable extends _isd.Table<int?> {
  OfflineSyncSpaceNodeTable({super.tableRelation})
    : super(tableName: 'offline_sync_space_nodes') {
    updateTable = OfflineSyncSpaceNodeUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    nodeId = _isd.ColumnInt(
      'nodeId',
      this,
    );
    lastReceivedHlc = _isd.ColumnStructured<_icw2tu00.Hlc>(
      'lastReceivedHlc',
      this,
    );
  }

  late final OfflineSyncSpaceNodeUpdateTable updateTable;

  late final _isd.ColumnInt spaceId;

  /// Space this participation row belongs to.
  _icw2tu00.OfflineSyncSpaceTable? _space;

  late final _isd.ColumnInt nodeId;

  /// Stable replica identity participating in the space.
  _icw2tu00.CrdtNodeTable? _node;

  /// Latest HLC from this node acknowledged for this space.
  late final _isd.ColumnStructured<_icw2tu00.Hlc> lastReceivedHlc;

  _icw2tu00.OfflineSyncSpaceTable get space {
    if (_space != null) return _space!;
    _space = _isd.createRelationTable(
      relationFieldName: 'space',
      field: OfflineSyncSpaceNode.t.spaceId,
      foreignField: _icw2tu00.OfflineSyncSpace.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncSpaceTable(tableRelation: foreignTableRelation),
    );
    return _space!;
  }

  _icw2tu00.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _isd.createRelationTable(
      relationFieldName: 'node',
      field: OfflineSyncSpaceNode.t.nodeId,
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
    spaceId,
    nodeId,
    lastReceivedHlc,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'space') {
      return space;
    }
    if (relationField == 'node') {
      return node;
    }
    return null;
  }
}

class OfflineSyncSpaceNodeInclude extends _isd.IncludeObject {
  OfflineSyncSpaceNodeInclude._({
    _icw2tu00.OfflineSyncSpaceInclude? space,
    _icw2tu00.CrdtNodeInclude? node,
  }) {
    _space = space;
    _node = node;
  }

  _icw2tu00.OfflineSyncSpaceInclude? _space;

  _icw2tu00.CrdtNodeInclude? _node;

  @override
  Map<String, _isd.Include?> get includes => {
    'space': _space,
    'node': _node,
  };

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceNode.t;
}

class OfflineSyncSpaceNodeIncludeList extends _isd.IncludeList {
  OfflineSyncSpaceNodeIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncSpaceNode.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceNode.t;
}

class OfflineSyncSpaceNodeRepository {
  const OfflineSyncSpaceNodeRepository._();

  final attachRow = const OfflineSyncSpaceNodeAttachRowRepository._();

  /// Returns a list of [OfflineSyncSpaceNode]s matching the given query parameters.
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
  Future<List<OfflineSyncSpaceNode>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceNodeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncSpaceNode>(
      where: where?.call(OfflineSyncSpaceNode.t),
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OfflineSyncSpaceNode] matching the given query parameters.
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
  Future<OfflineSyncSpaceNode?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceNodeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncSpaceNode>(
      where: where?.call(OfflineSyncSpaceNode.t),
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncSpaceNode] by its [id] or null if no such row exists.
  Future<OfflineSyncSpaceNode?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    OfflineSyncSpaceNodeInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncSpaceNode>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncSpaceNode]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncSpaceNode]s will have their `id` fields set.
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
  Future<List<OfflineSyncSpaceNode>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceNode> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncSpaceNode>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncSpaceNode] and returns the inserted row.
  ///
  /// The returned [OfflineSyncSpaceNode] will have its `id` field set.
  Future<OfflineSyncSpaceNode> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncSpaceNode>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncSpaceNode]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncSpaceNode]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceNode>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceNode> rows, {
    required _isd.ColumnSelections<OfflineSyncSpaceNodeTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceNodeTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncSpaceNode>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncSpaceNode.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceNode.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncSpaceNode] and returns the resulting row.
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
  /// The returned [OfflineSyncSpaceNode] will have its `id` field set.
  Future<OfflineSyncSpaceNode?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode row, {
    required _isd.ColumnSelections<OfflineSyncSpaceNodeTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceNodeTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncSpaceNode>(
      row,
      conflictColumns: conflictColumns(OfflineSyncSpaceNode.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceNode.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceNode]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceNode>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceNode> rows, {
    _isd.ColumnSelections<OfflineSyncSpaceNodeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncSpaceNode>(
      rows,
      columns: columns?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncSpaceNode]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncSpaceNode> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode row, {
    _isd.ColumnSelections<OfflineSyncSpaceNodeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncSpaceNode>(
      row,
      columns: columns?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncSpaceNode] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncSpaceNode?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceNodeUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncSpaceNode>(
      id,
      columnValues: columnValues(OfflineSyncSpaceNode.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceNode]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceNode>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceNodeUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncSpaceNode>(
      columnValues: columnValues(OfflineSyncSpaceNode.t.updateTable),
      where: where(OfflineSyncSpaceNode.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncSpaceNode]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncSpaceNode>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceNode> rows, {
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncSpaceNode>(
      rows,
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncSpaceNode].
  Future<OfflineSyncSpaceNode> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncSpaceNode>(
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
  Future<List<OfflineSyncSpaceNode>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable> where,
    _isd.OrderByBuilder<OfflineSyncSpaceNodeTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceNodeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncSpaceNode>(
      where: where(OfflineSyncSpaceNode.t),
      orderBy: orderBy?.call(OfflineSyncSpaceNode.t),
      orderByList: orderByList?.call(OfflineSyncSpaceNode.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncSpaceNode>(
      where: where?.call(OfflineSyncSpaceNode.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncSpaceNode] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceNodeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncSpaceNode>(
      where: where(OfflineSyncSpaceNode.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class OfflineSyncSpaceNodeAttachRowRepository {
  const OfflineSyncSpaceNodeAttachRowRepository._();

  /// Creates a relation between the given [OfflineSyncSpaceNode] and [OfflineSyncSpace]
  /// by setting the [OfflineSyncSpaceNode]'s foreign key `spaceId` to refer to the [OfflineSyncSpace].
  Future<void> space(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode offlineSyncSpaceNode,
    _icw2tu00.OfflineSyncSpace space, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpaceNode.id == null) {
      throw ArgumentError.notNull('offlineSyncSpaceNode.id');
    }
    if (space.id == null) {
      throw ArgumentError.notNull('space.id');
    }

    var $offlineSyncSpaceNode = offlineSyncSpaceNode.copyWith(
      spaceId: space.id,
    );
    await session.db.updateRow<OfflineSyncSpaceNode>(
      $offlineSyncSpaceNode,
      columns: [OfflineSyncSpaceNode.t.spaceId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [OfflineSyncSpaceNode] and [CrdtNode]
  /// by setting the [OfflineSyncSpaceNode]'s foreign key `nodeId` to refer to the [CrdtNode].
  Future<void> node(
    _isd.DatabaseSession session,
    OfflineSyncSpaceNode offlineSyncSpaceNode,
    _icw2tu00.CrdtNode node, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpaceNode.id == null) {
      throw ArgumentError.notNull('offlineSyncSpaceNode.id');
    }
    if (node.id == null) {
      throw ArgumentError.notNull('node.id');
    }

    var $offlineSyncSpaceNode = offlineSyncSpaceNode.copyWith(nodeId: node.id);
    await session.db.updateRow<OfflineSyncSpaceNode>(
      $offlineSyncSpaceNode,
      columns: [OfflineSyncSpaceNode.t.nodeId],
      transaction: transaction,
    );
  }
}
