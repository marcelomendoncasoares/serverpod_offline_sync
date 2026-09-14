import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../sync/engine.dart';
import 'database.dart';
import 'recorder.dart';

/// Wraps a [DatabaseSession] to provide a [OfflineSyncDatabase] as [DatabaseSession.db].
class OfflineSyncDatabaseSession implements DatabaseSession {
  /// Creates a [OfflineSyncDatabaseSession] instance.
  OfflineSyncDatabaseSession(
    Database db, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Shared CRDT database metadata.
    OfflineSyncDatabaseContext? context,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = OfflineSyncEngine.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = OfflineSyncEngine.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
  }) : _db = db is OfflineSyncDatabase
           ? db
           : OfflineSyncDatabase(
               db,
               syncTables: syncTables,
               context: context,
               syncBatchSize: syncBatchSize,
               continuousSyncInterval: continuousSyncInterval,
               persistentUserId: persistentUserId,
             );

  /// Creates a [OfflineSyncDatabaseSession] instance that wraps a [DatabaseSession].
  factory OfflineSyncDatabaseSession.wraps(
    DatabaseSession session, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// Shared CRDT database metadata.
    OfflineSyncDatabaseContext? context,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = OfflineSyncEngine.defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = OfflineSyncEngine.defaultContinuousSyncInterval,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
  }) => OfflineSyncDatabaseSession(
    session.db,
    syncTables: syncTables,
    context: context,
    syncBatchSize: syncBatchSize,
    continuousSyncInterval: continuousSyncInterval,
    persistentUserId: persistentUserId,
  );

  final OfflineSyncDatabase _db;

  @override
  OfflineSyncDatabase get db => _db;

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
extension OfflineSyncDatabaseAccess on DatabaseSession {
  /// Returns the wrapped [OfflineSyncDatabase] for this session.
  OfflineSyncDatabase get offlineSyncDb {
    final database = db;
    if (database is OfflineSyncDatabase) return database;
    throw StateError(
      'This database session is not wrapped with OfflineSyncDatabaseSession. '
      'Use OfflineSyncDatabaseSession.wraps(...) before accessing offlineSyncDb.',
    );
  }
}
