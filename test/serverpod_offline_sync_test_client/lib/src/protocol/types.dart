/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_database/serverpod_database.dart' as _i1;
import 'package:serverpod_client/serverpod_client.dart' as _i2;
import 'dart:typed_data' as _i3;
import 'types_enum.dart' as _i4;

abstract class Types implements _i1.TableRow<_i2.UuidValue?> {
  Types._({
    this.id,
    this.scopeId,
    required this.aBool,
    required this.aDateTime,
    required this.aText,
    required this.anInt,
    required this.anInt64,
    required this.aReal,
    required this.aBlob,
    this.anEnum,
    this.optionalText,
    this.optionalUuid,
  });

  factory Types({
    _i2.UuidValue? id,
    int? scopeId,
    required bool aBool,
    required DateTime aDateTime,
    required String aText,
    required int anInt,
    required BigInt anInt64,
    required double aReal,
    required _i3.ByteData aBlob,
    _i4.TypesEnum? anEnum,
    String? optionalText,
    _i2.UuidValue? optionalUuid,
  }) = _TypesImpl;

  factory Types.fromJson(Map<String, dynamic> jsonSerialization) {
    return Types(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      aBool: _i2.BoolJsonExtension.fromJson(jsonSerialization['aBool']),
      aDateTime: _i2.DateTimeJsonExtension.fromJson(
        jsonSerialization['aDateTime'],
      ),
      aText: jsonSerialization['aText'] as String,
      anInt: jsonSerialization['anInt'] as int,
      anInt64: _i2.BigIntJsonExtension.fromJson(jsonSerialization['anInt64']),
      aReal: (jsonSerialization['aReal'] as num).toDouble(),
      aBlob: _i2.ByteDataJsonExtension.fromJson(jsonSerialization['aBlob']),
      anEnum: jsonSerialization['anEnum'] == null
          ? null
          : _i4.TypesEnum.fromJson((jsonSerialization['anEnum'] as int)),
      optionalText: jsonSerialization['optionalText'] as String?,
      optionalUuid: jsonSerialization['optionalUuid'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['optionalUuid'],
            ),
    );
  }

  static final t = TypesTable();

  static const db = TypesRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  bool aBool;

  DateTime aDateTime;

  String aText;

  int anInt;

  BigInt anInt64;

  double aReal;

  _i3.ByteData aBlob;

  _i4.TypesEnum? anEnum;

  String? optionalText;

  _i2.UuidValue? optionalUuid;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Types]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  Types copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    bool? aBool,
    DateTime? aDateTime,
    String? aText,
    int? anInt,
    BigInt? anInt64,
    double? aReal,
    _i3.ByteData? aBlob,
    _i4.TypesEnum? anEnum,
    String? optionalText,
    _i2.UuidValue? optionalUuid,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Types',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'aBool': aBool,
      'aDateTime': aDateTime.toJson(),
      'aText': aText,
      'anInt': anInt,
      'anInt64': anInt64.toJson(),
      'aReal': aReal,
      'aBlob': aBlob.toJson(),
      if (anEnum != null) 'anEnum': anEnum?.toJson(),
      if (optionalText != null) 'optionalText': optionalText,
      if (optionalUuid != null) 'optionalUuid': optionalUuid?.toJson(),
    };
  }

  static TypesInclude include() {
    return TypesInclude._();
  }

  static TypesIncludeList includeList({
    _i1.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TypesTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    TypesInclude? include,
  }) {
    return TypesIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Types.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(Types.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TypesImpl extends Types {
  _TypesImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required bool aBool,
    required DateTime aDateTime,
    required String aText,
    required int anInt,
    required BigInt anInt64,
    required double aReal,
    required _i3.ByteData aBlob,
    _i4.TypesEnum? anEnum,
    String? optionalText,
    _i2.UuidValue? optionalUuid,
  }) : super._(
         id: id,
         scopeId: scopeId,
         aBool: aBool,
         aDateTime: aDateTime,
         aText: aText,
         anInt: anInt,
         anInt64: anInt64,
         aReal: aReal,
         aBlob: aBlob,
         anEnum: anEnum,
         optionalText: optionalText,
         optionalUuid: optionalUuid,
       );

  /// Returns a shallow copy of this [Types]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  Types copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    bool? aBool,
    DateTime? aDateTime,
    String? aText,
    int? anInt,
    BigInt? anInt64,
    double? aReal,
    _i3.ByteData? aBlob,
    Object? anEnum = _Undefined,
    Object? optionalText = _Undefined,
    Object? optionalUuid = _Undefined,
  }) {
    return Types(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      aBool: aBool ?? this.aBool,
      aDateTime: aDateTime ?? this.aDateTime,
      aText: aText ?? this.aText,
      anInt: anInt ?? this.anInt,
      anInt64: anInt64 ?? this.anInt64,
      aReal: aReal ?? this.aReal,
      aBlob: aBlob ?? this.aBlob.clone(),
      anEnum: anEnum is _i4.TypesEnum? ? anEnum : this.anEnum,
      optionalText: optionalText is String? ? optionalText : this.optionalText,
      optionalUuid: optionalUuid is _i2.UuidValue?
          ? optionalUuid
          : this.optionalUuid,
    );
  }
}

