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
  late TestSessionBuilder testSessionBuilder;
  late Session session;

  setUpAll(() async {
    await _preparePostgresMigrations(serverDirectory);
    // Configure sync before Serverpod starts and opens the harness transaction.
    testSessionBuilder.build().serverpod.initializeOfflineSync(syncTables: []);
  });

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  setUp(() {
    session = testSessionBuilder.build();
  });

  withServerpod(
    'PostgreSQL untracked updates with the database interceptor',
    (sessionBuilder, _) {
      testSessionBuilder = sessionBuilder;

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
          late ServerHealthMetric updated;

          setUp(() async {
            updated = await ServerHealthMetric.db.updateRow(
              session,
              metric.copyWith(name: 'updated'),
            );
          });

          test('then the updated row is returned.', () {
            expect(updated.id, metric.id);
            expect(updated.name, 'updated');
          });

          test('then the change is visible in the test transaction.', () async {
            final stored = await ServerHealthMetric.db.findById(session, metric.id!);
            expect(stored?.name, 'updated');
          });
        });

        group('when updateRow selects only the name column,', () {
          late ServerHealthMetric updated;

          setUp(() async {
            updated = await ServerHealthMetric.db.updateRow(
              session,
              metric.copyWith(name: 'updated', value: 2),
              columns: (t) => [t.name],
            );
          });

          test('then the returned row preserves the unselected value.', () {
            expect(updated.name, 'updated');
            expect(updated.value, 1);
          });

          test('then only the selected column is changed in the database.', () async {
            final stored = await ServerHealthMetric.db.findById(session, metric.id!);
            expect(stored?.name, 'updated');
            expect(stored?.value, 1);
          });
        });

        group('when updateRow runs in an explicit transaction that rolls back,', () {
          setUp(() async {
            await expectLater(
              session.db.transaction((tx) async {
                await ServerHealthMetric.db.updateRow(
                  session,
                  metric.copyWith(name: 'updated'),
                  transaction: tx,
                );
                throw StateError('rollback');
              }),
              throwsStateError,
            );
          });

          test('then the original row is preserved.', () async {
            final stored = await ServerHealthMetric.db.findById(session, metric.id!);
            expect(stored?.name, 'original');
          });
        });

        group('when updateById changes its name,', () {
          late ServerHealthMetric? updated;

          setUp(() async {
            updated = await ServerHealthMetric.db.updateById(
              session,
              metric.id!,
              columnValues: (t) => [t.name('updated')],
            );
          });

          test('then the updated row is returned.', () {
            expect(updated?.id, metric.id);
            expect(updated?.name, 'updated');
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
