// Query-counting Database proxy used to report merge query volumes.

import 'package:serverpod_database/serverpod_database.dart';

/// Database proxy that counts every database operation it delegates.
///
/// Each counted operation maps to one query issued by the caller (finds,
/// inserts, updates, deletes, locks and unsafe statements). Transaction
/// control ([transaction] itself) and metadata getters are not counted.
class QueryCountingDatabase implements Database {
  /// Creates a [QueryCountingDatabase] wrapping the [_delegate] database.
  QueryCountingDatabase(this._delegate);

  final Database _delegate;

  /// Number of database operations delegated so far.
  int queryCount = 0;

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
    queryCount++;
    return _delegate.find<T>(
      where: where,
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
    queryCount++;
    return _delegate.findById<T>(
      id,
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
    queryCount++;
    return _delegate.findFirstRow<T>(
      where: where,
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
    queryCount++;
    return _delegate.insert<T>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
    );
  }

  @override
  Future<T> insertRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.insertRow<T>(row, transaction: transaction);
  }

  @override
  Future<List<T>> upsert<T extends TableRow>(
    List<T> rows, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.upsert<T>(
      rows,
      conflictColumns: conflictColumns,
      updateColumns: updateColumns,
      updateWhere: updateWhere,
      transaction: transaction,
    );
  }

  @override
  Future<T?> upsertRow<T extends TableRow>(
    T row, {
    required List<Column> conflictColumns,
    List<Column>? updateColumns,
    Expression? updateWhere,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.upsertRow<T>(
      row,
      conflictColumns: conflictColumns,
      updateColumns: updateColumns,
      updateWhere: updateWhere,
      transaction: transaction,
    );
  }

  @override
  Future<List<T>> update<T extends TableRow>(
    List<T> rows, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.update<T>(rows, columns: columns, transaction: transaction);
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.updateRow<T>(row, columns: columns, transaction: transaction);
  }

  @override
  Future<T?> updateById<T extends TableRow>(
    Object id, {
    required List<ColumnValue> columnValues,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.updateById<T>(
      id,
      columnValues: columnValues,
      transaction: transaction,
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
    bool orderDescending = false,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.updateWhere<T>(
      columnValues: columnValues,
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      // Remove this once the deprecated member is removed.
      // ignore: deprecated_member_use
      orderDescending: orderDescending,
      transaction: transaction,
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
    queryCount++;
    return _delegate.delete<T>(
      rows,
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
    queryCount++;
    return _delegate.deleteRow<T>(row, transaction: transaction);
  }

  @override
  Future<List<T>> deleteWhere<T extends TableRow>({
    required Expression where,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) async {
    queryCount++;
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

  @override
  Future<int> count<T extends TableRow>({
    Expression? where,
    int? limit,
    bool useCache = true,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.count<T>(
      where: where,
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
    queryCount++;
    return _delegate.lockRows<T>(
      where: where,
      lockMode: lockMode,
      transaction: transaction,
      lockBehavior: lockBehavior,
    );
  }

  @override
  Future<DatabaseResult> unsafeQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    queryCount++;
    return _delegate.unsafeQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
      parameters: parameters,
    );
  }

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) async {
    queryCount++;
    return _delegate.unsafeExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
      parameters: parameters,
    );
  }

  @override
  Future<DatabaseResult> unsafeSimpleQuery(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.unsafeSimpleQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
    );
  }

  @override
  Future<int> unsafeSimpleExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
  }) async {
    queryCount++;
    return _delegate.unsafeSimpleExecute(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
    );
  }

  @override
  Future<R> transaction<R>(
    TransactionFunction<R> transactionFunction, {
    TransactionSettings? settings,
  }) async {
    return _delegate.transaction(transactionFunction, settings: settings);
  }

  @override
  Future<bool> testConnection() => _delegate.testConnection();
}
