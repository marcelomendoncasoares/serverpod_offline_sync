import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:test/test.dart';

void main() {
  const password = 'a secret imported as a Serverpod password';
  const variable = 'a secret set as BENCHMARK_SECRET variable';

  test('Given both a Serverpod password and a BENCHMARK_SECRET variable, '
      'when the server resolves its secret, '
      'then the password is used.', () {
    final secret = requireSecret(
      password: password,
      environment: {'BENCHMARK_SECRET': variable},
    );

    expect(secret, password);
  });

  test('Given only a BENCHMARK_SECRET variable, '
      'when the server resolves its secret, '
      'then the variable is used.', () {
    final secret = requireSecret(environment: {'BENCHMARK_SECRET': variable});

    expect(secret, variable);
  });

  test('Given a Serverpod password shorter than 24 characters '
      'and a valid BENCHMARK_SECRET variable, '
      'when the server resolves its secret, '
      'then the password is rejected by name.', () {
    expect(
      () => requireSecret(
        password: 'too short',
        passwordName: 'benchmarkSecret_0123',
        environment: {'BENCHMARK_SECRET': variable},
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Set the benchmarkSecret_0123 Serverpod password or BENCHMARK_SECRET '
              'to at least 24 characters.',
        ),
      ),
    );
  });

  group('Given a server directory without prepared build metadata,', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('benchmark-server-');
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('when the server resolves its password name, '
        'then it is benchmarkSecret.', () {
      expect(benchmarkPasswordName(directory.path), 'benchmarkSecret');
    });
  });

  group('Given a prepared server directory that records its password name,', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('benchmark-server-');
      final build = File(p.join(directory.path, 'config', 'benchmark_build.json'));
      await build.parent.create();
      await build.writeAsString(
        jsonEncode({'passwordName': 'benchmarkSecret_0123abcd'}),
      );
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    test('when the server resolves its password name, '
        'then it is the recorded name.', () {
      expect(benchmarkPasswordName(directory.path), 'benchmarkSecret_0123abcd');
    });
  });
}
