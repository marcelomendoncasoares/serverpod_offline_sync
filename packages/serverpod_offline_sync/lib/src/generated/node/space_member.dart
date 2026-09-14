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
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Authorization membership for shared CRDT spaces.
///
/// `database: all`, so the table exists on every node and membership resolves
/// with the same code on both ends. The server is the authoritative writer; a
/// client copy (once populated) is a read-only cache for UI and offline role
/// checks.
///
/// Personal-space membership is implicit: a user always belongs to the space
/// whose UUID equals their auth user UUID. Rows in this table represent shared
/// spaces only.
abstract class OfflineSyncSpaceMember
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  OfflineSyncSpaceMember._({
    this.id,
    required this.spaceId,
    this.space,
    required this.userUuid,
    required this.role,
  });

  factory OfflineSyncSpaceMember({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required _iss.UuidValue userUuid,
    required _icw2tu00.OfflineSyncSpaceRole role,
  }) = _OfflineSyncSpaceMemberImpl;

  factory OfflineSyncSpaceMember.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncSpaceMember(
      id: jsonSerialization['id'] as int?,
      spaceId: jsonSerialization['spaceId'] as int,
      space: jsonSerialization['space'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.OfflineSyncSpace>(
              jsonSerialization['space'],
            ),
      userUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['userUuid'],
      ),
      role: _icw2tu00.OfflineSyncSpaceRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  static final t = OfflineSyncSpaceMemberTable();

  static const db = OfflineSyncSpaceMemberRepository._();

  @override
  int? id;

  int spaceId;

  /// Shared space this membership grants access to.
  _icw2tu00.OfflineSyncSpace? space;

  /// Auth user UUID that may access the space.
  _iss.UuidValue userUuid;

  /// CRDT access role for this shared-space membership.
  _icw2tu00.OfflineSyncSpaceRole role;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [OfflineSyncSpaceMember]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncSpaceMember copyWith({
    int? id,
    int? spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    _iss.UuidValue? userUuid,
    _icw2tu00.OfflineSyncSpaceRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceMember',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJson(),
      'userUuid': userUuid.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceMember',
      if (id != null) 'id': id,
      'spaceId': spaceId,
      if (space != null) 'space': space?.toJsonForProtocol(),
      'userUuid': userUuid.toJson(),
      'role': role.toJson(),
    };
  }

  static OfflineSyncSpaceMemberInclude include({
    _icw2tu00.OfflineSyncSpaceInclude? space,
  }) {
    return OfflineSyncSpaceMemberInclude._(space: space);
  }

  static OfflineSyncSpaceMemberIncludeList includeList({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    OfflineSyncSpaceMemberInclude? include,
  }) {
    return OfflineSyncSpaceMemberIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _OfflineSyncSpaceMemberImpl extends OfflineSyncSpaceMember {
  _OfflineSyncSpaceMemberImpl({
    int? id,
    required int spaceId,
    _icw2tu00.OfflineSyncSpace? space,
    required _iss.UuidValue userUuid,
    required _icw2tu00.OfflineSyncSpaceRole role,
  }) : super._(
         id: id,
         spaceId: spaceId,
         space: space,
         userUuid: userUuid,
         role: role,
       );

  /// Returns a shallow copy of this [OfflineSyncSpaceMember]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpaceMember copyWith({
    Object? id = _Undefined,
    int? spaceId,
    Object? space = _Undefined,
    _iss.UuidValue? userUuid,
    _icw2tu00.OfflineSyncSpaceRole? role,
  }) {
    return OfflineSyncSpaceMember(
      id: id is int? ? id : this.id,
      spaceId: spaceId ?? this.spaceId,
      space: space is _icw2tu00.OfflineSyncSpace?
          ? space
          : this.space?.copyWith(),
      userUuid: userUuid ?? this.userUuid,
      role: role ?? this.role,
    );
  }
}

class OfflineSyncSpaceMemberUpdateTable
    extends _isd.UpdateTable<OfflineSyncSpaceMemberTable> {
  OfflineSyncSpaceMemberUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> userUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.userUuid,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.OfflineSyncSpaceRole,
    _icw2tu00.OfflineSyncSpaceRole
  >
  role(_icw2tu00.OfflineSyncSpaceRole value) => _isd.ColumnValue(
    table.role,
    value,
  );
}

