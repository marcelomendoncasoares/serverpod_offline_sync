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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Durable record of a terminal CRDT sync integrity violation.
///
/// These rows are sparse diagnostic state. They record observed corruption or
/// hostile input without duplicating hot CRDT indexes.
///
/// All identifiers are denormalized UUIDs and names so the record remains
/// useful after merge rollbacks and across databases that do not share the
/// same local CRDT metadata rows.
abstract class CrdtSyncIntegrityViolation
    implements _isd.TableRow<int?>, _iss.ProtocolSerialization {
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
    required _icw2tu00.CrdtSyncViolationType type,
    required String domainTableName,
    required _iss.UuidValue uuidRowId,
    _iss.UuidValue? ownerScopeUuid,
    required _iss.UuidValue incomingScopeUuid,
    required _icw2tu00.CrdtSyncViolationOperation operation,
    _iss.UuidValue? uuidNodeId,
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
      type: _icw2tu00.CrdtSyncViolationType.fromJson(
        (jsonSerialization['type'] as String),
      ),
      domainTableName: jsonSerialization['domainTableName'] as String,
      uuidRowId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidRowId'],
      ),
      ownerScopeUuid: jsonSerialization['ownerScopeUuid'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['ownerScopeUuid'],
            ),
      incomingScopeUuid: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['incomingScopeUuid'],
      ),
      operation: _icw2tu00.CrdtSyncViolationOperation.fromJson(
        (jsonSerialization['operation'] as String),
      ),
      uuidNodeId: jsonSerialization['uuidNodeId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['uuidNodeId'],
            ),
      crdtDataRowId: jsonSerialization['crdtDataRowId'] as int?,
      hlcDatetime: jsonSerialization['hlcDatetime'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(
              jsonSerialization['hlcDatetime'],
            ),
      hlcCounter: jsonSerialization['hlcCounter'] as int?,
      firstSeenAt: _iss.DateTimeJsonExtension.fromJson(
        jsonSerialization['firstSeenAt'],
      ),
      lastSeenAt: _iss.DateTimeJsonExtension.fromJson(
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
  _icw2tu00.CrdtSyncViolationType type;

  /// Durable table name for the violated domain row.
  String domainTableName;

  /// Domain row UUID involved in the violation.
  _iss.UuidValue uuidRowId;

  /// Global scope UUID that owns the physical domain row, when known.
  _iss.UuidValue? ownerScopeUuid;

  /// Global scope UUID that attempted to operate on the row.
  _iss.UuidValue incomingScopeUuid;

  /// Merge or sync operation that observed the violation.
  _icw2tu00.CrdtSyncViolationOperation operation;

  /// UUID of the node that authored the rejected change, when known.
  _iss.UuidValue? uuidNodeId;

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
  _isd.Table<int?> get table => t;

  /// Returns a shallow copy of this [CrdtSyncIntegrityViolation]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtSyncIntegrityViolation copyWith({
    int? id,
    _icw2tu00.CrdtSyncViolationType? type,
    String? domainTableName,
    _iss.UuidValue? uuidRowId,
    _iss.UuidValue? ownerScopeUuid,
    _iss.UuidValue? incomingScopeUuid,
    _icw2tu00.CrdtSyncViolationOperation? operation,
    _iss.UuidValue? uuidNodeId,
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
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
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
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _CrdtSyncIntegrityViolationImpl extends CrdtSyncIntegrityViolation {
  _CrdtSyncIntegrityViolationImpl({
    int? id,
    required _icw2tu00.CrdtSyncViolationType type,
    required String domainTableName,
    required _iss.UuidValue uuidRowId,
    _iss.UuidValue? ownerScopeUuid,
    required _iss.UuidValue incomingScopeUuid,
    required _icw2tu00.CrdtSyncViolationOperation operation,
    _iss.UuidValue? uuidNodeId,
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
  @_iss.useResult
  @override
  CrdtSyncIntegrityViolation copyWith({
    Object? id = _Undefined,
    _icw2tu00.CrdtSyncViolationType? type,
    String? domainTableName,
    _iss.UuidValue? uuidRowId,
    Object? ownerScopeUuid = _Undefined,
    _iss.UuidValue? incomingScopeUuid,
    _icw2tu00.CrdtSyncViolationOperation? operation,
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
      ownerScopeUuid: ownerScopeUuid is _iss.UuidValue?
          ? ownerScopeUuid
          : this.ownerScopeUuid,
      incomingScopeUuid: incomingScopeUuid ?? this.incomingScopeUuid,
      operation: operation ?? this.operation,
      uuidNodeId: uuidNodeId is _iss.UuidValue? ? uuidNodeId : this.uuidNodeId,
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
    extends _isd.UpdateTable<CrdtSyncIntegrityViolationTable> {
  CrdtSyncIntegrityViolationUpdateTable(super.table);

  _isd.ColumnValue<
    _icw2tu00.CrdtSyncViolationType,
    _icw2tu00.CrdtSyncViolationType
  >
  type(_icw2tu00.CrdtSyncViolationType value) => _isd.ColumnValue(
    table.type,
    value,
  );

  _isd.ColumnValue<String, String> domainTableName(String value) =>
      _isd.ColumnValue(
        table.domainTableName,
        value,
      );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> uuidRowId(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.uuidRowId,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> ownerScopeUuid(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(
    table.ownerScopeUuid,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> incomingScopeUuid(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(
    table.incomingScopeUuid,
    value,
  );

  _isd.ColumnValue<
    _icw2tu00.CrdtSyncViolationOperation,
    _icw2tu00.CrdtSyncViolationOperation
  >
  operation(_icw2tu00.CrdtSyncViolationOperation value) => _isd.ColumnValue(
    table.operation,
    value,
  );

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> uuidNodeId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(
    table.uuidNodeId,
    value,
  );

  _isd.ColumnValue<int, int> crdtDataRowId(int? value) => _isd.ColumnValue(
    table.crdtDataRowId,
    value,
  );

  _isd.ColumnValue<DateTime, DateTime> hlcDatetime(DateTime? value) =>
      _isd.ColumnValue(
        table.hlcDatetime,
        value,
      );

  _isd.ColumnValue<int, int> hlcCounter(int? value) => _isd.ColumnValue(
    table.hlcCounter,
    value,
  );

  _isd.ColumnValue<DateTime, DateTime> firstSeenAt(DateTime value) =>
      _isd.ColumnValue(
        table.firstSeenAt,
        value,
      );

  _isd.ColumnValue<DateTime, DateTime> lastSeenAt(DateTime value) =>
      _isd.ColumnValue(
        table.lastSeenAt,
        value,
      );

  _isd.ColumnValue<int, int> occurrences(int value) => _isd.ColumnValue(
    table.occurrences,
    value,
  );
}

class CrdtSyncIntegrityViolationTable extends _isd.Table<int?> {
  CrdtSyncIntegrityViolationTable({super.tableRelation})
    : super(tableName: 'crdt_sync_integrity_violations') {
    updateTable = CrdtSyncIntegrityViolationUpdateTable(this);
    type = _isd.ColumnEnum(
      'type',
      this,
      _isd.EnumSerialization.byName,
    );
    domainTableName = _isd.ColumnString(
      'domainTableName',
      this,
    );
    uuidRowId = _isd.ColumnUuid(
      'uuidRowId',
      this,
    );
    ownerScopeUuid = _isd.ColumnUuid(
      'ownerScopeUuid',
      this,
    );
    incomingScopeUuid = _isd.ColumnUuid(
      'incomingScopeUuid',
      this,
    );
    operation = _isd.ColumnEnum(
      'operation',
      this,
      _isd.EnumSerialization.byName,
    );
    uuidNodeId = _isd.ColumnUuid(
      'uuidNodeId',
      this,
    );
    crdtDataRowId = _isd.ColumnInt(
      'crdtDataRowId',
      this,
    );
    hlcDatetime = _isd.ColumnDateTime(
      'hlcDatetime',
      this,
    );
    hlcCounter = _isd.ColumnInt(
      'hlcCounter',
      this,
    );
    firstSeenAt = _isd.ColumnDateTime(
      'firstSeenAt',
      this,
    );
    lastSeenAt = _isd.ColumnDateTime(
      'lastSeenAt',
      this,
    );
    occurrences = _isd.ColumnInt(
      'occurrences',
      this,
    );
  }

  late final CrdtSyncIntegrityViolationUpdateTable updateTable;

  /// High-level integrity violation category.
  late final _isd.ColumnEnum<_icw2tu00.CrdtSyncViolationType> type;

  /// Durable table name for the violated domain row.
  late final _isd.ColumnString domainTableName;

  /// Domain row UUID involved in the violation.
  late final _isd.ColumnUuid uuidRowId;

  /// Global scope UUID that owns the physical domain row, when known.
  late final _isd.ColumnUuid ownerScopeUuid;

  /// Global scope UUID that attempted to operate on the row.
  late final _isd.ColumnUuid incomingScopeUuid;

  /// Merge or sync operation that observed the violation.
  late final _isd.ColumnEnum<_icw2tu00.CrdtSyncViolationOperation> operation;

  /// UUID of the node that authored the rejected change, when known.
  late final _isd.ColumnUuid uuidNodeId;

  /// Local CRDT metadata row id observed for the rejected operation, when known.
  late final _isd.ColumnInt crdtDataRowId;

  /// Last observed HLC datetime for the rejected change, when known.
  late final _isd.ColumnDateTime hlcDatetime;

  /// Last observed HLC counter for the rejected change, when known.
  late final _isd.ColumnInt hlcCounter;

  /// First time this violation key was observed.
  late final _isd.ColumnDateTime firstSeenAt;

  /// Most recent time this violation key was observed.
  late final _isd.ColumnDateTime lastSeenAt;

  /// Number of times this violation key has been observed.
  late final _isd.ColumnInt occurrences;

  @override
  List<_isd.Column> get columns => [
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

class CrdtSyncIntegrityViolationInclude extends _isd.IncludeObject {
  CrdtSyncIntegrityViolationInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<int?> get table => CrdtSyncIntegrityViolation.t;
}

class CrdtSyncIntegrityViolationIncludeList extends _isd.IncludeList {
  CrdtSyncIntegrityViolationIncludeList._({
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(CrdtSyncIntegrityViolation.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<int?> get table => CrdtSyncIntegrityViolation.t;
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? offset,
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    int id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
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
    _isd.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    required _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>
    conflictColumns,
    _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    required _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>
    conflictColumns,
    _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>? updateColumns,
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? updateWhere,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _isd.ColumnSelections<CrdtSyncIntegrityViolationTable>? columns,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    int id, {
    required _isd.ColumnValueListBuilder<CrdtSyncIntegrityViolationUpdateTable>
    columnValues,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<CrdtSyncIntegrityViolationUpdateTable>
    columnValues,
    required _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    List<CrdtSyncIntegrityViolation> rows, {
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session,
    CrdtSyncIntegrityViolation row, {
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    _isd.OrderByBuilder<CrdtSyncIntegrityViolationTable>? orderBy,
    _isd.OrderByListBuilder<CrdtSyncIntegrityViolationTable>? orderByList,
    _isd.Transaction? transaction,
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
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<CrdtSyncIntegrityViolation>(
      where: where?.call(CrdtSyncIntegrityViolation.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [CrdtSyncIntegrityViolation] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<CrdtSyncIntegrityViolationTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<CrdtSyncIntegrityViolation>(
      where: where(CrdtSyncIntegrityViolation.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
