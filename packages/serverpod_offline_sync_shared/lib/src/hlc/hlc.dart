// This file includes code from the project: https://github.com/cachapa/crdt
// Licensed under Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0
// Copyright Daniel Cachapa.
//
// Modifications copyright 2026 Marcelo Soares
// Licensed under MIT License: https://opensource.org/licenses/MIT

import 'package:clock/clock.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../src/generated/hlc/base.dart';
import 'exceptions.dart';
import 'node_with_worker.dart';

/// A Hybrid Logical Clock implementation that supports both ISO 8601 and Unix
/// timestamp formats. The datetime component has millisecond precision and is
/// always stored in UTC.
///
/// Although the original HLC paper uses microsecond precision, since it was
/// proved that the counter typically stays in single digits, millisecond
/// precision can be considered enough for the vast majority of applications.
///
/// The advantage of using milliseconds is that the timestamp can be generated
/// on any database (inside SQLite3 for example) and will occupy less space in
/// the database.
///
/// Inspiration: https://cse.buffalo.edu/tech-reports/2014-04.pdf
@immutable
class Hlc implements Comparable<Hlc> {
  /// Creates a new instance of [Hlc].
  ///
  /// Precision of the [datetime] is milliseconds.
  factory Hlc(DateTime datetime, int counter, NodeWithWorker node) =>
      Hlc._(datetime.toUtcMillisecond(), counter, node);

  const Hlc._(this.datetime, this.counter, this.node) : assert(counter <= _maxCounter);

  /// Instantiates an Hlc at the beginning of time and space: January 1, 1970.
  factory Hlc.zero(NodeWithWorker node) => Hlc(DateTime.utc(1970), 0, node);

  /// Instantiates an Hlc using the wall clock.
  factory Hlc.now(NodeWithWorker node) => Hlc(DateTime.now(), 0, node);

  /// Parse an HLC string in the format `<ISO8601_date>-<counter>-<node_id>:<worker_id>`
  /// or `<unix_timestamp>-<counter>-<node_id>:<worker_id>`.
  factory Hlc.parse(String timestamp) {
    final indexOfColon = timestamp.indexOf(':');
    final indexOfStart = indexOfColon > 0 && indexOfColon < 20 ? indexOfColon : 0;

    final counterDash = timestamp.indexOf('-', indexOfStart);
    final timestampPart = timestamp.substring(0, counterDash);

    final nodeIdDash = timestamp.indexOf('-', counterDash + 1);
    final counterPart = timestamp.substring(counterDash + 1, nodeIdDash);

    final unixTimestamp = int.tryParse(timestampPart);
    final datetime = unixTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(unixTimestamp, isUtc: true)
        : DateTime.tryParse(timestampPart);

    if (datetime == null) {
      throw FormatException('Invalid HLC string: $timestamp');
    }

    final counter = int.parse(counterPart, radix: 16);
    final nodeIdPart = timestamp.substring(nodeIdDash + 1);
    return Hlc(datetime, counter, NodeWithWorker.parse(nodeIdPart));
  }

  /// Convenience method to decode the HLC from a JSON map.
  factory Hlc.fromJson(Map<String, dynamic> json) => Hlc(
    DateTime.parse(json['datetime'] as String),
    int.parse(json['counter'] as String, radix: 16),
    NodeWithWorker.parse(json['node'] as String),
  );

  /// The date and time of the HLC.
  final DateTime datetime;

  /// The counter of the HLC.
  final int counter;

  /// The node with worker ID of the HLC.
  final NodeWithWorker node;

  /// The Unix timestamp of the HLC.
  int get unixTimestamp => datetime.millisecondsSinceEpoch;

  static const _maxDrift = Duration(minutes: 1);
  static const _maxCounter = 0xFFFF;

  /// Increments the current timestamp for transmission to another system.
  Hlc increment() {
    final localWallTime = clock.now().toUtc();
    final datetimeNew = localWallTime.isAfter(datetime) ? localWallTime : datetime;
    final counterNew = datetimeNew == datetime ? counter + 1 : 0;

    if (datetimeNew.difference(localWallTime) > const Duration(minutes: 1)) {
      throw ClockDriftException(datetimeNew, localWallTime, _maxDrift);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(datetimeNew, counterNew, node);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// timestamp to preserve monotonicity.
  Hlc merge(Hlc remote) {
    if (remote.datetime.isBefore(datetime) ||
        (remote.datetime.isAtSameMomentAs(datetime) && remote.counter <= counter)) {
      return this;
    }

    if (node.nodeId == remote.node.nodeId) {
      throw DuplicateNodeException(node.nodeId);
    }

    final localWallTime = clock.now().toUtc();
    if (remote.datetime.difference(localWallTime) > _maxDrift) {
      throw ClockDriftException(remote.datetime, localWallTime, _maxDrift);
    }

    return remote.copyWith(node: node);
  }

  /// Create a copy of this object replacing the optional properties.
  Hlc copyWith({DateTime? datetime, int? counter, NodeWithWorker? node}) => Hlc(
    datetime ?? this.datetime,
    counter ?? this.counter,
    node ?? this.node,
  );

  @override
  String toString() =>
      '${datetime.toIso8601String()}-'
      '${counter.toRadixString(16).toUpperCase().padLeft(4, '0')}-'
      '$node'; // Format: <ISO8601_date>-<counter>-<node_id>:<worker_id>

  /// Convenience method for easy json encoding.
  Map<String, dynamic> toJson() => {
    'datetime': datetime.toIso8601String(),
    'counter': counter.toRadixString(16).toUpperCase().padLeft(4, '0'),
    'node': node.toString(),
  };

  @override
  int get hashCode => toString().hashCode;

  @override
  bool operator ==(Object other) => other is Hlc && compareTo(other) == 0;

  /// Whether this [Hlc] is causally before the [other].
  bool operator <(Object other) => other is Hlc && compareTo(other) < 0;

  /// Whether this [Hlc] is causally before or equal to the [other].
  bool operator <=(Object other) => this < other || this == other;

  /// Whether this [Hlc] is causally after the [other].
  bool operator >(Object other) => other is Hlc && compareTo(other) > 0;

  /// Whether this [Hlc] is causally after or equal to the [other].
  bool operator >=(Object other) => this > other || this == other;

  @override
  int compareTo(Hlc other) => datetime.isAtSameMomentAs(other.datetime)
      ? counter == other.counter
            ? node.compareTo(other.node)
            : counter - other.counter
      : datetime.compareTo(other.datetime);
}

extension on DateTime {
  DateTime toUtcMillisecond() =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: true);
}

/// Extensions for [BaseHlc] to convert it to an [Hlc].
extension BaseHlcToHlc on BaseHlc {
  /// Converts the [BaseHlc] to an [Hlc] with the given [nodeId].
  Hlc toHlcForNode(UuidValue nodeId) =>
      Hlc(datetime, counter, NodeWithWorker(nodeId: nodeId, workerId: workerId));
}
