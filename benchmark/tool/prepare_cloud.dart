import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
// Serverpod's schema renderer is currently exposed through this CLI library.
// This build-time adapter never participates in benchmark traffic.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart';

/// Produces a self-contained source workspace with a conventional bin/main.dart
/// and a PostgreSQL baseline, suitable for a fresh dedicated Cloud database.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('output', defaultsTo: '.scale-benchmark/cloud')
    ..addFlag('help', abbr: 'h', negatable: false);
  final options = parser.parse(args);
  if (options['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }
  if (options.rest.isNotEmpty) throw ArgumentError('Unexpected arguments.');
  final root = p.normalize(p.join(File.fromUri(Platform.script).parent.path, '../..'));
  final output = Directory(p.absolute(options['output'] as String));
  if (output.existsSync()) throw StateError('Refusing to overwrite ${output.path}');
  await output.create(recursive: true);
  const packages = [
    'benchmark',
    'packages/serverpod_offline_sync',
    'packages/serverpod_offline_sync_client',
    'packages/serverpod_offline_sync_server',
    'test/serverpod_offline_sync_test_client',
    'test/serverpod_offline_sync_test_server',
    'test/serverpod_offline_sync_test_shared',
  ];
  await File(p.join(output.path, 'pubspec.yaml')).writeAsString('''
name: offline_sync_benchmark_deployment
publish_to: none
environment:
  sdk: '^3.12.2'
workspace:
${packages.map((path) => '  - $path').join('\n')}
''');
  for (final package in packages) {
    final destination = Directory(p.join(output.path, package));
    await destination.create(recursive: true);
    await File(
      p.join(root, package, 'pubspec.yaml'),
    ).copy(p.join(destination.path, 'pubspec.yaml'));
    await copyDirectory(
      Directory(p.join(root, package, 'lib')),
      Directory(p.join(destination.path, 'lib')),
    );
  }
  final server = Directory(p.join(output.path, 'benchmark'));
  await Directory(p.join(server.path, 'bin')).create();
  await File(
    p.join(root, 'benchmark/bin/scale_server.dart'),
  ).copy(p.join(server.path, 'bin/main.dart'));
  await copyDirectory(
    Directory(p.join(root, 'benchmark/scale_server/config')),
    Directory(p.join(server.path, 'config')),
  );
  // Preserve resolution versions when a workspace lockfile is available.
  final lock = File(p.join(root, 'pubspec.lock'));
  if (lock.existsSync()) await lock.copy(p.join(output.path, 'pubspec.lock'));

  final sourceMigrations = p.join(
    root,
    'test/serverpod_offline_sync_test_server/migrations',
  );
  final versions = await File(
    p.join(sourceMigrations, 'migration_registry.txt'),
  ).readAsLines();
  final version = versions.lastWhere((v) => v.trim().isNotEmpty).trim();
  final migration = Directory(p.join(server.path, 'migrations', version));
  await copyDirectory(Directory(p.join(sourceMigrations, version)), migration);
  final source = p.join(sourceMigrations, version, 'definition.json');
  final definition = DatabaseDefinition.fromJson(
    jsonDecode(await File(source).readAsString()) as Map<String, dynamic>,
  );
  final sql = definition.toPgSql(installedModules: definition.installedModules);
  await File(source).copy(p.join(migration.path, 'definition.json'));
  await File(p.join(migration.path, 'definition.sql')).writeAsString(sql);
  await File(p.join(migration.path, 'migration.sql')).writeAsString(sql);
  await File(
    p.join(server.path, 'migrations/migration_registry.txt'),
  ).writeAsString('$version\n');
  await File(p.join(output.path, 'PREPARED.json')).writeAsString(
    jsonEncode({
      'schemaVersion': version,
      'backend': 'postgres',
      'freshDatabaseRequired': true,
      'serverDirectory': 'benchmark',
      'sourceRevision': (await Process.run('git', [
        'rev-parse',
        'HEAD',
      ], workingDirectory: root)).stdout.toString().trim(),
    }),
  );
  stdout
    ..writeln('Prepared ${server.path} for a fresh PostgreSQL database.')
    ..writeln(
      'Run dart pub get in ${output.path}; Cloud server directory: ${server.path}',
    );
}

Future<void> copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true, followLinks: false)) {
    final target = p.join(destination.path, p.relative(entity.path, from: source.path));
    if (entity is Directory) {
      await Directory(target).create(recursive: true);
    } else if (entity is File) {
      await Directory(p.dirname(target)).create(recursive: true);
      await entity.copy(target);
    }
  }
}
