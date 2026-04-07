import 'package:serverpod_serialization/serverpod_serialization.dart';

/// A value object that combines a node ID and a worker ID.
///
/// This class should be used on the HLC to ensure uniqueness of the HLC in
/// multi-worker setups.
class NodeWithWorker implements Comparable<NodeWithWorker>, SerializableModel {
  /// Creates a new [NodeWithWorker] value object.
  const NodeWithWorker({
    required this.nodeId,
    required this.workerId,
  });

  /// Converts the [NodeWithWorker] from a JSON map.
  factory NodeWithWorker.fromJson(Map<String, dynamic> json) => NodeWithWorker(
    nodeId: UuidValue.withValidation(json['n'] as String),
    workerId: json['w'] as int,
  );

  /// Parses a [NodeWithWorker] from a string in the format `<node_id>:<worker_id>`.
  factory NodeWithWorker.parse(String value) {
    final parts = value.split(':');
    return NodeWithWorker(
      nodeId: UuidValue.withValidation(parts[0]),
      workerId: int.parse(parts[1]),
    );
  }

  /// The node ID.
  final UuidValue nodeId;

  /// The worker ID.
  final int workerId;

  @override
  int compareTo(NodeWithWorker other) => toString().compareTo(other.toString());

  @override
  String toString() => '$nodeId:$workerId';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeWithWorker && nodeId == other.nodeId && workerId == other.workerId;

  @override
  int get hashCode => nodeId.hashCode ^ workerId.hashCode;

  /// Converts the [NodeWithWorker] to a JSON map.
  @override
  Map<String, dynamic> toJson() => {
    'n': nodeId.toJson(),
    'w': workerId,
  };
}
