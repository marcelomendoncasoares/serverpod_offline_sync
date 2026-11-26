import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// In-memory semantic information accompanying native SQLite notifications.
///
/// This class never publishes notifications. Its owner must seal a transaction
/// before returning to the driver's commit, and finish it synchronously after
/// actual commit. Versions are published before the sealed record is removed.
@internal
class NativeWatchEffects {
  static final _owners = Expando<NativeWatchEffects>();

  /// Reuses bookkeeping without abandoning existing subscriptions' snapshots.
  static NativeWatchEffects bind(
    Database database,
    NativeWatchEffects? context, {
    required bool filterMetadataChanges,
  }) {
    final existing = _owners[database];
    if (existing != null && context != null && !identical(existing, context)) {
      existing.allowUnobservedWrites();
      context.allowUnobservedWrites();
    }
    final effects = existing ?? context ?? NativeWatchEffects();
    _owners[database] = effects;
    if (!filterMetadataChanges) effects.allowUnobservedWrites();
    return effects;
  }

  final _transactions = <Object, _TransactionEffects>{};
  final _versions = <String, int>{};
  var _uncertaintyVersion = 0;
  var _unobservedWriter = false;

  /// An unobserved commit cannot be acknowledged or expired safely.
  void allowUnobservedWrites() => _unobservedWriter = true;

  /// Owns the callback/COMMIT handoff without replacing the driver's signals.
  Future<R> transaction<R>(
    Database database,
    TransactionFunction<R> action, {
    TransactionSettings? settings,
    bool uncertain = false,
  }) async {
    Transaction? active;
    try {
      final result = await database.transaction((tx) async {
        active = tx;
        begin(tx);
        if (uncertain) unknown(tx);
        final result = await action(tx);
        seal(tx);
        return result;
      }, settings: settings);
      committed(active!);
      return result;
    } catch (_) {
      if (active != null) aborted(active!);
      rethrow;
    }
  }

  /// Mirrors the ORM's savepoint lifetime while retaining its error behavior.
  Future<R> isolate<R>(
    Database database,
    Transaction? transaction,
    TransactionFunction<R> action,
  ) async {
    if (transaction == null) return this.transaction(database, action);
    if (!_transactions.containsKey(transaction)) allowUnobservedWrites();

    final checkpoint = Object();
    savepoint(transaction, checkpoint);
    try {
      final result = await DatabaseUtil.runInTransactionOrSavepoint(
        database,
        transaction,
        action,
      );
      release(transaction, checkpoint);
      return result;
    } on RollbackToSavepointFailedException {
      unknown(transaction);
      release(transaction, checkpoint);
      rethrow;
    } catch (_) {
      rollbackTo(transaction, checkpoint);
      release(transaction, checkpoint);
      rethrow;
    }
  }

  void begin(Object transaction) {
    _transactions[transaction] = _TransactionEffects();
  }

  /// Records one classified write. An empty set explicitly means known empty.
  void record(Object transaction, Iterable<String> tables) {
    final effects = _transactions[transaction];
    if (effects == null) {
      // A missing lifecycle boundary cannot establish known-empty effects.
      allowUnobservedWrites();
      return;
    }

    effects.tables.addAll(tables);
  }

  /// Records an unclassified write without erasing earlier classifications.
  void unknown(Object? transaction) {
    final effects = _transactions[transaction];
    if (effects == null) {
      allowUnobservedWrites();
      return;
    }

    effects.uncertain = true;
  }

  void savepoint(Object transaction, Object savepoint) {
    final effects = _transactions[transaction];
    if (effects == null) return;

    effects.savepoints[savepoint] = effects.snapshot();
  }

  /// SQLite retains the rollback target and removes savepoints nested in it.
  void rollbackTo(Object transaction, Object savepoint) {
    final effects = _transactions[transaction];
    final checkpoint = effects?.savepoints[savepoint];
    if (effects == null || checkpoint == null) return;

    effects.tables
      ..clear()
      ..addAll(checkpoint.tables);
    effects.uncertain = checkpoint.uncertain;
    _removeSavepoints(effects, savepoint, includeTarget: false);
  }

  /// Release preserves writes while removing the target and nested checkpoints.
  void release(Object transaction, Object savepoint) {
    final effects = _transactions[transaction];
    if (effects == null) return;

    _removeSavepoints(effects, savepoint, includeTarget: true);
  }

  void _removeSavepoints(
    _TransactionEffects effects,
    Object target, {
    required bool includeTarget,
  }) {
    var found = false;
    effects.savepoints.removeWhere((key, _) {
      if (key == target) {
        found = true;
        return includeTarget;
      }
      return found;
    });
  }

  Set<String> affectedTables(Object transaction) =>
      Set.unmodifiable(_transactions[transaction]?.tables ?? const <String>{});

  void seal(Object transaction) {
    _transactions[transaction]?.sealed = true;
  }

  void committed(Object transaction) {
    final effects = _transactions[transaction];
    if (effects == null) return;

    for (final table in effects.tables) {
      _versions[table] = (_versions[table] ?? 0) + 1;
    }
    if (effects.uncertain) _uncertaintyVersion++;
    _transactions.remove(transaction);
  }

  void aborted(Object transaction) {
    _transactions.remove(transaction);
  }

  NativeWatchSnapshot capture(Iterable<String> dependencies) => NativeWatchSnapshot._(
    {for (final table in dependencies) table: _versions[table] ?? 0},
    _uncertaintyVersion,
  );

  bool shouldQuery(Set<String> dependencies, NativeWatchSnapshot? acknowledged) {
    if (_unobservedWriter || acknowledged == null) {
      return true;
    }
    if (acknowledged._uncertaintyVersion != _uncertaintyVersion) return true;

    for (final effects in _transactions.values) {
      if (effects.sealed &&
          (effects.uncertain || effects.tables.any(dependencies.contains))) {
        return true;
      }
    }
    return dependencies.any(
      (table) => (_versions[table] ?? 0) != acknowledged._versions[table],
    );
  }
}

/// Committed versions sampled before a query starts.
///
/// A watch acknowledges this exact snapshot only after the query succeeds.
@internal
class NativeWatchSnapshot {
  NativeWatchSnapshot._(
    this._versions,
    this._uncertaintyVersion,
  );

  final Map<String, int> _versions;
  final int _uncertaintyVersion;
}

class _TransactionEffects {
  final tables = <String>{};
  final savepoints = <Object, _EffectsSnapshot>{};
  bool uncertain = false;
  bool sealed = false;

  _EffectsSnapshot snapshot() => _EffectsSnapshot(Set.of(tables), uncertain: uncertain);
}

class _EffectsSnapshot {
  _EffectsSnapshot(this.tables, {required this.uncertain});

  final Set<String> tables;
  final bool uncertain;
}
