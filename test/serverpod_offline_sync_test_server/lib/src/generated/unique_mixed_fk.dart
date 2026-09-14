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

abstract class UniqueMixedFk
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueMixedFk._({
    this.id,
    this.spaceId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory UniqueMixedFk({
    _is.UuidValue? id,
    int? spaceId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) = _UniqueMixedFkImpl;

  factory UniqueMixedFk.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueMixedFk(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
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

  static final t = UniqueMixedFkTable();

  static const db = UniqueMixedFkRepository._();

  @override
  _is.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  String name;

  _is.UuidValue? parentId;

  _iensfz4m.Person? parent;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueMixedFk]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueMixedFk copyWith({
    _is.UuidValue? id,
    int? spaceId,
    String? name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueMixedFk',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueMixedFk',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static UniqueMixedFkInclude include({_iensfz4m.PersonInclude? parent}) {
    return UniqueMixedFkInclude._(parent: parent);
  }

  static UniqueMixedFkIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    UniqueMixedFkInclude? include,
  }) {
    return UniqueMixedFkIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueMixedFkImpl extends UniqueMixedFk {
  _UniqueMixedFkImpl({
    _is.UuidValue? id,
    int? spaceId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) : super._(
         id: id,
         spaceId: spaceId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [UniqueMixedFk]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueMixedFk copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return UniqueMixedFk(
      id: id is _is.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      name: name ?? this.name,
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class UniqueMixedFkUpdateTable extends _is.UpdateTable<UniqueMixedFkTable> {
  UniqueMixedFkUpdateTable(super.table);

  _is.ColumnValue<int, int> spaceId(int? value) => _is.ColumnValue(
    table.spaceId,
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

class UniqueMixedFkTable extends _is.Table<_is.UuidValue?> {
  UniqueMixedFkTable({super.tableRelation})
    : super(tableName: 'unique_mixed_fk') {
    updateTable = UniqueMixedFkUpdateTable(this);
    spaceId = _is.ColumnInt(
      'spaceId',
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

  late final UniqueMixedFkUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _is.ColumnInt spaceId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueMixedFk.t.parentId,
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
    spaceId,
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

class UniqueMixedFkInclude extends _is.IncludeObject {
  UniqueMixedFkInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueMixedFk.t;
}

class UniqueMixedFkIncludeList extends _is.IncludeList {
  UniqueMixedFkIncludeList._({
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueMixedFk.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueMixedFk.t;
}

class UniqueMixedFkRepository {
  const UniqueMixedFkRepository._();

  final attachRow = const UniqueMixedFkAttachRowRepository._();

  final detachRow = const UniqueMixedFkDetachRowRepository._();

  /// Returns a list of [UniqueMixedFk]s matching the given query parameters.
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
  Future<List<UniqueMixedFk>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    _is.Transaction? transaction,
    UniqueMixedFkInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueMixedFk>(
      where: where?.call(UniqueMixedFk.t),
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueMixedFk] matching the given query parameters.
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
  Future<UniqueMixedFk?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    _is.Transaction? transaction,
    UniqueMixedFkInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueMixedFk>(
      where: where?.call(UniqueMixedFk.t),
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueMixedFk] by its [id] or null if no such row exists.
  Future<UniqueMixedFk?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    UniqueMixedFkInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueMixedFk>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueMixedFk]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueMixedFk]s will have their `id` fields set.
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
  Future<List<UniqueMixedFk>> insert(
    _is.DatabaseSession session,
    List<UniqueMixedFk> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueMixedFk>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueMixedFk] and returns the inserted row.
  ///
  /// The returned [UniqueMixedFk] will have its `id` field set.
  Future<UniqueMixedFk> insertRow(
    _is.DatabaseSession session,
    UniqueMixedFk row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueMixedFk>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueMixedFk]s in the list and returns the resulting rows.
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
  /// The returned [UniqueMixedFk]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueMixedFk>> upsert(
    _is.DatabaseSession session,
    List<UniqueMixedFk> rows, {
    required _is.ColumnSelections<UniqueMixedFkTable> conflictColumns,
    _is.ColumnSelections<UniqueMixedFkTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueMixedFk>(
      rows,
      conflictColumns: conflictColumns(UniqueMixedFk.t),
      updateColumns: updateColumns?.call(UniqueMixedFk.t),
      updateWhere: updateWhere?.call(UniqueMixedFk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueMixedFk] and returns the resulting row.
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
  /// The returned [UniqueMixedFk] will have its `id` field set.
  Future<UniqueMixedFk?> upsertRow(
    _is.DatabaseSession session,
    UniqueMixedFk row, {
    required _is.ColumnSelections<UniqueMixedFkTable> conflictColumns,
    _is.ColumnSelections<UniqueMixedFkTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueMixedFk>(
      row,
      conflictColumns: conflictColumns(UniqueMixedFk.t),
      updateColumns: updateColumns?.call(UniqueMixedFk.t),
      updateWhere: updateWhere?.call(UniqueMixedFk.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueMixedFk]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueMixedFk>> update(
    _is.DatabaseSession session,
    List<UniqueMixedFk> rows, {
    _is.ColumnSelections<UniqueMixedFkTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueMixedFk>(
      rows,
      columns: columns?.call(UniqueMixedFk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueMixedFk]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueMixedFk> updateRow(
    _is.DatabaseSession session,
    UniqueMixedFk row, {
    _is.ColumnSelections<UniqueMixedFkTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueMixedFk>(
      row,
      columns: columns?.call(UniqueMixedFk.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueMixedFk] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueMixedFk?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueMixedFkUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueMixedFk>(
      id,
      columnValues: columnValues(UniqueMixedFk.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueMixedFk]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueMixedFk>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueMixedFkUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<UniqueMixedFkTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueMixedFk>(
      columnValues: columnValues(UniqueMixedFk.t.updateTable),
      where: where(UniqueMixedFk.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueMixedFk]s in the list and returns the deleted rows.
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
  Future<List<UniqueMixedFk>> delete(
    _is.DatabaseSession session,
    List<UniqueMixedFk> rows, {
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueMixedFk>(
      rows,
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueMixedFk].
  Future<UniqueMixedFk> deleteRow(
    _is.DatabaseSession session,
    UniqueMixedFk row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueMixedFk>(
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
  Future<List<UniqueMixedFk>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueMixedFkTable> where,
    _is.OrderByBuilder<UniqueMixedFkTable>? orderBy,
    _is.OrderByListBuilder<UniqueMixedFkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueMixedFk>(
      where: where(UniqueMixedFk.t),
      orderBy: orderBy?.call(UniqueMixedFk.t),
      orderByList: orderByList?.call(UniqueMixedFk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueMixedFkTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueMixedFk>(
      where: where?.call(UniqueMixedFk.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueMixedFk] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueMixedFkTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueMixedFk>(
      where: where(UniqueMixedFk.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueMixedFkAttachRowRepository {
  const UniqueMixedFkAttachRowRepository._();

  /// Creates a relation between the given [UniqueMixedFk] and [Person]
  /// by setting the [UniqueMixedFk]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueMixedFk uniqueMixedFk,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueMixedFk.id == null) {
      throw ArgumentError.notNull('uniqueMixedFk.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $uniqueMixedFk = uniqueMixedFk.copyWith(parentId: parent.id);
    await session.db.updateRow<UniqueMixedFk>(
      $uniqueMixedFk,
      columns: [UniqueMixedFk.t.parentId],
      transaction: transaction,
    );
  }
}

class UniqueMixedFkDetachRowRepository {
  const UniqueMixedFkDetachRowRepository._();

  /// Detaches the relation between this [UniqueMixedFk] and the [Person] set in `parent`
  /// by setting the [UniqueMixedFk]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueMixedFk uniqueMixedFk, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueMixedFk.id == null) {
      throw ArgumentError.notNull('uniqueMixedFk.id');
    }

    var $uniqueMixedFk = uniqueMixedFk.copyWith(parentId: null);
    await session.db.updateRow<UniqueMixedFk>(
      $uniqueMixedFk,
      columns: [UniqueMixedFk.t.parentId],
      transaction: transaction,
    );
  }
}
