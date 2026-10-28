// The Serverpod CLIs on PATH are shell scripts.
@TestOn('posix')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late String root;
  late Directory scratch;
  late Map<String, String> environment;

  setUpAll(() async {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:serverpod_offline_sync_benchmark/scale/common.dart'),
    );
    root = p.normalize(p.join(File.fromUri(library!).parent.path, '../../..'));
    scratch = await Directory.systemTemp.createTemp('benchmark-cloud-test-');
    environment = {
      'CI': 'true',
      'PATH':
          '${p.dirname(Platform.resolvedExecutable)}:${Platform.environment['PATH']}',
    };
  });

  tearDownAll(() async {
    await scratch.delete(recursive: true);
  });

  group('Given the Serverpod CLI at the version the export resolves,', () {
    late Map<String, String> cliEnvironment;

    setUpAll(() async {
      cliEnvironment = await serverpodOnPath(
        scratch,
        'resolved-cli',
        'exec "${Platform.resolvedExecutable}" run serverpod_cli "\$@"',
      );
    });

    group(
      'when preparation and the standard generation hook run,',
      () {
        late String output;
        late ProcessResult prepared;
        late ProcessResult generated;
        late ProcessResult analyzed;
        late bool dependenciesResolved;
        late String endpoints;
        late String protocol;
        late String endpointList;
        late Map<dynamic, dynamic> passwords;
        late Map<String, dynamic> metadata;
        late String metadataText;
        late String resolvedPasswordName;
        late Map<String, bool> uploadIgnored;
        late Map<dynamic, dynamic> sourceOverrides;
        late Map<dynamic, dynamic> exportedOverrides;
        late Map<dynamic, dynamic> lockedPackages;
        late String commitHintSource;
        late String exportedCommitHints;
        late String sourceDriver;
        late String exportedDriver;
        late List<dynamic> exportedWorkspace;

        setUpAll(() async {
          output = p.join(scratch.path, 'prepared');
          prepared = await runDart(
            ['run', 'benchmark/tool/prepare_cloud.dart', '--output', output],
            root,
            cliEnvironment,
          );
          if (prepared.exitCode != 0) {
            fail('Preparation failed:\n${prepared.stdout}\n${prepared.stderr}');
          }

          dependenciesResolved = File(
            p.join(output, '.dart_tool/package_config.json'),
          ).existsSync();
          // scloud launch runs its hook command through a shell on PATH.
          generated = await Process.run(
            'sh',
            ['-c', 'serverpod --no-analytics generate'],
            workingDirectory: p.join(output, 'benchmark'),
            environment: cliEnvironment,
          );
          analyzed = await runDart(['analyze'], output, environment);
          endpoints = await File(
            p.join(output, 'benchmark/lib/src/generated/endpoints.dart'),
          ).readAsString();
          protocol = await File(
            p.join(output, 'benchmark/lib/src/generated/protocol.dart'),
          ).readAsString();
          endpointList = await File(
            p.join(output, 'benchmark/lib/src/generated/protocol.yaml'),
          ).readAsString();
          passwords =
              loadYaml(
                    await File(
                      p.join(output, 'benchmark/config/passwords.yaml'),
                    ).readAsString(),
                  )
                  as Map;
          metadataText = await File(
            p.join(output, 'PREPARED.json'),
          ).readAsString();
          metadata = jsonDecode(metadataText) as Map<String, dynamic>;
          resolvedPasswordName = benchmarkPasswordName(
            p.join(output, 'benchmark'),
          );
          sourceOverrides =
              (loadYaml(await File(p.join(root, 'pubspec.yaml')).readAsString())
                      as Map)['dependency_overrides']
                  as Map;
          exportedOverrides =
              (loadYaml(
                        await File(
                          p.join(output, 'pubspec.yaml'),
                        ).readAsString(),
                      )
                      as Map)['dependency_overrides']
                  as Map;
          lockedPackages =
              (loadYaml(
                        await File(
                          p.join(output, 'pubspec.lock'),
                        ).readAsString(),
                      )
                      as Map)['packages']
                  as Map;
          exportedWorkspace =
              (loadYaml(await File(p.join(output, 'pubspec.yaml')).readAsString())
                      as Map)['workspace']
                  as List;
          sourceDriver = await File(
            p.join(root, 'vendor/postgres/lib/src/v3/connection.dart'),
          ).readAsString();
          final packageConfig = File(
            p.join(output, '.dart_tool/package_config.json'),
          );
          final postgres =
              (jsonDecode(await packageConfig.readAsString())['packages'] as List)
                  .cast<Map<String, dynamic>>()
                  .singleWhere((package) => package['name'] == 'postgres');
          exportedDriver = await File.fromUri(
            packageConfig.uri
                .resolve('${postgres['rootUri']}/')
                .resolve('lib/src/v3/connection.dart'),
          ).readAsString();
          commitHintSource = await File(
            p.join(root, 'benchmark/lib/scale/commit_hints.dart'),
          ).readAsString();
          exportedCommitHints = await File(
            p.join(output, 'benchmark/lib/scale/commit_hints.dart'),
          ).readAsString();
          uploadIgnored = await cloudUploadIgnores(
            p.join(scratch.path, 'upload-rules'),
            ignoreFiles: [
              File(p.join(output, '.gitignore')),
              File(p.join(output, '.scloudignore')),
            ],
            paths: [
              'benchmark/config/passwords.yaml',
              'benchmark/config/production.yaml',
              'benchmark/config/benchmark_build.json',
              'benchmark/bin/main.dart',
              'benchmark/lib/scale/commit_hints.dart',
              'vendor/postgres/pubspec.yaml',
              'vendor/postgres/lib/src/v3/connection.dart',
              'vendor/postgres/LICENSE',
              'pubspec.yaml',
              'pubspec.lock',
            ],
          );
        });

        test(
          'then dependencies and regeneratable application models are ready.',
          () {
            expect(dependenciesResolved, isTrue);
            expect(
              generated.exitCode,
              0,
              reason: '${generated.stdout}\n${generated.stderr}',
            );
            expect(
              analyzed.exitCode,
              0,
              reason: '${analyzed.stdout}\n${analyzed.stderr}',
            );
            expect(protocol, contains('City'));
            expect(endpoints, contains('BenchmarkEndpoint'));
          },
        );

        test(
          'then the normal manifest resolves the pinned SDK Git packages.',
          () {
            expect(exportedOverrides, sourceOverrides);
            expect(
              exportedOverrides.keys,
              unorderedEquals([
                'serverpod',
                'serverpod_client',
                'serverpod_database',
                'serverpod_shared',
                'serverpod_serialization',
                'serverpod_embedded_postgres',
              ]),
            );
            for (final entry in exportedOverrides.entries) {
              final git = (entry.value as Map)['git'] as Map;
              final locked = lockedPackages[entry.key] as Map;
              final description = locked['description'] as Map;

              expect(git['ref'], matches(RegExp(r'^[0-9a-f]{40}$')));
              expect(locked['source'], 'git');
              expect(description['url'], git['url']);
              expect(description['path'], git['path']);
              expect(description['resolved-ref'], git['ref']);
            }
          },
        );

        test(
          'then the exported workspace resolves the matched driver and native TLS package.',
          () {
            expect(exportedWorkspace, contains('vendor/postgres'));
            expect(exportedDriver, sourceDriver);
            expect(lockedPackages.containsKey('postgres'), isFalse);
            final tls = lockedPackages['postgres_tls'] as Map;
            expect(tls['source'], 'git');
            expect(
              (tls['description'] as Map)['resolved-ref'],
              '22067026c50da3447931ba71ad13fc95f230d5e8',
            );
          },
        );

        test(
          'then the server includes its transitive commit-hint implementation.',
          () {
            expect(exportedCommitHints, commitHintSource);
          },
        );

        test(
          'then the generated endpoints are only the benchmark control method.',
          () {
            expect(endpointList, 'benchmark:\n  - control:\n');
            expect(endpoints, isNot(contains('DemoAuthEndpoint')));
            expect(endpoints, isNot(contains('DemoDebugEndpoint')));
          },
        );

        test(
          'then a private launch password is kept out of status and provenance.',
          () {
            final secret =
                (passwords['production'] as Map)[metadata['passwordName']] as String;

            expect(base64Url.decode(secret), hasLength(32));
            expect(
              '${prepared.stdout}${prepared.stderr}',
              isNot(contains(secret)),
            );
            expect(metadataText, isNot(contains(secret)));
          },
        );

        test(
          'then the launch password has an export-specific name the server resolves.',
          () {
            final passwordName = metadata['passwordName'] as String;

            expect(
              passwordName,
              matches(RegExp(r'^benchmarkSecret_[0-9a-f]{32}$')),
            );
            expect((passwords['production'] as Map).keys, [passwordName]);
            expect(resolvedPasswordName, passwordName);
          },
        );

        test('then the launch password is excluded from the Cloud upload, '
            'while server files are included.', () {
          expect(uploadIgnored, {
            'benchmark/config/passwords.yaml': true,
            'benchmark/config/production.yaml': false,
            'benchmark/config/benchmark_build.json': false,
            'benchmark/bin/main.dart': false,
            'benchmark/lib/scale/commit_hints.dart': false,
            'vendor/postgres/pubspec.yaml': false,
            'vendor/postgres/lib/src/v3/connection.dart': false,
            'vendor/postgres/LICENSE': false,
            'pubspec.yaml': false,
            'pubspec.lock': false,
          });
        });
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  });

  group('Given a Serverpod CLI at another version than the export resolves,', () {
    late String resolved;
    late Map<String, String> cliEnvironment;

    setUpAll(() async {
      final lock = loadYaml(
        await File(p.join(root, 'pubspec.lock')).readAsString(),
      );
      resolved =
          (((lock as Map)['packages'] as Map)['serverpod_cli'] as Map)['version']
              as String;
      cliEnvironment = await serverpodOnPath(
        scratch,
        'other-cli',
        'echo "Serverpod version: 0.0.1"',
      );
    });

    group('when preparation runs,', () {
      late String output;
      late ProcessResult prepared;

      setUpAll(() async {
        output = p.join(scratch.path, 'other-cli-output');
        prepared = await runDart(
          ['run', 'benchmark/tool/prepare_cloud.dart', '--output', output],
          root,
          cliEnvironment,
        );
      });

      test(
        'then it fails with the command that installs the resolved version.',
        () {
          expect(prepared.exitCode, isNot(0));
          expect(
            prepared.stderr,
            contains(
              'scloud launch runs `serverpod generate` with the Serverpod CLI on PATH, '
              'which is 0.0.1. This export requires $resolved: '
              'dart pub global activate serverpod_cli $resolved',
            ),
          );
        },
      );

      test('then its incomplete output is removed.', () {
        expect(Directory(output).existsSync(), isFalse);
      });
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Given a preparation that has created its output,', () {
    late String output;
    late Process preparation;

    setUpAll(() async {
      output = p.join(scratch.path, 'interrupted');
      preparation = await Process.start(
        Platform.resolvedExecutable,
        ['run', 'benchmark/tool/prepare_cloud.dart', '--output', output],
        workingDirectory: root,
        environment: environment,
      );
      addTearDown(() => stopProcess(preparation));
      preparation.stdout.drain<void>().ignore();
      preparation.stderr.drain<void>().ignore();
      final deadline = DateTime.now().add(const Duration(minutes: 1));
      while (!Directory(output).existsSync()) {
        if (DateTime.now().isAfter(deadline)) fail('No output was created.');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });

    group('when it is interrupted,', () {
      late int exitCode;

      setUpAll(() async {
        preparation.kill(ProcessSignal.sigint);
        exitCode = await preparation.exitCode.timeout(
          const Duration(minutes: 1),
        );
      });

      test('then it fails.', () {
        expect(exitCode, isNot(0));
      });

      test('then its incomplete output is removed.', () {
        expect(Directory(output).existsSync(), isFalse);
      });
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('Given an existing output directory with an earlier export,', () {
    late String output;

    setUpAll(() async {
      output = p.join(scratch.path, 'existing');
      await Directory(output).create();
      await File(
        p.join(output, 'PREPARED.json'),
      ).writeAsString('earlier export');
    });

    group('when preparation targets it,', () {
      late ProcessResult prepared;

      setUpAll(() async {
        prepared = await runDart(
          ['run', 'benchmark/tool/prepare_cloud.dart', '--output', output],
          root,
          environment,
        );
      });

      test('then it is refused.', () {
        expect(prepared.exitCode, isNot(0));
        expect(prepared.stderr, contains('Refusing to overwrite $output'));
      });

      test('then the earlier export is preserved.', () {
        expect(
          File(p.join(output, 'PREPARED.json')).readAsStringSync(),
          'earlier export',
        );
      });
    });
  });

  group('Given a dangling symbolic link at the output path,', () {
    late String output;
    late String target;

    setUpAll(() async {
      output = p.join(scratch.path, 'dangling');
      target = p.join(scratch.path, 'missing-target');
      await Link(output).create(target);
    });

    group('when preparation targets it,', () {
      late ProcessResult prepared;

      setUpAll(() async {
        prepared = await runDart(
          ['run', 'benchmark/tool/prepare_cloud.dart', '--output', output],
          root,
          environment,
        );
      });

      test('then it is refused.', () {
        expect(prepared.exitCode, isNot(0));
        expect(prepared.stderr, contains('Refusing to overwrite $output'));
      });

      test('then the link and its missing target are left as they were.', () {
        expect(Link(output).targetSync(), target);
        expect(
          FileSystemEntity.typeSync(target),
          FileSystemEntityType.notFound,
        );
      });
    });
  });
}

Future<ProcessResult> runDart(
  List<String> arguments,
  String directory,
  Map<String, String> environment,
) {
  return Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: directory,
    environment: environment,
  );
}

/// Ends an owned test [process] if it still runs: interrupts it as a user
/// would, so it removes its output, then kills it if it does not exit in time.
Future<void> stopProcess(Process process) async {
  final exited = process.exitCode.then((_) => true);
  if (await exited.timeout(Duration.zero, onTimeout: () => false)) return;
  process.kill(ProcessSignal.sigint);
  if (await exited.timeout(
    const Duration(seconds: 30),
    onTimeout: () => false,
  )) {
    return;
  }
  process.kill(ProcessSignal.sigkill);
  await process.exitCode;
}

/// Puts an executable `serverpod` [script] first on PATH, where
/// `dart pub global activate serverpod_cli` would install it.
Future<Map<String, String>> serverpodOnPath(
  Directory scratch,
  String name,
  String script,
) async {
  final bin = await Directory(p.join(scratch.path, name)).create();
  final command = File(p.join(bin.path, 'serverpod'));
  await command.writeAsString('#!/bin/sh\n$script\n');
  final mode = await Process.run('chmod', ['+x', command.path]);
  if (mode.exitCode != 0) fail('Could not make ${command.path} executable.');
  return {
    'CI': 'true',
    'PATH':
        '${bin.path}:${p.dirname(Platform.resolvedExecutable)}:${Platform.environment['PATH']}',
  };
}

/// Whether Cloud's upload filter ignores each of [paths]. Cloud applies
/// gitignore rules from a hidden-file default, `.gitignore`, and
/// `.scloudignore`, in that order; git evaluates the same rules here.
Future<Map<String, bool>> cloudUploadIgnores(
  String directory, {
  required List<File> ignoreFiles,
  required List<String> paths,
}) async {
  await Directory(directory).create();
  final rules = [
    '.**',
    for (final file in ignoreFiles) await file.readAsString(),
  ];
  await File(p.join(directory, '.gitignore')).writeAsString(rules.join('\n'));
  final init = await Process.run('git', ['init', '-q', directory]);
  if (init.exitCode != 0) fail('git init failed: ${init.stderr}');
  return {
    for (final path in paths)
      path: switch ((await Process.run('git', [
        '-C',
        directory,
        'check-ignore',
        '--no-index',
        '-q',
        path,
      ])).exitCode) {
        0 => true,
        1 => false,
        final code => fail('git check-ignore failed with $code for $path'),
      },
  };
}
