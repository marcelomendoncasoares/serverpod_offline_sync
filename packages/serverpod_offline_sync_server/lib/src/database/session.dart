import 'package:serverpod/serverpod.dart';

import 'database.dart';

/// Wraps a [DatabaseSession] to provide a [CrdtDatabase] as [DatabaseSession.db].
class CrdtDatabaseSession implements DatabaseSession {
  /// Creates a [CrdtDatabaseSession] instance.
  CrdtDatabaseSession(Database db, {this.persistentUserId})
    : _db = CrdtDatabase(db, persistentUserId: persistentUserId);

  /// Wraps a [DatabaseSession] to provide a [CrdtDatabase] as [DatabaseSession.db].
  static CrdtDatabaseSession wraps(
    DatabaseSession session, {
    UuidValue? persistentUserId,
  }) => CrdtDatabaseSession(session.db, persistentUserId: persistentUserId);

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

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
