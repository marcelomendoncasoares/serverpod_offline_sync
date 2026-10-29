import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
// Serverpod exposes its dialect renderer through the CLI library.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// Appends generated schema changes to an existing prepared PostgreSQL project.
/// The existing baseline must match the source migration immediately preceding
/// the new version. Configuration and credentials are never read or changed.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Usage: append_cloud_migration.dart <prepared-workspace>');
  }
  final root = p.normalize(p.join(File.fromUri(Platform.script).parent.path, '../..'));
  final source = Directory(
    p.join(root, 'test/serverpod_offline_sync_test_server/migrations'),
  );
  final target = Directory(p.join(p.absolute(args.single), 'benchmark/migrations'));
  stdout.writeln(jsonEncode(await appendCloudMigration(source, target)));
}

/// Appends the next migration, retaining explicit PostgreSQL data backfills.
/// Structural JSON is rendered only when no dialect-specific SQL is supplied.
Future<Map<String, Object>> appendCloudMigration(
  Directory source,
  Directory target,
) async {
  final sourceVersions = await _versions(source);
  final targetVersions = await _versions(target);
  final version = sourceVersions.last;
  if (targetVersions.last != sourceVersions[sourceVersions.length - 2]) {
    throw StateError('Prepared schema is not the immediate predecessor of $version.');
  }
  final previous = targetVersions.last;
  final expected = await _definition(source, previous);
  final existing = await _definition(target, previous);
  if (jsonEncode(existing.toJson()) != jsonEncode(expected.toJson())) {
    throw StateError('Prepared baseline differs from the source schema.');
  }

  final definition = await _definition(source, version);
  final migration = DatabaseMigration.fromJson(
    jsonDecode(
          await File(p.join(source.path, version, 'migration.json')).readAsString(),
        )
        as Map<String, dynamic>,
  );
  final removedModules = existing.installedModules
      .where(
        (old) =>
            !definition.installedModules.any((current) => current.module == old.module),
      )
      .toList();
  final postgresSql = File(p.join(source.path, version, 'migration.postgres.sql'));
  final hasExplicitSql = postgresSql.existsSync();
  final sql = hasExplicitSql
      ? await postgresSql.readAsString()
      : migration.toPgSql(
          databaseDefinition: definition,
          installedModules: definition.installedModules,
          removedModules: removedModules,
        );
  final destination = Directory(p.join(target.path, version));
  if (destination.existsSync()) {
    throw StateError('Migration destination already exists.');
  }
  await destination.create();
  await for (final file in Directory(p.join(source.path, version)).list()) {
    if (file is File) await file.copy(p.join(destination.path, p.basename(file.path)));
  }
  await File(p.join(destination.path, 'definition.sql')).writeAsString(
    definition.toPgSql(installedModules: definition.installedModules),
  );
  await File(p.join(destination.path, 'migration.sql')).writeAsString(sql);
  await File(p.join(target.path, 'migration_registry.txt')).writeAsString(
    '${[...targetVersions, version].join('\n')}\n',
  );
  return {
    'previous': previous,
    'version': version,
    'migration': p.join(destination.path, 'migration.sql'),
    'sqlSource': hasExplicitSql ? 'migration.postgres.sql' : 'migration.json',
    'actions': migration.actions.length,
  };
}

Future<List<String>> _versions(Directory directory) async => (await File(
  p.join(directory.path, 'migration_registry.txt'),
).readAsLines()).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

Future<DatabaseDefinition> _definition(Directory directory, String version) async =>
    DatabaseDefinition.fromJson(
      jsonDecode(
            await File(
              p.join(directory.path, version, 'definition.json'),
            ).readAsString(),
          )
          as Map<String, dynamic>,
    );
