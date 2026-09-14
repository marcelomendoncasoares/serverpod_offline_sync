import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import '../hlc/hlc.dart';

/// A manager for [Hlc] instances that is used to generate unique timestamps
/// for CRDT operations.
class HlcManager {
  HlcManager._(
    this.uuidSpaceId,
    this.normalizedSpaceId,
    this.normalizedNodeId,
    this.lastHlc,
  );

  /// Creates a new [HlcManager] for the current node of [space].
  factory HlcManager.forSpace(OfflineSyncSpace space) {
    return HlcManager._(
      space.uuidSpaceId,
      space.id!,
      space.currentNodeId!,
      space.currentNode!.lastHlc ?? Hlc.zero(space.currentNode!.uuidNodeId),
    );
  }

  /// The UUID of the space this manager is for.
  final UuidValue uuidSpaceId;

  /// The normalized space ID of the space this manager is for.
  final int normalizedSpaceId;

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

  /// The HLC a following [increment] would return, without consuming it.
  ///
  /// Planning needs a timestamp to order a not-yet-written row against stored
  /// ones. It must not advance the clock, because the write that follows takes
  /// its own timestamp.
  Hlc peekNext() => lastHlc.increment();

  /// Merges another [Hlc] instance into the current one.
  void merge(Hlc other) {
    lastHlc = lastHlc.merge(other);
  }

  /// Converts this manager state to the persisted current-node model.
  CrdtNode getNode() => CrdtNode(
    id: normalizedNodeId,
    uuidNodeId: uuidNodeId,
    lastHlc: lastHlc,
  );
}
