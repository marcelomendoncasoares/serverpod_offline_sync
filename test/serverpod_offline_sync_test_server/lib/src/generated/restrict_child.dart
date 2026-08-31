/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, no_leading_underscores_for_library_prefixes
// ignore_for_file: unnecessary_null_comparison

import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _ixxccm81;
import 'person.dart' as _iensfz4m;

abstract class RestrictChild
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  RestrictChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory RestrictChild({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) = _RestrictChildImpl;

  factory RestrictChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return RestrictChild(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = RestrictChildTable();

  static const db = RestrictChildRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _is.UuidValue? parentId;

  _iensfz4m.Person? parent;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [RestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  RestrictChild copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static RestrictChildInclude include({_iensfz4m.PersonInclude? parent}) {
    return RestrictChildInclude._(parent: parent);
  }

  static RestrictChildIncludeList includeList({
    _is.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    RestrictChildInclude? include,
  }) {
    return RestrictChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RestrictChildImpl extends RestrictChild {
  _RestrictChildImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [RestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  RestrictChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return RestrictChild(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class RestrictChildUpdateTable extends _is.UpdateTable<RestrictChildTable> {
  RestrictChildUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> parentId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.parentId,
    value,
  );
}

class RestrictChildTable extends _is.Table<_is.UuidValue?> {
  RestrictChildTable({super.tableRelation})
    : super(tableName: 'restrict_child') {
    updateTable = RestrictChildUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    parentId = _is.ColumnUuid(
      'parentId',
      this,
    );
  }

  late final RestrictChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: RestrictChild.t.parentId,
      foreignField: _iensfz4m.Person.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iensfz4m.PersonTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    scopeId,
    name,
    parentId,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class RestrictChildInclude extends _is.IncludeObject {
  RestrictChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => RestrictChild.t;
}

class RestrictChildIncludeList extends _is.IncludeList {
  RestrictChildIncludeList._({
    _is.WhereExpressionBuilder<RestrictChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RestrictChild.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => RestrictChild.t;
}

class RestrictChildRepository {
  const RestrictChildRepository._();

  final attachRow = const RestrictChildAttachRowRepository._();

  final detachRow = const RestrictChildDetachRowRepository._();

  /// Returns a list of [RestrictChild]s matching the given query parameters.
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
  Future<List<RestrictChild>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    _is.Transaction? transaction,
    RestrictChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RestrictChild>(
      where: where?.call(RestrictChild.t),
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RestrictChild] matching the given query parameters.
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
  Future<RestrictChild?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RestrictChildTable>? where,
    int? offset,
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    _is.Transaction? transaction,
    RestrictChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RestrictChild>(
      where: where?.call(RestrictChild.t),
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RestrictChild] by its [id] or null if no such row exists.
  Future<RestrictChild?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    RestrictChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RestrictChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RestrictChild]s in the list and returns the inserted rows.
  ///
  /// The returned [RestrictChild]s will have their `id` fields set.
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
  Future<List<RestrictChild>> insert(
    _is.DatabaseSession session,
    List<RestrictChild> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<RestrictChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [RestrictChild] and returns the inserted row.
  ///
  /// The returned [RestrictChild] will have its `id` field set.
  Future<RestrictChild> insertRow(
    _is.DatabaseSession session,
    RestrictChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<RestrictChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [RestrictChild]s in the list and returns the resulting rows.
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
  /// The returned [RestrictChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RestrictChild>> upsert(
    _is.DatabaseSession session,
    List<RestrictChild> rows, {
    required _is.ColumnSelections<RestrictChildTable> conflictColumns,
    _is.ColumnSelections<RestrictChildTable>? updateColumns,
    _is.WhereExpressionBuilder<RestrictChildTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<RestrictChild>(
      rows,
      conflictColumns: conflictColumns(RestrictChild.t),
      updateColumns: updateColumns?.call(RestrictChild.t),
      updateWhere: updateWhere?.call(RestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [RestrictChild] and returns the resulting row.
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
  /// The returned [RestrictChild] will have its `id` field set.
  Future<RestrictChild?> upsertRow(
    _is.DatabaseSession session,
    RestrictChild row, {
    required _is.ColumnSelections<RestrictChildTable> conflictColumns,
    _is.ColumnSelections<RestrictChildTable>? updateColumns,
    _is.WhereExpressionBuilder<RestrictChildTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<RestrictChild>(
      row,
      conflictColumns: conflictColumns(RestrictChild.t),
      updateColumns: updateColumns?.call(RestrictChild.t),
      updateWhere: updateWhere?.call(RestrictChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [RestrictChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RestrictChild>> update(
    _is.DatabaseSession session,
    List<RestrictChild> rows, {
    _is.ColumnSelections<RestrictChildTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<RestrictChild>(
      rows,
      columns: columns?.call(RestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [RestrictChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RestrictChild> updateRow(
    _is.DatabaseSession session,
    RestrictChild row, {
    _is.ColumnSelections<RestrictChildTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<RestrictChild>(
      row,
      columns: columns?.call(RestrictChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RestrictChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RestrictChild?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<RestrictChildUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<RestrictChild>(
      id,
      columnValues: columnValues(RestrictChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RestrictChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RestrictChild>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<RestrictChildUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<RestrictChildTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<RestrictChild>(
      columnValues: columnValues(RestrictChild.t.updateTable),
      where: where(RestrictChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [RestrictChild]s in the list and returns the deleted rows.
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
  Future<List<RestrictChild>> delete(
    _is.DatabaseSession session,
    List<RestrictChild> rows, {
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<RestrictChild>(
      rows,
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [RestrictChild].
  Future<RestrictChild> deleteRow(
    _is.DatabaseSession session,
    RestrictChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RestrictChild>(
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
  Future<List<RestrictChild>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RestrictChildTable> where,
    _is.OrderByBuilder<RestrictChildTable>? orderBy,
    _is.OrderByListBuilder<RestrictChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<RestrictChild>(
      where: where(RestrictChild.t),
      orderBy: orderBy?.call(RestrictChild.t),
      orderByList: orderByList?.call(RestrictChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<RestrictChild>(
      where: where?.call(RestrictChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RestrictChild] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RestrictChildTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RestrictChild>(
      where: where(RestrictChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class RestrictChildAttachRowRepository {
  const RestrictChildAttachRowRepository._();

  /// Creates a relation between the given [RestrictChild] and [Person]
  /// by setting the [RestrictChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    RestrictChild restrictChild,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (restrictChild.id == null) {
      throw ArgumentError.notNull('restrictChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $restrictChild = restrictChild.copyWith(parentId: parent.id);
    await session.db.updateRow<RestrictChild>(
      $restrictChild,
      columns: [RestrictChild.t.parentId],
      transaction: transaction,
    );
  }
}

class RestrictChildDetachRowRepository {
  const RestrictChildDetachRowRepository._();

  /// Detaches the relation between this [RestrictChild] and the [Person] set in `parent`
  /// by setting the [RestrictChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    RestrictChild restrictChild, {
    _is.Transaction? transaction,
  }) async {
    if (restrictChild.id == null) {
      throw ArgumentError.notNull('restrictChild.id');
    }

    var $restrictChild = restrictChild.copyWith(parentId: null);
    await session.db.updateRow<RestrictChild>(
      $restrictChild,
      columns: [RestrictChild.t.parentId],
      transaction: transaction,
    );
  }
}
