import 'package:serverpod_database/serverpod_database.dart';

import 'exceptions.dart';

/// Cancellation for one sync session, bound only while its merge is active.
///
/// A signal can cover successive merges, but not overlapping transactions.
/// Cancellation is permanent and does not interrupt an executing SQL statement.
class OfflineSyncCancellation {
  bool _cancelled = false;
  Transaction? _transaction;
  Future<void>? _rollback;
  (Object, StackTrace)? _rollbackError;

  /// Whether this session has received cancellation.
  bool get isCancelled => _cancelled;

  /// Starts rollback; [run] joins it before the owning operation completes.
  ///
  /// Once the callback has returned to the driver's commit path, cancellation
  /// cannot undo that transaction. It still prevents this session's next merge.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final transaction = _transaction;
    if (transaction == null) return;

    // Observe failures immediately, but join rollback at the owning boundary.
    _rollback = Future<void>.sync(transaction.cancel).then(
      (_) {},
      onError: (Object error, StackTrace stack) {
        _rollbackError = (error, stack);
      },
    );
  }

  /// Rejects work that has not yet entered a transaction.
  void throwIfCancelled() {
    if (_cancelled) throw const OfflineSyncCancelledException();
  }

  /// Binds one transaction until its callback and any requested rollback settle.
  Future<R> run<R>(Transaction transaction, Future<R> Function() action) async {
    throwIfCancelled();
    if (_transaction != null) {
      throw StateError('A sync cancellation cannot bind overlapping transactions.');
    }
    _transaction = transaction;

    Object? failure;
    try {
      final result = await action();
      throwIfCancelled();
      return result;
    } on Object catch (error) {
      failure = error;
      if (_cancelled &&
          (error is DatabaseException || error is RollbackToSavepointFailedException)) {
        // Full rollback also removes savepoints used by nested merge operations.
        const cancelled = OfflineSyncCancelledException();
        failure = cancelled;
        throw cancelled;
      }
      rethrow;
    } finally {
      // Stop observing before returning control to the driver's commit path.
      _transaction = null;
      final rollback = _rollback;
      if (rollback != null) await rollback;
      if (_rollbackError case (
        final error,
        final stack,
      ) when failure == null || failure is OfflineSyncCancelledException) {
        Error.throwWithStackTrace(error, stack);
      }
    }
  }
}
