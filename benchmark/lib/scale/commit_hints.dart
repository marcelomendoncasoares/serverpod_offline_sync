// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

BenchmarkCommitHints? benchmarkCommitHints;

/// Both comparison arms publish the same notifications. The control drops
/// reception deliberately, exercising durable polling on the identical binary.
class BenchmarkCommitHints implements OfflineSyncCommitHints {
  BenchmarkCommitHints(this.transport);

  final PostgresSyncCommitHints transport;
  bool deliver = true;
  int received = 0;
  int suppressed = 0;

  Map<String, Object> get status => {
    'enabled': true,
    'connected': transport.isConnected,
    'deliver': deliver,
    'received': received,
    'suppressed': suppressed,
    'droppedRevisions': transport.droppedRevisions,
  };

  @override
  Stream<Map<UuidValue, int>> get changes => transport.changes.where((_) {
    received++;
    if (!deliver) suppressed++;
    return deliver;
  });

  @override
  void publish(Map<UuidValue, int> revisions) => transport.publish(revisions);

  @override
  Future<void> close() => transport.close();
}

BenchmarkCommitHints? createBenchmarkCommitHints(Serverpod pod) {
  if (Platform.environment['BENCHMARK_COMMIT_HINTS'] != 'on') return null;
  final config = pod.config.database;
  if (config is! PostgresDatabaseConfig) {
    throw StateError('Commit-hint benchmarks require PostgreSQL.');
  }

  // Neon explicitly does not support LISTEN on transaction-pooled endpoints.
  // The benchmark keeps application pooling intact and uses the corresponding
  // direct endpoint for this dedicated session. Never log connection settings.
  final host = config.host.endsWith('.neon.tech')
      ? config.host.replaceFirst('-pooler.', '.')
      : config.host;
  return benchmarkCommitHints = BenchmarkCommitHints(
    PostgresSyncCommitHints.fromConfig(config, host: host == config.host ? null : host),
  );
}
