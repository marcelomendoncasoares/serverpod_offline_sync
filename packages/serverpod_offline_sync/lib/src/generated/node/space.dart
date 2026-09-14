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

/// CRDT spaces table.
///
/// Normalized storage for space IDs. The normalized data table references this
/// by integer id instead of storing the space id string.
abstract class OfflineSyncSpace
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncSpace._({
    this.id,
    _iss.UuidValue? uuidSpaceId,
    this.currentNodeId,
    this.currentNode,
    this.nodes,
  }) : uuidSpaceId = uuidSpaceId ?? const _iss.Uuid().v7obj();

  factory OfflineSyncSpace({
    int? id,
    _iss.UuidValue? uuidSpaceId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.OfflineSyncSpaceNode>? nodes,
  }) = _OfflineSyncSpaceImpl;

  factory OfflineSyncSpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncSpace(
      id: jsonSerialization['id'] as int?,
      uuidSpaceId: jsonSerialization['uuidSpaceId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['uuidSpaceId'],
            ),
      currentNodeId: jsonSerialization['currentNodeId'] as int?,
      currentNode: jsonSerialization['currentNode'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['currentNode'],
            ),
      nodes: jsonSerialization['nodes'] == null
          ? null
          : _icw2tu00.Protocol()
                .deserialize<List<_icw2tu00.OfflineSyncSpaceNode>>(
                  jsonSerialization['nodes'],
                ),
    );
  }

  static final t = OfflineSyncSpaceTable();

  static const db = OfflineSyncSpaceRepository._();

  @override
  int? id;

  /// Space identifier string.
  _iss.UuidValue uuidSpaceId;

  int? currentNodeId;

  /// The current node id of the space.
  _icw2tu00.CrdtNode? currentNode;

  /// The nodes associated with the space and their per-space checkpoints.
  List<_icw2tu00.OfflineSyncSpaceNode>? nodes;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncSpace]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncSpace copyWith({
    int? id,
    _iss.UuidValue? uuidSpaceId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.OfflineSyncSpaceNode>? nodes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpace',
      if (id != null) 'id': id,
      'uuidSpaceId': uuidSpaceId.toJson(),
      if (currentNodeId != null) 'currentNodeId': currentNodeId,
      if (currentNode != null) 'currentNode': currentNode?.toJson(),
      if (nodes != null) 'nodes': nodes?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpace',
      if (id != null) 'id': id,
      'uuidSpaceId': uuidSpaceId.toJson(),
      if (currentNodeId != null) 'currentNodeId': currentNodeId,
      if (currentNode != null) 'currentNode': currentNode?.toJsonForProtocol(),
      if (nodes != null)
        'nodes': nodes?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  static OfflineSyncSpaceInclude include({
    _icw2tu00.CrdtNodeInclude? currentNode,
    _icw2tu00.OfflineSyncSpaceNodeIncludeList? nodes,
  }) {
    return OfflineSyncSpaceInclude._(
      currentNode: currentNode,
      nodes: nodes,
    );
  }

  static OfflineSyncSpaceIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    OfflineSyncSpaceInclude? include,
  }) {
    return OfflineSyncSpaceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OfflineSyncSpaceImpl extends OfflineSyncSpace {
  _OfflineSyncSpaceImpl({
    int? id,
    _iss.UuidValue? uuidSpaceId,
    int? currentNodeId,
    _icw2tu00.CrdtNode? currentNode,
    List<_icw2tu00.OfflineSyncSpaceNode>? nodes,
  }) : super._(
         id: id,
         uuidSpaceId: uuidSpaceId,
         currentNodeId: currentNodeId,
         currentNode: currentNode,
         nodes: nodes,
       );

  /// Returns a shallow copy of this [OfflineSyncSpace]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpace copyWith({
    Object? id = _Undefined,
    _iss.UuidValue? uuidSpaceId,
    Object? currentNodeId = _Undefined,
    Object? currentNode = _Undefined,
    Object? nodes = _Undefined,
  }) {
    return OfflineSyncSpace(
      id: id is int? ? id : this.id,
      uuidSpaceId: uuidSpaceId ?? this.uuidSpaceId,
      currentNodeId: currentNodeId is int? ? currentNodeId : this.currentNodeId,
      currentNode: currentNode is _icw2tu00.CrdtNode?
          ? currentNode
          : this.currentNode?.copyWith(),
      nodes: nodes is List<_icw2tu00.OfflineSyncSpaceNode>?
          ? nodes
          : this.nodes?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class OfflineSyncSpaceUpdateTable
    extends _isd.UpdateTable<OfflineSyncSpaceTable> {
  OfflineSyncSpaceUpdateTable(super.table);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> uuidSpaceId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.uuidSpaceId,
    value,
  );

  _isd.ColumnValue<int, int> currentNodeId(int? value) => _isd.ColumnValue(
    table.currentNodeId,
    value,
  );
}

class OfflineSyncSpaceTable extends _isd.Table<int?> {
  OfflineSyncSpaceTable({super.tableRelation})
    : super(tableName: 'offline_sync_spaces') {
    updateTable = OfflineSyncSpaceUpdateTable(this);
    uuidSpaceId = _isd.ColumnUuid(
      'uuidSpaceId',
      this,
      hasDefault: true,
    );
    currentNodeId = _isd.ColumnInt(
      'currentNodeId',
      this,
    );
  }

  late final OfflineSyncSpaceUpdateTable updateTable;

  /// Space identifier string.
  late final _isd.ColumnUuid uuidSpaceId;

  late final _isd.ColumnInt currentNodeId;

  /// The current node id of the space.
  _icw2tu00.CrdtNodeTable? _currentNode;

  /// The nodes associated with the space and their per-space checkpoints.
  _icw2tu00.OfflineSyncSpaceNodeTable? ___nodes;

  /// The nodes associated with the space and their per-space checkpoints.
  _isd.ManyRelation<_icw2tu00.OfflineSyncSpaceNodeTable>? _nodes;

  _icw2tu00.CrdtNodeTable get currentNode {
    if (_currentNode != null) return _currentNode!;
    _currentNode = _isd.createRelationTable(
      relationFieldName: 'currentNode',
      field: OfflineSyncSpace.t.currentNodeId,
      foreignField: _icw2tu00.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _currentNode!;
  }

  _icw2tu00.OfflineSyncSpaceNodeTable get __nodes {
    if (___nodes != null) return ___nodes!;
    ___nodes = _isd.createRelationTable(
      relationFieldName: '__nodes',
      field: OfflineSyncSpace.t.id,
      foreignField: _icw2tu00.OfflineSyncSpaceNode.t.spaceId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncSpaceNodeTable(
            tableRelation: foreignTableRelation,
          ),
    );
    return ___nodes!;
  }

  _isd.ManyRelation<_icw2tu00.OfflineSyncSpaceNodeTable> get nodes {
    if (_nodes != null) return _nodes!;
    var relationTable = _isd.createRelationTable(
      relationFieldName: 'nodes',
      field: OfflineSyncSpace.t.id,
      foreignField: _icw2tu00.OfflineSyncSpaceNode.t.spaceId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncSpaceNodeTable(
            tableRelation: foreignTableRelation,
          ),
    );
    _nodes = _isd.ManyRelation<_icw2tu00.OfflineSyncSpaceNodeTable>(
      tableWithRelations: relationTable,
      table: _icw2tu00.OfflineSyncSpaceNodeTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _nodes!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    uuidSpaceId,
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

class OfflineSyncSpaceInclude extends _isd.IncludeObject {
  OfflineSyncSpaceInclude._({
    _icw2tu00.CrdtNodeInclude? currentNode,
    _icw2tu00.OfflineSyncSpaceNodeIncludeList? nodes,
  }) {
    _currentNode = currentNode;
    _nodes = nodes;
  }

  _icw2tu00.CrdtNodeInclude? _currentNode;

  _icw2tu00.OfflineSyncSpaceNodeIncludeList? _nodes;

  @override
  Map<String, _isd.Include?> get includes => {
    'currentNode': _currentNode,
    'nodes': _nodes,
  };

  @override
  _isd.Table<int?> get table => OfflineSyncSpace.t;
}

class OfflineSyncSpaceIncludeList extends _isd.IncludeList {
  OfflineSyncSpaceIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncSpace.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncSpace.t;
}

class OfflineSyncSpaceRepository {
  const OfflineSyncSpaceRepository._();

  final attach = const OfflineSyncSpaceAttachRepository._();

  final attachRow = const OfflineSyncSpaceAttachRowRepository._();

  final detachRow = const OfflineSyncSpaceDetachRowRepository._();

  /// Returns a list of [OfflineSyncSpace]s matching the given query parameters.
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
  Future<List<OfflineSyncSpace>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncSpace>(
      where: where?.call(OfflineSyncSpace.t),
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OfflineSyncSpace] matching the given query parameters.
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
  Future<OfflineSyncSpace?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncSpace>(
      where: where?.call(OfflineSyncSpace.t),
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncSpace] by its [id] or null if no such row exists.
  Future<OfflineSyncSpace?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    OfflineSyncSpaceInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncSpace>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncSpace]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncSpace]s will have their `id` fields set.
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
  Future<List<OfflineSyncSpace>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpace> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncSpace>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncSpace] and returns the inserted row.
  ///
  /// The returned [OfflineSyncSpace] will have its `id` field set.
  Future<OfflineSyncSpace> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncSpace>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncSpace]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncSpace]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpace>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpace> rows, {
    required _isd.ColumnSelections<OfflineSyncSpaceTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncSpace>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncSpace.t),
      updateColumns: updateColumns?.call(OfflineSyncSpace.t),
      updateWhere: updateWhere?.call(OfflineSyncSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncSpace] and returns the resulting row.
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
  /// The returned [OfflineSyncSpace] will have its `id` field set.
  Future<OfflineSyncSpace?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpace row, {
    required _isd.ColumnSelections<OfflineSyncSpaceTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncSpace>(
      row,
      conflictColumns: conflictColumns(OfflineSyncSpace.t),
      updateColumns: updateColumns?.call(OfflineSyncSpace.t),
      updateWhere: updateWhere?.call(OfflineSyncSpace.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpace]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpace>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncSpace> rows, {
    _isd.ColumnSelections<OfflineSyncSpaceTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncSpace>(
      rows,
      columns: columns?.call(OfflineSyncSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncSpace]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncSpace> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncSpace row, {
    _isd.ColumnSelections<OfflineSyncSpaceTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncSpace>(
      row,
      columns: columns?.call(OfflineSyncSpace.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncSpace] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncSpace?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncSpace>(
      id,
      columnValues: columnValues(OfflineSyncSpace.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpace]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpace>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncSpace>(
      columnValues: columnValues(OfflineSyncSpace.t.updateTable),
      where: where(OfflineSyncSpace.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncSpace]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncSpace>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncSpace> rows, {
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncSpace>(
      rows,
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncSpace].
  Future<OfflineSyncSpace> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncSpace row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncSpace>(
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
  Future<List<OfflineSyncSpace>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceTable> where,
    _isd.OrderByBuilder<OfflineSyncSpaceTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncSpace>(
      where: where(OfflineSyncSpace.t),
      orderBy: orderBy?.call(OfflineSyncSpace.t),
      orderByList: orderByList?.call(OfflineSyncSpace.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncSpace>(
      where: where?.call(OfflineSyncSpace.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncSpace] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncSpace>(
      where: where(OfflineSyncSpace.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class OfflineSyncSpaceAttachRepository {
  const OfflineSyncSpaceAttachRepository._();

  /// Creates a relation between this [OfflineSyncSpace] and the given [OfflineSyncSpaceNode]s
  /// by setting each [OfflineSyncSpaceNode]'s foreign key `spaceId` to refer to this [OfflineSyncSpace].
  Future<void> nodes(
    _isd.DatabaseSession session,
    OfflineSyncSpace offlineSyncSpace,
    List<_icw2tu00.OfflineSyncSpaceNode> offlineSyncSpaceNode, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpaceNode.any((e) => e.id == null)) {
      throw ArgumentError.notNull('offlineSyncSpaceNode.id');
    }
    if (offlineSyncSpace.id == null) {
      throw ArgumentError.notNull('offlineSyncSpace.id');
    }

    var $offlineSyncSpaceNode = offlineSyncSpaceNode
        .map((e) => e.copyWith(spaceId: offlineSyncSpace.id))
        .toList();
    await session.db.update<_icw2tu00.OfflineSyncSpaceNode>(
      $offlineSyncSpaceNode,
      columns: [_icw2tu00.OfflineSyncSpaceNode.t.spaceId],
      transaction: transaction,
    );
  }
}

class OfflineSyncSpaceAttachRowRepository {
  const OfflineSyncSpaceAttachRowRepository._();

  /// Creates a relation between the given [OfflineSyncSpace] and [CrdtNode]
  /// by setting the [OfflineSyncSpace]'s foreign key `currentNodeId` to refer to the [CrdtNode].
  Future<void> currentNode(
    _isd.DatabaseSession session,
    OfflineSyncSpace offlineSyncSpace,
    _icw2tu00.CrdtNode currentNode, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpace.id == null) {
      throw ArgumentError.notNull('offlineSyncSpace.id');
    }
    if (currentNode.id == null) {
      throw ArgumentError.notNull('currentNode.id');
    }

    var $offlineSyncSpace = offlineSyncSpace.copyWith(
      currentNodeId: currentNode.id,
    );
    await session.db.updateRow<OfflineSyncSpace>(
      $offlineSyncSpace,
      columns: [OfflineSyncSpace.t.currentNodeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between this [OfflineSyncSpace] and the given [OfflineSyncSpaceNode]
  /// by setting the [OfflineSyncSpaceNode]'s foreign key `spaceId` to refer to this [OfflineSyncSpace].
  Future<void> nodes(
    _isd.DatabaseSession session,
    OfflineSyncSpace offlineSyncSpace,
    _icw2tu00.OfflineSyncSpaceNode offlineSyncSpaceNode, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpaceNode.id == null) {
      throw ArgumentError.notNull('offlineSyncSpaceNode.id');
    }
    if (offlineSyncSpace.id == null) {
      throw ArgumentError.notNull('offlineSyncSpace.id');
    }

    var $offlineSyncSpaceNode = offlineSyncSpaceNode.copyWith(
      spaceId: offlineSyncSpace.id,
    );
    await session.db.updateRow<_icw2tu00.OfflineSyncSpaceNode>(
      $offlineSyncSpaceNode,
      columns: [_icw2tu00.OfflineSyncSpaceNode.t.spaceId],
      transaction: transaction,
    );
  }
}

class OfflineSyncSpaceDetachRowRepository {
  const OfflineSyncSpaceDetachRowRepository._();

  /// Detaches the relation between this [OfflineSyncSpace] and the [CrdtNode] set in `currentNode`
  /// by setting the [OfflineSyncSpace]'s foreign key `currentNodeId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> currentNode(
    _isd.DatabaseSession session,
    OfflineSyncSpace offlineSyncSpace, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpace.id == null) {
      throw ArgumentError.notNull('offlineSyncSpace.id');
    }

    var $offlineSyncSpace = offlineSyncSpace.copyWith(currentNodeId: null);
    await session.db.updateRow<OfflineSyncSpace>(
      $offlineSyncSpace,
      columns: [OfflineSyncSpace.t.currentNodeId],
      transaction: transaction,
    );
  }
}
