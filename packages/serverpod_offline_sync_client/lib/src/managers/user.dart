import 'dart:collection';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [CrdtUser] instances.
class CrdtUserManager {
  CrdtUserManager._();

  /// Map of database to user ID cache for that database.
  static final Map<Database, Map<UuidValue, CrdtUser>> _instancesByDatabase =
      HashMap.identity();

  /// Returns the [CrdtUser] for the given user ID.
  ///
  /// Will create a new [CrdtUser] if no user is found.
  static CrdtUser getCached(
    DatabaseSession session,
    UuidValue uuidUserId,
  ) =>
      _cacheForSession(
        session,
      )[uuidUserId] ??
      (throw StateError(
        'User $uuidUserId not found in cache for this database session. '
        'Ensure getOrCreate() is called before getCached().',
      ));

  /// Clears the in-memory user cache. Used when the database is reset (e.g. tests)
  /// so [getOrCreate] loads fresh rows from the store.
  static void clearCache() {
    _instancesByDatabase.clear();
  }

  /// Returns the [CrdtUser] for the given user ID.
  ///
  /// Will create a new [CrdtUser] if no user is found.
  static Future<CrdtUser> getOrCreate(
    DatabaseSession session,
    UuidValue uuidUserId,
  ) async {
    final cache = _cacheForSession(session);
    return cache[uuidUserId] ??= await session.db.transaction(
      (transaction) => _getOrCreate(session, uuidUserId, transaction),
    );
  }

  static Map<UuidValue, CrdtUser> _cacheForSession(DatabaseSession session) {
    return _instancesByDatabase.putIfAbsent(session.db, () => {});
  }

  static Future<CrdtUser> _getOrCreate(
    DatabaseSession session,
    UuidValue uuidUserId,
    Transaction transaction,
  ) async {
    var user = await CrdtUser.db.findFirstRow(
      session,
      where: (t) => t.uuidUserId.equals(uuidUserId),
      include: CrdtUser.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    // User must be created.
    user ??= await CrdtUser.db.insertRow(
      session,
      CrdtUser(uuidUserId: uuidUserId),
      transaction: transaction,
    );

    if (user.currentNode != null) {
      return user;
    }

    // User has no current node and must be created.
    final currentNode = await CrdtNode.db.insertRow(
      session,
      CrdtNode(userId: user.id!),
      transaction: transaction,
    );

    await CrdtUser.db.attachRow.currentNode(
      session,
      user,
      currentNode,
      transaction: transaction,
    );

    return user.copyWith(
      currentNodeId: currentNode.id,
      currentNode: currentNode,
    );
  }
}
