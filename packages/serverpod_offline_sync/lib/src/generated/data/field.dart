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

/// CRDT data table.
///
/// This table stores only the HLC timestamp for a field. During merge, if the
/// other HLC is greater, the actual data must be fetched from the table itself.
abstract class CrdtDataField extends _icw2tu00.BaseHlc
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
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
    this.attemptedValue,
  });

  factory CrdtDataField({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int rowId,
    _icw2tu00.CrdtDataRow? row,
    required int columnId,
    _icw2tu00.CrdtSchemaColumn? column,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataAttemptedValue? attemptedValue,
  }) = _CrdtDataFieldImpl;

  factory CrdtDataField.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataField(
      id: jsonSerialization['id'] as int?,
      hlcDatetime: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['hlcDatetime'],
      ),
      hlcCounter: jsonSerialization['hlcCounter'] as int,
      rowId: jsonSerialization['rowId'] as int,
      row: jsonSerialization['row'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataRow>(
              jsonSerialization['row'],
            ),
      columnId: jsonSerialization['columnId'] as int,
      column: jsonSerialization['column'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtSchemaColumn>(
              jsonSerialization['column'],
            ),
      nodeId: jsonSerialization['nodeId'] as int,
      node: jsonSerialization['node'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtNode>(
              jsonSerialization['node'],
            ),
      attemptedValue: jsonSerialization['attemptedValue'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataAttemptedValue>(
              jsonSerialization['attemptedValue'],
            ),
    );
  }

  static final t = CrdtDataFieldTable();

  static const db = CrdtDataFieldRepository._();

  @override
  int? id;

  int rowId;

  /// Row that the field belongs to.
  _icw2tu00.CrdtDataRow? row;

  int columnId;

  /// Column that the field belongs to.
  _icw2tu00.CrdtSchemaColumn? column;

  int nodeId;

  /// The node that updated the field.
  _icw2tu00.CrdtNode? node;

  /// Authored value retained while a projector materializes a different domain
  /// value for this field.
  _icw2tu00.CrdtDataAttemptedValue? attemptedValue;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataField]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtDataField copyWith({
    int? id,
    DateTime? hlcDatetime,
    int? hlcCounter,
    int? rowId,
    _icw2tu00.CrdtDataRow? row,
    int? columnId,
    _icw2tu00.CrdtSchemaColumn? column,
    int? nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataAttemptedValue? attemptedValue,
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
      if (attemptedValue != null) 'attemptedValue': attemptedValue?.toJson(),
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
      if (attemptedValue != null)
        'attemptedValue': attemptedValue?.toJsonForProtocol(),
    };
  }

  static CrdtDataFieldInclude include({
    _icw2tu00.CrdtDataRowInclude? row,
    _icw2tu00.CrdtSchemaColumnInclude? column,
    _icw2tu00.CrdtNodeInclude? node,
    _icw2tu00.CrdtDataAttemptedValueInclude? attemptedValue,
  }) {
    return CrdtDataFieldInclude._(
      row: row,
      column: column,
      node: node,
      attemptedValue: attemptedValue,
    );
  }

  static CrdtDataFieldIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
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
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataFieldImpl extends CrdtDataField {
  _CrdtDataFieldImpl({
    int? id,
    required DateTime hlcDatetime,
    required int hlcCounter,
    required int rowId,
    _icw2tu00.CrdtDataRow? row,
    required int columnId,
    _icw2tu00.CrdtSchemaColumn? column,
    required int nodeId,
    _icw2tu00.CrdtNode? node,
    _icw2tu00.CrdtDataAttemptedValue? attemptedValue,
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
         attemptedValue: attemptedValue,
       );

  /// Returns a shallow copy of this [CrdtDataField]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
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
    Object? attemptedValue = _Undefined,
  }) {
    return CrdtDataField(
      id: id is int? ? id : this.id,
      hlcDatetime: hlcDatetime ?? this.hlcDatetime,
      hlcCounter: hlcCounter ?? this.hlcCounter,
      rowId: rowId ?? this.rowId,
      row: row is _icw2tu00.CrdtDataRow? ? row : this.row?.copyWith(),
      columnId: columnId ?? this.columnId,
      column: column is _icw2tu00.CrdtSchemaColumn?
          ? column
          : this.column?.copyWith(),
      nodeId: nodeId ?? this.nodeId,
      node: node is _icw2tu00.CrdtNode? ? node : this.node?.copyWith(),
      attemptedValue: attemptedValue is _icw2tu00.CrdtDataAttemptedValue?
          ? attemptedValue
          : this.attemptedValue?.copyWith(),
    );
  }
}

