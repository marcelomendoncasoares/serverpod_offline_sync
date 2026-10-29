// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// Reads the CPU controller exposed inside the server's container. This reports
/// the visible cgroup, not an inferred quota from the number of logical CPUs.
class CgroupCpuSampler {
  CgroupCpuSampler({
    this.directory = '/sys/fs/cgroup',
    this.membershipFile = '/proc/self/cgroup',
  });

  final String directory;
  final String membershipFile;

  String _processDirectory() {
    final membership = File(membershipFile);
    if (!membership.existsSync()) return directory;
    for (final line in membership.readAsLinesSync()) {
      if (!line.startsWith('0::')) continue;
      final path = line.substring(3);
      if (!path.startsWith('/') || path.split('/').contains('..')) continue;
      final candidate = '$directory$path';
      if (File('$candidate/cpu.max').existsSync()) return candidate;
    }
    // A container may expose only its controller root, hiding the host path.
    return directory;
  }

  Map<String, dynamic> sample() {
    try {
      final processDirectory = _processDirectory();
      final v2 = File('$processDirectory/cpu.max');
      if (v2.existsSync()) {
        final limit = v2.readAsStringSync().trim().split(RegExp(r'\s+'));
        final quota = limit[0] == 'max' ? null : int.parse(limit[0]);
        final period = int.parse(limit[1]);
        final stat = _stat('$processDirectory/cpu.stat');
        return {
          'available': true,
          'version': 2,
          'directory': processDirectory,
          'quotaMicros': quota,
          'periodMicros': period,
          'quotaCores': quota == null ? null : quota / period,
          'usageMicros': stat['usage_usec'],
          'periods': stat['nr_periods'],
          'throttledPeriods': stat['nr_throttled'],
          'throttledMicros': stat['throttled_usec'],
          'scope': 'visible container cgroup; ancestor limits may be hidden',
        };
      }

      for (final path in [directory, '$directory/cpu', '$directory/cpu,cpuacct']) {
        final quotaFile = File('$path/cpu.cfs_quota_us');
        if (!quotaFile.existsSync()) continue;
        final quota = int.parse(quotaFile.readAsStringSync().trim());
        final period = int.parse(
          File('$path/cpu.cfs_period_us').readAsStringSync().trim(),
        );
        final stat = _stat('$path/cpu.stat');
        return {
          'available': true,
          'version': 1,
          'quotaMicros': quota < 0 ? null : quota,
          'periodMicros': period,
          'quotaCores': quota < 0 ? null : quota / period,
          'periods': stat['nr_periods'],
          'throttledPeriods': stat['nr_throttled'],
          'throttledMicros': stat['throttled_time'] == null
              ? null
              : stat['throttled_time']! ~/ 1000,
          'scope': 'visible container cgroup; ancestor limits may be hidden',
        };
      }
      return {'available': false, 'reason': 'CPU controller is not exposed'};
    } on Object catch (error) {
      return {'available': false, 'reason': error.toString()};
    }
  }

  Map<String, int> _stat(String path) {
    final file = File(path);
    if (!file.existsSync()) return {};
    return {
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty)
          line.trim().split(RegExp(r'\s+'))[0]: int.parse(
            line.trim().split(RegExp(r'\s+'))[1],
          ),
    };
  }
}

final cpuCgroup = CgroupCpuSampler();

