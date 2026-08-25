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
import '../fk_chain/restrict_blocker.dart' as _iavpmkia;

abstract class FkChainMiddleSetNullChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  FkChainMiddleSetNullChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.restrictBlocker,
    this.restrictBlockerId,
  });

  factory FkChainMiddleSetNullChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
    _isc.UuidValue? restrictBlockerId,
  }) = _FkChainMiddleSetNullChildImpl;

  factory FkChainMiddleSetNullChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainMiddleSetNullChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      restrictBlocker: jsonSerialization['restrictBlocker'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iavpmkia.FkChainRestrictBlocker>(
              jsonSerialization['restrictBlocker'],
            ),
      restrictBlockerId: jsonSerialization['restrictBlockerId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['restrictBlockerId'],
            ),
    );
  }

  static final t = FkChainMiddleSetNullChildTable();

  static const db = FkChainMiddleSetNullChildRepository._();

  @override
  _isc.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _iavpmkia.FkChainRestrictBlocker? restrictBlocker;

  _isc.UuidValue? restrictBlockerId;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainMiddleSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FkChainMiddleSetNullChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
    _isc.UuidValue? restrictBlockerId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainMiddleSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlocker != null) 'restrictBlocker': restrictBlocker?.toJson(),
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainMiddleSetNullChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlocker != null)
        'restrictBlocker': restrictBlocker?.toJsonForProtocol(),
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
    };
  }

  static FkChainMiddleSetNullChildInclude include({
    _iavpmkia.FkChainRestrictBlockerInclude? restrictBlocker,
  }) {
    return FkChainMiddleSetNullChildInclude._(restrictBlocker: restrictBlocker);
  }

  static FkChainMiddleSetNullChildIncludeList includeList({
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    FkChainMiddleSetNullChildInclude? include,
  }) {
    return FkChainMiddleSetNullChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainMiddleSetNullChildImpl extends FkChainMiddleSetNullChild {
  _FkChainMiddleSetNullChildImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
    _isc.UuidValue? restrictBlockerId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         restrictBlocker: restrictBlocker,
         restrictBlockerId: restrictBlockerId,
       );

  /// Returns a shallow copy of this [FkChainMiddleSetNullChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FkChainMiddleSetNullChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? restrictBlocker = _Undefined,
    Object? restrictBlockerId = _Undefined,
  }) {
    return FkChainMiddleSetNullChild(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      restrictBlocker: restrictBlocker is _iavpmkia.FkChainRestrictBlocker?
          ? restrictBlocker
          : this.restrictBlocker?.copyWith(),
      restrictBlockerId: restrictBlockerId is _isc.UuidValue?
          ? restrictBlockerId
          : this.restrictBlockerId,
    );
  }
}

class FkChainMiddleSetNullChildUpdateTable
    extends _isd.UpdateTable<FkChainMiddleSetNullChildTable> {
  FkChainMiddleSetNullChildUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> restrictBlockerId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.restrictBlockerId,
    value,
  );
}

class FkChainMiddleSetNullChildTable extends _isd.Table<_isc.UuidValue?> {
  FkChainMiddleSetNullChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_middle_set_null_child') {
    updateTable = FkChainMiddleSetNullChildUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    restrictBlockerId = _isd.ColumnUuid(
      'restrictBlockerId',
      this,
    );
  }

  late final FkChainMiddleSetNullChildUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  _iavpmkia.FkChainRestrictBlockerTable? _restrictBlocker;

  late final _isd.ColumnUuid restrictBlockerId;

  _iavpmkia.FkChainRestrictBlockerTable get restrictBlocker {
    if (_restrictBlocker != null) return _restrictBlocker!;
    _restrictBlocker = _isd.createRelationTable(
      relationFieldName: 'restrictBlocker',
      field: FkChainMiddleSetNullChild.t.restrictBlockerId,
      foreignField: _iavpmkia.FkChainRestrictBlocker.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iavpmkia.FkChainRestrictBlockerTable(
            tableRelation: foreignTableRelation,
          ),
    );
    return _restrictBlocker!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
    restrictBlockerId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'restrictBlocker') {
      return restrictBlocker;
    }
    return null;
  }
}

class FkChainMiddleSetNullChildInclude extends _isd.IncludeObject {
  FkChainMiddleSetNullChildInclude._({
    _iavpmkia.FkChainRestrictBlockerInclude? restrictBlocker,
  }) {
    _restrictBlocker = restrictBlocker;
  }

  _iavpmkia.FkChainRestrictBlockerInclude? _restrictBlocker;

  @override
  Map<String, _isd.Include?> get includes => {
    'restrictBlocker': _restrictBlocker,
  };

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainMiddleSetNullChild.t;
}

