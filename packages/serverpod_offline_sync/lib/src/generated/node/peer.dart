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
import 'dart:async' as _ida;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A replica epoch scoped to the authenticated user of its connection.
abstract class OfflineSyncPeer
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncPeer._({
    this.id,
    required this.userUuid,
    required this.peerUuid,
  });

  factory OfflineSyncPeer({
    int? id,
    required _iss.UuidValue userUuid,
    required _iss.UuidValue peerUuid,
  }) = _OfflineSyncPeerImpl;

  factory OfflineSyncPeer.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncPeer(
      id: jsonSerialization['id'] as int?,
      userUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['userUuid'],
      ),
      peerUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['peerUuid'],
      ),
    );
  }

  static final t = OfflineSyncPeerTable();

  static const db = OfflineSyncPeerRepository._();

  @override
  int? id;

  _iss.UuidValue userUuid;

  _iss.UuidValue peerUuid;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncPeer]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncPeer copyWith({
    int? id,
    _iss.UuidValue? userUuid,
    _iss.UuidValue? peerUuid,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncPeer',
      if (id != null) 'id': id,
      'userUuid': userUuid.toJson(),
      'peerUuid': peerUuid.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncPeer',
      if (id != null) 'id': id,
      'userUuid': userUuid.toJson(),
      'peerUuid': peerUuid.toJson(),
    };
  }

  static OfflineSyncPeerInclude include() {
    return OfflineSyncPeerInclude._();
  }

  static OfflineSyncPeerIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    OfflineSyncPeerInclude? include,
  }) {
    return OfflineSyncPeerIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OfflineSyncPeerImpl extends OfflineSyncPeer {
  _OfflineSyncPeerImpl({
    int? id,
    required _iss.UuidValue userUuid,
    required _iss.UuidValue peerUuid,
  }) : super._(
         id: id,
         userUuid: userUuid,
         peerUuid: peerUuid,
       );

  /// Returns a shallow copy of this [OfflineSyncPeer]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncPeer copyWith({
    Object? id = _Undefined,
    _iss.UuidValue? userUuid,
    _iss.UuidValue? peerUuid,
  }) {
    return OfflineSyncPeer(
      id: id is int? ? id : this.id,
      userUuid: userUuid ?? this.userUuid,
      peerUuid: peerUuid ?? this.peerUuid,
    );
  }
}

class OfflineSyncPeerUpdateTable
    extends _isd.UpdateTable<OfflineSyncPeerTable> {
  OfflineSyncPeerUpdateTable(super.table);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> userUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.userUuid,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> peerUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.peerUuid,
    value,
  );
}

class OfflineSyncPeerTable extends _isd.Table<int?> {
  OfflineSyncPeerTable({super.tableRelation})
    : super(tableName: 'offline_sync_peers') {
    updateTable = OfflineSyncPeerUpdateTable(this);
    userUuid = _isd.ColumnUuid(
      'userUuid',
      this,
    );
    peerUuid = _isd.ColumnUuid(
      'peerUuid',
      this,
    );
  }

  late final OfflineSyncPeerUpdateTable updateTable;

  late final _isd.ColumnUuid userUuid;

  late final _isd.ColumnUuid peerUuid;

  @override
  List<_isd.Column> get columns => [
    id,
    userUuid,
    peerUuid,
  ];
}

class OfflineSyncPeerInclude extends _isd.IncludeObject {
  OfflineSyncPeerInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => OfflineSyncPeer.t;
}

class OfflineSyncPeerIncludeList extends _isd.IncludeList {
  OfflineSyncPeerIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncPeer.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncPeer.t;
}

class OfflineSyncPeerRepository {
  const OfflineSyncPeerRepository._();

  /// Returns a list of [OfflineSyncPeer]s matching the given query parameters.
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
  Future<List<OfflineSyncPeer>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncPeer>(
      where: where?.call(OfflineSyncPeer.t),
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [OfflineSyncPeer]s matching the given query parameters every time the
  /// source tables are modified.
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
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `OfflineSyncPeer.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<OfflineSyncPeer>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<OfflineSyncPeer>(
      where: where?.call(OfflineSyncPeer.t),
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [OfflineSyncPeer] matching the given query parameters.
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
  Future<OfflineSyncPeer?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncPeer>(
      where: where?.call(OfflineSyncPeer.t),
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncPeer] by its [id] or null if no such row exists.
  Future<OfflineSyncPeer?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncPeer>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncPeer]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncPeer]s will have their `id` fields set.
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
  Future<List<OfflineSyncPeer>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncPeer> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncPeer>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncPeer] and returns the inserted row.
  ///
  /// The returned [OfflineSyncPeer] will have its `id` field set.
  Future<OfflineSyncPeer> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncPeer row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncPeer>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncPeer]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncPeer]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeer>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncPeer> rows, {
    required _isd.ColumnSelections<OfflineSyncPeerTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncPeerTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncPeer>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncPeer.t),
      updateColumns: updateColumns?.call(OfflineSyncPeer.t),
      updateWhere: updateWhere?.call(OfflineSyncPeer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncPeer] and returns the resulting row.
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
  /// The returned [OfflineSyncPeer] will have its `id` field set.
  Future<OfflineSyncPeer?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncPeer row, {
    required _isd.ColumnSelections<OfflineSyncPeerTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncPeerTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncPeer>(
      row,
      conflictColumns: conflictColumns(OfflineSyncPeer.t),
      updateColumns: updateColumns?.call(OfflineSyncPeer.t),
      updateWhere: updateWhere?.call(OfflineSyncPeer.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncPeer]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeer>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncPeer> rows, {
    _isd.ColumnSelections<OfflineSyncPeerTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncPeer>(
      rows,
      columns: columns?.call(OfflineSyncPeer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncPeer]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncPeer> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncPeer row, {
    _isd.ColumnSelections<OfflineSyncPeerTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncPeer>(
      row,
      columns: columns?.call(OfflineSyncPeer.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncPeer] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncPeer?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<OfflineSyncPeerUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncPeer>(
      id,
      columnValues: columnValues(OfflineSyncPeer.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncPeer]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeer>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<OfflineSyncPeerUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncPeerTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncPeer>(
      columnValues: columnValues(OfflineSyncPeer.t.updateTable),
      where: where(OfflineSyncPeer.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncPeer]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncPeer>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncPeer> rows, {
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncPeer>(
      rows,
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncPeer].
  Future<OfflineSyncPeer> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncPeer row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncPeer>(
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
  Future<List<OfflineSyncPeer>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncPeerTable> where,
    _isd.OrderByBuilder<OfflineSyncPeerTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncPeer>(
      where: where(OfflineSyncPeer.t),
      orderBy: orderBy?.call(OfflineSyncPeer.t),
      orderByList: orderByList?.call(OfflineSyncPeer.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncPeer>(
      where: where?.call(OfflineSyncPeer.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncPeer] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncPeerTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncPeer>(
      where: where(OfflineSyncPeer.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
