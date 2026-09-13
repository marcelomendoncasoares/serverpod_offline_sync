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
import 'dart:typed_data' as _idt;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as _ixxccm81;
import 'sync_document.dart' as _ix6xayzv;
import 'types.dart' as _iwxwszsz;
import 'types_enum.dart' as _ire5m5mj;

abstract class Types
    implements _is.TableRow<_is.UuidValue?>, _is.ProtocolSerialization {
  Types._({
    this.id,
    this.spaceId,
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
    this.parentId,
    this.parent,
    this.jsonDocument,
    this.jsonbDocument,
    this.jsonbNumbers,
  });

  factory Types({
    _is.UuidValue? id,
    int? spaceId,
    required bool aBool,
    required DateTime aDateTime,
    required String aText,
    required int anInt,
    required BigInt anInt64,
    required double aReal,
    required _idt.ByteData aBlob,
    _ire5m5mj.TypesEnum? anEnum,
    String? optionalText,
    _is.UuidValue? optionalUuid,
    _is.UuidValue? parentId,
    _iwxwszsz.Types? parent,
    _ix6xayzv.SyncDocument? jsonDocument,
    _ix6xayzv.SyncDocument? jsonbDocument,
    List<int>? jsonbNumbers,
  }) = _TypesImpl;

  factory Types.fromJson(Map<String, dynamic> jsonSerialization) {
    return Types(
      id: jsonSerialization['id'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      aBool: _is.BoolJsonExtension.fromJson(jsonSerialization['aBool']),
      aDateTime: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['aDateTime'],
      ),
      aText: jsonSerialization['aText'] as String,
      anInt: jsonSerialization['anInt'] as int,
      anInt64: _is.BigIntJsonExtension.fromJson(jsonSerialization['anInt64']),
      aReal: (jsonSerialization['aReal'] as num).toDouble(),
      aBlob: _is.ByteDataJsonExtension.fromJson(jsonSerialization['aBlob']),
      anEnum: jsonSerialization['anEnum'] == null
          ? null
          : _ire5m5mj.TypesEnum.fromJson((jsonSerialization['anEnum'] as int)),
      optionalText: jsonSerialization['optionalText'] as String?,
      optionalUuid: jsonSerialization['optionalUuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['optionalUuid'],
            ),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_iwxwszsz.Types>(
              jsonSerialization['parent'],
            ),
      jsonDocument: jsonSerialization['jsonDocument'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_ix6xayzv.SyncDocument>(
              jsonSerialization['jsonDocument'],
            ),
      jsonbDocument: jsonSerialization['jsonbDocument'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<_ix6xayzv.SyncDocument>(
              jsonSerialization['jsonbDocument'],
            ),
      jsonbNumbers: jsonSerialization['jsonbNumbers'] == null
          ? null
          : _ixxccm81.Protocol().deserialize<List<int>>(
              jsonSerialization['jsonbNumbers'],
            ),
    );
  }

  static final t = TypesTable();

  static const db = TypesRepository._();

  @override
  _is.UuidValue? id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  bool aBool;

  DateTime aDateTime;

  String aText;

  int anInt;

  BigInt anInt64;

  double aReal;

  _idt.ByteData aBlob;

  _ire5m5mj.TypesEnum? anEnum;

  String? optionalText;

  _is.UuidValue? optionalUuid;

  _is.UuidValue? parentId;

  _iwxwszsz.Types? parent;

  _ix6xayzv.SyncDocument? jsonDocument;

  _ix6xayzv.SyncDocument? jsonbDocument;

  List<int>? jsonbNumbers;

  @override
  _is.Table<_is.UuidValue?> get table => t;

  /// Returns a shallow copy of this [Types]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Types copyWith({
    _is.UuidValue? id,
    int? spaceId,
    bool? aBool,
    DateTime? aDateTime,
    String? aText,
    int? anInt,
    BigInt? anInt64,
    double? aReal,
    _idt.ByteData? aBlob,
    _ire5m5mj.TypesEnum? anEnum,
    String? optionalText,
    _is.UuidValue? optionalUuid,
    _is.UuidValue? parentId,
    _iwxwszsz.Types? parent,
    _ix6xayzv.SyncDocument? jsonDocument,
    _ix6xayzv.SyncDocument? jsonbDocument,
    List<int>? jsonbNumbers,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Types',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
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
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
      if (jsonDocument != null) 'jsonDocument': jsonDocument?.toJson(),
      if (jsonbDocument != null) 'jsonbDocument': jsonbDocument?.toJson(),
      if (jsonbNumbers != null) 'jsonbNumbers': jsonbNumbers?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Types',
      if (id != null) 'id': id?.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
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
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
      if (jsonDocument != null)
        'jsonDocument': jsonDocument?.toJsonForProtocol(),
      if (jsonbDocument != null)
        'jsonbDocument': jsonbDocument?.toJsonForProtocol(),
      if (jsonbNumbers != null) 'jsonbNumbers': jsonbNumbers?.toJson(),
    };
  }

  static TypesInclude include({_iwxwszsz.TypesInclude? parent}) {
    return TypesInclude._(parent: parent);
  }

  static TypesIncludeList includeList({
    _is.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    TypesInclude? include,
  }) {
    return TypesIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TypesImpl extends Types {
  _TypesImpl({
    _is.UuidValue? id,
    int? spaceId,
    required bool aBool,
    required DateTime aDateTime,
    required String aText,
    required int anInt,
    required BigInt anInt64,
    required double aReal,
    required _idt.ByteData aBlob,
    _ire5m5mj.TypesEnum? anEnum,
    String? optionalText,
    _is.UuidValue? optionalUuid,
    _is.UuidValue? parentId,
    _iwxwszsz.Types? parent,
    _ix6xayzv.SyncDocument? jsonDocument,
    _ix6xayzv.SyncDocument? jsonbDocument,
    List<int>? jsonbNumbers,
  }) : super._(
         id: id,
         spaceId: spaceId,
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
         parentId: parentId,
         parent: parent,
         jsonDocument: jsonDocument,
         jsonbDocument: jsonbDocument,
         jsonbNumbers: jsonbNumbers,
       );

  /// Returns a shallow copy of this [Types]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Types copyWith({
    Object? id = _Undefined,
    Object? spaceId = _Undefined,
    bool? aBool,
    DateTime? aDateTime,
    String? aText,
    int? anInt,
    BigInt? anInt64,
    double? aReal,
    _idt.ByteData? aBlob,
    Object? anEnum = _Undefined,
    Object? optionalText = _Undefined,
    Object? optionalUuid = _Undefined,
    Object? parentId = _Undefined,
    Object? parent = _Undefined,
    Object? jsonDocument = _Undefined,
    Object? jsonbDocument = _Undefined,
    Object? jsonbNumbers = _Undefined,
  }) {
    return Types(
      id: id is _is.UuidValue? ? id : this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      aBool: aBool ?? this.aBool,
      aDateTime: aDateTime ?? this.aDateTime,
      aText: aText ?? this.aText,
      anInt: anInt ?? this.anInt,
      anInt64: anInt64 ?? this.anInt64,
      aReal: aReal ?? this.aReal,
      aBlob: aBlob ?? this.aBlob.clone(),
      anEnum: anEnum is _ire5m5mj.TypesEnum? ? anEnum : this.anEnum,
      optionalText: optionalText is String? ? optionalText : this.optionalText,
      optionalUuid: optionalUuid is _is.UuidValue?
          ? optionalUuid
          : this.optionalUuid,
      parentId: parentId is _is.UuidValue? ? parentId : this.parentId,
      parent: parent is _iwxwszsz.Types? ? parent : this.parent?.copyWith(),
      jsonDocument: jsonDocument is _ix6xayzv.SyncDocument?
          ? jsonDocument
          : this.jsonDocument?.copyWith(),
      jsonbDocument: jsonbDocument is _ix6xayzv.SyncDocument?
          ? jsonbDocument
          : this.jsonbDocument?.copyWith(),
      jsonbNumbers: jsonbNumbers is List<int>?
          ? jsonbNumbers
          : this.jsonbNumbers?.map((e0) => e0).toList(),
    );
  }
}

