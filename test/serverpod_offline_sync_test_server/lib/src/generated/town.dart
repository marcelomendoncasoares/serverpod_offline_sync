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
import 'package:serverpod/serverpod.dart' as _i1;
import 'city.dart' as _i2;
import 'person.dart' as _i3;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _i4;

abstract class Town
    implements _i1.TableRow<_i1.UuidValue?>, _i1.ProtocolSerialization {
  Town._({
    this.id,
    this.scopeId,
    required this.name,
    this.cityId,
    this.city,
    this.mayorId,
    this.mayor,
  });

  factory Town({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i1.UuidValue? cityId,
    _i2.City? city,
    _i1.UuidValue? mayorId,
    _i3.Person? mayor,
  }) = _TownImpl;

  factory Town.fromJson(Map<String, dynamic> jsonSerialization) {
    return Town(
      id: jsonSerialization['id'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      cityId: jsonSerialization['cityId'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['cityId']),
      city: jsonSerialization['city'] == null
          ? null
          : _i4.Protocol().deserialize<_i2.City>(jsonSerialization['city']),
      mayorId: jsonSerialization['mayorId'] == null
          ? null
          : _i1.UuidValueJsonExtension.fromJson(jsonSerialization['mayorId']),
      mayor: jsonSerialization['mayor'] == null
          ? null
          : _i4.Protocol().deserialize<_i3.Person>(jsonSerialization['mayor']),
    );
  }

  static final t = TownTable();

  static const db = TownRepository._();

  @override
  _i1.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  _i1.UuidValue? cityId;

  _i2.City? city;

  _i1.UuidValue? mayorId;

  _i3.Person? mayor;

  @override
  _i1.Table<_i1.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Town]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Town copyWith({
    _i1.UuidValue? id,
    int? scopeId,
    String? name,
    _i1.UuidValue? cityId,
    _i2.City? city,
    _i1.UuidValue? mayorId,
    _i3.Person? mayor,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Town',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cityId != null) 'cityId': cityId?.toJson(),
      if (city != null) 'city': city?.toJson(),
      if (mayorId != null) 'mayorId': mayorId?.toJson(),
      if (mayor != null) 'mayor': mayor?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Town',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (cityId != null) 'cityId': cityId?.toJson(),
      if (city != null) 'city': city?.toJsonForProtocol(),
      if (mayorId != null) 'mayorId': mayorId?.toJson(),
      if (mayor != null) 'mayor': mayor?.toJsonForProtocol(),
    };
  }

  static TownInclude include({
    _i2.CityInclude? city,
    _i3.PersonInclude? mayor,
  }) {
    return TownInclude._(
      city: city,
      mayor: mayor,
    );
  }

  static TownIncludeList includeList({
    _i1.WhereExpressionBuilder<TownTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    TownInclude? include,
  }) {
    return TownIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TownImpl extends Town {
  _TownImpl({
    _i1.UuidValue? id,
    int? scopeId,
    required String name,
    _i1.UuidValue? cityId,
    _i2.City? city,
    _i1.UuidValue? mayorId,
    _i3.Person? mayor,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         cityId: cityId,
         city: city,
         mayorId: mayorId,
         mayor: mayor,
       );

  /// Returns a shallow copy of this [Town]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Town copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? cityId = _Undefined,
    Object? city = _Undefined,
    Object? mayorId = _Undefined,
    Object? mayor = _Undefined,
  }) {
    return Town(
      id: id is _i1.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      cityId: cityId is _i1.UuidValue? ? cityId : this.cityId,
      city: city is _i2.City? ? city : this.city?.copyWith(),
      mayorId: mayorId is _i1.UuidValue? ? mayorId : this.mayorId,
      mayor: mayor is _i3.Person? ? mayor : this.mayor?.copyWith(),
    );
  }
}

class TownUpdateTable extends _i1.UpdateTable<TownTable> {
  TownUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> cityId(_i1.UuidValue? value) =>
      _i1.ColumnValue(
        table.cityId,
        value,
      );

  _i1.ColumnValue<_i1.UuidValue, _i1.UuidValue> mayorId(_i1.UuidValue? value) =>
      _i1.ColumnValue(
        table.mayorId,
        value,
      );
}

class TownTable extends _i1.Table<_i1.UuidValue?> {
  TownTable({super.tableRelation}) : super(tableName: 'town') {
    updateTable = TownUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    cityId = _i1.ColumnUuid(
      'cityId',
      this,
    );
    mayorId = _i1.ColumnUuid(
      'mayorId',
      this,
    );
  }

  late final TownUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  late final _i1.ColumnUuid cityId;

  _i2.CityTable? _city;

  late final _i1.ColumnUuid mayorId;

  _i3.PersonTable? _mayor;

  _i2.CityTable get city {
    if (_city != null) return _city!;
    _city = _i1.createRelationTable(
      relationFieldName: 'city',
      field: Town.t.cityId,
      foreignField: _i2.City.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i2.CityTable(tableRelation: foreignTableRelation),
    );
    return _city!;
  }

  _i3.PersonTable get mayor {
    if (_mayor != null) return _mayor!;
    _mayor = _i1.createRelationTable(
      relationFieldName: 'mayor',
      field: Town.t.mayorId,
      foreignField: _i3.Person.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.PersonTable(tableRelation: foreignTableRelation),
    );
    return _mayor!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    cityId,
    mayorId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'city') {
      return city;
    }
    if (relationField == 'mayor') {
      return mayor;
    }
    return null;
  }
}

