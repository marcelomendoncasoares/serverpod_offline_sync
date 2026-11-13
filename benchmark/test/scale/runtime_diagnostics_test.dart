import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/common.dart' show processSample;
import 'package:serverpod_offline_sync_benchmark/scale/runtime_diagnostics.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('benchmark-cgroup-test-');
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'Given a file descriptor that disappears during process sampling, '
    'when the sample is collected, '
    'then other process metrics remain available without throwing.',
    () {
      final sample = IOOverrides.runWithIOOverrides(
        processSample,
        _VanishingDescriptorOverrides(),
      );

      expect(sample['pid'], pid);
      expect(sample['rssBytes'], greaterThan(0));
      expect(sample['cpuUserTicks'], isNonNegative);
      expect(sample['threads'], greaterThan(0));
      expect(sample['openFds'], isNull);
      expect(sample['openFdsUnavailable'], contains('File descriptor disappeared'));
    },
    testOn: 'linux',
  );

  test(
    'Given a cgroup v2 CPU budget of 25 ms per 100 ms, '
    'when sampled, '
    'then it reports a quarter core and cumulative throttling in microseconds.',
    () async {
      await File('${directory.path}/cpu.max').writeAsString('25000 100000\n');
      await File('${directory.path}/cpu.stat').writeAsString(
        'usage_usec 900000\nnr_periods 20\nnr_throttled 7\nthrottled_usec 140000\n',
      );

      final sample = CgroupCpuSampler(directory: directory.path).sample();

      expect(sample['available'], true);
      expect(sample['version'], 2);
      expect(sample['quotaCores'], 0.25);
      expect(sample['usageMicros'], 900000);
      expect(sample['periods'], 20);
      expect(sample['throttledPeriods'], 7);
      expect(sample['throttledMicros'], 140000);
    },
  );

  test(
    'Given a process in a quarter-core child cgroup beneath an unlimited root, '
    'when sampled, '
    'then its own quota and throttling counters are reported.',
    () async {
      await File('${directory.path}/cpu.max').writeAsString('max 100000\n');
      final child = await Directory('${directory.path}/app/benchmark').create(
        recursive: true,
      );
      await File('${child.path}/cpu.max').writeAsString('25000 100000\n');
      await File('${child.path}/cpu.stat').writeAsString(
        'usage_usec 900000\nnr_periods 20\nnr_throttled 7\nthrottled_usec 140000\n',
      );
      final membership = await File('${directory.path}/membership').writeAsString(
        '0::/app/benchmark\n',
      );

      final sample = CgroupCpuSampler(
        directory: directory.path,
        membershipFile: membership.path,
      ).sample();

      expect(sample['quotaCores'], 0.25);
      expect(sample['throttledMicros'], 140000);
      expect(sample['directory'], child.path);
    },
  );

  test(
    'Given a cgroup v1 CPU budget of two cores, '
    'when sampled, '
    'then nanosecond throttling is converted to microseconds.',
    () async {
      final controller = await Directory('${directory.path}/cpu').create();
      await File('${controller.path}/cpu.cfs_quota_us').writeAsString('200000\n');
      await File('${controller.path}/cpu.cfs_period_us').writeAsString('100000\n');
      await File('${controller.path}/cpu.stat').writeAsString(
        'nr_periods 20\nnr_throttled 7\nthrottled_time 140000000\n',
      );

      final sample = CgroupCpuSampler(directory: directory.path).sample();

      expect(sample['available'], true);
      expect(sample['version'], 1);
      expect(sample['quotaCores'], 2);
      expect(sample['periods'], 20);
      expect(sample['throttledPeriods'], 7);
      expect(sample['throttledMicros'], 140000);
    },
  );

  test(
    'Given a visible cgroup with an unlimited CPU budget, '
    'when sampled, '
    'then it leaves the quota unknown instead of using the processor count.',
    () async {
      await File('${directory.path}/cpu.max').writeAsString('max 100000\n');

      final sample = CgroupCpuSampler(directory: directory.path).sample();

      expect(sample['available'], true);
      expect(sample['quotaCores'], isNull);
      expect(sample['quotaMicros'], isNull);
      expect(sample['throttledMicros'], isNull);
    },
  );

  test(
    'Given an environment without an exposed CPU controller, '
    'when sampled, '
    'then the unavailable measurement is reported explicitly.',
    () {
      final sample = CgroupCpuSampler(directory: directory.path).sample();

      expect(sample, {
        'available': false,
        'reason': 'CPU controller is not exposed',
      });
    },
  );
}

final class _VanishingDescriptorOverrides extends IOOverrides {
  @override
  Directory createDirectory(String path) => path == '/proc/self/fd'
      ? _VanishingDescriptorDirectory()
      : super.createDirectory(path);
}

class _VanishingDescriptorDirectory implements Directory {
  @override
  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true}) {
    throw const FileSystemException('File descriptor disappeared', '/proc/self/fd/20');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