class TypesUpdateTable extends _is.UpdateTable<TypesTable> {
  TypesUpdateTable(super.table);

  _is.ColumnValue<int, int> spaceId(int? value) => _is.ColumnValue(
    table.spaceId,
    value,
  );

  _is.ColumnValue<bool, bool> aBool(bool value) => _is.ColumnValue(
    table.aBool,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> aDateTime(DateTime value) =>
      _is.ColumnValue(
        table.aDateTime,
        value,
      );

  _is.ColumnValue<String, String> aText(String value) => _is.ColumnValue(
    table.aText,
    value,
  );

  _is.ColumnValue<int, int> anInt(int value) => _is.ColumnValue(
    table.anInt,
    value,
  );

  _is.ColumnValue<BigInt, BigInt> anInt64(BigInt value) => _is.ColumnValue(
    table.anInt64,
    value,
  );

  _is.ColumnValue<double, double> aReal(double value) => _is.ColumnValue(
    table.aReal,
    value,
  );

  _is.ColumnValue<_idt.ByteData, _idt.ByteData> aBlob(_idt.ByteData value) =>
      _is.ColumnValue(
        table.aBlob,
        value,
      );

  _is.ColumnValue<_ire5m5mj.TypesEnum, _ire5m5mj.TypesEnum> anEnum(
    _ire5m5mj.TypesEnum? value,
  ) => _is.ColumnValue(
    table.anEnum,
    value,
  );

  _is.ColumnValue<String, String> optionalText(String? value) =>
      _is.ColumnValue(
        table.optionalText,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> optionalUuid(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.optionalUuid,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> parentId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.parentId,
    value,
  );

  _is.ColumnValue<_ix6xayzv.SyncDocument, _ix6xayzv.SyncDocument> jsonDocument(
    _ix6xayzv.SyncDocument? value,
  ) => _is.ColumnValue(
    table.jsonDocument,
    value,
  );

  _is.ColumnValue<_ix6xayzv.SyncDocument, _ix6xayzv.SyncDocument> jsonbDocument(
    _ix6xayzv.SyncDocument? value,
  ) => _is.ColumnValue(
    table.jsonbDocument,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> jsonbNumbers(List<int>? value) =>
      _is.ColumnValue(
        table.jsonbNumbers,
        value,
      );
}

class TypesTable extends _is.Table<_is.UuidValue?> {
  TypesTable({super.tableRelation}) : super(tableName: 'types') {
    updateTable = TypesUpdateTable(this);
    spaceId = _is.ColumnInt(
      'spaceId',
      this,
    );
    aBool = _is.ColumnBool(
      'aBool',
      this,
    );
    aDateTime = _is.ColumnDateTime(
      'aDateTime',
      this,
    );
    aText = _is.ColumnString(
      'aText',
      this,
    );
    anInt = _is.ColumnInt(
      'anInt',
      this,
    );
    anInt64 = _is.ColumnBigInt(
      'anInt64',
      this,
    );
    aReal = _is.ColumnDouble(
      'aReal',
      this,
    );
    aBlob = _is.ColumnByteData(
      'aBlob',
      this,
    );
    anEnum = _is.ColumnEnum(
      'anEnum',
      this,
      _is.EnumSerialization.byIndex,
    );
    optionalText = _is.ColumnString(
      'optionalText',
      this,
    );
    optionalUuid = _is.ColumnUuid(
      'optionalUuid',
      this,
    );
    parentId = _is.ColumnUuid(
      'parentId',
      this,
    );
    jsonDocument = _is.ColumnSerializable<_ix6xayzv.SyncDocument>(
      'jsonDocument',
      this,
    );
    jsonbDocument = _is.ColumnStructured<_ix6xayzv.SyncDocument>(
      'jsonbDocument',
      this,
    );
    jsonbNumbers = _is.ColumnStructured<List<int>>(
      'jsonbNumbers',
      this,
    );
  }

  late final TypesUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _is.ColumnInt spaceId;

  late final _is.ColumnBool aBool;

  late final _is.ColumnDateTime aDateTime;

  late final _is.ColumnString aText;

  late final _is.ColumnInt anInt;

  late final _is.ColumnBigInt anInt64;

  late final _is.ColumnDouble aReal;

  late final _is.ColumnByteData aBlob;

  late final _is.ColumnEnum<_ire5m5mj.TypesEnum> anEnum;

  late final _is.ColumnString optionalText;

  late final _is.ColumnUuid optionalUuid;

  late final _is.ColumnUuid parentId;

  _iwxwszsz.TypesTable? _parent;

  late final _is.ColumnSerializable<_ix6xayzv.SyncDocument> jsonDocument;

  late final _is.ColumnStructured<_ix6xayzv.SyncDocument> jsonbDocument;

  late final _is.ColumnStructured<List<int>> jsonbNumbers;

  _iwxwszsz.TypesTable get parent {
    if (_parent != null) return _parent!;
    _parent = _is.createRelationTable(
      relationFieldName: 'parent',
      field: Types.t.parentId,
      foreignField: _iwxwszsz.Types.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _iwxwszsz.TypesTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_is.Column> get columns => [
    id,
    spaceId,
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
    parentId,
    jsonDocument,
    jsonbDocument,
    jsonbNumbers,
  ];

  @override
  _is.Table? getRelationTable(String relationField) {
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class TypesInclude extends _is.IncludeObject {
  TypesInclude._({_iwxwszsz.TypesInclude? parent}) {
    _parent = parent;
  }

  _iwxwszsz.TypesInclude? _parent;

  @override
  Map<String, _is.Include?> get includes => {'parent': _parent};

  @override
  _is.Table<_is.UuidValue?> get table => Types.t;
}

class TypesIncludeList extends _is.IncludeList {
  TypesIncludeList._({
    _is.WhereExpressionBuilder<TypesTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Types.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<_is.UuidValue?> get table => Types.t;
}

class TypesRepository {
  const TypesRepository._();

  final attachRow = const TypesAttachRowRepository._();

  final detachRow = const TypesDetachRowRepository._();

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
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    _is.Transaction? transaction,
    TypesInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Types>(
      where: where?.call(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
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
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TypesTable>? where,
    int? offset,
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    _is.Transaction? transaction,
    TypesInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Types>(
      where: where?.call(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Types] by its [id] or null if no such row exists.
  Future<Types?> findById(
    _is.DatabaseSession session,
    _is.UuidValue id, {
    _is.Transaction? transaction,
    TypesInclude? include,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Types>(
      id,
      transaction: transaction,
      include: include,
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
    _is.DatabaseSession session,
    List<Types> rows, {
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    Types row, {
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    List<Types> rows, {
    required _is.ColumnSelections<TypesTable> conflictColumns,
    _is.ColumnSelections<TypesTable>? updateColumns,
    _is.WhereExpressionBuilder<TypesTable>? updateWhere,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    Types row, {
    required _is.ColumnSelections<TypesTable> conflictColumns,
    _is.ColumnSelections<TypesTable>? updateColumns,
    _is.WhereExpressionBuilder<TypesTable>? updateWhere,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    List<Types> rows, {
    _is.ColumnSelections<TypesTable>? columns,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    Types row, {
    _is.ColumnSelections<TypesTable>? columns,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session,
    _is.UuidValue id, {
    required _is.ColumnValueListBuilder<TypesUpdateTable> columnValues,
    _is.Transaction? transaction,
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
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<TypesUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<TypesTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Types>(
      columnValues: columnValues(Types.t.updateTable),
      where: where(Types.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
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
    _is.DatabaseSession session,
    List<Types> rows, {
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Types>(
      rows,
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Types].
  Future<Types> deleteRow(
    _is.DatabaseSession session,
    Types row, {
    _is.Transaction? transaction,
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
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TypesTable> where,
    _is.OrderByBuilder<TypesTable>? orderBy,
    _is.OrderByListBuilder<TypesTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Types>(
      where: where(Types.t),
      orderBy: orderBy?.call(Types.t),
      orderByList: orderByList?.call(Types.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<TypesTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Types>(
      where: where?.call(Types.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Types] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<TypesTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Types>(
      where: where(Types.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class TypesAttachRowRepository {
  const TypesAttachRowRepository._();

  /// Creates a relation between the given [Types] and [Types]
  /// by setting the [Types]'s foreign key `parentId` to refer to the [Types].
  Future<void> parent(
    _is.DatabaseSession session,
    Types types,
    _iwxwszsz.Types parent, {
    _is.Transaction? transaction,
  }) async {
    if (types.id == null) {
      throw ArgumentError.notNull('types.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $types = types.copyWith(parentId: parent.id);
    await session.db.updateRow<Types>(
      $types,
      columns: [Types.t.parentId],
      transaction: transaction,
    );
  }
}

class TypesDetachRowRepository {
  const TypesDetachRowRepository._();

  /// Detaches the relation between this [Types] and the [Types] set in `parent`
  /// by setting the [Types]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _is.DatabaseSession session,
    Types types, {
    _is.Transaction? transaction,
  }) async {
    if (types.id == null) {
      throw ArgumentError.notNull('types.id');
    }

    var $types = types.copyWith(parentId: null);
    await session.db.updateRow<Types>(
      $types,
      columns: [Types.t.parentId],
      transaction: transaction,
    );
  }
}
