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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync_test_shared/serverpod_offline_sync_test_shared.dart'
    as _i2ap9bqs;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A synchronized parent owned by a shared package rather than the server.
abstract class SharedParent
    implements _isd.TableRow<_iss.UuidValue?>, _iss.ProtocolSerialization {
  SharedParent._({this.id, this.scopeId, required this.name, this.children});

  factory SharedParent({
    _iss.UuidValue? id,
    int? scopeId,
    required String name,
    List<_i2ap9bqs.SharedChild>? children,
  }) = _SharedParentImpl;

  factory SharedParent.fromJson(Map<String, dynamic> jsonSerialization) {
    return SharedParent(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      children: jsonSerialization['children'] == null
          ? null
          : _i2ap9bqs.Protocol().deserialize<List<_i2ap9bqs.SharedChild>>(
              jsonSerialization['children'],
            ),
    );
  }

  static final t = SharedParentTable();

  static const db = SharedParentRepository._();

  @override
  _iss.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  List<_i2ap9bqs.SharedChild>? children;

  @override
  _isd.Table<_iss.UuidValue?> get table => t;

  /// Returns a shallow copy of this [SharedParent]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SharedParent copyWith({
    _iss.UuidValue? id,
    int? scopeId,
    String? name,
    List<_i2ap9bqs.SharedChild>? children,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SharedParent',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (children != null)
        'children': children?.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SharedParent',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (children != null)
        'children': children?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  static SharedParentInclude include({
    _i2ap9bqs.SharedChildIncludeList? children,
  }) {
    return SharedParentInclude._(children: children);
  }

  static SharedParentIncludeList includeList({
    _isd.WhereExpressionBuilder<SharedParentTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    SharedParentInclude? include,
  }) {
    return SharedParentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SharedParentImpl extends SharedParent {
  _SharedParentImpl({
    _iss.UuidValue? id,
    int? scopeId,
    required String name,
    List<_i2ap9bqs.SharedChild>? children,
  }) : super._(id: id, scopeId: scopeId, name: name, children: children);

  /// Returns a shallow copy of this [SharedParent]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SharedParent copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? children = _Undefined,
  }) {
    return SharedParent(
      id: id is _iss.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      children: children is List<_i2ap9bqs.SharedChild>?
          ? children
          : this.children?.map((e0) => e0.copyWith()).toList(),
    );
  }
}

class SharedParentUpdateTable extends _isd.UpdateTable<SharedParentTable> {
  SharedParentUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) =>
      _isd.ColumnValue(table.scopeId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);
}

class SharedParentTable extends _isd.Table<_iss.UuidValue?> {
  SharedParentTable({super.tableRelation}) : super(tableName: 'shared_parent') {
    updateTable = SharedParentUpdateTable(this);
    scopeId = _isd.ColumnInt('scopeId', this);
    name = _isd.ColumnString('name', this);
  }

  late final SharedParentUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  _i2ap9bqs.SharedChildTable? ___children;

  _isd.ManyRelation<_i2ap9bqs.SharedChildTable>? _children;

  _i2ap9bqs.SharedChildTable get __children {
    if (___children != null) return ___children!;
    ___children = _isd.createRelationTable(
      relationFieldName: '__children',
      field: SharedParent.t.id,
      foreignField: _i2ap9bqs.SharedChild.t.parentId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2ap9bqs.SharedChildTable(tableRelation: foreignTableRelation),
    );
    return ___children!;
  }

  _isd.ManyRelation<_i2ap9bqs.SharedChildTable> get children {
    if (_children != null) return _children!;
    var relationTable = _isd.createRelationTable(
      relationFieldName: 'children',
      field: SharedParent.t.id,
      foreignField: _i2ap9bqs.SharedChild.t.parentId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2ap9bqs.SharedChildTable(tableRelation: foreignTableRelation),
    );
    _children = _isd.ManyRelation<_i2ap9bqs.SharedChildTable>(
      tableWithRelations: relationTable,
      table: _i2ap9bqs.SharedChildTable(
        tableRelation: relationTable.tableRelation!.lastRelation,
      ),
    );
    return _children!;
  }

