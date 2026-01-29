import 'package:crdt/crdt.dart';

/// Utilities for working with normalized HLC representation.
///
/// The normalized representation stores HLC as three separate components:
/// - datetime: Unix timestamp in microseconds (int64)
/// - counter: The logical counter (int32)
/// - nodeId: Reference to the node ID in the nodes table (int32)
class NormalizedHlc {
  /// Creates a normalized HLC representation.
  const NormalizedHlc({
    required this.datetime,
    required this.counter,
    required this.nodeId,
  });

  /// Unix timestamp in microseconds.
  final int datetime;

  /// The logical counter.
  final int counter;

  /// The node ID (normalized integer reference).
  final int nodeId;

  /// Extracts datetime (as Unix microseconds) from an HLC.
  static int extractDatetime(Hlc hlc) {
    final hlcStr = hlc.toString();
    final timestampEnd = hlcStr.indexOf('Z-');
    if (timestampEnd == -1) {
      throw FormatException('Invalid HLC format: $hlcStr');
    }
    final datetimeStr = hlcStr.substring(0, timestampEnd + 1);
    final dateTime = DateTime.parse(datetimeStr);
    return dateTime.microsecondsSinceEpoch;
  }

  /// Extracts the counter from an HLC.
  static int extractCounter(Hlc hlc) {
    return hlc.counter;
  }

  /// Reconstructs an HLC from normalized components.
  static Hlc reconstruct({
    required int datetime,
    required int counter,
    required String nodeId,
  }) {
    final dateTime = DateTime.fromMicrosecondsSinceEpoch(datetime, isUtc: true);
    final timestamp = dateTime.toIso8601String();
    final counterHex = counter.toRadixString(16).padLeft(4, '0');
    return Hlc.parse('$timestamp-$counterHex-$nodeId');
  }

  /// Converts this normalized HLC to an Hlc object.
  Hlc toHlc(String nodeId) {
    return reconstruct(
      datetime: datetime,
      counter: counter,
      nodeId: nodeId,
    );
  }
}
