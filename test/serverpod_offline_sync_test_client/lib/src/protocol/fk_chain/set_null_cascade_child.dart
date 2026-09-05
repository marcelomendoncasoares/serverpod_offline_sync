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
import '../fk_chain/set_null_middle.dart' as _izcicqvj;

abstract class FkChainSetNullCascadeChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  FkChainSetNullCascadeChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.setNullMiddleId,
    this.setNullMiddle,
  });

  factory FkChainSetNullCascadeChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? setNullMiddleId,
    _izcicqvj.FkChainSetNullMiddle? setNullMiddle,
  }) = _FkChainSetNullCascadeChildImpl;

  factory FkChainSetNullCascadeChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullCascadeChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      setNullMiddleId: jsonSerialization['setNullMiddleId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['setNullMiddleId'],
            ),
      setNullMiddle: jsonSerialization['setNullMiddle'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_izcicqvj.FkChainSetNullMiddle>(
              jsonSerialization['setNullMiddle'],
            ),
    );
  }

  static final t = FkChainSetNullCascadeChildTable();

  static const db = FkChainSetNullCascadeChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _isc.UuidValue? setNullMiddleId;

  _izcicqvj.FkChainSetNullMiddle? setNullMiddle;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FkChainSetNullCascadeChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _isc.UuidValue? setNullMiddleId,
    _izcicqvj.FkChainSetNullMiddle? setNullMiddle,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
      if (setNullMiddle != null) 'setNullMiddle': setNullMiddle?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainSetNullCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
      if (setNullMiddle != null)
        'setNullMiddle': setNullMiddle?.toJsonForProtocol(),
    };
  }

  static FkChainSetNullCascadeChildInclude include({
    _izcicqvj.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    return FkChainSetNullCascadeChildInclude._(setNullMiddle: setNullMiddle);
  }

  static FkChainSetNullCascadeChildIncludeList includeList({
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    FkChainSetNullCascadeChildInclude? include,
  }) {
    return FkChainSetNullCascadeChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullCascadeChildImpl extends FkChainSetNullCascadeChild {
  _FkChainSetNullCascadeChildImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? setNullMiddleId,
    _izcicqvj.FkChainSetNullMiddle? setNullMiddle,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         setNullMiddleId: setNullMiddleId,
         setNullMiddle: setNullMiddle,
       );

  /// Returns a shallow copy of this [FkChainSetNullCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FkChainSetNullCascadeChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? setNullMiddleId = _Undefined,
    Object? setNullMiddle = _Undefined,
  }) {
    return FkChainSetNullCascadeChild(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      setNullMiddleId: setNullMiddleId is _isc.UuidValue?
          ? setNullMiddleId
          : this.setNullMiddleId,
      setNullMiddle: setNullMiddle is _izcicqvj.FkChainSetNullMiddle?
          ? setNullMiddle
          : this.setNullMiddle?.copyWith(),
    );
  }
}

class FkChainSetNullCascadeChildUpdateTable
    extends _isd.UpdateTable<FkChainSetNullCascadeChildTable> {
  FkChainSetNullCascadeChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> setNullMiddleId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.setNullMiddleId,
    value,
  );
}

class FkChainSetNullCascadeChildTable extends _isd.Table<_isc.UuidValue?> {
  FkChainSetNullCascadeChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_cascade_child') {
    updateTable = FkChainSetNullCascadeChildUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    setNullMiddleId = _isd.ColumnUuid(
      'setNullMiddleId',
      this,
    );
  }

  late final FkChainSetNullCascadeChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid setNullMiddleId;

  _izcicqvj.FkChainSetNullMiddleTable? _setNullMiddle;

  _izcicqvj.FkChainSetNullMiddleTable get setNullMiddle {
    if (_setNullMiddle != null) return _setNullMiddle!;
    _setNullMiddle = _isd.createRelationTable(
      relationFieldName: 'setNullMiddle',
      field: FkChainSetNullCascadeChild.t.setNullMiddleId,
      foreignField: _izcicqvj.FkChainSetNullMiddle.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _izcicqvj.FkChainSetNullMiddleTable(
            tableRelation: foreignTableRelation,
          ),
    );
    return _setNullMiddle!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
    setNullMiddleId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'setNullMiddle') {
      return setNullMiddle;
    }
    return null;
  }
}

