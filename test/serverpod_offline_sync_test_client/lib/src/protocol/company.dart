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
import 'town.dart' as _iytblq2r;

abstract class Company
    implements _isd.TableRow<_isc.UuidValue?>, _isc.ProtocolSerialization {
  Company._({
    this.id,
    this.scopeId,
    required this.name,
    this.town,
    _isc.UuidValue? townId,
  }) : townId =
           townId ??
           _isc.UuidValue.fromString('550e8400-e29b-41d4-a716-446655440000');

  factory Company({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iytblq2r.Town? town,
    _isc.UuidValue? townId,
  }) = _CompanyImpl;

  factory Company.fromJson(Map<String, dynamic> jsonSerialization) {
    return Company(
      id: jsonSerialization['id'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      town: jsonSerialization['town'] == null
          ? null
          : _imkb9kra.Protocol().deserialize<_iytblq2r.Town>(
              jsonSerialization['town'],
            ),
      townId: jsonSerialization['townId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['townId']),
    );
  }

  static final t = CompanyTable();

  static const db = CompanyRepository._();

  @override
  _isc.UuidValue? id;

  /// The scope owning this row. Maintained by the sync engine.
  int? scopeId;

  String name;

  _iytblq2r.Town? town;

  _isc.UuidValue townId;

  @override
  _isd.Table<_isc.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Company]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Company copyWith({
    _isc.UuidValue? id,
    int? scopeId,
    String? name,
    _iytblq2r.Town? town,
    _isc.UuidValue? townId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Company',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (town != null) 'town': town?.toJson(),
      'townId': townId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Company',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (town != null) 'town': town?.toJsonForProtocol(),
      'townId': townId.toJson(),
    };
  }

  static CompanyInclude include({_iytblq2r.TownInclude? town}) {
    return CompanyInclude._(town: town);
  }

  static CompanyIncludeList includeList({
    _isd.WhereExpressionBuilder<CompanyTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    CompanyInclude? include,
  }) {
    return CompanyIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CompanyImpl extends Company {
  _CompanyImpl({
    _isc.UuidValue? id,
    int? scopeId,
    required String name,
    _iytblq2r.Town? town,
    _isc.UuidValue? townId,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         town: town,
         townId: townId,
       );

  /// Returns a shallow copy of this [Company]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Company copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? town = _Undefined,
    _isc.UuidValue? townId,
  }) {
    return Company(
      id: id is _isc.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      town: town is _iytblq2r.Town? ? town : this.town?.copyWith(),
      townId: townId ?? this.townId,
    );
  }
}

class CompanyUpdateTable extends _isd.UpdateTable<CompanyTable> {
  CompanyUpdateTable(super.table);

  _isd.ColumnValue<int, int> scopeId(int? value) => _isd.ColumnValue(
    table.scopeId,
    value,
  );

  _isd.ColumnValue<String, String> name(String value) => _isd.ColumnValue(
    table.name,
    value,
  );

  _isd.ColumnValue<_isc.UuidValue, _isc.UuidValue> townId(
    _isc.UuidValue value,
  ) => _isd.ColumnValue(
    table.townId,
    value,
  );
}

class CompanyTable extends _isd.Table<_isc.UuidValue?> {
  CompanyTable({super.tableRelation}) : super(tableName: 'company') {
    updateTable = CompanyUpdateTable(this);
    scopeId = _isd.ColumnInt(
      'scopeId',
      this,
    );
    name = _isd.ColumnString(
      'name',
      this,
    );
    townId = _isd.ColumnUuid(
      'townId',
      this,
      hasDefault: true,
    );
  }

  late final CompanyUpdateTable updateTable;

  /// The scope owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt scopeId;

  late final _isd.ColumnString name;

  _iytblq2r.TownTable? _town;

  late final _isd.ColumnUuid townId;

  _iytblq2r.TownTable get town {
    if (_town != null) return _town!;
    _town = _isd.createRelationTable(
      relationFieldName: 'town',
      field: Company.t.townId,
      foreignField: _iytblq2r.Town.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iytblq2r.TownTable(tableRelation: foreignTableRelation),
    );
    return _town!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    scopeId,
    name,
    townId,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'town') {
      return town;
    }
    return null;
  }
}

class CompanyInclude extends _isd.IncludeObject {
  CompanyInclude._({_iytblq2r.TownInclude? town}) {
    _town = town;
  }

  _iytblq2r.TownInclude? _town;

  @override
  Map<String, _isd.Include?> get includes => {'town': _town};

  @override
  _isd.Table<_isc.UuidValue?> get table => Company.t;
}

class CompanyIncludeList extends _isd.IncludeList {
  CompanyIncludeList._({
    _isd.WhereExpressionBuilder<CompanyTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Company.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_isc.UuidValue?> get table => Company.t;
}

class CompanyRepository {
  const CompanyRepository._();

  final attachRow = const CompanyAttachRowRepository._();

  /// Returns a list of [Company]s matching the given query parameters.
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
  Future<List<Company>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CompanyTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    _isd.Transaction? transaction,
    CompanyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Company>(
      where: where?.call(Company.t),
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Company] matching the given query parameters.
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
  Future<Company?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CompanyTable>? where,
    int? offset,
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    _isd.Transaction? transaction,
    CompanyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Company>(
      where: where?.call(Company.t),
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Company] by its [id] or null if no such row exists.
  Future<Company?> findById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    _isd.Transaction? transaction,
    CompanyInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Company>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Company]s in the list and returns the inserted rows.
  ///
  /// The returned [Company]s will have their `id` fields set.
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
  Future<List<Company>> insert(
    _isd.DatabaseSession session,
    List<Company> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Company>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Company] and returns the inserted row.
  ///
  /// The returned [Company] will have its `id` field set.
  Future<Company> insertRow(
    _isd.DatabaseSession session,
    Company row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Company>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Company]s in the list and returns the resulting rows.
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
  /// The returned [Company]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Company>> upsert(
    _isd.DatabaseSession session,
    List<Company> rows, {
    required _isd.ColumnSelections<CompanyTable> conflictColumns,
    _isd.ColumnSelections<CompanyTable>? updateColumns,
    _isd.WhereExpressionBuilder<CompanyTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Company>(
      rows,
      conflictColumns: conflictColumns(Company.t),
      updateColumns: updateColumns?.call(Company.t),
      updateWhere: updateWhere?.call(Company.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Company] and returns the resulting row.
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
  /// The returned [Company] will have its `id` field set.
  Future<Company?> upsertRow(
    _isd.DatabaseSession session,
    Company row, {
    required _isd.ColumnSelections<CompanyTable> conflictColumns,
    _isd.ColumnSelections<CompanyTable>? updateColumns,
    _isd.WhereExpressionBuilder<CompanyTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Company>(
      row,
      conflictColumns: conflictColumns(Company.t),
      updateColumns: updateColumns?.call(Company.t),
      updateWhere: updateWhere?.call(Company.t),
      transaction: transaction,
    );
  }

  /// Updates all [Company]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Company>> update(
    _isd.DatabaseSession session,
    List<Company> rows, {
    _isd.ColumnSelections<CompanyTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Company>(
      rows,
      columns: columns?.call(Company.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Company]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Company> updateRow(
    _isd.DatabaseSession session,
    Company row, {
    _isd.ColumnSelections<CompanyTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Company>(
      row,
      columns: columns?.call(Company.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Company] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Company?> updateById(
    _isd.DatabaseSession session,
    _isc.UuidValue id, {
    required _isd.ColumnValueListBuilder<CompanyUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Company>(
      id,
      columnValues: columnValues(Company.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Company]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Company>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CompanyUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<CompanyTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Company>(
      columnValues: columnValues(Company.t.updateTable),
      where: where(Company.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Company]s in the list and returns the deleted rows.
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
  Future<List<Company>> delete(
    _isd.DatabaseSession session,
    List<Company> rows, {
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Company>(
      rows,
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Company].
  Future<Company> deleteRow(
    _isd.DatabaseSession session,
    Company row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Company>(
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
  Future<List<Company>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CompanyTable> where,
    _isd.OrderByBuilder<CompanyTable>? orderBy,
    _isd.OrderByListBuilder<CompanyTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Company>(
      where: where(Company.t),
      orderBy: orderBy?.call(Company.t),
      orderByList: orderByList?.call(Company.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CompanyTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Company>(
      where: where?.call(Company.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Company] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CompanyTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Company>(
      where: where(Company.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class CompanyAttachRowRepository {
  const CompanyAttachRowRepository._();

  /// Creates a relation between the given [Company] and [Town]
  /// by setting the [Company]'s foreign key `townId` to refer to the [Town].
  Future<void> town(
    _isd.DatabaseSession session,
    Company company,
    _iytblq2r.Town town, {
    _isd.Transaction? transaction,
  }) async {
    if (company.id == null) {
      throw ArgumentError.notNull('company.id');
    }
    if (town.id == null) {
      throw ArgumentError.notNull('town.id');
    }

    var $company = company.copyWith(townId: town.id);
    await session.db.updateRow<Company>(
      $company,
      columns: [Company.t.townId],
      transaction: transaction,
    );
  }
}