class TypesUpdateTable extends _i1.UpdateTable<TypesTable> {
  TypesUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<bool, bool> aBool(bool value) => _i1.ColumnValue(
    table.aBool,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> aDateTime(DateTime value) =>
      _i1.ColumnValue(
        table.aDateTime,
        value,
      );

  _i1.ColumnValue<String, String> aText(String value) => _i1.ColumnValue(
    table.aText,
    value,
  );

  _i1.ColumnValue<int, int> anInt(int value) => _i1.ColumnValue(
    table.anInt,
    value,
  );

  _i1.ColumnValue<BigInt, BigInt> anInt64(BigInt value) => _i1.ColumnValue(
    table.anInt64,
    value,
  );

  _i1.ColumnValue<double, double> aReal(double value) => _i1.ColumnValue(
    table.aReal,
    value,
  );

  _i1.ColumnValue<_i3.ByteData, _i3.ByteData> aBlob(_i3.ByteData value) =>
      _i1.ColumnValue(
        table.aBlob,
        value,
      );

  _i1.ColumnValue<_i4.TypesEnum, _i4.TypesEnum> anEnum(_i4.TypesEnum? value) =>
      _i1.ColumnValue(
        table.anEnum,
        value,
      );

  _i1.ColumnValue<String, String> optionalText(String? value) =>
      _i1.ColumnValue(
        table.optionalText,
        value,
      );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> optionalUuid(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.optionalUuid,
    value,
  );
}

class TypesTable extends _i1.Table<_i2.UuidValue?> {
  TypesTable({super.tableRelation}) : super(tableName: 'types') {
    updateTable = TypesUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    aBool = _i1.ColumnBool(
      'aBool',
      this,
    );
    aDateTime = _i1.ColumnDateTime(
      'aDateTime',
      this,
    );
    aText = _i1.ColumnString(
      'aText',
      this,
    );
    anInt = _i1.ColumnInt(
      'anInt',
      this,
    );
    anInt64 = _i1.ColumnBigInt(
      'anInt64',
      this,
    );
    aReal = _i1.ColumnDouble(
      'aReal',
      this,
    );
    aBlob = _i1.ColumnByteData(
      'aBlob',
      this,
    );
    anEnum = _i1.ColumnEnum(
      'anEnum',
      this,
      _i1.EnumSerialization.byIndex,
    );
    optionalText = _i1.ColumnString(
      'optionalText',
      this,
    );
    optionalUuid = _i1.ColumnUuid(
      'optionalUuid',
      this,
    );
  }

  late final TypesUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnBool aBool;

  late final _i1.ColumnDateTime aDateTime;

  late final _i1.ColumnString aText;

  late final _i1.ColumnInt anInt;

  late final _i1.ColumnBigInt anInt64;

  late final _i1.ColumnDouble aReal;

