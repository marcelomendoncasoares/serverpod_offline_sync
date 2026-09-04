/// Constant fixtures for the `Hlc` tests.
///
/// Nothing here reads the wall clock or generates a random value, because both
/// make an HLC test depend on when it runs.
///
/// `Hlc.increment` and `Hlc.merge` compare against `clock.now()` and reject a
/// timestamp that drifts more than a minute from it, so a fixture built from
/// `DateTime.now()` only passes while the run is close to the moment the
/// fixture was created. On a runner that re-executes tests in the same process
/// that stops being true, since a top-level `final` is initialized once per
/// isolate and can outlive the values derived from it.
///
/// Node ids are fixed for the same reason: `Hlc.compareTo` breaks ties on the
/// node uuid, so a random id makes the expected ordering vary between runs.
library;

import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';

/// The instant the HLC tests treat as the current wall time.
final hlcTime = DateTime.parse('2001-09-09T01:46:40.000Z');

/// A node id that sorts before [hlcSecondNodeId].
final hlcNodeId = UuidValue.withValidation(
  '11111111-1111-4111-8111-111111111111',
);

/// A node id that sorts after [hlcNodeId].
final hlcSecondNodeId = UuidValue.withValidation(
  '22222222-2222-4222-8222-222222222222',
);

/// Runs [body] with the wall clock pinned to [wallTime].
T atWallTime<T>(DateTime wallTime, T Function() body) =>
    withClock(Clock.fixed(wallTime), body);

/// Offsets for building fixtures relative to [hlcTime].
extension HlcFixtureTime on DateTime {
  /// This instant one millisecond later.
  DateTime advance([Duration duration = const Duration(milliseconds: 1)]) =>
      add(duration);

  /// This instant one millisecond earlier.
  DateTime retreat([Duration duration = const Duration(milliseconds: 1)]) =>
      subtract(duration);
}
