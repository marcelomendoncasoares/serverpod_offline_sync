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
import '../fk_chain/root.dart' as _i3;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _i4;

abstract class FkChainCascadeMiddle implements _i1.TableRow<_i2.UuidValue?> {
  FkChainCascadeMiddle._({
    this.id,
    this.scopeId,
    required this.name,
    this.root,
    this.rootId,
  });

  factory FkChainCascadeMiddle({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.FkChainRoot? root,
    _i2.UuidValue? rootId,
  }) = _FkChainCascadeMiddleImpl;

  factory FkChainCascadeMiddle.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainCascadeMiddle(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      root: jsonSerialization['root'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.FkChainRoot>(
              jsonSerialization['root'],
            ),
      rootId: jsonSerialization['rootId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['rootId']),
    );
  }

  static final t = FkChainCascadeMiddleTable();

  static const db = FkChainCascadeMiddleRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i3.FkChainRoot? root;

  _i2.UuidValue? rootId;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainCascadeMiddle]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  FkChainCascadeMiddle copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    String? name,
    _i3.FkChainRoot? root,
    _i2.UuidValue? rootId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainCascadeMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (root != null) 'root': root?.toJson(),
      if (rootId != null) 'rootId': rootId?.toJson(),
    };
  }

  static FkChainCascadeMiddleInclude include({_i3.FkChainRootInclude? root}) {
    return FkChainCascadeMiddleInclude._(root: root);
  }

  static FkChainCascadeMiddleIncludeList includeList({
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    FkChainCascadeMiddleInclude? include,
  }) {
    return FkChainCascadeMiddleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainCascadeMiddleImpl extends FkChainCascadeMiddle {
  _FkChainCascadeMiddleImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.FkChainRoot? root,
    _i2.UuidValue? rootId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         root: root,
         rootId: rootId,
       );

  /// Returns a shallow copy of this [FkChainCascadeMiddle]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  FkChainCascadeMiddle copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? root = _Undefined,
    Object? rootId = _Undefined,
  }) {
    return FkChainCascadeMiddle(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      root: root is _i3.FkChainRoot? ? root : this.root?.copyWith(),
      rootId: rootId is _i2.UuidValue? ? rootId : this.rootId,
    );
  }
}

class FkChainCascadeMiddleUpdateTable
    extends _i1.UpdateTable<FkChainCascadeMiddleTable> {
  FkChainCascadeMiddleUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> rootId(_i2.UuidValue? value) =>
      _i1.ColumnValue(
        table.rootId,
        value,
      );
}

class FkChainCascadeMiddleTable extends _i1.Table<_i2.UuidValue?> {
  FkChainCascadeMiddleTable({super.tableRelation})
    : super(tableName: 'fk_chain_cascade_middle') {
    updateTable = FkChainCascadeMiddleUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    rootId = _i1.ColumnUuid(
      'rootId',
      this,
    );
  }

  late final FkChainCascadeMiddleUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i3.FkChainRootTable? _root;

  late final _i1.ColumnUuid rootId;

  _i3.FkChainRootTable get root {
    if (_root != null) return _root!;
    _root = _i1.createRelationTable(
      relationFieldName: 'root',
      field: FkChainCascadeMiddle.t.rootId,
      foreignField: _i3.FkChainRoot.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.FkChainRootTable(tableRelation: foreignTableRelation),
    );
    return _root!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    rootId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'root') {
      return root;
    }
    return null;
  }
}

class FkChainCascadeMiddleInclude extends _i1.IncludeObject {
  FkChainCascadeMiddleInclude._({_i3.FkChainRootInclude? root}) {
    _root = root;
  }

  _i3.FkChainRootInclude? _root;

  @override
  Map<String, _i1.Include?> get includes => {'root': _root};

  @override
  _i1.Table<_i2.UuidValue?> get table => FkChainCascadeMiddle.t;
}