  late final _i1.ColumnByteData aBlob;

  late final _i1.ColumnEnum<_i4.TypesEnum> anEnum;

  late final _i1.ColumnString optionalText;

  late final _i1.ColumnUuid optionalUuid;

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    aBool,
    aDateTime,
    aText,
    anInt,
    anInt64,
    aReal,
    aBlob,
    anEnum,
    optionalText,
    optionalUuid,
  ];
}

class TypesInclude extends _i1.IncludeObject {
  TypesInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<_i2.UuidValue?> get table => Types.t;
}

class TypesIncludeList extends _i1.IncludeList {
  TypesIncludeList._({
    _i1.WhereExpressionBuilder<TypesTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Types.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => Types.t;
}

class TypesRepository {
  const TypesRepository._();

  /// Returns a list of [Types]s matching the given query parameters.
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
  Future<List<Types>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TypesTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Types>(
      where: where?.call(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Types] matching the given query parameters.
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
  Future<Types?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TypesTable>? where,
    int? offset,
    _i1.OrderByBuilder<TypesTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Types>(
      where: where?.call(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Types] by its [id] or null if no such row exists.
  Future<Types?> findById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Types>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Types]s in the list and returns the inserted rows.
  ///
  /// The returned [Types]s will have their `id` fields set.
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
  Future<List<Types>> insert(
    _i1.DatabaseSession session,
    List<Types> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Types>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Types] and returns the inserted row.
  ///
  /// The returned [Types] will have its `id` field set.
  Future<Types> insertRow(
    _i1.DatabaseSession session,
    Types row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Types>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Types]s in the list and returns the resulting rows.
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
  /// The returned [Types]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Types>> upsert(
    _i1.DatabaseSession session,
    List<Types> rows, {
    required _i1.ColumnSelections<TypesTable> conflictColumns,
    _i1.ColumnSelections<TypesTable>? updateColumns,
    _i1.WhereExpressionBuilder<TypesTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Types>(
      rows,
      conflictColumns: conflictColumns(Types.t),
      updateColumns: updateColumns?.call(Types.t),
      updateWhere: updateWhere?.call(Types.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Types] and returns the resulting row.
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
  /// The returned [Types] will have its `id` field set.
  Future<Types?> upsertRow(
    _i1.DatabaseSession session,
    Types row, {
    required _i1.ColumnSelections<TypesTable> conflictColumns,
    _i1.ColumnSelections<TypesTable>? updateColumns,
    _i1.WhereExpressionBuilder<TypesTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Types>(
      row,
      conflictColumns: conflictColumns(Types.t),
      updateColumns: updateColumns?.call(Types.t),
      updateWhere: updateWhere?.call(Types.t),
      transaction: transaction,
    );
  }

  /// Updates all [Types]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Types>> update(
    _i1.DatabaseSession session,
    List<Types> rows, {
    _i1.ColumnSelections<TypesTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Types>(
      rows,
      columns: columns?.call(Types.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Types]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Types> updateRow(
    _i1.DatabaseSession session,
    Types row, {
    _i1.ColumnSelections<TypesTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Types>(
      row,
      columns: columns?.call(Types.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Types] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Types?> updateById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<TypesUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Types>(
      id,
      columnValues: columnValues(Types.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Types]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Types>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<TypesUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<TypesTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TypesTable>? orderBy,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Types>(
      columnValues: columnValues(Types.t.updateTable),
      where: where(Types.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Types]s in the list and returns the deleted rows.
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
  Future<List<Types>> delete(
    _i1.DatabaseSession session,
    List<Types> rows, {
    _i1.OrderByBuilder<TypesTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Types>(
      rows,
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Types].
  Future<Types> deleteRow(
    _i1.DatabaseSession session,
    Types row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Types>(
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
  Future<List<Types>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TypesTable> where,
    _i1.OrderByBuilder<TypesTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<TypesTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Types>(
      where: where(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
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
    _i1.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Types>(
      where: where?.call(Types.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Types] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TypesTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Types>(
      where: where(Types.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
