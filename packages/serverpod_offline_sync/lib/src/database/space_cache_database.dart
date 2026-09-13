import 'dart:async';

import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import 'session.dart';
import 'space_cache.dart';

/// Intercepts space metadata mutations and unwraps cache-aware transactions.
@internal
class OfflineSyncSpaceCacheDatabase implements Database {
  OfflineSyncSpaceCacheDatabase(this.inner, this.cache);

  static final _coordinatedMutation = Object();

  final Database inner;
  final OfflineSyncSpaceCache cache;

  @override
  DatabaseDialect get dialect => inner.dialect;

  @override
  DatabaseSerializationManager get serializationManager => inner.serializationManager;

  @override
  DatabaseAnalyzer get analyzer => inner.analyzer;

  Future<List<int>> spaceIds(UuidValue user, Transaction transaction) {
    if (OfflineSyncSpaceTransaction.of(transaction) case final managed?) {
      return managed.spaceIds(user);
    }
    return loadSpaceIds(inner, user, transaction);
  }

  Future<R> _mutate<R>(
    String? table,
    Transaction? transaction,
    Future<R> Function(Transaction? transaction) action,
  ) {
    if (transaction != null &&
        identical(
          Zone.current[_coordinatedMutation],
          spaceInnerTransaction(transaction),
        )) {
      return action(spaceInnerTransaction(transaction));
    }
    if (table == 'offline_sync_space_cache_versions') {
      throw StateError('Space cache revisions are maintained by the database wrapper.');
    }
    if (table != 'offline_sync_spaces' && table != 'offline_sync_space_members') {
      return action(spaceInnerTransaction(transaction));
    }
    return DatabaseUtil.runInTransactionOrSavepoint(
      this,
      transaction,
      (tx) => runZoned(() async {
        final managed = OfflineSyncSpaceTransaction.of(tx);
        final raw = spaceInnerTransaction(tx)!;
        final revision = managed != null
            ? await managed.lock(forWrite: true)
            : await lockSpaceCacheVersion(inner, raw, forWrite: true);
        final result = await action(raw);
        await OfflineSyncSpaceCacheVersion.db.updateRow(
          inner.session,
          OfflineSyncSpaceCacheVersion(
            id: 1,
            databaseUuid: revision.$1,
            revision: revision.$2 + 1,
          ),
          columns: (t) => [t.revision],
          transaction: raw,
        );
        managed?.changed((revision.$1, revision.$2 + 1));
        return result;
      }, zoneValues: {_coordinatedMutation: spaceInnerTransaction(tx)}),
    );
  }

