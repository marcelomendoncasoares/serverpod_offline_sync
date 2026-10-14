import 'dart:async';
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
  if (FileSystemEntity.typeSync(output.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError('Refusing to overwrite ${output.path}');
  }

  final processes = Subprocesses();
  final signals = [
    ProcessSignal.sigint,
    if (!Platform.isWindows) ProcessSignal.sigterm,
  ].map((signal) => signal.watch().listen(processes.interrupt)).toList();
  await output.create(recursive: true);
  try {
    await prepare(root, output, processes);
  } catch (_) {
    // Remove the incomplete export so the same command can be retried. It is
    // built in place because package configs record absolute paths.
    await removeIncomplete(output);
    rethrow;
  } finally {
    for (final signal in signals) {
      await signal.cancel();
    }
  }
}

Future<void> prepare(String root, Directory output, Subprocesses processes) async {
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
  // password flow, but only those the project lacks. A fresh name per export
  // keeps a relaunch to an existing project from retaining an older secret.
  // The file is excluded from the deployment archive.
  final random = Random.secure();
  List<int> randomBytes(int length) =>
      List.generate(length, (_) => random.nextInt(256));
  final secret = base64Url.encode(randomBytes(32));
  final passwordName =
      'benchmarkSecret_'
      '${randomBytes(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  await writeYaml(File(p.join(server.path, 'config/passwords.yaml')), {
    'production': {passwordName: secret},
  });
  await File(p.join(output.path, '.gitignore')).writeAsString(
    '**/.dart_tool/\n**/.scloud/\n**/config/passwords.yaml\n',
  );
  await File(p.join(output.path, '.scloudignore')).writeAsString(
    '**/config/passwords.yaml\n!.scloud/**\n',
  );
  final lock = File(p.join(root, 'pubspec.lock'));
  if (lock.existsSync()) await lock.copy(p.join(output.path, 'pubspec.lock'));

  await processes.dart(['pub', 'get'], output.path);
  await requireServerpodCli(processes, output.path, server.path);
  await processes.dart([
    'run',
    'serverpod_cli',
    '--no-analytics',
    'generate',
  ], p.join(output.path, 'packages/serverpod_offline_sync_server'));
  await processes.dart([
    'run',
    'serverpod_cli',
    '--no-analytics',
    'generate',
  ], server.path);

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
    'passwordName': passwordName,
    'preparedAt': DateTime.now().toUtc().toIso8601String(),
    'sourceRevision': checkout['revision'],
    'sourceDirty': checkout['dirty'],
  };
  await File(p.join(output.path, 'PREPARED.json')).writeAsString(jsonEncode(prepared));
  // The server reports this from its working directory as non-secret
  // provenance, because Cloud builds the executable itself. It also names the
  // password the server reads.
  await File(
    p.join(server.path, 'config', 'benchmark_build.json'),
  ).writeAsString(jsonEncode(prepared));
  processes.checkInterrupt();
  stdout
    ..writeln('Prepared ${server.path} for a fresh PostgreSQL database.')
    ..writeln('Dependencies and generated code are ready.')
    ..writeln('Next: cd ${server.path} && scloud launch')
    ..writeln(
      'The launch wizard will import $passwordName from config/passwords.yaml; '
      "its value is the load generator's BENCHMARK_SECRET.",
    );
}

/// `scloud launch` regenerates code with the `serverpod` command on PATH, and
/// Serverpod only warns when that CLI differs from the project's version.
/// Requiring the resolved version keeps the hook's output equal to this one.
Future<void> requireServerpodCli(
  Subprocesses processes,
  String workspace,
  String server,
) async {
  final lock = loadYaml(await File(p.join(workspace, 'pubspec.lock')).readAsString());
  final required =
      (((lock as Map)['packages'] as Map)['serverpod_cli'] as Map)['version'] as String;
  String? found;
  try {
    final result = await processes.run(
      'serverpod',
      ['--no-analytics', 'version'],
      server,
      capture: true,
      shell: Platform.isWindows,
    );
    if (result.exitCode == 0) {
      found = RegExp(r'Serverpod version: (\S+)').firstMatch(result.output)?.group(1);
    }
  } on ProcessException {
    // Not installed.
  }
  if (found != required) {
    throw StateError(
      'scloud launch runs `serverpod generate` with the Serverpod CLI on PATH, '
      'which is ${found ?? 'not available'}. This export requires $required: '
      'dart pub global activate serverpod_cli $required',
    );
  }
  stdout.writeln('Serverpod CLI $found matches the export.');
}

/// Runs preparation subprocesses one at a time. An interrupt is forwarded to
/// the running process and fails preparation before its next step.
class Subprocesses {
  Process? _running;
  ProcessSignal? _interrupt;

  void interrupt(ProcessSignal signal) {
    _interrupt = signal;
    _running?.kill(signal);
  }

  void checkInterrupt() {
    if (_interrupt case final signal?) {
      throw StateError('Preparation interrupted by $signal.');
    }
  }

  /// Puts the preparing SDK first on PATH, so tools started by Serverpod use
  /// the same SDK. Output is inherited unless [capture] is set.
  Future<({int exitCode, String output})> run(
    String executable,
    List<String> arguments,
    String directory, {
    bool capture = false,
    bool shell = false,
  }) async {
    checkInterrupt();
    final process = _running = await Process.start(
      executable,
      arguments,
      workingDirectory: directory,
      environment: {
        'PATH':
            '${p.dirname(Platform.resolvedExecutable)}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}',
      },
      runInShell: shell,
      mode: capture ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
    );
    // An interrupt during the start had no process to stop yet.
    if (_interrupt case final signal?) process.kill(signal);
    final output = capture
        ? process.stdout.transform(utf8.decoder).join()
        : Future.value('');
    if (capture) unawaited(process.stderr.drain<void>());
    final exitCode = await process.exitCode;
    _running = null;
    checkInterrupt();
    return (exitCode: exitCode, output: await output);
  }

  Future<void> dart(List<String> arguments, String directory) async {
    final result = await run(Platform.resolvedExecutable, arguments, directory);
    if (result.exitCode != 0) {
      throw ProcessException(
        Platform.resolvedExecutable,
        arguments,
        'Deployment preparation failed in $directory.',
        result.exitCode,
      );
    }
  }
}

Future<void> removeIncomplete(Directory output) async {
  try {
    if (output.existsSync()) await output.delete(recursive: true);
  } on FileSystemException catch (error) {
    stderr.writeln(
      'Could not remove the incomplete ${output.path}; '
      'delete it before retrying: ${error.message}',
    );
  }
}

/// JSON is also YAML, and preserves arbitrary package/config values faithfully.
Future<void> writeYaml(File file, Map<String, dynamic> value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(value)}\n');
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
