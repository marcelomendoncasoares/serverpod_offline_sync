// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

const benchmarkScope = 'offline-sync-benchmark-admin';

String requireSecret({String? password}) {
  final secret = Platform.environment['BENCHMARK_SECRET'] ?? password;
  if (secret == null || secret.length < 24) {
    throw StateError(
      'Set BENCHMARK_SECRET or the benchmarkSecret Serverpod password '
      'to at least 24 characters.',
    );
  }
  return secret;
}

UuidValue benchmarkId(String value) => UuidValue.withValidation(
  const Uuid().v5(Namespace.url.value, 'offline-sync-benchmark/$value'),
);

String userToken(String secret, String userId) {
  final signature = Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(userId));
  return '$userId.$signature';
}

bool constantTimeEqual(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var i = 0; i < left.length; i++) {
    difference |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
  }
  return difference == 0;
}

/// Who a bearer token represents. Database checks (provisioned, not blocked)
/// happen afterwards on the server.
sealed class TokenIdentity {
  const TokenIdentity();
}

class AdminToken extends TokenIdentity {
  const AdminToken();
}

class UserTokenIdentity extends TokenIdentity {
  const UserTokenIdentity(this.userId);

  final UuidValue userId;
}

TokenIdentity? classifyToken(String secret, String token) {
  if (constantTimeEqual(token, secret)) return const AdminToken();
  final parts = token.split('.');
  if (parts.length != 2 || !constantTimeEqual(token, userToken(secret, parts.first))) {
    return null;
  }
  try {
    return UserTokenIdentity(UuidValue.withValidation(parts.first));
  } on FormatException {
    return null;
  }
}

class BenchmarkAuth implements ClientAuthKeyProvider {
  BenchmarkAuth(this.token);

  final String token;

  @override
  Future<String?> get authHeaderValue async => 'Bearer $token';
}

Future<Map<String, dynamic>> control(
  Client client,
  Map<String, dynamic> request,
) async {
  final response = await client.callServerEndpoint<String>(
    'benchmark',
    'control',
    {'request': jsonEncode(request)},
  );
  return jsonDecode(response) as Map<String, dynamic>;
}

String digestStrings(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return sha256.convert(utf8.encode(jsonEncode(sorted))).toString();
}

/// SQLite removes WAL/SHM files on checkpoint or close, so a file can vanish
/// between any two calls. Only a missing file means zero bytes.
int fileBytes(String path) {
  try {
    return File(path).lengthSync();
  } on PathNotFoundException {
    return 0;
  }
}

Map<String, int> sqliteFiles(String path) => {
  'databaseBytes': fileBytes(path),
  'walBytes': fileBytes('$path-wal'),
  'shmBytes': fileBytes('$path-shm'),
};

/// Linux reports CPU time in USER_HZ clock ticks, which the kernel ABI fixes
/// at 100 per second on the supported architectures.
const linuxTicksPerSecond = 100;

Map<String, dynamic> processSample() {
  final result = <String, dynamic>{
    'pid': pid,
    'rssBytes': ProcessInfo.currentRss,
    'maxRssBytes': ProcessInfo.maxRss,
  };
  if (Platform.isLinux) {
    final stat = File('/proc/self/stat').readAsStringSync();
    final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
    result['cpuUserTicks'] = int.parse(fields[11]);
    result['cpuSystemTicks'] = int.parse(fields[12]);
    result['openFds'] = Directory('/proc/self/fd').listSync().length;
    final threads = RegExp(
      r'^Threads:\s+(\d+)',
      multiLine: true,
    ).firstMatch(File('/proc/self/status').readAsStringSync());
    if (threads != null) result['threads'] = int.parse(threads.group(1)!);
  }
  return result;
}

/// CPU seconds consumed by this process, or null off Linux.
double? cpuSeconds() {
  if (!Platform.isLinux) return null;
  final sample = processSample();
  return ((sample['cpuUserTicks'] as int) + (sample['cpuSystemTicks'] as int)) /
      linuxTicksPerSecond;
}

/// Bounded logarithmic histogram of successful durations. Quantiles are bucket
/// upper bounds, not exact sample quantiles; failures are counted separately so
/// a fast rejection cannot hide a slow tail. Raw values remain in events.jsonl.
class Latencies {
  int count = 0;
  int failures = 0;
  int okTotal = 0;
  int okMaximum = 0;
  int failureMaximum = 0;
  final buckets = <int, int>{};

  int get ok => count - failures;

  void add(int micros, {required bool ok}) {
    count++;
    if (!ok) {
      failures++;
      failureMaximum = max(failureMaximum, micros);
      return;
    }
    okTotal += micros;
    okMaximum = max(okMaximum, micros);
    final bucket = micros <= 1 ? 1 : pow(1.1, (log(micros) / log(1.1)).ceil()).ceil();
    buckets.update(bucket, (v) => v + 1, ifAbsent: () => 1);
  }

  int? quantile(double fraction) {
    if (ok == 0) return null;
    final target = max(1, (ok * fraction).ceil());
    var accumulated = 0;
    for (final bucket in buckets.keys.toList()..sort()) {
      accumulated += buckets[bucket]!;
      if (accumulated >= target) return bucket;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'count': count,
    'ok': ok,
    'failures': failures,
    'meanMicros': ok == 0 ? null : okTotal / ok,
    'maxMicros': ok == 0 ? null : okMaximum,
    'failureMaxMicros': failures == 0 ? null : failureMaximum,
    'p50UpperMicros': quantile(0.50),
    'p95UpperMicros': quantile(0.95),
    'p99UpperMicros': quantile(0.99),
  };
}

/// Measures how late a periodic timer fires. Sustained lag means the isolate
/// running device logic is saturated, so client-side measurements and offered
/// load reflect the load generator rather than the server.
class LoopLag {
  LoopLag({this.interval = const Duration(milliseconds: 100)});

