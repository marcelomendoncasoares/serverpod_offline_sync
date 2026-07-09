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
import '../fk_chain/set_null_middle.dart' as _i3;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _i4;

abstract class FkChainSetNullRestrictChild
    implements _i1.TableRow<_i2.UuidValue?> {
  FkChainSetNullRestrictChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.setNullMiddle,
    this.setNullMiddleId,
  });

  factory FkChainSetNullRestrictChild({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.FkChainSetNullMiddle? setNullMiddle,
    _i2.UuidValue? setNullMiddleId,
  }) = _FkChainSetNullRestrictChildImpl;

  factory FkChainSetNullRestrictChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullRestrictChild(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      setNullMiddle: jsonSerialization['setNullMiddle'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.FkChainSetNullMiddle>(
              jsonSerialization['setNullMiddle'],
            ),
      setNullMiddleId: jsonSerialization['setNullMiddleId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['setNullMiddleId'],
            ),
    );
  }

  static final t = FkChainSetNullRestrictChildTable();

  static const db = FkChainSetNullRestrictChildRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i3.FkChainSetNullMiddle? setNullMiddle;

  _i2.UuidValue? setNullMiddleId;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullRestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  FkChainSetNullRestrictChild copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    String? name,
    _i3.FkChainSetNullMiddle? setNullMiddle,
    _i2.UuidValue? setNullMiddleId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullRestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddle != null) 'setNullMiddle': setNullMiddle?.toJson(),
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
    };
  }

  static FkChainSetNullRestrictChildInclude include({
    _i3.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    return FkChainSetNullRestrictChildInclude._(setNullMiddle: setNullMiddle);
  }

  static FkChainSetNullRestrictChildIncludeList includeList({
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    FkChainSetNullRestrictChildInclude? include,
  }) {
    return FkChainSetNullRestrictChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullRestrictChildImpl extends FkChainSetNullRestrictChild {
  _FkChainSetNullRestrictChildImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.FkChainSetNullMiddle? setNullMiddle,
    _i2.UuidValue? setNullMiddleId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         setNullMiddle: setNullMiddle,
         setNullMiddleId: setNullMiddleId,
       );

  /// Returns a shallow copy of this [FkChainSetNullRestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  FkChainSetNullRestrictChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? setNullMiddle = _Undefined,
    Object? setNullMiddleId = _Undefined,
  }) {
    return FkChainSetNullRestrictChild(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      setNullMiddle: setNullMiddle is _i3.FkChainSetNullMiddle?
          ? setNullMiddle
          : this.setNullMiddle?.copyWith(),
      setNullMiddleId: setNullMiddleId is _i2.UuidValue?
          ? setNullMiddleId
          : this.setNullMiddleId,
    );
  }
}

class FkChainSetNullRestrictChildUpdateTable
    extends _i1.UpdateTable<FkChainSetNullRestrictChildTable> {
  FkChainSetNullRestrictChildUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> setNullMiddleId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.setNullMiddleId,
    value,
  );
}

class FkChainSetNullRestrictChildTable extends _i1.Table<_i2.UuidValue?> {
  FkChainSetNullRestrictChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_restrict_child') {
    updateTable = FkChainSetNullRestrictChildUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    setNullMiddleId = _i1.ColumnUuid(
      'setNullMiddleId',
      this,
    );
  }

  late final FkChainSetNullRestrictChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i3.FkChainSetNullMiddleTable? _setNullMiddle;

  late final _i1.ColumnUuid setNullMiddleId;

  _i3.FkChainSetNullMiddleTable get setNullMiddle {
    if (_setNullMiddle != null) return _setNullMiddle!;
    _setNullMiddle = _i1.createRelationTable(
      relationFieldName: 'setNullMiddle',
      field: FkChainSetNullRestrictChild.t.setNullMiddleId,
      foreignField: _i3.FkChainSetNullMiddle.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.FkChainSetNullMiddleTable(tableRelation: foreignTableRelation),
    );
    return _setNullMiddle!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    setNullMiddleId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'setNullMiddle') {
      return setNullMiddle;
    }
    return null;
  }
}

