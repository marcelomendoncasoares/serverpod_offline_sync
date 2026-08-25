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

abstract class Unique
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  Unique._({
    this.id,
    this.scopeId,
    required this.name,
  });

  factory Unique({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
  }) = _UniqueImpl;

  factory Unique.fromJson(Map<String, dynamic> jsonSerialization) {
    return Unique(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = UniqueTable();

  static const db = UniqueRepository._();

  @override
  _isc.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Unique]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Unique copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Unique',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Unique',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
    };
  }

  static UniqueInclude include() {
    return UniqueInclude._();
  }

  static UniqueIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    UniqueInclude? include,
  }) {
    return UniqueIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueImpl extends Unique {
  _UniqueImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
       );

  /// Returns a shallow copy of this [Unique]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Unique copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
  }) {
    return Unique(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
    );
  }
}

class UniqueUpdateTable extends _isd.UpdateTable<UniqueTable> {
  UniqueUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );
}

class UniqueTable extends _isd.Table<_isc.UuidValue?> {
  UniqueTable({super.tableRelation}) : super(tableName: 'unique') {
    updateTable = UniqueUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
  }

  late final UniqueUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
  ];
}

class UniqueInclude extends _isd.IncludeObject {
  UniqueInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_isc.UuidValue?> get table => Unique.t;
}

class UniqueIncludeList extends _isd.IncludeList {
  UniqueIncludeList._({
    _isd.WhereExpressionBuilder<UniqueTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Unique.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => Unique.t;
}

class UniqueRepository {
  const UniqueRepository._();

  /// Returns a list of [Unique]s matching the given query parameters.
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
  Future<List<Unique>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Unique>(
      where: where?.call(Unique.t),
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Unique] matching the given query parameters.
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
  Future<Unique?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Unique>(
      where: where?.call(Unique.t),
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Unique] by its [id] or null if no such row exists.
  Future<Unique?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Unique>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Unique]s in the list and returns the inserted rows.
  ///
  /// The returned [Unique]s will have their `id` fields set.
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
  Future<List<Unique>> insert(
    _isd.DatabaseSession session,
    List<Unique> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Unique>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Unique] and returns the inserted row.
  ///
  /// The returned [Unique] will have its `id` field set.
  Future<Unique> insertRow(
    _isd.DatabaseSession session,
    Unique row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Unique>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Unique]s in the list and returns the resulting rows.
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
  /// The returned [Unique]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Unique>> upsert(
    _isd.DatabaseSession session,
    List<Unique> rows, {
    required _isd.ColumnSelections<UniqueTable> conflictColumns,
    _isd.ColumnSelections<UniqueTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Unique>(
      rows,
      conflictColumns: conflictColumns(Unique.t),
      updateColumns: updateColumns?.call(Unique.t),
      updateWhere: updateWhere?.call(Unique.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Unique] and returns the resulting row.
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
  /// The returned [Unique] will have its `id` field set.
  Future<Unique?> upsertRow(
    _isd.DatabaseSession session,
    Unique row, {
    required _isd.ColumnSelections<UniqueTable> conflictColumns,
    _isd.ColumnSelections<UniqueTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Unique>(
      row,
      conflictColumns: conflictColumns(Unique.t),
      updateColumns: updateColumns?.call(Unique.t),
      updateWhere: updateWhere?.call(Unique.t),
      transaction: transaction,
    );
  }

  /// Updates all [Unique]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Unique>> update(
    _isd.DatabaseSession session,
    List<Unique> rows, {
    _isd.ColumnSelections<UniqueTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Unique>(
      rows,
      columns: columns?.call(Unique.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Unique]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Unique> updateRow(
    _isd.DatabaseSession session,
    Unique row, {
    _isd.ColumnSelections<UniqueTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Unique>(
      row,
      columns: columns?.call(Unique.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Unique] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Unique?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Unique>(
      id,
      columnValues: columnValues(Unique.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Unique]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Unique>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<UniqueTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Unique>(
      columnValues: columnValues(Unique.t.updateTable),
      where: where(Unique.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Unique]s in the list and returns the deleted rows.
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
  Future<List<Unique>> delete(
    _isd.DatabaseSession session,
    List<Unique> rows, {
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Unique>(
      rows,
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Unique].
  Future<Unique> deleteRow(
    _isd.DatabaseSession session,
    Unique row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Unique>(
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
  Future<List<Unique>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueTable> where,
    _isd.OrderByBuilder<UniqueTable>? orderBy,
    _isd.OrderByListBuilder<UniqueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Unique>(
      where: where(Unique.t),
      orderBy: orderBy?.call(Unique.t),
      orderByList: orderByList?.call(Unique.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Unique>(
      where: where?.call(Unique.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Unique] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Unique>(
      where: where(Unique.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
