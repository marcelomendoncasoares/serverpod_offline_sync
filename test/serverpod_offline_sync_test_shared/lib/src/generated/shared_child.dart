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

/// A synchronized child owned by a shared package rather than the server.
///
/// The set-null relation makes an insert that names a missing parent go through
/// foreign key projection, which rebuilds the row from its serialized form.
abstract class SharedChild
    implements _isd.TableRow<_iss.UuidValue?>, _iss.ProtocolSerialization {
  SharedChild._({
    this.id,
    this.scopeId,
    required this.name,
    _i2ap9bqs.SharedFlavor? flavor,
    this.parentId,
    this.parent,
  }) : flavor = flavor ?? _i2ap9bqs.SharedFlavor.plain;

  factory SharedChild({
    _iss.UuidValue? id,
    int? scopeId,
    required String name,
    _i2ap9bqs.SharedFlavor? flavor,
    _iss.UuidValue? parentId,
    _i2ap9bqs.SharedParent? parent,
  }) = _SharedChildImpl;

  factory SharedChild.fromJson(Map<String, dynamic> jsonSerialization) {
    return SharedChild(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      flavor: jsonSerialization['flavor'] == null
          ? null
          : _i2ap9bqs.SharedFlavor.fromJson(
              (jsonSerialization['flavor'] as String),
            ),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _i2ap9bqs.Protocol().deserialize<_i2ap9bqs.SharedParent>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = SharedChildTable();

  static const db = SharedChildRepository._();

  @override
  _iss.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _i2ap9bqs.SharedFlavor flavor;

  _iss.UuidValue? parentId;

  _i2ap9bqs.SharedParent? parent;

  @override
  _isd.Table<_iss.UuidValue?> get table => t;

  /// Returns a shallow copy of this [SharedChild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SharedChild copyWith({
    _iss.UuidValue? id,
    int? scopeId,
    String? name,
    _i2ap9bqs.SharedFlavor? flavor,
    _iss.UuidValue? parentId,
    _i2ap9bqs.SharedParent? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SharedChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      'flavor': flavor.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SharedChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      'flavor': flavor.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static SharedChildInclude include({_i2ap9bqs.SharedParentInclude? parent}) {
    return SharedChildInclude._(parent: parent);
  }

  static SharedChildIncludeList includeList({
    _isd.WhereExpressionBuilder<SharedChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    SharedChildInclude? include,
  }) {
    return SharedChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SharedChildImpl extends SharedChild {
  _SharedChildImpl({
    _iss.UuidValue? id,
    int? scopeId,
    required String name,
    _i2ap9bqs.SharedFlavor? flavor,
    _iss.UuidValue? parentId,
    _i2ap9bqs.SharedParent? parent,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         flavor: flavor,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [SharedChild]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SharedChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    _i2ap9bqs.SharedFlavor? flavor,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return SharedChild(
      id: id is _iss.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      flavor: flavor ?? this.flavor,
      parentId: parentId is _iss.UuidValue? ? parentId : this.parentId,
      parent: parent is _i2ap9bqs.SharedParent?
          ? parent
          : this.parent?.copyWith(),
    );
  }
}

class SharedChildUpdateTable extends _isd.UpdateTable<SharedChildTable> {
  SharedChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) =>
      _isd.ColumnValue(table.scopeId, value);

  _isd.ColumnValue<String, String> name(String value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<_i2ap9bqs.SharedFlavor, _i2ap9bqs.SharedFlavor> flavor(
    _i2ap9bqs.SharedFlavor value,
  ) => _isd.ColumnValue(table.flavor, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> parentId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.parentId, value);
}

class SharedChildTable extends _isd.Table<_iss.UuidValue?> {
  SharedChildTable({super.tableRelation}) : super(tableName: 'shared_child') {
    updateTable = SharedChildUpdateTable(this);
    scopeId = _isd.ColumnInt('scopeId', this);
    name = _isd.ColumnString('name', this);
    flavor = _isd.ColumnEnum(
      'flavor',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    parentId = _isd.ColumnUuid('parentId', this);
  }

  late final SharedChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnEnum<_i2ap9bqs.SharedFlavor> flavor;

  late final _isd.ColumnUuid parentId;

  _i2ap9bqs.SharedParentTable? _parent;

  _i2ap9bqs.SharedParentTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
      relationFieldName: 'parent',
      field: SharedChild.t.parentId,
      foreignField: _i2ap9bqs.SharedParent.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2ap9bqs.SharedParentTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_isd.Column> get columns => [id, scopeId, name, flavor, parentId];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class SharedChildInclude extends _isd.IncludeObject {
  SharedChildInclude._({_i2ap9bqs.SharedParentInclude? parent}) {
    _parent = parent;
  }

  _i2ap9bqs.SharedParentInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {'parent': _parent};

  @override
  _isd.Table<_iss.UuidValue?> get table => SharedChild.t;
}

class SharedChildIncludeList extends _isd.IncludeList {
  SharedChildIncludeList._({
    _isd.WhereExpressionBuilder<SharedChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SharedChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue?> get table => SharedChild.t;
}

class SharedChildRepository {
  const SharedChildRepository._();

  final attachRow = const SharedChildAttachRowRepository._();

  final detachRow = const SharedChildDetachRowRepository._();

  /// Returns a list of [SharedChild]s matching the given query parameters.
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
  Future<List<SharedChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    _isd.Transaction? transaction,
    SharedChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SharedChild>(
      where: where?.call(SharedChild.t),
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [SharedChild] matching the given query parameters.
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
  Future<SharedChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    _isd.Transaction? transaction,
    SharedChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SharedChild>(
      where: where?.call(SharedChild.t),
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SharedChild] by its [id] or null if no such row exists.
  Future<SharedChild?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SharedChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SharedChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SharedChild]s in the list and returns the inserted rows.
  ///
  /// The returned [SharedChild]s will have their `id` fields set.
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
  Future<List<SharedChild>> insert(
    _isd.DatabaseSession session,
    List<SharedChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SharedChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SharedChild] and returns the inserted row.
  ///
  /// The returned [SharedChild] will have its `id` field set.
  Future<SharedChild> insertRow(
    _isd.DatabaseSession session,
    SharedChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SharedChild>(row, transaction: transaction);
  }

  /// Upserts all [SharedChild]s in the list and returns the resulting rows.
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
  /// The returned [SharedChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedChild>> upsert(
    _isd.DatabaseSession session,
    List<SharedChild> rows, {
    required _isd.ColumnSelections<SharedChildTable> conflictColumns,
    _isd.ColumnSelections<SharedChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<SharedChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SharedChild>(
      rows,
      conflictColumns: conflictColumns(SharedChild.t),
      updateColumns: updateColumns?.call(SharedChild.t),
      updateWhere: updateWhere?.call(SharedChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SharedChild] and returns the resulting row.
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
  /// The returned [SharedChild] will have its `id` field set.
  Future<SharedChild?> upsertRow(
    _isd.DatabaseSession session,
    SharedChild row, {
    required _isd.ColumnSelections<SharedChildTable> conflictColumns,
    _isd.ColumnSelections<SharedChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<SharedChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SharedChild>(
      row,
      conflictColumns: conflictColumns(SharedChild.t),
      updateColumns: updateColumns?.call(SharedChild.t),
      updateWhere: updateWhere?.call(SharedChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [SharedChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedChild>> update(
    _isd.DatabaseSession session,
    List<SharedChild> rows, {
    _isd.ColumnSelections<SharedChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SharedChild>(
      rows,
      columns: columns?.call(SharedChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SharedChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SharedChild> updateRow(
    _isd.DatabaseSession session,
    SharedChild row, {
    _isd.ColumnSelections<SharedChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SharedChild>(
      row,
      columns: columns?.call(SharedChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SharedChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SharedChild?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SharedChildUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SharedChild>(
      id,
      columnValues: columnValues(SharedChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SharedChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SharedChildUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SharedChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SharedChild>(
      columnValues: columnValues(SharedChild.t.updateTable),
      where: where(SharedChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SharedChild]s in the list and returns the deleted rows.
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
  Future<List<SharedChild>> delete(
    _isd.DatabaseSession session,
    List<SharedChild> rows, {
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SharedChild>(
      rows,
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SharedChild].
  Future<SharedChild> deleteRow(
    _isd.DatabaseSession session,
    SharedChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SharedChild>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SharedChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SharedChildTable> where,
    _isd.OrderByBuilder<SharedChildTable>? orderBy,
    _isd.OrderByListBuilder<SharedChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SharedChild>(
      where: where(SharedChild.t),
      orderBy: orderBy?.call(SharedChild.t),
      orderByList: orderByList?.call(SharedChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SharedChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SharedChild>(
      where: where?.call(SharedChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SharedChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SharedChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SharedChild>(
      where: where(SharedChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SharedChildAttachRowRepository {
  const SharedChildAttachRowRepository._();

  /// Creates a relation between the given [SharedChild] and [SharedParent]
  /// by setting the [SharedChild]'s foreign key `parentId` to refer to the [SharedParent].
  Future<void> parent(
    _isd.DatabaseSession session,
    SharedChild sharedChild,
    _i2ap9bqs.SharedParent parent, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.id == null) {
      throw ArgumentError.notNull('sharedChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $sharedChild = sharedChild.copyWith(parentId: parent.id);
    await session.db.updateRow<SharedChild>(
      $sharedChild,
      columns: [SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}

class SharedChildDetachRowRepository {
  const SharedChildDetachRowRepository._();

  /// Detaches the relation between this [SharedChild] and the [SharedParent] set in `parent`
  /// by setting the [SharedChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _isd.DatabaseSession session,
    SharedChild sharedChild, {
    _isd.Transaction? transaction,
  }) async {
    if (sharedChild.id == null) {
      throw ArgumentError.notNull('sharedChild.id');
    }

    var $sharedChild = sharedChild.copyWith(parentId: null);
    await session.db.updateRow<SharedChild>(
      $sharedChild,
      columns: [SharedChild.t.parentId],
      transaction: transaction,
    );
  }
}
