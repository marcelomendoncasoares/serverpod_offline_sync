import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [CrdtUser] instances.
class CrdtUserManager {
  /// Creates a [CrdtUserManager] bound to a database session.
  CrdtUserManager(this._session);

  final DatabaseSession _session;

  final Map<UuidValue, CrdtUser> _instances = {};

  /// Returns the cached [CrdtUser] for the given user ID.
  CrdtUser getCached(UuidValue uuidUserId) =>
      _instances[uuidUserId] ??
      (throw StateError(
        'User $uuidUserId not found in cache. '
        'Ensure CrdtUserManager.getOrCreate() is called before getCached().',
      ));

  /// Clears the in-memory cache so state is reloaded from the store.
  void clearCache() {
    _instances.clear();
  }

  /// Returns the [CrdtUser] for the given user ID.
  ///
  /// Will create a new [CrdtUser] if no user is found.
  Future<CrdtUser> getOrCreate(UuidValue uuidUserId) async {
    return _instances[uuidUserId] ??= await _session.db.transaction(
      (transaction) => _getOrCreate(uuidUserId, transaction),
    );
  }

  Future<CrdtUser> _getOrCreate(
    UuidValue uuidUserId,
    Transaction transaction,
  ) async {
    var user = await CrdtUser.db.findFirstRow(
      _session,
      where: (t) => t.uuidUserId.equals(uuidUserId),
      include: CrdtUser.include(currentNode: CrdtNode.include()),
      transaction: transaction,
    );

    user ??= await CrdtUser.db.insertRow(
      _session,
      CrdtUser(uuidUserId: uuidUserId),
      transaction: transaction,
    );

    if (user.currentNode != null) {
      return user;
    }

    final currentNode = await CrdtNode.db.insertRow(
      _session,
      CrdtNode(userId: user.id!),
      transaction: transaction,
    );

    await CrdtUser.db.attachRow.currentNode(
      _session,
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
