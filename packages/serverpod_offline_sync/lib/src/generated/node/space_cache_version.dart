/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Coordinates space visibility caches across database sessions and processes.
/// Row 1 is shared-locked by readers and exclusively locked by space writers.
abstract class OfflineSyncSpaceCacheVersion
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncSpaceCacheVersion._({
    this.id,
    _iss.UuidValue? databaseUuid,
    int? revision,
  }) : databaseUuid = databaseUuid ?? const _iss.Uuid().v7obj(),
       revision = revision ?? 0;

  factory OfflineSyncSpaceCacheVersion({
    int? id,
    _iss.UuidValue? databaseUuid,
    int? revision,
  }) = _OfflineSyncSpaceCacheVersionImpl;

  factory OfflineSyncSpaceCacheVersion.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncSpaceCacheVersion(
      id: jsonSerialization['id'] as int?,
      databaseUuid: jsonSerialization['databaseUuid'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['databaseUuid'],
            ),
      revision: jsonSerialization['revision'] as int?,
    );
  }

  static final t = OfflineSyncSpaceCacheVersionTable();

  static const db = OfflineSyncSpaceCacheVersionRepository._();

  @override
  int? id;

  /// Separates caches even when a sync context wraps different databases.
  _iss.UuidValue databaseUuid;

  /// Changes whenever a space or membership mutation commits.
  int revision;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncSpaceCacheVersion]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncSpaceCacheVersion copyWith({
    int? id,
    _iss.UuidValue? databaseUuid,
    int? revision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceCacheVersion',
      if (id != null) 'id': id,
      'databaseUuid': databaseUuid.toJson(),
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceCacheVersion',
      if (id != null) 'id': id,
      'databaseUuid': databaseUuid.toJson(),
      'revision': revision,
    };
  }

  static OfflineSyncSpaceCacheVersionInclude include() {
    return OfflineSyncSpaceCacheVersionInclude._();
  }

  static OfflineSyncSpaceCacheVersionIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    OfflineSyncSpaceCacheVersionInclude? include,
  }) {
    return OfflineSyncSpaceCacheVersionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OfflineSyncSpaceCacheVersionImpl extends OfflineSyncSpaceCacheVersion {
  _OfflineSyncSpaceCacheVersionImpl({
    int? id,
    _iss.UuidValue? databaseUuid,
    int? revision,
  }) : super._(
         id: id,
         databaseUuid: databaseUuid,
         revision: revision,
       );

  /// Returns a shallow copy of this [OfflineSyncSpaceCacheVersion]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpaceCacheVersion copyWith({
    Object? id = _Undefined,
    _iss.UuidValue? databaseUuid,
    int? revision,
  }) {
    return OfflineSyncSpaceCacheVersion(
      id: id is int? ? id : this.id,
      databaseUuid: databaseUuid ?? this.databaseUuid,
      revision: revision ?? this.revision,
    );
  }
}

class OfflineSyncSpaceCacheVersionUpdateTable
    extends _isd.UpdateTable<OfflineSyncSpaceCacheVersionTable> {
  OfflineSyncSpaceCacheVersionUpdateTable(super.table);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> databaseUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.databaseUuid,
    value,
  );

  _isd.ColumnValue<int, int> revision(int value) => _isd.ColumnValue(
    table.revision,
    value,
  );
}

class OfflineSyncSpaceCacheVersionTable extends _isd.Table<int?> {
  OfflineSyncSpaceCacheVersionTable({super.tableRelation})
    : super(tableName: 'offline_sync_space_cache_versions') {
    updateTable = OfflineSyncSpaceCacheVersionUpdateTable(this);
    databaseUuid = _isd.ColumnUuid(
      'databaseUuid',
      this,
      hasDefault: true,
    );
    revision = _isd.ColumnInt(
      'revision',
      this,
      hasDefault: true,
    );
  }

  late final OfflineSyncSpaceCacheVersionUpdateTable updateTable;

  /// Separates caches even when a sync context wraps different databases.
  late final _isd.ColumnUuid databaseUuid;

  /// Changes whenever a space or membership mutation commits.
  late final _isd.ColumnInt revision;

  @override
  List<_isd.Column> get columns => [
    id,
    databaseUuid,
    revision,
  ];
}

class OfflineSyncSpaceCacheVersionInclude extends _isd.IncludeObject {
  OfflineSyncSpaceCacheVersionInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceCacheVersion.t;
}

