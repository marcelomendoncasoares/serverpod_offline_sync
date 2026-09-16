// The Database type is implemented here as a test-style proxy; some lints
// flag internal Serverpod APIs used by generated code.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../spaces/membership.dart';
import '../sync/engine.dart';
import '../sync/exceptions.dart';
import '../sync/integrity_violation.dart';
import 'merge_utils/database_helpers.dart';
import 'recorder.dart';
import 'session.dart';
import 'tombstone.dart';

part 'space.dart';

/// Map of transaction hashes to the space they are associated with.
final spaceForTransaction = <Transaction, OfflineSyncSpace>{};

/// Map of transaction hashes to the authenticated user associated with them.
final userForTransaction = <Transaction, UuidValue>{};

/// Database proxy that runs insert/update/delete ORM operations inside a
/// transaction to record each change in the CRDT tables.
class OfflineSyncDatabase implements Database {
  /// Creates a CRDT-aware database wrapper around the inner database.
  OfflineSyncDatabase(
    Database delegate, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Shared CRDT database metadata.
    OfflineSyncDatabaseContext? context,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = OfflineSyncEngine.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = OfflineSyncEngine.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
  }) : this._(
         delegate,
         context ??
             OfflineSyncDatabaseContext(
               syncTables: syncTables,
               serializationManager: delegate.serializationManager,
             ),
         syncTables: syncTables,
         syncBatchSize: syncBatchSize,
         continuousSyncInterval: continuousSyncInterval,
         persistentUserId: persistentUserId,
       );

  OfflineSyncDatabase._(
    this._delegate,
    this._context, {
    required this._syncTables,
    required this._syncBatchSize,
    required this._continuousSyncInterval,
    required UuidValue? persistentUserId,
  }) : _recorder = CrdtMutationRecorder(
         _delegate,
         context: _context,
         persistentUserId: persistentUserId,
       );

  final Database _delegate;
  final OfflineSyncDatabaseContext _context;
  final List<Table> _syncTables;
  final int _syncBatchSize;
  final Duration _continuousSyncInterval;

  final CrdtMutationRecorder _recorder;

  late final _sync = OfflineSyncEngine(
    syncTables: _syncTables,
    serializationManager: serializationManager,
    syncBatchSize: _syncBatchSize,
    continuousSyncInterval: _continuousSyncInterval,
    databaseContext: _context,
  );

  /// Initializes the CRDT database.
  Future<void> initialize() async {
    await _recorder.initialize();
  }

  Future<void> _ensureInitialized() async {
    await _recorder.ensureInitialized();
  }

  /// The hash describing the synchronized schema configured for this database.
  String get syncTablesHash => _sync.currentSyncTablesHash;

  /// Returns the current node identifier for the effective user.
  Future<UuidValue> currentNodeId({UuidValue? userId}) async {
    await _ensureInitialized();
    final effectiveUserId = await _requireUserId(userId);
    final user = await _recorder.getOrCreateSpace(effectiveUserId);
    return user.currentNode!.uuidNodeId;
  }

  /// Runs a symmetric CRDT sync session over a bidirectional event stream.
  Stream<OfflineSyncStreamEvent> sync({
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    UuidValue? userId,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) async* {
    await _ensureInitialized();
    final effectiveUserId = await _requireUserId(userId);
    yield* _sync.sync(
      _delegate.session,
      userId: effectiveUserId,
      inbound: inbound,
      once: once,
      onMergeSuccess: onMergeSuccess,
      mode: mode,
    );
  }

  /// Records the latest acknowledged sync checkpoint for [otherNodeId].
  Future<void> recordSyncCheckpoint(
    UuidValue otherNodeId,
    Hlc syncedHlc, {
    UuidValue? userId,
  }) async {
    await _ensureInitialized();
    final effectiveUserId = await _requireUserId(userId);
    await _recorder.recordSyncCheckpoint(
      effectiveUserId,
      otherNodeId,
      syncedHlc,
    );
  }

  /// Merges remote CRDT changes into the local database for the given space.
  ///
  /// When [spaceId] is omitted, this uses the recorder's persistent user id.
  /// The merge locks the current space's CRDT tables and executes atomically
  /// inside [transactionForUser].
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet, {
    UuidValue? spaceId,
  }) async {
    if (mergeSet.isEmpty) return;
    await _ensureInitialized();

    final effectiveSpaceId =
        spaceId ??
        _recorder.persistentUserId ??
        (throw StateError(
          'A space ID is required when merging changes without a persistent user.',
        ));
    try {
      await transactionForUser<void>(effectiveSpaceId, (tx) async {
        await _recorder.lockCurrentUser(tx);
        await _recorder.mergeChanges(mergeSet, tx);
      });
    } on OfflineSyncIntegrityViolationException catch (exception) {
      final persistedViolation = await recordOfflineSyncIntegrityViolation(
        _delegate.session,
        violation: exception.violation,
      );
      throw OfflineSyncIntegrityViolationException(persistedViolation);
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
  /// tables and the user associated with [transaction] (or the persistent user).
  ///
  /// Read filters are membership-wide. Write filters stay pinned to the acting
  /// space so mutations cannot cross space boundaries.
  Future<Expression?> _whereVisibleWithTombstone<T extends TableRow>(
    Expression? where,
    Include? include,
    Transaction? transaction, {
    required bool membershipWide,
  }) async {
    if (include == null && !_recorder.isCrdtTracked<T>()) return where;

    final spaceIds = await _spaceIdsForQueries(
      transaction,
      membershipWide: membershipWide,
    );
    return mergeWhereWithTombstone<T>(
      serializationManager,
      where,
      include,
      tableIdForName: _recorder.tableIdForName,
      spaceIds: () => spaceIds,
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
    await _ensureInitialized();
    final result = await _delegate.find<T>(
      where: await _whereVisibleWithTombstone<T>(
        where,
        include,
        transaction,
        membershipWide: true,
      ),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    return _stripSpaceIdFromSpaceScopedRead(result, include, transaction);
  }

  @override
  Future<T?> findById<T extends TableRow>(
    Object id, {
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    await _ensureInitialized();
    final table = serializationManager.getTableForType(T);
    final where = table?.id.equals(id);
    final result = await _delegate.findFirstRow<T>(
      where: await _whereVisibleWithTombstone<T>(
        where,
        include,
        transaction,
        membershipWide: true,
      ),
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (result == null) return null;
    return _stripSpaceIdFromSpaceScopedRead([result], include, transaction).single;
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
    await _ensureInitialized();
    final result = await _delegate.findFirstRow<T>(
      where: await _whereVisibleWithTombstone<T>(
        where,
        include,
        transaction,
        membershipWide: true,
      ),
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (result == null) return null;
    return _stripSpaceIdFromSpaceScopedRead([result], include, transaction).single;
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    if (rows.isEmpty) return [];
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return _delegate.insert<T>(
        rows,
        transaction: transaction,
        ignoreConflicts: ignoreConflicts,
        noReturn: noReturn,
      );
    }
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final prepared = _prepareRowsForInsert(rows, tx);
        final deletedRowIds = await _recorder.deletedRowIds(prepared.rows, tx);
        final rowsToInsert = [
          for (final row in prepared.rows)
            if (!deletedRowIds.contains(row.id)) row,
        ];
        final plannedInsert = await _recorder.planLocalInserts(rowsToInsert, tx);

        // Tracked rows can only skip RETURNING when the prepared rows are
        // exactly what gets inserted: every id is caller-provided and a
        // conflict throws instead of silently dropping rows.
        final skipReturn =
            noReturn && !ignoreConflicts && !rows.any((row) => row.id == null);

        final result = plannedInsert.rows.isEmpty
            ? <T>[]
            : await insertWithExplicitNulls<T>(
                _delegate,
                plannedInsert.rows,
                explicitNulls: {
                  for (final row in plannedInsert.rows)
                    if ({
                          for (final column in row.table.crdtSyncableColumns)
                            if (column.hasDefault &&
                                row.id != null &&
                                plannedInsert.attempts.containsKey((
                                  row.table.tableName,
                                  row.id as UuidValue,
                                  column.columnName,
                                )) &&
                                (row.toJsonForDatabase() as Map)[column.columnName] ==
                                    null)
                              column.columnName,
                        }
                        case final columns when columns.isNotEmpty)
                      row.id as UuidValue: columns,
                },
                transaction: tx,
                ignoreConflicts: ignoreConflicts,
                noReturn: skipReturn,
              );

        final insertedRows = skipReturn ? plannedInsert.rows : result;
        await _recorder.afterInsert<T>(
          insertedRows,
          tx,
          attempts: plannedInsert.attempts,
        );

        final reinsertedRows = await _reinsertTombstonedRows(
          prepared.rows,
          insertedRows,
          tx,
          deletedRowIds: deletedRowIds,
        );
        if (noReturn) return <T>[];

        final affectedRows = _orderAffectedRows(
          prepared.rows,
          insertedRows,
          reinsertedRows,
        );
        _stripStampedRows(affectedRows, prepared);
        return affectedRows;
      },
    );
  }

  @override
  Future<T> insertRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) async {
    return (await insert<T>([row], transaction: transaction)).single;
  }

  @override
  Future<List<T>> upsert<T extends TableRow>(
    List<T> rows, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
    bool noReturn = false,
  }) async {
    if (rows.isEmpty) return [];
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return _delegate.upsert<T>(
        rows,
        conflictColumns: conflictColumns,
        updateColumns: updateColumns,
        updateWhere: updateWhere,
        transaction: transaction,
        noReturn: noReturn,
      );
    }
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final prepared = _prepareRowsForInsert(rows, tx);
        final values = _recorder.withForeignKeyInsertDefaults(prepared.rows);
        final projectionUnchanged = await _recorder.prepareLocalUpsert(
          values,
          conflictColumns,
          updateColumns,
          tx,
        );

        // CRDT metadata needs the affected rows even when the public call uses
        // noReturn, because inserted rows may have database-generated ids.
        final result = await _delegate.upsert<T>(
          values,
          conflictColumns: conflictColumns,
          updateColumns: updateColumns,
          updateWhere: await _whereVisibleWithTombstone<T>(
            updateWhere,
            null,
            tx,
            membershipWide: false,
          ),
          transaction: tx,
        );

        final reinsertedRows = await _reinsertTombstonedRows(
          prepared.rows,
          result,
          tx,
        );

        final insertedRows = await _rowsWithoutCrdtMetadata(result, tx);
        await _recorder.afterInsert(insertedRows, tx);

        final insertedRowIds = {
          for (final row in insertedRows)
            if (row.id is UuidValue) row.id as UuidValue,
        };
        final updatedRows = [
          for (final row in result)
            if (row.id is! UuidValue || !insertedRowIds.contains(row.id)) row,
        ];
        await _recorder.afterUpdate(
          updatedRows,
          updateColumns,
          tx,
          projectionUnchanged: projectionUnchanged,
        );
        if (noReturn) return <T>[];
        _stripStampedRows(result, prepared);
        for (final row in reinsertedRows) {
          final rowId = row.id;
          if (rowId == null || !prepared.explicitRowIds.contains(rowId)) {
            _stripSpaceId(row);
          }
        }
        return [...result, ...reinsertedRows];
      },
    );
  }

  /// Reinserts upserted rows whose conflict target is a tombstoned row.
  ///
  /// The visibility filter merged into `updateWhere` keeps the delegate upsert
  /// from updating hidden rows, so they come back missing from [result]. From
  /// the caller's perspective a deleted row does not exist, so the upsert must
  /// behave as an insert: the domain row is overwritten with the incoming
  /// values — ignoring `updateColumns` and `updateWhere` — and the tombstone
  /// is lifted, mirroring the [insertRow] reinsert path.
  Future<List<T>> _reinsertTombstonedRows<T extends TableRow>(
    List<T> preparedRows,
    List<T> result,
    Transaction transaction, {
    Set<UuidValue>? deletedRowIds,
  }) async {
    final returnedIds = <Object>{
      for (final row in result)
        if (row.id != null) row.id as Object,
    };

    final missingRows = [
      for (final row in preparedRows)
        if (row.id case final rowId? when !returnedIds.contains(rowId)) row,
    ];
    deletedRowIds ??= await _recorder.deletedRowIds(missingRows, transaction);
    final rowsToReinsert = [
      for (final row in missingRows)
        if (deletedRowIds.contains(row.id)) row,
    ];
    if (rowsToReinsert.isEmpty) return [];

    final plannedReinserts = await _recorder.planLocalUpdates(
      rowsToReinsert,
      null,
      transaction,
    );
    final reinsertedRows = await _delegate.update<T>(
      plannedReinserts.rows,
      transaction: transaction,
    );
    await _recorder.afterReinsert(reinsertedRows, transaction);
    return reinsertedRows;
  }

  List<T> _orderAffectedRows<T extends TableRow>(
    List<T> preparedRows,
    List<T> insertedRows,
    List<T> reinsertedRows,
  ) {
    if (insertedRows.length + reinsertedRows.length != preparedRows.length) {
      return [...insertedRows, ...reinsertedRows];
    }

    final reinsertedIds = {for (final row in reinsertedRows) row.id};
    final inserted = insertedRows.iterator;
    final reinserted = reinsertedRows.iterator;
    return [
      for (final row in preparedRows)
        reinsertedIds.contains(row.id)
            ? (reinserted..moveNext()).current
            : (inserted..moveNext()).current,
    ];
  }

  Future<List<T>> _rowsWithoutCrdtMetadata<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return [];

    final rowIds = {
      for (final row in rows)
        if (row.id is UuidValue) row.id as UuidValue,
    };
    if (rowIds.isEmpty) return [];

    final tableId = _recorder.tableIdForName(rows.first.table.tableName)!;
    final spaceId = _requireEffectiveSpace(transaction).id!;
    final crdtRows = await CrdtDataRow.db.find(
      _delegate.session,
      where: (t) =>
          t.spaceId.equals(spaceId) &
          t.tblId.equals(tableId) &
          t.uuidRowId.inSet(rowIds),
      transaction: transaction,
    );
    final existingRowIds = crdtRows.map((row) => row.uuidRowId).toSet();

    return [
      for (final row in rows)
        if (row.id is UuidValue && !existingRowIds.contains(row.id)) row,
    ];
  }

  @override
  Future<T?> upsertRow<T extends TableRow>(
    T row, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) async {
    await _ensureInitialized();
    final result = await upsert<T>(
      [row],
      conflictColumns: conflictColumns,
      updateColumns: updateColumns,
      updateWhere: updateWhere,
      transaction: transaction,
    );
    if (result.length > 1) {
      throw DatabaseUnexpectedResultException(
        'Failed to upsert row, affected number of rows is ${result.length} != 1',
      );
    }
    return result.firstOrNull;
  }

  @override
  Future<List<T>> update<T extends TableRow>(
    List<T> rows, {
    List<Column>? columns,
    Transaction? transaction,
    bool noReturn = false,
  }) async {
    if (rows.isEmpty) return [];
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return _delegate.update<T>(
        rows,
        columns: columns,
        transaction: transaction,
        noReturn: noReturn,
      );
    }
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final plannedUpdates = await _recorder.planLocalUpdates(rows, columns, tx);
        final updatedRows = [
          for (final row in plannedUpdates.rows)
            await _updateRowWithoutRecording(
              row,
              stripSpaceId: _shouldStripReturnedSpaceId(row, tx),
              transaction: tx,
              columns: columns,
            ),
        ];

        await _recorder.afterUpdate(
          updatedRows,
          columns,
          tx,
          projectionUnchanged: plannedUpdates.projectionUnchanged,
        );
        return noReturn ? <T>[] : updatedRows;
      },
    );
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>(row.table)) {
      return _delegate.updateRow<T>(
        row,
        columns: columns,
        transaction: transaction,
      );
    }
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final plannedUpdates = await _recorder.planLocalUpdates([row], columns, tx);
        final stripSpaceId = _shouldStripReturnedSpaceId(row, tx);
        final updatedRow = await _updateRowWithoutRecording(
          plannedUpdates.rows.single,
          stripSpaceId: stripSpaceId,
          transaction: tx,
          columns: columns,
        );

        await _recorder.afterUpdate(
          [updatedRow],
          columns,
          tx,
          projectionUnchanged: plannedUpdates.projectionUnchanged,
        );
        return updatedRow;
      },
    );
  }

  Future<T> _updateRowWithoutRecording<T extends TableRow>(
    T row, {
    required Transaction transaction,
    required bool stripSpaceId,
    List<Column>? columns,
  }) async {
    final values = row.toJsonForDatabase() as Map<String, dynamic>;
    final columnValues = (columns ?? row.table.managedColumns).crdtSyncableColumns
        .map((c) => ColumnValue(c, values[c.columnName]))
        .toList();

    final where = row.table.id.equals(row.id);
    final updatedRows = await _delegate.updateWhere<T>(
      columnValues: columnValues,
      where: (await _whereVisibleWithTombstone<T>(
        where,
        null,
        transaction,
        membershipWide: false,
      ))!,
      transaction: transaction,
    );

    if (updatedRows.isEmpty) {
      throw DatabaseUnexpectedResultException(
        'Failed to update row, no rows updated',
      );
    }

    final updatedRow = updatedRows.single;
    if (stripSpaceId) _stripSpaceId(updatedRow);
    return updatedRow;
  }

  @override
  Future<T?> updateById<T extends TableRow>(
    Object id, {
    required List<ColumnValue> columnValues,
    Transaction? transaction,
  }) async {
    await _ensureInitialized();
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
    bool noReturn = false,
  }) async {
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>()) {
      return _delegate.updateWhere<T>(
        columnValues: columnValues,
        where: where,
        limit: limit,
        offset: offset,
        orderBy: orderBy,
        orderByList: orderByList,
        transaction: transaction,
        noReturn: noReturn,
      );
    }

    _assertNoSpaceIdColumnValues<T>(columnValues);
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateWhere<T>(
          columnValues: columnValues,
          where: (await _whereVisibleWithTombstone<T>(
            where,
            null,
            tx,
            membershipWide: false,
          ))!,
          limit: limit,
          offset: offset,
          orderBy: orderBy,
          orderByList: orderByList,
          transaction: tx,
        );

        final columns = columnValues.map((e) => e.column).toList();
        await _recorder.afterUpdate(result, columns, tx);
        if (noReturn) return <T>[];
        result.forEach(_stripSpaceId);
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
    bool noReturn = false,
  }) async {
    if (rows.isEmpty) return [];
    await _ensureInitialized();
    return deleteWhere<T>(
      where: rows.first.table.id.inSet(
        rows.map((row) => row.id).castToIdType().toSet(),
      ),
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  @override
  Future<T> deleteRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) async {
    await _ensureInitialized();
    final deletedRows = await deleteWhere<T>(
      where: row.table.id.equals(row.id),
      transaction: transaction,
    );

    if (deletedRows.isEmpty) {
      throw DatabaseUnexpectedResultException(
        'Failed to delete row, no rows deleted.',
      );
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
    bool noReturn = false,
  }) async {
    await _ensureInitialized();
    if (!_recorder.isCrdtTracked<T>()) {
      return _delegate.deleteWhere<T>(
        where: where,
        orderBy: orderBy,
        orderByList: orderByList,
        transaction: transaction,
        noReturn: noReturn,
      );
    }

    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final rows = await _delegate.find<T>(
          where: await _whereVisibleWithTombstone<T>(
            where,
            null,
            tx,
            membershipWide: false,
          ),
          orderBy: orderBy,
          orderByList: orderByList,
          transaction: tx,
        );

        await _recorder.insteadOfDelete<T>(rows, tx);
        if (noReturn) return <T>[];
        return _stripSpaceIdFromSpaceScopedRead(rows, null, tx);
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
    await _ensureInitialized();
    return _delegate.count<T>(
      where: await _whereVisibleWithTombstone<T>(
        where,
        null,
        transaction,
        membershipWide: true,
      ),
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
    await _ensureInitialized();
    return _delegate.lockRows<T>(
      where: (await _whereVisibleWithTombstone<T>(
        where,
        null,
        transaction,
        membershipWide: false,
      ))!,
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
    // Do not initialize CRDT here. Serverpod runs database migrations inside
    // [transaction] before CRDT tables exist. Callers that need CRDT state
    // ([transactionForUser], mutating ORM methods) initialize explicitly.
    return _delegate.transaction(
      transactionFunction,
      settings: settings,
    );
  }

  /// Executes the [transactionFunction] in a transaction with the provided [userId].
  ///
  /// Without [spaceId], writes act in the user's personal space. With [spaceId],
  /// [userId] stays the authenticated identity and [spaceId] is the space being
  /// acted in; the pair is checked before the transaction starts.
  Future<R> transactionForUser<R>(
    UuidValue userId,
    TransactionFunction<R> transactionFunction, {
    UuidValue? spaceId,
    TransactionSettings? settings,
  }) async {
    await _ensureInitialized();
    final effectiveSpaceId = spaceId ?? userId;
    await _assertCanActInSpace(userId, effectiveSpaceId);

    // Ensure that the space exists with a node before starting the transaction.
    final space = await _recorder.getOrCreateSpace(effectiveSpaceId);

    return transaction<R>(
      (tx) async {
        try {
          spaceForTransaction[tx] = space;
          userForTransaction[tx] = userId;
          return await transactionFunction(tx);
        } finally {
          spaceForTransaction.remove(tx);
          userForTransaction.remove(tx);
        }
      },
      settings: settings,
    );
  }

  Future<void> _assertCanActInSpace(UuidValue userId, UuidValue spaceId) async {
    if (userId == spaceId) return;

    // Authoritative membership: the source of truth on the server, the
    // read-only cache on a follower (empty until populated). A null role means
    // no membership row at all; a non-writable role means membership without
    // write access.
    final role = await OfflineSyncSpaceMembership.roleOf(
      _delegate.session,
      userUuid: userId,
      spaceUuid: spaceId,
    );
    if (role == null) {
      throw OfflineSyncSpaceMembershipException(userId: userId, spaceId: spaceId);
    }
    if (!role.canWrite) {
      throw OfflineSyncSpaceRoleException(userId: userId, spaceId: spaceId, role: role);
    }
  }

  Future<List<int>?> _spaceIdsForQueries(
    Transaction? transaction, {
    required bool membershipWide,
  }) async {
    if (!membershipWide) {
      return _actingSpaceIdsForQueries(transaction);
    }

    final userId = _userIdForQueries(transaction);
    if (userId == null) return null;

    // On the server this is authoritative membership; on a persistent client it
    // is the server-projected membership cache.
    final spaceGroups = await Future.wait<List<OfflineSyncSpace>>([
      OfflineSyncSpace.db.find(
        _delegate.session,
        where: (t) => t.uuidSpaceId.equals(userId),
      ),
      OfflineSyncSpaceMember.db
          .find(
            _delegate.session,
            where: (t) => t.userUuid.equals(userId),
            include: OfflineSyncSpaceMember.include(space: OfflineSyncSpace.include()),
          )
          .then((memberships) => [for (final member in memberships) member.space!]),
    ]);
    return {
      for (final spaces in spaceGroups)
        for (final space in spaces) space.id!,
    }.toList();
  }

  List<int>? _actingSpaceIdsForQueries(Transaction? transaction) {
    final spaceId = _recorder.spaceForQueries(transaction)?.id;
    return spaceId == null ? null : [spaceId];
  }

  UuidValue? _userIdForQueries(Transaction? transaction) {
    if (transaction != null) {
      final userId = userForTransaction[transaction];
      if (userId != null) return userId;
    }
    return _recorder.persistentUserId;
  }

  Future<UuidValue> _requireUserId(UuidValue? userId) async {
    return userId ??
        _recorder.persistentUserId ??
        (throw StateError(
          'A user ID is required when syncing without a persistent user.',
        ));
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
