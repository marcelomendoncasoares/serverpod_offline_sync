import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

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
  UuidValue get uuidNodeId => lastHlc.node.nodeId;

  /// The normalized node ID of the current node.
  final int normalizedNodeId;

  /// The worker ID of the current node.
  int get workerId => lastHlc.node.workerId;

  /// The last HLC timestamp for the current node.
  Hlc lastHlc;

  /// Map of user ID to [HlcManager] instance of the current node for that user.
  static final Map<UuidValue, HlcManager> _instances = {};

  /// Returns the [HlcManager] for the given node ID.
  ///
  /// Will create a new [HlcManager] with [Hlc.zero] if no manager is found.
  ///
  /// Call [initialize] once per process (e.g. server startup) before any CRDT
  /// writes so a [CrdtWorker] row exists and [workerId] is defined. Multi-worker
  /// negotiation for the same node is not implemented yet; all workers on this
  /// process share the allocated worker id from [initialize].
  static HlcManager forUser(CrdtUser user) {
    _instances[user.uuidUserId] ??= HlcManager._(
      user.uuidUserId,
      user.id!,
      user.currentNodeId!,
      user.currentNode!.lastReceivedHlc ??
          Hlc.zero(
            NodeWithWorker(
              nodeId: user.currentNode!.uuidNodeId,
              // TODO: This must be negotiated in an initialize step.
              workerId: _workerId ?? (throw StateError('Worker ID not initialized.')),
            ),
          ),
    );

    return _instances[user.uuidUserId]!;
  }

  /// Closes the [HlcManager] and updates the last received HLC for all nodes.
  ///
  /// Also deletes the worker row from the database to free the ID for reuse.
  /// Should be called when the application is shutting down.
  static Future<void> close(DatabaseSession session) async {
    await session.db.transaction((transaction) async {
      final nodes = await CrdtNode.db.find(
        session,
        where: (t) => t.uuidNodeId.inSet(
          _instances.values.map((e) => e.uuidNodeId).toSet(),
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
              lastReceivedHlc: _instances.values
                  .firstWhere((e) => e.uuidNodeId == node.uuidNodeId)
                  .lastHlc,
            ),
        ],
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );

      _instances.clear();

      if (_workerId != null) {
        await CrdtWorker.db.deleteWhere(
          session,
          where: (t) => t.workerId.equals(_workerId),
          transaction: transaction,
        );
      }
    });
  }

  static int? _workerId;

  /// Set the ID of this worker to apply to all nodes it manages.
  ///
  /// In case of a multi-user instance (like the server), this worker ID will
  /// be reused for all users. It serves only to make the HLC unique across
  /// different workers on the same node.
  static Future<int> initialize(DatabaseSession session) async {
    if (_workerId != null) return _workerId!;

    _workerId = await session.db.transaction((transaction) async {
      final lastWorkerId = await CrdtWorker.db.findFirstRow(
        session,
        orderBy: (t) => t.workerId.desc(),
        transaction: transaction,
        lockMode: LockMode.forUpdate,
        lockBehavior: LockBehavior.wait,
      );

      final workerId = (lastWorkerId?.workerId ?? -1) + 1;
      await CrdtWorker.db.insertRow(
        session,
        CrdtWorker(workerId: workerId),
        transaction: transaction,
      );

      return workerId;
    });

    return _workerId!;
  }

  /// Clears static worker and per-user HLC state when the database file was
  /// emptied (e.g. test cleanup). Call before [initialize] to recreate the
  /// [CrdtWorker] and HLC state that matches the store.
  static void reset() {
    _workerId = null;
    _instances.clear();
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
}
