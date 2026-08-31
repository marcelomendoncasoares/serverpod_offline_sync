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

abstract class RequiredSetNullChild
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  RequiredSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    required this.parentId,
    this.parent,
  });

  factory RequiredSetNullChild({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    required _is.UuidValue parentId,
    _iensfz4m.Person? parent,
  }) = _RequiredSetNullChildImpl;

  factory RequiredSetNullChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RequiredSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parentId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['parentId'],
      ),
      parent: jsonSerialization['parent'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = RequiredSetNullChildTable();

  static const db = RequiredSetNullChildRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _is.UuidValue parentId;

  _iensfz4m.Person? parent;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [RequiredSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  RequiredSetNullChild copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RequiredSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      'parentId': parentId.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RequiredSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      'parentId': parentId.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static RequiredSetNullChildInclude include({
    _iensfz4m.PersonInclude? parent,
  }) {
    return RequiredSetNullChildInclude._(parent: parent);
  }

  static RequiredSetNullChildIncludeList includeList({
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    RequiredSetNullChildInclude? include,
  }) {
    return RequiredSetNullChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RequiredSetNullChildImpl extends RequiredSetNullChild {
  _RequiredSetNullChildImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    required _is.UuidValue parentId,
    _iensfz4m.Person? parent,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [RequiredSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  RequiredSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    _is.UuidValue? parentId,
    Object? parent = _Undefined,
  }) {
    return RequiredSetNullChild(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class RequiredSetNullChildUpdateTable
    extends _is.UpdateTable<RequiredSetNullChildTable> {
  RequiredSetNullChildUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> parentId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.parentId,
        value,
      );
}

class RequiredSetNullChildTable extends _is.Table<_is.UuidValue?> {
  RequiredSetNullChildTable({super.tableRelation})
    : super(tableName: 'required_set_null_child') {
    updateTable = RequiredSetNullChildUpdateTable(this);
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

  late final RequiredSetNullChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: RequiredSetNullChild.t.parentId,
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

class RequiredSetNullChildInclude extends _is.IncludeObject {
  RequiredSetNullChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => RequiredSetNullChild.t;
}

class RequiredSetNullChildIncludeList extends _is.IncludeList {
  RequiredSetNullChildIncludeList._({
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RequiredSetNullChild.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => RequiredSetNullChild.t;
}

class RequiredSetNullChildRepository {
  const RequiredSetNullChildRepository._();

  final attachRow = const RequiredSetNullChildAttachRowRepository._();

  /// Returns a list of [RequiredSetNullChild]s matching the given query parameters.
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
  Future<List<RequiredSetNullChild>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RequiredSetNullChild>(
      where: where?.call(RequiredSetNullChild.t),
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RequiredSetNullChild] matching the given query parameters.
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
  Future<RequiredSetNullChild?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? offset,
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RequiredSetNullChild>(
      where: where?.call(RequiredSetNullChild.t),
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RequiredSetNullChild] by its [id] or null if no such row exists.
  Future<RequiredSetNullChild?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RequiredSetNullChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RequiredSetNullChild]s in the list and returns the inserted rows.
  ///
  /// The returned [RequiredSetNullChild]s will have their `id` fields set.
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
  Future<List<RequiredSetNullChild>> insert(
    _is.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<RequiredSetNullChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [RequiredSetNullChild] and returns the inserted row.
  ///
  /// The returned [RequiredSetNullChild] will have its `id` field set.
  Future<RequiredSetNullChild> insertRow(
    _is.DatabaseSession session,
    RequiredSetNullChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<RequiredSetNullChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [RequiredSetNullChild]s in the list and returns the resulting rows.
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
  /// The returned [RequiredSetNullChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredSetNullChild>> upsert(
    _is.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    required _is.ColumnSelections<RequiredSetNullChildTable> conflictColumns,
    _is.ColumnSelections<RequiredSetNullChildTable>? updateColumns,
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<RequiredSetNullChild>(
      rows,
      conflictColumns: conflictColumns(RequiredSetNullChild.t),
      updateColumns: updateColumns?.call(RequiredSetNullChild.t),
      updateWhere: updateWhere?.call(RequiredSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [RequiredSetNullChild] and returns the resulting row.
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
  /// The returned [RequiredSetNullChild] will have its `id` field set.
  Future<RequiredSetNullChild?> upsertRow(
    _is.DatabaseSession session,
    RequiredSetNullChild row, {
    required _is.ColumnSelections<RequiredSetNullChildTable> conflictColumns,
    _is.ColumnSelections<RequiredSetNullChildTable>? updateColumns,
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<RequiredSetNullChild>(
      row,
      conflictColumns: conflictColumns(RequiredSetNullChild.t),
      updateColumns: updateColumns?.call(RequiredSetNullChild.t),
      updateWhere: updateWhere?.call(RequiredSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [RequiredSetNullChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredSetNullChild>> update(
    _is.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _is.ColumnSelections<RequiredSetNullChildTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<RequiredSetNullChild>(
      rows,
      columns: columns?.call(RequiredSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [RequiredSetNullChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RequiredSetNullChild> updateRow(
    _is.DatabaseSession session,
    RequiredSetNullChild row, {
    _is.ColumnSelections<RequiredSetNullChildTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<RequiredSetNullChild>(
      row,
      columns: columns?.call(RequiredSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RequiredSetNullChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RequiredSetNullChild?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<RequiredSetNullChildUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<RequiredSetNullChild>(
      id,
      columnValues: columnValues(RequiredSetNullChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RequiredSetNullChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredSetNullChild>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<RequiredSetNullChildUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<RequiredSetNullChild>(
      columnValues: columnValues(RequiredSetNullChild.t.updateTable),
      where: where(RequiredSetNullChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [RequiredSetNullChild]s in the list and returns the deleted rows.
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
  Future<List<RequiredSetNullChild>> delete(
    _is.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<RequiredSetNullChild>(
      rows,
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [RequiredSetNullChild].
  Future<RequiredSetNullChild> deleteRow(
    _is.DatabaseSession session,
    RequiredSetNullChild row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RequiredSetNullChild>(
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
  Future<List<RequiredSetNullChild>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    _is.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _is.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<RequiredSetNullChild>(
      where: where(RequiredSetNullChild.t),
      orderBy: orderBy?.call(RequiredSetNullChild.t),
      orderByList: orderByList?.call(RequiredSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<RequiredSetNullChild>(
      where: where?.call(RequiredSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RequiredSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RequiredSetNullChild>(
      where: where(RequiredSetNullChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class RequiredSetNullChildAttachRowRepository {
  const RequiredSetNullChildAttachRowRepository._();

  /// Creates a relation between the given [RequiredSetNullChild] and [Person]
  /// by setting the [RequiredSetNullChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    RequiredSetNullChild requiredSetNullChild,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (requiredSetNullChild.id == null) {
      throw ArgumentError.notNull('requiredSetNullChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $requiredSetNullChild = requiredSetNullChild.copyWith(
      parentId: parent.id,
    );
    await session.db.updateRow<RequiredSetNullChild>(
      $requiredSetNullChild,
      columns: [RequiredSetNullChild.t.parentId],
      transaction: transaction,
    );
  }
}
