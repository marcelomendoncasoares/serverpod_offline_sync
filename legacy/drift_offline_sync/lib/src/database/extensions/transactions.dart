import '../database.dart';
import 'triggers.dart';

/// Extensions for [CrdtDatabase] to execute transactions.
extension CrdtDatabaseTransactionsExtensions on CrdtDatabase {
  /// Executes the [operation] in a transaction with the constraints deferred.
  ///
  /// On Postgres, this will result in deferring the constraints for the duration
  /// of the operation. On SQLite, this will result in disabling the foreign keys
  /// before the operation and restoring to the previous value afterwards.
  Future<T> transactionWithDeferredConstraints<T>(
    Future<T> Function() operation,
  ) async {
    if (isPostgres) {
      return transaction(
        () => withTriggersDisabled(() async {
          await customStatement('SET CONSTRAINTS ALL DEFERRED');
          return operation();
        }),
      );
    }

    return _withForeignKeysDisabled(
      () => transaction(() => withTriggersDisabled(operation)),
    );
  }

  Future<T> _withForeignKeysDisabled<T>(Future<T> Function() operation) async {
    const pragma = 'PRAGMA foreign_keys';
    final originalValueResult = await customSelect(pragma).getSingle();
    final originalValue = originalValueResult.read<int>('foreign_keys');
    try {
      await customStatement('$pragma = OFF');
      return await operation();
    } finally {
      await customStatement('$pragma = $originalValue');
    }
  }
}
