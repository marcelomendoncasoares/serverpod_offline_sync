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

/// CRDT schema tables table.
abstract class CrdtSchemaTable
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  CrdtSchemaTable._({
    this.id,
    required this.name,
  });

  factory CrdtSchemaTable({
    int? id,
    required String name,
  }) = _CrdtSchemaTableImpl;

  factory CrdtSchemaTable.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSchemaTable(
      id: jsonSerialization['id'] as int?,
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = CrdtSchemaTableTable();

  static const db = CrdtSchemaTableRepository._();

  @override
  int? id;

  /// Name of the synchronized table.
  String name;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtSchemaTable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  CrdtSchemaTable copyWith({
    int? id,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSchemaTable',
      if (id != null) 'id': id,
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSchemaTable',
      if (id != null) 'id': id,
      'name': name,
    };
  }

  static CrdtSchemaTableInclude include() {
    return CrdtSchemaTableInclude._();
  }

  static CrdtSchemaTableIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    CrdtSchemaTableInclude? include,
  }) {
    return CrdtSchemaTableIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtSchemaTableImpl extends CrdtSchemaTable {
  _CrdtSchemaTableImpl({
    int? id,
    required String name,
  }) : super._(
         id: id,
         name: name,
       );

  /// Returns a shallow copy of this [CrdtSchemaTable]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  CrdtSchemaTable copyWith({
    Object? id = _Undefined,
    String? name,
  }) {
    return CrdtSchemaTable(
      id: id is int? ? id : this.id,
      name: name ?? this.name,
    );
  }
}

class CrdtSchemaTableUpdateTable extends _i1.UpdateTable<CrdtSchemaTableTable> {
  CrdtSchemaTableUpdateTable(super.table);

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );
}

class CrdtSchemaTableTable extends _i1.Table<int?> {
  CrdtSchemaTableTable({super.tableRelation})
    : super(tableName: 'crdt_schema_tables') {
    updateTable = CrdtSchemaTableUpdateTable(this);
    name = _i1.ColumnString(
      'name',
      this,
    );
  }

  late final CrdtSchemaTableUpdateTable updateTable;

  /// Name of the synchronized table.
  late final _i1.ColumnString name;

  @override
  List<_i1.Column> get columns => [
    id,
    name,
  ];
}

class CrdtSchemaTableInclude extends _i1.IncludeObject {
  CrdtSchemaTableInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => CrdtSchemaTable.t;
}

class CrdtSchemaTableIncludeList extends _i1.IncludeList {
  CrdtSchemaTableIncludeList._({
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtSchemaTable.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtSchemaTable.t;
}

class CrdtSchemaTableRepository {
  const CrdtSchemaTableRepository._();

  /// Returns a list of [CrdtSchemaTable]s matching the given query parameters.
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
  Future<List<CrdtSchemaTable>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtSchemaTable>(
      where: where?.call(CrdtSchemaTable.t),
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtSchemaTable] matching the given query parameters.
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
  Future<CrdtSchemaTable?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtSchemaTable>(
      where: where?.call(CrdtSchemaTable.t),
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtSchemaTable] by its [id] or null if no such row exists.
  Future<CrdtSchemaTable?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtSchemaTable>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtSchemaTable]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtSchemaTable]s will have their `id` fields set.
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
  Future<List<CrdtSchemaTable>> insert(
    _i1.DatabaseSession session,
    List<CrdtSchemaTable> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtSchemaTable>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtSchemaTable] and returns the inserted row.
  ///
  /// The returned [CrdtSchemaTable] will have its `id` field set.
  Future<CrdtSchemaTable> insertRow(
    _i1.DatabaseSession session,
    CrdtSchemaTable row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtSchemaTable>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtSchemaTable]s in the list and returns the resulting rows.
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
  /// The returned [CrdtSchemaTable]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaTable>> upsert(
    _i1.DatabaseSession session,
    List<CrdtSchemaTable> rows, {
    required _i1.ColumnSelections<CrdtSchemaTableTable> conflictColumns,
    _i1.ColumnSelections<CrdtSchemaTableTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtSchemaTable>(
      rows,
      conflictColumns: conflictColumns(CrdtSchemaTable.t),
      updateColumns: updateColumns?.call(CrdtSchemaTable.t),
      updateWhere: updateWhere?.call(CrdtSchemaTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtSchemaTable] and returns the resulting row.
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
  /// The returned [CrdtSchemaTable] will have its `id` field set.
  Future<CrdtSchemaTable?> upsertRow(
    _i1.DatabaseSession session,
    CrdtSchemaTable row, {
    required _i1.ColumnSelections<CrdtSchemaTableTable> conflictColumns,
    _i1.ColumnSelections<CrdtSchemaTableTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtSchemaTable>(
      row,
      conflictColumns: conflictColumns(CrdtSchemaTable.t),
      updateColumns: updateColumns?.call(CrdtSchemaTable.t),
      updateWhere: updateWhere?.call(CrdtSchemaTable.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSchemaTable]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaTable>> update(
    _i1.DatabaseSession session,
    List<CrdtSchemaTable> rows, {
    _i1.ColumnSelections<CrdtSchemaTableTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtSchemaTable>(
      rows,
      columns: columns?.call(CrdtSchemaTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtSchemaTable]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtSchemaTable> updateRow(
    _i1.DatabaseSession session,
    CrdtSchemaTable row, {
    _i1.ColumnSelections<CrdtSchemaTableTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtSchemaTable>(
      row,
      columns: columns?.call(CrdtSchemaTable.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtSchemaTable] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtSchemaTable?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtSchemaTableUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtSchemaTable>(
      id,
      columnValues: columnValues(CrdtSchemaTable.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSchemaTable]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaTable>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtSchemaTableUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<CrdtSchemaTableTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtSchemaTable>(
      columnValues: columnValues(CrdtSchemaTable.t.updateTable),
      where: where(CrdtSchemaTable.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtSchemaTable]s in the list and returns the deleted rows.
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
  Future<List<CrdtSchemaTable>> delete(
    _i1.DatabaseSession session,
    List<CrdtSchemaTable> rows, {
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtSchemaTable>(
      rows,
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtSchemaTable].
  Future<CrdtSchemaTable> deleteRow(
    _i1.DatabaseSession session,
    CrdtSchemaTable row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtSchemaTable>(
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
  Future<List<CrdtSchemaTable>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSchemaTableTable> where,
    _i1.OrderByBuilder<CrdtSchemaTableTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaTableTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtSchemaTable>(
      where: where(CrdtSchemaTable.t),
      orderBy: orderBy?.call(CrdtSchemaTable.t),
      orderByList: orderByList?.call(CrdtSchemaTable.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaTableTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtSchemaTable>(
      where: where?.call(CrdtSchemaTable.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtSchemaTable] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSchemaTableTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtSchemaTable>(
      where: where(CrdtSchemaTable.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
