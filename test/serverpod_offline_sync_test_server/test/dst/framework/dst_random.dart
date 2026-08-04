import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';

/// Seeded randomness for the deterministic simulation harness.
///
/// Every choice a simulation makes - which replica acts, which operation it
/// performs, which row it targets, how the adversary schedules delivery - is
/// drawn from this generator. A run is therefore fully described by its seed,
/// and a failing run replays exactly by setting `DST_SEED_BASE`.
class DstRandom {
  /// Creates a generator for one simulation run.
  DstRandom(this.seed) : _random = Random(seed);

  /// The seed this generator was created from. Printed on failure so the run
  /// can be replayed.
  final int seed;

  final Random _random;

  /// A uniform integer in `[0, max)`.
  int nextInt(int max) => _random.nextInt(max);

  /// A uniform integer in `[min, max]`.
  int between(int min, int max) => min + _random.nextInt(max - min + 1);

  /// Whether an event with probability [probability] occurs.
  bool chance(double probability) => _random.nextDouble() < probability;

  /// A uniformly chosen element of [items], which must not be empty.
  T pick<T>(List<T> items) => items[_random.nextInt(items.length)];

  /// A uniformly chosen element of [items], or null when it is empty.
  T? pickOrNull<T>(List<T> items) => items.isEmpty ? null : pick(items);

  /// Picks one entry from [weights] proportionally to its weight.
  T weighted<T>(Map<T, int> weights) {
    final total = weights.values.fold(0, (sum, weight) => sum + weight);
    var roll = _random.nextInt(total);
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll < 0) return entry.key;
    }
    return weights.keys.last;
  }
}

/// Mints UUIDv7-shaped identifiers from the simulation seed.
///
/// Every identifier the simulation controls comes from here. `Uuid().v7obj()`
/// draws on the wall clock and platform randomness, so a run that used it
/// would not replay from its seed. This matters beyond row identity: node
/// identifiers break HLC ties (`Hlc.compareTo` falls through to the node UUID),
/// so a nondeterministic node id makes concurrent merge winners
/// nondeterministic too.
///
/// The 48-bit timestamp prefix is a counter rather than a clock reading, which
/// preserves v7's sort-by-creation property while keeping the value a pure
/// function of the seed.
class DstIds {
  /// Creates a generator drawing its random suffix from [DstRandom].
  DstIds(this._random);

  final DstRandom _random;
  var _counter = 0;

  /// The next identifier. Unique for the lifetime of this generator.
  UuidValue next() {
    final bytes = Uint8List(16);
    final stamp = ++_counter;
    for (var index = 0; index < 6; index++) {
      bytes[5 - index] = (stamp >> (8 * index)) & 0xFF;
    }
    for (var index = 6; index < 16; index++) {
      bytes[index] = _random.nextInt(256);
    }
    bytes[6] = (bytes[6] & 0x0F) | 0x70; // Version 7.
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // RFC 4122 variant.

    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();
    return UuidValue.withValidation(
      '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}',
    );
  }
}

/// A manually advanced clock for the simulation.
///
/// `Hlc` reads `clock.now()`, so driving time from here makes every HLC - and
/// therefore every merge tie-break - a function of the seed instead of the
/// wall clock.
///
/// Advances stay small on purpose. `Hlc` rejects a remote timestamp more than
/// one minute from local time with a `ClockDriftException`, so a simulation
/// that jumped time freely would fail on clock drift rather than on the
/// property under test. Drift deserves its own targeted test, not ambient
/// noise in every run.
class DstClock {
  /// Creates a clock starting at a fixed, seed-independent instant.
  DstClock() : _now = DateTime.utc(2026, 1, 1);

  DateTime _now;

  /// The clock to install with [withClock].
  Clock get clock => Clock(() => _now);

  /// A clock offset from this one, modelling per-replica time skew.
  Clock skewed(Duration offset) => Clock(() => _now.add(offset));

  /// Moves time forward. Callers keep steps small; see the class docs.
  void advance(Duration amount) => _now = _now.add(amount);
}

/// How many seeds to run and how long each simulation is.
///
/// Each run explores fresh schedules, because the seed base defaults to the
/// current time. The size stays small so `dart test` remains quick; a soak
/// widens it:
///
/// ```sh
/// DST_SEEDS=200 DST_ROUNDS=40 dart test test/dst
/// DST_SEED_BASE=1781161784 DST_SEEDS=1 dart test test/dst   # replay a failure
/// ```
class DstConfig {
  /// Creates an explicit configuration, mostly for focused tests.
  const DstConfig({
    required this.seedCount,
    required this.rounds,
    required this.seedBase,
  });

  /// Reads the sweep configuration from the environment.
  factory DstConfig.fromEnvironment() {
    return DstConfig(
      seedCount: _readInt('DST_SEEDS', 8),
      rounds: _readInt('DST_ROUNDS', 12),
      seedBase: _readInt('DST_SEED_BASE', _defaultSeedBase),
    );
  }

  /// How many seeds the sweep runs.
  final int seedCount;

  /// How many operation rounds each simulation performs.
  final int rounds;

  /// The first seed. Successive seeds are `seedBase + index`.
  final int seedBase;

  /// The seeds this sweep covers.
  Iterable<int> get seeds => Iterable.generate(seedCount, (index) => seedBase + index);

  /// Unix seconds, so an unset `DST_SEED_BASE` explores fresh schedules.
  ///
  /// A fixed default would be a smoke test rather than a search: the same
  /// simulations would run forever, and the suite would either catch a defect
  /// on every run or never. It fails silently, too - a change that shifts merge
  /// scheduling moves which defects those fixed seeds happen to reach, so
  /// coverage can disappear with nothing to show for it.
  ///
  /// Reproducibility is not lost, only deferred: a seed still determines its
  /// simulation entirely, every test names the seed it ran, and a failure
  /// prints the command that replays it.
  static int get _defaultSeedBase => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static int _readInt(String name, int fallback) {
    final raw = Platform.environment[name];
    if (raw == null || raw.isEmpty) return fallback;
    return int.tryParse(raw) ?? fallback;
  }
}
