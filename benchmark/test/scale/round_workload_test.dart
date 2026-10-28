import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_workload.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runtime_diagnostics.dart';
import 'package:serverpod_offline_sync_benchmark/scale/schema.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  test('Given the deployed database name, '
      'when capacity setup validates its destination, '
      'then it refuses to create or replace that database.', () {
    expect(() => validateCapacityDatabase('serverpod'), throwsArgumentError);
    expect(
      () => validateCapacityDatabase('benchmark_capacity_full_20261026'),
      returnsNormally,
    );
    expect(
      () => validateCapacityDatabase(
        'benchmark_capacity_city_test"; DROP DATABASE serverpod;',
      ),
      throwsArgumentError,
    );
  });

  test('Given the full generated schema, '
      'when the minimal experiment selects its tables, '
      'then only the City table with no persisted foreign keys is registered.', () {
    final tables = benchmarkTables(syncTables, 'city');

    expect(tables.map((table) => table.tableName), ['city']);
    expect(City(name: 'one').toJson().keys, isNot(contains('cityId')));
  });

  test('Given a City-only server schema, '
      'when a relational workload is requested, '
      'then the incompatible configuration is rejected.', () {
    expect(
      () => RoundOptions.parse([
        '--target',
        'http://localhost:8080/',
        '--schema',
        'city',
        '--workload',
        'town-linked',
      ]),
      throwsFormatException,
    );
  });

  test('Given a linked Town workload, '
      'when its parent graph and timed rows are created, '
      'then both foreign keys point at exactly the seeded parents.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--run-id',
      'relation-control',
      '--workload',
      'town-linked',
    ]);
    final parents = roundParents(options, 0);
    final row = makeRoundRows(options, 0, 2, 1, 1).single as Town;

    expect(row.cityId, parents['city']!.single.id);
    expect(row.mayorId, parents['person']!.single.id);
    expect((parents['person']!.single as Person).cityId, row.cityId);
    expect(row.name, startsWith('round:2/row:0/writer:1/'));
  });

  test('Given a nullable Town workload, '
      'when the timed rows are created, '
      'then it has the same fields but no populated relationship.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--run-id',
      'nullable-control',
      '--workload',
      'town',
    ]);
    final parents = roundParents(options, 0);
    final row = makeRoundRows(options, 0, 2, 1, 1).single as Town;

    expect(parents, isEmpty);
    expect(row.cityId, isNull);
    expect(row.mayorId, isNull);
  });

  test(
    'Given a visible cgroup memory limit and an OOM counter, '
    'when memory is sampled, '
    'then charged memory and failure counts remain distinct from process RSS.',
    () async {
      final directory = await Directory.systemTemp.createTemp('capacity-memory-');
      addTearDown(() => directory.delete(recursive: true));
      await File('${directory.path}/memory.current').writeAsString('123456');
      await File('${directory.path}/memory.max').writeAsString('268435456');
      await File(
        '${directory.path}/memory.events',
      ).writeAsString('oom 2\noom_kill 1\n');

      final sample = CgroupMemorySampler(directory: directory.path).sample();

      expect(sample['currentBytes'], 123456);
      expect(sample['limitBytes'], 268435456);
      expect(sample['events'], {'oom': 2, 'oom_kill': 1});
      expect(sample['peakBytes'], isNull);
    },
  );
}