class OfflineSyncSpaceCacheVersionIncludeList extends _isd.IncludeList {
  OfflineSyncSpaceCacheVersionIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncSpaceCacheVersion.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceCacheVersion.t;
}

class OfflineSyncSpaceCacheVersionRepository {
  const OfflineSyncSpaceCacheVersionRepository._();

  /// Returns a list of [OfflineSyncSpaceCacheVersion]s matching the given query parameters.
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
  Future<List<OfflineSyncSpaceCacheVersion>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncSpaceCacheVersion>(
      where: where?.call(OfflineSyncSpaceCacheVersion.t),
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OfflineSyncSpaceCacheVersion] matching the given query parameters.
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
  Future<OfflineSyncSpaceCacheVersion?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncSpaceCacheVersion>(
      where: where?.call(OfflineSyncSpaceCacheVersion.t),
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncSpaceCacheVersion] by its [id] or null if no such row exists.
  Future<OfflineSyncSpaceCacheVersion?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncSpaceCacheVersion>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncSpaceCacheVersion]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncSpaceCacheVersion]s will have their `id` fields set.
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
  Future<List<OfflineSyncSpaceCacheVersion>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceCacheVersion> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncSpaceCacheVersion>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncSpaceCacheVersion] and returns the inserted row.
  ///
  /// The returned [OfflineSyncSpaceCacheVersion] will have its `id` field set.
  Future<OfflineSyncSpaceCacheVersion> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceCacheVersion row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncSpaceCacheVersion>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncSpaceCacheVersion]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncSpaceCacheVersion]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceCacheVersion>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceCacheVersion> rows, {
    required _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>
    conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncSpaceCacheVersion>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncSpaceCacheVersion.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceCacheVersion.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncSpaceCacheVersion] and returns the resulting row.
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
  /// The returned [OfflineSyncSpaceCacheVersion] will have its `id` field set.
  Future<OfflineSyncSpaceCacheVersion?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceCacheVersion row, {
    required _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>
    conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncSpaceCacheVersion>(
      row,
      conflictColumns: conflictColumns(OfflineSyncSpaceCacheVersion.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceCacheVersion.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceCacheVersion]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceCacheVersion>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceCacheVersion> rows, {
    _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncSpaceCacheVersion>(
      rows,
      columns: columns?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncSpaceCacheVersion]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncSpaceCacheVersion> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceCacheVersion row, {
    _isd.ColumnSelections<OfflineSyncSpaceCacheVersionTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncSpaceCacheVersion>(
      row,
      columns: columns?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncSpaceCacheVersion] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncSpaceCacheVersion?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<
      OfflineSyncSpaceCacheVersionUpdateTable
    >
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncSpaceCacheVersion>(
      id,
      columnValues: columnValues(OfflineSyncSpaceCacheVersion.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceCacheVersion]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceCacheVersion>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<
      OfflineSyncSpaceCacheVersionUpdateTable
    >
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>
    where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncSpaceCacheVersion>(
      columnValues: columnValues(OfflineSyncSpaceCacheVersion.t.updateTable),
      where: where(OfflineSyncSpaceCacheVersion.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncSpaceCacheVersion]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncSpaceCacheVersion>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceCacheVersion> rows, {
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncSpaceCacheVersion>(
      rows,
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncSpaceCacheVersion].
  Future<OfflineSyncSpaceCacheVersion> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceCacheVersion row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncSpaceCacheVersion>(
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
  Future<List<OfflineSyncSpaceCacheVersion>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>
    where,
    _isd.OrderByBuilder<OfflineSyncSpaceCacheVersionTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceCacheVersionTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncSpaceCacheVersion>(
      where: where(OfflineSyncSpaceCacheVersion.t),
      orderBy: orderBy?.call(OfflineSyncSpaceCacheVersion.t),
      orderByList: orderByList?.call(OfflineSyncSpaceCacheVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncSpaceCacheVersion>(
      where: where?.call(OfflineSyncSpaceCacheVersion.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncSpaceCacheVersion] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceCacheVersionTable>
    where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncSpaceCacheVersion>(
      where: where(OfflineSyncSpaceCacheVersion.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
