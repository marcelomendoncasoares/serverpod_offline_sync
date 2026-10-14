import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
// Serverpod's schema renderer is currently exposed through this CLI library.
// This build-time adapter never participates in benchmark traffic.
// ignore: implementation_imports
import 'package:serverpod_cli/src/database/dialects/postgres.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:yaml/yaml.dart';

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

  if (!Platform.isWindows) {
    final permissions = await Process.run('chmod', ['700', output.path]);
    if (permissions.exitCode != 0) {
      throw StateError('Could not protect the prepared workspace permissions.');
    }
  }

  // Keep package identities so model serialization and the existing load
  // generator remain compatible. The deployed server lives at benchmark/.
  const packages = {
    'test/serverpod_offline_sync_test_server': 'benchmark',
    'packages/serverpod_offline_sync': 'packages/serverpod_offline_sync',
    'packages/serverpod_offline_sync_client': 'packages/serverpod_offline_sync_client',
    'packages/serverpod_offline_sync_server': 'packages/serverpod_offline_sync_server',
    'test/serverpod_offline_sync_test_client':
        'test/serverpod_offline_sync_test_client',
    'test/serverpod_offline_sync_test_shared':
        'test/serverpod_offline_sync_test_shared',
  };
  await writeYaml(File(p.join(output.path, 'pubspec.yaml')), {
    'name': 'offline_sync_benchmark_deployment',
    'publish_to': 'none',
    'environment': {'sdk': '^3.12.2'},
    'workspace': packages.values.toList(),
  });
  final benchmarkSpec =
      loadYaml(
            await File(p.join(root, 'benchmark/pubspec.yaml')).readAsString(),
          )
          as Map;
  for (final entry in packages.entries) {
    final destination = Directory(p.join(output.path, entry.value));
    await destination.create(recursive: true);
    final spec =
        jsonDecode(
              jsonEncode(
                loadYaml(
                  await File(p.join(root, entry.key, 'pubspec.yaml')).readAsString(),
                ),
              ),
            )
            as Map<String, dynamic>;
    for (final section in ['dependencies', 'dev_dependencies']) {
      final dependencies = spec[section] as Map<String, dynamic>?;
      if (dependencies == null) continue;
      for (final dependency in dependencies.values) {
        if (dependency is! Map || dependency['path'] is! String) continue;
        final sourcePath = p.normalize(p.join(entry.key, dependency['path'] as String));
        final targetPath = packages[sourcePath];
        if (targetPath == null) {
          throw StateError('Dependency outside the deployment: $sourcePath');
        }
        dependency['path'] = p.relative(targetPath, from: entry.value);
      }
    }
    spec.remove('serverpod'); // No demo Flutter app in the deployment.
    if (entry.value == 'benchmark') {
      final dependencies = spec['dependencies'] as Map<String, dynamic>;
      final devDependencies = spec['dev_dependencies'] as Map<String, dynamic>;
      for (final name in ['crypto', 'path']) {
        dependencies[name] = (benchmarkSpec['dependencies'] as Map)[name];
        devDependencies.remove(name);
      }
      dependencies['serverpod_offline_sync_test_client'] = devDependencies.remove(
        'serverpod_offline_sync_test_client',
      );
      for (final path in ['src/models', 'src/generated']) {
        await copyDirectory(
          Directory(p.join(root, entry.key, 'lib', path)),
          Directory(p.join(destination.path, 'lib', path)),
        );
      }
      // Regenerate dispatch without the test project's demo endpoints.
      await File(p.join(destination.path, 'lib/src/generated/endpoints.dart')).delete();
    } else {
      await copyDirectory(
        Directory(p.join(root, entry.key, 'lib')),
        Directory(p.join(destination.path, 'lib')),
      );
    }
    await writeYaml(File(p.join(destination.path, 'pubspec.yaml')), spec);
    final generatorFile = File(p.join(root, entry.key, 'config/generator.yaml'));
    if (generatorFile.existsSync()) {
      final generator =
          jsonDecode(
                jsonEncode(
                  loadYaml(
                    await generatorFile.readAsString(),
                  ),
                ),
              )
              as Map<String, dynamic>;
      String relocated(String path) => p.relative(
        packages[p.normalize(p.join(entry.key, path))]!,
        from: entry.value,
      );
      generator['client_package_path'] = relocated(
        generator['client_package_path'] as String,
      );
      generator['shared_packages'] = (generator['shared_packages'] as List)
          .cast<String>()
          .map(relocated)
          .toList();
      // Test harness generation belongs to the original test workspace.
      generator.remove('server_test_tools_path');
      await writeYaml(
        File(p.join(destination.path, 'config/generator.yaml')),
        generator,
      );
    }
  }
  final server = Directory(p.join(output.path, 'benchmark'));
  for (final name in ['common.dart', 'server.dart', 'verification.dart']) {
    final target = File(p.join(server.path, 'lib/scale', name));
    await target.parent.create(recursive: true);
    await File(p.join(root, 'benchmark/lib/scale', name)).copy(target.path);
  }
  final entrypoint = File(p.join(server.path, 'bin/main.dart'));
  await entrypoint.parent.create(recursive: true);
  await entrypoint.writeAsString(
    (await File(
      p.join(root, 'benchmark/bin/scale_server.dart'),
    ).readAsString()).replaceAll(
      'package:serverpod_offline_sync_benchmark/',
      'package:serverpod_offline_sync_test_server/',
    ),
  );
  // Serverpod requires one dialect across all run modes. This export is a
  // PostgreSQL project; the local benchmark's SQLite config stays in the repo.
  final production = File(
    p.join(root, 'benchmark/scale_server/config/production.yaml'),
  );
  await production.copy(p.join(server.path, 'config/production.yaml'));
  await production.copy(p.join(server.path, 'config/development.yaml'));
  // The launch wizard imports custom production passwords through its normal
  // password flow. The file is excluded from the deployment archive.
  final random = Random.secure();
  final secret = base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  await writeYaml(File(p.join(server.path, 'config/passwords.yaml')), {
    'production': {'benchmarkSecret': secret},
  });
  await File(p.join(output.path, '.gitignore')).writeAsString(
    '**/.dart_tool/\n**/.scloud/\n**/config/passwords.yaml\n',
  );
  await File(p.join(output.path, '.scloudignore')).writeAsString(
    '**/config/passwords.yaml\n!.scloud/**\n',
  );
  final lock = File(p.join(root, 'pubspec.lock'));
  if (lock.existsSync()) await lock.copy(p.join(output.path, 'pubspec.lock'));

  await runDart(['pub', 'get'], output.path);
  await runDart([
    'run',
    'serverpod_cli',
    '--no-analytics',
    'generate',
  ], p.join(output.path, 'packages/serverpod_offline_sync_server'));
  await runDart(['run', 'serverpod_cli', '--no-analytics', 'generate'], server.path);

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
  final checkout = await gitMetadata(root);
  final prepared = {
    'schemaVersion': version,
    'backend': 'postgres',
    'freshDatabaseRequired': true,
    'serverDirectory': 'benchmark',
    'preparedAt': DateTime.now().toUtc().toIso8601String(),
    'sourceRevision': checkout['revision'],
    'sourceDirty': checkout['dirty'],
  };
  await File(p.join(output.path, 'PREPARED.json')).writeAsString(jsonEncode(prepared));
  // The server reports this from its working directory as non-secret
  // provenance, because Cloud builds the executable itself.
  await File(
    p.join(server.path, 'config', 'benchmark_build.json'),
  ).writeAsString(jsonEncode(prepared));
  stdout
    ..writeln('Prepared ${server.path} for a fresh PostgreSQL database.')
    ..writeln('Dependencies and generated code are ready.')
    ..writeln('Next: cd ${server.path} && scloud launch')
    ..writeln(
      'The launch wizard will import benchmarkSecret from config/passwords.yaml.',
    );
}

/// JSON is also YAML, and preserves arbitrary package/config values faithfully.
Future<void> writeYaml(File file, Map<String, dynamic> value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(value)}\n');
}

Future<void> runDart(List<String> arguments, String directory) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: directory,
    environment: {
      // Use the same SDK as prepare for subprocesses started by Serverpod.
      'PATH':
          '${p.dirname(Platform.resolvedExecutable)}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}',
    },
    mode: ProcessStartMode.inheritStdio,
  );
  final result = await process.exitCode;
  if (result != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      arguments,
      'Deployment preparation failed in $directory.',
      result,
    );
  }
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
