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
import 'address.dart' as _i3;
import 'organization.dart' as _i4;
import 'company.dart' as _i5;
import 'package:serverpod_offline_sync_test_client/src/protocol/protocol.dart'
    as _i6;

abstract class Person implements _i1.TableRow<_i2.UuidValue?> {
  Person._({
    this.id,
    this.scopeId,
    required this.name,
    this.surname,
    this.address,
    this.organizationId,
    this.organization,
    this.oldCompanyId,
    this.oldCompany,
  }) : _cityCitizensCityId = null;

  factory Person({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    String? surname,
    _i3.Address? address,
    _i2.UuidValue? organizationId,
    _i4.Organization? organization,
    _i2.UuidValue? oldCompanyId,
    _i5.Company? oldCompany,
  }) = _PersonImpl;

  factory Person.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonImplicit._(
      id: jsonSerialization['id'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      scopeId: jsonSerialization['scopeId'] as int?,
      name: jsonSerialization['name'] as String,
      surname: jsonSerialization['surname'] as String?,
      address: jsonSerialization['address'] == null
          ? null
          : _i6.Protocol().deserialize<_i3.Address>(
              jsonSerialization['address'],
            ),
      organizationId: jsonSerialization['organizationId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['organizationId'],
            ),
      organization: jsonSerialization['organization'] == null
          ? null
          : _i6.Protocol().deserialize<_i4.Organization>(
              jsonSerialization['organization'],
            ),
      oldCompanyId: jsonSerialization['oldCompanyId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['oldCompanyId'],
            ),
      oldCompany: jsonSerialization['oldCompany'] == null
          ? null
          : _i6.Protocol().deserialize<_i5.Company>(
              jsonSerialization['oldCompany'],
            ),
      $_cityCitizensCityId: jsonSerialization['_cityCitizensCityId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['_cityCitizensCityId'],
            ),
    );
  }

  static final t = PersonTable();

  static const db = PersonRepository._();

  @override
  _i2.UuidValue? id;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  int? scopeId;

  String name;

  String? surname;

  _i3.Address? address;

  _i2.UuidValue? organizationId;

  _i4.Organization? organization;

  _i2.UuidValue? oldCompanyId;

  _i5.Company? oldCompany;

  final _i2.UuidValue? _cityCitizensCityId;

  @override
  _i1.Table<_i2.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  Person copyWith({
    _i2.UuidValue? id,
    int? scopeId,
    String? name,
    String? surname,
    _i3.Address? address,
    _i2.UuidValue? organizationId,
    _i4.Organization? organization,
    _i2.UuidValue? oldCompanyId,
    _i5.Company? oldCompany,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Person',
      if (id != null) 'id': id?.toJson(),
      if (scopeId != null) 'scopeId': scopeId,
      'name': name,
      if (surname != null) 'surname': surname,
      if (address != null) 'address': address?.toJson(),
      if (organizationId != null) 'organizationId': organizationId?.toJson(),
      if (organization != null) 'organization': organization?.toJson(),
      if (oldCompanyId != null) 'oldCompanyId': oldCompanyId?.toJson(),
      if (oldCompany != null) 'oldCompany': oldCompany?.toJson(),
      if (_cityCitizensCityId != null)
        '_cityCitizensCityId': _cityCitizensCityId.toJson(),
    };
  }

  static PersonInclude include({
    _i3.AddressInclude? address,
    _i4.OrganizationInclude? organization,
    _i5.CompanyInclude? oldCompany,
  }) {
    return PersonInclude._(
      address: address,
      organization: organization,
      oldCompany: oldCompany,
    );
  }

  static PersonIncludeList includeList({
    _i1.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PersonTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    PersonInclude? include,
  }) {
    return PersonIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Person.t),
      orderDescending: // ignore: deprecated_member_use_from_same_package
          orderDescending,
      orderByList: orderByList?.call(Person.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonImpl extends Person {
  _PersonImpl({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    String? surname,
    _i3.Address? address,
    _i2.UuidValue? organizationId,
    _i4.Organization? organization,
    _i2.UuidValue? oldCompanyId,
    _i5.Company? oldCompany,
  }) : super._(
         id: id,
         scopeId: scopeId,
         name: name,
         surname: surname,
         address: address,
         organizationId: organizationId,
         organization: organization,
         oldCompanyId: oldCompanyId,
         oldCompany: oldCompany,
       );

  /// Returns a shallow copy of this [Person]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  Person copyWith({
    Object? id = _Undefined,
    Object? scopeId = _Undefined,
    String? name,
    Object? surname = _Undefined,
    Object? address = _Undefined,
    Object? organizationId = _Undefined,
    Object? organization = _Undefined,
    Object? oldCompanyId = _Undefined,
    Object? oldCompany = _Undefined,
  }) {
    return PersonImplicit._(
      id: id is _i2.UuidValue? ? id : this.id,
      scopeId: scopeId is int? ? scopeId : this.scopeId,
      name: name ?? this.name,
      surname: surname is String? ? surname : this.surname,
      address: address is _i3.Address? ? address : this.address?.copyWith(),
      organizationId: organizationId is _i2.UuidValue?
          ? organizationId
          : this.organizationId,
      organization: organization is _i4.Organization?
          ? organization
          : this.organization?.copyWith(),
      oldCompanyId: oldCompanyId is _i2.UuidValue?
          ? oldCompanyId
          : this.oldCompanyId,
      oldCompany: oldCompany is _i5.Company?
          ? oldCompany
          : this.oldCompany?.copyWith(),
      $_cityCitizensCityId: this._cityCitizensCityId,
    );
  }
}

