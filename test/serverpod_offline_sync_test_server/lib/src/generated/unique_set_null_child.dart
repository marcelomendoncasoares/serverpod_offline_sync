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
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _ixxccm81;
import 'person.dart' as _iensfz4m;

abstract class UniqueSetNullChild
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parent,
    this.parentId,
  });

  factory UniqueSetNullChild({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _iensfz4m.Person? parent,
    _is.UuidValue? parentId,
  }) = _UniqueSetNullChildImpl;

  factory UniqueSetNullChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parent: jsonSerialization['parent'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
    );
  }

  static final t = UniqueSetNullChildTable();

  static const db = UniqueSetNullChildRepository._();

  @override
  _is.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _iensfz4m.Person? parent;

  _is.UuidValue? parentId;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueSetNullChild copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _iensfz4m.Person? parent,
    _is.UuidValue? parentId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueSetNullChild',
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
      '__className__': 'UniqueSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
      if (parentId != null) 'parentId': parentId?.toJson(),
    };
  }

  static UniqueSetNullChildInclude include({_iensfz4m.PersonInclude? parent}) {
    return UniqueSetNullChildInclude._(parent: parent);
  }

  static UniqueSetNullChildIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    UniqueSetNullChildInclude? include,
  }) {
    return UniqueSetNullChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueSetNullChildImpl extends UniqueSetNullChild {
  _UniqueSetNullChildImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _iensfz4m.Person? parent,
    _is.UuidValue? parentId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parent: parent,
         parentId: parentId,
       );

  /// Returns a shallow copy of this [UniqueSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parent = _Undefined,
    Object? parentId = _Undefined,
  }) {
    return UniqueSetNullChild(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
    );
  }
}

