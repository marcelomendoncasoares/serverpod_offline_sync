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
import '../fk_chain/restrict_blocker.dart' as _i2;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _i3;

abstract class FkChainMiddleCascadeChild
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  FkChainMiddleCascadeChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.restrictBlocker,
    this.restrictBlockerId,
  });

  factory FkChainMiddleCascadeChild({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainRestrictBlocker? restrictBlocker,
    _i1.UuidValue? restrictBlockerId,
  }) = _FkChainMiddleCascadeChildImpl;

  factory FkChainMiddleCascadeChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainMiddleCascadeChild(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      restrictBlocker: jsonSerialization['restrictBlocker'] == null
          ? null
          : _i3.Protocol().deserialize<_i2.FkChainRestrictBlocker>(
              jsonSerialization['restrictBlocker'],
            ),
      restrictBlockerId: jsonSerialization['restrictBlockerId'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(
              jsonSerialization['restrictBlockerId'],
            ),
    );
  }

  static final t = FkChainMiddleCascadeChildTable();

  static const db = FkChainMiddleCascadeChildRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i2.FkChainRestrictBlocker? restrictBlocker;

  _i1.UuidValue? restrictBlockerId;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainMiddleCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FkChainMiddleCascadeChild copyWith({
    _i1.UuidValue? id,
    int? scopeId,
    String? name,
    _i2.FkChainRestrictBlocker? restrictBlocker,
    _i1.UuidValue? restrictBlockerId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainMiddleCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlocker != null) 'restrictBlocker': restrictBlocker?.toJson(),
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainMiddleCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlocker != null)
        'restrictBlocker': restrictBlocker?.toJsonForProtocol(),
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
    };
  }

  static FkChainMiddleCascadeChildInclude include({
    _i2.FkChainRestrictBlockerInclude? restrictBlocker,
  }) {
    return FkChainMiddleCascadeChildInclude._(restrictBlocker: restrictBlocker);
  }

  static FkChainMiddleCascadeChildIncludeList includeList({
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    FkChainMiddleCascadeChildInclude? include,
  }) {
    return FkChainMiddleCascadeChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainMiddleCascadeChildImpl extends FkChainMiddleCascadeChild {
  _FkChainMiddleCascadeChildImpl({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i2.FkChainRestrictBlocker? restrictBlocker,
    _i1.UuidValue? restrictBlockerId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         restrictBlocker: restrictBlocker,
         restrictBlockerId: restrictBlockerId,
       );

  /// Returns a shallow copy of this [FkChainMiddleCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FkChainMiddleCascadeChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? restrictBlocker = _Undefined,
    Object? restrictBlockerId = _Undefined,
  }) {
    return FkChainMiddleCascadeChild(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      restrictBlocker: restrictBlocker is _i2.FkChainRestrictBlocker?
          ? restrictBlocker
          : this.restrictBlocker?.copyWith(),
      restrictBlockerId: restrictBlockerId is _i1.UuidValue?
          ? restrictBlockerId
          : this.restrictBlockerId,
    );
  }
}

class FkChainMiddleCascadeChildUpdateTable
    extends _i1.UpdateTable<FkChainMiddleCascadeChildTable> {
  FkChainMiddleCascadeChildUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> restrictBlockerId(
    _i1.UuidValue? value,
  ) => _i1.ColumnValue(
    table.restrictBlockerId,
    value,
  );
}

class FkChainMiddleCascadeChildTable extends _i1.Table<_i1.UuidValue?> {
  FkChainMiddleCascadeChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_middle_cascade_child') {
    updateTable = FkChainMiddleCascadeChildUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    restrictBlockerId = _i1.ColumnUuid(
      'restrictBlockerId',
      this,
    );
  }

  late final FkChainMiddleCascadeChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i2.FkChainRestrictBlockerTable? _restrictBlocker;

  late final _i1.ColumnUuid restrictBlockerId;

  _i2.FkChainRestrictBlockerTable get restrictBlocker {
    if (_restrictBlocker != null) return _restrictBlocker!;
    _restrictBlocker = _i1.createRelationTable(
      relationFieldName: 'restrictBlocker',
      field: FkChainMiddleCascadeChild.t.restrictBlockerId,
      foreignField: _i2.FkChainRestrictBlocker.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.FkChainRestrictBlockerTable(tableRelation: foreignTableRelation),
    );
    return _restrictBlocker!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    restrictBlockerId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'restrictBlocker') {
      return restrictBlocker;
    }
    return null;
  }
}

class FkChainMiddleCascadeChildInclude extends _i1.IncludeObject {
  FkChainMiddleCascadeChildInclude._({
    _i2.FkChainRestrictBlockerInclude? restrictBlocker,
  }) {
    _restrictBlocker = restrictBlocker;
  }

  _i2.FkChainRestrictBlockerInclude? _restrictBlocker;

  @override
  Map<String, _i1.Include?> get includes => {
    'restrictBlocker': _restrictBlocker,
  };

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainMiddleCascadeChild.t;
}

