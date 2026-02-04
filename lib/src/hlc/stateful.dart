import 'hlc.dart';

/// A [Hlc] instance that is used to generate unique timestamps for CRDT operations.
/// Will keep track of the HLC during the lifetime of the application.
class StatefulHlc {
  StatefulHlc._(this.userId, this.nodeId) {
    lastHlc = _lastUserIdHlc[userId]?.copyWith(nodeId: nodeId) ?? Hlc.zero(nodeId);
  }

  static final Map<String, Hlc> _lastUserIdHlc = {};
  static final Map<String, StatefulHlc> _instances = {};

  /// Initialize the HLC for the provided [userId].
  ///
  /// This method allows a pre-initialization of the HLC for the node from the
  /// last stored HLC for the user - regardless of the node ID. If no [initialHlc]
  /// is provided, a zero HLC will be used.
  static void initialize(String userId, Hlc initialHlc) {
    if (_lastUserIdHlc.containsKey(userId)) return;
    _lastUserIdHlc[userId] = initialHlc;
  }

  /// Returns a cached instance of [StatefulHlc] for the provided [nodeId].
  static StatefulHlc cached(String userId, String nodeId) {
    return _instances.putIfAbsent(nodeId, () => StatefulHlc._(userId, nodeId));
  }

  /// The user ID for the CRDT system.
  final String userId;

  /// The node ID for the CRDT system.
  final String nodeId;

  /// The current HLC timestamp for the user. Will be incremented on each operation.
  late Hlc lastHlc;

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
