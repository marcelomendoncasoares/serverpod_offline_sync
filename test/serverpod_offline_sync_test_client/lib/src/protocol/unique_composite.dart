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

abstract class UniqueComposite
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  UniqueComposite._({
    this.id,
    this.scopeId,
    required this.scope,
    required this.value,
  });

  factory UniqueComposite({
    _isc.UuidValue? id,
    int? scopeId,
    required String scope,
    required String value,
  }) = _UniqueCompositeImpl;

  factory UniqueComposite.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueComposite(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      scope: jsonSerialization['scope'] as String,
      value: jsonSerialization['value'] as String,
    );
  }

  static final t = UniqueCompositeTable();

  static const db = UniqueCompositeRepository._();

  @override
  _isc.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  /// This scope field has no relation with the CRDT sync layer.
  String scope;

  String value;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueComposite]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UniqueComposite copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? scope,
    String? value,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueComposite',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'scope': scope,
      'value': value,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueComposite',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'scope': scope,
      'value': value,
    };
  }

  static UniqueCompositeInclude include() {
    return UniqueCompositeInclude._();
  }

  static UniqueCompositeIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    UniqueCompositeInclude? include,
  }) {
    return UniqueCompositeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueCompositeImpl extends UniqueComposite {
  _UniqueCompositeImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String scope,
    required String value,
  }) : super._(
         id: id,
         scopeId: scopeId,
         scope: scope,
         value: value,
       );

  /// Returns a shallow copy of this [UniqueComposite]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UniqueComposite copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? scope,
    String? value,
  }) {
    return UniqueComposite(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      scope: scope ?? this.scope,
      value: value ?? this.value,
    );
  }
}

class UniqueCompositeUpdateTable
    extends _isd.UpdateTable<UniqueCompositeTable> {
  UniqueCompositeUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> scope(String value) => _isd.ColumnValue(
    table.scope,
    value,
  );

  _isd.ColumnValue<String, String> value(String value) => _isd.ColumnValue(
    table.value,
    value,
  );
}

class UniqueCompositeTable extends _isd.Table<_isc.UuidValue?> {
  UniqueCompositeTable({super.tableRelation})
    : super(tableName: 'unique_composite') {
    updateTable = UniqueCompositeUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    scope = _isd.ColumnString(
      'scope',
      this,
    );
    value = _isd.ColumnString(
      'value',
      this,
    );
  }

  late final UniqueCompositeUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _isd.ColumnInt scopeId;

  /// This scope field has no relation with the CRDT sync layer.
  late final _isd.ColumnString scope;

  late final _isd.ColumnString value;

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    scope,
    value,
  ];
}

class UniqueCompositeInclude extends _isd.IncludeObject {
  UniqueCompositeInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueComposite.t;
}

class UniqueCompositeIncludeList extends _isd.IncludeList {
  UniqueCompositeIncludeList._({
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueComposite.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueComposite.t;
}

class UniqueCompositeRepository {
  const UniqueCompositeRepository._();

  /// Returns a list of [UniqueComposite]s matching the given query parameters.
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
  Future<List<UniqueComposite>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueComposite>(
      where: where?.call(UniqueComposite.t),
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueComposite] matching the given query parameters.
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
  Future<UniqueComposite?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueComposite>(
      where: where?.call(UniqueComposite.t),
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueComposite] by its [id] or null if no such row exists.
  Future<UniqueComposite?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueComposite>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueComposite]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueComposite]s will have their `id` fields set.
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
  Future<List<UniqueComposite>> insert(
    _isd.DatabaseSession session,
    List<UniqueComposite> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueComposite>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueComposite] and returns the inserted row.
  ///
  /// The returned [UniqueComposite] will have its `id` field set.
  Future<UniqueComposite> insertRow(
    _isd.DatabaseSession session,
    UniqueComposite row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueComposite>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueComposite]s in the list and returns the resulting rows.
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
  /// The returned [UniqueComposite]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueComposite>> upsert(
    _isd.DatabaseSession session,
    List<UniqueComposite> rows, {
    required _isd.ColumnSelections<UniqueCompositeTable> conflictColumns,
    _isd.ColumnSelections<UniqueCompositeTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueComposite>(
      rows,
      conflictColumns: conflictColumns(UniqueComposite.t),
      updateColumns: updateColumns?.call(UniqueComposite.t),
      updateWhere: updateWhere?.call(UniqueComposite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueComposite] and returns the resulting row.
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
  /// The returned [UniqueComposite] will have its `id` field set.
  Future<UniqueComposite?> upsertRow(
    _isd.DatabaseSession session,
    UniqueComposite row, {
    required _isd.ColumnSelections<UniqueCompositeTable> conflictColumns,
    _isd.ColumnSelections<UniqueCompositeTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueComposite>(
      row,
      conflictColumns: conflictColumns(UniqueComposite.t),
      updateColumns: updateColumns?.call(UniqueComposite.t),
      updateWhere: updateWhere?.call(UniqueComposite.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueComposite]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueComposite>> update(
    _isd.DatabaseSession session,
    List<UniqueComposite> rows, {
    _isd.ColumnSelections<UniqueCompositeTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueComposite>(
      rows,
      columns: columns?.call(UniqueComposite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueComposite]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueComposite> updateRow(
    _isd.DatabaseSession session,
    UniqueComposite row, {
    _isd.ColumnSelections<UniqueCompositeTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueComposite>(
      row,
      columns: columns?.call(UniqueComposite.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueComposite] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueComposite?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueCompositeUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueComposite>(
      id,
      columnValues: columnValues(UniqueComposite.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueComposite]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueComposite>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueCompositeUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<UniqueCompositeTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueComposite>(
      columnValues: columnValues(UniqueComposite.t.updateTable),
      where: where(UniqueComposite.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueComposite]s in the list and returns the deleted rows.
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
  Future<List<UniqueComposite>> delete(
    _isd.DatabaseSession session,
    List<UniqueComposite> rows, {
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueComposite>(
      rows,
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueComposite].
  Future<UniqueComposite> deleteRow(
    _isd.DatabaseSession session,
    UniqueComposite row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueComposite>(
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
  Future<List<UniqueComposite>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueCompositeTable> where,
    _isd.OrderByBuilder<UniqueCompositeTable>? orderBy,
    _isd.OrderByListBuilder<UniqueCompositeTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueComposite>(
      where: where(UniqueComposite.t),
      orderBy: orderBy?.call(UniqueComposite.t),
      orderByList: orderByList?.call(UniqueComposite.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueCompositeTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<UniqueComposite>(
      where: where?.call(UniqueComposite.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueComposite] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueCompositeTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueComposite>(
      where: where(UniqueComposite.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
