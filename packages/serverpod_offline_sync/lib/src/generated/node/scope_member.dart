/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, no_leading_underscores_for_library_prefixes
// ignore_for_file: unnecessary_null_comparison

import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Authorization membership for shared CRDT scopes.
///
/// `database: all`, so the table exists on every node and membership resolves
/// with the same code on both ends. The server is the authoritative writer; a
/// client copy (once populated) is a read-only cache for UI and offline role
/// checks.
///
/// Personal-scope membership is implicit: a user always belongs to the scope
/// whose UUID equals their auth user UUID. Rows in this table represent shared
/// scopes only.
abstract class CrdtScopeMember
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  CrdtScopeMember._({
    this.id,
    required this.scopeId,
    this.scope,
    required this.userUuid,
    required this.role,
  });

  factory CrdtScopeMember({
    int? id,
    required int scopeId,
    _icw2tu00.CrdtScope? scope,
    required _iss.UuidValue userUuid,
    required _icw2tu00.CrdtScopeRole role,
  }) = _CrdtScopeMemberImpl;

  factory CrdtScopeMember.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtScopeMember(
      id: jsonSerialization['id'] as int?,
      scopeId: jsonSerialization['scopeId'] as int,
      scope: jsonSerialization['scope'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtScope>(
              jsonSerialization['scope'],
            ),
      userUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['userUuid'],
      ),
      role: _icw2tu00.CrdtScopeRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  static final t = CrdtScopeMemberTable();

  static const db = CrdtScopeMemberRepository._();

  @override
  int? id;

  int scopeId;

  /// Shared scope this membership grants access to.
  _icw2tu00.CrdtScope? scope;

  /// Auth user UUID that may access the scope.
  _iss.UuidValue userUuid;

  /// CRDT access role for this shared-scope membership.
  _icw2tu00.CrdtScopeRole role;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtScopeMember]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtScopeMember copyWith({
    int? id,
    int? scopeId,
    _icw2tu00.CrdtScope? scope,
    _iss.UuidValue? userUuid,
    _icw2tu00.CrdtScopeRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeMember',
      if (id != null) 'id': id,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJson(),
      'userUuid': userUuid.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeMember',
      if (id != null) 'id': id,
      'scopeId': scopeId,
      if (scope != null) 'scope': scope?.toJsonForProtocol(),
      'userUuid': userUuid.toJson(),
      'role': role.toJson(),
    };
  }

  static CrdtScopeMemberInclude include({_icw2tu00.CrdtScopeInclude? scope}) {
    return CrdtScopeMemberInclude._(scope: scope);
  }

  static CrdtScopeMemberIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    CrdtScopeMemberInclude? include,
  }) {
    return CrdtScopeMemberIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtScopeMemberImpl extends CrdtScopeMember {
  _CrdtScopeMemberImpl({
    int? id,
    required int scopeId,
    _icw2tu00.CrdtScope? scope,
    required _iss.UuidValue userUuid,
    required _icw2tu00.CrdtScopeRole role,
  }) : super._(
         id: id,
         scopeId: scopeId,
         scope: scope,
         userUuid: userUuid,
         role: role,
       );

  /// Returns a shallow copy of this [CrdtScopeMember]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtScopeMember copyWith({
    Object? id = _Undefined,
    int? scopeId,
    Object? scope = _Undefined,
    _iss.UuidValue? userUuid,
    _icw2tu00.CrdtScopeRole? role,
  }) {
    return CrdtScopeMember(
      id: id is int? ? id : this.id,
      scopeId: scopeId ?? this.scopeId,
      scope: scope is _icw2tu00.CrdtScope? ? scope : this.scope?.copyWith(),
      userUuid: userUuid ?? this.userUuid,
      role: role ?? this.role,
    );
  }
}

class CrdtScopeMemberUpdateTable
    extends _isd.UpdateTable<CrdtScopeMemberTable> {
  CrdtScopeMemberUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> userUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.userUuid,
    value,
  );

  _isd.ColumnValue<_icw2tu00.CrdtScopeRole, _icw2tu00.CrdtScopeRole> role(
    _icw2tu00.CrdtScopeRole value,
  ) => _isd.ColumnValue(
    table.role,
    value,
  );
}

class CrdtScopeMemberTable extends _isd.Table<int?> {
  CrdtScopeMemberTable({super.tableRelation})
    : super(tableName: 'crdt_scope_members') {
    updateTable = CrdtScopeMemberUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
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

  late final CrdtScopeMemberUpdateTable updateTable;

  late final _isd.ColumnInt scopeId;

  /// Shared scope this membership grants access to.
  _icw2tu00.CrdtScopeTable? _scope;

  /// Auth user UUID that may access the scope.
  late final _isd.ColumnUuid userUuid;

  /// CRDT access role for this shared-scope membership.
  late final _isd.ColumnEnum<_icw2tu00.CrdtScopeRole> role;

  _icw2tu00.CrdtScopeTable get scope {
    if (_scope != null) return _scope!;
    _scope = _isd.createRelationTable(
      relationFieldName: 'scope',
      field: CrdtScopeMember.t.scopeId,
      foreignField: _icw2tu00.CrdtScope.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtScopeTable(tableRelation: foreignTableRelation),
    );
    return _scope!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    userUuid,
    role,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'scope') {
      return scope;
    }
    return null;
  }
}

class CrdtScopeMemberInclude extends _isd.IncludeObject {
  CrdtScopeMemberInclude._({_icw2tu00.CrdtScopeInclude? scope}) {
    _scope = scope;
  }

  _icw2tu00.CrdtScopeInclude? _scope;

