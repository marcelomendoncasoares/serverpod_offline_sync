import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_runner.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_worker.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_workload.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runtime_diagnostics.dart';
import 'package:serverpod_offline_sync_benchmark/scale/schema.dart';
import 'package:serverpod_offline_sync_benchmark/scale/server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  test('Given a delivered Town with a stale parent reference, '
      'when exact round delivery is checked, '
      'then matching identifiers and names do not complete the round.', () {
    final expected = Town(
      id: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
      name: 'town',
      cityId: UuidValue.fromString('00000000-0000-4000-8000-000000000002'),
    );
    final actual = expected.copyWith(cityId: null);

    expect(deliveredRows('town', [actual], [expected]), isFalse);
  });

  test('Given visible memory usage and an OOM event, '
      'when cgroup memory is sampled, '
      'then usage, limit, and failure counters remain distinct.', () async {
    final directory = await Directory.systemTemp.createTemp('capacity-memory-');
    addTearDown(() => directory.delete(recursive: true));
    await File('${directory.path}/memory.current').writeAsString('123456');
    await File('${directory.path}/memory.max').writeAsString('268435456');
    await File('${directory.path}/memory.events').writeAsString('oom 2\noom_kill 1\n');

    final sample = CgroupMemorySampler(directory: directory.path).sample();

    expect(sample['currentBytes'], 123456);
    expect(sample['limitBytes'], 268435456);
    expect(sample['events'], {'oom': 2, 'oom_kill': 1});
    expect(sample['peakBytes'], isNull);
  });

  test('Given a hidden memory controller, '
      'when cgroup memory is sampled, '
      'then missing measurements are not reported as zero memory pressure.', () async {
    final directory = await Directory.systemTemp.createTemp('capacity-no-memory-');
    addTearDown(() => directory.delete(recursive: true));

    final sample = CgroupMemorySampler(directory: directory.path).sample();

    expect(sample['available'], isFalse);
    expect(sample.containsKey('currentBytes'), isFalse);
  });

  test('Given overlapping rounds for two independent users, '
      'when observed concurrency is calculated, '
      'then connected participants are counted only during their in-flight work.', () {
    final result = roundConcurrency([
      {'user': 0, 'startedMicros': 100, 'finishedMicros': 300},
      {'user': 1, 'startedMicros': 200, 'finishedMicros': 400},
    ], devicesPerUser: 2);

    expect(result['peakInFlightRounds'], 2);
    expect(result['peakParticipatingDevices'], 4);
    expect(result['windowMicros'], 300);
    expect(result['meanInFlightRounds'], closeTo(4 / 3, .0001));
  });

  test('Given overlapping rounds for the same user, '
      'when observed concurrency is calculated, '
      'then their shared devices are not counted twice.', () {
    final result = roundConcurrency([
      {'user': 0, 'startedMicros': 100, 'finishedMicros': 300},
      {'user': 0, 'startedMicros': 200, 'finishedMicros': 400},
    ], devicesPerUser: 4);

    expect(result['peakInFlightRounds'], 2);
    expect(result['peakParticipatingUsers'], 1);
    expect(result['peakParticipatingDevices'], 4);
    expect(result['meanParticipatingDevices'], 4);
  });

  test('Given consecutive rounds whose boundaries touch, '
      'when observed concurrency is calculated, '
      'then they are not reported as overlapping.', () {
    final result = roundConcurrency([
      {'user': 0, 'startedMicros': 100, 'finishedMicros': 200},
      {'user': 1, 'startedMicros': 200, 'finishedMicros': 300},
    ], devicesPerUser: 2);

    expect(result['peakInFlightRounds'], 1);
    expect(result['peakParticipatingDevices'], 2);
  });

  test('Given eight connected devices and one active user, '
      'when the spread schedule is selected, '
      'then idle users do not dilute the active write rate.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--users',
      '4',
      '--active-users',
      '1',
      '--devices',
      '2',
      '--rounds',
      '3',
      '--period-ms',
      '2000',
    ]);

    expect(options.scale.totalDevices, 8);
    expect(options.activeUsers, 1);
    expect(options.userOffsetMicros(0), 0);
    expect(options.exerciseMicros, 6000000);
  });

  test('Given only idle connected users, '
      'when the hold duration is configured, '
      'then the exercise lasts for the requested hold without a write schedule.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--active-users',
      '0',
      '--idle-seconds',
      '17',
    ]);

    expect(options.activeUsers, 0);
    expect(options.exerciseMicros, 17000000);
  });

  test('Given two active users among eight connected users, '
      'when burst scheduling is selected, '
      'then both users share the same due time.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--users',
      '8',
      '--active-users',
      '2',
      '--schedule',
      'burst',
    ]);

    expect(options.userOffsetMicros(0), 0);
    expect(options.userOffsetMicros(1), 0);
  });

  test(
    'Given two active users among eight connected users, '
    'when spread scheduling is selected, '
    'then their offsets cover the active population rather than all connections.',
    () {
      final options = RoundOptions.parse([
        '--target',
        'http://localhost:8080/',
        '--users',
        '8',
        '--active-users',
        '2',
        '--period-ms',
        '2000',
      ]);

      expect(options.userOffsetMicros(0), 0);
      expect(options.userOffsetMicros(1), 1000000);
    },
  );

  test('Given more active users than connected users, '
      'when options are parsed, '
      'then the impossible workload is rejected.', () {
    expect(
      () => RoundOptions.parse([
        '--target',
        'http://localhost:8080/',
        '--users',
        '2',
        '--active-users',
        '3',
        '--workers',
        '1',
      ]),
      throwsFormatException,
    );
  });

  test('Given syncOnce mode with idle connected users, '
      'when options are parsed, '
      'then the workload cannot claim persistent connections.', () {
    expect(
      () => RoundOptions.parse([
        '--target',
        'http://localhost:8080/',
        '--mode',
        'once',
        '--active-users',
        '0',
      ]),
      throwsFormatException,
    );
  });

  test('Given the ordinary deployed database, '
      'when an isolated capacity destination is selected, '
      'then its name is rejected.', () {
    expect(() => validateCapacityDatabase('serverpod'), throwsArgumentError);
  });

  test('Given a dedicated capacity database name, '
      'when the destination is validated, '
      'then the isolated schema experiment is allowed.', () {
    expect(
      () => validateCapacityDatabase('benchmark_capacity_city_20261029'),
      returnsNormally,
    );
  });

  test('Given a database identifier containing SQL syntax, '
      'when the capacity destination is validated, '
      'then it is rejected before database selection.', () {
    expect(
      () => validateCapacityDatabase(
        'benchmark_capacity_city_x"; DROP DATABASE serverpod;',
      ),
      throwsArgumentError,
    );
  });

  test('Given the full generated schema, '
      'when the flat profile is selected, '
      'then only the City table is registered.', () {
    final tables = benchmarkTables(syncTables, 'city');

    expect(tables.map((table) => table.tableName), ['city']);
  });

  test('Given a flat City-only profile, '
      'when a relational workload is selected, '
      'then incompatible configuration is rejected.', () {
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
      'when its parent graph and changed rows are constructed, '
      'then every reference points to its seeded parent.', () {
    final options = RoundOptions.parse([
      '--target',
      'http://localhost:8080/',
      '--run-id',
      'capacity-linked',
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
}
