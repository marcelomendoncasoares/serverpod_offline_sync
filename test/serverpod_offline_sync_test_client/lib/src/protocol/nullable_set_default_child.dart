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

abstract class NullableSetDefaultChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  NullableSetDefaultChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory NullableSetDefaultChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) = _NullableSetDefaultChildImpl;

  factory NullableSetDefaultChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return NullableSetDefaultChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = NullableSetDefaultChildTable();

  static const db = NullableSetDefaultChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _isc.UuidValue? parentId;

  _iensfz4m.Person? parent;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [NullableSetDefaultChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  NullableSetDefaultChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _isc.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NullableSetDefaultChild',
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
      '__className__': 'NullableSetDefaultChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static NullableSetDefaultChildInclude include({
    _iensfz4m.PersonInclude? parent,
  }) {
    return NullableSetDefaultChildInclude._(parent: parent);
  }

  static NullableSetDefaultChildIncludeList includeList({
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    NullableSetDefaultChildInclude? include,
  }) {
    return NullableSetDefaultChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NullableSetDefaultChildImpl extends NullableSetDefaultChild {
  _NullableSetDefaultChildImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [NullableSetDefaultChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  NullableSetDefaultChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return NullableSetDefaultChild(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parentId: parentId is _isc.UuidValue? ? parentId : this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class NullableSetDefaultChildUpdateTable
    extends _isd.UpdateTable<NullableSetDefaultChildTable> {
  NullableSetDefaultChildUpdateTable(super.table);

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

class NullableSetDefaultChildTable extends _isd.Table<_isc.UuidValue?> {
  NullableSetDefaultChildTable({super.tableRelation})
    : super(tableName: 'nullable_set_default_child') {
    updateTable = NullableSetDefaultChildUpdateTable(this);
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

  late final NullableSetDefaultChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
      relationFieldName: 'parent',
      field: NullableSetDefaultChild.t.parentId,
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

class NullableSetDefaultChildInclude extends _isd.IncludeObject {
  NullableSetDefaultChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {'parent': _parent};

  @override
  _isd.Table<_isc.UuidValue?> get table => NullableSetDefaultChild.t;
}

class NullableSetDefaultChildIncludeList extends _isd.IncludeList {
  NullableSetDefaultChildIncludeList._({
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(NullableSetDefaultChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => NullableSetDefaultChild.t;
}

class NullableSetDefaultChildRepository {
  const NullableSetDefaultChildRepository._();

  final attachRow = const NullableSetDefaultChildAttachRowRepository._();

  final detachRow = const NullableSetDefaultChildDetachRowRepository._();

  /// Returns a list of [NullableSetDefaultChild]s matching the given query parameters.
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
  Future<List<NullableSetDefaultChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    NullableSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<NullableSetDefaultChild>(
      where: where?.call(NullableSetDefaultChild.t),
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [NullableSetDefaultChild] matching the given query parameters.
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
  Future<NullableSetDefaultChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    NullableSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<NullableSetDefaultChild>(
      where: where?.call(NullableSetDefaultChild.t),
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [NullableSetDefaultChild] by its [id] or null if no such row exists.
  Future<NullableSetDefaultChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    NullableSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<NullableSetDefaultChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [NullableSetDefaultChild]s in the list and returns the inserted rows.
  ///
  /// The returned [NullableSetDefaultChild]s will have their `id` fields set.
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
  Future<List<NullableSetDefaultChild>> insert(
    _isd.DatabaseSession session,
    List<NullableSetDefaultChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<NullableSetDefaultChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [NullableSetDefaultChild] and returns the inserted row.
  ///
  /// The returned [NullableSetDefaultChild] will have its `id` field set.
  Future<NullableSetDefaultChild> insertRow(
    _isd.DatabaseSession session,
    NullableSetDefaultChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<NullableSetDefaultChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [NullableSetDefaultChild]s in the list and returns the resulting rows.
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
  /// The returned [NullableSetDefaultChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NullableSetDefaultChild>> upsert(
    _isd.DatabaseSession session,
    List<NullableSetDefaultChild> rows, {
    required _isd.ColumnSelections<NullableSetDefaultChildTable>
    conflictColumns,
    _isd.ColumnSelections<NullableSetDefaultChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<NullableSetDefaultChild>(
      rows,
      conflictColumns: conflictColumns(NullableSetDefaultChild.t),
      updateColumns: updateColumns?.call(NullableSetDefaultChild.t),
      updateWhere: updateWhere?.call(NullableSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [NullableSetDefaultChild] and returns the resulting row.
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
  /// The returned [NullableSetDefaultChild] will have its `id` field set.
  Future<NullableSetDefaultChild?> upsertRow(
    _isd.DatabaseSession session,
    NullableSetDefaultChild row, {
    required _isd.ColumnSelections<NullableSetDefaultChildTable>
    conflictColumns,
    _isd.ColumnSelections<NullableSetDefaultChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<NullableSetDefaultChild>(
      row,
      conflictColumns: conflictColumns(NullableSetDefaultChild.t),
      updateColumns: updateColumns?.call(NullableSetDefaultChild.t),
      updateWhere: updateWhere?.call(NullableSetDefaultChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [NullableSetDefaultChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NullableSetDefaultChild>> update(
    _isd.DatabaseSession session,
    List<NullableSetDefaultChild> rows, {
    _isd.ColumnSelections<NullableSetDefaultChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<NullableSetDefaultChild>(
      rows,
      columns: columns?.call(NullableSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [NullableSetDefaultChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<NullableSetDefaultChild> updateRow(
    _isd.DatabaseSession session,
    NullableSetDefaultChild row, {
    _isd.ColumnSelections<NullableSetDefaultChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<NullableSetDefaultChild>(
      row,
      columns: columns?.call(NullableSetDefaultChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [NullableSetDefaultChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<NullableSetDefaultChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<NullableSetDefaultChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<NullableSetDefaultChild>(
      id,
      columnValues: columnValues(NullableSetDefaultChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [NullableSetDefaultChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<NullableSetDefaultChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<NullableSetDefaultChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<NullableSetDefaultChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<NullableSetDefaultChild>(
      columnValues: columnValues(NullableSetDefaultChild.t.updateTable),
      where: where(NullableSetDefaultChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [NullableSetDefaultChild]s in the list and returns the deleted rows.
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
  Future<List<NullableSetDefaultChild>> delete(
    _isd.DatabaseSession session,
    List<NullableSetDefaultChild> rows, {
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<NullableSetDefaultChild>(
      rows,
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [NullableSetDefaultChild].
  Future<NullableSetDefaultChild> deleteRow(
    _isd.DatabaseSession session,
    NullableSetDefaultChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<NullableSetDefaultChild>(
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
  Future<List<NullableSetDefaultChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<NullableSetDefaultChildTable> where,
    _isd.OrderByBuilder<NullableSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<NullableSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<NullableSetDefaultChild>(
      where: where(NullableSetDefaultChild.t),
      orderBy: orderBy?.call(NullableSetDefaultChild.t),
      orderByList: orderByList?.call(NullableSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<NullableSetDefaultChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<NullableSetDefaultChild>(
      where: where?.call(NullableSetDefaultChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [NullableSetDefaultChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<NullableSetDefaultChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<NullableSetDefaultChild>(
      where: where(NullableSetDefaultChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class NullableSetDefaultChildAttachRowRepository {
  const NullableSetDefaultChildAttachRowRepository._();

  /// Creates a relation between the given [NullableSetDefaultChild] and [Person]
  /// by setting the [NullableSetDefaultChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _isd.DatabaseSession session,
    NullableSetDefaultChild nullableSetDefaultChild,
    _iensfz4m.Person parent, {
    _isd.Transaction? transaction,
  }) async {
    if (nullableSetDefaultChild.id == null) {
      throw ArgumentError.notNull('nullableSetDefaultChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $nullableSetDefaultChild = nullableSetDefaultChild.copyWith(
      parentId: parent.id,
    );
    await session.db.updateRow<NullableSetDefaultChild>(
      $nullableSetDefaultChild,
      columns: [NullableSetDefaultChild.t.parentId],
      transaction: transaction,
    );
  }
}

class NullableSetDefaultChildDetachRowRepository {
  const NullableSetDefaultChildDetachRowRepository._();

  /// Detaches the relation between this [NullableSetDefaultChild] and the [Person] set in `parent`
  /// by setting the [NullableSetDefaultChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _isd.DatabaseSession session,
    NullableSetDefaultChild nullableSetDefaultChild, {
    _isd.Transaction? transaction,
  }) async {
    if (nullableSetDefaultChild.id == null) {
      throw ArgumentError.notNull('nullableSetDefaultChild.id');
    }

    var $nullableSetDefaultChild = nullableSetDefaultChild.copyWith(
      parentId: null,
    );
    await session.db.updateRow<NullableSetDefaultChild>(
      $nullableSetDefaultChild,
      columns: [NullableSetDefaultChild.t.parentId],
      transaction: transaction,
    );
  }
}
