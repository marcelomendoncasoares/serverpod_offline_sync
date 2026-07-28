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
import 'package:serverpod/serverpod.dart' as _i1;

abstract class UniqueUuid
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  UniqueUuid._({
    this.id,
    this.scopeId,
    required this.value,
  });

  factory UniqueUuid({
    _i1.UuidValue? id,
    int? scopeId,
    required _i1.UuidValue value,
  }) = _UniqueUuidImpl;

  factory UniqueUuid.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueUuid(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      value: _i1.UuidValueJsonExtension.fromJson(jsonSerialization['value']),
    );
  }

  static final t = UniqueUuidTable();

  static const db = UniqueUuidRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  _i1.UuidValue value;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueUuid]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UniqueUuid copyWith({
    _i1.UuidValue? id,
    int? scopeId,
    _i1.UuidValue? value,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueUuid',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'value': value.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueUuid',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'value': value.toJson(),
    };
  }

  static UniqueUuidInclude include() {
    return UniqueUuidInclude._();
  }

  static UniqueUuidIncludeList includeList({
    _i1.WhereExpressionBuilder<UniqueUuidTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    UniqueUuidInclude? include,
  }) {
    return UniqueUuidIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueUuidImpl extends UniqueUuid {
  _UniqueUuidImpl({
    _i1.UuidValue? id,
    int? scopeId,
    required _i1.UuidValue value,
  }) : super._(
         id: id,
         scopeId: scopeId,
         value: value,
       );

  /// Returns a shallow copy of this [UniqueUuid]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  UniqueUuid copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    _i1.UuidValue? value,
  }) {
    return UniqueUuid(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      value: value ?? this.value,
    );
  }
}

class UniqueUuidUpdateTable extends _i1.UpdateTable<UniqueUuidTable> {
  UniqueUuidUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> value(_i1.UuidValue value) =>
      _i1.ColumnValue(
        table.value,
        value,
      );
}

class UniqueUuidTable extends _i1.Table<_i1.UuidValue?> {
  UniqueUuidTable({super.tableRelation}) : super(tableName: 'unique_uuid') {
    updateTable = UniqueUuidUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    value = _i1.ColumnUuid(
      'value',
      this,
    );
  }

  late final UniqueUuidUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnUuid value;

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    value,
  ];
}

class UniqueUuidInclude extends _i1.IncludeObject {
  UniqueUuidInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i1.UuidValue?> get table => UniqueUuid.t;
}

class UniqueUuidIncludeList extends _i1.IncludeList {
  UniqueUuidIncludeList._({
    _i1.WhereExpressionBuilder<UniqueUuidTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueUuid.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => UniqueUuid.t;
}

class UniqueUuidRepository {
  const UniqueUuidRepository._();

  /// Returns a list of [UniqueUuid]s matching the given query parameters.
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
  Future<List<UniqueUuid>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueUuidTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueUuid>(
      where: where?.call(UniqueUuid.t),
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueUuid] matching the given query parameters.
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
  Future<UniqueUuid?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueUuidTable>? where,
    int? offset,
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueUuid>(
      where: where?.call(UniqueUuid.t),
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueUuid] by its [id] or null if no such row exists.
  Future<UniqueUuid?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueUuid>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueUuid]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueUuid]s will have their `id` fields set.
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
  Future<List<UniqueUuid>> insert(
    _i1.DatabaseSession session,
    List<UniqueUuid> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueUuid>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueUuid] and returns the inserted row.
  ///
  /// The returned [UniqueUuid] will have its `id` field set.
  Future<UniqueUuid> insertRow(
    _i1.DatabaseSession session,
    UniqueUuid row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueUuid>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueUuid]s in the list and returns the resulting rows.
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
  /// The returned [UniqueUuid]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueUuid>> upsert(
    _i1.DatabaseSession session,
    List<UniqueUuid> rows, {
    required _i1.ColumnSelections<UniqueUuidTable> conflictColumns,
    _i1.ColumnSelections<UniqueUuidTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueUuidTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueUuid>(
      rows,
      conflictColumns: conflictColumns(UniqueUuid.t),
      updateColumns: updateColumns?.call(UniqueUuid.t),
      updateWhere: updateWhere?.call(UniqueUuid.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueUuid] and returns the resulting row.
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
  /// The returned [UniqueUuid] will have its `id` field set.
  Future<UniqueUuid?> upsertRow(
    _i1.DatabaseSession session,
    UniqueUuid row, {
    required _i1.ColumnSelections<UniqueUuidTable> conflictColumns,
    _i1.ColumnSelections<UniqueUuidTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueUuidTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueUuid>(
      row,
      conflictColumns: conflictColumns(UniqueUuid.t),
      updateColumns: updateColumns?.call(UniqueUuid.t),
      updateWhere: updateWhere?.call(UniqueUuid.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueUuid]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueUuid>> update(
    _i1.DatabaseSession session,
    List<UniqueUuid> rows, {
    _i1.ColumnSelections<UniqueUuidTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueUuid>(
      rows,
      columns: columns?.call(UniqueUuid.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueUuid]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueUuid> updateRow(
    _i1.DatabaseSession session,
    UniqueUuid row, {
    _i1.ColumnSelections<UniqueUuidTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueUuid>(
      row,
      columns: columns?.call(UniqueUuid.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueUuid] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueUuid?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<UniqueUuidUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueUuid>(
      id,
      columnValues: columnValues(UniqueUuid.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueUuid]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueUuid>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<UniqueUuidUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<UniqueUuidTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueUuid>(
      columnValues: columnValues(UniqueUuid.t.updateTable),
      where: where(UniqueUuid.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueUuid]s in the list and returns the deleted rows.
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
  Future<List<UniqueUuid>> delete(
    _i1.DatabaseSession session,
    List<UniqueUuid> rows, {
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueUuid>(
      rows,
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueUuid].
  Future<UniqueUuid> deleteRow(
    _i1.DatabaseSession session,
    UniqueUuid row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueUuid>(
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
  Future<List<UniqueUuid>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueUuidTable> where,
    _i1.OrderByBuilder<UniqueUuidTable>? orderBy,
    _i1.OrderByListBuilder<UniqueUuidTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueUuid>(
      where: where(UniqueUuid.t),
      orderBy: orderBy?.call(UniqueUuid.t),
      orderByList: orderByList?.call(UniqueUuid.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueUuidTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<UniqueUuid>(
      where: where?.call(UniqueUuid.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueUuid] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueUuidTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueUuid>(
      where: where(UniqueUuid.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
