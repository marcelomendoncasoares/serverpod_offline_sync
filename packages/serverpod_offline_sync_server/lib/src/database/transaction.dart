import 'package:serverpod/serverpod.dart';

/// Custom transaction class that allows passing a user ID for the operations
/// done in the transaction.
class CrdtTransaction implements Transaction {
  /// Creates a new [CrdtTransaction].
  CrdtTransaction(
    Transaction transaction, {
    required this.userId,
  }) : _transaction = transaction;

  /// The user ID to use for the operations done in the transaction.
  final UuidValue userId;

  final Transaction _transaction;

  @override
  Future<void> cancel() => _transaction.cancel();

  @override
  Future<Savepoint> createSavepoint() => _transaction.createSavepoint();

  @override
  Future<void> setRuntimeParameters(RuntimeParametersListBuilder builder) =>
      _transaction.setRuntimeParameters(builder);

  @override
  Map<String, dynamic> get runtimeParameters => _transaction.runtimeParameters;
}
