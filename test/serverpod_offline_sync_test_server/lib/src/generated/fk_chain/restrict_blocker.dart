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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _ixxccm81;
import '../fk_chain/cascade_middle.dart' as _i2nw0ajk;

abstract class FkChainRestrictBlocker
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  FkChainRestrictBlocker._({
    this.id,
    this.scopeId,
    required this.name,
    this.cascadeMiddle,
    this.cascadeMiddleId,
  });

  factory FkChainRestrictBlocker({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
    _is.UuidValue? cascadeMiddleId,
  }) = _FkChainRestrictBlockerImpl;

  factory FkChainRestrictBlocker.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainRestrictBlocker(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      cascadeMiddle: jsonSerialization['cascadeMiddle'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_i2nw0ajk.FkChainCascadeMiddle>(
              jsonSerialization['cascadeMiddle'],
            ),
      cascadeMiddleId: jsonSerialization['cascadeMiddleId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['cascadeMiddleId'],
            ),
    );
  }

  static final t = FkChainRestrictBlockerTable();

  static const db = FkChainRestrictBlockerRepository._();

  @override
  _is.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle;

  _is.UuidValue? cascadeMiddleId;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainRestrictBlocker]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FkChainRestrictBlocker copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
    _is.UuidValue? cascadeMiddleId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainRestrictBlocker',
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
      '__className__': 'FkChainRestrictBlocker',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cascadeMiddle != null)
        'cascadeMiddle': cascadeMiddle?.toJsonForProtocol(),
      if (cascadeMiddleId != null) 'cascadeMiddleId': cascadeMiddleId?.toJson(),
    };
  }

  static FkChainRestrictBlockerInclude include({
    _i2nw0ajk.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    return FkChainRestrictBlockerInclude._(cascadeMiddle: cascadeMiddle);
  }

  static FkChainRestrictBlockerIncludeList includeList({
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    FkChainRestrictBlockerInclude? include,
  }) {
    return FkChainRestrictBlockerIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainRestrictBlockerImpl extends FkChainRestrictBlocker {
  _FkChainRestrictBlockerImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _i2nw0ajk.FkChainCascadeMiddle? cascadeMiddle,
    _is.UuidValue? cascadeMiddleId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         cascadeMiddle: cascadeMiddle,
         cascadeMiddleId: cascadeMiddleId,
       );

  /// Returns a shallow copy of this [FkChainRestrictBlocker]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FkChainRestrictBlocker copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? cascadeMiddle = _Undefined,
    Object? cascadeMiddleId = _Undefined,
  }) {
    return FkChainRestrictBlocker(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      cascadeMiddle: cascadeMiddle is _i2nw0ajk.FkChainCascadeMiddle?
          ? cascadeMiddle
          : this.cascadeMiddle?.copyWith(),
      cascadeMiddleId: cascadeMiddleId is _is.UuidValue?
          ? cascadeMiddleId
          : this.cascadeMiddleId,
    );
  }
}

class FkChainRestrictBlockerUpdateTable
    extends _is.UpdateTable<FkChainRestrictBlockerTable> {
  FkChainRestrictBlockerUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> cascadeMiddleId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.cascadeMiddleId,
    value,
  );
}

class FkChainRestrictBlockerTable extends _is.Table<_is.UuidValue?> {
  FkChainRestrictBlockerTable({super.tableRelation})
    : super(tableName: 'fk_chain_restrict_blocker') {
    updateTable = FkChainRestrictBlockerUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    cascadeMiddleId = _is.ColumnUuid(
      'cascadeMiddleId',
      this,
    );
  }

  late final FkChainRestrictBlockerUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  _i2nw0ajk.FkChainCascadeMiddleTable? _cascadeMiddle;

  late final _is.ColumnUuid cascadeMiddleId;

