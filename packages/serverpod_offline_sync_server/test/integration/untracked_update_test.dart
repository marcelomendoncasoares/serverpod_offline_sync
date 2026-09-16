import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
// Serverpod currently exposes its SQL generator only through this library.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart' show DatabaseDefinition;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/offline_sync_updates_${const Uuid().v4()}',
  );
  setUpAll(() async {
    await _preparePostgresMigrations(serverDirectory);
  });

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL untracked updates with the database interceptor',
    (sessionBuilder, _) {
      late Session session;

      setUp(() {
        sessionBuilder.build().serverpod.initializeOfflineSync(syncTables: []);
        session = sessionBuilder.build();
      });

      group('Given an ordinary row in the test harness transaction,', () {
        late ServerHealthMetric metric;

        setUp(() async {
          metric = await ServerHealthMetric.db.insertRow(
            session,
            ServerHealthMetric(
              name: 'original',
              serverId: 'test server',
              timestamp: DateTime.utc(2026),
              isHealthy: true,
              value: 1,
              granularity: 1,
            ),
          );
        });

        group('when updateRow changes its name,', () {
          setUp(() async {
            await ServerHealthMetric.db.updateRow(
              session,
              metric.copyWith(name: 'updated'),
            );
          });

          test('then the change is visible in the test transaction.', () async {
            final stored = await ServerHealthMetric.db.findById(session, metric.id!);
            expect(stored?.name, 'updated');
          });
        });
      });
    },
    databaseInterceptor: offlineSyncDatabaseInterceptor,
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      apiServer: ServerConfig(
        port: 0,
        publicHost: 'localhost',
        publicPort: 0,
        publicScheme: 'http',
      ),
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${Directory.systemTemp.path}/offline_sync_updates_postgres_$pid',
        name: 'serverpod_test',
        maxConnectionCount: 5,
      ),
    ),
  );
}

// The module's committed SQL targets SQLite. Render the current generated
// definition with the same PostgreSQL generator used by serverpod create-migration.
Future<void> _preparePostgresMigrations(Directory serverDirectory) async {
  final versions = await File('migrations/migration_registry.txt').readAsLines();
  final version = versions.lastWhere((line) => line.trim().isNotEmpty);
  final source = Directory('migrations/$version');
  final target = Directory('${serverDirectory.path}/migrations/$version');
  await target.create(recursive: true);
  await for (final file in source.list()) {
    if (file is File) {
      await file.copy('${target.path}/${file.uri.pathSegments.last}');
    }
  }
  final definition = DatabaseDefinition.fromJson(
    jsonDecode(await File('${target.path}/definition.json').readAsString())
        as Map<String, dynamic>,
  );
  final sql = definition.toPgSql(installedModules: definition.installedModules);
  await File('${target.path}/definition.sql').writeAsString(sql);
  await File('${target.path}/migration.sql').writeAsString(sql);
  await File(
    '${serverDirectory.path}/migrations/migration_registry.txt',
  ).writeAsString('$version\n');
}
