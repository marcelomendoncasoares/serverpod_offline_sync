import 'dart:async';

import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import 'session.dart';

/// Database identity and committed membership revision.
@internal
typedef SpaceCacheVersion = (UuidValue, int);

/// Committed space visibility shared by wrappers of one database.
@internal
class OfflineSyncSpaceCache {
  SpaceCacheVersion? _revision;
  final _entries = <UuidValue, List<int>>{};

  List<int>? read(SpaceCacheVersion revision, UuidValue user) =>
      _revision == revision ? _entries[user] : null;

  void publish(SpaceCacheVersion revision, Map<UuidValue, List<int>> entries) {
    if (_revision case final previous?
        when previous.$1 == revision.$1 && previous.$2 > revision.$2) {
      return;
    }
    if (_revision != revision) {
      _revision = revision;
      _entries.clear();
    }
    _entries.addAll(entries);
  }
}

/// Database transaction and savepoint state for the space visibility cache.
@internal
class OfflineSyncSpaceTransaction implements Transaction {
  OfflineSyncSpaceTransaction(this.inner, this.database, this.cache) {
    _transactions[inner] = this;
  }

  static final _transactions = Expando<OfflineSyncSpaceTransaction>();

  static OfflineSyncSpaceTransaction? of(Transaction? transaction) =>
      transaction is OfflineSyncSpaceTransaction
      ? transaction
      : transaction == null
      ? null
      : _transactions[transaction];

  void close() => _transactions[inner] = null;

  final Transaction inner;
  final Database database;
  final OfflineSyncSpaceCache cache;
  SpaceCacheVersion? revision;
  bool exclusive = false;
  bool cancelled = false;
  int _generation = 0;
  final entries = <UuidValue, List<int>>{};
  final _loading = <UuidValue, Future<List<int>>>{};
  final _savepoints = <_SpaceSavepoint>[];
  Future<SpaceCacheVersion>? _locking;

  Future<SpaceCacheVersion> lock({bool forWrite = false}) async {
    if (cancelled) throw StateError('The space transaction was cancelled.');
    if (_locking case final pending?) await pending;
    if (revision != null && (!forWrite || exclusive)) return revision!;
    final pending = lockSpaceCacheVersion(database, inner, forWrite: forWrite);
    _locking = pending;
    try {
      revision = await pending;
      exclusive = forWrite;
      return revision!;
    } finally {
      _locking = null;
    }
  }

  Future<List<int>> spaceIds(UuidValue user) async {
    final current = await lock();
    if (revision != current) return spaceIds(user);
    final generation = _generation;
    if (entries[user] case final entry?) return entry;
    if (cache.read(current, user) case final entry?) {
      entries[user] = entry;
      return entry;
    }
    return _loading.putIfAbsent(user, () async {
      final entry = await loadSpaceIds(database, user, inner);
      if (_generation == generation) entries[user] = entry;
      return entry;
    });
  }

  void changed(SpaceCacheVersion newRevision) {
    _generation++;
    revision = newRevision;
    exclusive = true;
    entries.clear();
    _loading.clear();
  }

  void commit() {
    if (!cancelled && revision != null) cache.publish(revision!, entries);
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    _generation++;
    entries.clear();
    _loading.clear();
    await inner.cancel();
  }

  @override
  Future<Savepoint> createSavepoint() async {
    final savepoint = _SpaceSavepoint(
      await inner.createSavepoint(),
      this,
      revision,
      Map.of(entries),
      exclusive: exclusive,
    );
    _savepoints.add(savepoint);
    return savepoint;
  }

  @override
  Map<String, dynamic> get runtimeParameters => inner.runtimeParameters;

  @override
  Future<void> setRuntimeParameters(RuntimeParametersListBuilder builder) =>
      inner.setRuntimeParameters(builder);
}

class _SpaceSavepoint implements Savepoint {
  _SpaceSavepoint(
    this.inner,
    this.transaction,
    this.revision,
    this.entries, {
    required this.exclusive,
  });

  final Savepoint inner;
  final OfflineSyncSpaceTransaction transaction;
  final SpaceCacheVersion? revision;
  final bool exclusive;
  final Map<UuidValue, List<int>> entries;
  bool active = true;

  @override
  String get id => inner.id;

  void _checkActive() {
    if (!active) throw StateError('The savepoint is no longer active.');
  }

  void _discardLater({required bool includeSelf}) {
    final index = transaction._savepoints.indexOf(this);
    final start = includeSelf ? index : index + 1;
    for (final point in transaction._savepoints.skip(start)) {
      point.active = false;
    }
    transaction._savepoints.removeRange(start, transaction._savepoints.length);
  }

  @override
  Future<void> release() async {
    _checkActive();
    await inner.release();
    _discardLater(includeSelf: true);
  }

  @override
  Future<void> rollback() async {
    _checkActive();
    await inner.rollback();
    transaction._generation++;
    transaction
      ..revision = revision
      ..exclusive = exclusive
      ..entries.clear()
      ..entries.addAll(entries)
      .._loading.clear();
    _discardLater(includeSelf: false);
  }
}

/// Unwraps the cache transaction before reaching a database adapter.
@internal
Transaction? spaceInnerTransaction(Transaction? transaction) =>
    transaction is OfflineSyncSpaceTransaction ? transaction.inner : transaction;

/// Acquires the database-backed cache revision for the transaction's lifetime.
@internal
Future<SpaceCacheVersion> lockSpaceCacheVersion(
  Database database,
  Transaction transaction, {
  bool forWrite = false,
}) async {
  final session = database.session;
  final mode = forWrite ? LockMode.forUpdate : LockMode.forShare;
  var row = await OfflineSyncSpaceCacheVersion.db.findById(
    session,
    1,
    transaction: transaction,
    lockMode: mode,
  );
  if (row == null) {
    await OfflineSyncSpaceCacheVersion.db.insert(
      session,
      [OfflineSyncSpaceCacheVersion(id: 1, revision: 0)],
      ignoreConflicts: true,
      transaction: transaction,
    );
    row = await OfflineSyncSpaceCacheVersion.db.findById(
      session,
      1,
      transaction: transaction,
      lockMode: mode,
    );
  }
  if (row == null) {
    throw StateError('Space cache revision is not visible in this transaction.');
  }
  return (row.databaseUuid, row.revision);
}

/// Loads space identities using the caller's database snapshot.
@internal
Future<List<int>> loadSpaceIds(
  Database database,
  UuidValue user,
  Transaction transaction,
) async {
  final groups = await Future.wait<List<int>>([
    OfflineSyncSpace.db
        .find(
          database.session,
          where: (t) => t.uuidSpaceId.equals(user),
          transaction: transaction,
        )
        .then((spaces) => [for (final space in spaces) space.id!]),
    OfflineSyncSpaceMember.db
        .find(
          database.session,
          where: (t) => t.userUuid.equals(user),
          transaction: transaction,
          include: OfflineSyncSpaceMember.include(space: OfflineSyncSpace.include()),
        )
        .then((members) => [for (final member in members) member.space!.id!]),
  ]);
  return List.unmodifiable({for (final group in groups) ...group});
}
