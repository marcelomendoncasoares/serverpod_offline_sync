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
import '../data/field.dart' as _i2;
import 'package:serverpod_client/serverpod_client.dart' as _i3;
import '../data/foreign_key_override_reason.dart' as _i4;
import 'package:serverpod_offline_sync_client/src/protocol/protocol.dart'
    as _i5;

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
abstract class CrdtDataForeignKey implements _i1.TableRow<int?> {
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
    _i2.CrdtDataField? field,
    required int fieldId,
    required _i3.UuidValue? attemptedValue,
    _i3.UuidValue? visibleValue,
    _i4.CrdtForeignKeyOverrideReason? overrideReason,
  }) = _CrdtDataForeignKeyImpl;

  factory CrdtDataForeignKey.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtDataForeignKey(
      id: jsonSerialization['id'] as int?,
      field: jsonSerialization['field'] == null
          ? null
          : _i5.Protocol().deserialize<_i2.CrdtDataField>(
              jsonSerialization['field'],
            ),
      fieldId: jsonSerialization['fieldId'] as int,
      attemptedValue: jsonSerialization['attemptedValue'] == null
          ? null
          : _i3.UuidValueJsonExtension.fromJson(
              jsonSerialization['attemptedValue'],
            ),
      visibleValue: jsonSerialization['visibleValue'] == null
          ? null
          : _i3.UuidValueJsonExtension.fromJson(
              jsonSerialization['visibleValue'],
            ),
      overrideReason: jsonSerialization['overrideReason'] == null
          ? null
          : _i4.CrdtForeignKeyOverrideReason.fromJson(
              (jsonSerialization['overrideReason'] as int),
            ),
    );
  }

  static final t = CrdtDataForeignKeyTable();

  static const db = CrdtDataForeignKeyRepository._();

  @override
  int? id;

  /// The field that the foreign key belongs to.
  _i2.CrdtDataField? field;

  int fieldId;

  /// The user-attempted foreign key value that the CRDT field currently carries.
  ///
  /// This may be null for nullable foreign keys. This is durable FK field-value
  /// storage for CRDT columns whose CrdtDataField row stores only HLC metadata.
  _i3.UuidValue? attemptedValue;

  /// The foreign key value that is currently visible in the actual data row
  /// when an override is active (overrideReason is non-null).
  _i3.UuidValue? visibleValue;

  /// The authoritative indicator and reason for an active projection override.
  ///
  /// This is the single source of truth for whether an override is active:
  /// non-null means an override is active; null means no override. It also
  /// names the cause of the override. The FK resolver recomputes it from merged
  /// row, field, and tombstone facts.
  _i4.CrdtForeignKeyOverrideReason? overrideReason;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtDataForeignKey]
  /// with some or all fields replaced by the given arguments.
  @_i3.useResult
  CrdtDataForeignKey copyWith({
    int? id,
    _i2.CrdtDataField? field,
    int? fieldId,
    _i3.UuidValue? attemptedValue,
    _i3.UuidValue? visibleValue,
    _i4.CrdtForeignKeyOverrideReason? overrideReason,
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

  static CrdtDataForeignKeyInclude include({_i2.CrdtDataFieldInclude? field}) {
    return CrdtDataForeignKeyInclude._(field: field);
  }

  static CrdtDataForeignKeyIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    CrdtDataForeignKeyInclude? include,
  }) {
    return CrdtDataForeignKeyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i3.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtDataForeignKeyImpl extends CrdtDataForeignKey {
  _CrdtDataForeignKeyImpl({
    int? id,
    _i2.CrdtDataField? field,
    required int fieldId,
    required _i3.UuidValue? attemptedValue,
    _i3.UuidValue? visibleValue,
    _i4.CrdtForeignKeyOverrideReason? overrideReason,
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
  @_i3.useResult
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
      field: field is _i2.CrdtDataField? ? field : this.field?.copyWith(),
      fieldId: fieldId ?? this.fieldId,
      attemptedValue: attemptedValue is _i3.UuidValue?
          ? attemptedValue
          : this.attemptedValue,
      visibleValue: visibleValue is _i3.UuidValue?
          ? visibleValue
          : this.visibleValue,
      overrideReason: overrideReason is _i4.CrdtForeignKeyOverrideReason?
          ? overrideReason
          : this.overrideReason,
    );
  }
}

class CrdtDataForeignKeyUpdateTable
    extends _i1.UpdateTable<CrdtDataForeignKeyTable> {
  CrdtDataForeignKeyUpdateTable(super.table);

  _i1.ColumnValue<int, int> fieldId(int value) => _i1.ColumnValue(
    table.fieldId,
    value,
  );

  _i1.ColumnValue<_i3.UuidValue, _i3.UuidValue> attemptedValue(
    _i3.UuidValue? value,
  ) => _i1.ColumnValue(
    table.attemptedValue,
    value,
  );

  _i1.ColumnValue<_i3.UuidValue, _i3.UuidValue> visibleValue(
    _i3.UuidValue? value,
  ) => _i1.ColumnValue(
    table.visibleValue,
    value,
  );

  _i1.ColumnValue<
    _i4.CrdtForeignKeyOverrideReason,
    _i4.CrdtForeignKeyOverrideReason
  >
  overrideReason(_i4.CrdtForeignKeyOverrideReason? value) => _i1.ColumnValue(
    table.overrideReason,
    value,
  );
}

class CrdtDataForeignKeyTable extends _i1.Table<int?> {
  CrdtDataForeignKeyTable({super.tableRelation})
    : super(tableName: 'crdt_data_foreign_key') {
    updateTable = CrdtDataForeignKeyUpdateTable(this);
    fieldId = _i1.ColumnInt(
      'fieldId',
      this,
    );
    attemptedValue = _i1.ColumnUuid(
      'attemptedValue',
      this,
    );
    visibleValue = _i1.ColumnUuid(
      'visibleValue',
      this,
    );
    overrideReason = _i1.ColumnEnum(
      'overrideReason',
      this,
      _i1.EnumSerialization.byIndex,
    );
  }

  late final CrdtDataForeignKeyUpdateTable updateTable;

  /// The field that the foreign key belongs to.
  _i2.CrdtDataFieldTable? _field;

  late final _i1.ColumnInt fieldId;

  /// The user-attempted foreign key value that the CRDT field currently carries.
  ///
  /// This may be null for nullable foreign keys. This is durable FK field-value
  /// storage for CRDT columns whose CrdtDataField row stores only HLC metadata.
  late final _i1.ColumnUuid attemptedValue;

  /// The foreign key value that is currently visible in the actual data row
  /// when an override is active (overrideReason is non-null).
  late final _i1.ColumnUuid visibleValue;

  /// The authoritative indicator and reason for an active projection override.
  ///
  /// This is the single source of truth for whether an override is active:
  /// non-null means an override is active; null means no override. It also
  /// names the cause of the override. The FK resolver recomputes it from merged
  /// row, field, and tombstone facts.
  late final _i1.ColumnEnum<_i4.CrdtForeignKeyOverrideReason> overrideReason;

  _i2.CrdtDataFieldTable get field {
    if (_field != null) return _field!;
    _field = _i1.createRelationTable(
      relationFieldName: 'field',
      field: CrdtDataForeignKey.t.fieldId,
      foreignField: _i2.CrdtDataField.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.CrdtDataFieldTable(tableRelation: foreignTableRelation),
    );
    return _field!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    fieldId,
    attemptedValue,
    visibleValue,
    overrideReason,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'field') {
      return field;
    }
    return null;
  }
}

