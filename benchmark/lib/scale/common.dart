// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

const benchmarkScope = 'offline-sync-benchmark-admin';

String requireSecret() {
  final secret = Platform.environment['BENCHMARK_SECRET'];
  if (secret == null || secret.length < 24) {
    throw StateError('Set BENCHMARK_SECRET to at least 24 characters.');
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

/// Domain values only: spaceId is a database-local surrogate, not synced data.
Map<String, dynamic> snapshotOf(Map<String, List<Map<String, dynamic>>> tables) {
  final canonical = <String>[];
  final counts = <String, int>{};
  for (final entry in tables.entries) {
    counts[entry.key] = entry.value.length;
    for (final row in entry.value) {
      final keys =
          row.keys.where((k) => k != 'spaceId' && k != '__className__').toList()
            ..sort();
      canonical.add(
        jsonEncode([
          entry.key,
          {for (final key in keys) key: row[key]},
        ]),
      );
    }
  }
  return {
    'digest': digestStrings(canonical),
    'rows': counts,
    'receiptsDigest': digestStrings(tables['person']!.map((r) => r['id'].toString())),
  };
}

Map<String, int> sqliteFiles(String path) => {
  for (final suffix in ['', '-wal', '-shm'])
    suffix.isEmpty ? 'databaseBytes' : '${suffix.substring(1)}Bytes':
        File('$path$suffix').existsSync() ? File('$path$suffix').lengthSync() : 0,
};

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
  }
  return result;
}
