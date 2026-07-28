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
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as _i1;
import 'package:serverpod/serverpod.dart' as _i2;
import '../data/row.dart' as _i3;
import '../schema/column.dart' as _i4;
import '../node/node.dart' as _i5;
import '../data/foreign_key.dart' as _i6;
import 'package:serverpod_offline_sync_server/src/generated/protocol.dart'
    as _i7;

/// CRDT data table.
///
/// This table stores only the HLC timestamp for a field. During merge, if the
/// other HLC is greater, the actual data must be fetched from the table itself.
abstract class CrdtDataField extends _i1.BaseHlc
    implements _i2.TableRow<int?>, _i2.ProtocolSerialization {
  CrdtDataField._({
    this.id,
    required super.hlcDatetime,
    required super.hlcCounter,
    required this.rowId,
    this.row,
    required this.columnId,
    this.column,
    required this.nodeId,
    this.node,
    this.foreignKey,
  });

  factory CrdtDataField({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int rowId,
    _i3.CrdtDataRow? row,
    required int columnId,
    _i4.CrdtSchemaColumn? column,
    required int nodeId,
    _i5.CrdtNode? node,
    _i6.CrdtDataForeignKey? foreignKey,
  }) = _CrdtDataFieldImpl;

  factory CrdtDataField.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataField(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _i2.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      rowId: jsonSerialization['rowId'] as int,
      row: jsonSerialization['row'] == null
          ? null
          : _i7.Protocol().deserialize<_i3.CrdtDataRow>(
              jsonSerialization['row'],
            ),
      columnId: jsonSerialization['columnId'] as int,
      column: jsonSerialization['column'] == null
          ? null
          : _i7.Protocol().deserialize<_i4.CrdtSchemaColumn>(
              jsonSerialization['column'],
            ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _i7.Protocol().deserialize<_i5.CrdtNode>(jsonSerialization['node']),
      foreignKey: jsonSerialization['foreignKey'] == null
          ? null
          : _i7.Protocol().deserialize<_i6.CrdtDataForeignKey>(
              jsonSerialization['foreignKey'],
            ),
    );
  }

  static final t = CrdtDataFieldTable();

  static const db = CrdtDataFieldRepository._();

  @override
  int? id;

  int rowId;

  /// Row that the field belongs to.
  _i3.CrdtDataRow? row;

  int columnId;

  /// Column that the field belongs to.
  _i4.CrdtSchemaColumn? column;

  int nodeId;

  /// The node that updated the field.
  _i5.CrdtNode? node;

  /// The foreign key information for the field, if this field holds a
  /// reference to another row.
  _i6.CrdtDataForeignKey? foreignKey;

  @override
  _i2.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataField]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtDataField copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? rowId,
    _i3.CrdtDataRow? row,
    int? columnId,
    _i4.CrdtSchemaColumn? column,
    int? nodeId,
    _i5.CrdtNode? node,
    _i6.CrdtDataForeignKey? foreignKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataField',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'rowId': rowId,
      if (row != null) 'row': row?.toJson(),
      'columnId': columnId,
      if (column != null) 'column': column?.toJson(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJson(),
      if (foreignKey != null) 'foreignKey': foreignKey?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataField',
      if (id != null) 'id': id,
      'hlcDatetime': hlcDatetime.toJson(),
      'hlcCounter': hlcCounter,
      'rowId': rowId,
      if (row != null) 'row': row?.toJsonForProtocol(),
      'columnId': columnId,
      if (column != null) 'column': column?.toJsonForProtocol(),
      'nodeId': nodeId,
      if (node != null) 'node': node?.toJsonForProtocol(),
      if (foreignKey != null) 'foreignKey': foreignKey?.toJsonForProtocol(),
    };
  }

  static CrdtDataFieldInclude include({
    _i3.CrdtDataRowInclude? row,
    _i4.CrdtSchemaColumnInclude? column,
    _i5.CrdtNodeInclude? node,
    _i6.CrdtDataForeignKeyInclude? foreignKey,
  }) {
    return CrdtDataFieldInclude._(
      row: row,
      column: column,
      node: node,
      foreignKey: foreignKey,
    );
  }

  static CrdtDataFieldIncludeList includeList({
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    CrdtDataFieldInclude? include,
  }) {
    return CrdtDataFieldIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataFieldImpl extends CrdtDataField {
  _CrdtDataFieldImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int rowId,
    _i3.CrdtDataRow? row,
    required int columnId,
    _i4.CrdtSchemaColumn? column,
    required int nodeId,
    _i5.CrdtNode? node,
    _i6.CrdtDataForeignKey? foreignKey,
  }) : super._(
         id: id,
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         rowId: rowId,
         row: row,
         columnId: columnId,
         column: column,
         nodeId: nodeId,
         node: node,
         foreignKey: foreignKey,
       );

  /// Returns a shallow copy of this [CrdtDataField]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtDataField copyWith({
    Object? id = _Undefined,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? rowId,
    Object? row = _Undefined,
    int? columnId,
    Object? column = _Undefined,
    int? nodeId,
    Object? node = _Undefined,
    Object? foreignKey = _Undefined,
  }) {
    return CrdtDataField(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      rowId: rowId ?? this.rowId,
      row: row is _i3.CrdtDataRow? ? row : this.row?.copyWith(),
      columnId: columnId ?? this.columnId,
      column: column is _i4.CrdtSchemaColumn?
          ? column
          : this.column?.copyWith(),
      nodeId: nodeId ?? this.nodeId,
      node: node is _i5.CrdtNode? ? node : this.node?.copyWith(),
      foreignKey: foreignKey is _i6.CrdtDataForeignKey?
          ? foreignKey
          : this.foreignKey?.copyWith(),
    );
  }
}