  @override
  Future<R> transaction<R>(
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async {
    OfflineSyncSpaceTransaction? owned;
    try {
      final result = await inner.transaction((tx) {
        final existing = OfflineSyncSpaceTransaction.of(tx);
        if (existing != null) return transactionFunction(existing);
        owned = OfflineSyncSpaceTransaction(tx, inner, cache);
        return transactionFunction(owned!);
      }, settings: settings);
      owned?.commit();
      return result;
    } finally {
      owned?.close();
    }
  }

  @override
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    return inner.find<T>(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: spaceInnerTransaction(transaction),
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
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) {
    return inner.findFirstRow<T>(
      where: where,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      transaction: spaceInnerTransaction(transaction),
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
  }) {
    return inner.findById<T>(
      id,
      transaction: spaceInnerTransaction(transaction),
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<void> lockRows<T extends TableRow>({
    required Expression where,
    required LockMode lockMode,
    required Transaction transaction,
    LockBehavior lockBehavior = LockBehavior.wait,
  }) {
    return inner.lockRows<T>(
      where: where,
      lockMode: lockMode,
      transaction: spaceInnerTransaction(transaction)!,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<List<T>> update<T extends TableRow>(
    List<T> rows, {
    List<Column>? columns,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    return _mutate(
      rows.firstOrNull?.table.tableName,
      transaction,
      (raw) =>
          inner.update<T>(rows, columns: columns, transaction: raw, noReturn: noReturn),
    );
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) {
    return _mutate(
      row.table.tableName,
      transaction,
      (raw) => inner.updateRow<T>(row, columns: columns, transaction: raw),
    );
  }

  @override
  Future<T?> updateById<T extends TableRow>(
    Object id, {
    required List<ColumnValue> columnValues,
    Transaction? transaction,
  }) {
    return _mutate(
      serializationManager.getTableForType(T)?.tableName,
      transaction,
      (raw) => inner.updateById<T>(id, columnValues: columnValues, transaction: raw),
    );
  }

  @override
  Future<List<T>> updateWhere<T extends TableRow>({
    required List<ColumnValue> columnValues,
    required Expression where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    return _mutate(
      serializationManager.getTableForType(T)?.tableName,
      transaction,
      (raw) => inner.updateWhere<T>(
        columnValues: columnValues,
        where: where,
        limit: limit,
        offset: offset,
        orderBy: orderBy,
        orderByList: orderByList,
        transaction: raw,
        noReturn: noReturn,
      ),
    );
  }

  @override
  Future<List<T>> insert<T extends TableRow>(
    List<T> rows, {
    Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) {
    return _mutate(
      rows.firstOrNull?.table.tableName,
      transaction,
      (raw) => inner.insert<T>(
        rows,
        transaction: raw,
        ignoreConflicts: ignoreConflicts,
        noReturn: noReturn,
      ),
    );
  }

  @override
  Future<T> insertRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) {
    return _mutate(
      row.table.tableName,
      transaction,
      (raw) => inner.insertRow<T>(row, transaction: raw),
    );
  }

  @override
  Future<List<T>> upsert<T extends TableRow>(
    List<T> rows, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    return _mutate(
      rows.firstOrNull?.table.tableName,
      transaction,
      (raw) => inner.upsert<T>(
        rows,
        conflictColumns: conflictColumns,
        updateColumns: updateColumns,
        updateWhere: updateWhere,
        transaction: raw,
        noReturn: noReturn,
      ),
    );
  }

  @override
  Future<T?> upsertRow<T extends TableRow>(
    T row, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) {
    return _mutate(
      row.table.tableName,
      transaction,
      (raw) => inner.upsertRow<T>(
        row,
        conflictColumns: conflictColumns,
        updateColumns: updateColumns,
        updateWhere: updateWhere,
        transaction: raw,
      ),
    );
  }

  @override
  Future<List<T>> delete<T extends TableRow>(
    List<T> rows, {
    Column? orderBy,
    List<Column>? orderByList,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    return _mutate(
      rows.firstOrNull?.table.tableName,
      transaction,
      (raw) => inner.delete<T>(
        rows,
        orderBy: orderBy,
        orderByList: orderByList,
        transaction: raw,
        noReturn: noReturn,
      ),
    );
  }

  @override
  Future<T> deleteRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) {
    return _mutate(
      row.table.tableName,
      transaction,
      (raw) => inner.deleteRow<T>(row, transaction: raw),
    );
  }

  @override
  Future<List<T>> deleteWhere<T extends TableRow>({
    required Expression where,
    Column? orderBy,
    List<Column>? orderByList,
    Transaction? transaction,
    bool noReturn = false,
  }) {
    return _mutate(
      serializationManager.getTableForType(T)?.tableName,
      transaction,
      (raw) => inner.deleteWhere<T>(
        where: where,
        orderBy: orderBy,
        orderByList: orderByList,
        transaction: raw,
        noReturn: noReturn,
      ),
    );
  }

  @override
  Future<int> count<T extends TableRow>({
    Expression? where,
    int? limit,
    bool useCache = true,
    Transaction? transaction,
  }) {
    return inner.count<T>(
      where: where,
      limit: limit,
      useCache: useCache,
      transaction: spaceInnerTransaction(transaction),
    );
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) {
    return inner.unsafeQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: spaceInnerTransaction(transaction),
      parameters: parameters,
    );
  }

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) {
    return inner.unsafeExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: spaceInnerTransaction(transaction),
      parameters: parameters,
    );
  }

  @override
  Future<DatabaseResult> unsafeSimpleQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) {
    return inner.unsafeSimpleQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: spaceInnerTransaction(transaction),
    );
  }

  @override
  Future<int> unsafeSimpleExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) {
    return inner.unsafeSimpleExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: spaceInnerTransaction(transaction),
    );
  }

  @override
  Future<bool> testConnection() {
    return inner.testConnection();
  }
}
