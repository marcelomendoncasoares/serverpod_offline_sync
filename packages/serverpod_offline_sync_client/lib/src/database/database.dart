// The Database type is implemented here as a test-style proxy; some lints
// flag internal Serverpod APIs used by generated code.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../crdt/exceptions.dart';
import '../crdt/merge.dart';
import '../crdt/ownership_violation.dart';
import '../crdt/sync.dart';
import '../protocol/protocol.dart';
import 'recorder.dart';
import 'session.dart';
import 'tombstone.dart';

/// Map of transaction hashes to the scope they are associated with.
final scopeForTransaction = <Transaction, CrdtScope>{};

/// Database proxy that runs insert/update/delete ORM operations inside a
/// transaction to record each change in the CRDT tables.
class CrdtDatabase implements Database {
  /// Creates a CRDT-aware database wrapper around the inner database.
  CrdtDatabase(
    this._delegate, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = CrdtSync.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
  }) : _syncTables = syncTables,
       _syncBatchSize = syncBatchSize,
       _continuousSyncInterval = continuousSyncInterval,
       _recorder = CrdtMutationRecorder(
         _delegate,
         persistentUserId: persistentUserId,
         syncTables: syncTables,
       );

  final Database _delegate;
  final List<Table> _syncTables;
  final int _syncBatchSize;
  final Duration _continuousSyncInterval;

  final CrdtMutationRecorder _recorder;

  late final CrdtSync _sync = CrdtSync(
    syncTables: _syncTables,
    serializationManager: serializationManager,
    syncBatchSize: _syncBatchSize,
    continuousSyncInterval: _continuousSyncInterval,
  );

  /// Initializes the CRDT database.
  Future<void> initialize() async {
    await _recorder.initialize();
  }

  /// The hash describing the synchronized schema configured for this database.
  String get syncTablesHash => _sync.currentSyncTablesHash;

  /// Returns the current node identifier for the effective user.
  Future<UuidValue> currentNodeId({UuidValue? userId}) async {
    final effectiveUserId = await _requireUserId(userId);
    final user = await _recorder.getOrCreateScope(effectiveUserId);
    return user.currentNode!.uuidNodeId;
  }

  /// Runs a symmetric CRDT sync session over a bidirectional event stream.
  Stream<CrdtSyncStreamEvent> sync({
    required Stream<CrdtSyncStreamEvent> inbound,
    UuidValue? userId,
    bool once = false,
    CrdtSyncOnMergeSuccess? onMergeSuccess,
  }) async* {
    final effectiveUserId = await _requireUserId(userId);
    yield* _sync.sync(
      _delegate.session,
      userId: effectiveUserId,
      inbound: inbound,
      once: once,
      onMergeSuccess: onMergeSuccess,
    );
  }

  /// Records the latest acknowledged sync checkpoint for [otherNodeId].
  Future<void> recordSyncCheckpoint(
    UuidValue otherNodeId,
    Hlc syncedHlc, {
    UuidValue? userId,
  }) async {
    final effectiveUserId = await _requireUserId(userId);
    await _recorder.recordSyncCheckpoint(
      effectiveUserId,
      otherNodeId,
      syncedHlc,
    );
  }

  /// Merges remote CRDT changes into the local database for the given scope.
  ///
  /// When [scopeId] is omitted, this uses the recorder's persistent user id.
  /// The merge locks the current scope's CRDT tables and executes atomically
  /// inside [transactionForUser].
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet, {
    UuidValue? scopeId,
  }) async {
    if (mergeSet.isEmpty) return;

    final effectiveScopeId =
        scopeId ??
        _recorder.persistentUserId ??
        (throw StateError(
          'A scope ID is required when merging changes without a persistent user.',
        ));
    try {
      await transactionForUser<void>(effectiveScopeId, (tx) async {
        await _recorder.lockCurrentUser(tx);
        await _recorder.mergeChanges(mergeSet, tx);
      });
    } on CrdtSyncOwnershipViolationException catch (exception) {
      final persistedViolation = await recordCrdtOwnershipViolation(
        _delegate.session,
        violation: exception.violation,
      );
      throw CrdtSyncOwnershipViolationException(persistedViolation);
    }
  }

  @override
  DatabaseAnalyzer get analyzer => _delegate.analyzer;

  @override
  DatabaseDialect get dialect => _delegate.dialect;

  @override
  DatabaseSerializationManager get serializationManager =>
      _delegate.serializationManager;

  /// Merges [where] with the CRDT visibility predicates scoped to the queried
  /// tables and the user associated with [transaction] (or the persistent
  /// user). Without a user scope (e.g. server-side admin reads), a row is
  /// only hidden when every user tracking it has it hidden.
  Expression? _whereVisibleWithTombstone<T extends TableRow>(
    Expression? where,
    Include? include,
    Transaction? transaction,
  ) {
    return mergeWhereWithTombstone<T>(
      serializationManager,
      where,
      include,
      tableIdForName: _recorder.tableIdForName,
      scopeId: () => _recorder.scopeForQueries(transaction)?.id,
    );
  }

  @override
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    final result = await _delegate.find<T>(
      where: _whereVisibleWithTombstone<T>(where, include, transaction),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      // Remove this once the deprecated member is removed.
      // ignore: deprecated_member_use
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    return _stripScopeIdFromScopedRead(result, include, transaction);
  }

  @override
  Future<T?> findById<T extends TableRow>(
    Object id, {
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    final table = serializationManager.getTableForType(T);
    final where = table?.id.equals(id);
    final result = await _delegate.findFirstRow<T>(
      where: _whereVisibleWithTombstone<T>(where, include, transaction),
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (result == null) return null;
    return _stripScopeIdFromScopedRead([result], include, transaction).single;
  }

  @override
  Future<T?> findFirstRow<T extends TableRow>({
    Expression? where,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    final result = await _delegate.findFirstRow<T>(
      where: _whereVisibleWithTombstone<T>(where, include, transaction),
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      // Remove this once the deprecated member is removed.
      // ignore: deprecated_member_use
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (result == null) return null;
    return _stripScopeIdFromScopedRead([result], include, transaction).single;
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    if (rows.isEmpty) return [];
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final prepared = _prepareRowsForInsert(rows, tx);
        final result = await _delegate.insert<T>(
          prepared.rows,
          transaction: tx,
          ignoreConflicts: ignoreConflicts,
        );

        await _recorder.afterInsert<T>(result, tx);
        _stripStampedRows(result, prepared);
        return result;
      },
    );
  }

  @override
  Future<T> insertRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) async {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final prepared = _prepareRowsForInsert([row], tx);
        final databaseRow = prepared.rows.single;
        late final T result;
        try {
          result = await _delegate.insertRow<T>(databaseRow, transaction: tx);
        } on DatabaseQueryException {
          if (!await _recorder.isDeleted(row, tx)) rethrow;

          result = await _delegate.updateRow<T>(databaseRow, transaction: tx);
          await _recorder.afterReinsert([result], tx);
          _stripStampedRows([result], prepared);
          return result;
        }

        await _recorder.afterInsert([result], tx);
        _stripStampedRows([result], prepared);
        return result;
      },
    );
  }

  @override
  Future<List<T>> upsert<T extends TableRow>(
    List<T> rows, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) async {
    // TODO: Implement CRDT upsert.
    throw UnimplementedError('CRDT upsert is not implemented.');
  }

  @override
  Future<T?> upsertRow<T extends TableRow>(
    T row, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) async {
    // TODO: Implement CRDT upsert.
    throw UnimplementedError('CRDT upsert is not implemented.');
  }

  @override
  Future<List<T>> update<T extends TableRow>(
    List<T> rows, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    if (rows.isEmpty) return [];
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final updatedRows = [
          for (final row in rows)
            await _updateRowWithoutRecording(
              row,
              stripScopeId: _shouldStripReturnedScopeId(row, tx),
              transaction: tx,
              columns: columns,
            ),
        ];

        await _recorder.afterUpdate(updatedRows, columns, tx);
        return updatedRows;
      },
    );
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final stripScopeId = _shouldStripReturnedScopeId(row, tx);
        final updatedRow = await _updateRowWithoutRecording(
          row,
          stripScopeId: stripScopeId,
          transaction: tx,
          columns: columns,
        );

        await _recorder.afterUpdate([updatedRow], columns, tx);
        return updatedRow;
      },
    );
  }

  Future<T> _updateRowWithoutRecording<T extends TableRow>(
    T row, {
    required Transaction transaction,
    required bool stripScopeId,
    List<Column>? columns,
  }) async {
    final values = row.toJsonForDatabase() as Map<String, dynamic>;
    final columnValues = (columns ?? row.table.managedColumns)
        .where((c) => c.columnName != 'id' && c.columnName != 'scopeId')
        .map((c) => ColumnValue(c, values[c.columnName]))
        .toList();

    final where = row.table.id.equals(row.id);
    final updatedRows = await _delegate.updateWhere<T>(
      columnValues: columnValues,
      where: _whereVisibleWithTombstone<T>(where, null, transaction)!,
      transaction: transaction,
    );

    if (updatedRows.isEmpty) {
      // FIXME: We can't use the proper `DatabaseUpdateRowException` because
      // it is declared as a base type on the `serverpod_database` package.
      throw Exception('Failed to update row, no rows updated.');
    }

    final updatedRow = updatedRows.single;
    if (stripScopeId) _stripScopeId(updatedRow);
    return updatedRow;
  }

  @override
  Future<T?> updateById<T extends TableRow>(
    Object id, {
    required List<ColumnValue> columnValues,
    Transaction? transaction,
  }) async {
    final table = serializationManager.getTableForType(T);
    if (table == null) return null;

    final updatedRows = await updateWhere<T>(
      columnValues: columnValues,
      where: table.id.equals(id),
      transaction: transaction,
    );

    if (updatedRows.isEmpty) return null;
    return updatedRows.single;
  }

  @override
  Future<List<T>> updateWhere<T extends TableRow>({
    required List<ColumnValue> columnValues,
    required Expression where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) async {
    if (_recorder.isCrdtTracked<T>()) {
      _assertNoScopeIdColumnValues<T>(columnValues);
    }

    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateWhere<T>(
          columnValues: columnValues,
          where: _whereVisibleWithTombstone<T>(where, null, tx)!,
          limit: limit,
          offset: offset,
          orderBy: orderBy,
          orderByList: orderByList,
          // Remove this once the deprecated member is removed.
          // ignore: deprecated_member_use
          orderDescending: orderDescending,
          transaction: tx,
        );

        final columns = columnValues.map((e) => e.column).toList();
        await _recorder.afterUpdate(result, columns, tx);
        if (_recorder.isCrdtTracked<T>()) {
          result.forEach(_stripScopeId);
        }
        return result;
      },
    );
  }

  @override
  Future<List<T>> delete<T extends TableRow>(
    List<T> rows, {
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) async {
    if (rows.isEmpty) return [];
    return deleteWhere<T>(
      where: rows.first.table.id.inSet(
        rows.map((row) => row.id).castToIdType().toSet(),
      ),
      orderBy: orderBy,
      orderByList: orderByList,
      // Remove this once the deprecated member is removed.
      // ignore: deprecated_member_use
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  @override
  Future<T> deleteRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) async {
    final deletedRows = await deleteWhere<T>(
      where: row.table.id.equals(row.id),
      transaction: transaction,
    );

    if (deletedRows.isEmpty) {
      // FIXME: We can't use the proper `DatabaseDeleteRowException` because
      // it is declared as a base type on the `serverpod_database` package.
      throw Exception('Failed to delete row, no rows deleted.');
    }

    return deletedRows.single;
  }

  @override
  Future<List<T>> deleteWhere<T extends TableRow>({
    required Expression where,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) async {
    if (!_recorder.isCrdtTracked<T>()) {
      return _delegate.deleteWhere<T>(
        where: where,
        orderBy: orderBy,
        orderByList: orderByList,
        // Remove this once the deprecated member is removed.
        // ignore: deprecated_member_use
        orderDescending: orderDescending,
        transaction: transaction,
      );
    }

    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final rows = await _delegate.find<T>(
          where: _whereVisibleWithTombstone<T>(where, null, tx),
          orderBy: orderBy,
          orderByList: orderByList,
          // Remove this once the deprecated member is removed.
          // ignore: deprecated_member_use
          orderDescending: orderDescending,
          transaction: tx,
        );

        await _recorder.insteadOfDelete<T>(rows, tx);
        return _stripScopeIdFromScopedRead(rows, null, tx);
      },
    );
  }

  @override
  Future<int> count<T extends TableRow>({
    Expression? where,
    int? limit,
    bool useCache = true,
    Transaction? transaction,
  }) async {
    return _delegate.count<T>(
      where: _whereVisibleWithTombstone<T>(where, null, transaction),
      limit: limit,
      useCache: useCache,
      transaction: transaction,
    );
  }

  @override
  Future<void> lockRows<T extends TableRow>({
    required Expression where,
    required LockMode lockMode,
    required Transaction transaction,
    LockBehavior lockBehavior = LockBehavior.wait,
  }) async {
    return _delegate.lockRows<T>(
      where: _whereVisibleWithTombstone<T>(where, null, transaction)!,
      lockMode: lockMode,
      transaction: transaction,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<R> transaction<R>(
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async {
    return _delegate.transaction(
      transactionFunction,
      settings: settings,
    );
  }

  /// Executes the [transactionFunction] in a transaction with the provided [userId].
  ///
  /// The [userId] is used to record the CRDT operations in the database. This method
  /// must be used instead of [transaction] when performing operations on the server,
  /// where the database knows multiple users.
  Future<R> transactionForUser<R>(
    UuidValue userId,
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async {
    // Ensure that the user exists with a node before starting the transaction.
    final user = await _recorder.getOrCreateScope(userId);

    return transaction<R>(
      (tx) async {
        try {
          scopeForTransaction[tx] = user;
          return await transactionFunction(tx);
        } finally {
          scopeForTransaction.remove(tx);
        }
      },
      settings: settings,
    );
  }

  Future<UuidValue> _requireUserId(UuidValue? userId) async {
    return userId ??
        _recorder.persistentUserId ??
        (throw StateError(
          'A user ID is required when syncing without a persistent user.',
        ));
  }

  ({
    List<T> rows,
    Set<int> stampedIndexes,
    Set<Object> explicitRowIds,
  })
  _prepareRowsForInsert<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return (rows: rows, stampedIndexes: const {}, explicitRowIds: const {});
    }

    final scope = _requireEffectiveScope(transaction);
    final effectiveScopeId = scope.id!;
    final databaseRows = <T>[];
    final stampedIndexes = <int>{};
    final explicitRowIds = <Object>{};

    for (final (index, row) in rows.indexed) {
      final rowScopeId = _readScopeId(row);
      if (rowScopeId == null) {
        databaseRows.add(_copyWithScopeId(row, effectiveScopeId));
        stampedIndexes.add(index);
        continue;
      }

      if (rowScopeId != effectiveScopeId) {
        throw StateError(
          'Cannot write ${row.table.tableName} row ${row.id} with scopeId '
          '$rowScopeId while acting in scope $effectiveScopeId.',
        );
      }

      databaseRows.add(row);
      final rowId = row.id;
      if (rowId != null) explicitRowIds.add(rowId as Object);
    }

    return (
      rows: databaseRows,
      stampedIndexes: stampedIndexes,
      explicitRowIds: explicitRowIds,
    );
  }

  bool _shouldStripReturnedScopeId<T extends TableRow>(
    T row,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(row.table)) return false;

    final rowScopeId = _readScopeId(row);
    if (rowScopeId == null) return true;

    final effectiveScopeId = _requireEffectiveScope(transaction).id!;
    if (rowScopeId != effectiveScopeId) {
      throw StateError(
        'Cannot write ${row.table.tableName} row ${row.id} with scopeId '
        '$rowScopeId while acting in scope $effectiveScopeId.',
      );
    }

    return false;
  }

  void _assertNoScopeIdColumnValues<T extends TableRow>(
    List<ColumnValue> columnValues,
  ) {
    for (final columnValue in columnValues) {
      if (columnValue.column.columnName == 'scopeId') {
        final table = serializationManager.getTableForType(T)?.tableName ?? 'unknown';
        throw StateError(
          'scopeId is immutable and owned by the CRDT sync layer for $table.',
        );
      }
    }
  }

  CrdtScope _requireEffectiveScope(Transaction transaction) {
    return _recorder.scopeForQueries(transaction) ??
        (throw StateError(
          'A scope ID is required for CRDT writes without a persistent user.',
        ));
  }

  int? _readScopeId(TableRow row) => (row as dynamic).scopeId as int?;

  T _copyWithScopeId<T extends TableRow>(T row, int scopeId) {
    return (row as dynamic).copyWith(scopeId: scopeId) as T;
  }

  void _stripStampedRows<T extends TableRow>(
    List<T> rows,
    ({
      List<T> rows,
      Set<int> stampedIndexes,
      Set<Object> explicitRowIds,
    })
    prepared,
  ) {
    if (rows.length == prepared.rows.length) {
      for (final (index, row) in rows.indexed) {
        if (prepared.stampedIndexes.contains(index)) _stripScopeId(row);
      }
      return;
    }

    // `ignoreConflicts` dropped rows, so positions no longer align with the
    // input. Keep the value only on rows whose id was caller-provided on an
    // explicit (asserted) input row; everything else is treated as stamped.
    for (final row in rows) {
      final rowId = row.id;
      if (rowId == null || !prepared.explicitRowIds.contains(rowId)) {
        _stripScopeId(row);
      }
    }
  }

  void _stripScopeId(TableRow row) {
    (row as dynamic).scopeId = null;
  }

  List<T> _stripScopeIdFromScopedRead<T extends TableRow>(
    List<T> rows,
    Include? include,
    Transaction? transaction,
  ) {
    if (rows.isEmpty) return rows;
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) return rows;
    if (_recorder.scopeForQueries(transaction) == null) return rows;

    final hasNestedRows =
        include != null && include.includes.values.any((inc) => inc != null);
    if (!hasNestedRows) {
      // Hot path: delegate-returned rows are package-owned, so the root
      // field is stripped in place with no allocation.
      rows.forEach(_stripScopeId);
      return rows;
    }

    // Nested models are only reachable through generated fields, which
    // cannot be accessed generically by name, so include graphs pay a
    // serialization round-trip per row to strip recursively.
    return [
      for (final row in rows) _copyWithScopeIdsStripped(row),
    ];
  }

  T _copyWithScopeIdsStripped<T extends TableRow>(T row) {
    final json = Map<String, dynamic>.from(row.toJson() as Map);
    _stripScopeIdsFromJson(json);
    return serializationManager.deserialize<T>(json);
  }

  void _stripScopeIdsFromJson(Object? value) {
    if (value is Map) {
      if (value.containsKey('scopeId')) {
        value['scopeId'] = null;
      }
      value.values.forEach(_stripScopeIdsFromJson);
      return;
    }

    if (value is Iterable) {
      value.forEach(_stripScopeIdsFromJson);
    }
  }

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    return _delegate.unsafeExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
      parameters: parameters,
    );
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    return _delegate.unsafeQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
      parameters: parameters,
    );
  }

  @override
  Future<int> unsafeSimpleExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    return _delegate.unsafeSimpleExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
    );
  }

  @override
  Future<DatabaseResult> unsafeSimpleQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    return _delegate.unsafeSimpleQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
    );
  }

  @override
  Future<bool> testConnection() => _delegate.testConnection();
}
