import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/worker.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

void main() {
  test('Given two offline devices belonging to the same user, '
      'when one writes and closes then reopens its database, '
      'then its data persists without appearing in the other device.', () async {
    final directory = await Directory.systemTemp.createTemp('scale-device-test-');
    final options = ScaleOptions.parse([
      '--target',
      'http://127.0.0.1:1/',
      '--data-dir',
      directory.path,
      '--run-id',
      'persistence',
    ]);
    final first = Device(options, 0, 0, (_) {});
    final second = Device(options, 0, 1, (_) {});
    addTearDown(() async {
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    });
    const secret = 'unused-local-device-test-secret';
    await first.setState('offline', secret);
    await second.setState('offline', secret);
    final row = City(id: benchmarkId('persistent-city'), name: 'Saved offline');

    await City.db.insertRow(first.session!, row);
    await first.setState('closed', secret);
    await first.setState('offline', secret);
    final restored = await City.db.find(first.session!);
    final otherRows = await City.db.find(second.session!);

    expect(first.path, isNot(second.path));
    expect(first.userId, second.userId);
    expect(restored.map((city) => (city.id, city.name)).toList(), [(row.id, row.name)]);
    expect(otherRows, isEmpty);
  });

  test(
    'Given one-byte town names written offline, '
    'when a device renames its towns, '
    'then every rename changes the stored name and the journal matches the database.',
    () async {
      final directory = await Directory.systemTemp.createTemp('scale-rename-test-');
      final options = ScaleOptions.parse([
        '--target',
        'http://127.0.0.1:1/',
        '--data-dir',
        directory.path,
        '--run-id',
        'renames',
        '--payload-bytes',
        '1',
        '--seed-rows',
        '2',
        '--seed',
        '3',
      ]);
      final events = <Map<String, dynamic>>[];
      final device = Device(options, 0, 0, events.add);
      addTearDown(() async {
        await device.close();
        await directory.delete(recursive: true);
      });
      await device.setState('offline', 'unused-local-device-test-secret');
      await device.seed();

      var renames = 0;
      for (var i = 0; i < 80; i++) {
        final before = {
          for (final entry in device.towns.entries) entry.key: entry.value['name'],
        };
        await device.operate();
        final operation = events.lastWhere((e) => e['type'] == 'operation');
        if (operation['kind'] == 'update') {
          final id = operation['townId'] as String;
          renames++;
          expect(device.towns[id]!['name'], hasLength(1));
          expect(device.towns[id]!['name'], isNot(before[id]));
        }
      }
      final stored = await Town.db.find(device.session!);

      expect(renames, greaterThan(3));
      expect(
        {
          for (final town in stored)
            town.id.toString(): (town.name, town.cityId.toString()),
        },
        {
          for (final entry in device.towns.entries)
            entry.key: (entry.value['name'], entry.value['cityId']),
        },
      );
    },
  );

  test(
    'Given a device that changes state during the workload, '
    'when residency is accounted, '
    'then opening and closing time is a transition, not the destination state.',
    () async {
      final directory = await Directory.systemTemp.createTemp('scale-residency-test-');
      final options = ScaleOptions.parse([
        '--target',
        'http://127.0.0.1:1/',
        '--data-dir',
        directory.path,
        '--run-id',
        'residency',
      ]);
      final device = Device(options, 0, 0, (_) {});
      addTearDown(() async {
        await device.close();
        await directory.delete(recursive: true);
      });
      const secret = 'unused-local-device-test-secret';
      await device.setState('offline', secret);
      device.beginResidency();

      await Future<void>.delayed(const Duration(milliseconds: 40));
      await device.setState('closed', secret);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await device.setState('offline', secret);
      device.endResidency();

      final micros = device.residencyMicros;
      expect(micros.keys, unorderedEquals(['offline', 'closed', 'transition']));
      expect(micros['transition'], greaterThan(0));
      expect(micros['closed'], greaterThanOrEqualTo(30000));
      expect(micros['offline'], greaterThanOrEqualTo(30000));
    },
  );
}
