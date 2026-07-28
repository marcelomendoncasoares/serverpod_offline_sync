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
import '../fk_chain/cascade_middle.dart' as _i2;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _i3;

abstract class FkChainSetNullMiddle
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  FkChainSetNullMiddle._({
    this.id,
    this.scopeId,
    required this.name,
    this.cascadeMiddle,
    this.cascadeMiddleId,
  });

  factory FkChainSetNullMiddle({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainCascadeMiddle? cascadeMiddle,
    _i1.UuidValue? cascadeMiddleId,
  }) = _FkChainSetNullMiddleImpl;

  factory FkChainSetNullMiddle.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullMiddle(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      cascadeMiddle: jsonSerialization['cascadeMiddle'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.FkChainCascadeMiddle>(
              jsonSerialization['cascadeMiddle'],
            ),
      cascadeMiddleId: jsonSerialization['cascadeMiddleId'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(
              jsonSerialization['cascadeMiddleId'],
            ),
    );
  }

  static final t = FkChainSetNullMiddleTable();

  static const db = FkChainSetNullMiddleRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i2.FkChainCascadeMiddle? cascadeMiddle;

  _i1.UuidValue? cascadeMiddleId;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullMiddle]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FkChainSetNullMiddle copyWith({
    _i1.UuidValue? id,
    int? scopeId,
    String? name,
    _i2.FkChainCascadeMiddle? cascadeMiddle,
    _i1.UuidValue? cascadeMiddleId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cascadeMiddle != null) 'cascadeMiddle': cascadeMiddle?.toJson(),
      if (cascadeMiddleId != null) 'cascadeMiddleId': cascadeMiddleId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainSetNullMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cascadeMiddle != null)
        'cascadeMiddle': cascadeMiddle?.toJsonForProtocol(),
      if (cascadeMiddleId != null) 'cascadeMiddleId': cascadeMiddleId?.toJson(),
    };
  }

  static FkChainSetNullMiddleInclude include({
    _i2.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    return FkChainSetNullMiddleInclude._(cascadeMiddle: cascadeMiddle);
  }

  static FkChainSetNullMiddleIncludeList includeList({
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    FkChainSetNullMiddleInclude? include,
  }) {
    return FkChainSetNullMiddleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullMiddleImpl extends FkChainSetNullMiddle {
  _FkChainSetNullMiddleImpl({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainCascadeMiddle? cascadeMiddle,
    _i1.UuidValue? cascadeMiddleId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         cascadeMiddle: cascadeMiddle,
         cascadeMiddleId: cascadeMiddleId,
       );

  /// Returns a shallow copy of this [FkChainSetNullMiddle]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FkChainSetNullMiddle copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? cascadeMiddle = _Undefined,
    Object? cascadeMiddleId = _Undefined,
  }) {
    return FkChainSetNullMiddle(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      cascadeMiddle: cascadeMiddle is _i2.FkChainCascadeMiddle?
          ? cascadeMiddle
          : this.cascadeMiddle?.copyWith(),
      cascadeMiddleId: cascadeMiddleId is _i1.UuidValue?
          ? cascadeMiddleId
          : this.cascadeMiddleId,
    );
  }
}

class FkChainSetNullMiddleUpdateTable
    extends _i1.UpdateTable<FkChainSetNullMiddleTable> {
  FkChainSetNullMiddleUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> cascadeMiddleId(
    _i1.UuidValue? value,
  ) => _i1.ColumnValue(
    table.cascadeMiddleId,
    value,
  );
}

class FkChainSetNullMiddleTable extends _i1.Table<_i1.UuidValue?> {
  FkChainSetNullMiddleTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_middle') {
    updateTable = FkChainSetNullMiddleUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    cascadeMiddleId = _i1.ColumnUuid(
      'cascadeMiddleId',
      this,
    );
  }

  late final FkChainSetNullMiddleUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i2.FkChainCascadeMiddleTable? _cascadeMiddle;

  late final _i1.ColumnUuid cascadeMiddleId;

  _i2.FkChainCascadeMiddleTable get cascadeMiddle {
    if (_cascadeMiddle != null) return _cascadeMiddle!;
    _cascadeMiddle = _i1.createRelationTable(
      relationFieldName: 'cascadeMiddle',
      field: FkChainSetNullMiddle.t.cascadeMiddleId,
      foreignField: _i2.FkChainCascadeMiddle.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.FkChainCascadeMiddleTable(tableRelation: foreignTableRelation),
    );
    return _cascadeMiddle!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    cascadeMiddleId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'cascadeMiddle') {
      return cascadeMiddle;
    }
    return null;
  }
}

