part of 'database.dart';

// Weak keys retain the guard for escaped transaction references without keeping
// completed transactions alive. Expando also permits the context to hold its tx.
final _spaceTransactionContexts = Expando<OfflineSyncSpacesTransaction>();

// All recorder and query paths already resolve these maps. Validate those reads
// centrally so another wrapper cannot bypass the active scope's zone check.
// MapView forwards inspection directly to the underlying map. MapBase would
// route values/entries/toString through [], poisoning unrelated active scopes
// merely because diagnostic code inspected their bindings from another zone.
class _ScopedTransactionBindings<V> extends MapView<Transaction, V> {
  _ScopedTransactionBindings() : super(<Transaction, V>{});

  @override
  V? operator [](Object? key) {
    if (key is Transaction) {
      _spaceTransactionContexts[key]?._assertBindingAccess();
    }
    return super[key];
  }
}

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
  ) {
    _spaceTransactionContexts[_transaction] = this;
  }

  final OfflineSyncDatabase _database;
  final UuidValue _userId;
  final Transaction _transaction;
  final Map<UuidValue, OfflineSyncSpace> _spaces;
  final _scopeZoneKey = Object();
  var _isActive = true;
  final _activeScopes = <Object>[];
  StateError? _failure;

  /// Runs [action] in [spaceId] using the enclosing transaction.
  ///
  /// Returns the action's result. A failure rolls back this scope's savepoint,
  /// and the previous space binding is restored even when the failure is caught.
  /// Membership is checked using the transaction before the action runs.
  ///
  /// Await every call. Awaited nesting is supported; overlapping sibling calls
  /// throw [StateError]. An undeclared space throws [ArgumentError], and using
  /// the context after its transaction callback ends throws [StateError].
  /// Using a parent binding while its child runs, or returning from a parent
  /// while its child still runs, invalidates the whole transaction even if caught.
  ///
  /// Do not call `cancel()` on the scope transaction: cancellation prevents
  /// savepoint cleanup. Throw from the scope to roll it back, or let the error
  /// escape the enclosing callback to roll back all writes. A failed savepoint
  /// rollback also invalidates the whole transaction.
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
            return _database._runBound(tx, space, _userId, (tx) async {
              try {
                return await action(tx);
              } finally {
                // Check both exits before _runBound restores the prior binding.
                // Otherwise an orphan can observe that binding in a microtask
                // between restoration and the enclosing savepoint cleanup.
                _assertScopeCanExit(scope);
              }
            });
          },
        ),
        zoneValues: {_scopeZoneKey: scope},
      );
    } on RollbackToSavepointFailedException {
      // The driver can no longer guarantee that the failed scope was undone.
      // Catching that exception must not allow a partial transaction to commit.
      _invalidate('A runForSpace savepoint failed to roll back.');
      rethrow;
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
    final failure = _failure;
    if (failure != null) throw failure;
    if (!_isActive) {
      throw StateError('The transactionForSpaces callback has ended.');
    }
  }

  void _assertBindingAccess() {
    _assertActive();
    if (!identical(Zone.current[_scopeZoneKey], _activeScopes.lastOrNull)) {
      throw _invalidate(
        'Await each runForSpace call before using the transaction again.',
      );
    }
  }

  void _assertScopeCanExit(Object scope) {
    _assertActive();
    if (!identical(_activeScopes.lastOrNull, scope)) {
      throw _invalidate('Await every nested runForSpace call before returning.');
    }
  }

  StateError _invalidate(String message) => _failure ??= StateError(message);
}