class CrdtDataFieldUpdateTable extends _i2.UpdateTable<CrdtDataFieldTable> {
  CrdtDataFieldUpdateTable(super.table);

  _i2.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _i2.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _i2.ColumnValue<int, int> hlcCounter(int value) => _i2.ColumnValue(
    table.hlcCounter,
    value,
  );

  _i2.ColumnValue<int, int> rowId(int value) => _i2.ColumnValue(
    table.rowId,
    value,
  );

  _i2.ColumnValue<int, int> columnId(int value) => _i2.ColumnValue(
    table.columnId,
    value,
  );

  _i2.ColumnValue<int, int> nodeId(int value) => _i2.ColumnValue(
    table.nodeId,
    value,
  );
}

class CrdtDataFieldTable extends _i2.Table<int?> {
  CrdtDataFieldTable({super.tableRelation})
    : super(tableName: 'crdt_data_fields') {
    updateTable = CrdtDataFieldUpdateTable(this);
    hlcDatetime = _i2.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _i2.ColumnInt(
      'hlcCounter',
      this,
    );
    rowId = _i2.ColumnInt(
      'rowId',
      this,
    );
    columnId = _i2.ColumnInt(
      'columnId',
      this,
    );
    nodeId = _i2.ColumnInt(
      'nodeId',
      this,
    );
  }

  late final CrdtDataFieldUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _i2.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _i2.ColumnInt hlcCounter;

  late final _i2.ColumnInt rowId;

  /// Row that the field belongs to.
  _i3.CrdtDataRowTable? _row;

  late final _i2.ColumnInt columnId;

  /// Column that the field belongs to.
  _i4.CrdtSchemaColumnTable? _column;

  late final _i2.ColumnInt nodeId;

  /// The node that updated the field.
  _i5.CrdtNodeTable? _node;

  /// The foreign key information for the field, if this field holds a
  /// reference to another row.
  _i6.CrdtDataForeignKeyTable? _foreignKey;