class OfflineSyncSpaceMemberTable extends _isd.Table<int?> {
  OfflineSyncSpaceMemberTable({super.tableRelation})
    : super(tableName: 'offline_sync_space_members') {
    updateTable = OfflineSyncSpaceMemberUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    userUuid = _isd.ColumnUuid(
      'userUuid',
      this,
    );
    role = _isd.ColumnEnum(
      'role',
      this,
      _isd.EnumSerialization.byName,
    );
  }

  late final OfflineSyncSpaceMemberUpdateTable updateTable;

  late final _isd.ColumnInt spaceId;

  /// Shared space this membership grants access to.
  _icw2tu00.OfflineSyncSpaceTable? _space;

  /// Auth user UUID that may access the space.
  late final _isd.ColumnUuid userUuid;

  /// CRDT access role for this shared-space membership.
  late final _isd.ColumnEnum<_icw2tu00.OfflineSyncSpaceRole> role;

  _icw2tu00.OfflineSyncSpaceTable get space {
    if (_space != null) return _space!;
    _space = _isd.createRelationTable(
      relationFieldName: 'space',
      field: OfflineSyncSpaceMember.t.spaceId,
      foreignField: _icw2tu00.OfflineSyncSpace.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.OfflineSyncSpaceTable(tableRelation: foreignTableRelation),
    );
    return _space!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    userUuid,
    role,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'space') {
      return space;
    }
    return null;
  }
}

class OfflineSyncSpaceMemberInclude extends _isd.IncludeObject {
  OfflineSyncSpaceMemberInclude._({_icw2tu00.OfflineSyncSpaceInclude? space}) {
    _space = space;
  }

  _icw2tu00.OfflineSyncSpaceInclude? _space;

  @override
  Map<String, _isd.Include?> get includes => {'space': _space};

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceMember.t;
}

