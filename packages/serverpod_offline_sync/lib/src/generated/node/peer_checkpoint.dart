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
import 'dart:async' as _ida;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A committed prefix of one immediate peer's local delivery revision.
abstract class OfflineSyncPeerCheckpoint
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncPeerCheckpoint._({
    this.id,
    required this.spaceId,
    this.space,
    required this.peerId,
    this.peer,
    required this.revision,
  });

  factory OfflineSyncPeerCheckpoint({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required int peerId,
    _icw2tu00.OfflineSyncPeer? peer,
    required int revision,
  }) = _OfflineSyncPeerCheckpointImpl;

  factory OfflineSyncPeerCheckpoint.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncPeerCheckpoint(
      id: jsonSerialization['id'] as int?,
      spaceId: jsonSerialization['spaceId'] as int,
      space: jsonSerialization['space'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.OfflineSyncSpace>(
              jsonSerialization['space'],
            ),
      peerId: jsonSerialization['peerId'] as int,
      peer: jsonSerialization['peer'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.OfflineSyncPeer>(
              jsonSerialization['peer'],
            ),
      revision: jsonSerialization['revision'] as int,
    );
  }

  static final t = OfflineSyncPeerCheckpointTable();

  static const db = OfflineSyncPeerCheckpointRepository._();

  @override
  int? id;

  int spaceId;

  _icw2tu00.OfflineSyncSpace? space;

  int peerId;

  _icw2tu00.OfflineSyncPeer? peer;

  int revision;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncPeerCheckpoint]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncPeerCheckpoint copyWith({
    int? id,
    int? spaceId,
    _icw2tu00.OfflineSyncSpace? space =
        const _UndefinedOfflineSyncPeerCheckpoint$space(),
    int? peerId,
    _icw2tu00.OfflineSyncPeer? peer =
        const _UndefinedOfflineSyncPeerCheckpoint$peer(),
    int? revision,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncPeerCheckpoint',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJson(),
      'peerId': peerId,
      if (peer != null) 'peer': peer?.toJson(),
      'revision': revision,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncPeerCheckpoint',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJsonForProtocol(),
      'peerId': peerId,
      if (peer != null) 'peer': peer?.toJsonForProtocol(),
      'revision': revision,
    };
  }

  static OfflineSyncPeerCheckpointInclude include({
    _icw2tu00.OfflineSyncSpaceInclude? space,
    _icw2tu00.OfflineSyncPeerInclude? peer,
  }) {
    return OfflineSyncPeerCheckpointInclude._(
      space: space,
      peer: peer,
    );
  }

  static OfflineSyncPeerCheckpointIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    OfflineSyncPeerCheckpointInclude? include,
  }) {
    return OfflineSyncPeerCheckpointIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedOfflineSyncPeerCheckpoint$space extends _iss.UndefinedSentinel
    implements _icw2tu00.OfflineSyncSpace {
  const _UndefinedOfflineSyncPeerCheckpoint$space();
}

class _UndefinedOfflineSyncPeerCheckpoint$peer extends _iss.UndefinedSentinel
    implements _icw2tu00.OfflineSyncPeer {
  const _UndefinedOfflineSyncPeerCheckpoint$peer();
}

class _OfflineSyncPeerCheckpointImpl extends OfflineSyncPeerCheckpoint {
  _OfflineSyncPeerCheckpointImpl({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required int peerId,
    _icw2tu00.OfflineSyncPeer? peer,
    required int revision,
  }) : super._(
         id: id,
         spaceId: spaceId,
         space: space,
         peerId: peerId,
         peer: peer,
         revision: revision,
       );

  /// Returns a shallow copy of this [OfflineSyncPeerCheckpoint]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncPeerCheckpoint copyWith({
    Object? id = _Undefined,
    int? spaceId,
    _icw2tu00.OfflineSyncSpace? space =
        const _UndefinedOfflineSyncPeerCheckpoint$space(),
    int? peerId,
    _icw2tu00.OfflineSyncPeer? peer =
        const _UndefinedOfflineSyncPeerCheckpoint$peer(),
    int? revision,
  }) {
    return OfflineSyncPeerCheckpoint(
      id: id is int? ? id : this.id,
      spaceId: spaceId ?? this.spaceId,
      space: space is _iss.UndefinedSentinel ? this.space?.copyWith() : space,
      peerId: peerId ?? this.peerId,
      peer: peer is _iss.UndefinedSentinel ? this.peer?.copyWith() : peer,
      revision: revision ?? this.revision,
    );
  }
}

class OfflineSyncPeerCheckpointUpdateTable
    extends _isd.UpdateTable<OfflineSyncPeerCheckpointTable> {
  OfflineSyncPeerCheckpointUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<int, int> peerId(int value) => _isd.ColumnValue(
    table.peerId,
    value,
  );

  _isd.ColumnValue<int, int> revision(int value) => _isd.ColumnValue(
    table.revision,
    value,
  );
}

