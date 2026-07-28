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
import '../fk_chain/set_null_middle.dart' as _i2;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _i3;

abstract class FkChainSetNullSetNullChild
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  FkChainSetNullSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.setNullMiddle,
    this.setNullMiddleId,
  });

  factory FkChainSetNullSetNullChild({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainSetNullMiddle? setNullMiddle,
    _i1.UuidValue? setNullMiddleId,
  }) = _FkChainSetNullSetNullChildImpl;

  factory FkChainSetNullSetNullChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      setNullMiddle: jsonSerialization['setNullMiddle'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.FkChainSetNullMiddle>(
              jsonSerialization['setNullMiddle'],
            ),
      setNullMiddleId: jsonSerialization['setNullMiddleId'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(
              jsonSerialization['setNullMiddleId'],
            ),
    );
  }

  static final t = FkChainSetNullSetNullChildTable();

  static const db = FkChainSetNullSetNullChildRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i2.FkChainSetNullMiddle? setNullMiddle;

  _i1.UuidValue? setNullMiddleId;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FkChainSetNullSetNullChild copyWith({
    _i1.UuidValue? id,
    int? scopeId,
    String? name,
    _i2.FkChainSetNullMiddle? setNullMiddle,
    _i1.UuidValue? setNullMiddleId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddle != null) 'setNullMiddle': setNullMiddle?.toJson(),
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainSetNullSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddle != null)
        'setNullMiddle': setNullMiddle?.toJsonForProtocol(),
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
    };
  }

  static FkChainSetNullSetNullChildInclude include({
    _i2.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    return FkChainSetNullSetNullChildInclude._(setNullMiddle: setNullMiddle);
  }

  static FkChainSetNullSetNullChildIncludeList includeList({
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    FkChainSetNullSetNullChildInclude? include,
  }) {
    return FkChainSetNullSetNullChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullSetNullChildImpl extends FkChainSetNullSetNullChild {
  _FkChainSetNullSetNullChildImpl({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainSetNullMiddle? setNullMiddle,
    _i1.UuidValue? setNullMiddleId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         setNullMiddle: setNullMiddle,
         setNullMiddleId: setNullMiddleId,
       );

  /// Returns a shallow copy of this [FkChainSetNullSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FkChainSetNullSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? setNullMiddle = _Undefined,
    Object? setNullMiddleId = _Undefined,
  }) {
    return FkChainSetNullSetNullChild(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      setNullMiddle: setNullMiddle is _i2.FkChainSetNullMiddle?
          ? setNullMiddle
          : this.setNullMiddle?.copyWith(),
      setNullMiddleId: setNullMiddleId is _i1.UuidValue?
          ? setNullMiddleId
          : this.setNullMiddleId,
    );
  }
}

class FkChainSetNullSetNullChildUpdateTable
    extends _i1.UpdateTable<FkChainSetNullSetNullChildTable> {
  FkChainSetNullSetNullChildUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> setNullMiddleId(
    _i1.UuidValue? value,
  ) => _i1.ColumnValue(
    table.setNullMiddleId,
    value,
  );
}

class FkChainSetNullSetNullChildTable extends _i1.Table<_i1.UuidValue?> {
  FkChainSetNullSetNullChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_set_null_child') {
    updateTable = FkChainSetNullSetNullChildUpdateTable(this);
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

  late final FkChainSetNullSetNullChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i2.FkChainSetNullMiddleTable? _setNullMiddle;

  late final _i1.ColumnUuid setNullMiddleId;

  _i2.FkChainSetNullMiddleTable get setNullMiddle {
    if (_setNullMiddle != null) return _setNullMiddle!;
    _setNullMiddle = _i1.createRelationTable(
      relationFieldName: 'setNullMiddle',
      field: FkChainSetNullSetNullChild.t.setNullMiddleId,
      foreignField: _i2.FkChainSetNullMiddle.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.FkChainSetNullMiddleTable(tableRelation: foreignTableRelation),
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

class FkChainSetNullSetNullChildInclude extends _i1.IncludeObject {
  FkChainSetNullSetNullChildInclude._({
    _i2.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    _setNullMiddle = setNullMiddle;
  }

  _i2.FkChainSetNullMiddleInclude? _setNullMiddle;

  @override
  Map<String, _i1.Include?> get includes => {'setNullMiddle': _setNullMiddle};

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainSetNullSetNullChild.t;
}

class FkChainSetNullSetNullChildIncludeList extends _i1.IncludeList {
  FkChainSetNullSetNullChildIncludeList._({
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullSetNullChild.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainSetNullSetNullChild.t;
}

class FkChainSetNullSetNullChildRepository {
  const FkChainSetNullSetNullChildRepository._();

  final attachRow = const FkChainSetNullSetNullChildAttachRowRepository._();

  final detachRow = const FkChainSetNullSetNullChildDetachRowRepository._();

  /// Returns a list of [FkChainSetNullSetNullChild]s matching the given query parameters.
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
  Future<List<FkChainSetNullSetNullChild>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainSetNullSetNullChild>(
      where: where?.call(FkChainSetNullSetNullChild.t),
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainSetNullSetNullChild] matching the given query parameters.
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
  Future<FkChainSetNullSetNullChild?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? where,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainSetNullSetNullChild>(
      where: where?.call(FkChainSetNullSetNullChild.t),
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainSetNullSetNullChild] by its [id] or null if no such row exists.
  Future<FkChainSetNullSetNullChild?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    FkChainSetNullSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainSetNullSetNullChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainSetNullSetNullChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainSetNullSetNullChild]s will have their `id` fields set.
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
  Future<List<FkChainSetNullSetNullChild>> insert(
    _i1.DatabaseSession session,
    List<FkChainSetNullSetNullChild> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainSetNullSetNullChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainSetNullSetNullChild] and returns the inserted row.
  ///
  /// The returned [FkChainSetNullSetNullChild] will have its `id` field set.
  Future<FkChainSetNullSetNullChild> insertRow(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainSetNullSetNullChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainSetNullSetNullChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainSetNullSetNullChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullSetNullChild>> upsert(
    _i1.DatabaseSession session,
    List<FkChainSetNullSetNullChild> rows, {
    required _i1.ColumnSelections<FkChainSetNullSetNullChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainSetNullSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainSetNullSetNullChild>(
      rows,
      conflictColumns: conflictColumns(FkChainSetNullSetNullChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullSetNullChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainSetNullSetNullChild] and returns the resulting row.
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
  /// The returned [FkChainSetNullSetNullChild] will have its `id` field set.
  Future<FkChainSetNullSetNullChild?> upsertRow(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild row, {
    required _i1.ColumnSelections<FkChainSetNullSetNullChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainSetNullSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainSetNullSetNullChild>(
      row,
      conflictColumns: conflictColumns(FkChainSetNullSetNullChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullSetNullChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullSetNullChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullSetNullChild>> update(
    _i1.DatabaseSession session,
    List<FkChainSetNullSetNullChild> rows, {
    _i1.ColumnSelections<FkChainSetNullSetNullChildTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainSetNullSetNullChild>(
      rows,
      columns: columns?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainSetNullSetNullChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainSetNullSetNullChild> updateRow(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild row, {
    _i1.ColumnSelections<FkChainSetNullSetNullChildTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainSetNullSetNullChild>(
      row,
      columns: columns?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainSetNullSetNullChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainSetNullSetNullChild?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<FkChainSetNullSetNullChildUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainSetNullSetNullChild>(
      id,
      columnValues: columnValues(FkChainSetNullSetNullChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullSetNullChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullSetNullChild>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<FkChainSetNullSetNullChildUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainSetNullSetNullChild>(
      columnValues: columnValues(FkChainSetNullSetNullChild.t.updateTable),
      where: where(FkChainSetNullSetNullChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainSetNullSetNullChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainSetNullSetNullChild>> delete(
    _i1.DatabaseSession session,
    List<FkChainSetNullSetNullChild> rows, {
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainSetNullSetNullChild>(
      rows,
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainSetNullSetNullChild].
  Future<FkChainSetNullSetNullChild> deleteRow(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainSetNullSetNullChild>(
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
  Future<List<FkChainSetNullSetNullChild>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable> where,
    _i1.OrderByBuilder<FkChainSetNullSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainSetNullSetNullChild>(
      where: where(FkChainSetNullSetNullChild.t),
      orderBy: orderBy?.call(FkChainSetNullSetNullChild.t),
      orderByList: orderByList?.call(FkChainSetNullSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullSetNullChild>(
      where: where?.call(FkChainSetNullSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullSetNullChildTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainSetNullSetNullChild>(
      where: where(FkChainSetNullSetNullChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainSetNullSetNullChildAttachRowRepository {
  const FkChainSetNullSetNullChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainSetNullSetNullChild] and [FkChainSetNullMiddle]
  /// by setting the [FkChainSetNullSetNullChild]'s foreign key `setNullMiddleId` to refer to the [FkChainSetNullMiddle].
  Future<void> setNullMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild fkChainSetNullSetNullChild,
    _i2.FkChainSetNullMiddle setNullMiddle, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullSetNullChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullSetNullChild.id');
    }
    if (setNullMiddle.id == null) {
      throw ArgumentError.notNull('setNullMiddle.id');
    }

    var $fkChainSetNullSetNullChild = fkChainSetNullSetNullChild.copyWith(
      setNullMiddleId: setNullMiddle.id,
    );
    await session.db.updateRow<FkChainSetNullSetNullChild>(
      $fkChainSetNullSetNullChild,
      columns: [FkChainSetNullSetNullChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}

class FkChainSetNullSetNullChildDetachRowRepository {
  const FkChainSetNullSetNullChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainSetNullSetNullChild] and the [FkChainSetNullMiddle] set in `setNullMiddle`
  /// by setting the [FkChainSetNullSetNullChild]'s foreign key `setNullMiddleId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> setNullMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullSetNullChild fkChainSetNullSetNullChild, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullSetNullChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullSetNullChild.id');
    }

    var $fkChainSetNullSetNullChild = fkChainSetNullSetNullChild.copyWith(
      setNullMiddleId: null,
    );
    await session.db.updateRow<FkChainSetNullSetNullChild>(
      $fkChainSetNullSetNullChild,
      columns: [FkChainSetNullSetNullChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}
