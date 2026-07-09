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

abstract class UniqueDiscriminator
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  UniqueDiscriminator._({
    this.id,
    this.scopeId,
    required this.categoryId,
    required this.name,
  });

  factory UniqueDiscriminator({
    _i1.UuidValue? id,
    int? scopeId,
    required int categoryId,
    required String name,
  }) = _UniqueDiscriminatorImpl;

  factory UniqueDiscriminator.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueDiscriminator(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      categoryId: jsonSerialization['categoryId'] as int,
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = UniqueDiscriminatorTable();

  static const db = UniqueDiscriminatorRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  int categoryId;

  String name;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueDiscriminator]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  UniqueDiscriminator copyWith({
    _i1.UuidValue? id,
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
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    UniqueDiscriminatorInclude? include,
  }) {
    return UniqueDiscriminatorIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueDiscriminatorImpl extends UniqueDiscriminator {
  _UniqueDiscriminatorImpl({
    _i1.UuidValue? id,
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
  @_i1.useResult
  @override
  UniqueDiscriminator copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    int? categoryId,
    String? name,
  }) {
    return UniqueDiscriminator(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
    );
  }
}

class UniqueDiscriminatorUpdateTable
    extends _i1.UpdateTable<UniqueDiscriminatorTable> {
  UniqueDiscriminatorUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<int, int> categoryId(int value) => _i1.ColumnValue(
    table.categoryId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );
}

class UniqueDiscriminatorTable extends _i1.Table<_i1.UuidValue?> {
  UniqueDiscriminatorTable({super.tableRelation})
    : super(tableName: 'unique_discriminator') {
    updateTable = UniqueDiscriminatorUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    categoryId = _i1.ColumnInt(
      'categoryId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
  }

  late final UniqueDiscriminatorUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnInt categoryId;

  late final _i1.ColumnString name;

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    categoryId,
    name,
  ];
}

class UniqueDiscriminatorInclude extends _i1.IncludeObject {
  UniqueDiscriminatorInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i1.UuidValue?> get table => UniqueDiscriminator.t;
}

class UniqueDiscriminatorIncludeList extends _i1.IncludeList {
  UniqueDiscriminatorIncludeList._({
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueDiscriminator.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => UniqueDiscriminator.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? offset,
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueDiscriminator] by its [id] or null if no such row exists.
  Future<UniqueDiscriminator?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueDiscriminator row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    required _i1.ColumnSelections<UniqueDiscriminatorTable> conflictColumns,
    _i1.ColumnSelections<UniqueDiscriminatorTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueDiscriminator row, {
    required _i1.ColumnSelections<UniqueDiscriminatorTable> conflictColumns,
    _i1.ColumnSelections<UniqueDiscriminatorTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _i1.ColumnSelections<UniqueDiscriminatorTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueDiscriminator row, {
    _i1.ColumnSelections<UniqueDiscriminatorTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<UniqueDiscriminatorUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<UniqueDiscriminatorUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueDiscriminator>(
      columnValues: columnValues(UniqueDiscriminator.t.updateTable),
      where: where(UniqueDiscriminator.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i1.DatabaseSession session,
    List<UniqueDiscriminator> rows, {
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueDiscriminator>(
      rows,
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueDiscriminator].
  Future<UniqueDiscriminator> deleteRow(
    _i1.DatabaseSession session,
    UniqueDiscriminator row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    _i1.OrderByBuilder<UniqueDiscriminatorTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<UniqueDiscriminatorTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueDiscriminator>(
      where: where(UniqueDiscriminator.t),
      orderBy: orderBy?.call(UniqueDiscriminator.t),
      orderByList: orderByList?.call(UniqueDiscriminator.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueDiscriminatorTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<UniqueDiscriminator>(
      where: where?.call(UniqueDiscriminator.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueDiscriminator] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueDiscriminatorTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueDiscriminator>(
      where: where(UniqueDiscriminator.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
