import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [CrdtUser] instances.
class CrdtUserManager {
  CrdtUserManager._();

  /// Map of user ID to [CrdtUser] instance for that user.
  static final Map<UuidValue, CrdtUser> _instances = {};

  /// Returns the [CrdtUser] for the given user ID.
  ///
  /// Will create a new [CrdtUser] if no user is found.
  static CrdtUser getCached(UuidValue uuidUserId) =>
      _instances[uuidUserId] ?? (throw StateError('User $uuidUserId not found.'));

  /// Returns the [CrdtUser] for the given user ID.
  ///
  /// Will create a new [CrdtUser] if no user is found.
  static Future<CrdtUser> getOrCreate(
    DatabaseSession session,
    UuidValue uuidUserId,
  ) async {
    return _instances[uuidUserId] ??= await session.db.transaction(
      (transaction) => _getOrCreate(session, uuidUserId, transaction),
    );
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
