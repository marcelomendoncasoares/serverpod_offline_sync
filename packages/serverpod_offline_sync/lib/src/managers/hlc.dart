import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';
import '../hlc/hlc.dart';

/// A manager for [Hlc] instances that is used to generate unique timestamps
/// for CRDT operations.
class HlcManager {
  /// Creates a manager writing to [normalizedSpaceId] with the clock of [node].
  ///
  /// [node] is shared, not copied. [onUse] runs after every [increment],
  /// [merge], or [observe], so the owner knows to store the clock.
  HlcManager(this.normalizedSpaceId, CrdtNode node, {void Function()? onUse})
    : normalizedNodeId = node.id!,
      _node = node,
      // A private field cannot be a named initializing formal.
      // ignore: prefer_initializing_formals
      _onUse = onUse;

  /// The normalized space ID of the space this manager writes to.
  final int normalizedSpaceId;

  /// The node ID of the acting user's local clock.
  UuidValue get uuidNodeId => _node.uuidNodeId;

  /// The normalized node ID of the acting user's local clock.
  final int normalizedNodeId;

  final CrdtNode _node;

  final void Function()? _onUse;

  /// The last HLC timestamp of the acting user's clock.
  Hlc get lastHlc => _node.lastHlc ?? Hlc.zero(_node.uuidNodeId);

  set lastHlc(Hlc value) => _node.lastHlc = value;

  /// Returns the next HLC timestamp for the current node.
  Hlc increment() {
    lastHlc = lastHlc.increment();
    _onUse?.call();
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
    _onUse?.call();
  }

  /// Advances the clock to at least [other], a timestamp already committed to
  /// this database, without the remote merge checks.
  void observe(Hlc other) {
    if (other > lastHlc) lastHlc = other.copyWith(nodeId: uuidNodeId);
    _onUse?.call();
  }

  /// Converts this manager state to the persisted current-node model.
  CrdtNode getNode() => CrdtNode(
    id: normalizedNodeId,
    uuidNodeId: uuidNodeId,
    lastHlc: lastHlc,
  );
}
