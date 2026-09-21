part of 'database.dart';

/// Space scopes sharing one transaction for one authenticated user.
///
/// Created by [OfflineSyncDatabase.transactionForSpaces]. Only its declared
/// spaces may be used, and only while its transaction callback is active.
final class OfflineSyncSpacesTransaction {
  OfflineSyncSpacesTransaction._(
    this._database,
    this._userId,
    this._transaction,
    this._spaces,
  );

  final OfflineSyncDatabase _database;
  final UuidValue _userId;
  final Transaction _transaction;
  final Map<UuidValue, OfflineSyncSpace> _spaces;
  final _scopeZoneKey = Object();
  var _isActive = true;
  final _activeScopes = <Object>[];

  /// Runs [action] in [spaceId] using the enclosing transaction.
  ///
  /// Returns the action's result. A failure rolls back this scope's savepoint,
  /// and the previous space binding is restored even when the failure is caught.
  /// Membership is checked using the transaction before the action runs.
  ///
  /// Await every call. Awaited nesting is supported; overlapping sibling calls
  /// throw [StateError]. An undeclared space throws [ArgumentError], and using
  /// the context after its transaction callback ends throws [StateError].
  Future<R> runForSpace<R>(
    UuidValue spaceId,
    TransactionFunction<R> action,
  ) async {
    _assertActive();
    final space = _spaces[spaceId];
    if (space == null) {
      throw ArgumentError.value(spaceId, 'spaceId', 'Space was not declared.');
    }
    final previous = _activeScopes.lastOrNull;
    if (previous != null && !identical(Zone.current[_scopeZoneKey], previous)) {
      throw StateError(
        'Overlapping runForSpace calls on one transaction are not supported. '
        'Await each call before using the transaction again.',
      );
    }
    final scope = Object();
    _activeScopes.add(scope);
    try {
      return await runZoned(
        () => DatabaseUtil.runInTransactionOrSavepoint(
          _database._delegate,
          _transaction,
          (tx) async {
            await _database._assertCanActInSpace(_userId, spaceId, transaction: tx);
            _assertActive();
            return _database._runBound(tx, space, _userId, action);
          },
        ),
        zoneValues: {_scopeZoneKey: scope},
      );
    } finally {
      _activeScopes.remove(scope);
      // An unawaited nested action may finish after its transaction closed.
      // Do not let its saved outer binding survive that transaction.
      if (!_isActive) _close();
    }
  }

  void _close() {
    _isActive = false;
    spaceForTransaction.remove(_transaction);
    userForTransaction.remove(_transaction);
  }

  void _assertActive() {
    if (!_isActive) {
      throw StateError('The transactionForSpaces callback has ended.');
    }
  }
}
