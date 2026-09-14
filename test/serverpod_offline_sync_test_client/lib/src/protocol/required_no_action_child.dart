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

abstract class RequiredNoActionChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  RequiredNoActionChild._({
    this.id,
    this.spaceId,
    required this.name,
    required this.parentId,
    this.parent,
  });

  factory RequiredNoActionChild({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    required _isc.UuidValue parentId,
    _iensfz4m.Person? parent,
  }) = _RequiredNoActionChildImpl;

  factory RequiredNoActionChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return RequiredNoActionChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      name: jsonSerialization['name'] as String,
      parentId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['parentId'],
      ),
      parent: jsonSerialization['parent'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['parent'],
            ),
    );
  }

  static final t = RequiredNoActionChildTable();

  static const db = RequiredNoActionChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  String name;

  _isc.UuidValue parentId;

  _iensfz4m.Person? parent;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [RequiredNoActionChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RequiredNoActionChild copyWith({
    _isc.UuidValue? id,
    int? spaceId,
    String? name,
    _isc.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RequiredNoActionChild',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      'parentId': parentId.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RequiredNoActionChild',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      'parentId': parentId.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static RequiredNoActionChildInclude include({
    _iensfz4m.PersonInclude? parent,
  }) {
    return RequiredNoActionChildInclude._(parent: parent);
  }

  static RequiredNoActionChildIncludeList includeList({
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    RequiredNoActionChildInclude? include,
  }) {
    return RequiredNoActionChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RequiredNoActionChildImpl extends RequiredNoActionChild {
  _RequiredNoActionChildImpl({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    required _isc.UuidValue parentId,
    _iensfz4m.Person? parent,
  }) : super._(
         id: id,
         spaceId: spaceId,
         name: name,
         parentId: parentId,
         parent: parent,
       );

  /// Returns a shallow copy of this [RequiredNoActionChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RequiredNoActionChild copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    String? name,
    _isc.UuidValue? parentId,
    Object? parent = _Undefined,
  }) {
    return RequiredNoActionChild(
      id: id is _isc.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class RequiredNoActionChildUpdateTable
    extends _isd.UpdateTable<RequiredNoActionChildTable> {
  RequiredNoActionChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> parentId(
    _isc.UuidValue value,
  ) => _isd.ColumnValue(
    table.parentId,
    value,
  );
}

class RequiredNoActionChildTable extends _isd.Table<_isc.UuidValue?> {
  RequiredNoActionChildTable({super.tableRelation})
    : super(tableName: 'required_no_action_child') {
    updateTable = RequiredNoActionChildUpdateTable(this);
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
    );
  }

  late final RequiredNoActionChildUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
      relationFieldName: 'parent',
      field: RequiredNoActionChild.t.parentId,
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

class RequiredNoActionChildInclude extends _isd.IncludeObject {
  RequiredNoActionChildInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {'parent': _parent};

  @override
  _isd.Table<_isc.UuidValue?> get table => RequiredNoActionChild.t;
}

class RequiredNoActionChildIncludeList extends _isd.IncludeList {
  RequiredNoActionChildIncludeList._({
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(RequiredNoActionChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => RequiredNoActionChild.t;
}

class RequiredNoActionChildRepository {
  const RequiredNoActionChildRepository._();

  final attachRow = const RequiredNoActionChildAttachRowRepository._();

  /// Returns a list of [RequiredNoActionChild]s matching the given query parameters.
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
  Future<List<RequiredNoActionChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    _isd.Transaction? transaction,
    RequiredNoActionChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<RequiredNoActionChild>(
      where: where?.call(RequiredNoActionChild.t),
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [RequiredNoActionChild] matching the given query parameters.
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
  Future<RequiredNoActionChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    _isd.Transaction? transaction,
    RequiredNoActionChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<RequiredNoActionChild>(
      where: where?.call(RequiredNoActionChild.t),
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [RequiredNoActionChild] by its [id] or null if no such row exists.
  Future<RequiredNoActionChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    RequiredNoActionChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<RequiredNoActionChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [RequiredNoActionChild]s in the list and returns the inserted rows.
  ///
  /// The returned [RequiredNoActionChild]s will have their `id` fields set.
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
  Future<List<RequiredNoActionChild>> insert(
    _isd.DatabaseSession session,
    List<RequiredNoActionChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<RequiredNoActionChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [RequiredNoActionChild] and returns the inserted row.
  ///
  /// The returned [RequiredNoActionChild] will have its `id` field set.
  Future<RequiredNoActionChild> insertRow(
    _isd.DatabaseSession session,
    RequiredNoActionChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<RequiredNoActionChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [RequiredNoActionChild]s in the list and returns the resulting rows.
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
  /// The returned [RequiredNoActionChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredNoActionChild>> upsert(
    _isd.DatabaseSession session,
    List<RequiredNoActionChild> rows, {
    required _isd.ColumnSelections<RequiredNoActionChildTable> conflictColumns,
    _isd.ColumnSelections<RequiredNoActionChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<RequiredNoActionChild>(
      rows,
      conflictColumns: conflictColumns(RequiredNoActionChild.t),
      updateColumns: updateColumns?.call(RequiredNoActionChild.t),
      updateWhere: updateWhere?.call(RequiredNoActionChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [RequiredNoActionChild] and returns the resulting row.
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
  /// The returned [RequiredNoActionChild] will have its `id` field set.
  Future<RequiredNoActionChild?> upsertRow(
    _isd.DatabaseSession session,
    RequiredNoActionChild row, {
    required _isd.ColumnSelections<RequiredNoActionChildTable> conflictColumns,
    _isd.ColumnSelections<RequiredNoActionChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<RequiredNoActionChild>(
      row,
      conflictColumns: conflictColumns(RequiredNoActionChild.t),
      updateColumns: updateColumns?.call(RequiredNoActionChild.t),
      updateWhere: updateWhere?.call(RequiredNoActionChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [RequiredNoActionChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredNoActionChild>> update(
    _isd.DatabaseSession session,
    List<RequiredNoActionChild> rows, {
    _isd.ColumnSelections<RequiredNoActionChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<RequiredNoActionChild>(
      rows,
      columns: columns?.call(RequiredNoActionChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [RequiredNoActionChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<RequiredNoActionChild> updateRow(
    _isd.DatabaseSession session,
    RequiredNoActionChild row, {
    _isd.ColumnSelections<RequiredNoActionChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<RequiredNoActionChild>(
      row,
      columns: columns?.call(RequiredNoActionChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [RequiredNoActionChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<RequiredNoActionChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<RequiredNoActionChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<RequiredNoActionChild>(
      id,
      columnValues: columnValues(RequiredNoActionChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [RequiredNoActionChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<RequiredNoActionChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<RequiredNoActionChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<RequiredNoActionChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<RequiredNoActionChild>(
      columnValues: columnValues(RequiredNoActionChild.t.updateTable),
      where: where(RequiredNoActionChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [RequiredNoActionChild]s in the list and returns the deleted rows.
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
  Future<List<RequiredNoActionChild>> delete(
    _isd.DatabaseSession session,
    List<RequiredNoActionChild> rows, {
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<RequiredNoActionChild>(
      rows,
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [RequiredNoActionChild].
  Future<RequiredNoActionChild> deleteRow(
    _isd.DatabaseSession session,
    RequiredNoActionChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<RequiredNoActionChild>(
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
  Future<List<RequiredNoActionChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<RequiredNoActionChildTable> where,
    _isd.OrderByBuilder<RequiredNoActionChildTable>? orderBy,
    _isd.OrderByListBuilder<RequiredNoActionChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<RequiredNoActionChild>(
      where: where(RequiredNoActionChild.t),
      orderBy: orderBy?.call(RequiredNoActionChild.t),
      orderByList: orderByList?.call(RequiredNoActionChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<RequiredNoActionChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<RequiredNoActionChild>(
      where: where?.call(RequiredNoActionChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [RequiredNoActionChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<RequiredNoActionChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<RequiredNoActionChild>(
      where: where(RequiredNoActionChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class RequiredNoActionChildAttachRowRepository {
  const RequiredNoActionChildAttachRowRepository._();

  /// Creates a relation between the given [RequiredNoActionChild] and [Person]
  /// by setting the [RequiredNoActionChild]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _isd.DatabaseSession session,
    RequiredNoActionChild requiredNoActionChild,
    _iensfz4m.Person parent, {
    _isd.Transaction? transaction,
  }) async {
    if (requiredNoActionChild.id == null) {
      throw ArgumentError.notNull('requiredNoActionChild.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $requiredNoActionChild = requiredNoActionChild.copyWith(
      parentId: parent.id,
    );
    await session.db.updateRow<RequiredNoActionChild>(
      $requiredNoActionChild,
      columns: [RequiredNoActionChild.t.parentId],
      transaction: transaction,
    );
  }
}