class CrdtDataFieldUpdateTable extends _isd.UpdateTable<CrdtDataFieldTable> {
  CrdtDataFieldUpdateTable(super.table);

  _isd.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime value) =>
      _isd.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _isd.ColumnValue<int, int> hlcCounter(int value) => _isd.ColumnValue(
    table.hlcCounter,
    value,
  );

  _isd.ColumnValue<int, int> rowId(int value) => _isd.ColumnValue(
    table.rowId,
    value,
  );

  _isd.ColumnValue<int, int> columnId(int value) => _isd.ColumnValue(
    table.columnId,
    value,
  );

  _isd.ColumnValue<int, int> nodeId(int value) => _isd.ColumnValue(
    table.nodeId,
    value,
  );
}

class CrdtDataFieldTable extends _isd.Table<int?> {
  CrdtDataFieldTable({super.tableRelation})
    : super(tableName: 'crdt_data_fields') {
    updateTable = CrdtDataFieldUpdateTable(this);
    hlcDatetime = _isd.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _isd.ColumnInt(
      'hlcCounter',
      this,
    );
    rowId = _isd.ColumnInt(
      'rowId',
      this,
    );
    columnId = _isd.ColumnInt(
      'columnId',
      this,
    );
    nodeId = _isd.ColumnInt(
      'nodeId',
      this,
    );
  }

  late final CrdtDataFieldUpdateTable updateTable;

  /// The datetime component of the HLC timestamp.
  late final _isd.ColumnDateTime hlcDatetime;

  /// The counter component of the HLC timestamp.
  late final _isd.ColumnInt hlcCounter;

  late final _isd.ColumnInt rowId;

  /// Row that the field belongs to.
  _icw2tu00.CrdtDataRowTable? _row;

  late final _isd.ColumnInt columnId;

  /// Column that the field belongs to.
  _icw2tu00.CrdtSchemaColumnTable? _column;

  late final _isd.ColumnInt nodeId;

  /// The node that updated the field.
  _icw2tu00.CrdtNodeTable? _node;

  /// Authored value retained while a projector materializes a different domain
  /// value for this field.
  _icw2tu00.CrdtDataAttemptedValueTable? _attemptedValue;

  _icw2tu00.CrdtDataRowTable get row {
    if (_row != null) return _row!;
    _row = _isd.createRelationTable(
      relationFieldName: 'row',
      field: CrdtDataField.t.rowId,
      foreignField: _icw2tu00.CrdtDataRow.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return _row!;
  }

  _icw2tu00.CrdtSchemaColumnTable get column {
    if (_column != null) return _column!;
    _column = _isd.createRelationTable(
      relationFieldName: 'column',
      field: CrdtDataField.t.columnId,
      foreignField: _icw2tu00.CrdtSchemaColumn.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtSchemaColumnTable(tableRelation: foreignTableRelation),
    );
    return _column!;
  }

  _icw2tu00.CrdtNodeTable get node {
    if (_node != null) return _node!;
    _node = _isd.createRelationTable(
      relationFieldName: 'node',
      field: CrdtDataField.t.nodeId,
      foreignField: _icw2tu00.CrdtNode.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtNodeTable(tableRelation: foreignTableRelation),
    );
    return _node!;
  }

  _icw2tu00.CrdtDataAttemptedValueTable get attemptedValue {
    if (_attemptedValue != null) return _attemptedValue!;
    _attemptedValue = _isd.createRelationTable(
      relationFieldName: 'attemptedValue',
      field: CrdtDataField.t.id,
      foreignField: _icw2tu00.CrdtDataAttemptedValue.t.fieldId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataAttemptedValueTable(
            tableRelation: foreignTableRelation,
          ),
    );
    return _attemptedValue!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    hlcDatetime,
    hlcCounter,
    rowId,
    columnId,
    nodeId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'row') {
      return row;
    }
    if (relationField == 'column') {
      return column;
    }
    if (relationField == 'node') {
      return node;
    }
    if (relationField == 'attemptedValue') {
      return attemptedValue;
    }
    return null;
  }
}