class PersonImplicit extends _PersonImpl {
  PersonImplicit._({
    _i2.UuidValue? id,
    int? scopeId,
    required String name,
    String? surname,
    _i3.Address? address,
    _i2.UuidValue? organizationId,
    _i4.Organization? organization,
    _i2.UuidValue? oldCompanyId,
    _i5.Company? oldCompany,
    _i2.UuidValue? $_cityCitizensCityId,
  }) : _cityCitizensCityId = $_cityCitizensCityId,
       super(
         id: id,
         scopeId: scopeId,
         name: name,
         surname: surname,
         address: address,
         organizationId: organizationId,
         organization: organization,
         oldCompanyId: oldCompanyId,
         oldCompany: oldCompany,
       );

  factory PersonImplicit(
    Person person, {
    _i2.UuidValue? $_cityCitizensCityId,
  }) {
    return PersonImplicit._(
      id: person.id,
      scopeId: person.scopeId,
      name: person.name,
      surname: person.surname,
      address: person.address,
      organizationId: person.organizationId,
      organization: person.organization,
      oldCompanyId: person.oldCompanyId,
      oldCompany: person.oldCompany,
      $_cityCitizensCityId: $_cityCitizensCityId,
    );
  }

  @override
  final _i2.UuidValue? _cityCitizensCityId;
}

class PersonUpdateTable extends _i1.UpdateTable<PersonTable> {
  PersonUpdateTable(super.table);

  _i1.ColumnValue<int, int> scopeId(int? value) => _i1.ColumnValue(
    table.scopeId,
    value,
  );

  _i1.ColumnValue<String, String> name(String value) => _i1.ColumnValue(
    table.name,
    value,
  );

  _i1.ColumnValue<String, String> surname(String? value) => _i1.ColumnValue(
    table.surname,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> organizationId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.organizationId,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> oldCompanyId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.oldCompanyId,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> $_cityCitizensCityId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.$_cityCitizensCityId,
    value,
  );
}

class PersonTable extends _i1.Table<_i2.UuidValue?> {
  PersonTable({super.tableRelation}) : super(tableName: 'person') {
    updateTable = PersonUpdateTable(this);
    scopeId = _i1.ColumnInt(
      'scopeId',
      this,
    );
    name = _i1.ColumnString(
      'name',
      this,
    );
    surname = _i1.ColumnString(
      'surname',
      this,
    );
    organizationId = _i1.ColumnUuid(
      'organizationId',
      this,
    );
    oldCompanyId = _i1.ColumnUuid(
      'oldCompanyId',
      this,
    );
    $_cityCitizensCityId = _i1.ColumnUuid(
      '_cityCitizensCityId',
      this,
    );
  }

  late final PersonUpdateTable updateTable;

  /// Owner scope of this row. Maintained by the CRDT sync layer.
  late final _i1.ColumnInt scopeId;

  late final _i1.ColumnString name;

  late final _i1.ColumnString surname;

  _i3.AddressTable? _address;

  late final _i1.ColumnUuid organizationId;

  _i4.OrganizationTable? _organization;

  late final _i1.ColumnUuid oldCompanyId;

  _i5.CompanyTable? _oldCompany;

  late final _i1.ColumnUuid $_cityCitizensCityId;

  _i3.AddressTable get address {
    if (_address != null) return _address!;
    _address = _i1.createRelationTable(
      relationFieldName: 'address',
      field: Person.t.id,
      foreignField: _i3.Address.t.inhabitantId,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i3.AddressTable(tableRelation: foreignTableRelation),
    );
    return _address!;
  }

  _i4.OrganizationTable get organization {
    if (_organization != null) return _organization!;
    _organization = _i1.createRelationTable(
      relationFieldName: 'organization',
      field: Person.t.organizationId,
      foreignField: _i4.Organization.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i4.OrganizationTable(tableRelation: foreignTableRelation),
    );
    return _organization!;
  }