class FkChainSetNullCascadeChildInclude extends _isd.IncludeObject {
  FkChainSetNullCascadeChildInclude._({
    _izcicqvj.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    _setNullMiddle = setNullMiddle;
  }

  _izcicqvj.FkChainSetNullMiddleInclude? _setNullMiddle;

  @override
  Map<String, _isd.Include?> get includes => {'setNullMiddle': _setNullMiddle};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullCascadeChild.t;
}

class FkChainSetNullCascadeChildIncludeList extends _isd.IncludeList {
  FkChainSetNullCascadeChildIncludeList._({
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullCascadeChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullCascadeChild.t;
}

class FkChainSetNullCascadeChildRepository {
  const FkChainSetNullCascadeChildRepository._();

  final attachRow = const FkChainSetNullCascadeChildAttachRowRepository._();

  final detachRow = const FkChainSetNullCascadeChildDetachRowRepository._();

  /// Returns a list of [FkChainSetNullCascadeChild]s matching the given query parameters.
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
  Future<List<FkChainSetNullCascadeChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainSetNullCascadeChild>(
      where: where?.call(FkChainSetNullCascadeChild.t),
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainSetNullCascadeChild] matching the given query parameters.
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
  Future<FkChainSetNullCascadeChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainSetNullCascadeChild>(
      where: where?.call(FkChainSetNullCascadeChild.t),
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainSetNullCascadeChild] by its [id] or null if no such row exists.
  Future<FkChainSetNullCascadeChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    FkChainSetNullCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainSetNullCascadeChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainSetNullCascadeChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainSetNullCascadeChild]s will have their `id` fields set.
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
  Future<List<FkChainSetNullCascadeChild>> insert(
    _isd.DatabaseSession session,
    List<FkChainSetNullCascadeChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainSetNullCascadeChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainSetNullCascadeChild] and returns the inserted row.
  ///
  /// The returned [FkChainSetNullCascadeChild] will have its `id` field set.
  Future<FkChainSetNullCascadeChild> insertRow(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainSetNullCascadeChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainSetNullCascadeChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainSetNullCascadeChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullCascadeChild>> upsert(
    _isd.DatabaseSession session,
    List<FkChainSetNullCascadeChild> rows, {
    required _isd.ColumnSelections<FkChainSetNullCascadeChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainSetNullCascadeChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainSetNullCascadeChild>(
      rows,
      conflictColumns: conflictColumns(FkChainSetNullCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainSetNullCascadeChild] and returns the resulting row.
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
  /// The returned [FkChainSetNullCascadeChild] will have its `id` field set.
  Future<FkChainSetNullCascadeChild?> upsertRow(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild row, {
    required _isd.ColumnSelections<FkChainSetNullCascadeChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainSetNullCascadeChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainSetNullCascadeChild>(
      row,
      conflictColumns: conflictColumns(FkChainSetNullCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainSetNullCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullCascadeChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullCascadeChild>> update(
    _isd.DatabaseSession session,
    List<FkChainSetNullCascadeChild> rows, {
    _isd.ColumnSelections<FkChainSetNullCascadeChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainSetNullCascadeChild>(
      rows,
      columns: columns?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainSetNullCascadeChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainSetNullCascadeChild> updateRow(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild row, {
    _isd.ColumnSelections<FkChainSetNullCascadeChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainSetNullCascadeChild>(
      row,
      columns: columns?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainSetNullCascadeChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainSetNullCascadeChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<FkChainSetNullCascadeChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainSetNullCascadeChild>(
      id,
      columnValues: columnValues(FkChainSetNullCascadeChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainSetNullCascadeChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainSetNullCascadeChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FkChainSetNullCascadeChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainSetNullCascadeChild>(
      columnValues: columnValues(FkChainSetNullCascadeChild.t.updateTable),
      where: where(FkChainSetNullCascadeChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainSetNullCascadeChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainSetNullCascadeChild>> delete(
    _isd.DatabaseSession session,
    List<FkChainSetNullCascadeChild> rows, {
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainSetNullCascadeChild>(
      rows,
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainSetNullCascadeChild].
  Future<FkChainSetNullCascadeChild> deleteRow(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainSetNullCascadeChild>(
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
  Future<List<FkChainSetNullCascadeChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable> where,
    _isd.OrderByBuilder<FkChainSetNullCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainSetNullCascadeChild>(
      where: where(FkChainSetNullCascadeChild.t),
      orderBy: orderBy?.call(FkChainSetNullCascadeChild.t),
      orderByList: orderByList?.call(FkChainSetNullCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullCascadeChild>(
      where: where?.call(FkChainSetNullCascadeChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullCascadeChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullCascadeChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainSetNullCascadeChild>(
      where: where(FkChainSetNullCascadeChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainSetNullCascadeChildAttachRowRepository {
  const FkChainSetNullCascadeChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainSetNullCascadeChild] and [FkChainSetNullMiddle]
  /// by setting the [FkChainSetNullCascadeChild]'s foreign key `setNullMiddleId` to refer to the [FkChainSetNullMiddle].
  Future<void> setNullMiddle(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild fkChainSetNullCascadeChild,
    _izcicqvj.FkChainSetNullMiddle setNullMiddle, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainSetNullCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullCascadeChild.id');
    }
    if (setNullMiddle.id == null) {
      throw ArgumentError.notNull('setNullMiddle.id');
    }

    var $fkChainSetNullCascadeChild = fkChainSetNullCascadeChild.copyWith(
      setNullMiddleId: setNullMiddle.id,
    );
    await session.db.updateRow<FkChainSetNullCascadeChild>(
      $fkChainSetNullCascadeChild,
      columns: [FkChainSetNullCascadeChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}

class FkChainSetNullCascadeChildDetachRowRepository {
  const FkChainSetNullCascadeChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainSetNullCascadeChild] and the [FkChainSetNullMiddle] set in `setNullMiddle`
  /// by setting the [FkChainSetNullCascadeChild]'s foreign key `setNullMiddleId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> setNullMiddle(
    _isd.DatabaseSession session,
    FkChainSetNullCascadeChild fkChainSetNullCascadeChild, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainSetNullCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainSetNullCascadeChild.id');
    }

    var $fkChainSetNullCascadeChild = fkChainSetNullCascadeChild.copyWith(
      setNullMiddleId: null,
    );
    await session.db.updateRow<FkChainSetNullCascadeChild>(
      $fkChainSetNullCascadeChild,
      columns: [FkChainSetNullCascadeChild.t.setNullMiddleId],
      transaction: transaction,
    );
  }
}
