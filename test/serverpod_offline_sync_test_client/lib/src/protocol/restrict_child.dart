/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _imkb9kra;
import 'person.dart' as _iensfz4m;

abstract class RestrictChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  RestrictChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parent,
    this.parentId,
  });

  factory RestrictChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iensfz4m.Person? parent,
    _isc.UuidValue? parentId,
  }) = _RestrictChildImpl;

  factory RestrictChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return RestrictChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parent: jsonSerialization['parent'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
    );
  }

  static final t = RestrictChildTable();

  static const db = RestrictChildRepository._();

  @override
  _isc.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _iensfz4m.Person? parent;

  _isc.UuidValue? parentId;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [RestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RestrictChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _iensfz4m.Person? parent,
    _isc.UuidValue? parentId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parent != null) 'parent': parent?.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RestrictChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
      if (parentId != null) 'parentId': parentId?.toJson(),
    };
  }

  static RestrictChildInclude include({_iensfz4m.PersonInclude? parent}) {
    return RestrictChildInclude._(parent: parent);
  }

  static RestrictChildIncludeList includeList({
    _isd.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
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
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RestrictChildImpl extends RestrictChild {
  _RestrictChildImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iensfz4m.Person? parent,
    _isc.UuidValue? parentId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parent: parent,
         parentId: parentId,
       );

  /// Returns a shallow copy of this [RestrictChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RestrictChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parent = _Undefined,
    Object? parentId = _Undefined,
  }) {
    return RestrictChild(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
      parentId: parentId is _isc.UuidValue? ? parentId : this.parentId,
    );
  }
}

class RestrictChildUpdateTable extends _isd.UpdateTable<RestrictChildTable> {
  RestrictChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> parentId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.parentId,
    value,
  );
}

class RestrictChildTable extends _isd.Table<_isc.UuidValue?> {
  RestrictChildTable({super.tableRelation})
    : super(tableName: 'restrict_child') {
    updateTable = RestrictChildUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    parentId = _isd.ColumnUuid(
      'parentId',
      this,
    );
  }

  late final RestrictChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  _iensfz4m.PersonTable? _parent;

  late final _isd.ColumnUuid parentId;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
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
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
    parentId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class RestrictChildInclude extends _isd.IncludeObject {
  RestrictChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {'parent': _parent};

  @override
  _isd.Table<_isc.UuidValue?> get table => RestrictChild.t;
}

class RestrictChildIncludeList extends _isd.IncludeList {
  RestrictChildIncludeList._({
    _isd.WhereExpressionBuilder<RestrictChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RestrictChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => RestrictChild.t;
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    RestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RestrictChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
    RestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    RestrictChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<RestrictChild> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    RestrictChild row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<RestrictChild> rows, {
    required _isd.ColumnSelections<RestrictChildTable> conflictColumns,
    _isd.ColumnSelections<RestrictChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<RestrictChildTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    RestrictChild row, {
    required _isd.ColumnSelections<RestrictChildTable> conflictColumns,
    _isd.ColumnSelections<RestrictChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<RestrictChildTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<RestrictChild> rows, {
    _isd.ColumnSelections<RestrictChildTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    RestrictChild row, {
    _isd.ColumnSelections<RestrictChildTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<RestrictChildUpdateTable> columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<RestrictChildUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<RestrictChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<RestrictChild> rows, {
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    RestrictChild row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<RestrictChildTable> where,
    _isd.OrderByBuilder<RestrictChildTable>? orderBy,
    _isd.OrderByListBuilder<RestrictChildTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RestrictChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<RestrictChild>(
      where: where?.call(RestrictChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RestrictChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<RestrictChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
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
    _isd.DatabaseSession session,
    RestrictChild restrictChild,
    _iensfz4m.Person parent, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    RestrictChild restrictChild, {
    _isd.Transaction? transaction,
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
