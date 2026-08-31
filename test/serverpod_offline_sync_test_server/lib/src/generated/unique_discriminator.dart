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

abstract class UniqueDiscriminator
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueDiscriminator._({
    this.id,
    this.scopeId,
    required this.categoryId,
    required this.name,
  });

  factory UniqueDiscriminator({
    _is.UuidValue? id,
    int? scopeId,
    required int categoryId,
    required String name,
  }) = _UniqueDiscriminatorImpl;

  factory UniqueDiscriminator.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueDiscriminator(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      categoryId: jsonSerialization['categoryId'] as int,
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = UniqueDiscriminatorTable();

  static const db = UniqueDiscriminatorRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  int categoryId;

  String name;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueDiscriminator]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueDiscriminator copyWith({
    _is.UuidValue? id,
    int? scopeId,
    int? categoryId,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueDiscriminator',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'categoryId': categoryId,
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueDiscriminator',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'categoryId': categoryId,
      'name': name,
    };
  }

  static UniqueDiscriminatorInclude include() {
    return UniqueDiscriminatorInclude._();
  }

  static UniqueDiscriminatorIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    UniqueDiscriminatorInclude? include,
  }) {
    return UniqueDiscriminatorIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueDiscriminatorImpl extends UniqueDiscriminator {
  _UniqueDiscriminatorImpl({
    _is.UuidValue? id,
    int? scopeId,
    required int categoryId,
    required String name,
  }) : super._(
         id: id,
         scopeId: scopeId,
         categoryId: categoryId,
         name: name,
       );

  /// Returns a shallow copy of this [UniqueDiscriminator]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueDiscriminator copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    int? categoryId,
    String? name,
  }) {
    return UniqueDiscriminator(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
    );
  }
}

class UniqueDiscriminatorUpdateTable
    extends _is.UpdateTable<UniqueDiscriminatorTable> {
  UniqueDiscriminatorUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<int, int> categoryId(int value) => _is.ColumnValue(
    table.categoryId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );
}

class UniqueDiscriminatorTable extends _is.Table<_is.UuidValue?> {
  UniqueDiscriminatorTable({super.tableRelation})
    : super(tableName: 'unique_discriminator') {
    updateTable = UniqueDiscriminatorUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    categoryId = _is.ColumnInt(
      'categoryId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
  }

  late final UniqueDiscriminatorUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnInt categoryId;

  late final _is.ColumnString name;

  @override
  List<_is.Column> get columns => [
    id,
    scopeId,
    categoryId,
    name,
  ];
}

class UniqueDiscriminatorInclude extends _is.IncludeObject {
  UniqueDiscriminatorInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueDiscriminator.t;
}

class UniqueDiscriminatorIncludeList extends _is.IncludeList {
  UniqueDiscriminatorIncludeList._({
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueDiscriminator.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueDiscriminator.t;
}

class UniqueDiscriminatorRepository {
  const UniqueDiscriminatorRepository._();

  /// Returns a list of [UniqueDiscriminator]s matching the given query parameters.
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
  Future<List<UniqueDiscriminator>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueDiscriminator] matching the given query parameters.
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
  Future<UniqueDiscriminator?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueDiscriminator] by its [id] or null if no such row exists.
  Future<UniqueDiscriminator?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueDiscriminator>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueDiscriminator]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueDiscriminator]s will have their `id` fields set.
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
  Future<List<UniqueDiscriminator>> insert(
    _is.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueDiscriminator>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueDiscriminator] and returns the inserted row.
  ///
  /// The returned [UniqueDiscriminator] will have its `id` field set.
  Future<UniqueDiscriminator> insertRow(
    _is.DatabaseSession session,
    UniqueDiscriminator row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueDiscriminator>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueDiscriminator]s in the list and returns the resulting rows.
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
  /// The returned [UniqueDiscriminator]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueDiscriminator>> upsert(
    _is.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    required _is.ColumnSelections<UniqueDiscriminatorTable> conflictColumns,
    _is.ColumnSelections<UniqueDiscriminatorTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueDiscriminator>(
      rows,
      conflictColumns: conflictColumns(UniqueDiscriminator.t),
      updateColumns: updateColumns?.call(UniqueDiscriminator.t),
      updateWhere: updateWhere?.call(UniqueDiscriminator.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueDiscriminator] and returns the resulting row.
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
  /// The returned [UniqueDiscriminator] will have its `id` field set.
  Future<UniqueDiscriminator?> upsertRow(
    _is.DatabaseSession session,
    UniqueDiscriminator row, {
    required _is.ColumnSelections<UniqueDiscriminatorTable> conflictColumns,
    _is.ColumnSelections<UniqueDiscriminatorTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueDiscriminator>(
      row,
      conflictColumns: conflictColumns(UniqueDiscriminator.t),
      updateColumns: updateColumns?.call(UniqueDiscriminator.t),
      updateWhere: updateWhere?.call(UniqueDiscriminator.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueDiscriminator]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueDiscriminator>> update(
    _is.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _is.ColumnSelections<UniqueDiscriminatorTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueDiscriminator>(
      rows,
      columns: columns?.call(UniqueDiscriminator.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueDiscriminator]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueDiscriminator> updateRow(
    _is.DatabaseSession session,
    UniqueDiscriminator row, {
    _is.ColumnSelections<UniqueDiscriminatorTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueDiscriminator>(
      row,
      columns: columns?.call(UniqueDiscriminator.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueDiscriminator] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueDiscriminator?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueDiscriminatorUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueDiscriminator>(
      id,
      columnValues: columnValues(UniqueDiscriminator.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueDiscriminator]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueDiscriminator>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueDiscriminatorUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueDiscriminator>(
      columnValues: columnValues(UniqueDiscriminator.t.updateTable),
      where: where(UniqueDiscriminator.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueDiscriminator]s in the list and returns the deleted rows.
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
  Future<List<UniqueDiscriminator>> delete(
    _is.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueDiscriminator>(
      rows,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueDiscriminator].
  Future<UniqueDiscriminator> deleteRow(
    _is.DatabaseSession session,
    UniqueDiscriminator row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueDiscriminator>(
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
  Future<List<UniqueDiscriminator>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    _is.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _is.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueDiscriminator>(
      where: where(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueDiscriminator] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueDiscriminator>(
      where: where(UniqueDiscriminator.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