class FkChainMiddleSetNullChildIncludeList extends _isd.IncludeList {
  FkChainMiddleSetNullChildIncludeList._({
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainMiddleSetNullChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainMiddleSetNullChild.t;
}

class FkChainMiddleSetNullChildRepository {
  const FkChainMiddleSetNullChildRepository._();

  final attachRow = const FkChainMiddleSetNullChildAttachRowRepository._();

  final detachRow = const FkChainMiddleSetNullChildDetachRowRepository._();

  /// Returns a list of [FkChainMiddleSetNullChild]s matching the given query parameters.
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
  Future<List<FkChainMiddleSetNullChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainMiddleSetNullChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainMiddleSetNullChild>(
      where: where?.call(FkChainMiddleSetNullChild.t),
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainMiddleSetNullChild] matching the given query parameters.
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
  Future<FkChainMiddleSetNullChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainMiddleSetNullChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainMiddleSetNullChild>(
      where: where?.call(FkChainMiddleSetNullChild.t),
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainMiddleSetNullChild] by its [id] or null if no such row exists.
  Future<FkChainMiddleSetNullChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    FkChainMiddleSetNullChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainMiddleSetNullChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainMiddleSetNullChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainMiddleSetNullChild]s will have their `id` fields set.
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
  Future<List<FkChainMiddleSetNullChild>> insert(
    _isd.DatabaseSession session,
    List<FkChainMiddleSetNullChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainMiddleSetNullChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainMiddleSetNullChild] and returns the inserted row.
  ///
  /// The returned [FkChainMiddleSetNullChild] will have its `id` field set.
  Future<FkChainMiddleSetNullChild> insertRow(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainMiddleSetNullChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainMiddleSetNullChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainMiddleSetNullChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleSetNullChild>> upsert(
    _isd.DatabaseSession session,
    List<FkChainMiddleSetNullChild> rows, {
    required _isd.ColumnSelections<FkChainMiddleSetNullChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainMiddleSetNullChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainMiddleSetNullChild>(
      rows,
      conflictColumns: conflictColumns(FkChainMiddleSetNullChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleSetNullChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainMiddleSetNullChild] and returns the resulting row.
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
  /// The returned [FkChainMiddleSetNullChild] will have its `id` field set.
  Future<FkChainMiddleSetNullChild?> upsertRow(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild row, {
    required _isd.ColumnSelections<FkChainMiddleSetNullChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainMiddleSetNullChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainMiddleSetNullChild>(
      row,
      conflictColumns: conflictColumns(FkChainMiddleSetNullChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleSetNullChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleSetNullChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleSetNullChild>> update(
    _isd.DatabaseSession session,
    List<FkChainMiddleSetNullChild> rows, {
    _isd.ColumnSelections<FkChainMiddleSetNullChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainMiddleSetNullChild>(
      rows,
      columns: columns?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainMiddleSetNullChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainMiddleSetNullChild> updateRow(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild row, {
    _isd.ColumnSelections<FkChainMiddleSetNullChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainMiddleSetNullChild>(
      row,
      columns: columns?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainMiddleSetNullChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainMiddleSetNullChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<FkChainMiddleSetNullChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainMiddleSetNullChild>(
      id,
      columnValues: columnValues(FkChainMiddleSetNullChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleSetNullChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleSetNullChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FkChainMiddleSetNullChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainMiddleSetNullChild>(
      columnValues: columnValues(FkChainMiddleSetNullChild.t.updateTable),
      where: where(FkChainMiddleSetNullChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainMiddleSetNullChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainMiddleSetNullChild>> delete(
    _isd.DatabaseSession session,
    List<FkChainMiddleSetNullChild> rows, {
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainMiddleSetNullChild>(
      rows,
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainMiddleSetNullChild].
  Future<FkChainMiddleSetNullChild> deleteRow(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainMiddleSetNullChild>(
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
  Future<List<FkChainMiddleSetNullChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable> where,
    _isd.OrderByBuilder<FkChainMiddleSetNullChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleSetNullChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainMiddleSetNullChild>(
      where: where(FkChainMiddleSetNullChild.t),
      orderBy: orderBy?.call(FkChainMiddleSetNullChild.t),
      orderByList: orderByList?.call(FkChainMiddleSetNullChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FkChainMiddleSetNullChild>(
      where: where?.call(FkChainMiddleSetNullChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainMiddleSetNullChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainMiddleSetNullChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainMiddleSetNullChild>(
      where: where(FkChainMiddleSetNullChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainMiddleSetNullChildAttachRowRepository {
  const FkChainMiddleSetNullChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainMiddleSetNullChild] and [FkChainRestrictBlocker]
  /// by setting the [FkChainMiddleSetNullChild]'s foreign key `restrictBlockerId` to refer to the [FkChainRestrictBlocker].
  Future<void> restrictBlocker(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild fkChainMiddleSetNullChild,
    _iavpmkia.FkChainRestrictBlocker restrictBlocker, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainMiddleSetNullChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleSetNullChild.id');
    }
    if (restrictBlocker.id == null) {
      throw ArgumentError.notNull('restrictBlocker.id');
    }

    var $fkChainMiddleSetNullChild = fkChainMiddleSetNullChild.copyWith(
      restrictBlockerId: restrictBlocker.id,
    );
    await session.db.updateRow<FkChainMiddleSetNullChild>(
      $fkChainMiddleSetNullChild,
      columns: [FkChainMiddleSetNullChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}

class FkChainMiddleSetNullChildDetachRowRepository {
  const FkChainMiddleSetNullChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainMiddleSetNullChild] and the [FkChainRestrictBlocker] set in `restrictBlocker`
  /// by setting the [FkChainMiddleSetNullChild]'s foreign key `restrictBlockerId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> restrictBlocker(
    _isd.DatabaseSession session,
    FkChainMiddleSetNullChild fkChainMiddleSetNullChild, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainMiddleSetNullChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleSetNullChild.id');
    }

    var $fkChainMiddleSetNullChild = fkChainMiddleSetNullChild.copyWith(
      restrictBlockerId: null,
    );
    await session.db.updateRow<FkChainMiddleSetNullChild>(
      $fkChainMiddleSetNullChild,
      columns: [FkChainMiddleSetNullChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}
