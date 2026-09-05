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

abstract class FkChainMiddleCascadeChild
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  FkChainMiddleCascadeChild._({
    this.id,
    this.scopeId,
    required this.name,
    this.restrictBlockerId,
    this.restrictBlocker,
  });

  factory FkChainMiddleCascadeChild({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? restrictBlockerId,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
  }) = _FkChainMiddleCascadeChildImpl;

  factory FkChainMiddleCascadeChild.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FkChainMiddleCascadeChild(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      restrictBlockerId: jsonSerialization['restrictBlockerId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['restrictBlockerId'],
            ),
      restrictBlocker: jsonSerialization['restrictBlocker'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iavpmkia.FkChainRestrictBlocker>(
              jsonSerialization['restrictBlocker'],
            ),
    );
  }

  static final t = FkChainMiddleCascadeChildTable();

  static const db = FkChainMiddleCascadeChildRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _isc.UuidValue? restrictBlockerId;

  _iavpmkia.FkChainRestrictBlocker? restrictBlocker;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [FkChainMiddleCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FkChainMiddleCascadeChild copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _isc.UuidValue? restrictBlockerId,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FkChainMiddleCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
      if (restrictBlocker != null) 'restrictBlocker': restrictBlocker?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FkChainMiddleCascadeChild',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (restrictBlockerId != null)
        'restrictBlockerId': restrictBlockerId?.toJson(),
      if (restrictBlocker != null)
        'restrictBlocker': restrictBlocker?.toJsonForProtocol(),
    };
  }

  static FkChainMiddleCascadeChildInclude include({
    _iavpmkia.FkChainRestrictBlockerInclude? restrictBlocker,
  }) {
    return FkChainMiddleCascadeChildInclude._(restrictBlocker: restrictBlocker);
  }

  static FkChainMiddleCascadeChildIncludeList includeList({
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    FkChainMiddleCascadeChildInclude? include,
  }) {
    return FkChainMiddleCascadeChildIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _FkChainMiddleCascadeChildImpl extends FkChainMiddleCascadeChild {
  _FkChainMiddleCascadeChildImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _isc.UuidValue? restrictBlockerId,
    _iavpmkia.FkChainRestrictBlocker? restrictBlocker,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         restrictBlockerId: restrictBlockerId,
         restrictBlocker: restrictBlocker,
       );

  /// Returns a shallow copy of this [FkChainMiddleCascadeChild]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FkChainMiddleCascadeChild copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? restrictBlockerId = _Undefined,
    Object? restrictBlocker = _Undefined,
  }) {
    return FkChainMiddleCascadeChild(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      restrictBlockerId: restrictBlockerId is _isc.UuidValue?
          ? restrictBlockerId
          : this.restrictBlockerId,
      restrictBlocker: restrictBlocker is _iavpmkia.FkChainRestrictBlocker?
          ? restrictBlocker
          : this.restrictBlocker?.copyWith(),
    );
  }
}