class OfflineSyncPeerCheckpointTable extends _isd.Table<int?> {
  OfflineSyncPeerCheckpointTable({super.tableRelation})
    : super(tableName: 'offline_sync_peer_checkpoints') {
    updateTable = OfflineSyncPeerCheckpointUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    peerId = _isd.ColumnInt(
      'peerId',
      this,
    );
    revision = _isd.ColumnInt(
      'revision',
      this,
    );
  }

  late final OfflineSyncPeerCheckpointUpdateTable updateTable;

  late final _isd.ColumnInt spaceId;

  _icw2tu00.OfflineSyncSpaceTable? _space;

  late final _isd.ColumnInt peerId;

  _icw2tu00.OfflineSyncPeerTable? _peer;

  late final _isd.ColumnInt revision;

  _icw2tu00.OfflineSyncSpaceTable get space {
    if (_space != null) return _space!;
    _space = _isd.createRelationTable(
      relationFieldName: 'space',
      field: OfflineSyncPeerCheckpoint.t.spaceId,
      foreignField: _icw2tu00.OfflineSyncSpace.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncSpaceTable(tableRelation: foreignTableRelation),
    );
    return _space!;
  }

  _icw2tu00.OfflineSyncPeerTable get peer {
    if (_peer != null) return _peer!;
    _peer = _isd.createRelationTable(
      relationFieldName: 'peer',
      field: OfflineSyncPeerCheckpoint.t.peerId,
      foreignField: _icw2tu00.OfflineSyncPeer.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncPeerTable(tableRelation: foreignTableRelation),
    );
    return _peer!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    peerId,
    revision,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'space') {
      return space;
    }
    if (relationField == 'peer') {
      return peer;
    }
    return null;
  }
}

class OfflineSyncPeerCheckpointInclude extends _isd.IncludeObject {
  OfflineSyncPeerCheckpointInclude._({
    _icw2tu00.OfflineSyncSpaceInclude? space,
    _icw2tu00.OfflineSyncPeerInclude? peer,
  }) {
    _space = space;
    _peer = peer;
  }

  _icw2tu00.OfflineSyncSpaceInclude? _space;

  _icw2tu00.OfflineSyncPeerInclude? _peer;

  @override
  Map<String, _isd.Include?> get includes => {
    'space': _space,
    'peer': _peer,
  };

  @override
  _isd.Table<int?> get table => OfflineSyncPeerCheckpoint.t;
}

class OfflineSyncPeerCheckpointIncludeList extends _isd.IncludeList {
  OfflineSyncPeerCheckpointIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncPeerCheckpoint.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncPeerCheckpoint.t;
}

class OfflineSyncPeerCheckpointRepository {
  const OfflineSyncPeerCheckpointRepository._();

  final attachRow = const OfflineSyncPeerCheckpointAttachRowRepository._();

