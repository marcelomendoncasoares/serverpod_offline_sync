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

/// Authored field value retained while the domain column holds a projection.
///
/// Sparse one-to-one dependent of CrdtDataField. Present only while the
/// materialized domain value differs from the authored value. `value` is a
/// durable authored fact; `projectionReason` is disposable diagnostic state.
abstract class CrdtDataAttemptedValue
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  CrdtDataAttemptedValue._({
    this.id,
    required this.fieldId,
    this.field,
    required this.value,
    required this.projectionReason,
  });

  factory CrdtDataAttemptedValue({
    int? id,
    required int fieldId,
    _icw2tu00.CrdtDataField? field,
    required dynamic value,
    required _icw2tu00.CrdtProjectionReason projectionReason,
  }) = _CrdtDataAttemptedValueImpl;

  factory CrdtDataAttemptedValue.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return CrdtDataAttemptedValue(
      id: jsonSerialization['id'] as int?,
      fieldId: jsonSerialization['fieldId'] as int,
      field: jsonSerialization['field'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataField>(
              jsonSerialization['field'],
            ),
      value: _icw2tu00.Protocol().deserializeDynamicFieldValue(
        jsonSerialization['value'],
      ),
      projectionReason: _icw2tu00.CrdtProjectionReason.fromJson(
        (jsonSerialization['projectionReason'] as int),
      ),
    );
  }

  static final t = CrdtDataAttemptedValueTable();

  static const db = CrdtDataAttemptedValueRepository._();

  @override
  int? id;

  /// The field whose authored value this row preserves.
  int fieldId;

  _icw2tu00.CrdtDataField? field;

  /// The authored value, using Serverpod's dynamic `{className, data}` envelope.
  dynamic value;

  /// Terminal projector that selected the current domain value.
  _icw2tu00.CrdtProjectionReason projectionReason;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataAttemptedValue]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtDataAttemptedValue copyWith({
    int? id,
    int? fieldId,
    _icw2tu00.CrdtDataField? field,
    dynamic value,
    _icw2tu00.CrdtProjectionReason? projectionReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataAttemptedValue',
      if (id != null) 'id': id,
      'fieldId': fieldId,
      if (field != null) 'field': field?.toJson(),
      'value': _icw2tu00.Protocol().dynamicFieldToJson(value),
      'projectionReason': projectionReason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataAttemptedValue',
      if (id != null) 'id': id,
      'fieldId': fieldId,
      if (field != null) 'field': field?.toJsonForProtocol(),
      'value': _icw2tu00.Protocol().dynamicFieldToJson(
        value,
        forProtocol: true,
      ),
      'projectionReason': projectionReason.toJson(),
    };
  }

  static CrdtDataAttemptedValueInclude include({
    _icw2tu00.CrdtDataFieldInclude? field,
  }) {
    return CrdtDataAttemptedValueInclude._(field: field);
  }

  static CrdtDataAttemptedValueIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    CrdtDataAttemptedValueInclude? include,
  }) {
    return CrdtDataAttemptedValueIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataAttemptedValueImpl extends CrdtDataAttemptedValue {
  _CrdtDataAttemptedValueImpl({
    int? id,
    required int fieldId,
    _icw2tu00.CrdtDataField? field,
    required dynamic value,
    required _icw2tu00.CrdtProjectionReason projectionReason,
  }) : super._(
         id: id,
         fieldId: fieldId,
         field: field,
         value: value,
         projectionReason: projectionReason,
       );

  /// Returns a shallow copy of this [CrdtDataAttemptedValue]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtDataAttemptedValue copyWith({
    Object? id = _Undefined,
    int? fieldId,
    Object? field = _Undefined,
    Object? value = _Undefined,
    _icw2tu00.CrdtProjectionReason? projectionReason,
  }) {
    return CrdtDataAttemptedValue(
      id: id is int? ? id : this.id,
      fieldId: fieldId ?? this.fieldId,
      field: field is _icw2tu00.CrdtDataField? ? field : this.field?.copyWith(),
      value: value != _Undefined ? value : this.value,
      projectionReason: projectionReason ?? this.projectionReason,
    );
  }
}

