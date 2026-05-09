import 'dart:collection';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../protocol/protocol.dart';

/// A manager for [Hlc] instances that is used to generate unique timestamps
/// for CRDT operations. Will keep track of the HLC during the lifetime of the
/// application.
class HlcManager {
  HlcManager._(
    this.uuidUserId,
    this.normalizedUserId,
    this.normalizedNodeId,
    this.lastHlc,
  );

  /// The UUID of the user this manager is for.
  final UuidValue uuidUserId;

  /// The normalized user ID of the user this manager is for.
  final int normalizedUserId;

  /// The node ID of the current node.
  UuidValue get uuidNodeId => lastHlc.nodeId;

  /// The normalized node ID of the current node.
  final int normalizedNodeId;

  /// The last HLC timestamp for the current node.
  Hlc lastHlc;

  /// Map of database to per-user [HlcManager] instances for that database.
  static final Map<Database, Map<UuidValue, HlcManager>> _instancesByDatabase =
      HashMap.identity();

  /// Returns the [HlcManager] for the given node ID.
  ///
  /// Will create a new [HlcManager] with [Hlc.zero] if no manager is found.
  static HlcManager forUser(DatabaseSession session, CrdtUser user) {
    final cache = _cacheForSession(session);
    cache[user.uuidUserId] ??= HlcManager._(
      user.uuidUserId,
      user.id!,
      user.currentNodeId!,
      user.currentNode!.lastReceivedHlc ?? Hlc.zero(user.currentNode!.uuidNodeId),
    );

    return cache[user.uuidUserId]!;
  }

  /// Closes the [HlcManager] and updates the last received HLC for all nodes.
  ///
  /// Should be called when the application is shutting down.
  static Future<void> close(DatabaseSession session) async {
    final managers = _instancesByDatabase[session.db];
    if (managers == null || managers.isEmpty) return;

    await session.db.transaction((transaction) async {
      final nodes = await CrdtNode.db.find(
        session,
        where: (t) => t.uuidNodeId.inSet(
          managers.values.map((e) => e.uuidNodeId).toSet(),
        ),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
        lockBehavior: LockBehavior.wait,
      );

      await CrdtNode.db.update(
        session,
        [
          for (final node in nodes)
            CrdtNode(
              id: node.id,
              userId: node.userId,
              lastReceivedHlc: managers.values
                  .firstWhere((e) => e.uuidNodeId == node.uuidNodeId)
                  .lastHlc,
            ),
        ],
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );

      _instancesByDatabase.remove(session.db);
    });
  }

  /// Clears per-user HLC state when the database file was emptied (e.g. test
  /// cleanup). Call before recreating managers so state matches the store.
  static void reset() {
    _instancesByDatabase.clear();
  }

  /// Returns the next HLC timestamp for the current node.
  Hlc increment() {
    lastHlc = lastHlc.increment();
    return lastHlc;
  }

  /// Merges another [Hlc] instance into the current one.
  void merge(Hlc other) {
    lastHlc = lastHlc.merge(other);
  }

  static Map<UuidValue, HlcManager> _cacheForSession(DatabaseSession session) {
    return _instancesByDatabase.putIfAbsent(session.db, () => {});
  }
}
