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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;

abstract class UniqueNullable
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  UniqueNullable._({
    this.id,
    this.spaceId,
    this.value,
  });

  factory UniqueNullable({
    _isc.UuidValue? id,
    int? spaceId,
    int? value,
  }) = _UniqueNullableImpl;

  factory UniqueNullable.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueNullable(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      value: jsonSerialization['value'] as int?,
    );
  }

  static final t = UniqueNullableTable();

  static const db = UniqueNullableRepository._();

  @override
  _isc.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  int? value;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueNullable]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UniqueNullable copyWith({
    _isc.UuidValue? id,
    int? spaceId,
    int? value,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueNullable',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      if (value != null) 'value': value,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueNullable',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      if (value != null) 'value': value,
    };
  }

  static UniqueNullableInclude include() {
    return UniqueNullableInclude._();
  }

  static UniqueNullableIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueNullableTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    UniqueNullableInclude? include,
  }) {
    return UniqueNullableIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueNullableImpl extends UniqueNullable {
  _UniqueNullableImpl({
    _isc.UuidValue? id,
    int? spaceId,
    int? value,
  }) : super._(
         id: id,
         spaceId: spaceId,
         value: value,
       );

  /// Returns a shallow copy of this [UniqueNullable]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UniqueNullable copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    Object? value = _Undefined,
  }) {
    return UniqueNullable(
      id: id is _isc.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      value: value is int? ? value : this.value,
    );
  }
}

class UniqueNullableUpdateTable extends _isd.UpdateTable<UniqueNullableTable> {
  UniqueNullableUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<int, int> value(int? value) => _isd.ColumnValue(
    table.value,
    value,
  );
}

class UniqueNullableTable extends _isd.Table<_isc.UuidValue?> {
  UniqueNullableTable({super.tableRelation})
    : super(tableName: 'unique_nullable') {
    updateTable = UniqueNullableUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    value = _isd.ColumnInt(
      'value',
      this,
    );
  }

  late final UniqueNullableUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnInt value;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    value,
  ];
}

class UniqueNullableInclude extends _isd.IncludeObject {
  UniqueNullableInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueNullable.t;
}

class UniqueNullableIncludeList extends _isd.IncludeList {
  UniqueNullableIncludeList._({
    _isd.WhereExpressionBuilder<UniqueNullableTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueNullable.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueNullable.t;
}

class UniqueNullableRepository {
  const UniqueNullableRepository._();

  /// Returns a list of [UniqueNullable]s matching the given query parameters.
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
  Future<List<UniqueNullable>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueNullableTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueNullable>(
      where: where?.call(UniqueNullable.t),
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueNullable] matching the given query parameters.
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
  Future<UniqueNullable?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueNullableTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueNullable>(
      where: where?.call(UniqueNullable.t),
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueNullable] by its [id] or null if no such row exists.
  Future<UniqueNullable?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueNullable>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueNullable]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueNullable]s will have their `id` fields set.
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
  Future<List<UniqueNullable>> insert(
    _isd.DatabaseSession session,
    List<UniqueNullable> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueNullable>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueNullable] and returns the inserted row.
  ///
  /// The returned [UniqueNullable] will have its `id` field set.
  Future<UniqueNullable> insertRow(
    _isd.DatabaseSession session,
    UniqueNullable row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueNullable>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueNullable]s in the list and returns the resulting rows.
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
  /// The returned [UniqueNullable]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNullable>> upsert(
    _isd.DatabaseSession session,
    List<UniqueNullable> rows, {
    required _isd.ColumnSelections<UniqueNullableTable> conflictColumns,
    _isd.ColumnSelections<UniqueNullableTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueNullableTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueNullable>(
      rows,
      conflictColumns: conflictColumns(UniqueNullable.t),
      updateColumns: updateColumns?.call(UniqueNullable.t),
      updateWhere: updateWhere?.call(UniqueNullable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueNullable] and returns the resulting row.
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
  /// The returned [UniqueNullable] will have its `id` field set.
  Future<UniqueNullable?> upsertRow(
    _isd.DatabaseSession session,
    UniqueNullable row, {
    required _isd.ColumnSelections<UniqueNullableTable> conflictColumns,
    _isd.ColumnSelections<UniqueNullableTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueNullableTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueNullable>(
      row,
      conflictColumns: conflictColumns(UniqueNullable.t),
      updateColumns: updateColumns?.call(UniqueNullable.t),
      updateWhere: updateWhere?.call(UniqueNullable.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueNullable]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNullable>> update(
    _isd.DatabaseSession session,
    List<UniqueNullable> rows, {
    _isd.ColumnSelections<UniqueNullableTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueNullable>(
      rows,
      columns: columns?.call(UniqueNullable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueNullable]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueNullable> updateRow(
    _isd.DatabaseSession session,
    UniqueNullable row, {
    _isd.ColumnSelections<UniqueNullableTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueNullable>(
      row,
      columns: columns?.call(UniqueNullable.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueNullable] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueNullable?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueNullableUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueNullable>(
      id,
      columnValues: columnValues(UniqueNullable.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueNullable]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueNullable>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueNullableUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<UniqueNullableTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueNullable>(
      columnValues: columnValues(UniqueNullable.t.updateTable),
      where: where(UniqueNullable.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueNullable]s in the list and returns the deleted rows.
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
  Future<List<UniqueNullable>> delete(
    _isd.DatabaseSession session,
    List<UniqueNullable> rows, {
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueNullable>(
      rows,
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueNullable].
  Future<UniqueNullable> deleteRow(
    _isd.DatabaseSession session,
    UniqueNullable row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueNullable>(
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
  Future<List<UniqueNullable>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueNullableTable> where,
    _isd.OrderByBuilder<UniqueNullableTable>? orderBy,
    _isd.OrderByListBuilder<UniqueNullableTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueNullable>(
      where: where(UniqueNullable.t),
      orderBy: orderBy?.call(UniqueNullable.t),
      orderByList: orderByList?.call(UniqueNullable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueNullableTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<UniqueNullable>(
      where: where?.call(UniqueNullable.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueNullable] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueNullableTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueNullable>(
      where: where(UniqueNullable.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
