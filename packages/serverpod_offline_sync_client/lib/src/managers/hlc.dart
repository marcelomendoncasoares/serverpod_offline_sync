import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../protocol/protocol.dart';

/// A manager for [Hlc] instances that is used to generate unique timestamps
/// for CRDT operations.
class HlcManager {
  HlcManager._(
    this.uuidScopeId,
    this.normalizedScopeId,
    this.normalizedNodeId,
    this.lastHlc,
  );

  /// Creates a new [HlcManager] for the current node of [scope].
  factory HlcManager.forScope(CrdtScope scope) {
    return HlcManager._(
      scope.uuidScopeId,
      scope.id!,
      scope.currentNodeId!,
      scope.currentNode!.lastReceivedHlc ?? Hlc.zero(scope.currentNode!.uuidNodeId),
    );
  }

  /// The UUID of the scope this manager is for.
  final UuidValue uuidScopeId;

  /// The normalized scope ID of the scope this manager is for.
  final int normalizedScopeId;

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
    scopeId: normalizedScopeId,
    uuidNodeId: uuidNodeId,
    lastReceivedHlc: lastHlc,
  );
}
