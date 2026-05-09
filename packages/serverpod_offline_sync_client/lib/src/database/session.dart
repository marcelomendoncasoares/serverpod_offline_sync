import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/client.dart';
import 'database.dart';

/// Wraps a [DatabaseSession] to provide a [CrdtDatabase] as [DatabaseSession.db].
class CrdtDatabaseSession implements DatabaseSession {
  /// Creates a [CrdtDatabaseSession] instance.
  CrdtDatabaseSession(
    Database db, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
    Caller? syncCaller,
  }) : _db = CrdtDatabase(
         db,
         syncTables: syncTables,
         persistentUserId: persistentUserId,
         syncCaller: syncCaller,
       );

  /// Creates a [CrdtDatabaseSession] instance that wraps a [DatabaseSession].
  factory CrdtDatabaseSession.wraps(
    DatabaseSession session, {

    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The user ID to use for all CRDT operations. This should only be used for
    /// databases operating on the client side, where all data is for the same user.
    /// Otherwise, the user ID must be passed through the transaction.
    UuidValue? persistentUserId,
    Caller? syncCaller,
  }) => CrdtDatabaseSession(
    session.db,
    syncTables: syncTables,
    persistentUserId: persistentUserId,
    syncCaller: syncCaller,
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