/// A small, read-only probe run at diagnostic boundaries, outside the workload.
/// One acquired connection is warmed before timing serial SELECT 1 exchanges.
Future<Map<String, dynamic>> databaseRoundTripProbe(Session session) async {
  final before = cpuCgroup.sample();
  final total = Stopwatch()..start();
  final samples = <int>[];
  late int connectionWaitAndBeginMicros;
  late int singleBatchMicros;
  late List<dynamic> plan;
  await session.db.transaction((tx) async {
    connectionWaitAndBeginMicros = total.elapsedMicroseconds;
    await session.db.unsafeExecute('SET TRANSACTION READ ONLY', transaction: tx);
    await session.db.unsafeExecute(
      "SET LOCAL statement_timeout = '2s'",
      transaction: tx,
    );
    for (var index = 0; index < 3; index++) {
      await session.db.unsafeQuery('SELECT 1', transaction: tx);
    }
    for (var index = 0; index < 16; index++) {
      final watch = Stopwatch()..start();
      final rows = await session.db.unsafeQuery('SELECT 1', transaction: tx);
      samples.add(watch.elapsedMicroseconds);
      if (rows.single.single != 1) throw StateError('Unexpected SELECT 1 result.');
    }
    final batch = Stopwatch()..start();
    final rows = await session.db.unsafeQuery(
      'SELECT 1 FROM generate_series(1, 16)',
      transaction: tx,
    );
    singleBatchMicros = batch.elapsedMicroseconds;
    if (rows.length != 16) throw StateError('Unexpected batched probe result.');
    plan = (await session.db.unsafeQuery(
      'EXPLAIN (ANALYZE, FORMAT JSON) SELECT 1',
      transaction: tx,
    )).toList();
  });
  final sorted = samples.toList()..sort();
  return {
    'samples': samples.length,
    'warmupQueries': 3,
    'serialSelect1Micros': samples,
    'minimumMicros': sorted.first,
    'medianMicros': (sorted[7] + sorted[8]) / 2,
    'p95Micros': sorted.last,
    'meanMicros': samples.reduce((left, right) => left + right) / samples.length,
    'connectionWaitAndBeginMicros': connectionWaitAndBeginMicros,
    'singleQuery16RowsMicros': singleBatchMicros,
    'totalMicros': total.elapsedMicroseconds,
    'select1Plan': plan,
    'cpuCgroupBefore': before,
    'cpuCgroupAfter': cpuCgroup.sample(),
    'measurement':
        'Same warmed connection; includes driver, network, server execution and scheduling.',
  };
}

/// Visible cgroup memory, reported separately from process RSS and high-water RSS.
/// An unavailable counter remains null; it is never interpreted as zero pressure.
class CgroupMemorySampler {
  CgroupMemorySampler({this.directory = '/sys/fs/cgroup'});

  final String directory;

  Map<String, dynamic> sample() {
    try {
      for (final path in [directory, '$directory/memory']) {
        final v2 = File('$path/memory.current').existsSync();
        if (!v2 && !File('$path/memory.usage_in_bytes').existsSync()) continue;

        int? read(String name) {
          final file = File('$path/$name');
          return file.existsSync()
              ? int.tryParse(file.readAsStringSync().trim())
              : null;
        }

        Map<String, int> pairs(String name) {
          final file = File('$path/$name');
          if (!file.existsSync()) return {};
          return {
            for (final line in file.readAsLinesSync())
              if (line.trim().isNotEmpty)
                line.trim().split(RegExp(r'\s+'))[0]: int.parse(
                  line.trim().split(RegExp(r'\s+'))[1],
                ),
          };
        }

        return {
          'available': true,
          'version': v2 ? 2 : 1,
          'currentBytes': read(v2 ? 'memory.current' : 'memory.usage_in_bytes'),
          'limitBytes': read(v2 ? 'memory.max' : 'memory.limit_in_bytes'),
          'peakBytes': read(v2 ? 'memory.peak' : 'memory.max_usage_in_bytes'),
          'failCount': v2 ? null : read('memory.failcnt'),
          'events': pairs(v2 ? 'memory.events' : 'memory.oom_control'),
          'scope': 'visible container cgroup; ancestor limits may be hidden',
        };
      }
      return {'available': false, 'reason': 'Memory controller is not exposed'};
    } on Object catch (error) {
      return {'available': false, 'reason': error.toString()};
    }
  }
}

final memoryCgroup = CgroupMemorySampler();
