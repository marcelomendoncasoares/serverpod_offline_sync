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
}
