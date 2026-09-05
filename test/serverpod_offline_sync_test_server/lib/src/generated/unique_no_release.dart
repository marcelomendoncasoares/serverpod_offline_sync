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

abstract class UniqueNoRelease
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueNoRelease._({
    this.id,
    this.scopeId,
    required this.categoryId,
  });

  factory UniqueNoRelease({
    _is.UuidValue? id,
    int? scopeId,
    required int categoryId,
  }) = _UniqueNoReleaseImpl;

  factory UniqueNoRelease.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueNoRelease(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      categoryId: jsonSerialization['categoryId'] as int,
    );
  }

  static final t = UniqueNoReleaseTable();

  static const db = UniqueNoReleaseRepository._();

  @override
  _is.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  int categoryId;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueNoRelease]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueNoRelease copyWith({
    _is.UuidValue? id,
    int? scopeId,
    int? categoryId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueNoRelease',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'categoryId': categoryId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueNoRelease',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'categoryId': categoryId,
    };
  }

  static UniqueNoReleaseInclude include() {
    return UniqueNoReleaseInclude._();
  }

  static UniqueNoReleaseIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    UniqueNoReleaseInclude? include,
  }) {
    return UniqueNoReleaseIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueNoReleaseImpl extends UniqueNoRelease {
  _UniqueNoReleaseImpl({
    _is.UuidValue? id,
    int? scopeId,
    required int categoryId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         categoryId: categoryId,
       );

  /// Returns a shallow copy of this [UniqueNoRelease]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueNoRelease copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    int? categoryId,
  }) {
    return UniqueNoRelease(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

class UniqueNoReleaseUpdateTable extends _is.UpdateTable<UniqueNoReleaseTable> {
  UniqueNoReleaseUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<int, int> categoryId(int value) => _is.ColumnValue(
    table.categoryId,
    value,
  );
}

class UniqueNoReleaseTable extends _is.Table<_is.UuidValue?> {
  UniqueNoReleaseTable({super.tableRelation})
    : super(tableName: 'unique_no_release') {
    updateTable = UniqueNoReleaseUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    categoryId = _is.ColumnInt(
      'categoryId',
      this,
    );
  }

  late final UniqueNoReleaseUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnInt categoryId;

  @override
  List<_is.Column> get columns => [
    id,
    scopeId,
    categoryId,
  ];
}

class UniqueNoReleaseInclude extends _is.IncludeObject {
  UniqueNoReleaseInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueNoRelease.t;
}

class UniqueNoReleaseIncludeList extends _is.IncludeList {
  UniqueNoReleaseIncludeList._({
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueNoRelease.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueNoRelease.t;
}

class UniqueNoReleaseRepository {
  const UniqueNoReleaseRepository._();

  /// Returns a list of [UniqueNoRelease]s matching the given query parameters.
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
  Future<List<UniqueNoRelease>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueNoRelease>(
      where: where?.call(UniqueNoRelease.t),
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueNoRelease] matching the given query parameters.
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
  Future<UniqueNoRelease?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueNoRelease>(
      where: where?.call(UniqueNoRelease.t),
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueNoRelease] by its [id] or null if no such row exists.
  Future<UniqueNoRelease?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueNoRelease>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueNoRelease]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueNoRelease]s will have their `id` fields set.
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
  Future<List<UniqueNoRelease>> insert(
    _is.DatabaseSession session,
    List<UniqueNoRelease> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueNoRelease>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueNoRelease] and returns the inserted row.
  ///
  /// The returned [UniqueNoRelease] will have its `id` field set.
  Future<UniqueNoRelease> insertRow(
    _is.DatabaseSession session,
    UniqueNoRelease row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueNoRelease>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueNoRelease]s in the list and returns the resulting rows.
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
  /// The returned [UniqueNoRelease]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNoRelease>> upsert(
    _is.DatabaseSession session,
    List<UniqueNoRelease> rows, {
    required _is.ColumnSelections<UniqueNoReleaseTable> conflictColumns,
    _is.ColumnSelections<UniqueNoReleaseTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueNoRelease>(
      rows,
      conflictColumns: conflictColumns(UniqueNoRelease.t),
      updateColumns: updateColumns?.call(UniqueNoRelease.t),
      updateWhere: updateWhere?.call(UniqueNoRelease.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueNoRelease] and returns the resulting row.
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
  /// The returned [UniqueNoRelease] will have its `id` field set.
  Future<UniqueNoRelease?> upsertRow(
    _is.DatabaseSession session,
    UniqueNoRelease row, {
    required _is.ColumnSelections<UniqueNoReleaseTable> conflictColumns,
    _is.ColumnSelections<UniqueNoReleaseTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueNoRelease>(
      row,
      conflictColumns: conflictColumns(UniqueNoRelease.t),
      updateColumns: updateColumns?.call(UniqueNoRelease.t),
      updateWhere: updateWhere?.call(UniqueNoRelease.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueNoRelease]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNoRelease>> update(
    _is.DatabaseSession session,
    List<UniqueNoRelease> rows, {
    _is.ColumnSelections<UniqueNoReleaseTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueNoRelease>(
      rows,
      columns: columns?.call(UniqueNoRelease.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueNoRelease]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueNoRelease> updateRow(
    _is.DatabaseSession session,
    UniqueNoRelease row, {
    _is.ColumnSelections<UniqueNoReleaseTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueNoRelease>(
      row,
      columns: columns?.call(UniqueNoRelease.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueNoRelease] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueNoRelease?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueNoReleaseUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueNoRelease>(
      id,
      columnValues: columnValues(UniqueNoRelease.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueNoRelease]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNoRelease>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueNoReleaseUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UniqueNoReleaseTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueNoRelease>(
      columnValues: columnValues(UniqueNoRelease.t.updateTable),
      where: where(UniqueNoRelease.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueNoRelease]s in the list and returns the deleted rows.
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
  Future<List<UniqueNoRelease>> delete(
    _is.DatabaseSession session,
    List<UniqueNoRelease> rows, {
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueNoRelease>(
      rows,
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueNoRelease].
  Future<UniqueNoRelease> deleteRow(
    _is.DatabaseSession session,
    UniqueNoRelease row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueNoRelease>(
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
  Future<List<UniqueNoRelease>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueNoReleaseTable> where,
    _is.OrderByBuilder<UniqueNoReleaseTable>? orderBy,
    _is.OrderByListBuilder<UniqueNoReleaseTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueNoRelease>(
      where: where(UniqueNoRelease.t),
      orderBy: orderBy?.call(UniqueNoRelease.t),
      orderByList: orderByList?.call(UniqueNoRelease.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueNoReleaseTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueNoRelease>(
      where: where?.call(UniqueNoRelease.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueNoRelease] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueNoReleaseTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueNoRelease>(
      where: where(UniqueNoRelease.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
