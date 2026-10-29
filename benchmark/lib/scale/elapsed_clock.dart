// Internal benchmark tooling, not a published library API.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Measures benchmark intervals without Linux clock-discipline frequency slews.
///
/// CLOCK_MONOTONIC_RAW is independent of NTP frequency adjustments. Stopwatch
/// uses the disciplined monotonic clock, which this benchmark machine has been
/// observed slowing by several percent relative to the remote server's clock.
class ElapsedClock {
  static final _fallback = Stopwatch()..start();
  static final _raw = Platform.isLinux ? _RawClock() : null;

  /// Identifies the clock in each benchmark observation.
  static String get source => _raw == null ? 'Stopwatch' : 'CLOCK_MONOTONIC_RAW';

  static int _now() => _raw?.microseconds ?? _fallback.elapsedMicroseconds;

  int _elapsed = 0;
  int? _started;

  /// Elapsed microseconds, excluding explicitly stopped intervals.
  int get elapsedMicroseconds => _elapsed + (_started == null ? 0 : _now() - _started!);

  /// Starts or resumes the clock.
  void start() => _started ??= _now();

  /// Stops the clock without discarding its elapsed time.
  void stop() {
    final started = _started;
    if (started == null) return;
    _elapsed += _now() - started;
    _started = null;
  }
}

final class _Timespec extends Struct {
  @Long()
  external int seconds;

  @Long()
  external int nanoseconds;
}

class _RawClock {
  // One synchronous scratch allocation per worker isolate, retained for its
  // lifetime. Reading the clock neither awaits nor allocates per observation.
  final _value = calloc<_Timespec>();
  final _read = DynamicLibrary.process()
      .lookupFunction<
        Int32 Function(Int32, Pointer<_Timespec>),
        int Function(int, Pointer<_Timespec>)
      >('clock_gettime');

  int get microseconds {
    if (_read(4, _value) != 0) {
      throw StateError('Cannot read CLOCK_MONOTONIC_RAW for benchmark timing.');
    }
    return _value.ref.seconds * 1000000 + _value.ref.nanoseconds ~/ 1000;
  }
}
