import 'package:crdt/crdt.dart';

import 'normalized.dart';

/// A [Hlc] instance that is used to generate unique timestamps for CRDT operations.
/// Will keep track of the HLC during the lifetime of the application.
/// 
/// Supports both traditional HLC format and normalized format for reduced storage.
class StatefulHlc {
  StatefulHlc._(this.userId, this.nodeId, this.normalizedNodeId) {
    lastHlc = _lastUserIdHlc[userId]?.apply(nodeId: nodeId) ?? Hlc.zero(nodeId);
  }

  static final Map<String, Hlc> _lastUserIdHlc = {};
  static final Map<String, StatefulHlc> _instances = {};
  static final Map<String, int> _nodeIdToNormalized = {};

  /// Initialize the HLC for the provided [userId].
  ///
  /// This method allows a pre-initialization of the HLC for the node from the
  /// last stored HLC for the user - regardless of the node ID. If no [initialHlc]
  /// is provided, a zero HLC will be used.
  static void initialize(String userId, Hlc initialHlc) {
    if (_lastUserIdHlc.containsKey(userId)) return;
    _lastUserIdHlc[userId] = initialHlc;
  }

  /// Registers the normalized node ID for a given node ID string.
  ///
  /// This is used to track the integer ID that corresponds to a node ID string
  /// in the normalized schema. Must be called during initialization.
  static void registerNormalizedNodeId(String nodeId, int normalizedId) {
    _nodeIdToNormalized[nodeId] = normalizedId;
  }

  /// Returns a cached instance of [StatefulHlc] for the provided [nodeId].
  static StatefulHlc cached(String userId, String nodeId) {
    return _instances.putIfAbsent(nodeId, () {
      final normalizedId = _nodeIdToNormalized[nodeId];
      if (normalizedId == null) {
        throw StateError(
          'Normalized node ID for "$nodeId" not registered. '
          'Call registerNormalizedNodeId() during initialization.',
        );
      }
      return StatefulHlc._(userId, nodeId, normalizedId);
    });
  }

  /// Returns a cached instance for the current user, regardless of node ID.
  ///
  /// This is used by the database function which doesn't receive a node ID parameter.
  /// Returns null if no instance has been cached yet for this user.
  static StatefulHlc? getCachedInstance(String userId) {
    // Find any cached instance for this user
    for (final instance in _instances.values) {
      if (instance.userId == userId) {
        return instance;
      }
    }
    return null;
  }

  /// The user ID for the CRDT system.
  final String userId;

  /// The node ID for the CRDT system.
  final String nodeId;

  /// The normalized node ID (integer reference to __crdt_nodes table).
  final int normalizedNodeId;

  /// The current HLC timestamp for the user. Will be incremented on each operation.
  late Hlc lastHlc;

  /// Returns the next HLC timestamp for the current node.
  Hlc increment() {
    lastHlc = lastHlc.increment();
    return lastHlc;
  }

  /// Returns the next HLC as normalized components (datetime, counter).
  ///
  /// This is used by the database trigger function to return only the
  /// timestamp and counter, reducing the data that needs to be passed around.
  /// The node ID is implicit (always uses normalizedNodeId).
  ///
  /// Returns a tuple of (datetime_microseconds, counter).
  (int, int) incrementNormalized() {
    lastHlc = lastHlc.increment();
    return (
      NormalizedHlc.extractDatetime(lastHlc),
      NormalizedHlc.extractCounter(lastHlc),
    );
  }

  /// Merges another [Hlc] instance into the current one.
  void merge(Hlc other) {
    lastHlc = lastHlc.merge(other);
  }
}
