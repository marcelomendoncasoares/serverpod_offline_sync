import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;
import 'package:serverpod_offline_sync_test_server/src/generated/sync_tables.dart';

Future<void> main(List<String> args) async {
  final secret = requireSecret();
  final pod = Serverpod(
    args,
    model.Protocol(),
    BenchmarkEndpoints(),
    authenticationHandler: benchmarkAuthentication(secret),
    databaseInterceptor: offlineSyncDatabaseInterceptor,
  )..initializeOfflineSync(syncTables: syncTables);
  await pod.start();

  Future<void> stop() async {
    await pod.shutdown();
    exit(0);
  }

  ProcessSignal.sigterm.watch().listen((_) => stop());
  ProcessSignal.sigint.watch().listen((_) => stop());
}