  /// Returns a list of [OfflineSyncPeerCheckpoint]s matching the given query parameters.
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
  Future<List<OfflineSyncPeerCheckpoint>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncPeerCheckpointInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncPeerCheckpoint>(
      where: where?.call(OfflineSyncPeerCheckpoint.t),
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [OfflineSyncPeerCheckpoint]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `OfflineSyncPeerCheckpoint.t`.
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
  _ida.Stream<List<OfflineSyncPeerCheckpoint>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    OfflineSyncPeerCheckpointInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<OfflineSyncPeerCheckpoint>(
      where: where?.call(OfflineSyncPeerCheckpoint.t),
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [OfflineSyncPeerCheckpoint] matching the given query parameters.
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
  Future<OfflineSyncPeerCheckpoint?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncPeerCheckpointInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncPeerCheckpoint>(
      where: where?.call(OfflineSyncPeerCheckpoint.t),
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncPeerCheckpoint] by its [id] or null if no such row exists.
  Future<OfflineSyncPeerCheckpoint?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    OfflineSyncPeerCheckpointInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncPeerCheckpoint>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncPeerCheckpoint]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncPeerCheckpoint]s will have their `id` fields set.
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
  Future<List<OfflineSyncPeerCheckpoint>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncPeerCheckpoint> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncPeerCheckpoint>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncPeerCheckpoint] and returns the inserted row.
  ///
  /// The returned [OfflineSyncPeerCheckpoint] will have its `id` field set.
  Future<OfflineSyncPeerCheckpoint> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncPeerCheckpoint>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncPeerCheckpoint]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncPeerCheckpoint]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeerCheckpoint>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncPeerCheckpoint> rows, {
    required _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>
    conflictColumns,
    _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncPeerCheckpoint>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncPeerCheckpoint.t),
      updateColumns: updateColumns?.call(OfflineSyncPeerCheckpoint.t),
      updateWhere: updateWhere?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncPeerCheckpoint] and returns the resulting row.
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
  /// The returned [OfflineSyncPeerCheckpoint] will have its `id` field set.
  Future<OfflineSyncPeerCheckpoint?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint row, {
    required _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>
    conflictColumns,
    _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncPeerCheckpoint>(
      row,
      conflictColumns: conflictColumns(OfflineSyncPeerCheckpoint.t),
      updateColumns: updateColumns?.call(OfflineSyncPeerCheckpoint.t),
      updateWhere: updateWhere?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncPeerCheckpoint]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeerCheckpoint>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncPeerCheckpoint> rows, {
    _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncPeerCheckpoint>(
      rows,
      columns: columns?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncPeerCheckpoint]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncPeerCheckpoint> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint row, {
    _isd.ColumnSelections<OfflineSyncPeerCheckpointTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncPeerCheckpoint>(
      row,
      columns: columns?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncPeerCheckpoint] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncPeerCheckpoint?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<OfflineSyncPeerCheckpointUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncPeerCheckpoint>(
      id,
      columnValues: columnValues(OfflineSyncPeerCheckpoint.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncPeerCheckpoint]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncPeerCheckpoint>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<OfflineSyncPeerCheckpointUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncPeerCheckpoint>(
      columnValues: columnValues(OfflineSyncPeerCheckpoint.t.updateTable),
      where: where(OfflineSyncPeerCheckpoint.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncPeerCheckpoint]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncPeerCheckpoint>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncPeerCheckpoint> rows, {
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncPeerCheckpoint>(
      rows,
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncPeerCheckpoint].
  Future<OfflineSyncPeerCheckpoint> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncPeerCheckpoint>(
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
  Future<List<OfflineSyncPeerCheckpoint>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable> where,
    _isd.OrderByBuilder<OfflineSyncPeerCheckpointTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncPeerCheckpointTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncPeerCheckpoint>(
      where: where(OfflineSyncPeerCheckpoint.t),
      orderBy: orderBy?.call(OfflineSyncPeerCheckpoint.t),
      orderByList: orderByList?.call(OfflineSyncPeerCheckpoint.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncPeerCheckpoint>(
      where: where?.call(OfflineSyncPeerCheckpoint.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncPeerCheckpoint] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncPeerCheckpointTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncPeerCheckpoint>(
      where: where(OfflineSyncPeerCheckpoint.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class OfflineSyncPeerCheckpointAttachRowRepository {
  const OfflineSyncPeerCheckpointAttachRowRepository._();

  /// Creates a relation between the given [OfflineSyncPeerCheckpoint] and [OfflineSyncSpace]
  /// by setting the [OfflineSyncPeerCheckpoint]'s foreign key `spaceId` to refer to the [OfflineSyncSpace].
  Future<void> space(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint offlineSyncPeerCheckpoint,
    _icw2tu00.OfflineSyncSpace space, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncPeerCheckpoint.id == null) {
      throw ArgumentError.notNull('offlineSyncPeerCheckpoint.id');
    }
    if (space.id == null) {
      throw ArgumentError.notNull('space.id');
    }

    var $offlineSyncPeerCheckpoint = offlineSyncPeerCheckpoint.copyWith(
      spaceId: space.id,
    );
    await session.db.updateRow<OfflineSyncPeerCheckpoint>(
      $offlineSyncPeerCheckpoint,
      columns: [OfflineSyncPeerCheckpoint.t.spaceId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [OfflineSyncPeerCheckpoint] and [OfflineSyncPeer]
  /// by setting the [OfflineSyncPeerCheckpoint]'s foreign key `peerId` to refer to the [OfflineSyncPeer].
  Future<void> peer(
    _isd.DatabaseSession session,
    OfflineSyncPeerCheckpoint offlineSyncPeerCheckpoint,
    _icw2tu00.OfflineSyncPeer peer, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncPeerCheckpoint.id == null) {
      throw ArgumentError.notNull('offlineSyncPeerCheckpoint.id');
    }
    if (peer.id == null) {
      throw ArgumentError.notNull('peer.id');
    }

    var $offlineSyncPeerCheckpoint = offlineSyncPeerCheckpoint.copyWith(
      peerId: peer.id,
    );
    await session.db.updateRow<OfflineSyncPeerCheckpoint>(
      $offlineSyncPeerCheckpoint,
      columns: [OfflineSyncPeerCheckpoint.t.peerId],
      transaction: transaction,
    );
  }
}