  final Duration interval;
  final _watch = Stopwatch();
  Timer? _timer;
  int _previous = 0;
  var window = Latencies();
  final marks = <String, Latencies>{};

  void start() {
    _watch.start();
    _previous = _watch.elapsedMicroseconds;
    _timer = Timer.periodic(interval, (_) {
      final now = _watch.elapsedMicroseconds;
      final lag = max(0, now - _previous - interval.inMicroseconds);
      _previous = now;
      window.add(lag, ok: true);
      for (final mark in marks.values) {
        mark.add(lag, ok: true);
      }
    });
  }

  /// Returns and resets the samples since the previous call.
  Map<String, dynamic> takeWindow() {
    final result = window.toJson();
    window = Latencies();
    return result;
  }

  void stop() => _timer?.cancel();
}

/// Git checkout facts for [directory]. This describes a checkout, which is not
/// necessarily the code an executable was built from.
Future<Map<String, dynamic>> gitMetadata(String directory) async {
  try {
    final revision = await Process.run('git', ['-C', directory, 'rev-parse', 'HEAD']);
    if (revision.exitCode != 0) return {'directory': directory, 'revision': null};
    final status = await Process.run('git', [
      '-C',
      directory,
      'status',
      '--porcelain',
    ]);
    return {
      'directory': directory,
      'revision': revision.stdout.toString().trim(),
      'dirty': status.exitCode == 0 ? status.stdout.toString().isNotEmpty : null,
    };
  } on ProcessException {
    return {'directory': directory, 'revision': null, 'gitAvailable': false};
  }
}

Future<String> sha256OfFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();

/// Identity of the code this process runs. JIT runs execute source, described
/// by the script's checkout. Native bundles are identified by their executable
/// hash; `build-info.json` from tool/build_native.dart adds the build revision
/// only when its recorded hash matches the running executable.
Future<Map<String, dynamic>> executableIdentity() async {
  final script = Platform.script;
  if (script.path.endsWith('.dart')) {
    final path = script.toFilePath();
    return {
      'mode': 'jit',
      'script': path,
      'dartVersion': Platform.version,
      'source': await gitMetadata(p.dirname(path)),
    };
  }
  final executable = Platform.resolvedExecutable;
  final hash = await sha256OfFile(executable);
  final stampFile = File(p.join(p.dirname(p.dirname(executable)), 'build-info.json'));
  Map<String, dynamic>? stamp;
  if (stampFile.existsSync()) {
    stamp = jsonDecode(stampFile.readAsStringSync()) as Map<String, dynamic>;
  }
  return {
    'mode': 'aot',
    'executable': executable,
    'executableSha256': hash,
    'dartVersion': Platform.version,
    'buildStamp': stamp,
    'buildStampMatches': stamp == null ? null : stamp['executableSha256'] == hash,
  };
}

/// Deterministic 32-bit FNV-1a over integers. Unlike Object.hash, the result
/// is stable across processes, which keeps seeded workloads reproducible.
int mixSeed(Iterable<int> parts) {
  var hash = 0x811c9dc5;
  for (final part in parts) {
    var value = part;
    for (var i = 0; i < 8; i++) {
      hash = ((hash ^ (value & 0xff)) * 0x01000193) & 0xffffffff;
      value >>= 8;
    }
  }
  return hash;
}

const _payloadAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

/// Seeded ASCII text of exactly [length] characters. The uniformly random
/// characters (6 bits each) are not meaningfully compressible, so PostgreSQL
/// TOAST cannot shrink them. The readable [prefix] is kept only when at least
/// 16 random characters follow it, so short payloads stay random too.
String seededPayload(int seed, int length, String prefix) {
  final random = Random(seed);
  final buffer = StringBuffer(length >= prefix.length + 16 ? prefix : '');
  while (buffer.length < length) {
    buffer.writeCharCode(_payloadAlphabet.codeUnitAt(random.nextInt(64)));
  }
  return buffer.toString();
}

/// [candidate], or, when it equals [previous], the same text with its last
/// character advanced. A rename therefore changes the value at any length.
String distinctFrom(String? previous, String candidate) {
  if (candidate != previous || candidate.isEmpty) return candidate;
  final last = _payloadAlphabet.indexOf(candidate[candidate.length - 1]);
  return candidate.substring(0, candidate.length - 1) +
      _payloadAlphabet[(last + 1) % _payloadAlphabet.length];
}

/// A single pool of permits. Every leaf operation takes one permit directly, so
/// the cap holds however callers group their work; nothing holds a permit
/// while waiting for another, so it cannot deadlock.
class Semaphore {
  Semaphore(this.permits) : assert(permits > 0);

  final int permits;
  var _inUse = 0;
  var peak = 0;
  final _waiting = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() action) async {
    if (_inUse >= permits) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _inUse++;
    }
    peak = max(peak, _inUse);
    try {
      return await action();
    } finally {
      // Hand the permit straight to the next waiter, keeping _inUse unchanged.
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _inUse--;
      }
    }
  }
}

/// Runs [action] for every item with at most [concurrency] in flight. After a
/// failure no new items start; the first error is rethrown once lanes drain.
Future<void> forEachBounded<T>(
  Iterable<T> items,
  int concurrency,
  Future<void> Function(T item) action,
) async {
  final iterator = items.iterator;
  var failed = false;
  Future<void> lane() async {
    while (!failed && iterator.moveNext()) {
      try {
        await action(iterator.current);
      } catch (_) {
        failed = true;
        rethrow;
      }
    }
  }

  await Future.wait([for (var i = 0; i < max(1, concurrency); i++) lane()]);
}
