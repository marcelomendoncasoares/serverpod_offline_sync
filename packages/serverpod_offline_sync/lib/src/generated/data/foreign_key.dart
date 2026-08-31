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

/// CRDT field foreign key value and projection table.
///
/// This table stores the user/attempted foreign key value for a CRDT field and
/// the materialized foreign key projection for that value. CrdtDataField stores
/// only HLC metadata, so FK columns store their durable attempted value here.
///
/// Repairs must be recomputable from merged CRDT row, field, and tombstone
/// facts plus this attempted FK value. The projection columns record what was
/// materialized into the domain row; they do not decide business semantics or
/// create user field updates during merge.
abstract class CrdtDataForeignKey
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
  CrdtDataForeignKey._({
    this.id,
    this.field,
    required this.fieldId,
    required this.attemptedValue,
    this.visibleValue,
    this.overrideReason,
  });

  factory CrdtDataForeignKey({
    int? id,
    _icw2tu00.CrdtDataField? field,
    required int fieldId,
    required _iss.UuidValue? attemptedValue,
    _iss.UuidValue? visibleValue,
    _icw2tu00.CrdtForeignKeyOverrideReason? overrideReason,
  }) = _CrdtDataForeignKeyImpl;

  factory CrdtDataForeignKey.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataForeignKey(
      id: jsonSerialization['id'] as int?,
      field: jsonSerialization['field'] == null
          ? null
          : _icw2tu00.Protocol().deserialize<_icw2tu00.CrdtDataField>(
              jsonSerialization['field'],
            ),
      fieldId: jsonSerialization['fieldId'] as int,
      attemptedValue: jsonSerialization['attemptedValue'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['attemptedValue'],
            ),
      visibleValue: jsonSerialization['visibleValue'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['visibleValue'],
            ),
      overrideReason: jsonSerialization['overrideReason'] == null
          ? null
          : _icw2tu00.CrdtForeignKeyOverrideReason.fromJson(
              (jsonSerialization['overrideReason'] as int),
            ),
    );
  }

  static final t = CrdtDataForeignKeyTable();

  static const db = CrdtDataForeignKeyRepository._();

  @override
  int? id;

  /// The field that the foreign key belongs to.
  _icw2tu00.CrdtDataField? field;

  int fieldId;

  /// The user-attempted foreign key value that the CRDT field currently carries.
  ///
  /// This may be null for nullable foreign keys. This is durable FK field-value
  /// storage for CRDT columns whose CrdtDataField row stores only HLC metadata.
  _iss.UuidValue? attemptedValue;

  /// The foreign key value that is currently visible in the actual data row
  /// when an override is active (overrideReason is non-null).
  _iss.UuidValue? visibleValue;

  /// The authoritative indicator and reason for an active projection override.
  ///
  /// This is the single source of truth for whether an override is active:
  /// non-null means an override is active; null means no override. It also
  /// names the cause of the override. The FK resolver recomputes it from merged
  /// row, field, and tombstone facts.
  _icw2tu00.CrdtForeignKeyOverrideReason? overrideReason;

  @override
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataForeignKey]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtDataForeignKey copyWith({
    int? id,
    _icw2tu00.CrdtDataField? field,
    int? fieldId,
    _iss.UuidValue? attemptedValue,
    _iss.UuidValue? visibleValue,
    _icw2tu00.CrdtForeignKeyOverrideReason? overrideReason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataForeignKey',
      if (id != null) 'id': id,
      if (field != null) 'field': field?.toJson(),
      'fieldId': fieldId,
      if (attemptedValue != null) 'attemptedValue': attemptedValue?.toJson(),
      if (visibleValue != null) 'visibleValue': visibleValue?.toJson(),
      if (overrideReason != null) 'overrideReason': overrideReason?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtDataForeignKey',
      if (id != null) 'id': id,
      if (field != null) 'field': field?.toJsonForProtocol(),
      'fieldId': fieldId,
      if (attemptedValue != null) 'attemptedValue': attemptedValue?.toJson(),
      if (visibleValue != null) 'visibleValue': visibleValue?.toJson(),
      if (overrideReason != null) 'overrideReason': overrideReason?.toJson(),
    };
  }

  static CrdtDataForeignKeyInclude include({
    _icw2tu00.CrdtDataFieldInclude? field,
  }) {
    return CrdtDataForeignKeyInclude._(field: field);
  }

  static CrdtDataForeignKeyIncludeList includeList({
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    CrdtDataForeignKeyInclude? include,
  }) {
    return CrdtDataForeignKeyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataForeignKeyImpl extends CrdtDataForeignKey {
  _CrdtDataForeignKeyImpl({
    int? id,
    _icw2tu00.CrdtDataField? field,
    required int fieldId,
    required _iss.UuidValue? attemptedValue,
    _iss.UuidValue? visibleValue,
    _icw2tu00.CrdtForeignKeyOverrideReason? overrideReason,
  }) : super._(
         id: id,
         field: field,
         fieldId: fieldId,
         attemptedValue: attemptedValue,
         visibleValue: visibleValue,
         overrideReason: overrideReason,
       );

  /// Returns a shallow copy of this [CrdtDataForeignKey]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtDataForeignKey copyWith({
    Object? id = _Undefined,
    Object? field = _Undefined,
    int? fieldId,
    Object? attemptedValue = _Undefined,
    Object? visibleValue = _Undefined,
    Object? overrideReason = _Undefined,
  }) {
    return CrdtDataForeignKey(
      id: id is int? ? id : this.id,
      field: field is _icw2tu00.CrdtDataField? ? field : this.field?.copyWith(),
      fieldId: fieldId ?? this.fieldId,
      attemptedValue: attemptedValue is _iss.UuidValue?
          ? attemptedValue
          : this.attemptedValue,
      visibleValue: visibleValue is _iss.UuidValue?
          ? visibleValue
          : this.visibleValue,
      overrideReason: overrideReason is _icw2tu00.CrdtForeignKeyOverrideReason?
          ? overrideReason
          : this.overrideReason,
    );
  }
}

