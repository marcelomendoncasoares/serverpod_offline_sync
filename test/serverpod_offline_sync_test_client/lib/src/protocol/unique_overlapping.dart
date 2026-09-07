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

abstract class UniqueOverlapping
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  UniqueOverlapping._({
    this.id,
    this.scopeId,
    required this.first,
    required this.second,
    required this.third,
  });

  factory UniqueOverlapping({
    _isc.UuidValue? id,
    int? scopeId,
    required String first,
    required String second,
    required String third,
  }) = _UniqueOverlappingImpl;

  factory UniqueOverlapping.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueOverlapping(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      first: jsonSerialization['first'] as String,
      second: jsonSerialization['second'] as String,
      third: jsonSerialization['third'] as String,
    );
  }

  static final t = UniqueOverlappingTable();

  static const db = UniqueOverlappingRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String first;

  String second;

  String third;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueOverlapping]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UniqueOverlapping copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? first,
    String? second,
    String? third,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueOverlapping',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'first': first,
      'second': second,
      'third': third,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueOverlapping',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'first': first,
      'second': second,
      'third': third,
    };
  }

  static UniqueOverlappingInclude include() {
    return UniqueOverlappingInclude._();
  }

  static UniqueOverlappingIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    UniqueOverlappingInclude? include,
  }) {
    return UniqueOverlappingIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueOverlappingImpl extends UniqueOverlapping {
  _UniqueOverlappingImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String first,
    required String second,
    required String third,
  }) : super._(
         id: id,
         scopeId: scopeId,
         first: first,
         second: second,
         third: third,
       );

  /// Returns a shallow copy of this [UniqueOverlapping]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UniqueOverlapping copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? first,
    String? second,
    String? third,
  }) {
    return UniqueOverlapping(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      first: first ?? this.first,
      second: second ?? this.second,
      third: third ?? this.third,
    );
  }
}

class UniqueOverlappingUpdateTable
    extends _isd.UpdateTable<UniqueOverlappingTable> {
  UniqueOverlappingUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> first(String value) => _isd.ColumnValue(
    table.first,
    value,
  );

  _isd.ColumnValue<String, String> second(String value) => _isd.ColumnValue(
    table.second,
    value,
  );

  _isd.ColumnValue<String, String> third(String value) => _isd.ColumnValue(
    table.third,
    value,
  );
}

class UniqueOverlappingTable extends _isd.Table<_isc.UuidValue?> {
  UniqueOverlappingTable({super.tableRelation})
    : super(tableName: 'unique_overlapping') {
    updateTable = UniqueOverlappingUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    first = _isd.ColumnString(
      'first',
      this,
    );
    second = _isd.ColumnString(
      'second',
      this,
    );
    third = _isd.ColumnString(
      'third',
      this,
    );
  }

  late final UniqueOverlappingUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString first;

  late final _isd.ColumnString second;

  late final _isd.ColumnString third;

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    first,
    second,
    third,
  ];
}

class UniqueOverlappingInclude extends _isd.IncludeObject {
  UniqueOverlappingInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueOverlapping.t;
}

class UniqueOverlappingIncludeList extends _isd.IncludeList {
  UniqueOverlappingIncludeList._({
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueOverlapping.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueOverlapping.t;
}

class UniqueOverlappingRepository {
  const UniqueOverlappingRepository._();

  /// Returns a list of [UniqueOverlapping]s matching the given query parameters.
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
  Future<List<UniqueOverlapping>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueOverlapping>(
      where: where?.call(UniqueOverlapping.t),
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueOverlapping] matching the given query parameters.
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
  Future<UniqueOverlapping?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueOverlapping>(
      where: where?.call(UniqueOverlapping.t),
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueOverlapping] by its [id] or null if no such row exists.
  Future<UniqueOverlapping?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueOverlapping>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueOverlapping]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueOverlapping]s will have their `id` fields set.
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
  Future<List<UniqueOverlapping>> insert(
    _isd.DatabaseSession session,
    List<UniqueOverlapping> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueOverlapping>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueOverlapping] and returns the inserted row.
  ///
  /// The returned [UniqueOverlapping] will have its `id` field set.
  Future<UniqueOverlapping> insertRow(
    _isd.DatabaseSession session,
    UniqueOverlapping row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueOverlapping>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueOverlapping]s in the list and returns the resulting rows.
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
  /// The returned [UniqueOverlapping]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueOverlapping>> upsert(
    _isd.DatabaseSession session,
    List<UniqueOverlapping> rows, {
    required _isd.ColumnSelections<UniqueOverlappingTable> conflictColumns,
    _isd.ColumnSelections<UniqueOverlappingTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueOverlapping>(
      rows,
      conflictColumns: conflictColumns(UniqueOverlapping.t),
      updateColumns: updateColumns?.call(UniqueOverlapping.t),
      updateWhere: updateWhere?.call(UniqueOverlapping.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueOverlapping] and returns the resulting row.
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
  /// The returned [UniqueOverlapping] will have its `id` field set.
  Future<UniqueOverlapping?> upsertRow(
    _isd.DatabaseSession session,
    UniqueOverlapping row, {
    required _isd.ColumnSelections<UniqueOverlappingTable> conflictColumns,
    _isd.ColumnSelections<UniqueOverlappingTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueOverlapping>(
      row,
      conflictColumns: conflictColumns(UniqueOverlapping.t),
      updateColumns: updateColumns?.call(UniqueOverlapping.t),
      updateWhere: updateWhere?.call(UniqueOverlapping.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueOverlapping]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueOverlapping>> update(
    _isd.DatabaseSession session,
    List<UniqueOverlapping> rows, {
    _isd.ColumnSelections<UniqueOverlappingTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueOverlapping>(
      rows,
      columns: columns?.call(UniqueOverlapping.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueOverlapping]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueOverlapping> updateRow(
    _isd.DatabaseSession session,
    UniqueOverlapping row, {
    _isd.ColumnSelections<UniqueOverlappingTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueOverlapping>(
      row,
      columns: columns?.call(UniqueOverlapping.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueOverlapping] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueOverlapping?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueOverlappingUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueOverlapping>(
      id,
      columnValues: columnValues(UniqueOverlapping.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueOverlapping]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueOverlapping>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueOverlappingUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<UniqueOverlappingTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueOverlapping>(
      columnValues: columnValues(UniqueOverlapping.t.updateTable),
      where: where(UniqueOverlapping.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueOverlapping]s in the list and returns the deleted rows.
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
  Future<List<UniqueOverlapping>> delete(
    _isd.DatabaseSession session,
    List<UniqueOverlapping> rows, {
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueOverlapping>(
      rows,
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueOverlapping].
  Future<UniqueOverlapping> deleteRow(
    _isd.DatabaseSession session,
    UniqueOverlapping row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueOverlapping>(
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
  Future<List<UniqueOverlapping>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueOverlappingTable> where,
    _isd.OrderByBuilder<UniqueOverlappingTable>? orderBy,
    _isd.OrderByListBuilder<UniqueOverlappingTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueOverlapping>(
      where: where(UniqueOverlapping.t),
      orderBy: orderBy?.call(UniqueOverlapping.t),
      orderByList: orderByList?.call(UniqueOverlapping.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueOverlappingTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<UniqueOverlapping>(
      where: where?.call(UniqueOverlapping.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueOverlapping] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueOverlappingTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueOverlapping>(
      where: where(UniqueOverlapping.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