class CrdtDataFieldInclude extends _isd.IncludeObject {
  CrdtDataFieldInclude._({
    _icw2tu00.CrdtDataRowInclude? row,
    _icw2tu00.CrdtSchemaColumnInclude? column,
    _icw2tu00.CrdtNodeInclude? node,
    _icw2tu00.CrdtDataAttemptedValueInclude? attemptedValue,
  }) {
    _row = row;
    _column = column;
    _node = node;
    _attemptedValue = attemptedValue;
  }

  _icw2tu00.CrdtDataRowInclude? _row;

  _icw2tu00.CrdtSchemaColumnInclude? _column;

  _icw2tu00.CrdtNodeInclude? _node;

  _icw2tu00.CrdtDataAttemptedValueInclude? _attemptedValue;

  @override
  Map<String, _isd.Include?> get includes => {
    'row': _row,
    'column': _column,
    'node': _node,
    'attemptedValue': _attemptedValue,
  };

  @override
  _isd.Table<int?> get table => CrdtDataField.t;
}

class CrdtDataFieldIncludeList extends _isd.IncludeList {
  CrdtDataFieldIncludeList._({
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataField.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtDataField.t;
}

class CrdtDataFieldRepository {
  const CrdtDataFieldRepository._();

  final attachRow = const CrdtDataFieldAttachRowRepository._();

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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtDataFieldInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<CrdtDataField> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataField> rows, {
    required _isd.ColumnSelections<CrdtDataFieldTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataFieldTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField row, {
    required _isd.ColumnSelections<CrdtDataFieldTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataFieldTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataField> rows, {
    _isd.ColumnSelections<CrdtDataFieldTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField row, {
    _isd.ColumnSelections<CrdtDataFieldTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtDataFieldUpdateTable> columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtDataFieldUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CrdtDataFieldTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtDataField> rows, {
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataFieldTable> where,
    _isd.OrderByBuilder<CrdtDataFieldTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataFieldTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataFieldTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataField>(
      where: where?.call(CrdtDataField.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataField] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataFieldTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
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
    _isd.DatabaseSession session,
    CrdtDataField crdtDataField,
    _icw2tu00.CrdtDataRow row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField crdtDataField,
    _icw2tu00.CrdtSchemaColumn column, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtDataField crdtDataField,
    _icw2tu00.CrdtNode node, {
    _isd.Transaction? transaction,
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

  /// Creates a relation between the given [CrdtDataField] and [CrdtDataAttemptedValue]
  /// by setting the [CrdtDataField]'s foreign key `id` to refer to the [CrdtDataAttemptedValue].
  Future<void> attemptedValue(
    _isd.DatabaseSession session,
    CrdtDataField crdtDataField,
    _icw2tu00.CrdtDataAttemptedValue attemptedValue, {
    _isd.Transaction? transaction,
  }) async {
    if (attemptedValue.id == null) {
      throw ArgumentError.notNull('attemptedValue.id');
    }
    if (crdtDataField.id == null) {
      throw ArgumentError.notNull('crdtDataField.id');
    }

    var $attemptedValue = attemptedValue.copyWith(fieldId: crdtDataField.id);
    await session.db.updateRow<_icw2tu00.CrdtDataAttemptedValue>(
      $attemptedValue,
      columns: [_icw2tu00.CrdtDataAttemptedValue.t.fieldId],
      transaction: transaction,
    );
  }
}