class FkChainSetNullMiddleInclude extends _i1.IncludeObject {
  FkChainSetNullMiddleInclude._({
    _i2.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    _cascadeMiddle = cascadeMiddle;
  }

  _i2.FkChainCascadeMiddleInclude? _cascadeMiddle;

  @override
  Map<String, _i1.Include?> get includes => {'cascadeMiddle': _cascadeMiddle};

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainSetNullMiddle.t;
}

class FkChainSetNullMiddleIncludeList extends _i1.IncludeList {
  FkChainSetNullMiddleIncludeList._({
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullMiddle.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainSetNullMiddle.t;
}

class FkChainSetNullMiddleRepository {
  const FkChainSetNullMiddleRepository._();

  final attachRow = const FkChainSetNullMiddleAttachRowRepository._();

  final detachRow = const FkChainSetNullMiddleDetachRowRepository._();

  /// Returns a list of [FkChainSetNullMiddle]s matching the given query parameters.
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
  Future<List<FkChainSetNullMiddle>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainSetNullMiddle>(
      where: where?.call(FkChainSetNullMiddle.t),
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainSetNullMiddle] matching the given query parameters.
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
  Future<FkChainSetNullMiddle?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainSetNullMiddle>(
      where: where?.call(FkChainSetNullMiddle.t),
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainSetNullMiddle] by its [id] or null if no such row exists.
  Future<FkChainSetNullMiddle?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainSetNullMiddle>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainSetNullMiddle]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainSetNullMiddle]s will have their `id` fields set.
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
  Future<List<FkChainSetNullMiddle>> insert(
    _i1.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainSetNullMiddle>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainSetNullMiddle] and returns the inserted row.
  ///
  /// The returned [FkChainSetNullMiddle] will have its `id` field set.
  Future<FkChainSetNullMiddle> insertRow(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainSetNullMiddle>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainSetNullMiddle]s in the list and returns the resulting rows.
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
  /// The returned [FkChainSetNullMiddle]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullMiddle>> upsert(
    _i1.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    required _i1.ColumnSelections<FkChainSetNullMiddleTable> conflictColumns,
    _i1.ColumnSelections<FkChainSetNullMiddleTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainSetNullMiddle>(
      rows,
      conflictColumns: conflictColumns(FkChainSetNullMiddle.t),
      updateColumns: updateColumns?.call(FkChainSetNullMiddle.t),
      updateWhere: updateWhere?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainSetNullMiddle] and returns the resulting row.
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
  /// The returned [FkChainSetNullMiddle] will have its `id` field set.
  Future<FkChainSetNullMiddle?> upsertRow(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle row, {
    required _i1.ColumnSelections<FkChainSetNullMiddleTable> conflictColumns,
    _i1.ColumnSelections<FkChainSetNullMiddleTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainSetNullMiddle>(
      row,
      conflictColumns: conflictColumns(FkChainSetNullMiddle.t),
      updateColumns: updateColumns?.call(FkChainSetNullMiddle.t),
      updateWhere: updateWhere?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullMiddle]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullMiddle>> update(
    _i1.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _i1.ColumnSelections<FkChainSetNullMiddleTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainSetNullMiddle>(
      rows,
      columns: columns?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainSetNullMiddle]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainSetNullMiddle> updateRow(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _i1.ColumnSelections<FkChainSetNullMiddleTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainSetNullMiddle>(
      row,
      columns: columns?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainSetNullMiddle] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainSetNullMiddle?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<FkChainSetNullMiddleUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainSetNullMiddle>(
      id,
      columnValues: columnValues(FkChainSetNullMiddle.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullMiddle]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullMiddle>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<FkChainSetNullMiddleUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainSetNullMiddle>(
      columnValues: columnValues(FkChainSetNullMiddle.t.updateTable),
      where: where(FkChainSetNullMiddle.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainSetNullMiddle]s in the list and returns the deleted rows.
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
  Future<List<FkChainSetNullMiddle>> delete(
    _i1.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainSetNullMiddle>(
      rows,
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainSetNullMiddle].
  Future<FkChainSetNullMiddle> deleteRow(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainSetNullMiddle>(
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
  Future<List<FkChainSetNullMiddle>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    _i1.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _i1.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainSetNullMiddle>(
      where: where(FkChainSetNullMiddle.t),
      orderBy: orderBy?.call(FkChainSetNullMiddle.t),
      orderByList: orderByList?.call(FkChainSetNullMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullMiddle>(
      where: where?.call(FkChainSetNullMiddle.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullMiddle] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainSetNullMiddle>(
      where: where(FkChainSetNullMiddle.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainSetNullMiddleAttachRowRepository {
  const FkChainSetNullMiddleAttachRowRepository._();

  /// Creates a relation between the given [FkChainSetNullMiddle] and [FkChainCascadeMiddle]
  /// by setting the [FkChainSetNullMiddle]'s foreign key `cascadeMiddleId` to refer to the [FkChainCascadeMiddle].
  Future<void> cascadeMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle fkChainSetNullMiddle,
    _i2.FkChainCascadeMiddle cascadeMiddle, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullMiddle.id == null) {
      throw ArgumentError.notNull('fkChainSetNullMiddle.id');
    }
    if (cascadeMiddle.id == null) {
      throw ArgumentError.notNull('cascadeMiddle.id');
    }

    var $fkChainSetNullMiddle = fkChainSetNullMiddle.copyWith(
      cascadeMiddleId: cascadeMiddle.id,
    );
    await session.db.updateRow<FkChainSetNullMiddle>(
      $fkChainSetNullMiddle,
      columns: [FkChainSetNullMiddle.t.cascadeMiddleId],
      transaction: transaction,
    );
  }
}

class FkChainSetNullMiddleDetachRowRepository {
  const FkChainSetNullMiddleDetachRowRepository._();

  /// Detaches the relation between this [FkChainSetNullMiddle] and the [FkChainCascadeMiddle] set in `cascadeMiddle`
  /// by setting the [FkChainSetNullMiddle]'s foreign key `cascadeMiddleId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> cascadeMiddle(
    _i1.DatabaseSession session,
    FkChainSetNullMiddle fkChainSetNullMiddle, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainSetNullMiddle.id == null) {
      throw ArgumentError.notNull('fkChainSetNullMiddle.id');
    }

    var $fkChainSetNullMiddle = fkChainSetNullMiddle.copyWith(
      cascadeMiddleId: null,
    );
    await session.db.updateRow<FkChainSetNullMiddle>(
      $fkChainSetNullMiddle,
      columns: [FkChainSetNullMiddle.t.cascadeMiddleId],
      transaction: transaction,
    );
  }
}
