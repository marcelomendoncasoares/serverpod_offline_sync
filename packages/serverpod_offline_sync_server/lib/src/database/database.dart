// The Database type is implemented here as a test-style proxy; some lints
// flag internal Serverpod APIs used by generated code.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'recorder.dart';
import 'session.dart';
import 'transaction.dart';

/// Database proxy that runs insert/update/delete ORM operations inside a
/// transaction to record each change in the CRDT tables.
class CrdtDatabase implements Database {
  /// Creates a CRDT-aware database wrapper around the inner database.
  CrdtDatabase(
    this._delegate, {
    required this.persistentUserId,
    required CrdtMutationRecorder Function(Database) recorder,
  }) : _recorder = recorder(_delegate);

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  final Database _delegate;

  final CrdtMutationRecorder _recorder;

  /// Internal sessions used for operations with CRDT tables.
  late final _delegateSession = CrdtDatabaseSession(_delegate);

  @override
  DatabaseAnalyzer get analyzer => _delegate.analyzer;

  @override
  DatabaseDialect get dialect => _delegate.dialect;

  @override
  SerializationManagerServer get serializationManager => _delegate.serializationManager;

  @override
  Future<List<T>> find<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Order>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    void applyTombstoneToIncludeLists(Include? include) {
      switch (include) {
        case null:
          return;
        case IncludeList():
          include.where = _notDeletedWhere(include.table, include.where);
          applyTombstoneToIncludeLists(include.include);
          return;
        case IncludeObject():
          include.includes.values.forEach(applyTombstoneToIncludeLists);
      }
    }

    applyTombstoneToIncludeLists(include);
    return _delegate.find<T>(
      where: _notDeletedWhere<T>(null, where),
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Join path: domain row PK (UUID) = `crdt_data_rows.rowId`, then
  /// `crdt_data_rows.id` = `crdt_data_tombstone.rowId`, same as generated `CrdtDataRow.deleted`.
  Expression _notDeletedWhere<T extends TableRow>(Table? table, Expression? where) {
    final targetTable = table ?? serializationManager.getTableForType(T)!;
    final crdtRowTable = createRelationTable<CrdtDataRowTable>(
      relationFieldName: '${targetTable.tableName}_crdt_row',
      field: targetTable.id,
      foreignField: CrdtDataRow.t.rowId,
      tableRelation: targetTable.tableRelation,
      createTable: (foreignTableRelation) =>
          CrdtDataRowTable(tableRelation: foreignTableRelation),
    );
    return _andWhere(where, ~crdtRowTable.deleted.isDeleted.equals(true));
  }

  Expression _andWhere(Expression? where, Expression addition) {
    if (where == null) return addition;
    return where & addition;
  }

  @override
  Future<T?> findById<T extends TableRow>(
    Object id, {
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    return _filterDeletedRow(
      await _delegate.findById<T>(
        id,
        transaction: transaction,
        include: include,
        lockMode: lockMode,
        lockBehavior: lockBehavior,
      ),
    );
  }

  @override
  Future<T?> findFirstRow<T extends TableRow>({
    Expression? where,
    int? offset,
    Column? orderBy,
    List<Order>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
    Include? include,
    LockMode? lockMode,
    LockBehavior? lockBehavior,
  }) async {
    return _filterDeletedRow(
      await _delegate.findFirstRow<T>(
        where: where,
        offset: offset,
        orderBy: orderBy,
        orderByList: orderByList,
        orderDescending: orderDescending,
        transaction: transaction,
        include: include,
        lockMode: lockMode,
        lockBehavior: lockBehavior,
      ),
    );
  }

  /// Removes a single row that is marked as deleted in the CRDT tombstone table.
  Future<T?> _filterDeletedRow<T extends TableRow>(
    T? row,
  ) async {
    if (row == null) return null;
    return _filterDeletedRows([row]).then((rows) => rows.firstOrNull);
  }

  /// Removes rows that are marked as deleted in the CRDT tombstone table.
  Future<List<T>> _filterDeletedRows<T extends TableRow>(
    List<T> rows,
  ) async {
    final deletedRows = await CrdtDataRow.db.find(
      _delegateSession,
      where: (t) =>
          t.rowId.inSet(rows.map((row) => row.id as UuidValue).toSet()) &
          t.deleted.isDeleted.equals(true),
    );
    final deletedRowIds = deletedRows.map((row) => row.rowId).toSet();
    return rows.where((row) => !deletedRowIds.contains(row.id)).toList();
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
    List<Order>? orderByList,
    bool orderDescending = false,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.updateWhere<T>(
          columnValues: columnValues,
          where: where,
          limit: limit,
          offset: offset,
          orderBy: orderBy,
          orderByList: orderByList,
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
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.delete<T>(
          rows,
          transaction: tx,
        );

        await _recorder.afterDelete<T>(result, tx);
        return result;
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
        final result = await _delegate.deleteRow<T>(
          row,
          transaction: tx,
        );

        await _recorder.afterDelete([result], tx);
        return result;
      },
    );
  }

  @override
  Future<List<T>> deleteWhere<T extends TableRow>({
    required Expression where,
    Transaction? transaction,
  }) {
    return DatabaseUtil.runInTransactionOrSavepoint(
      _delegate,
      transaction,
      (tx) async {
        final result = await _delegate.deleteWhere<T>(
          where: where,
          transaction: tx,
        );

        await _recorder.afterDelete(result, tx);
        return result;
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
  }) {
    return _delegate.lockRows<T>(
      where: where,
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
  }) {
    return transaction<R>(
      (tx) => transactionFunction(CrdtTransaction(tx, userId: userId)),
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
