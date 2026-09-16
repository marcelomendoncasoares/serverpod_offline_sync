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
  ).._wrappedSession = session;

  final OfflineSyncDatabase _db;
  DatabaseSession? _wrappedSession;
  Future<void>? _closeFuture;

  /// Closes the underlying client database.
  ///
  /// Supported for sessions created by [OfflineSyncDatabaseSession.wraps] around
  /// a [ClientDatabaseSession], including nested sync-session wrappers and the
  /// sessions returned by the generated client's `createSyncSession` method.
  /// Repeated or concurrent calls share the same close operation.
  ///
  /// Throws [UnsupportedError] for sessions constructed directly from a
  /// [Database] or wrapping a non-client session. Those connections must be
  /// closed through their owner, such as the server.
  Future<void> close() => _closeFuture ??= switch (_wrappedSession) {
    final ClientDatabaseSession session => session.close(),
    final OfflineSyncDatabaseSession session => session.close(),
    _ => Future<void>.error(
      UnsupportedError(
        'Only sync sessions wrapping a ClientDatabaseSession can be closed. '
        'Close the underlying database through its owner.',
      ),
    ),
  };

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
