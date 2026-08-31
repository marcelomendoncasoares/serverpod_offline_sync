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
import '../fk_chain/root.dart' as _iv6n0jeb;

abstract class FkChainCascadeMiddle
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  FkChainCascadeMiddle._({
    this.id,
    this.scopeId,
    required this.name,
    this.rootId,
    this.root,
  });

  factory FkChainCascadeMiddle({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? rootId,
    _iv6n0jeb.FkChainRoot? root,
  }) = _FkChainCascadeMiddleImpl;

  factory FkChainCascadeMiddle.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainCascadeMiddle(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      rootId: jsonSerialization['rootId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['rootId']),
      root: jsonSerialization['root'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_iv6n0jeb.FkChainRoot>(
              jsonSerialization['root'],
            ),
    );
  }

  static final t = FkChainCascadeMiddleTable();

  static const db = FkChainCascadeMiddleRepository._();

  @override
  _is.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _is.UuidValue? rootId;

  _iv6n0jeb.FkChainRoot? root;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainCascadeMiddle]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FkChainCascadeMiddle copyWith({
    _is.UuidValue? id,
    int? scopeId,
    String? name,
    _is.UuidValue? rootId,
    _iv6n0jeb.FkChainRoot? root,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainCascadeMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (rootId != null) 'rootId': rootId?.toJson(),
      if (root != null) 'root': root?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainCascadeMiddle',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (rootId != null) 'rootId': rootId?.toJson(),
      if (root != null) 'root': root?.toJsonForProtocol(),
    };
  }

  static FkChainCascadeMiddleInclude include({
    _iv6n0jeb.FkChainRootInclude? root,
  }) {
    return FkChainCascadeMiddleInclude._(root: root);
  }

  static FkChainCascadeMiddleIncludeList includeList({
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    FkChainCascadeMiddleInclude? include,
  }) {
    return FkChainCascadeMiddleIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainCascadeMiddleImpl extends FkChainCascadeMiddle {
  _FkChainCascadeMiddleImpl({
    _is.UuidValue? id,
    int? scopeId,
    required String name,
    _is.UuidValue? rootId,
    _iv6n0jeb.FkChainRoot? root,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         rootId: rootId,
         root: root,
       );

  /// Returns a shallow copy of this [FkChainCascadeMiddle]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FkChainCascadeMiddle copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? rootId = _Undefined,
    Object? root = _Undefined,
  }) {
    return FkChainCascadeMiddle(
      id: id is _is.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      rootId: rootId is _is.UuidValue? ? rootId : this.rootId,
      root: root is _iv6n0jeb.FkChainRoot? ? root : this.root?.copyWith(),
    );
  }
}

class FkChainCascadeMiddleUpdateTable
    extends _is.UpdateTable<FkChainCascadeMiddleTable> {
  FkChainCascadeMiddleUpdateTable(super.table);

  _is.ColumnValue<int, int> scopeId(int? value) => _is.ColumnValue(
    table.scopeId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> rootId(_is.UuidValue? value) =>
      _is.ColumnValue(
        table.rootId,
        value,
      );
}

class FkChainCascadeMiddleTable extends _is.Table<_is.UuidValue?> {
  FkChainCascadeMiddleTable({super.tableRelation})
    : super(tableName: 'fk_chain_cascade_middle') {
    updateTable = FkChainCascadeMiddleUpdateTable(this);
    scopeId = _is.ColumnInt(
      'scopeId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    rootId = _is.ColumnUuid(
      'rootId',
      this,
    );
  }

  late final FkChainCascadeMiddleUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _is.ColumnInt scopeId;

  late final _is.ColumnString name;

  late final _is.ColumnUuid rootId;

  _iv6n0jeb.FkChainRootTable? _root;

  _iv6n0jeb.FkChainRootTable get root {
    if (_root != null) return _root!;
    _root = _is.createRelationTable(
      relationFieldName: 'root',
      field: FkChainCascadeMiddle.t.rootId,
      foreignField: _iv6n0jeb.FkChainRoot.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iv6n0jeb.FkChainRootTable(tableRelation: foreignTableRelation),
    );
    return _root!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    scopeId,
    name,
    rootId,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'root') {
      return root;
    }
    return null;
  }
}

class FkChainCascadeMiddleInclude extends _is.IncludeObject {
  FkChainCascadeMiddleInclude._({_iv6n0jeb.FkChainRootInclude? root}) {
    _root = root;
  }

  _iv6n0jeb.FkChainRootInclude? _root;

  @override
  Map<String, _is.Include?> get includes => {'root': _root};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainCascadeMiddle.t;
}