class TownInclude extends _i1.IncludeObject {
  TownInclude._({
    _i2.CityInclude? city,
    _i3.PersonInclude? mayor,
  }) {
    _city = city;
    _mayor = mayor;
  }

  _i2.CityInclude? _city;

  _i3.PersonInclude? _mayor;

  @override
  Map<String, _i1.Include?> get includes => {
    'city': _city,
    'mayor': _mayor,
  };

  @override
  _i1.Table<_i1.UuidValue?> get table => Town.t;
}

class TownIncludeList extends _i1.IncludeList {
  TownIncludeList._({
    _i1.WhereExpressionBuilder<TownTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Town.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i1.UuidValue?> get table => Town.t;
}

class TownRepository {
  const TownRepository._();

  final attachRow = const TownAttachRowRepository._();

  final detachRow = const TownDetachRowRepository._();

  /// Returns a list of [Town]s matching the given query parameters.
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
  Future<List<Town>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TownTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    _i1.Transaction? transaction,
    TownInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Town>(
      where: where?.call(Town.t),
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Town] matching the given query parameters.
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
  Future<Town?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TownTable>? where,
    int? offset,
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    _i1.Transaction? transaction,
    TownInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Town>(
      where: where?.call(Town.t),
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Town] by its [id] or null if no such row exists.
  Future<Town?> findById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    _i1.Transaction? transaction,
    TownInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Town>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Town]s in the list and returns the inserted rows.
  ///
  /// The returned [Town]s will have their `id` fields set.
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
  Future<List<Town>> insert(
    _i1.DatabaseSession session,
    List<Town> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Town>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Town] and returns the inserted row.
  ///
  /// The returned [Town] will have its `id` field set.
  Future<Town> insertRow(
    _i1.DatabaseSession session,
    Town row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Town>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Town]s in the list and returns the resulting rows.
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
  /// The returned [Town]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Town>> upsert(
    _i1.DatabaseSession session,
    List<Town> rows, {
    required _i1.ColumnSelections<TownTable> conflictColumns,
    _i1.ColumnSelections<TownTable>? updateColumns,
    _i1.WhereExpressionBuilder<TownTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Town>(
      rows,
      conflictColumns: conflictColumns(Town.t),
      updateColumns: updateColumns?.call(Town.t),
      updateWhere: updateWhere?.call(Town.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Town] and returns the resulting row.
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
  /// The returned [Town] will have its `id` field set.
  Future<Town?> upsertRow(
    _i1.DatabaseSession session,
    Town row, {
    required _i1.ColumnSelections<TownTable> conflictColumns,
    _i1.ColumnSelections<TownTable>? updateColumns,
    _i1.WhereExpressionBuilder<TownTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Town>(
      row,
      conflictColumns: conflictColumns(Town.t),
      updateColumns: updateColumns?.call(Town.t),
      updateWhere: updateWhere?.call(Town.t),
      transaction: transaction,
    );
  }

  /// Updates all [Town]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Town>> update(
    _i1.DatabaseSession session,
    List<Town> rows, {
    _i1.ColumnSelections<TownTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Town>(
      rows,
      columns: columns?.call(Town.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Town]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Town> updateRow(
    _i1.DatabaseSession session,
    Town row, {
    _i1.ColumnSelections<TownTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Town>(
      row,
      columns: columns?.call(Town.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Town] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Town?> updateById(
    _i1.DatabaseSession session,
    _i1.UuidValue id, {
    required _i1.ColumnValueListBuilder<TownUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Town>(
      id,
      columnValues: columnValues(Town.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Town]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Town>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<TownUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<TownTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Town>(
      columnValues: columnValues(Town.t.updateTable),
      where: where(Town.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Town]s in the list and returns the deleted rows.
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
  Future<List<Town>> delete(
    _i1.DatabaseSession session,
    List<Town> rows, {
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Town>(
      rows,
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Town].
  Future<Town> deleteRow(
    _i1.DatabaseSession session,
    Town row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Town>(
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
  Future<List<Town>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TownTable> where,
    _i1.OrderByBuilder<TownTable>? orderBy,
    _i1.OrderByListBuilder<TownTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Town>(
      where: where(Town.t),
      orderBy: orderBy?.call(Town.t),
      orderByList: orderByList?.call(Town.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<TownTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Town>(
      where: where?.call(Town.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Town] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<TownTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Town>(
      where: where(Town.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class TownAttachRowRepository {
  const TownAttachRowRepository._();

  /// Creates a relation between the given [Town] and [City]
  /// by setting the [Town]'s foreign key `cityId` to refer to the [City].
  Future<void> city(
    _i1.DatabaseSession session,
    Town town,
    _i2.City city, {
    _i1.Transaction? transaction,
  }) async {
    if (town.id == null) {
      throw ArgumentError.notNull('town.id');
    }
    if (city.id == null) {
      throw ArgumentError.notNull('city.id');
    }

    var $town = town.copyWith(cityId: city.id);
    await session.db.updateRow<Town>(
      $town,
      columns: [Town.t.cityId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [Town] and [Person]
  /// by setting the [Town]'s foreign key `mayorId` to refer to the [Person].
  Future<void> mayor(
    _i1.DatabaseSession session,
    Town town,
    _i3.Person mayor, {
    _i1.Transaction? transaction,
  }) async {
    if (town.id == null) {
      throw ArgumentError.notNull('town.id');
    }
    if (mayor.id == null) {
      throw ArgumentError.notNull('mayor.id');
    }

    var $town = town.copyWith(mayorId: mayor.id);
    await session.db.updateRow<Town>(
      $town,
      columns: [Town.t.mayorId],
      transaction: transaction,
    );
  }
}

class TownDetachRowRepository {
  const TownDetachRowRepository._();

  /// Detaches the relation between this [Town] and the [City] set in `city`
  /// by setting the [Town]'s foreign key `cityId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> city(
    _i1.DatabaseSession session,
    Town town, {
    _i1.Transaction? transaction,
  }) async {
    if (town.id == null) {
      throw ArgumentError.notNull('town.id');
    }

    var $town = town.copyWith(cityId: null);
    await session.db.updateRow<Town>(
      $town,
      columns: [Town.t.cityId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [Town] and the [Person] set in `mayor`
  /// by setting the [Town]'s foreign key `mayorId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> mayor(
    _i1.DatabaseSession session,
    Town town, {
    _i1.Transaction? transaction,
  }) async {
    if (town.id == null) {
      throw ArgumentError.notNull('town.id');
    }

    var $town = town.copyWith(mayorId: null);
    await session.db.updateRow<Town>(
      $town,
      columns: [Town.t.mayorId],
      transaction: transaction,
    );
  }
}
