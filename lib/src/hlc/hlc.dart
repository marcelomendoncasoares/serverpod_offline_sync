// This file includes code from the project: https://github.com/cachapa/crdt
// Licensed under Apache License 2.0: https://www.apache.org/licenses/LICENSE-2.0
// Copyright Daniel Cachapa.
//
// Modifications copyright 2026 Marcelo Soares
// Licensed under MIT License: https://opensource.org/licenses/MIT

import 'package:clock/clock.dart';

import 'exceptions.dart';

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
class Hlc implements Comparable<Hlc> {
  /// Creates a new instance of [Hlc].
  Hlc(DateTime dateTime, this.counter, this.nodeId)
    : dateTime = dateTime.toUtcMillisecond(),
      assert(counter <= _maxCounter);

  /// Instantiates an Hlc at the beginning of time and space: January 1, 1970.
  Hlc.zero(String nodeId) : this(DateTime.utc(1970), 0, nodeId);

  /// Instantiates an Hlc using the wall clock.
  Hlc.now(String nodeId) : this(DateTime.now(), 0, nodeId);

  /// Parse an HLC string in the format `<ISO8601_date>-<counter>-<node_id>` or
  /// `<unix_timestamp>-<counter>-<node_id>`.
  factory Hlc.parse(String timestamp) {
    final indexOfColon = timestamp.lastIndexOf(':');
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
    final nodeId = timestamp.substring(nodeIdDash + 1);
    return Hlc(datetime, counter, nodeId);
  }

  /// The date and time of the HLC.
  final DateTime dateTime;

  /// The counter of the HLC.
  final int counter;

  /// The node ID of the HLC.
  final String nodeId;

  /// The Unix timestamp of the HLC.
  int get unixTimestamp => dateTime.millisecondsSinceEpoch;

  static const _maxDrift = Duration(minutes: 1);
  static const _maxCounter = 0xFFFF;

  /// Increments the current timestamp for transmission to another system.
  Hlc increment() {
    final localWallTime = clock.now().toUtc();
    final dateTimeNew = localWallTime.isAfter(dateTime) ? localWallTime : dateTime;
    final counterNew = dateTimeNew == dateTime ? counter + 1 : 0;

    if (dateTimeNew.difference(localWallTime) > const Duration(minutes: 1)) {
      throw ClockDriftException(dateTimeNew, localWallTime, _maxDrift);
    }
    if (counterNew > _maxCounter) {
      throw OverflowException(counterNew);
    }

    return Hlc(dateTimeNew, counterNew, nodeId);
  }

  /// Compares and validates a timestamp from a remote system with the local
  /// timestamp to preserve monotonicity.
  Hlc merge(Hlc remote) {
    if (remote.dateTime.isBefore(dateTime) ||
        (remote.dateTime.isAtSameMomentAs(dateTime) && remote.counter <= counter)) {
      return this;
    }

    if (nodeId == remote.nodeId) {
      throw DuplicateNodeException(nodeId);
    }

    final localWallTime = clock.now().toUtc();
    if (remote.dateTime.difference(localWallTime) > _maxDrift) {
      throw ClockDriftException(remote.dateTime, localWallTime, _maxDrift);
    }

    return remote.copyWith(nodeId: nodeId);
  }

  /// Create a copy of this object replacing the optional properties.
  Hlc copyWith({DateTime? dateTime, int? counter, String? nodeId}) =>
      Hlc(dateTime ?? this.dateTime, counter ?? this.counter, nodeId ?? this.nodeId);

  /// Convenience method for easy json encoding.
  String toJson({bool unixTimestamp = false}) => toString(unixTimestamp: unixTimestamp);

  @override
  String toString({bool unixTimestamp = false}) => [
    if (unixTimestamp)
      this.unixTimestamp.toString().padLeft(15, '0')
    else
      dateTime.toIso8601String(),
    counter.toRadixString(16).toUpperCase().padLeft(4, '0'),
    nodeId,
  ].join('-');

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
  int compareTo(Hlc other) => dateTime.isAtSameMomentAs(other.dateTime)
      ? counter == other.counter
            ? nodeId.compareTo(other.nodeId)
            : counter - other.counter
      : dateTime.compareTo(other.dateTime);
}

extension on DateTime {
  DateTime toUtcMillisecond() =>
      DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch, isUtc: true);
}
