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
import 'town.dart' as _iytblq2r;

abstract class UniqueSetDefaultChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  UniqueSetDefaultChild._({
    this.id,
    this.spaceId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory UniqueSetDefaultChild({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    _isc.UuidValue? parentId,
    _iytblq2r.Town? parent,
  }) = _UniqueSetDefaultChildImpl;

  factory UniqueSetDefaultChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return UniqueSetDefaultChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      name: jsonSerialization['name'] as String,
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iytblq2r.Town>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = UniqueSetDefaultChildTable();

  static const db = UniqueSetDefaultChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  String name;

  _isc.UuidValue? parentId;

  _iytblq2r.Town? parent;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueSetDefaultChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UniqueSetDefaultChild copyWith({
    _isc.UuidValue? id,
    int? spaceId,
    String? name,
    _isc.UuidValue? parentId,
    _iytblq2r.Town? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueSetDefaultChild',
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
      '__className__': 'UniqueSetDefaultChild',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static UniqueSetDefaultChildInclude include({_iytblq2r.TownInclude? parent}) {
    return UniqueSetDefaultChildInclude._(parent: parent);
  }

  static UniqueSetDefaultChildIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    UniqueSetDefaultChildInclude? include,
  }) {
    return UniqueSetDefaultChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueSetDefaultChildImpl extends UniqueSetDefaultChild {
  _UniqueSetDefaultChildImpl({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    _isc.UuidValue? parentId,
    _iytblq2r.Town? parent,
  }) : super._(
         id: id,
         spaceId: spaceId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [UniqueSetDefaultChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UniqueSetDefaultChild copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return UniqueSetDefaultChild(
      id: id is _isc.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      name: name ?? this.name,
      parentId: parentId is _isc.UuidValue? ? parentId : this.parentId,
      parent: parent is _iytblq2r.Town? ? parent : this.parent?.copyWith(),
    );
  }
}

class UniqueSetDefaultChildUpdateTable
    extends _isd.UpdateTable<UniqueSetDefaultChildTable> {
  UniqueSetDefaultChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) => _isd.ColumnValue(
    table.spaceId,
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

class UniqueSetDefaultChildTable extends _isd.Table<_isc.UuidValue?> {
  UniqueSetDefaultChildTable({super.tableRelation})
    : super(tableName: 'unique_set_default_child') {
    updateTable = UniqueSetDefaultChildUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    parentId = _isd.ColumnUuid(
      'parentId',
      this,
      hasDefault: true,
    );
  }

  late final UniqueSetDefaultChildUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid parentId;

  _iytblq2r.TownTable? _parent;

  _iytblq2r.TownTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueSetDefaultChild.t.parentId,
      foreignField: _iytblq2r.Town.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iytblq2r.TownTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
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

class UniqueSetDefaultChildInclude extends _isd.IncludeObject {
  UniqueSetDefaultChildInclude._({_iytblq2r.TownInclude? parent}) {
    _parent = parent;
  }

  _iytblq2r.TownInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {'parent': _parent};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueSetDefaultChild.t;
}

class UniqueSetDefaultChildIncludeList extends _isd.IncludeList {
  UniqueSetDefaultChildIncludeList._({
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueSetDefaultChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueSetDefaultChild.t;
}

class UniqueSetDefaultChildRepository {
  const UniqueSetDefaultChildRepository._();

  final attachRow = const UniqueSetDefaultChildAttachRowRepository._();

  final detachRow = const UniqueSetDefaultChildDetachRowRepository._();

  /// Returns a list of [UniqueSetDefaultChild]s matching the given query parameters.
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
  Future<List<UniqueSetDefaultChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    UniqueSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueSetDefaultChild>(
      where: where?.call(UniqueSetDefaultChild.t),
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueSetDefaultChild] matching the given query parameters.
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
  Future<UniqueSetDefaultChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    UniqueSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueSetDefaultChild>(
      where: where?.call(UniqueSetDefaultChild.t),
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueSetDefaultChild] by its [id] or null if no such row exists.
  Future<UniqueSetDefaultChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    UniqueSetDefaultChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueSetDefaultChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueSetDefaultChild]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueSetDefaultChild]s will have their `id` fields set.
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
  Future<List<UniqueSetDefaultChild>> insert(
    _isd.DatabaseSession session,
    List<UniqueSetDefaultChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueSetDefaultChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueSetDefaultChild] and returns the inserted row.
  ///
  /// The returned [UniqueSetDefaultChild] will have its `id` field set.
  Future<UniqueSetDefaultChild> insertRow(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueSetDefaultChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueSetDefaultChild]s in the list and returns the resulting rows.
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
  /// The returned [UniqueSetDefaultChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetDefaultChild>> upsert(
    _isd.DatabaseSession session,
    List<UniqueSetDefaultChild> rows, {
    required _isd.ColumnSelections<UniqueSetDefaultChildTable> conflictColumns,
    _isd.ColumnSelections<UniqueSetDefaultChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueSetDefaultChild>(
      rows,
      conflictColumns: conflictColumns(UniqueSetDefaultChild.t),
      updateColumns: updateColumns?.call(UniqueSetDefaultChild.t),
      updateWhere: updateWhere?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueSetDefaultChild] and returns the resulting row.
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
  /// The returned [UniqueSetDefaultChild] will have its `id` field set.
  Future<UniqueSetDefaultChild?> upsertRow(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild row, {
    required _isd.ColumnSelections<UniqueSetDefaultChildTable> conflictColumns,
    _isd.ColumnSelections<UniqueSetDefaultChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueSetDefaultChild>(
      row,
      conflictColumns: conflictColumns(UniqueSetDefaultChild.t),
      updateColumns: updateColumns?.call(UniqueSetDefaultChild.t),
      updateWhere: updateWhere?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueSetDefaultChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetDefaultChild>> update(
    _isd.DatabaseSession session,
    List<UniqueSetDefaultChild> rows, {
    _isd.ColumnSelections<UniqueSetDefaultChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueSetDefaultChild>(
      rows,
      columns: columns?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueSetDefaultChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueSetDefaultChild> updateRow(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild row, {
    _isd.ColumnSelections<UniqueSetDefaultChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueSetDefaultChild>(
      row,
      columns: columns?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueSetDefaultChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueSetDefaultChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueSetDefaultChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueSetDefaultChild>(
      id,
      columnValues: columnValues(UniqueSetDefaultChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueSetDefaultChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueSetDefaultChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueSetDefaultChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueSetDefaultChild>(
      columnValues: columnValues(UniqueSetDefaultChild.t.updateTable),
      where: where(UniqueSetDefaultChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueSetDefaultChild]s in the list and returns the deleted rows.
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
  Future<List<UniqueSetDefaultChild>> delete(
    _isd.DatabaseSession session,
    List<UniqueSetDefaultChild> rows, {
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueSetDefaultChild>(
      rows,
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueSetDefaultChild].
  Future<UniqueSetDefaultChild> deleteRow(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueSetDefaultChild>(
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
  Future<List<UniqueSetDefaultChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable> where,
    _isd.OrderByBuilder<UniqueSetDefaultChildTable>? orderBy,
    _isd.OrderByListBuilder<UniqueSetDefaultChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueSetDefaultChild>(
      where: where(UniqueSetDefaultChild.t),
      orderBy: orderBy?.call(UniqueSetDefaultChild.t),
      orderByList: orderByList?.call(UniqueSetDefaultChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<UniqueSetDefaultChild>(
      where: where?.call(UniqueSetDefaultChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueSetDefaultChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueSetDefaultChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueSetDefaultChild>(
      where: where(UniqueSetDefaultChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueSetDefaultChildAttachRowRepository {
  const UniqueSetDefaultChildAttachRowRepository._();

  /// Creates a relation between the given [UniqueSetDefaultChild] and [Town]
  /// by setting the [UniqueSetDefaultChild]'s foreign key `parentId` to refer to the [Town].
  Future<void> parent(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild uniqueSetDefaultChild,
    _iytblq2r.Town parent, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueSetDefaultChild.id == null) {
      throw ArgumentError.notNull('uniqueSetDefaultChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $uniqueSetDefaultChild = uniqueSetDefaultChild.copyWith(
      parentId: parent.id,
    );
    await session.db.updateRow<UniqueSetDefaultChild>(
      $uniqueSetDefaultChild,
      columns: [UniqueSetDefaultChild.t.parentId],
      transaction: transaction,
    );
  }
}

class UniqueSetDefaultChildDetachRowRepository {
  const UniqueSetDefaultChildDetachRowRepository._();

  /// Detaches the relation between this [UniqueSetDefaultChild] and the [Town] set in `parent`
  /// by setting the [UniqueSetDefaultChild]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _isd.DatabaseSession session,
    UniqueSetDefaultChild uniqueSetDefaultChild, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueSetDefaultChild.id == null) {
      throw ArgumentError.notNull('uniqueSetDefaultChild.id');
    }

    var $uniqueSetDefaultChild = uniqueSetDefaultChild.copyWith(parentId: null);
    await session.db.updateRow<UniqueSetDefaultChild>(
      $uniqueSetDefaultChild,
      columns: [UniqueSetDefaultChild.t.parentId],
      transaction: transaction,
    );
  }
}