  @override
  List<_isd.Column> get columns => [id, scopeId, name];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'children') {
      return __children;
    }
    return null;
  }
}

class SharedParentInclude extends _isd.IncludeObject {
  SharedParentInclude._({_i2ap9bqs.SharedChildIncludeList? children}) {
    _children = children;
  }

  _i2ap9bqs.SharedChildIncludeList? _children;

  @override
  Map<String, _isd.Include?> get includes => {'children': _children};

  @override
  _isd.Table<_iss.UuidValue?> get table => SharedParent.t;
}

class SharedParentIncludeList extends _isd.IncludeList {
  SharedParentIncludeList._({
    _isd.WhereExpressionBuilder<SharedParentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SharedParent.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue?> get table => SharedParent.t;
}

class SharedParentRepository {
  const SharedParentRepository._();

  final attach = const SharedParentAttachRepository._();

  final attachRow = const SharedParentAttachRowRepository._();

  final detach = const SharedParentDetachRepository._();

  final detachRow = const SharedParentDetachRowRepository._();

  /// Returns a list of [SharedParent]s matching the given query parameters.
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
  Future<List<SharedParent>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedParentTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    _isd.Transaction? transaction,
    SharedParentInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SharedParent>(
      where: where?.call(SharedParent.t),
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SharedParent] matching the given query parameters.
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
  Future<SharedParent?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedParentTable>? where,
    int? offset,
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    _isd.Transaction? transaction,
    SharedParentInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SharedParent>(
      where: where?.call(SharedParent.t),
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SharedParent] by its [id] or null if no such row exists.
  Future<SharedParent?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SharedParentInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SharedParent>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SharedParent]s in the list and returns the inserted rows.
  ///
  /// The returned [SharedParent]s will have their `id` fields set.
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
  Future<List<SharedParent>> insert(
    _isd.DatabaseSession session,
    List<SharedParent> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SharedParent>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SharedParent] and returns the inserted row.
  ///
  /// The returned [SharedParent] will have its `id` field set.
  Future<SharedParent> insertRow(
    _isd.DatabaseSession session,
    SharedParent row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SharedParent>(row, transaction: transaction);
  }

  /// Upserts all [SharedParent]s in the list and returns the resulting rows.
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
  /// The returned [SharedParent]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedParent>> upsert(
    _isd.DatabaseSession session,
    List<SharedParent> rows, {
    required _isd.ColumnSelections<SharedParentTable> conflictColumns,
    _isd.ColumnSelections<SharedParentTable>? updateColumns,
    _isd.WhereExpressionBuilder<SharedParentTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SharedParent>(
      rows,
      conflictColumns: conflictColumns(SharedParent.t),
      updateColumns: updateColumns?.call(SharedParent.t),
      updateWhere: updateWhere?.call(SharedParent.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SharedParent] and returns the resulting row.
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
  /// The returned [SharedParent] will have its `id` field set.
  Future<SharedParent?> upsertRow(
    _isd.DatabaseSession session,
    SharedParent row, {
    required _isd.ColumnSelections<SharedParentTable> conflictColumns,
    _isd.ColumnSelections<SharedParentTable>? updateColumns,
    _isd.WhereExpressionBuilder<SharedParentTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SharedParent>(
      row,
      conflictColumns: conflictColumns(SharedParent.t),
      updateColumns: updateColumns?.call(SharedParent.t),
      updateWhere: updateWhere?.call(SharedParent.t),
      transaction: transaction,
    );
  }

  /// Updates all [SharedParent]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedParent>> update(
    _isd.DatabaseSession session,
    List<SharedParent> rows, {
    _isd.ColumnSelections<SharedParentTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SharedParent>(
      rows,
      columns: columns?.call(SharedParent.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SharedParent]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SharedParent> updateRow(
    _isd.DatabaseSession session,
    SharedParent row, {
    _isd.ColumnSelections<SharedParentTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SharedParent>(
      row,
      columns: columns?.call(SharedParent.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SharedParent] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SharedParent?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SharedParentUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SharedParent>(
      id,
      columnValues: columnValues(SharedParent.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SharedParent]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedParent>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SharedParentUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SharedParentTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SharedParent>(
      columnValues: columnValues(SharedParent.t.updateTable),
      where: where(SharedParent.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SharedParent]s in the list and returns the deleted rows.
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
  Future<List<SharedParent>> delete(
    _isd.DatabaseSession session,
    List<SharedParent> rows, {
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SharedParent>(
      rows,
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SharedParent].
  Future<SharedParent> deleteRow(
    _isd.DatabaseSession session,
    SharedParent row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SharedParent>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedParent>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SharedParentTable> where,
    _isd.OrderByBuilder<SharedParentTable>? orderBy,
    _isd.OrderByListBuilder<SharedParentTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SharedParent>(
      where: where(SharedParent.t),
      orderBy: orderBy?.call(SharedParent.t),
      orderByList: orderByList?.call(SharedParent.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedParentTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SharedParent>(
      where: where?.call(SharedParent.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SharedParent] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SharedParentTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SharedParent>(
      where: where(SharedParent.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SharedParentAttachRepository {
  const SharedParentAttachRepository._();

  /// Creates a relation between this [SharedParent] and the given [SharedChild]s
  /// by setting each [SharedChild]'s foreign key `parentId` to refer to this [SharedParent].
  Future<void> children(
    _isd.DatabaseSession session,
    SharedParent sharedParent,
    List<_i2ap9bqs.SharedChild> sharedChild, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.any((e) => e.id == null)) {
      throw ArgumentError.notNull('sharedChild.id');
    }
    if (sharedParent.id == null) {
      throw ArgumentError.notNull('sharedParent.id');
    }

    var $sharedChild = sharedChild
        .map((e) => e.copyWith(parentId: sharedParent.id))
        .toList();
    await session.db.update<_i2ap9bqs.SharedChild>(
      $sharedChild,
      columns: [_i2ap9bqs.SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}

class SharedParentAttachRowRepository {
  const SharedParentAttachRowRepository._();

  /// Creates a relation between this [SharedParent] and the given [SharedChild]
  /// by setting the [SharedChild]'s foreign key `parentId` to refer to this [SharedParent].
  Future<void> children(
    _isd.DatabaseSession session,
    SharedParent sharedParent,
    _i2ap9bqs.SharedChild sharedChild, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.id == null) {
      throw ArgumentError.notNull('sharedChild.id');
    }
    if (sharedParent.id == null) {
      throw ArgumentError.notNull('sharedParent.id');
    }

    var $sharedChild = sharedChild.copyWith(parentId: sharedParent.id);
    await session.db.updateRow<_i2ap9bqs.SharedChild>(
      $sharedChild,
      columns: [_i2ap9bqs.SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}

class SharedParentDetachRepository {
  const SharedParentDetachRepository._();

  /// Detaches the relation between this [SharedParent] and the given [SharedChild]
  /// by setting the [SharedChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> children(
    _isd.DatabaseSession session,
    List<_i2ap9bqs.SharedChild> sharedChild, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.any((e) => e.id == null)) {
      throw ArgumentError.notNull('sharedChild.id');
    }

    var $sharedChild = sharedChild
        .map((e) => e.copyWith(parentId: null))
        .toList();
    await session.db.update<_i2ap9bqs.SharedChild>(
      $sharedChild,
      columns: [_i2ap9bqs.SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}

class SharedParentDetachRowRepository {
  const SharedParentDetachRowRepository._();

  /// Detaches the relation between this [SharedParent] and the given [SharedChild]
  /// by setting the [SharedChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> children(
    _isd.DatabaseSession session,
    _i2ap9bqs.SharedChild sharedChild, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.id == null) {
      throw ArgumentError.notNull('sharedChild.id');
    }

    var $sharedChild = sharedChild.copyWith(parentId: null);
    await session.db.updateRow<_i2ap9bqs.SharedChild>(
      $sharedChild,
      columns: [_i2ap9bqs.SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}