class FkChainMiddleCascadeChildUpdateTable
    extends _isd.UpdateTable<FkChainMiddleCascadeChildTable> {
  FkChainMiddleCascadeChildUpdateTable(super.table);

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

class FkChainMiddleCascadeChildTable extends _isd.Table<_isc.UuidValue?> {
  FkChainMiddleCascadeChildTable({super.tableRelation})
    : super(tableName: 'fk_chain_middle_cascade_child') {
    updateTable = FkChainMiddleCascadeChildUpdateTable(this);
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

  late final FkChainMiddleCascadeChildUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid restrictBlockerId;

  _iavpmkia.FkChainRestrictBlockerTable? _restrictBlocker;

  _iavpmkia.FkChainRestrictBlockerTable get restrictBlocker {
    if (_restrictBlocker != null) return _restrictBlocker!;
    _restrictBlocker = _isd.createRelationTable(
      relationFieldName: 'restrictBlocker',
      field: FkChainMiddleCascadeChild.t.restrictBlockerId,
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

class FkChainMiddleCascadeChildInclude extends _isd.IncludeObject {
  FkChainMiddleCascadeChildInclude._({
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
  _isd.Table<_isc.UuidValue?> get table => FkChainMiddleCascadeChild.t;
}

class FkChainMiddleCascadeChildIncludeList extends _isd.IncludeList {
  FkChainMiddleCascadeChildIncludeList._({
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(FkChainMiddleCascadeChild.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => FkChainMiddleCascadeChild.t;
}

class FkChainMiddleCascadeChildRepository {
  const FkChainMiddleCascadeChildRepository._();

  final attachRow = const FkChainMiddleCascadeChildAttachRowRepository._();

  final detachRow = const FkChainMiddleCascadeChildDetachRowRepository._();

  /// Returns a list of [FkChainMiddleCascadeChild]s matching the given query parameters.
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
  Future<List<FkChainMiddleCascadeChild>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [FkChainMiddleCascadeChild] matching the given query parameters.
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
  Future<FkChainMiddleCascadeChild?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [FkChainMiddleCascadeChild] by its [id] or null if no such row exists.
  Future<FkChainMiddleCascadeChild?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    FkChainMiddleCascadeChildInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<FkChainMiddleCascadeChild>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [FkChainMiddleCascadeChild]s in the list and returns the inserted rows.
  ///
  /// The returned [FkChainMiddleCascadeChild]s will have their `id` fields set.
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
  Future<List<FkChainMiddleCascadeChild>> insert(
    _isd.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<FkChainMiddleCascadeChild>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [FkChainMiddleCascadeChild] and returns the inserted row.
  ///
  /// The returned [FkChainMiddleCascadeChild] will have its `id` field set.
  Future<FkChainMiddleCascadeChild> insertRow(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<FkChainMiddleCascadeChild>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [FkChainMiddleCascadeChild]s in the list and returns the resulting rows.
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
  /// The returned [FkChainMiddleCascadeChild]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> upsert(
    _isd.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    required _isd.ColumnSelections<FkChainMiddleCascadeChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainMiddleCascadeChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<FkChainMiddleCascadeChild>(
      rows,
      conflictColumns: conflictColumns(FkChainMiddleCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [FkChainMiddleCascadeChild] and returns the resulting row.
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
  /// The returned [FkChainMiddleCascadeChild] will have its `id` field set.
  Future<FkChainMiddleCascadeChild?> upsertRow(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    required _isd.ColumnSelections<FkChainMiddleCascadeChildTable>
    conflictColumns,
    _isd.ColumnSelections<FkChainMiddleCascadeChildTable>? updateColumns,
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<FkChainMiddleCascadeChild>(
      row,
      conflictColumns: conflictColumns(FkChainMiddleCascadeChild.t),
      updateColumns: updateColumns?.call(FkChainMiddleCascadeChild.t),
      updateWhere: updateWhere?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleCascadeChild]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> update(
    _isd.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _isd.ColumnSelections<FkChainMiddleCascadeChildTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<FkChainMiddleCascadeChild>(
      rows,
      columns: columns?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [FkChainMiddleCascadeChild]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<FkChainMiddleCascadeChild> updateRow(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _isd.ColumnSelections<FkChainMiddleCascadeChildTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<FkChainMiddleCascadeChild>(
      row,
      columns: columns?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
    );
  }

  /// Updates a single [FkChainMiddleCascadeChild] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<FkChainMiddleCascadeChild?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<FkChainMiddleCascadeChildUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<FkChainMiddleCascadeChild>(
      id,
      columnValues: columnValues(FkChainMiddleCascadeChild.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [FkChainMiddleCascadeChild]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<FkChainMiddleCascadeChild>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<FkChainMiddleCascadeChildUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<FkChainMiddleCascadeChild>(
      columnValues: columnValues(FkChainMiddleCascadeChild.t.updateTable),
      where: where(FkChainMiddleCascadeChild.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [FkChainMiddleCascadeChild]s in the list and returns the deleted rows.
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
  Future<List<FkChainMiddleCascadeChild>> delete(
    _isd.DatabaseSession session,
    List<FkChainMiddleCascadeChild> rows, {
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<FkChainMiddleCascadeChild>(
      rows,
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [FkChainMiddleCascadeChild].
  Future<FkChainMiddleCascadeChild> deleteRow(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<FkChainMiddleCascadeChild>(
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
  Future<List<FkChainMiddleCascadeChild>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    _isd.OrderByBuilder<FkChainMiddleCascadeChildTable>? orderBy,
    _isd.OrderByListBuilder<FkChainMiddleCascadeChildTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<FkChainMiddleCascadeChild>(
      where: where(FkChainMiddleCascadeChild.t),
      orderBy: orderBy?.call(FkChainMiddleCascadeChild.t),
      orderByList: orderByList?.call(FkChainMiddleCascadeChild.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<FkChainMiddleCascadeChild>(
      where: where?.call(FkChainMiddleCascadeChild.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [FkChainMiddleCascadeChild] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<FkChainMiddleCascadeChildTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<FkChainMiddleCascadeChild>(
      where: where(FkChainMiddleCascadeChild.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class FkChainMiddleCascadeChildAttachRowRepository {
  const FkChainMiddleCascadeChildAttachRowRepository._();

  /// Creates a relation between the given [FkChainMiddleCascadeChild] and [FkChainRestrictBlocker]
  /// by setting the [FkChainMiddleCascadeChild]'s foreign key `restrictBlockerId` to refer to the [FkChainRestrictBlocker].
  Future<void> restrictBlocker(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild fkChainMiddleCascadeChild,
    _iavpmkia.FkChainRestrictBlocker restrictBlocker, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainMiddleCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleCascadeChild.id');
    }
    if (restrictBlocker.id == null) {
      throw ArgumentError.notNull('restrictBlocker.id');
    }

    var $fkChainMiddleCascadeChild = fkChainMiddleCascadeChild.copyWith(
      restrictBlockerId: restrictBlocker.id,
    );
    await session.db.updateRow<FkChainMiddleCascadeChild>(
      $fkChainMiddleCascadeChild,
      columns: [FkChainMiddleCascadeChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}

class FkChainMiddleCascadeChildDetachRowRepository {
  const FkChainMiddleCascadeChildDetachRowRepository._();

  /// Detaches the relation between this [FkChainMiddleCascadeChild] and the [FkChainRestrictBlocker] set in `restrictBlocker`
  /// by setting the [FkChainMiddleCascadeChild]'s foreign key `restrictBlockerId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> restrictBlocker(
    _isd.DatabaseSession session,
    FkChainMiddleCascadeChild fkChainMiddleCascadeChild, {
    _isd.Transaction? transaction,
  }) async {
    if (fkChainMiddleCascadeChild.id == null) {
      throw ArgumentError.notNull('fkChainMiddleCascadeChild.id');
    }

    var $fkChainMiddleCascadeChild = fkChainMiddleCascadeChild.copyWith(
      restrictBlockerId: null,
    );
    await session.db.updateRow<FkChainMiddleCascadeChild>(
      $fkChainMiddleCascadeChild,
      columns: [FkChainMiddleCascadeChild.t.restrictBlockerId],
      transaction: transaction,
    );
  }
}