  _i3.CrdtDataRowTable get row {
    if (_row != null) return _row!;
    _row = _i2.createRelationTable(
      relationFieldName: 'row',
      field: CrdtDataField.t.rowId,
      foreignField: _i3.CrdtDataRow.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _i4.CrdtSchemaColumnTable get column {
    if (_column != null) return _column!;
    _column = _i2.createRelationTable(
      relationFieldName: 'column',
      field: CrdtDataField.t.columnId,
      foreignField: _i4.CrdtSchemaColumn.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i4.CrdtSchemaColumnTable(tableRelation: foreignTableRelation),
    );
    return _column!;
  }

  _i5.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _i2.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataField.t.nodeId,
      foreignField: _i5.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i5.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  _i6.CrdtDataForeignKeyTable get foreignKey {
    if (_foreignKey != null) return _foreignKey!;
    _foreignKey = _i2.createRelationTable(
      relationFieldName: 'foreignKey',
      field: CrdtDataField.t.id,
      foreignField: _i6.CrdtDataForeignKey.t.fieldId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i6.CrdtDataForeignKeyTable(tableRelation: foreignTableRelation),
    );
    return _foreignKey!;
  }

  @override
  List<_i2.Column> get columns => [
    id,
    hlcDatetime,
    hlcCounter,
    rowId,
    columnId,
    nodeId,
  ];

  @override
  _i2.Table? getRelationTable(String relationField) {
    if (relationField == 'row') {
      return row;
    }
    if (relationField == 'column') {
      return column;
    }
    if (relationField == 'node') {
      return node;
    }
    if (relationField == 'foreignKey') {
      return foreignKey;
    }
    return null;
  }
}

class CrdtDataFieldInclude extends _i2.IncludeObject {
  CrdtDataFieldInclude._({
    _i3.CrdtDataRowInclude? row,
    _i4.CrdtSchemaColumnInclude? column,
    _i5.CrdtNodeInclude? node,
    _i6.CrdtDataForeignKeyInclude? foreignKey,
  }) {
    _row = row;
    _column = column;
    _node = node;
    _foreignKey = foreignKey;
  }

  _i3.CrdtDataRowInclude? _row;

  _i4.CrdtSchemaColumnInclude? _column;

  _i5.CrdtNodeInclude? _node;

  _i6.CrdtDataForeignKeyInclude? _foreignKey;

  @override
  Map<String, _i2.Include?> get includes => {
    'row': _row,
    'column': _column,
    'node': _node,
    'foreignKey': _foreignKey,
  };

  @override
  _i2.Table<int?> get table => CrdtDataField.t;
}

class CrdtDataFieldIncludeList extends _i2.IncludeList {
  CrdtDataFieldIncludeList._({
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataField.t);
  }

  @override
  Map<String, _i2.Include?> get includes => include?.includes ?? {};

  @override
  _i2.Table<int?> get table => CrdtDataField.t;
}

class CrdtDataFieldRepository {
  const CrdtDataFieldRepository._();

  final attachRow = const CrdtDataFieldAttachRowRepository._();

  final detachRow = const CrdtDataFieldDetachRowRepository._();

  /// Returns a list of [CrdtDataField]s matching the given query parameters.
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
  Future<List<CrdtDataField>> find(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataField>(
      where: where?.call(CrdtDataField.t),
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtDataField] matching the given query parameters.
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
  Future<CrdtDataField?> findFirstRow(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? offset,
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _i2.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataField>(
      where: where?.call(CrdtDataField.t),
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataField] by its [id] or null if no such row exists.
  Future<CrdtDataField?> findById(
    _i2.DatabaseSession session,
    int id, {
    _i2.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _i2.LockMode? lockMode,
    _i2.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtDataField>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtDataField]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtDataField]s will have their `id` fields set.
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
  Future<List<CrdtDataField>> insert(
    _i2.DatabaseSession session,
    List<CrdtDataField> rows, {
    _i2.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtDataField>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtDataField] and returns the inserted row.
  ///
  /// The returned [CrdtDataField] will have its `id` field set.
  Future<CrdtDataField> insertRow(
    _i2.DatabaseSession session,
    CrdtDataField row, {
    _i2.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtDataField>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtDataField]s in the list and returns the resulting rows.
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
  /// The returned [CrdtDataField]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataField>> upsert(
    _i2.DatabaseSession session,
    List<CrdtDataField> rows, {
    required _i2.ColumnSelections<CrdtDataFieldTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataFieldTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? updateWhere,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtDataField>(
      rows,
      conflictColumns: conflictColumns(CrdtDataField.t),
      updateColumns: updateColumns?.call(CrdtDataField.t),
      updateWhere: updateWhere?.call(CrdtDataField.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtDataField] and returns the resulting row.
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
  /// The returned [CrdtDataField] will have its `id` field set.
  Future<CrdtDataField?> upsertRow(
    _i2.DatabaseSession session,
    CrdtDataField row, {
    required _i2.ColumnSelections<CrdtDataFieldTable> conflictColumns,
    _i2.ColumnSelections<CrdtDataFieldTable>? updateColumns,
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? updateWhere,
    _i2.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtDataField>(
      row,
      conflictColumns: conflictColumns(CrdtDataField.t),
      updateColumns: updateColumns?.call(CrdtDataField.t),
      updateWhere: updateWhere?.call(CrdtDataField.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataField]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataField>> update(
    _i2.DatabaseSession session,
    List<CrdtDataField> rows, {
    _i2.ColumnSelections<CrdtDataFieldTable>? columns,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtDataField>(
      rows,
      columns: columns?.call(CrdtDataField.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtDataField]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtDataField> updateRow(
    _i2.DatabaseSession session,
    CrdtDataField row, {
    _i2.ColumnSelections<CrdtDataFieldTable>? columns,
    _i2.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtDataField>(
      row,
      columns: columns?.call(CrdtDataField.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtDataField] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtDataField?> updateById(
    _i2.DatabaseSession session,
    int id, {
    required _i2.ColumnValueListBuilder<CrdtDataFieldUpdateTable> columnValues,
    _i2.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtDataField>(
      id,
      columnValues: columnValues(CrdtDataField.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataField]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataField>> updateWhere(
    _i2.DatabaseSession session, {
    required _i2.ColumnValueListBuilder<CrdtDataFieldUpdateTable> columnValues,
    required _i2.WhereExpressionBuilder<CrdtDataFieldTable> where,
    int? limit,
    int? offset,
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataField>(
      columnValues: columnValues(CrdtDataField.t.updateTable),
      where: where(CrdtDataField.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtDataField]s in the list and returns the deleted rows.
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
  Future<List<CrdtDataField>> delete(
    _i2.DatabaseSession session,
    List<CrdtDataField> rows, {
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataField>(
      rows,
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataField].
  Future<CrdtDataField> deleteRow(
    _i2.DatabaseSession session,
    CrdtDataField row, {
    _i2.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtDataField>(
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
  Future<List<CrdtDataField>> deleteWhere(
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataFieldTable> where,
    _i2.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _i2.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _i2.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataField>(
      where: where(CrdtDataField.t),
      orderBy: orderBy?.call(CrdtDataField.t),
      orderByList: orderByList?.call(CrdtDataField.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i2.DatabaseSession session, {
    _i2.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    _i2.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataField>(
      where: where?.call(CrdtDataField.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataField] rows matching the [where] expression.
  Future<void> lockRows(
    _i2.DatabaseSession session, {
    required _i2.WhereExpressionBuilder<CrdtDataFieldTable> where,
    required _i2.LockMode lockMode,
    required _i2.Transaction transaction,
    _i2.LockBehavior lockBehavior = _i2.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtDataField>(
      where: where(CrdtDataField.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtDataFieldAttachRowRepository {
  const CrdtDataFieldAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataField] and [CrdtDataRow]
  /// by setting the [CrdtDataField]'s foreign key `rowId` to refer to the [CrdtDataRow].
  Future<void> row(
    _i2.DatabaseSession session,
    CrdtDataField crdtDataField,
    _i3.CrdtDataRow row, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (row.id == null) {
      throw ArgumentError.notNull('row.id');
    }

    var $crdtDataField = crdtDataField.copyWith(rowId: row.id);
    await session.db.updateRow<CrdtDataField>(
      $crdtDataField,
      columns: [CrdtDataField.t.rowId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataField] and [CrdtSchemaColumn]
  /// by setting the [CrdtDataField]'s foreign key `columnId` to refer to the [CrdtSchemaColumn].
  Future<void> column(
    _i2.DatabaseSession session,
    CrdtDataField crdtDataField,
    _i4.CrdtSchemaColumn column, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (column.id == null) {
      throw ArgumentError.notNull('column.id');
    }

    var $crdtDataField = crdtDataField.copyWith(columnId: column.id);
    await session.db.updateRow<CrdtDataField>(
      $crdtDataField,
      columns: [CrdtDataField.t.columnId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataField] and [CrdtNode]
  /// by setting the [CrdtDataField]'s foreign key `nodeId` to refer to the [CrdtNode].
  Future<void> node(
    _i2.DatabaseSession session,
    CrdtDataField crdtDataField,
    _i5.CrdtNode node, {
    _i2.Transaction? transaction,
  }) async {
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }
    if (node.id == null) {
      throw ArgumentError.notNull('node.id');
    }

    var $crdtDataField = crdtDataField.copyWith(nodeId: node.id);
    await session.db.updateRow<CrdtDataField>(
      $crdtDataField,
      columns: [CrdtDataField.t.nodeId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [CrdtDataField] and [CrdtDataForeignKey]
  /// by setting the [CrdtDataField]'s foreign key `id` to refer to the [CrdtDataForeignKey].
  Future<void> foreignKey(
    _i2.DatabaseSession session,
    CrdtDataField crdtDataField,
    _i6.CrdtDataForeignKey foreignKey, {
    _i2.Transaction? transaction,
  }) async {
    if (foreignKey.id == null) {
      throw ArgumentError.notNull('foreignKey.id');
    }
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }

    var $foreignKey = foreignKey.copyWith(fieldId: crdtDataField.id);
    await session.db.updateRow<_i6.CrdtDataForeignKey>(
      $foreignKey,
      columns: [_i6.CrdtDataForeignKey.t.fieldId],
      transaction: transaction,
    );
  }
}

class CrdtDataFieldDetachRowRepository {
  const CrdtDataFieldDetachRowRepository._();

  /// Detaches the relation between this [CrdtDataField] and the [CrdtDataForeignKey] set in `foreignKey`
  /// by setting the [CrdtDataField]'s foreign key `id` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> foreignKey(
    _i2.DatabaseSession session,
    CrdtDataField crdtDataField, {
    _i2.Transaction? transaction,
  }) async {
    var $foreignKey = crdtDataField.foreignKey;

    if ($foreignKey == null) {
      throw ArgumentError.notNull('crdtDataField.foreignKey');
    }
    if ($foreignKey.id == null) {
      throw ArgumentError.notNull('crdtDataField.foreignKey.id');
    }
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }

    var $$foreignKey = $foreignKey.copyWith(fieldId: null);
    await session.db.updateRow<_i6.CrdtDataForeignKey>(
      $$foreignKey,
      columns: [_i6.CrdtDataForeignKey.t.fieldId],
      transaction: transaction,
    );
  }
}