  @override
  Map<String, _isd.Include?> get includes => {'scope': _scope};

  @override
  _isd.Table<int?> get table => CrdtScopeMember.t;
}

class CrdtScopeMemberIncludeList extends _isd.IncludeList {
  CrdtScopeMemberIncludeList._({
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtScopeMember.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtScopeMember.t;
}

class CrdtScopeMemberRepository {
  const CrdtScopeMemberRepository._();

  final attachRow = const CrdtScopeMemberAttachRowRepository._();

  /// Returns a list of [CrdtScopeMember]s matching the given query parameters.
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
  Future<List<CrdtScopeMember>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtScopeMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtScopeMember>(
      where: where?.call(CrdtScopeMember.t),
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtScopeMember] matching the given query parameters.
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
  Future<CrdtScopeMember?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtScopeMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtScopeMember>(
      where: where?.call(CrdtScopeMember.t),
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtScopeMember] by its [id] or null if no such row exists.
  Future<CrdtScopeMember?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtScopeMemberInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtScopeMember>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtScopeMember]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtScopeMember]s will have their `id` fields set.
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
  Future<List<CrdtScopeMember>> insert(
    _isd.DatabaseSession session,
    List<CrdtScopeMember> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtScopeMember>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtScopeMember] and returns the inserted row.
  ///
  /// The returned [CrdtScopeMember] will have its `id` field set.
  Future<CrdtScopeMember> insertRow(
    _isd.DatabaseSession session,
    CrdtScopeMember row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtScopeMember>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtScopeMember]s in the list and returns the resulting rows.
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
  /// The returned [CrdtScopeMember]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeMember>> upsert(
    _isd.DatabaseSession session,
    List<CrdtScopeMember> rows, {
    required _isd.ColumnSelections<CrdtScopeMemberTable> conflictColumns,
    _isd.ColumnSelections<CrdtScopeMemberTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtScopeMember>(
      rows,
      conflictColumns: conflictColumns(CrdtScopeMember.t),
      updateColumns: updateColumns?.call(CrdtScopeMember.t),
      updateWhere: updateWhere?.call(CrdtScopeMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtScopeMember] and returns the resulting row.
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
  /// The returned [CrdtScopeMember] will have its `id` field set.
  Future<CrdtScopeMember?> upsertRow(
    _isd.DatabaseSession session,
    CrdtScopeMember row, {
    required _isd.ColumnSelections<CrdtScopeMemberTable> conflictColumns,
    _isd.ColumnSelections<CrdtScopeMemberTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtScopeMember>(
      row,
      conflictColumns: conflictColumns(CrdtScopeMember.t),
      updateColumns: updateColumns?.call(CrdtScopeMember.t),
      updateWhere: updateWhere?.call(CrdtScopeMember.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScopeMember]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeMember>> update(
    _isd.DatabaseSession session,
    List<CrdtScopeMember> rows, {
    _isd.ColumnSelections<CrdtScopeMemberTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtScopeMember>(
      rows,
      columns: columns?.call(CrdtScopeMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtScopeMember]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtScopeMember> updateRow(
    _isd.DatabaseSession session,
    CrdtScopeMember row, {
    _isd.ColumnSelections<CrdtScopeMemberTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtScopeMember>(
      row,
      columns: columns?.call(CrdtScopeMember.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtScopeMember] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtScopeMember?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtScopeMemberUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtScopeMember>(
      id,
      columnValues: columnValues(CrdtScopeMember.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtScopeMember]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtScopeMember>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtScopeMemberUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<CrdtScopeMemberTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtScopeMember>(
      columnValues: columnValues(CrdtScopeMember.t.updateTable),
      where: where(CrdtScopeMember.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtScopeMember]s in the list and returns the deleted rows.
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
  Future<List<CrdtScopeMember>> delete(
    _isd.DatabaseSession session,
    List<CrdtScopeMember> rows, {
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtScopeMember>(
      rows,
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtScopeMember].
  Future<CrdtScopeMember> deleteRow(
    _isd.DatabaseSession session,
    CrdtScopeMember row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtScopeMember>(
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
  Future<List<CrdtScopeMember>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtScopeMemberTable> where,
    _isd.OrderByBuilder<CrdtScopeMemberTable>? orderBy,
    _isd.OrderByListBuilder<CrdtScopeMemberTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtScopeMember>(
      where: where(CrdtScopeMember.t),
      orderBy: orderBy?.call(CrdtScopeMember.t),
      orderByList: orderByList?.call(CrdtScopeMember.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtScopeMemberTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtScopeMember>(
      where: where?.call(CrdtScopeMember.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtScopeMember] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtScopeMemberTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtScopeMember>(
      where: where(CrdtScopeMember.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtScopeMemberAttachRowRepository {
  const CrdtScopeMemberAttachRowRepository._();

  /// Creates a relation between the given [CrdtScopeMember] and [CrdtScope]
  /// by setting the [CrdtScopeMember]'s foreign key `scopeId` to refer to the [CrdtScope].
  Future<void> scope(
    _isd.DatabaseSession session,
    CrdtScopeMember crdtScopeMember,
    _icw2tu00.CrdtScope scope, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtScopeMember.id == null) {
      throw ArgumentError.notNull('crdtScopeMember.id');
    }
    if (scope.id == null) {
      throw ArgumentError.notNull('scope.id');
    }

    var $crdtScopeMember = crdtScopeMember.copyWith(scopeId: scope.id);
    await session.db.updateRow<CrdtScopeMember>(
      $crdtScopeMember,
      columns: [CrdtScopeMember.t.scopeId],
      transaction: transaction,
    );
  }
}