  _i5.CompanyTable get oldCompany {
    if (_oldCompany != null) return _oldCompany!;
    _oldCompany = _i1.createRelationTable(
      relationFieldName: 'oldCompany',
      field: Person.t.oldCompanyId,
      foreignField: _i5.Company.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i5.CompanyTable(tableRelation: foreignTableRelation),
    );
    return _oldCompany!;
  }

  @override
  List<_i1.Column> get columns => [
    id,
    scopeId,
    name,
    surname,
    organizationId,
    oldCompanyId,
    $_cityCitizensCityId,
  ];

  @override
  List<_i1.Column> get managedColumns => [
    id,
    scopeId,
    name,
    surname,
    organizationId,
    oldCompanyId,
  ];

  @override
  _i1.Table? getRelationTable(String relationField) {
    if (relationField == 'address') {
      return address;
    }
    if (relationField == 'organization') {
      return organization;
    }
    if (relationField == 'oldCompany') {
      return oldCompany;
    }
    return null;
  }
}

class PersonInclude extends _i1.IncludeObject {
  PersonInclude._({
    _i3.AddressInclude? address,
    _i4.OrganizationInclude? organization,
    _i5.CompanyInclude? oldCompany,
  }) {
    _address = address;
    _organization = organization;
    _oldCompany = oldCompany;
  }

  _i3.AddressInclude? _address;

  _i4.OrganizationInclude? _organization;

  _i5.CompanyInclude? _oldCompany;

  @override
  Map<String, _i1.Include?> get includes => {
    'address': _address,
    'organization': _organization,
    'oldCompany': _oldCompany,
  };

  @override
  _i1.Table<_i2.UuidValue?> get table => Person.t;
}

