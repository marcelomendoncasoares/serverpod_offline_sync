import 'package:crdt/crdt.dart';

/// A [Hlc] instance that is used to generate unique timestamps for CRDT operations.
/// Will keep track of the HLC during the lifetime of the application.
class StatefulHlc {
  StatefulHlc._(this.nodeId) : lastHlc = Hlc.now(nodeId);

  static final Map<String, StatefulHlc> _instances = {};

  /// Returns a cached instance of [StatefulHlc] for the provided [nodeId].
  static StatefulHlc cached(String nodeId) {
    return _instances.putIfAbsent(nodeId, () => StatefulHlc._(nodeId));
  }

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
