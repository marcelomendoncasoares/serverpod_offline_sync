import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [Hlc] instances that is used to generate unique timestamps
/// for CRDT operations.
class HlcManager {
  HlcManager._(
    this.uuidUserId,
    this.normalizedUserId,
    this.normalizedNodeId,
    this.lastHlc,
  );

  /// Creates a new [HlcManager] for the current node of [user].
  factory HlcManager.forUser(CrdtUser user) {
    return HlcManager._(
      user.uuidUserId,
      user.id!,
      user.currentNodeId!,
      user.currentNode!.lastReceivedHlc ?? Hlc.zero(user.currentNode!.uuidNodeId),
    );
  }

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

  /// Returns the next HLC timestamp for the current node.
  Hlc increment() {
    lastHlc = lastHlc.increment();
    return lastHlc;
  }

  /// Merges another [Hlc] instance into the current one.
  void merge(Hlc other) {
    lastHlc = lastHlc.merge(other);
  }

  /// Converts this manager state to the persisted current-node model.
  CrdtNode getNode() => CrdtNode(
    id: normalizedNodeId,
    userId: normalizedUserId,
    uuidNodeId: uuidNodeId,
    lastReceivedHlc: lastHlc,
  );
}