class CrdtDataForeignKeyUpdateTable
    extends _isd.UpdateTable<CrdtDataForeignKeyTable> {
  CrdtDataForeignKeyUpdateTable(super.table);

  _isd.ColumnValue<int, int> fieldId(int value) => _isd.ColumnValue(
    table.fieldId,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> attemptedValue(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(
    table.attemptedValue,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> visibleValue(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(
    table.visibleValue,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.CrdtForeignKeyOverrideReason,
    _icw2tu00.CrdtForeignKeyOverrideReason
  >
  overrideReason(_icw2tu00.CrdtForeignKeyOverrideReason? value) =>
      _isd.ColumnValue(
        table.overrideReason,
        value,
      );
}

class CrdtDataForeignKeyTable extends _isd.Table<int?> {
  CrdtDataForeignKeyTable({super.tableRelation})
    : super(tableName: 'crdt_data_foreign_key') {
    updateTable = CrdtDataForeignKeyUpdateTable(this);
    fieldId = _isd.ColumnInt(
      'fieldId',
      this,
    );
    attemptedValue = _isd.ColumnUuid(
      'attemptedValue',
      this,
    );
    visibleValue = _isd.ColumnUuid(
      'visibleValue',
      this,
    );
    overrideReason = _isd.ColumnEnum(
      'overrideReason',
      this,
      _isd.EnumSerialization.byIndex,
    );
  }

  late final CrdtDataForeignKeyUpdateTable updateTable;

  /// The field that the foreign key belongs to.
  _icw2tu00.CrdtDataFieldTable? _field;

  late final _isd.ColumnInt fieldId;

  /// The user-attempted foreign key value that the CRDT field currently carries.
  ///
  /// This may be null for nullable foreign keys. This is durable FK field-value
  /// storage for CRDT columns whose CrdtDataField row stores only HLC metadata.
  late final _isd.ColumnUuid attemptedValue;

  /// The foreign key value that is currently visible in the actual data row
  /// when an override is active (overrideReason is non-null).
  late final _isd.ColumnUuid visibleValue;

  /// The authoritative indicator and reason for an active projection override.
  ///
  /// This is the single source of truth for whether an override is active:
  /// non-null means an override is active; null means no override. It also
  /// names the cause of the override. The FK resolver recomputes it from merged
  /// row, field, and tombstone facts.
  late final _isd.ColumnEnum<_icw2tu00.CrdtForeignKeyOverrideReason>
  overrideReason;

  _icw2tu00.CrdtDataFieldTable get field {
    if (_field != null) return _field!;
    _field = _isd.createRelationTable(
      relationFieldName: 'field',
      field: CrdtDataForeignKey.t.fieldId,
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
    attemptedValue,
    visibleValue,
    overrideReason,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'field') {
      return field;
    }
    return null;
  }
}

class CrdtDataForeignKeyInclude extends _isd.IncludeObject {
  CrdtDataForeignKeyInclude._({_icw2tu00.CrdtDataFieldInclude? field}) {
    _field = field;
  }

  _icw2tu00.CrdtDataFieldInclude? _field;

  @override
  Map<String, _isd.Include?> get includes => {'field': _field};

  @override
  _isd.Table<int?> get table => CrdtDataForeignKey.t;
}

class CrdtDataForeignKeyIncludeList extends _isd.IncludeList {
  CrdtDataForeignKeyIncludeList._({
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataForeignKey.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtDataForeignKey.t;
}

class CrdtDataForeignKeyRepository {
  const CrdtDataForeignKeyRepository._();

  final attachRow = const CrdtDataForeignKeyAttachRowRepository._();

  /// Returns a list of [CrdtDataForeignKey]s matching the given query parameters.
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
  Future<List<CrdtDataForeignKey>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtDataForeignKey] matching the given query parameters.
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
  Future<CrdtDataForeignKey?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _isd.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataForeignKey] by its [id] or null if no such row exists.
  Future<CrdtDataForeignKey?> findById(
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtDataForeignKey>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtDataForeignKey]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtDataForeignKey]s will have their `id` fields set.
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
  Future<List<CrdtDataForeignKey>> insert(
    _isd.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtDataForeignKey>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtDataForeignKey] and returns the inserted row.
  ///
  /// The returned [CrdtDataForeignKey] will have its `id` field set.
  Future<CrdtDataForeignKey> insertRow(
    _isd.DatabaseSession session,
    CrdtDataForeignKey row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtDataForeignKey>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtDataForeignKey]s in the list and returns the resulting rows.
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
  /// The returned [CrdtDataForeignKey]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataForeignKey>> upsert(
    _isd.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    required _isd.ColumnSelections<CrdtDataForeignKeyTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataForeignKeyTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtDataForeignKey>(
      rows,
      conflictColumns: conflictColumns(CrdtDataForeignKey.t),
      updateColumns: updateColumns?.call(CrdtDataForeignKey.t),
      updateWhere: updateWhere?.call(CrdtDataForeignKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtDataForeignKey] and returns the resulting row.
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
  /// The returned [CrdtDataForeignKey] will have its `id` field set.
  Future<CrdtDataForeignKey?> upsertRow(
    _isd.DatabaseSession session,
    CrdtDataForeignKey row, {
    required _isd.ColumnSelections<CrdtDataForeignKeyTable> conflictColumns,
    _isd.ColumnSelections<CrdtDataForeignKeyTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtDataForeignKey>(
      row,
      conflictColumns: conflictColumns(CrdtDataForeignKey.t),
      updateColumns: updateColumns?.call(CrdtDataForeignKey.t),
      updateWhere: updateWhere?.call(CrdtDataForeignKey.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataForeignKey]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataForeignKey>> update(
    _isd.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _isd.ColumnSelections<CrdtDataForeignKeyTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtDataForeignKey>(
      rows,
      columns: columns?.call(CrdtDataForeignKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtDataForeignKey]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtDataForeignKey> updateRow(
    _isd.DatabaseSession session,
    CrdtDataForeignKey row, {
    _isd.ColumnSelections<CrdtDataForeignKeyTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtDataForeignKey>(
      row,
      columns: columns?.call(CrdtDataForeignKey.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtDataForeignKey] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtDataForeignKey?> updateById(
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtDataForeignKeyUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtDataForeignKey>(
      id,
      columnValues: columnValues(CrdtDataForeignKey.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtDataForeignKey]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtDataForeignKey>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtDataForeignKeyUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataForeignKey>(
      columnValues: columnValues(CrdtDataForeignKey.t.updateTable),
      where: where(CrdtDataForeignKey.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtDataForeignKey]s in the list and returns the deleted rows.
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
  Future<List<CrdtDataForeignKey>> delete(
    _isd.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataForeignKey>(
      rows,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataForeignKey].
  Future<CrdtDataForeignKey> deleteRow(
    _isd.DatabaseSession session,
    CrdtDataForeignKey row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtDataForeignKey>(
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
  Future<List<CrdtDataForeignKey>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    _isd.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _isd.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataForeignKey>(
      where: where(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataForeignKey] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtDataForeignKey>(
      where: where(CrdtDataForeignKey.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CrdtDataForeignKeyAttachRowRepository {
  const CrdtDataForeignKeyAttachRowRepository._();

  /// Creates a relation between the given [CrdtDataForeignKey] and [CrdtDataField]
  /// by setting the [CrdtDataForeignKey]'s foreign key `fieldId` to refer to the [CrdtDataField].
  Future<void> field(
    _isd.DatabaseSession session,
    CrdtDataForeignKey crdtDataForeignKey,
    _icw2tu00.CrdtDataField field, {
    _isd.Transaction? transaction,
  }) async {
    if (crdtDataForeignKey.id == null) {
      throw ArgumentError.notNull('crdtDataForeignKey.id');
    }
    if (field.id == null) {
      throw ArgumentError.notNull('field.id');
    }

    var $crdtDataForeignKey = crdtDataForeignKey.copyWith(fieldId: field.id);
    await session.db.updateRow<CrdtDataForeignKey>(
      $crdtDataForeignKey,
      columns: [CrdtDataForeignKey.t.fieldId],
      transaction: transaction,
    );
  }
}
