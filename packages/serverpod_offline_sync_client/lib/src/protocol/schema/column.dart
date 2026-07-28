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
import 'package:serverpod_database/serverpod_database.dart' as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import '../schema/table.dart' as _i3;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i4;

/// CRDT schema columns table.
abstract class CrdtSchemaColumn
    implements _i1.TableRow<int?>, _i2.ProtocolSerialization {
  CrdtSchemaColumn._({
    this.id,
    required this.tblId,
    this.tbl,
    required this.name,
  });

  factory CrdtSchemaColumn({
    int? id,
    required int tblId,
    _i3.CrdtSchemaTable? tbl,
    required String name,
  }) = _CrdtSchemaColumnImpl;

  factory CrdtSchemaColumn.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSchemaColumn(
      id: jsonSerialization['id'] as int?,
      tblId: jsonSerialization['tblId'] as int,
      tbl: jsonSerialization['tbl'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.CrdtSchemaTable>(
              jsonSerialization['tbl'],
            ),
      name: jsonSerialization['name'] as String,
    );
  }

  static final t = CrdtSchemaColumnTable();

  static const db = CrdtSchemaColumnRepository._();

  @override
  int? id;

  int tblId;

  /// Reference to the table this column belongs to.
  _i3.CrdtSchemaTable? tbl;

  /// Name of the column.
  String name;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtSchemaColumn]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  CrdtSchemaColumn copyWith({
    int? id,
    int? tblId,
    _i3.CrdtSchemaTable? tbl,
    String? name,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSchemaColumn',
      if (id != null) 'id': id,
      'tblId': tblId,
      if (tbl != null) 'tbl': tbl?.toJson(),
      'name': name,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSchemaColumn',
      if (id != null) 'id': id,
      'tblId': tblId,
      if (tbl != null) 'tbl': tbl?.toJsonForProtocol(),
      'name': name,
    };
  }

  static CrdtSchemaColumnInclude include({_i3.CrdtSchemaTableInclude? tbl}) {
    return CrdtSchemaColumnInclude._(tbl: tbl);
  }

  static CrdtSchemaColumnIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    CrdtSchemaColumnInclude? include,
  }) {
    return CrdtSchemaColumnIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtSchemaColumnImpl extends CrdtSchemaColumn {
  _CrdtSchemaColumnImpl({
    int? id,
    required int tblId,
    _i3.CrdtSchemaTable? tbl,
    required String name,
  }) : super._(
         id: id,
         tblId: tblId,
         tbl: tbl,
         name: name,
       );

  /// Returns a shallow copy of this [CrdtSchemaColumn]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSchemaColumn copyWith({
    Object? id = _Undefined,
    int? tblId,
    Object? tbl = _Undefined,
    String? name,
  }) {
    return CrdtSchemaColumn(
      id: id is int? ? id : this.id,
      tblId: tblId ?? this.tblId,
      tbl: tbl is _i3.CrdtSchemaTable? ? tbl : this.tbl?.copyWith(),
      name: name ?? this.name,
    );
  }
}

class CrdtSchemaColumnUpdateTable
    extends _i1.UpdateTable<CrdtSchemaColumnTable> {
  CrdtSchemaColumnUpdateTable(super.table);

  _i1.ColumnValue<int, int> tblId(int value) => _i1.ColumnValue(
    table.tblId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );
}

class CrdtSchemaColumnTable extends _i1.Table<int?> {
  CrdtSchemaColumnTable({super.tableRelation})
    : super(tableName: 'crdt_schema_columns') {
    updateTable = CrdtSchemaColumnUpdateTable(this);
    tblId = _i1.ColumnInt(
      'tblId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
  }

  late final CrdtSchemaColumnUpdateTable updateTable;

  late final _i1.ColumnInt tblId;

  /// Reference to the table this column belongs to.
  _i3.CrdtSchemaTableTable? _tbl;

  /// Name of the column.
  late final _i1.ColumnString name;

  _i3.CrdtSchemaTableTable get tbl {
    if (_tbl != null) return _tbl!;
    _tbl = _i1.createRelationTable(
      relationFieldName: 'tbl',
      field: CrdtSchemaColumn.t.tblId,
      foreignField: _i3.CrdtSchemaTable.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.CrdtSchemaTableTable(tableRelation: foreignTableRelation),
    );
    return _tbl!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    tblId,
    name,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'tbl') {
      return tbl;
    }
    return null;
  }
}

class CrdtSchemaColumnInclude extends _i1.IncludeObject {
  CrdtSchemaColumnInclude._({_i3.CrdtSchemaTableInclude? tbl}) {
    _tbl = tbl;
  }

  _i3.CrdtSchemaTableInclude? _tbl;

  @override
  Map<String, _i1.Include?> get includes => {'tbl': _tbl};

  @override
  _i1.Table<int?> get table => CrdtSchemaColumn.t;
}

