/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, no_leading_underscores_for_library_prefixes
// ignore_for_file: unnecessary_null_comparison

import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _imkb9kra;
import '../fk_chain/set_null_middle.dart' as _izcicqvj;

abstract class FkChainSetNullRestrictChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  FkChainSetNullRestrictChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.setNullMiddleId,
    this.setNullMiddle,
  });

  factory FkChainSetNullRestrictChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? setNullMiddleId,
    _izcicqvj.FkChainSetNullMiddle? setNullMiddle,
  }) = _FkChainSetNullRestrictChildImpl;

  factory FkChainSetNullRestrictChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainSetNullRestrictChild(
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

  static final t = FkChainSetNullRestrictChildTable();

  static const db = FkChainSetNullRestrictChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _isc.UuidValue? setNullMiddleId;

  _izcicqvj.FkChainSetNullMiddle? setNullMiddle;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainSetNullRestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FkChainSetNullRestrictChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _isc.UuidValue? setNullMiddleId,
    _izcicqvj.FkChainSetNullMiddle? setNullMiddle,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainSetNullRestrictChild',
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
      '__className__': 'FkChainSetNullRestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (setNullMiddleId != null) 'setNullMiddleId': setNullMiddleId?.toJson(),
      if (setNullMiddle != null)
        'setNullMiddle': setNullMiddle?.toJsonForProtocol(),
    };
  }

  static FkChainSetNullRestrictChildInclude include({
    _izcicqvj.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    return FkChainSetNullRestrictChildInclude._(setNullMiddle: setNullMiddle);
  }

  static FkChainSetNullRestrictChildIncludeList includeList({
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    FkChainSetNullRestrictChildInclude? include,
  }) {
    return FkChainSetNullRestrictChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainSetNullRestrictChildImpl extends FkChainSetNullRestrictChild {
  _FkChainSetNullRestrictChildImpl({
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

  /// Returns a shallow copy of this [FkChainSetNullRestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FkChainSetNullRestrictChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? setNullMiddleId = _Undefined,
    Object? setNullMiddle = _Undefined,
  }) {
    return FkChainSetNullRestrictChild(
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

class FkChainSetNullRestrictChildUpdateTable
    extends _isd.UpdateTable<FkChainSetNullRestrictChildTable> {
  FkChainSetNullRestrictChildUpdateTable(super.table);

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

class FkChainSetNullRestrictChildTable extends _isd.Table<_isc.UuidValue?> {
  FkChainSetNullRestrictChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_set_null_restrict_child') {
    updateTable = FkChainSetNullRestrictChildUpdateTable(this);
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

  late final FkChainSetNullRestrictChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid setNullMiddleId;

  _izcicqvj.FkChainSetNullMiddleTable? _setNullMiddle;

  _izcicqvj.FkChainSetNullMiddleTable get setNullMiddle {
    if (_setNullMiddle != null) return _setNullMiddle!;
    _setNullMiddle = _isd.createRelationTable(
      relationFieldName: 'setNullMiddle',
      field: FkChainSetNullRestrictChild.t.setNullMiddleId,
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

class FkChainSetNullRestrictChildInclude extends _isd.IncludeObject {
  FkChainSetNullRestrictChildInclude._({
    _izcicqvj.FkChainSetNullMiddleInclude? setNullMiddle,
  }) {
    _setNullMiddle = setNullMiddle;
  }

  _izcicqvj.FkChainSetNullMiddleInclude? _setNullMiddle;

  @override
  Map<String, _isd.Include?> get includes => {'setNullMiddle': _setNullMiddle};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullRestrictChild.t;
}

class FkChainSetNullRestrictChildIncludeList extends _isd.IncludeList {
  FkChainSetNullRestrictChildIncludeList._({
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainSetNullRestrictChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainSetNullRestrictChild.t;
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainSetNullRestrictChild] by its [id] or null if no such row exists.
  Future<FkChainSetNullRestrictChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    FkChainSetNullRestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    required _isd.ColumnSelections<FkChainSetNullRestrictChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainSetNullRestrictChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    required _isd.ColumnSelections<FkChainSetNullRestrictChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainSetNullRestrictChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _isd.ColumnSelections<FkChainSetNullRestrictChildTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _isd.ColumnSelections<FkChainSetNullRestrictChildTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<FkChainSetNullRestrictChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FkChainSetNullRestrictChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>
    where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainSetNullRestrictChild>(
      columnValues: columnValues(FkChainSetNullRestrictChild.t.updateTable),
      where: where(FkChainSetNullRestrictChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
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
    _isd.DatabaseSession session,
    List<FkChainSetNullRestrictChild> rows, {
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainSetNullRestrictChild>(
      rows,
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainSetNullRestrictChild].
  Future<FkChainSetNullRestrictChild> deleteRow(
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>
    where,
    _isd.OrderByBuilder<FkChainSetNullRestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainSetNullRestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainSetNullRestrictChild>(
      where: where(FkChainSetNullRestrictChild.t),
      orderBy: orderBy?.call(FkChainSetNullRestrictChild.t),
      orderByList: orderByList?.call(FkChainSetNullRestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FkChainSetNullRestrictChild>(
      where: where?.call(FkChainSetNullRestrictChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainSetNullRestrictChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainSetNullRestrictChildTable>
    where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
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
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild fkChainSetNullRestrictChild,
    _izcicqvj.FkChainSetNullMiddle setNullMiddle, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    FkChainSetNullRestrictChild fkChainSetNullRestrictChild, {
    _isd.Transaction? transaction,
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
