import 'dart:async';

// The Database type is implemented here as a test-style proxy; some lints
// flag internal Serverpod APIs used by generated code.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../crdt/merge.dart';
import '../crdt/sync.dart';
import '../protocol/protocol.dart';
import 'recorder.dart';
import 'session.dart';
import 'tombstone.dart';

/// Map of transaction hashes to the user ID they are associated with.
final userForTransaction = <Transaction, CrdtUser>{};

/// Database proxy that runs insert/update/delete ORM operations inside a
/// transaction to record each change in the CRDT tables.
class CrdtDatabase implements Database {
  /// Creates a CRDT-aware database wrapper around the inner database.
  CrdtDatabase(
    this._delegate, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
    Caller? syncCaller,
  }) : _syncTables = syncTables,
       _syncCaller = syncCaller,
       _recorder = CrdtMutationRecorder(
         _delegate,
         persistentUserId: persistentUserId,
         syncTables: syncTables,
       );

  final Database _delegate;
  final List<Table> _syncTables;
  final Caller? _syncCaller;

  final CrdtMutationRecorder _recorder;

  late final CrdtSync _sync = CrdtSync(
    syncTables: _syncTables,
    serializationManager: serializationManager,
  );

  /// Initializes the CRDT database.
  Future<void> initialize() async {
    await _recorder.initialize();
  }

  /// The hash describing the synchronized schema configured for this database.
  String get syncTablesHash => _sync.currentSyncTablesHash;

  /// Collects local CRDT changes after [lastSyncHlc].
  Future<CrdtMergeSet> collectPendingChanges({
    required Hlc lastSyncHlc,
    UuidValue? userId,
  }) async {
    final effectiveUserId = await _requireUserId(userId);
    return _sync.collectPendingChanges(
      _delegate.session,
      userId: effectiveUserId,
      lastSyncHlc: lastSyncHlc,
    );
  }

  /// Merges remote CRDT changes into the local database for the given user.
  ///
  /// When [userId] is omitted, this uses the recorder's persistent user id.
  /// The merge locks the current user's CRDT tables and executes atomically
  /// inside [transactionForUser].
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet, {
    UuidValue? userId,
  }) async {
    if (mergeSet.isEmpty) return;

    final effectiveUserId =
        userId ??
        _recorder.persistentUserId ??
        (throw StateError(
          'A user ID is required when merging changes without a persistent user.',
        ));
    await transactionForUser<void>(effectiveUserId, (tx) async {
      await _recorder.lockCurrentUser(tx);
      await _recorder.mergeChanges(mergeSet, tx);
    });
  }

  /// Pushes the local pending changes to the remote sync endpoint in one call.
  Future<void> syncOnce({
    Hlc? lastSyncHlc,
    UuidValue? userId,
    Caller? syncCaller,
  }) async {
    final effectiveUserId = await _requireUserId(userId);
    final effectiveLastSyncHlc = lastSyncHlc ?? await _zeroSyncHlc(effectiveUserId);
    final mergeSet = await collectPendingChanges(
      lastSyncHlc: effectiveLastSyncHlc,
      userId: effectiveUserId,
    );
    if (mergeSet.isEmpty) return;

    await _requireSyncCaller(syncCaller).callServerEndpoint<void>(
      'serverpod_offline_sync.crdtSync',
      'syncOnce',
      {
        'syncTablesHash': syncTablesHash,
        'changes': mergeSet,
      },
    );
  }

  /// Performs a bidirectional sync against the remote streaming endpoint.
  Future<void> syncContinuously({
    Hlc? lastSyncHlc,
    UuidValue? userId,
    Caller? syncCaller,
  }) async {
    final effectiveUserId = await _requireUserId(userId);
    final effectiveLastSyncHlc = lastSyncHlc ?? await _zeroSyncHlc(effectiveUserId);
    final pendingChanges = await collectPendingChanges(
      lastSyncHlc: effectiveLastSyncHlc,
      userId: effectiveUserId,
    );
    final caller = _requireSyncCaller(syncCaller);
    final remoteStream =
        caller.callStreamingServerEndpoint<CrdtMergeChange, CrdtMergeChange?>(
              'serverpod_offline_sync.crdtSync',
              'syncStream',
              {
                'syncTablesHash': syncTablesHash,
                'lastSyncHlc': effectiveLastSyncHlc,
              },
              {'changes': Stream<CrdtMergeChange?>.value(null)},
            )
            as Stream<CrdtMergeChange?>;

    final remoteChangesFuture = _collectRemoteChanges(remoteStream);

    final remoteChanges = await remoteChangesFuture;
    if (remoteChanges != null && !remoteChanges.isEmpty) {
      await mergeChanges(remoteChanges, userId: effectiveUserId);
    }

    if (pendingChanges.isEmpty) return;

    await caller.callServerEndpoint<void>(
      'serverpod_offline_sync.crdtSync',
      'syncOnce',
      {
        'syncTablesHash': syncTablesHash,
        'changes': pendingChanges,
      },
    );
  }

  @override
  DatabaseAnalyzer get analyzer => _delegate.analyzer;

  @override
  DatabaseDialect get dialect => _delegate.dialect;

  @override
  DatabaseSerializationManager get serializationManager =>
      _delegate.serializationManager;

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
    return _delegate.find<T>(
      where: mergeWhereWithTombstone<T>(serializationManager, where, include),
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
    return _delegate.findFirstRow<T>(
      where: mergeWhereWithTombstone<T>(serializationManager, where, include),
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
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
    return _delegate.findFirstRow<T>(
      where: mergeWhereWithTombstone<T>(serializationManager, where, include),
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
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
  }) async {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.insert<T>(
          rows,
          transaction: tx,
          ignoreConflicts: ignoreConflicts,
        );

        await _recorder.afterInsert<T>(result, tx);
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
        late final T result;
        try {
          result = await _delegate.insertRow<T>(row, transaction: tx);
        } on DatabaseQueryException {
          if (!await _recorder.isDeleted(row, tx)) rethrow;

          result = await _delegate.updateRow<T>(row, transaction: tx);
          await _recorder.afterReinsert([result], tx);
          return result;
        }

        await _recorder.afterInsert([result], tx);
        return result;
      },
    );
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
        return [
          for (final row in rows)
            await updateRow<T>(row, columns: columns, transaction: tx),
        ];
      },
    );
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    final values = row.toJsonForDatabase() as Map<String, dynamic>;
    final columnValues = (columns ?? row.table.managedColumns)
        .where((c) => c.columnName != 'id')
        .map((c) => ColumnValue(c, values[c.columnName]))
        .toList();

    final updatedRows = await updateWhere<T>(
      columnValues: columnValues,
      where: row.table.id.equals(row.id),
      transaction: transaction,
    );

    if (updatedRows.isEmpty) {
      // FIXME: We can't use the proper `DatabaseUpdateRowException` because
      // it is declared as a base type on the `serverpod_database` package.
      throw Exception('Failed to update row, no rows updated.');
    }

    return updatedRows.single;
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
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateWhere<T>(
          columnValues: columnValues,
          where: mergeWhereWithTombstone<T>(serializationManager, where, null)!,
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
          where: mergeWhereWithTombstone<T>(serializationManager, where, null),
          orderBy: orderBy,
          orderByList: orderByList,
          // Remove this once the deprecated member is removed.
          // ignore: deprecated_member_use
          orderDescending: orderDescending,
          transaction: tx,
        );

        await _recorder.insteadOfDelete<T>(rows, tx);
        return rows;
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
      where: mergeWhereWithTombstone<T>(serializationManager, where, null),
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
      where: mergeWhereWithTombstone<T>(serializationManager, where, null)!,
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
    final user = await _recorder.getOrCreateUser(userId);

    return transaction<R>(
      (tx) async {
        try {
          userForTransaction[tx] = user;
          return await transactionFunction(tx);
        } finally {
          userForTransaction.remove(tx);
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

  Caller _requireSyncCaller(Caller? syncCaller) {
    return syncCaller ??
        _syncCaller ??
        (throw StateError(
          'A sync caller is required to use remote sync helpers. '
          'Pass syncCaller when creating the CRDT database session or when '
          'calling syncOnce()/syncContinuously().',
        ));
  }

  Future<Hlc> _zeroSyncHlc(UuidValue userId) async {
    final user = await _recorder.getOrCreateUser(userId);
    return Hlc.zero(user.currentNode!.uuidNodeId);
  }

  Future<CrdtMergeSet?> _collectRemoteChanges(
    Stream<CrdtMergeChange?> remoteStream,
  ) async {
    final inserts = <CrdtMergeInsert>[];
    final updates = <CrdtMergeUpdate>[];
    final deletes = <CrdtMergeDelete>[];
    var receivedStopSentinel = false;

    await for (final change in remoteStream) {
      switch (change) {
        case null:
          receivedStopSentinel = true;
        case final CrdtMergeInsert insert:
          inserts.add(insert);
        case final CrdtMergeUpdate update:
          updates.add(update);
        case final CrdtMergeDelete delete:
          deletes.add(delete);
      }
      if (change == null) break;
    }

    if (!receivedStopSentinel) return null;

    return CrdtMergeSet(
      inserts: inserts,
      updates: updates,
      deletes: deletes,
    );
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