class OfflineSyncSpaceMemberIncludeList extends _isd.IncludeList {
  OfflineSyncSpaceMemberIncludeList._({
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(OfflineSyncSpaceMember.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => OfflineSyncSpaceMember.t;
}

class OfflineSyncSpaceMemberRepository {
  const OfflineSyncSpaceMemberRepository._();

  final attachRow = const OfflineSyncSpaceMemberAttachRowRepository._();

  /// Returns a list of [OfflineSyncSpaceMember]s matching the given query parameters.
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
  Future<List<OfflineSyncSpaceMember>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<OfflineSyncSpaceMember>(
      where: where?.call(OfflineSyncSpaceMember.t),
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [OfflineSyncSpaceMember] matching the given query parameters.
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
  Future<OfflineSyncSpaceMember?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? where,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    _isd.Transaction? transaction,
    OfflineSyncSpaceMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<OfflineSyncSpaceMember>(
      where: where?.call(OfflineSyncSpaceMember.t),
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [OfflineSyncSpaceMember] by its [id] or null if no such row exists.
  Future<OfflineSyncSpaceMember?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    OfflineSyncSpaceMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<OfflineSyncSpaceMember>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [OfflineSyncSpaceMember]s in the list and returns the inserted rows.
  ///
  /// The returned [OfflineSyncSpaceMember]s will have their `id` fields set.
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
  Future<List<OfflineSyncSpaceMember>> insert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceMember> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<OfflineSyncSpaceMember>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [OfflineSyncSpaceMember] and returns the inserted row.
  ///
  /// The returned [OfflineSyncSpaceMember] will have its `id` field set.
  Future<OfflineSyncSpaceMember> insertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceMember row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<OfflineSyncSpaceMember>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [OfflineSyncSpaceMember]s in the list and returns the resulting rows.
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
  /// The returned [OfflineSyncSpaceMember]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceMember>> upsert(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceMember> rows, {
    required _isd.ColumnSelections<OfflineSyncSpaceMemberTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceMemberTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<OfflineSyncSpaceMember>(
      rows,
      conflictColumns: conflictColumns(OfflineSyncSpaceMember.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceMember.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [OfflineSyncSpaceMember] and returns the resulting row.
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
  /// The returned [OfflineSyncSpaceMember] will have its `id` field set.
  Future<OfflineSyncSpaceMember?> upsertRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceMember row, {
    required _isd.ColumnSelections<OfflineSyncSpaceMemberTable> conflictColumns,
    _isd.ColumnSelections<OfflineSyncSpaceMemberTable>? updateColumns,
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<OfflineSyncSpaceMember>(
      row,
      conflictColumns: conflictColumns(OfflineSyncSpaceMember.t),
      updateColumns: updateColumns?.call(OfflineSyncSpaceMember.t),
      updateWhere: updateWhere?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceMember]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceMember>> update(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceMember> rows, {
    _isd.ColumnSelections<OfflineSyncSpaceMemberTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<OfflineSyncSpaceMember>(
      rows,
      columns: columns?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [OfflineSyncSpaceMember]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<OfflineSyncSpaceMember> updateRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceMember row, {
    _isd.ColumnSelections<OfflineSyncSpaceMemberTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<OfflineSyncSpaceMember>(
      row,
      columns: columns?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
    );
  }

  /// Updates a single [OfflineSyncSpaceMember] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<OfflineSyncSpaceMember?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceMemberUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<OfflineSyncSpaceMember>(
      id,
      columnValues: columnValues(OfflineSyncSpaceMember.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [OfflineSyncSpaceMember]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<OfflineSyncSpaceMember>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<OfflineSyncSpaceMemberUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<OfflineSyncSpaceMember>(
      columnValues: columnValues(OfflineSyncSpaceMember.t.updateTable),
      where: where(OfflineSyncSpaceMember.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [OfflineSyncSpaceMember]s in the list and returns the deleted rows.
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
  Future<List<OfflineSyncSpaceMember>> delete(
    _isd.DatabaseSession session,
    List<OfflineSyncSpaceMember> rows, {
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<OfflineSyncSpaceMember>(
      rows,
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [OfflineSyncSpaceMember].
  Future<OfflineSyncSpaceMember> deleteRow(
    _isd.DatabaseSession session,
    OfflineSyncSpaceMember row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<OfflineSyncSpaceMember>(
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
  Future<List<OfflineSyncSpaceMember>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable> where,
    _isd.OrderByBuilder<OfflineSyncSpaceMemberTable>? orderBy,
    _isd.OrderByListBuilder<OfflineSyncSpaceMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<OfflineSyncSpaceMember>(
      where: where(OfflineSyncSpaceMember.t),
      orderBy: orderBy?.call(OfflineSyncSpaceMember.t),
      orderByList: orderByList?.call(OfflineSyncSpaceMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<OfflineSyncSpaceMember>(
      where: where?.call(OfflineSyncSpaceMember.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [OfflineSyncSpaceMember] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<OfflineSyncSpaceMemberTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<OfflineSyncSpaceMember>(
      where: where(OfflineSyncSpaceMember.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class OfflineSyncSpaceMemberAttachRowRepository {
  const OfflineSyncSpaceMemberAttachRowRepository._();

  /// Creates a relation between the given [OfflineSyncSpaceMember] and [OfflineSyncSpace]
  /// by setting the [OfflineSyncSpaceMember]'s foreign key `spaceId` to refer to the [OfflineSyncSpace].
  Future<void> space(
    _isd.DatabaseSession session,
    OfflineSyncSpaceMember offlineSyncSpaceMember,
    _icw2tu00.OfflineSyncSpace space, {
    _isd.Transaction? transaction,
  }) async {
    if (offlineSyncSpaceMember.id == null) {
      throw ArgumentError.notNull('offlineSyncSpaceMember.id');
    }
    if (space.id == null) {
      throw ArgumentError.notNull('space.id');
    }

    var $offlineSyncSpaceMember = offlineSyncSpaceMember.copyWith(
      spaceId: space.id,
    );
    await session.db.updateRow<OfflineSyncSpaceMember>(
      $offlineSyncSpaceMember,
      columns: [OfflineSyncSpaceMember.t.spaceId],
      transaction: transaction,
    );
  }
}
