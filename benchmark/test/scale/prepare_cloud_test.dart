import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('Given a fresh Cloud benchmark destination,', () {
    late Directory scratch;
    late String root;
    late String output;

    setUpAll(() async {
      final library = await Isolate.resolvePackageUri(
        Uri.parse('package:serverpod_offline_sync_benchmark/scale/common.dart'),
      );
      root = p.normalize(p.join(File.fromUri(library!).parent.path, '../../..'));
      scratch = await Directory.systemTemp.createTemp('benchmark-cloud-test-');
      output = p.join(scratch.path, 'prepared');
    });

    tearDownAll(() async {
      await scratch.delete(recursive: true);
    });

    group(
      'when preparation and the standard generation hook run,',
      () {
        late ProcessResult prepared;
        late ProcessResult generated;
        late ProcessResult analyzed;
        late bool dependenciesResolved;
        late String endpoints;
        late String protocol;
        late String secret;
        late String metadata;

        setUpAll(() async {
          prepared = await runDart([
            'run',
            'benchmark/tool/prepare_cloud.dart',
            '--output',
            output,
          ], root);
          if (prepared.exitCode != 0) {
            fail('Preparation failed:\n${prepared.stdout}\n${prepared.stderr}');
          }

          dependenciesResolved = File(
            p.join(output, '.dart_tool/package_config.json'),
          ).existsSync();
          generated = await runDart([
            'run',
            'serverpod_cli',
            '--no-analytics',
            'generate',
          ], p.join(output, 'benchmark'));
          analyzed = await runDart(['analyze'], output);
          endpoints = await File(
            p.join(output, 'benchmark/lib/src/generated/endpoints.dart'),
          ).readAsString();
          protocol = await File(
            p.join(output, 'benchmark/lib/src/generated/protocol.dart'),
          ).readAsString();
          final passwords =
              loadYaml(
                    await File(
                      p.join(output, 'benchmark/config/passwords.yaml'),
                    ).readAsString(),
                  )
                  as Map;
          secret = (passwords['production'] as Map)['benchmarkSecret'] as String;
          metadata = await File(p.join(output, 'PREPARED.json')).readAsString();
        });

        test('then dependencies and regeneratable application models are ready.', () {
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
          expect(endpoints, isNot(contains('AuthTestEndpoint')));
        });

        test(
          'then a private launch password is kept out of status and provenance.',
          () {
            expect(base64Url.decode(secret), hasLength(32));
            expect('${prepared.stdout}${prepared.stderr}', isNot(contains(secret)));
            expect(metadata, isNot(contains(secret)));
          },
        );
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}

Future<ProcessResult> runDart(List<String> arguments, String directory) {
  return Process.run(
    Platform.resolvedExecutable,
    arguments,
    workingDirectory: directory,
    environment: {
      'CI': 'true',
      'PATH':
          '${p.dirname(Platform.resolvedExecutable)}${Platform.isWindows ? ';' : ':'}${Platform.environment['PATH'] ?? ''}',
    },
  );
}