class FkChainMiddleCascadeChildIncludeList extends _i1.IncludeList {
  FkChainMiddleCascadeChildIncludeList._({
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainMiddleCascadeChild.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => FkChainMiddleCascadeChild.t;
}

class FkChainMiddleCascadeChildRepository {
  const FkChainMiddleCascadeChildRepository._();

  final attachRow = const FkChainMiddleCascadeChildAttachRowRepository._();

  final detachRow = const FkChainMiddleCascadeChildDetachRowRepository._();

  /// Returns a list of [FkChainMiddleCascadeChild]s matching the given query parameters.
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
  Future<List<FkChainMiddleCascadeChild>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
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

  /// Returns the first matching [FkChainMiddleCascadeChild] matching the given query parameters.
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
  Future<FkChainMiddleCascadeChild?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? offset,
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _i1.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainMiddleCascadeChild] by its [id] or null if no such row exists.
  Future<FkChainMiddleCascadeChild?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainMiddleCascadeChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainMiddleCascadeChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainMiddleCascadeChild]s will have their `id` fields set.
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
  Future<List<FkChainMiddleCascadeChild>> insert(
    _i1.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainMiddleCascadeChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainMiddleCascadeChild] and returns the inserted row.
  ///
  /// The returned [FkChainMiddleCascadeChild] will have its `id` field set.
  Future<FkChainMiddleCascadeChild> insertRow(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainMiddleCascadeChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainMiddleCascadeChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainMiddleCascadeChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> upsert(
    _i1.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    required _i1.ColumnSelections<FkChainMiddleCascadeChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainMiddleCascadeChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainMiddleCascadeChild>(
      rows,
      conflictColumns: conflictColumns(FkChainMiddleCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainMiddleCascadeChild] and returns the resulting row.
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
  /// The returned [FkChainMiddleCascadeChild] will have its `id` field set.
  Future<FkChainMiddleCascadeChild?> upsertRow(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    required _i1.ColumnSelections<FkChainMiddleCascadeChildTable>
    conflictColumns,
    _i1.ColumnSelections<FkChainMiddleCascadeChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainMiddleCascadeChild>(
      row,
      conflictColumns: conflictColumns(FkChainMiddleCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleCascadeChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> update(
    _i1.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _i1.ColumnSelections<FkChainMiddleCascadeChildTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainMiddleCascadeChild>(
      rows,
      columns: columns?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainMiddleCascadeChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainMiddleCascadeChild> updateRow(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _i1.ColumnSelections<FkChainMiddleCascadeChildTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainMiddleCascadeChild>(
      row,
      columns: columns?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainMiddleCascadeChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainMiddleCascadeChild?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<FkChainMiddleCascadeChildUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainMiddleCascadeChild>(
      id,
      columnValues: columnValues(FkChainMiddleCascadeChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleCascadeChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<FkChainMiddleCascadeChildUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainMiddleCascadeChild>(
      columnValues: columnValues(FkChainMiddleCascadeChild.t.updateTable),
      where: where(FkChainMiddleCascadeChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainMiddleCascadeChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainMiddleCascadeChild>> delete(
    _i1.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainMiddleCascadeChild>(
      rows,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainMiddleCascadeChild].
  Future<FkChainMiddleCascadeChild> deleteRow(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainMiddleCascadeChild>(
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
  Future<List<FkChainMiddleCascadeChild>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    _i1.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainMiddleCascadeChild>(
      where: where(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
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
    _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainMiddleCascadeChild] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainMiddleCascadeChild>(
      where: where(FkChainMiddleCascadeChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainMiddleCascadeChildAttachRowRepository {
  const FkChainMiddleCascadeChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainMiddleCascadeChild] and [FkChainRestrictBlocker]
  /// by setting the [FkChainMiddleCascadeChild]'s foreign key `restrictBlockerId` to refer to the [FkChainRestrictBlocker].
  Future<void> restrictBlocker(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild fkChainMiddleCascadeChild,
    _i2.FkChainRestrictBlocker restrictBlocker, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainMiddleCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleCascadeChild.id');
    }
    if (restrictBlocker.id == null) {
      throw ArgumentError.notNull('restrictBlocker.id');
    }

    var $fkChainMiddleCascadeChild = fkChainMiddleCascadeChild.copyWith(
      restrictBlockerId: restrictBlocker.id,
    );
    await session.db.updateRow<FkChainMiddleCascadeChild>(
      $fkChainMiddleCascadeChild,
      columns: [FkChainMiddleCascadeChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}

class FkChainMiddleCascadeChildDetachRowRepository {
  const FkChainMiddleCascadeChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainMiddleCascadeChild] and the [FkChainRestrictBlocker] set in `restrictBlocker`
  /// by setting the [FkChainMiddleCascadeChild]'s foreign key `restrictBlockerId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> restrictBlocker(
    _i1.DatabaseSession session,
    FkChainMiddleCascadeChild fkChainMiddleCascadeChild, {
    _i1.Transaction? transaction,
  }) async {
    if (fkChainMiddleCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleCascadeChild.id');
    }

    var $fkChainMiddleCascadeChild = fkChainMiddleCascadeChild.copyWith(
      restrictBlockerId: null,
    );
    await session.db.updateRow<FkChainMiddleCascadeChild>(
      $fkChainMiddleCascadeChild,
      columns: [FkChainMiddleCascadeChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}
