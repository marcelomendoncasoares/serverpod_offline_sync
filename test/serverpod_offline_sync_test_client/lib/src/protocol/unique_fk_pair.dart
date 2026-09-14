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

abstract class UniqueFkPair
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  UniqueFkPair._({
    this.id,
    this.spaceId,
    required this.name,
    this.leftId,
    this.left,
    this.rightId,
    this.right,
  });

  factory UniqueFkPair({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    _isc.UuidValue? leftId,
    _iensfz4m.Person? left,
    _isc.UuidValue? rightId,
    _iensfz4m.Person? right,
  }) = _UniqueFkPairImpl;

  factory UniqueFkPair.fromJson(Map<String, dynamic> jsonSerialization) {
    return UniqueFkPair(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      name: jsonSerialization['name'] as String,
      leftId: jsonSerialization['leftId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['leftId']),
      left: jsonSerialization['left'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['left'],
            ),
      rightId: jsonSerialization['rightId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['rightId']),
      right: jsonSerialization['right'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iensfz4m.Person>(
              jsonSerialization['right'],
            ),
    );
  }

  static final t = UniqueFkPairTable();

  static const db = UniqueFkPairRepository._();

  @override
  _isc.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  String name;

  _isc.UuidValue? leftId;

  _iensfz4m.Person? left;

  _isc.UuidValue? rightId;

  _iensfz4m.Person? right;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [UniqueFkPair]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  UniqueFkPair copyWith({
    _isc.UuidValue? id,
    int? spaceId,
    String? name,
    _isc.UuidValue? leftId,
    _iensfz4m.Person? left,
    _isc.UuidValue? rightId,
    _iensfz4m.Person? right,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UniqueFkPair',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      if (leftId != null) 'leftId': leftId?.toJson(),
      if (left != null) 'left': left?.toJson(),
      if (rightId != null) 'rightId': rightId?.toJson(),
      if (right != null) 'right': right?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UniqueFkPair',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'name': name,
      if (leftId != null) 'leftId': leftId?.toJson(),
      if (left != null) 'left': left?.toJsonForProtocol(),
      if (rightId != null) 'rightId': rightId?.toJson(),
      if (right != null) 'right': right?.toJsonForProtocol(),
    };
  }

  static UniqueFkPairInclude include({
    _iensfz4m.PersonInclude? left,
    _iensfz4m.PersonInclude? right,
  }) {
    return UniqueFkPairInclude._(
      left: left,
      right: right,
    );
  }

  static UniqueFkPairIncludeList includeList({
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    UniqueFkPairInclude? include,
  }) {
    return UniqueFkPairIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UniqueFkPairImpl extends UniqueFkPair {
  _UniqueFkPairImpl({
    _isc.UuidValue? id,
    int? spaceId,
    required String name,
    _isc.UuidValue? leftId,
    _iensfz4m.Person? left,
    _isc.UuidValue? rightId,
    _iensfz4m.Person? right,
  }) : super._(
         id: id,
         spaceId: spaceId,
         name: name,
         leftId: leftId,
         left: left,
         rightId: rightId,
         right: right,
       );

  /// Returns a shallow copy of this [UniqueFkPair]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  UniqueFkPair copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    String? name,
    Object? leftId = _Undefined,
    Object? left = _Undefined,
    Object? rightId = _Undefined,
    Object? right = _Undefined,
  }) {
    return UniqueFkPair(
      id: id is _isc.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      name: name ?? this.name,
      leftId: leftId is _isc.UuidValue? ? leftId : this.leftId,
      left: left is _iensfz4m.Person? ? left : this.left?.copyWith(),
      rightId: rightId is _isc.UuidValue? ? rightId : this.rightId,
      right: right is _iensfz4m.Person? ? right : this.right?.copyWith(),
    );
  }
}

class UniqueFkPairUpdateTable extends _isd.UpdateTable<UniqueFkPairTable> {
  UniqueFkPairUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) => _isd.ColumnValue(
    table.spaceId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> leftId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.leftId,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> rightId(
    _isc.UuidValue? value,
  ) => _isd.ColumnValue(
    table.rightId,
    value,
  );
}

class UniqueFkPairTable extends _isd.Table<_isc.UuidValue?> {
  UniqueFkPairTable({super.tableRelation})
    : super(tableName: 'unique_fk_pair') {
    updateTable = UniqueFkPairUpdateTable(this);
    spaceId = _isd.ColumnInt(
      'spaceId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    leftId = _isd.ColumnUuid(
      'leftId',
      this,
    );
    rightId = _isd.ColumnUuid(
      'rightId',
      this,
    );
  }

  late final UniqueFkPairUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnString name;

  late final _isd.ColumnUuid leftId;

  _iensfz4m.PersonTable? _left;

  late final _isd.ColumnUuid rightId;

  _iensfz4m.PersonTable? _right;

  _iensfz4m.PersonTable get left {
    if (_left != null) return _left!;
    _left = _isd.createRelationTable(
      relationFieldName: 'left',
      field: UniqueFkPair.t.leftId,
      foreignField: _iensfz4m.Person.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iensfz4m.PersonTable(tableRelation: foreignTableRelation),
    );
    return _left!;
  }

  _iensfz4m.PersonTable get right {
    if (_right != null) return _right!;
    _right = _isd.createRelationTable(
      relationFieldName: 'right',
      field: UniqueFkPair.t.rightId,
      foreignField: _iensfz4m.Person.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iensfz4m.PersonTable(tableRelation: foreignTableRelation),
    );
    return _right!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    name,
    leftId,
    rightId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'left') {
      return left;
    }
    if (relationField == 'right') {
      return right;
    }
    return null;
  }
}

class UniqueFkPairInclude extends _isd.IncludeObject {
  UniqueFkPairInclude._({
    _iensfz4m.PersonInclude? left,
    _iensfz4m.PersonInclude? right,
  }) {
    _left = left;
    _right = right;
  }

  _iensfz4m.PersonInclude? _left;

  _iensfz4m.PersonInclude? _right;

  @override
  Map<String, _isd.Include?> get includes => {
    'left': _left,
    'right': _right,
  };

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueFkPair.t;
}

class UniqueFkPairIncludeList extends _isd.IncludeList {
  UniqueFkPairIncludeList._({
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(UniqueFkPair.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => UniqueFkPair.t;
}

class UniqueFkPairRepository {
  const UniqueFkPairRepository._();

  final attachRow = const UniqueFkPairAttachRowRepository._();

  final detachRow = const UniqueFkPairDetachRowRepository._();

  /// Returns a list of [UniqueFkPair]s matching the given query parameters.
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
  Future<List<UniqueFkPair>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    _isd.Transaction? transaction,
    UniqueFkPairInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<UniqueFkPair>(
      where: where?.call(UniqueFkPair.t),
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [UniqueFkPair] matching the given query parameters.
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
  Future<UniqueFkPair?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? where,
    int? offset,
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    _isd.Transaction? transaction,
    UniqueFkPairInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<UniqueFkPair>(
      where: where?.call(UniqueFkPair.t),
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [UniqueFkPair] by its [id] or null if no such row exists.
  Future<UniqueFkPair?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    UniqueFkPairInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<UniqueFkPair>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [UniqueFkPair]s in the list and returns the inserted rows.
  ///
  /// The returned [UniqueFkPair]s will have their `id` fields set.
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
  Future<List<UniqueFkPair>> insert(
    _isd.DatabaseSession session,
    List<UniqueFkPair> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<UniqueFkPair>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [UniqueFkPair] and returns the inserted row.
  ///
  /// The returned [UniqueFkPair] will have its `id` field set.
  Future<UniqueFkPair> insertRow(
    _isd.DatabaseSession session,
    UniqueFkPair row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<UniqueFkPair>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [UniqueFkPair]s in the list and returns the resulting rows.
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
  /// The returned [UniqueFkPair]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueFkPair>> upsert(
    _isd.DatabaseSession session,
    List<UniqueFkPair> rows, {
    required _isd.ColumnSelections<UniqueFkPairTable> conflictColumns,
    _isd.ColumnSelections<UniqueFkPairTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<UniqueFkPair>(
      rows,
      conflictColumns: conflictColumns(UniqueFkPair.t),
      updateColumns: updateColumns?.call(UniqueFkPair.t),
      updateWhere: updateWhere?.call(UniqueFkPair.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [UniqueFkPair] and returns the resulting row.
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
  /// The returned [UniqueFkPair] will have its `id` field set.
  Future<UniqueFkPair?> upsertRow(
    _isd.DatabaseSession session,
    UniqueFkPair row, {
    required _isd.ColumnSelections<UniqueFkPairTable> conflictColumns,
    _isd.ColumnSelections<UniqueFkPairTable>? updateColumns,
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<UniqueFkPair>(
      row,
      conflictColumns: conflictColumns(UniqueFkPair.t),
      updateColumns: updateColumns?.call(UniqueFkPair.t),
      updateWhere: updateWhere?.call(UniqueFkPair.t),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueFkPair]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueFkPair>> update(
    _isd.DatabaseSession session,
    List<UniqueFkPair> rows, {
    _isd.ColumnSelections<UniqueFkPairTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<UniqueFkPair>(
      rows,
      columns: columns?.call(UniqueFkPair.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [UniqueFkPair]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<UniqueFkPair> updateRow(
    _isd.DatabaseSession session,
    UniqueFkPair row, {
    _isd.ColumnSelections<UniqueFkPairTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<UniqueFkPair>(
      row,
      columns: columns?.call(UniqueFkPair.t),
      transaction: transaction,
    );
  }

  /// Updates a single [UniqueFkPair] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<UniqueFkPair?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<UniqueFkPairUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<UniqueFkPair>(
      id,
      columnValues: columnValues(UniqueFkPair.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [UniqueFkPair]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<UniqueFkPair>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<UniqueFkPairUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<UniqueFkPairTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<UniqueFkPair>(
      columnValues: columnValues(UniqueFkPair.t.updateTable),
      where: where(UniqueFkPair.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [UniqueFkPair]s in the list and returns the deleted rows.
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
  Future<List<UniqueFkPair>> delete(
    _isd.DatabaseSession session,
    List<UniqueFkPair> rows, {
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<UniqueFkPair>(
      rows,
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [UniqueFkPair].
  Future<UniqueFkPair> deleteRow(
    _isd.DatabaseSession session,
    UniqueFkPair row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<UniqueFkPair>(
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
  Future<List<UniqueFkPair>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueFkPairTable> where,
    _isd.OrderByBuilder<UniqueFkPairTable>? orderBy,
    _isd.OrderByListBuilder<UniqueFkPairTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<UniqueFkPair>(
      where: where(UniqueFkPair.t),
      orderBy: orderBy?.call(UniqueFkPair.t),
      orderByList: orderByList?.call(UniqueFkPair.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<UniqueFkPairTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<UniqueFkPair>(
      where: where?.call(UniqueFkPair.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [UniqueFkPair] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<UniqueFkPairTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<UniqueFkPair>(
      where: where(UniqueFkPair.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class UniqueFkPairAttachRowRepository {
  const UniqueFkPairAttachRowRepository._();

  /// Creates a relation between the given [UniqueFkPair] and [Person]
  /// by setting the [UniqueFkPair]'s foreign key `leftId` to refer to the [Person].
  Future<void> left(
    _isd.DatabaseSession session,
    UniqueFkPair uniqueFkPair,
    _iensfz4m.Person left, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueFkPair.id == null) {
      throw ArgumentError.notNull('uniqueFkPair.id');
    }
    if (left.id == null) {
      throw ArgumentError.notNull('left.id');
    }

    var $uniqueFkPair = uniqueFkPair.copyWith(leftId: left.id);
    await session.db.updateRow<UniqueFkPair>(
      $uniqueFkPair,
      columns: [UniqueFkPair.t.leftId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [UniqueFkPair] and [Person]
  /// by setting the [UniqueFkPair]'s foreign key `rightId` to refer to the [Person].
  Future<void> right(
    _isd.DatabaseSession session,
    UniqueFkPair uniqueFkPair,
    _iensfz4m.Person right, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueFkPair.id == null) {
      throw ArgumentError.notNull('uniqueFkPair.id');
    }
    if (right.id == null) {
      throw ArgumentError.notNull('right.id');
    }

    var $uniqueFkPair = uniqueFkPair.copyWith(rightId: right.id);
    await session.db.updateRow<UniqueFkPair>(
      $uniqueFkPair,
      columns: [UniqueFkPair.t.rightId],
      transaction: transaction,
    );
  }
}

class UniqueFkPairDetachRowRepository {
  const UniqueFkPairDetachRowRepository._();

  /// Detaches the relation between this [UniqueFkPair] and the [Person] set in `left`
  /// by setting the [UniqueFkPair]'s foreign key `leftId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> left(
    _isd.DatabaseSession session,
    UniqueFkPair uniqueFkPair, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueFkPair.id == null) {
      throw ArgumentError.notNull('uniqueFkPair.id');
    }

    var $uniqueFkPair = uniqueFkPair.copyWith(leftId: null);
    await session.db.updateRow<UniqueFkPair>(
      $uniqueFkPair,
      columns: [UniqueFkPair.t.leftId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [UniqueFkPair] and the [Person] set in `right`
  /// by setting the [UniqueFkPair]'s foreign key `rightId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> right(
    _isd.DatabaseSession session,
    UniqueFkPair uniqueFkPair, {
    _isd.Transaction? transaction,
  }) async {
    if (uniqueFkPair.id == null) {
      throw ArgumentError.notNull('uniqueFkPair.id');
    }

    var $uniqueFkPair = uniqueFkPair.copyWith(rightId: null);
    await session.db.updateRow<UniqueFkPair>(
      $uniqueFkPair,
      columns: [UniqueFkPair.t.rightId],
      transaction: transaction,
    );
  }
}
