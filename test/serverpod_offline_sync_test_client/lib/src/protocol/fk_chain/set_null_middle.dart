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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _imkb9kra;
import '../fk_chain/cascade_middle.dart' as _i2nw0ajk;

abstract class FkChainSetNullMiddle
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  FkChainSetNullMiddle._({
    this.id,
    this.scopeId,
    required this.name,
    this.cascadeMiddleId,
    this.cascadeMiddle,
  });

  factory FkChainSetNullMiddle({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? cascadeMiddleId,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
  }) = _FkChainSetNullMiddleImpl;

  factory FkChainSetNullMiddle.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullMiddle(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      cascadeMiddleId: jsonSerialization['cascadeMiddleId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['cascadeMiddleId'],
            ),
      cascadeMiddle: jsonSerialization['cascadeMiddle'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_i2nw0ajk.FkChainCascadeMiddle>(
              jsonSerialization['cascadeMiddle'],
            ),
    );
  }

  static final t = FkChainSetNullMiddleTable();

  static const db = FkChainSetNullMiddleRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _isc.UuidValue? cascadeMiddleId;

  _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullMiddle]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FkChainSetNullMiddle copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _isc.UuidValue? cascadeMiddleId,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cascadeMiddleId != null) 'cascadeMiddleId': cascadeMiddleId?.toJson(),
      if (cascadeMiddle != null) 'cascadeMiddle': cascadeMiddle?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainSetNullMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cascadeMiddleId != null) 'cascadeMiddleId': cascadeMiddleId?.toJson(),
      if (cascadeMiddle != null)
        'cascadeMiddle': cascadeMiddle?.toJsonForProtocol(),
    };
  }

  static FkChainSetNullMiddleInclude include({
    _i2nw0ajk.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    return FkChainSetNullMiddleInclude._(cascadeMiddle: cascadeMiddle);
  }

  static FkChainSetNullMiddleIncludeList includeList({
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullMiddleImpl extends FkChainSetNullMiddle {
  _FkChainSetNullMiddleImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? cascadeMiddleId,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         cascadeMiddleId: cascadeMiddleId,
         cascadeMiddle: cascadeMiddle,
       );

  /// Returns a shallow copy of this [FkChainSetNullMiddle]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FkChainSetNullMiddle copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? cascadeMiddleId = _Undefined,
    Object? cascadeMiddle = _Undefined,
  }) {
    return FkChainSetNullMiddle(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      cascadeMiddleId: cascadeMiddleId is _isc.UuidValue?
          ? cascadeMiddleId
          : this.cascadeMiddleId,
      cascadeMiddle: cascadeMiddle is _i2nw0ajk.FkChainCascadeMiddle?
          ? cascadeMiddle
          : this.cascadeMiddle?.copyWith(),
    );
  }
}

class FkChainSetNullMiddleUpdateTable
    extends _isd.UpdateTable<FkChainSetNullMiddleTable> {
  FkChainSetNullMiddleUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> cascadeMiddleId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.cascadeMiddleId,
    value,
  );
}

class FkChainSetNullMiddleTable extends _isd.Table<_isc.UuidValue?> {
  FkChainSetNullMiddleTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_middle') {
    updateTable = FkChainSetNullMiddleUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    cascadeMiddleId = _isd.ColumnUuid(
      'cascadeMiddleId',
      this,
    );
  }

  late final FkChainSetNullMiddleUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid cascadeMiddleId;

  _i2nw0ajk.FkChainCascadeMiddleTable? _cascadeMiddle;

  _i2nw0ajk.FkChainCascadeMiddleTable get cascadeMiddle {
    if (_cascadeMiddle != null) return _cascadeMiddle!;
    _cascadeMiddle = _isd.createRelationTable(
      relationFieldName: 'cascadeMiddle',
      field: FkChainSetNullMiddle.t.cascadeMiddleId,
      foreignField: _i2nw0ajk.FkChainCascadeMiddle.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2nw0ajk.FkChainCascadeMiddleTable(
            tableRelation: foreignTableRelation,
          ),
    );
    return _cascadeMiddle!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
    cascadeMiddleId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'cascadeMiddle') {
      return cascadeMiddle;
    }
    return null;
  }
}

class FkChainSetNullMiddleInclude extends _isd.IncludeObject {
  FkChainSetNullMiddleInclude._({
    _i2nw0ajk.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    _cascadeMiddle = cascadeMiddle;
  }

  _i2nw0ajk.FkChainCascadeMiddleInclude? _cascadeMiddle;

  @override
  Map<String, _isd.Include?> get includes => {'cascadeMiddle': _cascadeMiddle};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullMiddle.t;
}

class FkChainSetNullMiddleIncludeList extends _isd.IncludeList {
  FkChainSetNullMiddleIncludeList._({
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullMiddle.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullMiddle.t;
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    FkChainSetNullMiddleInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    required _isd.ColumnSelections<FkChainSetNullMiddleTable> conflictColumns,
    _isd.ColumnSelections<FkChainSetNullMiddleTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle row, {
    required _isd.ColumnSelections<FkChainSetNullMiddleTable> conflictColumns,
    _isd.ColumnSelections<FkChainSetNullMiddleTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _isd.ColumnSelections<FkChainSetNullMiddleTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _isd.ColumnSelections<FkChainSetNullMiddleTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<FkChainSetNullMiddleUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FkChainSetNullMiddleUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullMiddle> rows, {
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    _isd.OrderByBuilder<FkChainSetNullMiddleTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullMiddleTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullMiddle>(
      where: where?.call(FkChainSetNullMiddle.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullMiddle] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullMiddleTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle fkChainSetNullMiddle,
    _i2nw0ajk.FkChainCascadeMiddle cascadeMiddle, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullMiddle fkChainSetNullMiddle, {
    _isd.Transaction? transaction,
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
