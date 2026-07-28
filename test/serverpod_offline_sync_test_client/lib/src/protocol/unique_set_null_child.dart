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

abstract class UniqueSetNullChild
    implements _i1.TableRow<_i2.UuidValue?>, _i2.ProtocolSerialization {
  UniqueSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parent,
    this.parentId,
  });

  factory UniqueSetNullChild({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.Person? parent,
    _i2.UuidValue? parentId,
  }) = _UniqueSetNullChildImpl;

  factory UniqueSetNullChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parent: jsonSerialization['parent'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.Person>(jsonSerialization['parent']),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
    );
  }

  static final t = UniqueSetNullChildTable();

  static const db = UniqueSetNullChildRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i3.Person? parent;

  _i2.UuidValue? parentId;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  UniqueSetNullChild copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    String? name,
    _i3.Person? parent,
    _i2.UuidValue? parentId,
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

  static UniqueSetNullChildInclude include({_i3.PersonInclude? parent}) {
    return UniqueSetNullChildInclude._(parent: parent);
  }

  static UniqueSetNullChildIncludeList includeList({
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
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
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueSetNullChildImpl extends UniqueSetNullChild {
  _UniqueSetNullChildImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    _i3.Person? parent,
    _i2.UuidValue? parentId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parent: parent,
         parentId: parentId,
       );

  /// Returns a shallow copy of this [UniqueSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  UniqueSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parent = _Undefined,
    Object? parentId = _Undefined,
  }) {
    return UniqueSetNullChild(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parent: parent is _i3.Person? ? parent : this.parent?.copyWith(),
      parentId: parentId is _i2.UuidValue? ? parentId : this.parentId,
    );
  }
}

class UniqueSetNullChildUpdateTable
    extends _i1.UpdateTable<UniqueSetNullChildTable> {
  UniqueSetNullChildUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> parentId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.parentId,
    value,
  );
}

class UniqueSetNullChildTable extends _i1.Table<_i2.UuidValue?> {
  UniqueSetNullChildTable({super.tableRelation})
    : super(tableName: 'unique_set_null_child') {
    updateTable = UniqueSetNullChildUpdateTable(this);
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

  late final UniqueSetNullChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  _i3.PersonTable? _parent;

  late final _i1.ColumnUuid parentId;

  _i3.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _i1.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueSetNullChild.t.parentId,
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

class UniqueSetNullChildInclude extends _i1.IncludeObject {
  UniqueSetNullChildInclude._({_i3.PersonInclude? parent}) {
    _parent = parent;
  }

  _i3.PersonInclude? _parent;

  @override
  Map<String, _i1.Include?> get includes => {'parent': _parent};

  @override
  _i1.Table<_i2.UuidValue?> get table => UniqueSetNullChild.t;
}

class UniqueSetNullChildIncludeList extends _i1.IncludeList {
  UniqueSetNullChildIncludeList._({
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueSetNullChild.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => UniqueSetNullChild.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? offset,
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    UniqueSetNullChildInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    required _i1.ColumnSelections<UniqueSetNullChildTable> conflictColumns,
    _i1.ColumnSelections<UniqueSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild row, {
    required _i1.ColumnSelections<UniqueSetNullChildTable> conflictColumns,
    _i1.ColumnSelections<UniqueSetNullChildTable>? updateColumns,
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _i1.ColumnSelections<UniqueSetNullChildTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild row, {
    _i1.ColumnSelections<UniqueSetNullChildTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<UniqueSetNullChildUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<UniqueSetNullChildUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<UniqueSetNullChild> rows, {
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    _i1.OrderByBuilder<UniqueSetNullChildTable>? orderBy,
    _i1.OrderByListBuilder<UniqueSetNullChildTable>? orderByList,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<UniqueSetNullChildTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<UniqueSetNullChild>(
      where: where?.call(UniqueSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<UniqueSetNullChildTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild uniqueSetNullChild,
    _i3.Person parent, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    UniqueSetNullChild uniqueSetNullChild, {
    _i1.Transaction? transaction,
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
