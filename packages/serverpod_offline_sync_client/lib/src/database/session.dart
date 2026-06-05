import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../crdt/sync.dart';
import '../crdt/unique_conflict.dart';
import 'database.dart';

/// Wraps a [DatabaseSession] to provide a [CrdtDatabase] as [DatabaseSession.db].
class CrdtDatabaseSession implements DatabaseSession {
  /// Creates a [CrdtDatabaseSession] instance.
  CrdtDatabaseSession(
    Database db, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = CrdtSync.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,

    /// Called after a merge materializes unique conflicts.
    UniqueConflictCallback? onUniqueConflicts,
  }) : _db = CrdtDatabase(
         db,
         syncTables: syncTables,
         syncBatchSize: syncBatchSize,
         continuousSyncInterval: continuousSyncInterval,
         persistentUserId: persistentUserId,
         onUniqueConflicts: onUniqueConflicts,
       );

  /// Creates a [CrdtDatabaseSession] instance that wraps a [DatabaseSession].
  factory CrdtDatabaseSession.wraps(
    DatabaseSession session, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = CrdtSync.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = CrdtSync.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,

    /// Called after a merge materializes unique conflicts.
    UniqueConflictCallback? onUniqueConflicts,
  }) => CrdtDatabaseSession(
    session.db,
    syncTables: syncTables,
    syncBatchSize: syncBatchSize,
    continuousSyncInterval: continuousSyncInterval,
    persistentUserId: persistentUserId,
    onUniqueConflicts: onUniqueConflicts,
  );

  final CrdtDatabase _db;

  @override
  CrdtDatabase get db => _db;

  @override
  LogQueryFunction? get logQuery => null;

  @override
  LogWarningFunction? get logWarning => null;

  @override
  Transaction? transaction;
}

/// Wraps a [Database] to provide a [DatabaseSession] as [DatabaseSession.db].
@internal
class BasicDatabaseSession implements DatabaseSession {
  /// Creates a [BasicDatabaseSession] instance.
  BasicDatabaseSession(this._db);

  final Database _db;

  @override
  Database get db => _db;

  @override
  LogQueryFunction? get logQuery => null;

  @override
  LogWarningFunction? get logWarning => null;

  @override
  Transaction? transaction;
}

@internal
extension DatabaseSessionExtension on Database {
  DatabaseSession get session => BasicDatabaseSession(this);
}

/// Convenience access to a CRDT-aware database from a wrapped session.
extension CrdtDatabaseAccess on DatabaseSession {
  /// Returns the wrapped [CrdtDatabase] for this session.
  CrdtDatabase get crdtDb {
    final database = db;
    if (database is CrdtDatabase) return database;
    throw StateError(
      'This database session is not wrapped with CrdtDatabaseSession. '
      'Use CrdtDatabaseSession.wraps(...) before accessing crdtDb.',
    );
  }
}
