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
import 'package:serverpod_serialization/serverpod_serialization.dart' as _i2;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart' as _i3;

/// Durable record of a terminal CRDT sync integrity violation.
///
/// These rows are sparse diagnostic state. They record observed corruption or
/// hostile input without duplicating hot CRDT indexes.
///
/// All identifiers are denormalized UUIDs and names so the record remains
/// useful after merge rollbacks and across databases that do not share the
/// same local CRDT metadata rows.
abstract class CrdtSyncIntegrityViolation
    implements _i1.TableRow<int?>, _i2.ProtocolSerialization {
  CrdtSyncIntegrityViolation._({
    this.id,
    required this.type,
    required this.domainTableName,
    required this.uuidRowId,
    this.ownerScopeUuid,
    required this.incomingScopeUuid,
    required this.operation,
    this.uuidNodeId,
    this.crdtDataRowId,
    this.hlcDatetime,
    this.hlcCounter,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.occurrences,
  });

  factory CrdtSyncIntegrityViolation({
    int? id,
    required _i3.CrdtSyncViolationType type,
    required String domainTableName,
    required _i2.UuidValue uuidRowId,
    _i2.UuidValue? ownerScopeUuid,
    required _i2.UuidValue incomingScopeUuid,
    required _i3.CrdtSyncViolationOperation operation,
    _i2.UuidValue? uuidNodeId,
    int? crdtDataRowId,
    DateTime? hlcDatetime,
    int? hlcCounter,
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    required int occurrences,
  }) = _CrdtSyncIntegrityViolationImpl;

  factory CrdtSyncIntegrityViolation.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return CrdtSyncIntegrityViolation(
      id: jsonSerialization['id'] as int?,
      type: _i3.CrdtSyncViolationType.fromJson(
        (jsonSerialization['type'] as String),
      ),
      domainTableName: jsonSerialization['domainTableName'] as String,
      uuidRowId: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      ownerScopeUuid: jsonSerialization['ownerScopeUuid'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['ownerScopeUuid'],
            ),
      incomingScopeUuid: _i2.UuidValueJsonExtension.fromJson(
        jsonSerialization['incomingScopeUuid'],
      ),
      operation: _i3.CrdtSyncViolationOperation.fromJson(
        (jsonSerialization['operation'] as String),
      ),
      uuidNodeId: jsonSerialization['uuidNodeId'] == null
          ? null
          : _i2.UuidValueJsonExtension.fromJson(
              jsonSerialization['uuidNodeId'],
            ),
      crdtDataRowId: jsonSerialization['crdtDataRowId'] as int?,
      hlcDatetime: jsonSerialization['hlcDatetime'] == null
          ? null
          : _i2.DateTimeJsonExtension.fromJson(
              jsonSerialization['hlcDatetime'],
            ),
      hlcCounter: jsonSerialization['hlcCounter'] as int?,
      firstSeenAt: _i2.DateTimeJsonExtension.fromJson(
        jsonSerialization['firstSeenAt'],
      ),
      lastSeenAt: _i2.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastSeenAt'],
      ),
      occurrences: jsonSerialization['occurrences'] as int,
    );
  }

  static final t = CrdtSyncIntegrityViolationTable();

  static const db = CrdtSyncIntegrityViolationRepository._();

  @override
  int? id;

  /// High-level integrity violation category.
  _i3.CrdtSyncViolationType type;

  /// Durable table name for the violated domain row.
  String domainTableName;

  /// Domain row UUID involved in the violation.
  _i2.UuidValue uuidRowId;

  /// Global scope UUID that owns the physical domain row, when known.
  _i2.UuidValue? ownerScopeUuid;

  /// Global scope UUID that attempted to operate on the row.
  _i2.UuidValue incomingScopeUuid;

  /// Merge or sync operation that observed the violation.
  _i3.CrdtSyncViolationOperation operation;

  /// UUID of the node that authored the rejected change, when known.
  _i2.UuidValue? uuidNodeId;

  /// Local CRDT metadata row id observed for the rejected operation, when known.
  int? crdtDataRowId;

  /// Last observed HLC datetime for the rejected change, when known.
  DateTime? hlcDatetime;

  /// Last observed HLC counter for the rejected change, when known.
  int? hlcCounter;

  /// First time this violation key was observed.
  DateTime firstSeenAt;

  /// Most recent time this violation key was observed.
  DateTime lastSeenAt;

  /// Number of times this violation key has been observed.
  int occurrences;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtSyncIntegrityViolation]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  CrdtSyncIntegrityViolation copyWith({
    int? id,
    _i3.CrdtSyncViolationType? type,
    String? domainTableName,
    _i2.UuidValue? uuidRowId,
    _i2.UuidValue? ownerScopeUuid,
    _i2.UuidValue? incomingScopeUuid,
    _i3.CrdtSyncViolationOperation? operation,
    _i2.UuidValue? uuidNodeId,
    int? crdtDataRowId,
    DateTime? hlcDatetime,
    int? hlcCounter,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    int? occurrences,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncIntegrityViolation',
      if (id != null) 'id': id,
      'type': type.toJson(),
      'domainTableName': domainTableName,
      'uuidRowId': uuidRowId.toJson(),
      if (ownerScopeUuid != null) 'ownerScopeUuid': ownerScopeUuid?.toJson(),
      'incomingScopeUuid': incomingScopeUuid.toJson(),
      'operation': operation.toJson(),
      if (uuidNodeId != null) 'uuidNodeId': uuidNodeId?.toJson(),
      if (crdtDataRowId != null) 'crdtDataRowId': crdtDataRowId,
      if (hlcDatetime != null) 'hlcDatetime': hlcDatetime?.toJson(),
      if (hlcCounter != null) 'hlcCounter': hlcCounter,
      'firstSeenAt': firstSeenAt.toJson(),
      'lastSeenAt': lastSeenAt.toJson(),
      'occurrences': occurrences,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncIntegrityViolation',
      if (id != null) 'id': id,
      'type': type.toJson(),
      'domainTableName': domainTableName,
      'uuidRowId': uuidRowId.toJson(),
      if (ownerScopeUuid != null) 'ownerScopeUuid': ownerScopeUuid?.toJson(),
      'incomingScopeUuid': incomingScopeUuid.toJson(),
      'operation': operation.toJson(),
      if (uuidNodeId != null) 'uuidNodeId': uuidNodeId?.toJson(),
      if (crdtDataRowId != null) 'crdtDataRowId': crdtDataRowId,
      if (hlcDatetime != null) 'hlcDatetime': hlcDatetime?.toJson(),
      if (hlcCounter != null) 'hlcCounter': hlcCounter,
      'firstSeenAt': firstSeenAt.toJson(),
      'lastSeenAt': lastSeenAt.toJson(),
      'occurrences': occurrences,
    };
  }

  static CrdtSyncIntegrityViolationInclude include() {
    return CrdtSyncIntegrityViolationInclude._();
  }

  static CrdtSyncIntegrityViolationIncludeList includeList({
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    CrdtSyncIntegrityViolationInclude? include,
  }) {
    return CrdtSyncIntegrityViolationIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtSyncIntegrityViolationImpl extends CrdtSyncIntegrityViolation {
  _CrdtSyncIntegrityViolationImpl({
    int? id,
    required _i3.CrdtSyncViolationType type,
    required String domainTableName,
    required _i2.UuidValue uuidRowId,
    _i2.UuidValue? ownerScopeUuid,
    required _i2.UuidValue incomingScopeUuid,
    required _i3.CrdtSyncViolationOperation operation,
    _i2.UuidValue? uuidNodeId,
    int? crdtDataRowId,
    DateTime? hlcDatetime,
    int? hlcCounter,
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    required int occurrences,
  }) : super._(
         id: id,
         type: type,
         domainTableName: domainTableName,
         uuidRowId: uuidRowId,
         ownerScopeUuid: ownerScopeUuid,
         incomingScopeUuid: incomingScopeUuid,
         operation: operation,
         uuidNodeId: uuidNodeId,
         crdtDataRowId: crdtDataRowId,
         hlcDatetime: hlcDatetime,
         hlcCounter: hlcCounter,
         firstSeenAt: firstSeenAt,
         lastSeenAt: lastSeenAt,
         occurrences: occurrences,
       );

  /// Returns a shallow copy of this [CrdtSyncIntegrityViolation]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncIntegrityViolation copyWith({
    Object? id = _Undefined,
    _i3.CrdtSyncViolationType? type,
    String? domainTableName,
    _i2.UuidValue? uuidRowId,
    Object? ownerScopeUuid = _Undefined,
    _i2.UuidValue? incomingScopeUuid,
    _i3.CrdtSyncViolationOperation? operation,
    Object? uuidNodeId = _Undefined,
    Object? crdtDataRowId = _Undefined,
    Object? hlcDatetime = _Undefined,
    Object? hlcCounter = _Undefined,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    int? occurrences,
  }) {
    return CrdtSyncIntegrityViolation(
      id: id is int? ? id : this.id,
      type: type ?? this.type,
      domainTableName: domainTableName ?? this.domainTableName,
      uuidRowId: uuidRowId ?? this.uuidRowId,
      ownerScopeUuid: ownerScopeUuid is _i2.UuidValue?
          ? ownerScopeUuid
          : this.ownerScopeUuid,
      incomingScopeUuid: incomingScopeUuid ?? this.incomingScopeUuid,
      operation: operation ?? this.operation,
      uuidNodeId: uuidNodeId is _i2.UuidValue? ? uuidNodeId : this.uuidNodeId,
      crdtDataRowId: crdtDataRowId is int? ? crdtDataRowId : this.crdtDataRowId,
      hlcDatetime: hlcDatetime is DateTime? ? hlcDatetime : this.hlcDatetime,
      hlcCounter: hlcCounter is int? ? hlcCounter : this.hlcCounter,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      occurrences: occurrences ?? this.occurrences,
    );
  }
}