class CrdtDataAttemptedValueUpdateTable
    extends _isd.UpdateTable<CrdtDataAttemptedValueTable> {
  CrdtDataAttemptedValueUpdateTable(super.table);

  _isd.ColumnValue<int, int> fieldId(int value) => _isd.ColumnValue(
    table.fieldId,
    value,
  );

  _isd.ColumnValue<dynamic, dynamic> value(dynamic value) => _isd.ColumnValue(
    table.value,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.CrdtProjectionReason,
    _icw2tu00.CrdtProjectionReason
  >
  projectionReason(_icw2tu00.CrdtProjectionReason value) => _isd.ColumnValue(
    table.projectionReason,
    value,
  );
}

class CrdtDataAttemptedValueTable extends _isd.Table<int?> {
  CrdtDataAttemptedValueTable({super.tableRelation})
    : super(tableName: 'crdt_data_attempted_value') {
    updateTable = CrdtDataAttemptedValueUpdateTable(this);
    fieldId = _isd.ColumnInt(
      'fieldId',
      this,
    );
    value = _isd.ColumnStructured<dynamic>(
      'value',
      this,
    );
    projectionReason = _isd.ColumnEnum(
      'projectionReason',
      this,
      _isd.EnumSerialization.byIndex,
    );
  }

  late final CrdtDataAttemptedValueUpdateTable updateTable;

  /// The field whose authored value this row preserves.
  late final _isd.ColumnInt fieldId;

  _icw2tu00.CrdtDataFieldTable? _field;

  /// The authored value, using Serverpod's dynamic `{className, data}` envelope.
  late final _isd.ColumnStructured<dynamic> value;

  /// Terminal projector that selected the current domain value.
  late final _isd.ColumnEnum<_icw2tu00.CrdtProjectionReason> projectionReason;

  _icw2tu00.CrdtDataFieldTable get field {
    if (_field != null) return _field!;
    _field = _isd.createRelationTable(
      relationFieldName: 'field',
      field: CrdtDataAttemptedValue.t.fieldId,
      foreignField: _icw2tu00.CrdtDataField.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _icw2tu00.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    return _field!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    fieldId,
    value,
    projectionReason,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'field') {
      return field;
    }
    return null;
  }
}

class CrdtDataAttemptedValueInclude extends _isd.IncludeObject {
  CrdtDataAttemptedValueInclude._({_icw2tu00.CrdtDataFieldInclude? field}) {
    _field = field;
  }

  _icw2tu00.CrdtDataFieldInclude? _field;

  @override
  Map<String, _isd.Include?> get includes => {'field': _field};

  @override
  _isd.Table<int?> get table => CrdtDataAttemptedValue.t;
}

class CrdtDataAttemptedValueIncludeList extends _isd.IncludeList {
  CrdtDataAttemptedValueIncludeList._({
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataAttemptedValue.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtDataAttemptedValue.t;
}

class CrdtDataAttemptedValueRepository {
  const CrdtDataAttemptedValueRepository._();

  final attachRow = const CrdtDataAttemptedValueAttachRowRepository._();

  /// Returns a list of [CrdtDataAttemptedValue]s matching the given query parameters.
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
  Future<List<CrdtDataAttemptedValue>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataAttemptedValueInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataAttemptedValue>(
      where: where?.call(CrdtDataAttemptedValue.t),
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtDataAttemptedValue] matching the given query parameters.
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
  Future<CrdtDataAttemptedValue?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataAttemptedValueInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataAttemptedValue>(
      where: where?.call(CrdtDataAttemptedValue.t),
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataAttemptedValue] by its [id] or null if no such row exists.
  Future<CrdtDataAttemptedValue?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtDataAttemptedValueInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtDataAttemptedValue>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtDataAttemptedValue]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtDataAttemptedValue]s will have their `id` fields set.
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
  Future<List<CrdtDataAttemptedValue>> insert(
    _isd.DatabaseSession session,
    List<CrdtDataAttemptedValue> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtDataAttemptedValue>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtDataAttemptedValue] and returns the inserted row.
  ///
  /// The returned [CrdtDataAttemptedValue] will have its `id` field set.
  Future<CrdtDataAttemptedValue> insertRow(
    _isd.DatabaseSession session,
    CrdtDataAttemptedValue row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtDataAttemptedValue>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtDataAttemptedValue]s in the list and returns the resulting rows.
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
  /// The returned [CrdtDataAttemptedValue]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataAttemptedValue>> upsert(
    _isd.DatabaseSession session,
    List<CrdtDataAttemptedValue> rows, {
    required _isd.ColumnSelections<CrdtDataAttemptedValueTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataAttemptedValueTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtDataAttemptedValue>(
      rows,
      conflictColumns: conflictColumns(CrdtDataAttemptedValue.t),
      updateColumns: updateColumns?.call(CrdtDataAttemptedValue.t),
      updateWhere: updateWhere?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtDataAttemptedValue] and returns the resulting row.
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
  /// The returned [CrdtDataAttemptedValue] will have its `id` field set.
  Future<CrdtDataAttemptedValue?> upsertRow(
    _isd.DatabaseSession session,
    CrdtDataAttemptedValue row, {
    required _isd.ColumnSelections<CrdtDataAttemptedValueTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataAttemptedValueTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtDataAttemptedValue>(
      row,
      conflictColumns: conflictColumns(CrdtDataAttemptedValue.t),
      updateColumns: updateColumns?.call(CrdtDataAttemptedValue.t),
      updateWhere: updateWhere?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataAttemptedValue]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataAttemptedValue>> update(
    _isd.DatabaseSession session,
    List<CrdtDataAttemptedValue> rows, {
    _isd.ColumnSelections<CrdtDataAttemptedValueTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtDataAttemptedValue>(
      rows,
      columns: columns?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtDataAttemptedValue]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtDataAttemptedValue> updateRow(
    _isd.DatabaseSession session,
    CrdtDataAttemptedValue row, {
    _isd.ColumnSelections<CrdtDataAttemptedValueTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtDataAttemptedValue>(
      row,
      columns: columns?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtDataAttemptedValue] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtDataAttemptedValue?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtDataAttemptedValueUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtDataAttemptedValue>(
      id,
      columnValues: columnValues(CrdtDataAttemptedValue.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataAttemptedValue]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataAttemptedValue>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtDataAttemptedValueUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataAttemptedValue>(
      columnValues: columnValues(CrdtDataAttemptedValue.t.updateTable),
      where: where(CrdtDataAttemptedValue.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtDataAttemptedValue]s in the list and returns the deleted rows.
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
  Future<List<CrdtDataAttemptedValue>> delete(
    _isd.DatabaseSession session,
    List<CrdtDataAttemptedValue> rows, {
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataAttemptedValue>(
      rows,
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataAttemptedValue].
  Future<CrdtDataAttemptedValue> deleteRow(
    _isd.DatabaseSession session,
    CrdtDataAttemptedValue row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtDataAttemptedValue>(
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
  Future<List<CrdtDataAttemptedValue>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable> where,
    _isd.OrderByBuilder<CrdtDataAttemptedValueTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataAttemptedValueTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataAttemptedValue>(
      where: where(CrdtDataAttemptedValue.t),
      orderBy: orderBy?.call(CrdtDataAttemptedValue.t),
      orderByList: orderByList?.call(CrdtDataAttemptedValue.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataAttemptedValue>(
      where: where?.call(CrdtDataAttemptedValue.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataAttemptedValue] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataAttemptedValueTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtDataAttemptedValue>(
      where: where(CrdtDataAttemptedValue.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtDataAttemptedValueAttachRowRepository {
  const CrdtDataAttemptedValueAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataAttemptedValue] and [CrdtDataField]
  /// by setting the [CrdtDataAttemptedValue]'s foreign key `fieldId` to refer to the [CrdtDataField].
  Future<void> field(
    _isd.DatabaseSession session,
    CrdtDataAttemptedValue crdtDataAttemptedValue,
    _icw2tu00.CrdtDataField field, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtDataAttemptedValue.id == null) {
      throw ArgumentError.notNull('crdtDataAttemptedValue.id');
    }
    if (field.id == null) {
      throw ArgumentError.notNull('field.id');
    }

    var $crdtDataAttemptedValue = crdtDataAttemptedValue.copyWith(
      fieldId: field.id,
    );
    await session.db.updateRow<CrdtDataAttemptedValue>(
      $crdtDataAttemptedValue,
      columns: [CrdtDataAttemptedValue.t.fieldId],
      transaction: transaction,
    );
  }
}
