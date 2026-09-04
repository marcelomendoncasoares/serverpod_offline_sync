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

abstract class UniqueCascadeChild
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueCascadeChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory UniqueCascadeChild({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) = _UniqueCascadeChildImpl;

  factory UniqueCascadeChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueCascadeChild(
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

  static final t = UniqueCascadeChildTable();

  static const db = UniqueCascadeChildRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _is.UuidValue? parentId;

  _iensfz4m.Person? parent;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueCascadeChild copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueCascadeChild',
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
      '__className__': 'UniqueCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static UniqueCascadeChildInclude include({_iensfz4m.PersonInclude? parent}) {
    return UniqueCascadeChildInclude._(parent: parent);
  }

  static UniqueCascadeChildIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    UniqueCascadeChildInclude? include,
  }) {
    return UniqueCascadeChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueCascadeChildImpl extends UniqueCascadeChild {
  _UniqueCascadeChildImpl({
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

  /// Returns a shallow copy of this [UniqueCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueCascadeChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return UniqueCascadeChild(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class UniqueCascadeChildUpdateTable
    extends _is.UpdateTable<UniqueCascadeChildTable> {
  UniqueCascadeChildUpdateTable(super.table);

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

class UniqueCascadeChildTable extends _is.Table<_is.UuidValue?> {
  UniqueCascadeChildTable({super.tableRelation})
    : super(tableName: 'unique_cascade_child') {
    updateTable = UniqueCascadeChildUpdateTable(this);
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

  late final UniqueCascadeChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueCascadeChild.t.parentId,
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

class UniqueCascadeChildInclude extends _is.IncludeObject {
  UniqueCascadeChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueCascadeChild.t;
}

class UniqueCascadeChildIncludeList extends _is.IncludeList {
  UniqueCascadeChildIncludeList._({
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueCascadeChild.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueCascadeChild.t;
}

class UniqueCascadeChildRepository {
  const UniqueCascadeChildRepository._();

  final attachRow = const UniqueCascadeChildAttachRowRepository._();

  final detachRow = const UniqueCascadeChildDetachRowRepository._();

  /// Returns a list of [UniqueCascadeChild]s matching the given query parameters.
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
  Future<List<UniqueCascadeChild>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    _is.Transaction? transaction,
    UniqueCascadeChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueCascadeChild>(
      where: where?.call(UniqueCascadeChild.t),
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueCascadeChild] matching the given query parameters.
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
  Future<UniqueCascadeChild?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    _is.Transaction? transaction,
    UniqueCascadeChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueCascadeChild>(
      where: where?.call(UniqueCascadeChild.t),
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueCascadeChild] by its [id] or null if no such row exists.
  Future<UniqueCascadeChild?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    UniqueCascadeChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueCascadeChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueCascadeChild]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueCascadeChild]s will have their `id` fields set.
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
  Future<List<UniqueCascadeChild>> insert(
    _is.DatabaseSession session,
    List<UniqueCascadeChild> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueCascadeChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueCascadeChild] and returns the inserted row.
  ///
  /// The returned [UniqueCascadeChild] will have its `id` field set.
  Future<UniqueCascadeChild> insertRow(
    _is.DatabaseSession session,
    UniqueCascadeChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueCascadeChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueCascadeChild]s in the list and returns the resulting rows.
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
  /// The returned [UniqueCascadeChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeChild>> upsert(
    _is.DatabaseSession session,
    List<UniqueCascadeChild> rows, {
    required _is.ColumnSelections<UniqueCascadeChildTable> conflictColumns,
    _is.ColumnSelections<UniqueCascadeChildTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueCascadeChild>(
      rows,
      conflictColumns: conflictColumns(UniqueCascadeChild.t),
      updateColumns: updateColumns?.call(UniqueCascadeChild.t),
      updateWhere: updateWhere?.call(UniqueCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueCascadeChild] and returns the resulting row.
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
  /// The returned [UniqueCascadeChild] will have its `id` field set.
  Future<UniqueCascadeChild?> upsertRow(
    _is.DatabaseSession session,
    UniqueCascadeChild row, {
    required _is.ColumnSelections<UniqueCascadeChildTable> conflictColumns,
    _is.ColumnSelections<UniqueCascadeChildTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueCascadeChild>(
      row,
      conflictColumns: conflictColumns(UniqueCascadeChild.t),
      updateColumns: updateColumns?.call(UniqueCascadeChild.t),
      updateWhere: updateWhere?.call(UniqueCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueCascadeChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeChild>> update(
    _is.DatabaseSession session,
    List<UniqueCascadeChild> rows, {
    _is.ColumnSelections<UniqueCascadeChildTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueCascadeChild>(
      rows,
      columns: columns?.call(UniqueCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueCascadeChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueCascadeChild> updateRow(
    _is.DatabaseSession session,
    UniqueCascadeChild row, {
    _is.ColumnSelections<UniqueCascadeChildTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueCascadeChild>(
      row,
      columns: columns?.call(UniqueCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueCascadeChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueCascadeChild?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueCascadeChildUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueCascadeChild>(
      id,
      columnValues: columnValues(UniqueCascadeChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueCascadeChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeChild>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueCascadeChildUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UniqueCascadeChildTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueCascadeChild>(
      columnValues: columnValues(UniqueCascadeChild.t.updateTable),
      where: where(UniqueCascadeChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueCascadeChild]s in the list and returns the deleted rows.
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
  Future<List<UniqueCascadeChild>> delete(
    _is.DatabaseSession session,
    List<UniqueCascadeChild> rows, {
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueCascadeChild>(
      rows,
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueCascadeChild].
  Future<UniqueCascadeChild> deleteRow(
    _is.DatabaseSession session,
    UniqueCascadeChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueCascadeChild>(
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
  Future<List<UniqueCascadeChild>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueCascadeChildTable> where,
    _is.OrderByBuilder<UniqueCascadeChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueCascadeChild>(
      where: where(UniqueCascadeChild.t),
      orderBy: orderBy?.call(UniqueCascadeChild.t),
      orderByList: orderByList?.call(UniqueCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeChildTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueCascadeChild>(
      where: where?.call(UniqueCascadeChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueCascadeChild] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueCascadeChildTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueCascadeChild>(
      where: where(UniqueCascadeChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueCascadeChildAttachRowRepository {
  const UniqueCascadeChildAttachRowRepository._();

  /// Creates a relation between the given [UniqueCascadeChild] and [Person]
  /// by setting the [UniqueCascadeChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueCascadeChild uniqueCascadeChild,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueCascadeChild.id == null) {
      throw ArgumentError.notNull('uniqueCascadeChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $uniqueCascadeChild = uniqueCascadeChild.copyWith(parentId: parent.id);
    await session.db.updateRow<UniqueCascadeChild>(
      $uniqueCascadeChild,
      columns: [UniqueCascadeChild.t.parentId],
      transaction: transaction,
    );
  }
}

class UniqueCascadeChildDetachRowRepository {
  const UniqueCascadeChildDetachRowRepository._();

  /// Detaches the relation between this [UniqueCascadeChild] and the [Person] set in `parent`
  /// by setting the [UniqueCascadeChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueCascadeChild uniqueCascadeChild, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueCascadeChild.id == null) {
      throw ArgumentError.notNull('uniqueCascadeChild.id');
    }

    var $uniqueCascadeChild = uniqueCascadeChild.copyWith(parentId: null);
    await session.db.updateRow<UniqueCascadeChild>(
      $uniqueCascadeChild,
      columns: [UniqueCascadeChild.t.parentId],
      transaction: transaction,
    );
  }
}
