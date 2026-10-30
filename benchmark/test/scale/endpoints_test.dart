import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:test/fake.dart';
import 'package:test/test.dart';

/// Endpoints only record the server they belong to while being initialized.
class _Server extends Fake implements Server {}

void main() {
  group('Given the benchmark server endpoint dispatch,', () {
    late BenchmarkEndpoints dispatch;

    setUpAll(() {
      dispatch = BenchmarkEndpoints();
    });

    group('when it is initialized,', () {
      setUpAll(() {
        dispatch.initializeEndpoints(_Server());
      });

      test('then its application endpoint exposes the control and echo methods.', () {
        expect(dispatch.connectors.keys, ['benchmark']);
        expect(
          dispatch.connectors['benchmark']!.methodConnectors.keys,
          unorderedEquals(['control', 'echo']),
        );
      });

      test('then its only module is the offline sync module.', () {
        expect(dispatch.modules.keys, ['serverpod_offline_sync']);
      });

      test('then the control endpoint requires a login with the benchmark scope.', () {
        final endpoint = dispatch.connectors['benchmark']!.endpoint;

        expect(endpoint.requireLogin, isTrue);
        expect(endpoint.requiredScopes.map((scope) => scope.name), [benchmarkScope]);
      });
    });
  });
}
