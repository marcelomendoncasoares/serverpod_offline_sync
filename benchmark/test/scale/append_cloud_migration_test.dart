import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../tool/append_cloud_migration.dart';

void main() {
  late Directory scratch;
  late Directory repositoryMigrations;

  setUpAll(() async {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:serverpod_offline_sync_benchmark/scale/common.dart'),
    );
    final root = p.normalize(p.join(File.fromUri(library!).parent.path, '../../..'));
    repositoryMigrations = Directory(
      p.join(root, 'test/serverpod_offline_sync_test_server/migrations'),
    );
    scratch = await Directory.systemTemp.createTemp('append-cloud-migration-');
  });

  tearDownAll(() => scratch.delete(recursive: true));

  group('Given a prepared predecessor of the populated checkpoint migration,', () {
    const version = '20261029055700456';
    late String previous;
    late Directory source;
    late Directory target;
    late String expectedSql;
    late String previousDefinition;
    late File protectedConfig;

    setUpAll(() async {
      final versions = await File(
        p.join(repositoryMigrations.path, 'migration_registry.txt'),
      ).readAsLines();
      previous = versions[versions.indexOf(version) - 1];
      source = await Directory(p.join(scratch.path, 'source')).create();
      target = await Directory(p.join(scratch.path, 'prepared/migrations')).create(
        recursive: true,
      );
      for (final selected in [previous, version]) {
        final destination = await Directory(p.join(source.path, selected)).create();
        await for (final file in Directory(
          p.join(repositoryMigrations.path, selected),
        ).list()) {
          if (file is File) {
            await file.copy(p.join(destination.path, p.basename(file.path)));
          }
        }
      }
      await File(p.join(source.path, 'migration_registry.txt')).writeAsString(
        '$previous\n$version\n',
      );
      previousDefinition = await File(
        p.join(source.path, previous, 'definition.json'),
      ).readAsString();
      await Directory(p.join(target.path, previous)).create();
      await File(p.join(target.path, previous, 'definition.json')).writeAsString(
        previousDefinition,
      );
      await File(p.join(target.path, 'migration_registry.txt')).writeAsString(
        '$previous\n',
      );
      expectedSql = await File(
        p.join(source.path, version, 'migration.postgres.sql'),
      ).readAsString();
      protectedConfig = File(p.join(target.parent.path, 'configuration-marker'));
      await protectedConfig.writeAsString('preserve this configuration');
    });

    group('when its PostgreSQL migration is appended,', () {
      late Map<String, Object> result;
      late String installedSql;
      late List<String> installedVersions;
      late String preservedDefinition;
      late String preservedConfig;

      setUpAll(() async {
        result = await appendCloudMigration(source, target);
        installedSql = await File(
          p.join(target.path, version, 'migration.sql'),
        ).readAsString();
        installedVersions = await File(
          p.join(target.path, 'migration_registry.txt'),
        ).readAsLines();
        preservedDefinition = await File(
          p.join(target.path, previous, 'definition.json'),
        ).readAsString();
        preservedConfig = await protectedConfig.readAsString();
      });

      test(
        'then the executed SQL retains the reviewed backfill and revision seed.',
        () {
          expect(result['sqlSource'], 'migration.postgres.sql');
          expect(installedSql, expectedSql);
          expect(installedSql, contains('UPDATE "crdt_data_fields"'));
          expect(installedSql, contains('"syncRevision" = 1'));
        },
      );

      test('then only the new version is appended to the migration registry.', () {
        expect(installedVersions, [previous, version]);
      });

      test('then the previous schema and deployment configuration remain intact.', () {
        expect(preservedDefinition, previousDefinition);
        expect(preservedConfig, 'preserve this configuration');
      });
    });
  });
}