class FkChainSetNullRestrictChildInclude extends _i1.IncludeObject {
  FkChainSetNullRestrictChildInclude._({
    _i3.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    _setNullMiddle = setNullMiddle;
  }

  _i3.FkChainSetNullMiddleInclude? _setNullMiddle;

  @override
  Map<String, _i1.Include?> get includes => {'setNullMiddle': _setNullMiddle};

  @override
  _i1.Table<_i2.UuidValue?> get table => FkChainSetNullRestrictChild.t;
}

class FkChainSetNullRestrictChildIncludeList extends _i1.IncludeList {
  FkChainSetNullRestrictChildIncludeList._({
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullRestrictChild.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => FkChainSetNullRestrictChild.t;
}

class FkChainSetNullRestrictChildRepository {
  const FkChainSetNullRestrictChildRepository._();

  final attachRow = const FkChainSetNullRestrictChildAttachRowRepository._();

  final detachRow = const FkChainSetNullRestrictChildDetachRowRepository._();

  /// Returns a list of [FkChainSetNullRestrictChild]s matching the given query parameters.
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
  Future<List<FkChainSetNullRestrictChild>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
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

  /// Returns the first matching [FkChainSetNullRestrictChild] matching the given query parameters.
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
  Future<FkChainSetNullRestrictChild?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainSetNullRestrictChild] by its [id] or null if no such row exists.
  Future<FkChainSetNullRestrictChild?> findById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainSetNullRestrictChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainSetNullRestrictChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainSetNullRestrictChild]s will have their `id` fields set.
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
  Future<List<FkChainSetNullRestrictChild>> insert(
    _i1.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainSetNullRestrictChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainSetNullRestrictChild] and returns the inserted row.
  ///
  /// The returned [FkChainSetNullRestrictChild] will have its `id` field set.
  Future<FkChainSetNullRestrictChild> insertRow(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainSetNullRestrictChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainSetNullRestrictChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainSetNullRestrictChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullRestrictChild>> upsert(
    _i1.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    required _i1.ColumnSelections<FkChainSetNullRestrictChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainSetNullRestrictChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainSetNullRestrictChild>(
      rows,
      conflictColumns: conflictColumns(FkChainSetNullRestrictChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullRestrictChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainSetNullRestrictChild] and returns the resulting row.
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
  /// The returned [FkChainSetNullRestrictChild] will have its `id` field set.
  Future<FkChainSetNullRestrictChild?> upsertRow(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    required _i1.ColumnSelections<FkChainSetNullRestrictChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainSetNullRestrictChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainSetNullRestrictChild>(
      row,
      conflictColumns: conflictColumns(FkChainSetNullRestrictChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullRestrictChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullRestrictChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullRestrictChild>> update(
    _i1.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _i1.ColumnSelections<FkChainSetNullRestrictChildTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainSetNullRestrictChild>(
      rows,
      columns: columns?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainSetNullRestrictChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainSetNullRestrictChild> updateRow(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _i1.ColumnSelections<FkChainSetNullRestrictChildTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainSetNullRestrictChild>(
      row,
      columns: columns?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainSetNullRestrictChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainSetNullRestrictChild?> updateById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<FkChainSetNullRestrictChildUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainSetNullRestrictChild>(
      id,
      columnValues: columnValues(FkChainSetNullRestrictChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullRestrictChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullRestrictChild>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<FkChainSetNullRestrictChildUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainSetNullRestrictChild>(
      columnValues: columnValues(FkChainSetNullRestrictChild.t.updateTable),
      where: where(FkChainSetNullRestrictChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainSetNullRestrictChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainSetNullRestrictChild>> delete(
    _i1.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainSetNullRestrictChild>(
      rows,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainSetNullRestrictChild].
  Future<FkChainSetNullRestrictChild> deleteRow(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainSetNullRestrictChild>(
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
  Future<List<FkChainSetNullRestrictChild>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable> where,
    _i1.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainSetNullRestrictChild>(
      where: where(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
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
    _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullRestrictChild] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullRestrictChildTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainSetNullRestrictChild>(
      where: where(FkChainSetNullRestrictChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainSetNullRestrictChildAttachRowRepository {
  const FkChainSetNullRestrictChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainSetNullRestrictChild] and [FkChainSetNullMiddle]
  /// by setting the [FkChainSetNullRestrictChild]'s foreign key `setNullMiddleId` to refer to the [FkChainSetNullMiddle].
  Future<void> setNullMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild fkChainSetNullRestrictChild,
    _i3.FkChainSetNullMiddle setNullMiddle, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullRestrictChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullRestrictChild.id');
    }
    if (setNullMiddle.id == null) {
      throw ArgumentError.notNull('setNullMiddle.id');
    }

    var $fkChainSetNullRestrictChild = fkChainSetNullRestrictChild.copyWith(
      setNullMiddleId: setNullMiddle.id,
    );
    await session.db.updateRow<FkChainSetNullRestrictChild>(
      $fkChainSetNullRestrictChild,
      columns: [FkChainSetNullRestrictChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}

class FkChainSetNullRestrictChildDetachRowRepository {
  const FkChainSetNullRestrictChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainSetNullRestrictChild] and the [FkChainSetNullMiddle] set in `setNullMiddle`
  /// by setting the [FkChainSetNullRestrictChild]'s foreign key `setNullMiddleId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> setNullMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullRestrictChild fkChainSetNullRestrictChild, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullRestrictChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullRestrictChild.id');
    }

    var $fkChainSetNullRestrictChild = fkChainSetNullRestrictChild.copyWith(
      setNullMiddleId: null,
    );
    await session.db.updateRow<FkChainSetNullRestrictChild>(
      $fkChainSetNullRestrictChild,
      columns: [FkChainSetNullRestrictChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}
