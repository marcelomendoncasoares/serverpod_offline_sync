import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_benchmark/scale/commit_hints.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server_diagnostics.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:serverpod_offline_sync_test_server/src/generated/sync_tables.dart';

Future<void> main(List<String> args) async {
  late AuthenticationHandler authenticate;
  final pod = Serverpod(
    args,
    model.Protocol(),
    BenchmarkEndpoints(),
    configOverride: benchmarkServerConfig,
    authenticationHandler: (session, token) => authenticate(session, token),
    databaseInterceptor: benchmarkDatabaseInterceptor,
  );
  pod.initializeOfflineSync(
    syncTables: syncTables,
    commitHints: createBenchmarkCommitHints(pod),
  );
  final passwordName = benchmarkPasswordName();
  final password = pod.getPassword(passwordName);
  if (password != null && Platform.environment.containsKey('BENCHMARK_SECRET')) {
    stderr.writeln('Using the $passwordName password; BENCHMARK_SECRET is ignored.');
  }
  authenticate = benchmarkAuthentication(
    requireSecret(password: password, passwordName: passwordName),
  );
  if (pod.runMode == 'production' &&
      pod.config.database?.dialect != DatabaseDialect.postgres) {
    throw StateError('Production benchmarks require PostgreSQL.');
  }
  await pod.start();
  serverDiagnostics.start();
}
