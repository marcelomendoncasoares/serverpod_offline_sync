/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod/serverpod.dart' as _is;

abstract class FkChainRoot
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  FkChainRoot._({
    this.id,
    this.scopeId,
    required this.name,
  });

  factory FkChainRoot({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
  }) = _FkChainRootImpl;

  factory FkChainRoot.fromJson(Map<String, dynamic> jsonSerialization) {
    return FkChainRoot(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = FkChainRootTable();

  static const db = FkChainRootRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainRoot]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FkChainRoot copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainRoot',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainRoot',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
    };
  }

  static FkChainRootInclude include() {
    return FkChainRootInclude._();
  }

  static FkChainRootIncludeList includeList({
    _is.WhereExpressionBuilder<FkChainRootTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    FkChainRootInclude? include,
  }) {
    return FkChainRootIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainRootImpl extends FkChainRoot {
  _FkChainRootImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
       );

  /// Returns a shallow copy of this [FkChainRoot]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FkChainRoot copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
  }) {
    return FkChainRoot(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
    );
  }
}

class FkChainRootUpdateTable extends _is.UpdateTable<FkChainRootTable> {
  FkChainRootUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );
}

class FkChainRootTable extends _is.Table<_is.UuidValue?> {
  FkChainRootTable({super.tableRelation}) : super(tableName: 'fk_chain_root') {
    updateTable = FkChainRootUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
  }

  late final FkChainRootUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  @override
  List<_is.Column> get columns => [
    id,
    scopeId,
    name,
  ];
}

class FkChainRootInclude extends _is.IncludeObject {
  FkChainRootInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainRoot.t;
}

class FkChainRootIncludeList extends _is.IncludeList {
  FkChainRootIncludeList._({
    _is.WhereExpressionBuilder<FkChainRootTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainRoot.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainRoot.t;
}

class FkChainRootRepository {
  const FkChainRootRepository._();

  /// Returns a list of [FkChainRoot]s matching the given query parameters.
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
  Future<List<FkChainRoot>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRootTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainRoot>(
      where: where?.call(FkChainRoot.t),
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainRoot] matching the given query parameters.
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
  Future<FkChainRoot?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRootTable>? where,
    int? offset,
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainRoot>(
      where: where?.call(FkChainRoot.t),
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainRoot] by its [id] or null if no such row exists.
  Future<FkChainRoot?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainRoot>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainRoot]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainRoot]s will have their `id` fields set.
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
  Future<List<FkChainRoot>> insert(
    _is.DatabaseSession session,
    List<FkChainRoot> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainRoot>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainRoot] and returns the inserted row.
  ///
  /// The returned [FkChainRoot] will have its `id` field set.
  Future<FkChainRoot> insertRow(
    _is.DatabaseSession session,
    FkChainRoot row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainRoot>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainRoot]s in the list and returns the resulting rows.
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
  /// The returned [FkChainRoot]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRoot>> upsert(
    _is.DatabaseSession session,
    List<FkChainRoot> rows, {
    required _is.ColumnSelections<FkChainRootTable> conflictColumns,
    _is.ColumnSelections<FkChainRootTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainRootTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainRoot>(
      rows,
      conflictColumns: conflictColumns(FkChainRoot.t),
      updateColumns: updateColumns?.call(FkChainRoot.t),
      updateWhere: updateWhere?.call(FkChainRoot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainRoot] and returns the resulting row.
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
  /// The returned [FkChainRoot] will have its `id` field set.
  Future<FkChainRoot?> upsertRow(
    _is.DatabaseSession session,
    FkChainRoot row, {
    required _is.ColumnSelections<FkChainRootTable> conflictColumns,
    _is.ColumnSelections<FkChainRootTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainRootTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainRoot>(
      row,
      conflictColumns: conflictColumns(FkChainRoot.t),
      updateColumns: updateColumns?.call(FkChainRoot.t),
      updateWhere: updateWhere?.call(FkChainRoot.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainRoot]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRoot>> update(
    _is.DatabaseSession session,
    List<FkChainRoot> rows, {
    _is.ColumnSelections<FkChainRootTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainRoot>(
      rows,
      columns: columns?.call(FkChainRoot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainRoot]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainRoot> updateRow(
    _is.DatabaseSession session,
    FkChainRoot row, {
    _is.ColumnSelections<FkChainRootTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainRoot>(
      row,
      columns: columns?.call(FkChainRoot.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainRoot] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainRoot?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<FkChainRootUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainRoot>(
      id,
      columnValues: columnValues(FkChainRoot.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainRoot]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainRoot>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<FkChainRootUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<FkChainRootTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainRoot>(
      columnValues: columnValues(FkChainRoot.t.updateTable),
      where: where(FkChainRoot.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainRoot]s in the list and returns the deleted rows.
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
  Future<List<FkChainRoot>> delete(
    _is.DatabaseSession session,
    List<FkChainRoot> rows, {
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainRoot>(
      rows,
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainRoot].
  Future<FkChainRoot> deleteRow(
    _is.DatabaseSession session,
    FkChainRoot row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainRoot>(
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
  Future<List<FkChainRoot>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainRootTable> where,
    _is.OrderByBuilder<FkChainRootTable>? orderBy,
    _is.OrderByListBuilder<FkChainRootTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainRoot>(
      where: where(FkChainRoot.t),
      orderBy: orderBy?.call(FkChainRoot.t),
      orderByList: orderByList?.call(FkChainRoot.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainRootTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<FkChainRoot>(
      where: where?.call(FkChainRoot.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainRoot] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainRootTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainRoot>(
      where: where(FkChainRoot.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
