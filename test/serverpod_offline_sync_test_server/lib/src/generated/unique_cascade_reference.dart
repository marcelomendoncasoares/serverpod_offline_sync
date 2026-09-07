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

abstract class UniqueCascadeReference
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  UniqueCascadeReference._({
    this.id,
    this.scopeId,
    required this.name,
    this.parentId,
    this.parent,
  });

  factory UniqueCascadeReference({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  }) = _UniqueCascadeReferenceImpl;

  factory UniqueCascadeReference.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return UniqueCascadeReference(
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

  static final t = UniqueCascadeReferenceTable();

  static const db = UniqueCascadeReferenceRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _is.UuidValue? parentId;

  _iensfz4m.Person? parent;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueCascadeReference]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  UniqueCascadeReference copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _is.UuidValue? parentId,
    _iensfz4m.Person? parent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueCascadeReference',
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
      '__className__': 'UniqueCascadeReference',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
    };
  }

  static UniqueCascadeReferenceInclude include({
    _iensfz4m.PersonInclude? parent,
  }) {
    return UniqueCascadeReferenceInclude._(parent: parent);
  }

  static UniqueCascadeReferenceIncludeList includeList({
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    UniqueCascadeReferenceInclude? include,
  }) {
    return UniqueCascadeReferenceIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueCascadeReferenceImpl extends UniqueCascadeReference {
  _UniqueCascadeReferenceImpl({
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

  /// Returns a shallow copy of this [UniqueCascadeReference]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UniqueCascadeReference copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
  }) {
    return UniqueCascadeReference(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
      parent: parent is _iensfz4m.Person? ? parent : this.parent?.copyWith(),
    );
  }
}

class UniqueCascadeReferenceUpdateTable
    extends _is.UpdateTable<UniqueCascadeReferenceTable> {
  UniqueCascadeReferenceUpdateTable(super.table);

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

class UniqueCascadeReferenceTable extends _is.Table<_is.UuidValue?> {
  UniqueCascadeReferenceTable({super.tableRelation})
    : super(tableName: 'unique_cascade_reference') {
    updateTable = UniqueCascadeReferenceUpdateTable(this);
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

  late final UniqueCascadeReferenceUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid parentId;

  _iensfz4m.PersonTable? _parent;

  _iensfz4m.PersonTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: UniqueCascadeReference.t.parentId,
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

class UniqueCascadeReferenceInclude extends _is.IncludeObject {
  UniqueCascadeReferenceInclude._({_iensfz4m.PersonInclude? parent}) {
    _parent = parent;
  }

  _iensfz4m.PersonInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueCascadeReference.t;
}

class UniqueCascadeReferenceIncludeList extends _is.IncludeList {
  UniqueCascadeReferenceIncludeList._({
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueCascadeReference.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => UniqueCascadeReference.t;
}

class UniqueCascadeReferenceRepository {
  const UniqueCascadeReferenceRepository._();

  final attachRow = const UniqueCascadeReferenceAttachRowRepository._();

  final detachRow = const UniqueCascadeReferenceDetachRowRepository._();

  /// Returns a list of [UniqueCascadeReference]s matching the given query parameters.
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
  Future<List<UniqueCascadeReference>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    _is.Transaction? transaction,
    UniqueCascadeReferenceInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueCascadeReference>(
      where: where?.call(UniqueCascadeReference.t),
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueCascadeReference] matching the given query parameters.
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
  Future<UniqueCascadeReference?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? where,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    _is.Transaction? transaction,
    UniqueCascadeReferenceInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueCascadeReference>(
      where: where?.call(UniqueCascadeReference.t),
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueCascadeReference] by its [id] or null if no such row exists.
  Future<UniqueCascadeReference?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    UniqueCascadeReferenceInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueCascadeReference>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueCascadeReference]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueCascadeReference]s will have their `id` fields set.
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
  Future<List<UniqueCascadeReference>> insert(
    _is.DatabaseSession session,
    List<UniqueCascadeReference> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueCascadeReference>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueCascadeReference] and returns the inserted row.
  ///
  /// The returned [UniqueCascadeReference] will have its `id` field set.
  Future<UniqueCascadeReference> insertRow(
    _is.DatabaseSession session,
    UniqueCascadeReference row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueCascadeReference>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueCascadeReference]s in the list and returns the resulting rows.
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
  /// The returned [UniqueCascadeReference]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeReference>> upsert(
    _is.DatabaseSession session,
    List<UniqueCascadeReference> rows, {
    required _is.ColumnSelections<UniqueCascadeReferenceTable> conflictColumns,
    _is.ColumnSelections<UniqueCascadeReferenceTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueCascadeReference>(
      rows,
      conflictColumns: conflictColumns(UniqueCascadeReference.t),
      updateColumns: updateColumns?.call(UniqueCascadeReference.t),
      updateWhere: updateWhere?.call(UniqueCascadeReference.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueCascadeReference] and returns the resulting row.
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
  /// The returned [UniqueCascadeReference] will have its `id` field set.
  Future<UniqueCascadeReference?> upsertRow(
    _is.DatabaseSession session,
    UniqueCascadeReference row, {
    required _is.ColumnSelections<UniqueCascadeReferenceTable> conflictColumns,
    _is.ColumnSelections<UniqueCascadeReferenceTable>? updateColumns,
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueCascadeReference>(
      row,
      conflictColumns: conflictColumns(UniqueCascadeReference.t),
      updateColumns: updateColumns?.call(UniqueCascadeReference.t),
      updateWhere: updateWhere?.call(UniqueCascadeReference.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueCascadeReference]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeReference>> update(
    _is.DatabaseSession session,
    List<UniqueCascadeReference> rows, {
    _is.ColumnSelections<UniqueCascadeReferenceTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueCascadeReference>(
      rows,
      columns: columns?.call(UniqueCascadeReference.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueCascadeReference]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueCascadeReference> updateRow(
    _is.DatabaseSession session,
    UniqueCascadeReference row, {
    _is.ColumnSelections<UniqueCascadeReferenceTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueCascadeReference>(
      row,
      columns: columns?.call(UniqueCascadeReference.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueCascadeReference] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueCascadeReference?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<UniqueCascadeReferenceUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueCascadeReference>(
      id,
      columnValues: columnValues(UniqueCascadeReference.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueCascadeReference]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueCascadeReference>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<UniqueCascadeReferenceUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<UniqueCascadeReferenceTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueCascadeReference>(
      columnValues: columnValues(UniqueCascadeReference.t.updateTable),
      where: where(UniqueCascadeReference.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueCascadeReference]s in the list and returns the deleted rows.
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
  Future<List<UniqueCascadeReference>> delete(
    _is.DatabaseSession session,
    List<UniqueCascadeReference> rows, {
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueCascadeReference>(
      rows,
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueCascadeReference].
  Future<UniqueCascadeReference> deleteRow(
    _is.DatabaseSession session,
    UniqueCascadeReference row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueCascadeReference>(
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
  Future<List<UniqueCascadeReference>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueCascadeReferenceTable> where,
    _is.OrderByBuilder<UniqueCascadeReferenceTable>? orderBy,
    _is.OrderByListBuilder<UniqueCascadeReferenceTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueCascadeReference>(
      where: where(UniqueCascadeReference.t),
      orderBy: orderBy?.call(UniqueCascadeReference.t),
      orderByList: orderByList?.call(UniqueCascadeReference.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<UniqueCascadeReferenceTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<UniqueCascadeReference>(
      where: where?.call(UniqueCascadeReference.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueCascadeReference] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<UniqueCascadeReferenceTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueCascadeReference>(
      where: where(UniqueCascadeReference.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueCascadeReferenceAttachRowRepository {
  const UniqueCascadeReferenceAttachRowRepository._();

  /// Creates a relation between the given [UniqueCascadeReference] and [Person]
  /// by setting the [UniqueCascadeReference]'s foreign key `parentId` to refer to the [Person].
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueCascadeReference uniqueCascadeReference,
    _iensfz4m.Person parent, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueCascadeReference.id == null) {
      throw ArgumentError.notNull('uniqueCascadeReference.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $uniqueCascadeReference = uniqueCascadeReference.copyWith(
      parentId: parent.id,
    );
    await session.db.updateRow<UniqueCascadeReference>(
      $uniqueCascadeReference,
      columns: [UniqueCascadeReference.t.parentId],
      transaction: transaction,
    );
  }
}

class UniqueCascadeReferenceDetachRowRepository {
  const UniqueCascadeReferenceDetachRowRepository._();

  /// Detaches the relation between this [UniqueCascadeReference] and the [Person] set in `parent`
  /// by setting the [UniqueCascadeReference]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    UniqueCascadeReference uniqueCascadeReference, {
    _is.Transaction? transaction,
  }) async {
    if (uniqueCascadeReference.id == null) {
      throw ArgumentError.notNull('uniqueCascadeReference.id');
    }

    var $uniqueCascadeReference = uniqueCascadeReference.copyWith(
      parentId: null,
    );
    await session.db.updateRow<UniqueCascadeReference>(
      $uniqueCascadeReference,
      columns: [UniqueCascadeReference.t.parentId],
      transaction: transaction,
    );
  }
}