class UniqueSetNullChildUpdateTable
    extends _is.UpdateTable<UniqueSetNullChildTable> {
  UniqueSetNullChildUpdateTable(super.table);

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

class UniqueSetNullChildTable extends _is.Table<_is.UuidValue?> {
  UniqueSetNullChildTable({super.tableRelation})
    : super(tableName: 'unique_set_null_child') {
    updateTable = UniqueSetNullChildUpdateTable(this);
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

  late final UniqueSetNullChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  _iensfz4m.PersonTable? _parent;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueSetNullChild.t.parentId,
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

class UniqueSetNullChildInclude extends _is.IncludeObject {
  UniqueSetNullChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueSetNullChild.t;
}

class UniqueSetNullChildIncludeList extends _is.IncludeList {
  UniqueSetNullChildIncludeList._({
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueSetNullChild.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueSetNullChild.t;
}

class UniqueSetNullChildRepository {
  const UniqueSetNullChildRepository._();

  final attachRow = const UniqueSetNullChildAttachRowRepository._();

  final detachRow = const UniqueSetNullChildDetachRowRepository._();

  /// Returns a list of [UniqueSetNullChild]s matching the given query parameters.
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
  Future<List<UniqueSetNullChild>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueSetNullChild>(
      where: where?.call(UniqueSetNullChild.t),
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueSetNullChild] matching the given query parameters.
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
  Future<UniqueSetNullChild?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueSetNullChild>(
      where: where?.call(UniqueSetNullChild.t),
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueSetNullChild] by its [id] or null if no such row exists.
  Future<UniqueSetNullChild?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueSetNullChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueSetNullChild]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueSetNullChild]s will have their `id` fields set.
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
  Future<List<UniqueSetNullChild>> insert(
    _is.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueSetNullChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueSetNullChild] and returns the inserted row.
  ///
  /// The returned [UniqueSetNullChild] will have its `id` field set.
  Future<UniqueSetNullChild> insertRow(
    _is.DatabaseSession session,
    UniqueSetNullChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueSetNullChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueSetNullChild]s in the list and returns the resulting rows.
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
  /// The returned [UniqueSetNullChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetNullChild>> upsert(
    _is.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    required _is.ColumnSelections<UniqueSetNullChildTable> conflictColumns,
    _is.ColumnSelections<UniqueSetNullChildTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueSetNullChild>(
      rows,
      conflictColumns: conflictColumns(UniqueSetNullChild.t),
      updateColumns: updateColumns?.call(UniqueSetNullChild.t),
      updateWhere: updateWhere?.call(UniqueSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueSetNullChild] and returns the resulting row.
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
  /// The returned [UniqueSetNullChild] will have its `id` field set.
  Future<UniqueSetNullChild?> upsertRow(
    _is.DatabaseSession session,
    UniqueSetNullChild row, {
    required _is.ColumnSelections<UniqueSetNullChildTable> conflictColumns,
    _is.ColumnSelections<UniqueSetNullChildTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueSetNullChild>(
      row,
      conflictColumns: conflictColumns(UniqueSetNullChild.t),
      updateColumns: updateColumns?.call(UniqueSetNullChild.t),
      updateWhere: updateWhere?.call(UniqueSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueSetNullChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetNullChild>> update(
    _is.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _is.ColumnSelections<UniqueSetNullChildTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueSetNullChild>(
      rows,
      columns: columns?.call(UniqueSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueSetNullChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueSetNullChild> updateRow(
    _is.DatabaseSession session,
    UniqueSetNullChild row, {
    _is.ColumnSelections<UniqueSetNullChildTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueSetNullChild>(
      row,
      columns: columns?.call(UniqueSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueSetNullChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueSetNullChild?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueSetNullChildUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueSetNullChild>(
      id,
      columnValues: columnValues(UniqueSetNullChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueSetNullChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetNullChild>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueSetNullChildUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueSetNullChild>(
      columnValues: columnValues(UniqueSetNullChild.t.updateTable),
      where: where(UniqueSetNullChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueSetNullChild]s in the list and returns the deleted rows.
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
  Future<List<UniqueSetNullChild>> delete(
    _is.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueSetNullChild>(
      rows,
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueSetNullChild].
  Future<UniqueSetNullChild> deleteRow(
    _is.DatabaseSession session,
    UniqueSetNullChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueSetNullChild>(
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
  Future<List<UniqueSetNullChild>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    _is.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueSetNullChild>(
      where: where(UniqueSetNullChild.t),
      orderBy: orderBy?.call(UniqueSetNullChild.t),
      orderByList: orderByList?.call(UniqueSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueSetNullChild>(
      where: where?.call(UniqueSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueSetNullChild>(
      where: where(UniqueSetNullChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueSetNullChildAttachRowRepository {
  const UniqueSetNullChildAttachRowRepository._();

  /// Creates a relation between the given [UniqueSetNullChild] and [Person]
  /// by setting the [UniqueSetNullChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueSetNullChild uniqueSetNullChild,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueSetNullChild.id == null) {
      throw ArgumentError.notNull('uniqueSetNullChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $uniqueSetNullChild = uniqueSetNullChild.copyWith(parentId: parent.id);
    await session.db.updateRow<UniqueSetNullChild>(
      $uniqueSetNullChild,
      columns: [UniqueSetNullChild.t.parentId],
      transaction: transaction,
    );
  }
}

class UniqueSetNullChildDetachRowRepository {
  const UniqueSetNullChildDetachRowRepository._();

  /// Detaches the relation between this [UniqueSetNullChild] and the [Person] set in `parent`
  /// by setting the [UniqueSetNullChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueSetNullChild uniqueSetNullChild, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueSetNullChild.id == null) {
      throw ArgumentError.notNull('uniqueSetNullChild.id');
    }

    var $uniqueSetNullChild = uniqueSetNullChild.copyWith(parentId: null);
    await session.db.updateRow<UniqueSetNullChild>(
      $uniqueSetNullChild,
      columns: [UniqueSetNullChild.t.parentId],
      transaction: transaction,
    );
  }
}
