import 'package:serverpod_serialization/serverpod_serialization.dart';

/// Exception thrown when the clock drift exceeds the maximum allowed.
class ClockDriftException implements Exception {
  /// Creates a new instance of [ClockDriftException].
  ClockDriftException(DateTime dateTime, DateTime wallTime, this.maxDrift)
    : drift = dateTime.difference(wallTime);

  /// The duration of the clock drift.
  final Duration drift;

  /// The maximum allowed clock drift.
  final Duration maxDrift;

  @override
  String toString() => 'Clock drift of $drift ms exceeds maximum ($maxDrift)';
}

/// Exception thrown when the timestamp counter overflows.
class OverflowException implements Exception {
  /// Creates a new instance of [OverflowException].
  OverflowException(this.counter);

  /// The counter that overflowed.
  final int counter;

  @override
  String toString() => 'Timestamp counter overflow: $counter';
}

/// Exception thrown when a duplicate node is detected.
class DuplicateNodeException implements Exception {
  /// Creates a new instance of [DuplicateNodeException].
  DuplicateNodeException(this.nodeId);

  /// The node ID that is duplicated.
  final UuidValue nodeId;

  @override
  String toString() => 'Duplicate node: $nodeId';
}