class CrdtSyncIntegrityViolationUpdateTable
    extends _i1.UpdateTable<CrdtSyncIntegrityViolationTable> {
  CrdtSyncIntegrityViolationUpdateTable(super.table);

  _i1.ColumnValue<_i3.CrdtSyncViolationType, _i3.CrdtSyncViolationType> type(
    _i3.CrdtSyncViolationType value,
  ) => _i1.ColumnValue(
    table.type,
    value,
  );

  _i1.ColumnValue<String, String> domainTableName(String value) =>
      _i1.ColumnValue(
        table.domainTableName,
        value,
      );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> uuidRowId(
    _i2.UuidValue value,
  ) => _i1.ColumnValue(
    table.uuidRowId,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> ownerScopeUuid(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.ownerScopeUuid,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> incomingScopeUuid(
    _i2.UuidValue value,
  ) => _i1.ColumnValue(
    table.incomingScopeUuid,
    value,
  );

  _i1.ColumnValue<
    _i3.CrdtSyncViolationOperation,
    _i3.CrdtSyncViolationOperation
  >
  operation(_i3.CrdtSyncViolationOperation value) => _i1.ColumnValue(
    table.operation,
    value,
  );

  _i1.ColumnValue<_i2.UuidValue, _i2.UuidValue> uuidNodeId(
    _i2.UuidValue? value,
  ) => _i1.ColumnValue(
    table.uuidNodeId,
    value,
  );

  _i1.ColumnValue<int, int> crdtDataRowId(int? value) => _i1.ColumnValue(
    table.crdtDataRowId,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime? value) =>
      _i1.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _i1.ColumnValue<int, int> hlcCounter(int? value) => _i1.ColumnValue(
    table.hlcCounter,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> firstSeenAt(DateTime value) =>
      _i1.ColumnValue(
        table.firstSeenAt,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> lastSeenAt(DateTime value) =>
      _i1.ColumnValue(
        table.lastSeenAt,
        value,
      );

  _i1.ColumnValue<int, int> occurrences(int value) => _i1.ColumnValue(
    table.occurrences,
    value,
  );
}

class CrdtSyncIntegrityViolationTable extends _i1.Table<int?> {
  CrdtSyncIntegrityViolationTable({super.tableRelation})
    : super(tableName: 'crdt_sync_integrity_violations') {
    updateTable = CrdtSyncIntegrityViolationUpdateTable(this);
    type = _i1.ColumnEnum(
      'type',
      this,
      _i1.EnumSerialization.byName,
    );
    domainTableName = _i1.ColumnString(
      'domainTableName',
      this,
    );
    uuidRowId = _i1.ColumnUuid(
      'uuidRowId',
      this,
    );
    ownerScopeUuid = _i1.ColumnUuid(
      'ownerScopeUuid',
      this,
    );
    incomingScopeUuid = _i1.ColumnUuid(
      'incomingScopeUuid',
      this,
    );
    operation = _i1.ColumnEnum(
      'operation',
      this,
      _i1.EnumSerialization.byName,
    );
    uuidNodeId = _i1.ColumnUuid(
      'uuidNodeId',
      this,
    );
    crdtDataRowId = _i1.ColumnInt(
      'crdtDataRowId',
      this,
    );
    hlcDatetime = _i1.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _i1.ColumnInt(
      'hlcCounter',
      this,
    );
    firstSeenAt = _i1.ColumnDateTime(
      'firstSeenAt',
      this,
    );
    lastSeenAt = _i1.ColumnDateTime(
      'lastSeenAt',
      this,
    );
    occurrences = _i1.ColumnInt(
      'occurrences',
      this,
    );
  }

  late final CrdtSyncIntegrityViolationUpdateTable updateTable;

  /// High-level integrity violation category.
  late final _i1.ColumnEnum<_i3.CrdtSyncViolationType> type;

  /// Durable table name for the violated domain row.
  late final _i1.ColumnString domainTableName;

  /// Domain row UUID involved in the violation.
  late final _i1.ColumnUuid uuidRowId;

  /// Global scope UUID that owns the physical domain row, when known.
  late final _i1.ColumnUuid ownerScopeUuid;

  /// Global scope UUID that attempted to operate on the row.
  late final _i1.ColumnUuid incomingScopeUuid;

  /// Merge or sync operation that observed the violation.
  late final _i1.ColumnEnum<_i3.CrdtSyncViolationOperation> operation;

  /// UUID of the node that authored the rejected change, when known.
  late final _i1.ColumnUuid uuidNodeId;

  /// Local CRDT metadata row id observed for the rejected operation, when known.
  late final _i1.ColumnInt crdtDataRowId;

  /// Last observed HLC datetime for the rejected change, when known.
  late final _i1.ColumnDateTime hlcDatetime;

  /// Last observed HLC counter for the rejected change, when known.
  late final _i1.ColumnInt hlcCounter;

  /// First time this violation key was observed.
  late final _i1.ColumnDateTime firstSeenAt;

  /// Most recent time this violation key was observed.
  late final _i1.ColumnDateTime lastSeenAt;

  /// Number of times this violation key has been observed.
  late final _i1.ColumnInt occurrences;

  @override
  List<_i1.Column> get columns => [
    id,
    type,
    domainTableName,
    uuidRowId,
    ownerScopeUuid,
    incomingScopeUuid,
    operation,
    uuidNodeId,
    crdtDataRowId,
    hlcDatetime,
    hlcCounter,
    firstSeenAt,
    lastSeenAt,
    occurrences,
  ];
}

class CrdtSyncIntegrityViolationInclude extends _i1.IncludeObject {
  CrdtSyncIntegrityViolationInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => CrdtSyncIntegrityViolation.t;
}

class CrdtSyncIntegrityViolationIncludeList extends _i1.IncludeList {
  CrdtSyncIntegrityViolationIncludeList._({
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtSyncIntegrityViolation.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => CrdtSyncIntegrityViolation.t;
}

class CrdtSyncIntegrityViolationRepository {
  const CrdtSyncIntegrityViolationRepository._();

  /// Returns a list of [CrdtSyncIntegrityViolation]s matching the given query parameters.
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
  Future<List<CrdtSyncIntegrityViolation>> find(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<CrdtSyncIntegrityViolation>(
      where: where?.call(CrdtSyncIntegrityViolation.t),
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [CrdtSyncIntegrityViolation] matching the given query parameters.
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
  Future<CrdtSyncIntegrityViolation?> findFirstRow(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? offset,
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<CrdtSyncIntegrityViolation>(
      where: where?.call(CrdtSyncIntegrityViolation.t),
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [CrdtSyncIntegrityViolation] by its [id] or null if no such row exists.
  Future<CrdtSyncIntegrityViolation?> findById(
    _i1.DatabaseSession session,
    int id, {
    _i1.Transaction? transaction,
    _i1.LockMode? lockMode,
    _i1.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<CrdtSyncIntegrityViolation>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [CrdtSyncIntegrityViolation]s in the list and returns the inserted rows.
  ///
  /// The returned [CrdtSyncIntegrityViolation]s will have their `id` fields set.
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
  Future<List<CrdtSyncIntegrityViolation>> insert(
    _i1.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _i1.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<CrdtSyncIntegrityViolation>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [CrdtSyncIntegrityViolation] and returns the inserted row.
  ///
  /// The returned [CrdtSyncIntegrityViolation] will have its `id` field set.
  Future<CrdtSyncIntegrityViolation> insertRow(
    _i1.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<CrdtSyncIntegrityViolation>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [CrdtSyncIntegrityViolation]s in the list and returns the resulting rows.
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
  /// The returned [CrdtSyncIntegrityViolation]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSyncIntegrityViolation>> upsert(
    _i1.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    required _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>
    conflictColumns,
    _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? updateWhere,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<CrdtSyncIntegrityViolation>(
      rows,
      conflictColumns: conflictColumns(CrdtSyncIntegrityViolation.t),
      updateColumns: updateColumns?.call(CrdtSyncIntegrityViolation.t),
      updateWhere: updateWhere?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [CrdtSyncIntegrityViolation] and returns the resulting row.
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
  /// The returned [CrdtSyncIntegrityViolation] will have its `id` field set.
  Future<CrdtSyncIntegrityViolation?> upsertRow(
    _i1.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    required _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>
    conflictColumns,
    _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>? updateColumns,
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? updateWhere,
    _i1.Transaction? transaction,
  }) async {
    return session.db.upsertRow<CrdtSyncIntegrityViolation>(
      row,
      conflictColumns: conflictColumns(CrdtSyncIntegrityViolation.t),
      updateColumns: updateColumns?.call(CrdtSyncIntegrityViolation.t),
      updateWhere: updateWhere?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSyncIntegrityViolation]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSyncIntegrityViolation>> update(
    _i1.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>? columns,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<CrdtSyncIntegrityViolation>(
      rows,
      columns: columns?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [CrdtSyncIntegrityViolation]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<CrdtSyncIntegrityViolation> updateRow(
    _i1.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _i1.ColumnSelections<CrdtSyncIntegrityViolationTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<CrdtSyncIntegrityViolation>(
      row,
      columns: columns?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
    );
  }

  /// Updates a single [CrdtSyncIntegrityViolation] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<CrdtSyncIntegrityViolation?> updateById(
    _i1.DatabaseSession session,
    int id, {
    required _i1.ColumnValueListBuilder<CrdtSyncIntegrityViolationUpdateTable>
    columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<CrdtSyncIntegrityViolation>(
      id,
      columnValues: columnValues(CrdtSyncIntegrityViolation.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [CrdtSyncIntegrityViolation]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<CrdtSyncIntegrityViolation>> updateWhere(
    _i1.DatabaseSession session, {
    required _i1.ColumnValueListBuilder<CrdtSyncIntegrityViolationUpdateTable>
    columnValues,
    required _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<CrdtSyncIntegrityViolation>(
      columnValues: columnValues(CrdtSyncIntegrityViolation.t.updateTable),
      where: where(CrdtSyncIntegrityViolation.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [CrdtSyncIntegrityViolation]s in the list and returns the deleted rows.
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
  Future<List<CrdtSyncIntegrityViolation>> delete(
    _i1.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<CrdtSyncIntegrityViolation>(
      rows,
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [CrdtSyncIntegrityViolation].
  Future<CrdtSyncIntegrityViolation> deleteRow(
    _i1.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<CrdtSyncIntegrityViolation>(
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
  Future<List<CrdtSyncIntegrityViolation>> deleteWhere(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    _i1.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _i1.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _i1.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<CrdtSyncIntegrityViolation>(
      where: where(CrdtSyncIntegrityViolation.t),
      orderBy: orderBy?.call(CrdtSyncIntegrityViolation.t),
      orderByList: orderByList?.call(CrdtSyncIntegrityViolation.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.DatabaseSession session, {
    _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<CrdtSyncIntegrityViolation>(
      where: where?.call(CrdtSyncIntegrityViolation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtSyncIntegrityViolation] rows matching the [where] expression.
  Future<void> lockRows(
    _i1.DatabaseSession session, {
    required _i1.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    required _i1.LockMode lockMode,
    required _i1.Transaction transaction,
    _i1.LockBehavior lockBehavior = _i1.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtSyncIntegrityViolation>(
      where: where(CrdtSyncIntegrityViolation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