class CrdtDataForeignKeyInclude extends _i1.IncludeObject {
  CrdtDataForeignKeyInclude._({_i2.CrdtDataFieldInclude? field}) {
    _field = field;
  }

  _i2.CrdtDataFieldInclude? _field;

  @override
  Map<String, _i1.Include?> get includes => {'field': _field};

  @override
  _i1.Table<int?> get table => CrdtDataForeignKey.t;
}

class CrdtDataForeignKeyIncludeList extends _i1.IncludeList {
  CrdtDataForeignKeyIncludeList._({
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtDataForeignKey.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtDataForeignKey.t;
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _i1.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtDataForeignKey] by its [id] or null if no such row exists.
  Future<CrdtDataForeignKey?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    CrdtDataForeignKeyInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
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
    _i1.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtDataForeignKey row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    required _i1.ColumnSelections<CrdtDataForeignKeyTable> conflictColumns,
    _i1.ColumnSelections<CrdtDataForeignKeyTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtDataForeignKey row, {
    required _i1.ColumnSelections<CrdtDataForeignKeyTable> conflictColumns,
    _i1.ColumnSelections<CrdtDataForeignKeyTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? updateWhere,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _i1.ColumnSelections<CrdtDataForeignKeyTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    CrdtDataForeignKey row, {
    _i1.ColumnSelections<CrdtDataForeignKeyTable>? columns,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtDataForeignKeyUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtDataForeignKeyUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtDataForeignKey>(
      columnValues: columnValues(CrdtDataForeignKey.t.updateTable),
      where: where(CrdtDataForeignKey.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
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
    _i1.DatabaseSession session,
    List<CrdtDataForeignKey> rows, {
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtDataForeignKey>(
      rows,
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtDataForeignKey].
  Future<CrdtDataForeignKey> deleteRow(
    _i1.DatabaseSession session,
    CrdtDataForeignKey row, {
    _i1.Transaction? transaction,
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
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    _i1.OrderByBuilder<CrdtDataForeignKeyTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<CrdtDataForeignKeyTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtDataForeignKey>(
      where: where(CrdtDataForeignKey.t),
      orderBy: orderBy?.call(CrdtDataForeignKey.t),
      orderByList: orderByList?.call(CrdtDataForeignKey.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtDataForeignKey>(
      where: where?.call(CrdtDataForeignKey.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtDataForeignKey] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtDataForeignKeyTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
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
    _i1.DatabaseSession session,
    CrdtDataForeignKey crdtDataForeignKey,
    _i2.CrdtDataField field, {
    _i1.Transaction? transaction,
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