class PersonIncludeList extends _i1.IncludeList {
  PersonIncludeList._({
    _i1.WhereExpressionBuilder<PersonTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Person.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<_i2.UuidValue?> get table => Person.t;
}

class PersonRepository {
  const PersonRepository._();

  final attachRow = const PersonAttachRowRepository._();

  final detachRow = const PersonDetachRowRepository._();

  /// Returns a list of [Person]s matching the given query parameters.
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
  Future<List<Person>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PersonTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    _i1.Transaction? transaction,
    PersonInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Person>(
      where: where?.call(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
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

  /// Returns the first matching [Person] matching the given query parameters.
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
  Future<Person?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<PersonTable>? where,
    int? offset,
    _i1.OrderByBuilder<PersonTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    _i1.Transaction? transaction,
    PersonInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Person>(
      where: where?.call(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Person] by its [id] or null if no such row exists.
  Future<Person?> findById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    _i1.Transaction? transaction,
    PersonInclude? include,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Person>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Person]s in the list and returns the inserted rows.
  ///
  /// The returned [Person]s will have their `id` fields set.
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
  Future<List<Person>> insert(
    _i1.DatabaseSession session,
    List<Person> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Person>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Person] and returns the inserted row.
  ///
  /// The returned [Person] will have its `id` field set.
  Future<Person> insertRow(
    _i1.DatabaseSession session,
    Person row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Person>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Person]s in the list and returns the resulting rows.
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
  /// The returned [Person]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> upsert(
    _i1.DatabaseSession session,
    List<Person> rows, {
    required _i1.ColumnSelections<PersonTable> conflictColumns,
    _i1.ColumnSelections<PersonTable>? updateColumns,
    _i1.WhereExpressionBuilder<PersonTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Person>(
      rows,
      conflictColumns: conflictColumns(Person.t),
      updateColumns: updateColumns?.call(Person.t),
      updateWhere: updateWhere?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Person] and returns the resulting row.
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
  /// The returned [Person] will have its `id` field set.
  Future<Person?> upsertRow(
    _i1.DatabaseSession session,
    Person row, {
    required _i1.ColumnSelections<PersonTable> conflictColumns,
    _i1.ColumnSelections<PersonTable>? updateColumns,
    _i1.WhereExpressionBuilder<PersonTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Person>(
      row,
      conflictColumns: conflictColumns(Person.t),
      updateColumns: updateColumns?.call(Person.t),
      updateWhere: updateWhere?.call(Person.t),
      transaction: transaction,
    );
  }

  /// Updates all [Person]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> update(
    _i1.DatabaseSession session,
    List<Person> rows, {
    _i1.ColumnSelections<PersonTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Person>(
      rows,
      columns: columns?.call(Person.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Person]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Person> updateRow(
    _i1.DatabaseSession session,
    Person row, {
    _i1.ColumnSelections<PersonTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Person>(
      row,
      columns: columns?.call(Person.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Person] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Person?> updateById(
    _i1.DatabaseSession session,
    _i2.UuidValue id, {
    required _i1.ColumnValueListBuilder<PersonUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Person>(
      id,
      columnValues: columnValues(Person.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Person]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Person>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<PersonUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<PersonTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<PersonTable>? orderBy,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Person>(
      columnValues: columnValues(Person.t.updateTable),
      where: where(Person.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Person]s in the list and returns the deleted rows.
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
  Future<List<Person>> delete(
    _i1.DatabaseSession session,
    List<Person> rows, {
    _i1.OrderByBuilder<PersonTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Person>(
      rows,
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
      orderDescending: // ignore: deprecated_member_use
          orderDescending,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Person].
  Future<Person> deleteRow(
    _i1.DatabaseSession session,
    Person row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Person>(
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
  Future<List<Person>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<PersonTable> where,
    _i1.OrderByBuilder<PersonTable>? orderBy,
    @Deprecated('Use desc() on the orderBy column instead.')
    bool orderDescending = false,
    _i1.OrderByListBuilder<PersonTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Person>(
      where: where(Person.t),
      orderBy: orderBy?.call(Person.t),
      orderByList: orderByList?.call(Person.t),
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
    _i1.WhereExpressionBuilder<PersonTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Person>(
      where: where?.call(Person.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Person] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<PersonTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Person>(
      where: where(Person.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class PersonAttachRowRepository {
  const PersonAttachRowRepository._();

  /// Creates a relation between the given [Person] and [Address]
  /// by setting the [Person]'s foreign key `id` to refer to the [Address].
  Future<void> address(
    _i1.DatabaseSession session,
    Person person,
    _i3.Address address, {
    _i1.Transaction? transaction,
  }) async {
    if (address.id == null) {
      throw ArgumentError.notNull('address.id');
    }
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }

    var $address = address.copyWith(inhabitantId: person.id);
    await session.db.updateRow<_i3.Address>(
      $address,
      columns: [_i3.Address.t.inhabitantId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [Person] and [Organization]
  /// by setting the [Person]'s foreign key `organizationId` to refer to the [Organization].
  Future<void> organization(
    _i1.DatabaseSession session,
    Person person,
    _i4.Organization organization, {
    _i1.Transaction? transaction,
  }) async {
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }
    if (organization.id == null) {
      throw ArgumentError.notNull('organization.id');
    }

    var $person = person.copyWith(organizationId: organization.id);
    await session.db.updateRow<Person>(
      $person,
      columns: [Person.t.organizationId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [Person] and [Company]
  /// by setting the [Person]'s foreign key `oldCompanyId` to refer to the [Company].
  Future<void> oldCompany(
    _i1.DatabaseSession session,
    Person person,
    _i5.Company oldCompany, {
    _i1.Transaction? transaction,
  }) async {
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }
    if (oldCompany.id == null) {
      throw ArgumentError.notNull('oldCompany.id');
    }

    var $person = person.copyWith(oldCompanyId: oldCompany.id);
    await session.db.updateRow<Person>(
      $person,
      columns: [Person.t.oldCompanyId],
      transaction: transaction,
    );
  }
}

class PersonDetachRowRepository {
  const PersonDetachRowRepository._();

  /// Detaches the relation between this [Person] and the [Address] set in `address`
  /// by setting the [Person]'s foreign key `id` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> address(
    _i1.DatabaseSession session,
    Person person, {
    _i1.Transaction? transaction,
  }) async {
    var $address = person.address;

    if ($address == null) {
      throw ArgumentError.notNull('person.address');
    }
    if ($address.id == null) {
      throw ArgumentError.notNull('person.address.id');
    }
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }

    var $$address = $address.copyWith(inhabitantId: null);
    await session.db.updateRow<_i3.Address>(
      $$address,
      columns: [_i3.Address.t.inhabitantId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [Person] and the [Organization] set in `organization`
  /// by setting the [Person]'s foreign key `organizationId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> organization(
    _i1.DatabaseSession session,
    Person person, {
    _i1.Transaction? transaction,
  }) async {
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }

    var $person = person.copyWith(organizationId: null);
    await session.db.updateRow<Person>(
      $person,
      columns: [Person.t.organizationId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [Person] and the [Company] set in `oldCompany`
  /// by setting the [Person]'s foreign key `oldCompanyId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> oldCompany(
    _i1.DatabaseSession session,
    Person person, {
    _i1.Transaction? transaction,
  }) async {
    if (person.id == null) {
      throw ArgumentError.notNull('person.id');
    }

    var $person = person.copyWith(oldCompanyId: null);
    await session.db.updateRow<Person>(
      $person,
      columns: [Person.t.oldCompanyId],
      transaction: transaction,
    );
  }
}