class FkChainCascadeMiddleIncludeList extends _i1.IncludeList {
  FkChainCascadeMiddleIncludeList._({
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainCascadeMiddle.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => FkChainCascadeMiddle.t;
}

class FkChainCascadeMiddleRepository {
  const FkChainCascadeMiddleRepository._();

  final attachRow = const FkChainCascadeMiddleAttachRowRepository._();

  final detachRow = const FkChainCascadeMiddleDetachRowRepository._();

  /// Returns a list of [FkChainCascadeMiddle]s matching the given query parameters.
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
  Future<List<FkChainCascadeMiddle>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
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

  /// Returns the first matching [FkChainCascadeMiddle] matching the given query parameters.
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
  Future<FkChainCascadeMiddle?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? offset,
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainCascadeMiddle] by its [id] or null if no such row exists.
  Future<FkChainCascadeMiddle?> findById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainCascadeMiddle>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainCascadeMiddle]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainCascadeMiddle]s will have their `id` fields set.
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
  Future<List<FkChainCascadeMiddle>> insert(
    _i1.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainCascadeMiddle>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainCascadeMiddle] and returns the inserted row.
  ///
  /// The returned [FkChainCascadeMiddle] will have its `id` field set.
  Future<FkChainCascadeMiddle> insertRow(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainCascadeMiddle>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainCascadeMiddle]s in the list and returns the resulting rows.
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
  /// The returned [FkChainCascadeMiddle]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> upsert(
    _i1.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    required _i1.ColumnSelections<FkChainCascadeMiddleTable> conflictColumns,
    _i1.ColumnSelections<FkChainCascadeMiddleTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainCascadeMiddle>(
      rows,
      conflictColumns: conflictColumns(FkChainCascadeMiddle.t),
      updateColumns: updateColumns?.call(FkChainCascadeMiddle.t),
      updateWhere: updateWhere?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainCascadeMiddle] and returns the resulting row.
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
  /// The returned [FkChainCascadeMiddle] will have its `id` field set.
  Future<FkChainCascadeMiddle?> upsertRow(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle row, {
    required _i1.ColumnSelections<FkChainCascadeMiddleTable> conflictColumns,
    _i1.ColumnSelections<FkChainCascadeMiddleTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainCascadeMiddle>(
      row,
      conflictColumns: conflictColumns(FkChainCascadeMiddle.t),
      updateColumns: updateColumns?.call(FkChainCascadeMiddle.t),
      updateWhere: updateWhere?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainCascadeMiddle]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> update(
    _i1.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _i1.ColumnSelections<FkChainCascadeMiddleTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainCascadeMiddle>(
      rows,
      columns: columns?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainCascadeMiddle]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainCascadeMiddle> updateRow(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _i1.ColumnSelections<FkChainCascadeMiddleTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainCascadeMiddle>(
      row,
      columns: columns?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainCascadeMiddle] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainCascadeMiddle?> updateById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<FkChainCascadeMiddleUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainCascadeMiddle>(
      id,
      columnValues: columnValues(FkChainCascadeMiddle.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainCascadeMiddle]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<FkChainCascadeMiddleUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainCascadeMiddle>(
      columnValues: columnValues(FkChainCascadeMiddle.t.updateTable),
      where: where(FkChainCascadeMiddle.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainCascadeMiddle]s in the list and returns the deleted rows.
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
  Future<List<FkChainCascadeMiddle>> delete(
    _i1.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainCascadeMiddle>(
      rows,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainCascadeMiddle].
  Future<FkChainCascadeMiddle> deleteRow(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainCascadeMiddle>(
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
  Future<List<FkChainCascadeMiddle>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    _i1.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainCascadeMiddle>(
      where: where(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainCascadeMiddle] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainCascadeMiddle>(
      where: where(FkChainCascadeMiddle.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainCascadeMiddleAttachRowRepository {
  const FkChainCascadeMiddleAttachRowRepository._();

  /// Creates a relation between the given [FkChainCascadeMiddle] and [FkChainRoot]
  /// by setting the [FkChainCascadeMiddle]'s foreign key `rootId` to refer to the [FkChainRoot].
  Future<void> root(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle fkChainCascadeMiddle,
    _i3.FkChainRoot root, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainCascadeMiddle.id == null) {
      throw ArgumentError.notNull('fkChainCascadeMiddle.id');
    }
    if (root.id == null) {
      throw ArgumentError.notNull('root.id');
    }

    var $fkChainCascadeMiddle = fkChainCascadeMiddle.copyWith(rootId: root.id);
    await session.db.updateRow<FkChainCascadeMiddle>(
      $fkChainCascadeMiddle,
      columns: [FkChainCascadeMiddle.t.rootId],
      transaction: transaction,
    );
  }
}

class FkChainCascadeMiddleDetachRowRepository {
  const FkChainCascadeMiddleDetachRowRepository._();

  /// Detaches the relation between this [FkChainCascadeMiddle] and the [FkChainRoot] set in `root`
  /// by setting the [FkChainCascadeMiddle]'s foreign key `rootId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> root(
    _i1.DatabaseSession session,
    FkChainCascadeMiddle fkChainCascadeMiddle, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainCascadeMiddle.id == null) {
      throw ArgumentError.notNull('fkChainCascadeMiddle.id');
    }

    var $fkChainCascadeMiddle = fkChainCascadeMiddle.copyWith(rootId: null);
    await session.db.updateRow<FkChainCascadeMiddle>(
      $fkChainCascadeMiddle,
      columns: [FkChainCascadeMiddle.t.rootId],
      transaction: transaction,
    );
  }
}
