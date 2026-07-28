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
import 'package:serverpod_database/serverpod_database.dart' as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import 'person.dart' as _i3;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _i4;

abstract class RequiredSetNullChild
    implements _i1.TableRow<_i2.UuidValue?>, _i2.ProtocolSerialization {
  RequiredSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parent,
    required this.parentId,
  });

  factory RequiredSetNullChild({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.Person? parent,
    required _i2.UuidValue parentId,
  }) = _RequiredSetNullChildImpl;

  factory RequiredSetNullChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RequiredSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parent: jsonSerialization['parent'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.Person>(jsonSerialization['parent']),
      parentId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['parentId'],
      ),
    );
  }

  static final t = RequiredSetNullChildTable();

  static const db = RequiredSetNullChildRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i3.Person? parent;

  _i2.UuidValue parentId;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [RequiredSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  RequiredSetNullChild copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    String? name,
    _i3.Person? parent,
    _i2.UuidValue? parentId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RequiredSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parent != null) 'parent': parent?.toJson(),
      'parentId': parentId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RequiredSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
      'parentId': parentId.toJson(),
    };
  }

  static RequiredSetNullChildInclude include({_i3.PersonInclude? parent}) {
    return RequiredSetNullChildInclude._(parent: parent);
  }

  static RequiredSetNullChildIncludeList includeList({
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
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
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RequiredSetNullChildImpl extends RequiredSetNullChild {
  _RequiredSetNullChildImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.Person? parent,
    required _i2.UuidValue parentId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parent: parent,
         parentId: parentId,
       );

  /// Returns a shallow copy of this [RequiredSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  RequiredSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parent = _Undefined,
    _i2.UuidValue? parentId,
  }) {
    return RequiredSetNullChild(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parent: parent is _i3.Person? ? parent : this.parent?.copyWith(),
      parentId: parentId ?? this.parentId,
    );
  }
}

class RequiredSetNullChildUpdateTable
    extends _i1.UpdateTable<RequiredSetNullChildTable> {
  RequiredSetNullChildUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> parentId(_i2.UuidValue value) =>
      _i1.ColumnValue(
        table.parentId,
        value,
      );
}

class RequiredSetNullChildTable extends _i1.Table<_i2.UuidValue?> {
  RequiredSetNullChildTable({super.tableRelation})
    : super(tableName: 'required_set_null_child') {
    updateTable = RequiredSetNullChildUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    parentId = _i1.ColumnUuid(
      'parentId',
      this,
    );
  }

  late final RequiredSetNullChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i3.PersonTable? _parent;

  late final _i1.ColumnUuid parentId;

  _i3.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _i1.createRelationTable(
      relationFieldName: 'parent',
      field: RequiredSetNullChild.t.parentId,
      foreignField: _i3.Person.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.PersonTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    parentId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class RequiredSetNullChildInclude extends _i1.IncludeObject {
  RequiredSetNullChildInclude._({_i3.PersonInclude? parent}) {
    _parent = parent;
  }

  _i3.PersonInclude? _parent;

  @override
  Map<String, _i1.Include?> get includes => {'parent': _parent};

  @override
  _i1.Table<_i2.UuidValue?> get table => RequiredSetNullChild.t;
}

class RequiredSetNullChildIncludeList extends _i1.IncludeList {
  RequiredSetNullChildIncludeList._({
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RequiredSetNullChild.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => RequiredSetNullChild.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? offset,
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    RequiredSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    RequiredSetNullChild row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    required _i1.ColumnSelections<RequiredSetNullChildTable> conflictColumns,
    _i1.ColumnSelections<RequiredSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    RequiredSetNullChild row, {
    required _i1.ColumnSelections<RequiredSetNullChildTable> conflictColumns,
    _i1.ColumnSelections<RequiredSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _i1.ColumnSelections<RequiredSetNullChildTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    RequiredSetNullChild row, {
    _i1.ColumnSelections<RequiredSetNullChildTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<RequiredSetNullChildUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<RequiredSetNullChildUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<RequiredSetNullChild> rows, {
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    RequiredSetNullChild row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    _i1.OrderByBuilder<RequiredSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<RequiredSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<RequiredSetNullChildTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<RequiredSetNullChild>(
      where: where?.call(RequiredSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RequiredSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<RequiredSetNullChildTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
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
    _i1.DatabaseSession session,
    RequiredSetNullChild requiredSetNullChild,
    _i3.Person parent, {
    _i1.Transaction? transaction,
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
