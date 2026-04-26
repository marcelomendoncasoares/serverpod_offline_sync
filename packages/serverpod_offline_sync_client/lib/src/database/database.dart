// The Database type is implemented here as a test-style proxy; some lints
// flag internal Serverpod APIs used by generated code.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../crdt/user.dart';
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
  }) : _recorder = CrdtMutationRecorder(
         _delegate,
         persistentUserId: persistentUserId,
         syncTables: syncTables,
       );

  final Database _delegate;

  final CrdtMutationRecorder _recorder;

  /// Initializes the CRDT database.
  Future<void> initialize() async {
    await _recorder.initialize();
  }

  DatabaseSession get _session => BasicDatabaseSession(this);

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
  }) {
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
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.insertRow<T>(
          row,
          transaction: tx,
        );

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
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.update<T>(
          rows,
          columns: columns,
          transaction: tx,
        );

        await _recorder.afterUpdate<T>(result, columns, tx);
        return result;
      },
    );
  }

  @override
  Future<T> updateRow<T extends TableRow>(
    T row, {
    List<Column>? columns,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateRow<T>(
          row,
          columns: columns,
          transaction: tx,
        );

        await _recorder.afterUpdate([result], columns, tx);
        return result;
      },
    );
  }

  @override
  Future<T?> updateById<T extends TableRow>(
    Object id, {
    required List<ColumnValue> columnValues,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateById<T>(
          id,
          columnValues: columnValues,
          transaction: tx,
        );

        if (result != null) {
          final columns = columnValues.map((e) => e.column).toList();
          await _recorder.afterUpdate([result], columns, tx);
        }
        return result;
      },
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
  }) {
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
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        if (!_domainTableHasUuidPrimaryKey<T>(serializationManager)) {
          final result = await _delegate.delete<T>(
            rows,
            transaction: tx,
            orderBy: orderBy,
            orderByList: orderByList,
            // Remove this once the deprecated member is removed.
            // ignore: deprecated_member_use
            orderDescending: orderDescending,
          );
          await _recorder.afterDelete<T>(result, tx);
          return result;
        }
        if (rows.isEmpty) return [];
        await _recorder.markDomainRowsDeleted(rows, tx);
        return rows;
      },
    );
  }

  @override
  Future<T> deleteRow<T extends TableRow>(
    T row, {
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        if (!_domainTableHasUuidPrimaryKey<T>(serializationManager)) {
          final result = await _delegate.deleteRow<T>(
            row,
            transaction: tx,
          );
          await _recorder.afterDelete([result], tx);
          return result;
        }
        await _recorder.markDomainRowsDeleted([row], tx);
        return row;
      },
    );
  }

  @override
  Future<List<T>> deleteWhere<T extends TableRow>({
    required Expression where,
    Column? orderBy,
    List<Column>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        if (!_domainTableHasUuidPrimaryKey<T>(serializationManager)) {
          final result = await _delegate.deleteWhere<T>(
            where: where,
            orderBy: orderBy,
            orderByList: orderByList,
            // Remove this once the deprecated member is removed.
            // ignore: deprecated_member_use
            orderDescending: orderDescending,
            transaction: tx,
          );
          await _recorder.afterDelete(result, tx);
          return result;
        }
        final rows = await _delegate.find<T>(
          where: mergeWhereWithTombstone<T>(serializationManager, where, null),
          transaction: tx,
        );
        if (rows.isEmpty) return [];
        await _recorder.markDomainRowsDeleted(rows, tx);
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
  }) {
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
  }) {
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
  }) {
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
    final user = await CrdtUserManager.getOrCreate(_session, userId);

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

  @override
  Future<int> unsafeExecute(
    String query, {
    int? timeoutInSeconds,
    Transaction? transaction,
    QueryParameters? parameters,
  }) {
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
  }) {
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
  }) {
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
  }) {
    return _delegate.unsafeSimpleQuery(
      query,
      timeoutInSeconds: timeoutInSeconds,
      transaction: transaction,
    );
  }

  @override
  Future<bool> testConnection() => _delegate.testConnection();
}

bool _domainTableHasUuidPrimaryKey<T extends TableRow>(
  DatabaseSerializationManager serializationManager,
) {
  final table = serializationManager.getTableForType(T);
  return table != null && table.id is ColumnUuid;
}