class FkChainCascadeMiddleIncludeList extends _is.IncludeList {
  FkChainCascadeMiddleIncludeList._({
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainCascadeMiddle.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => FkChainCascadeMiddle.t;
}

class FkChainCascadeMiddleRepository {
  const FkChainCascadeMiddleRepository._();

  final attachRow = const FkChainCascadeMiddleAttachRowRepository._();

  final detachRow = const FkChainCascadeMiddleDetachRowRepository._();

  /// Returns a list of [FkChainCascadeMiddle]s matching the given query parameters.
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
  Future<List<FkChainCascadeMiddle>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _is.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainCascadeMiddle] matching the given query parameters.
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
  Future<FkChainCascadeMiddle?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? offset,
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _is.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainCascadeMiddle] by its [id] or null if no such row exists.
  Future<FkChainCascadeMiddle?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    FkChainCascadeMiddleInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainCascadeMiddle>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainCascadeMiddle]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainCascadeMiddle]s will have their `id` fields set.
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
  Future<List<FkChainCascadeMiddle>> insert(
    _is.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainCascadeMiddle>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainCascadeMiddle] and returns the inserted row.
  ///
  /// The returned [FkChainCascadeMiddle] will have its `id` field set.
  Future<FkChainCascadeMiddle> insertRow(
    _is.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainCascadeMiddle>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainCascadeMiddle]s in the list and returns the resulting rows.
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
  /// The returned [FkChainCascadeMiddle]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> upsert(
    _is.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    required _is.ColumnSelections<FkChainCascadeMiddleTable> conflictColumns,
    _is.ColumnSelections<FkChainCascadeMiddleTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainCascadeMiddle>(
      rows,
      conflictColumns: conflictColumns(FkChainCascadeMiddle.t),
      updateColumns: updateColumns?.call(FkChainCascadeMiddle.t),
      updateWhere: updateWhere?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainCascadeMiddle] and returns the resulting row.
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
  /// The returned [FkChainCascadeMiddle] will have its `id` field set.
  Future<FkChainCascadeMiddle?> upsertRow(
    _is.DatabaseSession session,
    FkChainCascadeMiddle row, {
    required _is.ColumnSelections<FkChainCascadeMiddleTable> conflictColumns,
    _is.ColumnSelections<FkChainCascadeMiddleTable>? updateColumns,
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainCascadeMiddle>(
      row,
      conflictColumns: conflictColumns(FkChainCascadeMiddle.t),
      updateColumns: updateColumns?.call(FkChainCascadeMiddle.t),
      updateWhere: updateWhere?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainCascadeMiddle]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> update(
    _is.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _is.ColumnSelections<FkChainCascadeMiddleTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainCascadeMiddle>(
      rows,
      columns: columns?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainCascadeMiddle]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainCascadeMiddle> updateRow(
    _is.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _is.ColumnSelections<FkChainCascadeMiddleTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainCascadeMiddle>(
      row,
      columns: columns?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainCascadeMiddle] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainCascadeMiddle?> updateById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<FkChainCascadeMiddleUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainCascadeMiddle>(
      id,
      columnValues: columnValues(FkChainCascadeMiddle.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainCascadeMiddle]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainCascadeMiddle>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<FkChainCascadeMiddleUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainCascadeMiddle>(
      columnValues: columnValues(FkChainCascadeMiddle.t.updateTable),
      where: where(FkChainCascadeMiddle.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainCascadeMiddle]s in the list and returns the deleted rows.
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
  Future<List<FkChainCascadeMiddle>> delete(
    _is.DatabaseSession session,
    List<FkChainCascadeMiddle> rows, {
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainCascadeMiddle>(
      rows,
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainCascadeMiddle].
  Future<FkChainCascadeMiddle> deleteRow(
    _is.DatabaseSession session,
    FkChainCascadeMiddle row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainCascadeMiddle>(
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
  Future<List<FkChainCascadeMiddle>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    _is.OrderByBuilder<FkChainCascadeMiddleTable>? orderBy,
    _is.OrderByListBuilder<FkChainCascadeMiddleTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainCascadeMiddle>(
      where: where(FkChainCascadeMiddle.t),
      orderBy: orderBy?.call(FkChainCascadeMiddle.t),
      orderByList: orderByList?.call(FkChainCascadeMiddle.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<FkChainCascadeMiddleTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<FkChainCascadeMiddle>(
      where: where?.call(FkChainCascadeMiddle.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainCascadeMiddle] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<FkChainCascadeMiddleTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainCascadeMiddle>(
      where: where(FkChainCascadeMiddle.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainCascadeMiddleAttachRowRepository {
  const FkChainCascadeMiddleAttachRowRepository._();

  /// Creates a relation between the given [FkChainCascadeMiddle] and [FkChainRoot]
  /// by setting the [FkChainCascadeMiddle]'s foreign key `rootId` to refer to the [FkChainRoot].
  Future<void> root(
    _is.DatabaseSession session,
    FkChainCascadeMiddle fkChainCascadeMiddle,
    _iv6n0jeb.FkChainRoot root, {
    _is.Transaction? transaction,
  }) async {
    if (fkChainCascadeMiddle.id == null) {
      throw ArgumentError.notNull('fkChainCascadeMiddle.id');
    }
    if (root.id == null) {
      throw ArgumentError.notNull('root.id');
    }

    var $fkChainCascadeMiddle = fkChainCascadeMiddle.copyWith(rootId: root.id);
    await session.db.updateRow<FkChainCascadeMiddle>(
      $fkChainCascadeMiddle,
      columns: [FkChainCascadeMiddle.t.rootId],
      transaction: transaction,
    );
  }
}

class FkChainCascadeMiddleDetachRowRepository {
  const FkChainCascadeMiddleDetachRowRepository._();

  /// Detaches the relation between this [FkChainCascadeMiddle] and the [FkChainRoot] set in `root`
  /// by setting the [FkChainCascadeMiddle]'s foreign key `rootId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> root(
    _is.DatabaseSession session,
    FkChainCascadeMiddle fkChainCascadeMiddle, {
    _is.Transaction? transaction,
  }) async {
    if (fkChainCascadeMiddle.id == null) {
      throw ArgumentError.notNull('fkChainCascadeMiddle.id');
    }

    var $fkChainCascadeMiddle = fkChainCascadeMiddle.copyWith(rootId: null);
    await session.db.updateRow<FkChainCascadeMiddle>(
      $fkChainCascadeMiddle,
      columns: [FkChainCascadeMiddle.t.rootId],
      transaction: transaction,
    );
  }
}