class CrdtSchemaColumnIncludeList extends _i1.IncludeList {
  CrdtSchemaColumnIncludeList._({
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtSchemaColumn.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtSchemaColumn.t;
}

class CrdtSchemaColumnRepository {
  const CrdtSchemaColumnRepository._();

  final attachRow = const CrdtSchemaColumnAttachRowRepository._();

  /// Returns a list of [CrdtSchemaColumn]s matching the given query parameters.
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
  Future<List<CrdtSchemaColumn>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtSchemaColumnInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtSchemaColumn>(
      where: where?.call(CrdtSchemaColumn.t),
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtSchemaColumn] matching the given query parameters.
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
  Future<CrdtSchemaColumn?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtSchemaColumnInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtSchemaColumn>(
      where: where?.call(CrdtSchemaColumn.t),
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtSchemaColumn] by its [id] or null if no such row exists.
  Future<CrdtSchemaColumn?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    CrdtSchemaColumnInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtSchemaColumn>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtSchemaColumn]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtSchemaColumn]s will have their `id` fields set.
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
  Future<List<CrdtSchemaColumn>> insert(
    _i1.DatabaseSession session,
    List<CrdtSchemaColumn> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtSchemaColumn>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtSchemaColumn] and returns the inserted row.
  ///
  /// The returned [CrdtSchemaColumn] will have its `id` field set.
  Future<CrdtSchemaColumn> insertRow(
    _i1.DatabaseSession session,
    CrdtSchemaColumn row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtSchemaColumn>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtSchemaColumn]s in the list and returns the resulting rows.
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
  /// The returned [CrdtSchemaColumn]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaColumn>> upsert(
    _i1.DatabaseSession session,
    List<CrdtSchemaColumn> rows, {
    required _i1.ColumnSelections<CrdtSchemaColumnTable> conflictColumns,
    _i1.ColumnSelections<CrdtSchemaColumnTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtSchemaColumn>(
      rows,
      conflictColumns: conflictColumns(CrdtSchemaColumn.t),
      updateColumns: updateColumns?.call(CrdtSchemaColumn.t),
      updateWhere: updateWhere?.call(CrdtSchemaColumn.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtSchemaColumn] and returns the resulting row.
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
  /// The returned [CrdtSchemaColumn] will have its `id` field set.
  Future<CrdtSchemaColumn?> upsertRow(
    _i1.DatabaseSession session,
    CrdtSchemaColumn row, {
    required _i1.ColumnSelections<CrdtSchemaColumnTable> conflictColumns,
    _i1.ColumnSelections<CrdtSchemaColumnTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtSchemaColumn>(
      row,
      conflictColumns: conflictColumns(CrdtSchemaColumn.t),
      updateColumns: updateColumns?.call(CrdtSchemaColumn.t),
      updateWhere: updateWhere?.call(CrdtSchemaColumn.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSchemaColumn]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaColumn>> update(
    _i1.DatabaseSession session,
    List<CrdtSchemaColumn> rows, {
    _i1.ColumnSelections<CrdtSchemaColumnTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtSchemaColumn>(
      rows,
      columns: columns?.call(CrdtSchemaColumn.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtSchemaColumn]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtSchemaColumn> updateRow(
    _i1.DatabaseSession session,
    CrdtSchemaColumn row, {
    _i1.ColumnSelections<CrdtSchemaColumnTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtSchemaColumn>(
      row,
      columns: columns?.call(CrdtSchemaColumn.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtSchemaColumn] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtSchemaColumn?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtSchemaColumnUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtSchemaColumn>(
      id,
      columnValues: columnValues(CrdtSchemaColumn.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSchemaColumn]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSchemaColumn>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtSchemaColumnUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<CrdtSchemaColumnTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtSchemaColumn>(
      columnValues: columnValues(CrdtSchemaColumn.t.updateTable),
      where: where(CrdtSchemaColumn.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtSchemaColumn]s in the list and returns the deleted rows.
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
  Future<List<CrdtSchemaColumn>> delete(
    _i1.DatabaseSession session,
    List<CrdtSchemaColumn> rows, {
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtSchemaColumn>(
      rows,
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtSchemaColumn].
  Future<CrdtSchemaColumn> deleteRow(
    _i1.DatabaseSession session,
    CrdtSchemaColumn row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtSchemaColumn>(
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
  Future<List<CrdtSchemaColumn>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSchemaColumnTable> where,
    _i1.OrderByBuilder<CrdtSchemaColumnTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSchemaColumnTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtSchemaColumn>(
      where: where(CrdtSchemaColumn.t),
      orderBy: orderBy?.call(CrdtSchemaColumn.t),
      orderByList: orderByList?.call(CrdtSchemaColumn.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSchemaColumnTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtSchemaColumn>(
      where: where?.call(CrdtSchemaColumn.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtSchemaColumn] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSchemaColumnTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtSchemaColumn>(
      where: where(CrdtSchemaColumn.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtSchemaColumnAttachRowRepository {
  const CrdtSchemaColumnAttachRowRepository._();

  /// Creates a relation between the given [CrdtSchemaColumn] and [CrdtSchemaTable]
  /// by setting the [CrdtSchemaColumn]'s foreign key `tblId` to refer to the [CrdtSchemaTable].
  Future<void> tbl(
    _i1.DatabaseSession session,
    CrdtSchemaColumn crdtSchemaColumn,
    _i3.CrdtSchemaTable tbl, {
    _i1.Transaction? transaction,
  }) async {
    if (crdtSchemaColumn.id == null) {
      throw ArgumentError.notNull('crdtSchemaColumn.id');
    }
    if (tbl.id == null) {
      throw ArgumentError.notNull('tbl.id');
    }

    var $crdtSchemaColumn = crdtSchemaColumn.copyWith(tblId: tbl.id);
    await session.db.updateRow<CrdtSchemaColumn>(
      $crdtSchemaColumn,
      columns: [CrdtSchemaColumn.t.tblId],
      transaction: transaction,
    );
  }
}