  _i2nw0ajk.FkChainCascadeMiddleTable get cascadeMiddle {
    if (_cascadeMiddle != null) return _cascadeMiddle!;
    _cascadeMiddle = _is.createRelationTable(
      relationFieldName: 'cascadeMiddle',
      field: FkChainRestrictBlocker.t.cascadeMiddleId,
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
  List<_is.Column> get columns => [
    id,
    scopeId,
    name,
    cascadeMiddleId,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'cascadeMiddle') {
      return cascadeMiddle;
    }
    return null;
  }
}

class FkChainRestrictBlockerInclude extends _is.IncludeObject {
  FkChainRestrictBlockerInclude._({
    _i2nw0ajk.FkChainCascadeMiddleInclude? cascadeMiddle,
  }) {
    _cascadeMiddle = cascadeMiddle;
  }

  _i2nw0ajk.FkChainCascadeMiddleInclude? _cascadeMiddle;

  @override
  Map<String, _is.Include?> get includes => {'cascadeMiddle': _cascadeMiddle};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainRestrictBlocker.t;
}

class FkChainRestrictBlockerIncludeList extends _is.IncludeList {
  FkChainRestrictBlockerIncludeList._({
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainRestrictBlocker.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainRestrictBlocker.t;
}

class FkChainRestrictBlockerRepository {
  const FkChainRestrictBlockerRepository._();

  final attachRow = const FkChainRestrictBlockerAttachRowRepository._();

  final detachRow = const FkChainRestrictBlockerDetachRowRepository._();

  /// Returns a list of [FkChainRestrictBlocker]s matching the given query parameters.
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
  Future<List<FkChainRestrictBlocker>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    _is.Transaction? transaction,
    FkChainRestrictBlockerInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainRestrictBlocker>(
      where: where?.call(FkChainRestrictBlocker.t),
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainRestrictBlocker] matching the given query parameters.
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
  Future<FkChainRestrictBlocker?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? where,
    int? offset,
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    _is.Transaction? transaction,
    FkChainRestrictBlockerInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainRestrictBlocker>(
      where: where?.call(FkChainRestrictBlocker.t),
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainRestrictBlocker] by its [id] or null if no such row exists.
  Future<FkChainRestrictBlocker?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    FkChainRestrictBlockerInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainRestrictBlocker>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainRestrictBlocker]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainRestrictBlocker]s will have their `id` fields set.
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
  Future<List<FkChainRestrictBlocker>> insert(
    _is.DatabaseSession session,
    List<FkChainRestrictBlocker> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainRestrictBlocker>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainRestrictBlocker] and returns the inserted row.
  ///
  /// The returned [FkChainRestrictBlocker] will have its `id` field set.
  Future<FkChainRestrictBlocker> insertRow(
    _is.DatabaseSession session,
    FkChainRestrictBlocker row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainRestrictBlocker>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainRestrictBlocker]s in the list and returns the resulting rows.
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
  /// The returned [FkChainRestrictBlocker]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRestrictBlocker>> upsert(
    _is.DatabaseSession session,
    List<FkChainRestrictBlocker> rows, {
    required _is.ColumnSelections<FkChainRestrictBlockerTable> conflictColumns,
    _is.ColumnSelections<FkChainRestrictBlockerTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainRestrictBlocker>(
      rows,
      conflictColumns: conflictColumns(FkChainRestrictBlocker.t),
      updateColumns: updateColumns?.call(FkChainRestrictBlocker.t),
      updateWhere: updateWhere?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainRestrictBlocker] and returns the resulting row.
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
  /// The returned [FkChainRestrictBlocker] will have its `id` field set.
  Future<FkChainRestrictBlocker?> upsertRow(
    _is.DatabaseSession session,
    FkChainRestrictBlocker row, {
    required _is.ColumnSelections<FkChainRestrictBlockerTable> conflictColumns,
    _is.ColumnSelections<FkChainRestrictBlockerTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainRestrictBlocker>(
      row,
      conflictColumns: conflictColumns(FkChainRestrictBlocker.t),
      updateColumns: updateColumns?.call(FkChainRestrictBlocker.t),
      updateWhere: updateWhere?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainRestrictBlocker]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRestrictBlocker>> update(
    _is.DatabaseSession session,
    List<FkChainRestrictBlocker> rows, {
    _is.ColumnSelections<FkChainRestrictBlockerTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainRestrictBlocker>(
      rows,
      columns: columns?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainRestrictBlocker]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainRestrictBlocker> updateRow(
    _is.DatabaseSession session,
    FkChainRestrictBlocker row, {
    _is.ColumnSelections<FkChainRestrictBlockerTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainRestrictBlocker>(
      row,
      columns: columns?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainRestrictBlocker] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainRestrictBlocker?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<FkChainRestrictBlockerUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainRestrictBlocker>(
      id,
      columnValues: columnValues(FkChainRestrictBlocker.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainRestrictBlocker]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRestrictBlocker>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<FkChainRestrictBlockerUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<FkChainRestrictBlockerTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainRestrictBlocker>(
      columnValues: columnValues(FkChainRestrictBlocker.t.updateTable),
      where: where(FkChainRestrictBlocker.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainRestrictBlocker]s in the list and returns the deleted rows.
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
  Future<List<FkChainRestrictBlocker>> delete(
    _is.DatabaseSession session,
    List<FkChainRestrictBlocker> rows, {
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainRestrictBlocker>(
      rows,
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainRestrictBlocker].
  Future<FkChainRestrictBlocker> deleteRow(
    _is.DatabaseSession session,
    FkChainRestrictBlocker row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainRestrictBlocker>(
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
  Future<List<FkChainRestrictBlocker>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainRestrictBlockerTable> where,
    _is.OrderByBuilder<FkChainRestrictBlockerTable>? orderBy,
    _is.OrderByListBuilder<FkChainRestrictBlockerTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainRestrictBlocker>(
      where: where(FkChainRestrictBlocker.t),
      orderBy: orderBy?.call(FkChainRestrictBlocker.t),
      orderByList: orderByList?.call(FkChainRestrictBlocker.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRestrictBlockerTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<FkChainRestrictBlocker>(
      where: where?.call(FkChainRestrictBlocker.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainRestrictBlocker] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainRestrictBlockerTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainRestrictBlocker>(
      where: where(FkChainRestrictBlocker.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainRestrictBlockerAttachRowRepository {
  const FkChainRestrictBlockerAttachRowRepository._();

  /// Creates a relation between the given [FkChainRestrictBlocker] and [FkChainCascadeMiddle]
  /// by setting the [FkChainRestrictBlocker]'s foreign key `cascadeMiddleId` to refer to the [FkChainCascadeMiddle].
  Future<void> cascadeMiddle(
    _is.DatabaseSession session,
    FkChainRestrictBlocker fkChainRestrictBlocker,
    _i2nw0ajk.FkChainCascadeMiddle cascadeMiddle, {
    _is.Transaction? transaction,
  }) async {
    if (fkChainRestrictBlocker.id == null) {
      throw ArgumentError.notNull('fkChainRestrictBlocker.id');
    }
    if (cascadeMiddle.id == null) {
      throw ArgumentError.notNull('cascadeMiddle.id');
    }

    var $fkChainRestrictBlocker = fkChainRestrictBlocker.copyWith(
      cascadeMiddleId: cascadeMiddle.id,
    );
    await session.db.updateRow<FkChainRestrictBlocker>(
      $fkChainRestrictBlocker,
      columns: [FkChainRestrictBlocker.t.cascadeMiddleId],
      transaction: transaction,
    );
  }
}

class FkChainRestrictBlockerDetachRowRepository {
  const FkChainRestrictBlockerDetachRowRepository._();

  /// Detaches the relation between this [FkChainRestrictBlocker] and the [FkChainCascadeMiddle] set in `cascadeMiddle`
  /// by setting the [FkChainRestrictBlocker]'s foreign key `cascadeMiddleId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> cascadeMiddle(
    _is.DatabaseSession session,
    FkChainRestrictBlocker fkChainRestrictBlocker, {
    _is.Transaction? transaction,
  }) async {
    if (fkChainRestrictBlocker.id == null) {
      throw ArgumentError.notNull('fkChainRestrictBlocker.id');
    }

    var $fkChainRestrictBlocker = fkChainRestrictBlocker.copyWith(
      cascadeMiddleId: null,
    );
    await session.db.updateRow<FkChainRestrictBlocker>(
      $fkChainRestrictBlocker,
      columns: [FkChainRestrictBlocker.t.cascadeMiddleId],
      transaction: transaction,
    );
  }
}
