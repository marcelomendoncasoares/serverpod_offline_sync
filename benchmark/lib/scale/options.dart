// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'dart:io';
import 'dart:math';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

final scaleParser = ArgParser()
  ..addOption('target', help: 'Deployed benchmark API URL (http or https).')
  ..addOption('users', defaultsTo: '2')
  ..addOption('devices', defaultsTo: '2', help: 'Devices per user: N or MIN:MAX.')
  ..addOption(
    'workers',
    defaultsTo: '1',
    help: 'Dart processes, at most the number of users.',
  )
  ..addOption(
    'duration',
    defaultsTo: '20',
    help: 'Workload seconds, excluding setup and verification.',
  )
  ..addOption(
    'interval-ms',
    defaultsTo: '500',
    help: 'Think time after each device operation.',
  )
  ..addOption('seed-rows', defaultsTo: '5', help: 'Initial cities per user.')
  ..addOption('payload-bytes', defaultsTo: '128', help: 'ASCII bytes per town name.')
  ..addOption('seed', defaultsTo: '1')
  ..addOption(
    'active',
    defaultsTo: '0.6',
    help: 'Probability of online writers in each state epoch.',
  )
  ..addOption(
    'idle',
    defaultsTo: '0.2',
    help: 'Probability of connected devices without writes.',
  )
  ..addOption(
    'closed',
    defaultsTo: '0.1',
    help:
        'Probability of closed database and network clients; remainder writes offline.',
  )
  ..addOption(
    'churn-seconds',
    defaultsTo: '5',
    help: 'Reassign device states on each epoch; 0 holds initial states.',
  )
  ..addOption('sample-seconds', defaultsTo: '2')
  ..addOption(
    'timeout-seconds',
    defaultsTo: '120',
    help: 'Per-phase and convergence deadline.',
  )
  ..addOption(
    'ramp-ms',
    defaultsTo: '100',
    help: 'Delay between device starts in each worker.',
  )
  ..addOption(
    'run-id',
    help: 'Unique user namespace; defaults to UTC timestamp plus PID.',
  )
  ..addOption(
    'data-dir',
    defaultsTo: '.scale-benchmark',
    help: 'Parent directory for retained per-run databases and reports.',
  )
  ..addFlag('help', abbr: 'h', negatable: false);

class ScaleOptions {
  ScaleOptions(this.values);

  factory ScaleOptions.parse(List<String> args) {
    final parsed = scaleParser.parse(args);
    if (parsed.rest.isNotEmpty) {
      throw FormatException('Unexpected arguments: ${parsed.rest}');
    }
    final target = Uri.tryParse(parsed['target'] as String? ?? '');
    if (target == null ||
        !['http', 'https'].contains(target.scheme) ||
        target.host.isEmpty ||
        target.userInfo.isNotEmpty ||
        target.hasQuery ||
        target.hasFragment) {
      throw const FormatException(
        '--target must be an http(s) API URL without credentials, query, or fragment.',
      );
    }
    final result = <String, dynamic>{
      'target': target.toString().endsWith('/') ? target.toString() : '$target/',
    };
    for (final name in [
      'users',
      'workers',
      'duration',
      'interval-ms',
      'seed-rows',
      'payload-bytes',
      'sample-seconds',
      'timeout-seconds',
    ]) {
      final value = int.tryParse(parsed[name] as String);
      if (value == null || value < 1) {
        throw FormatException('--$name must be positive.');
      }
      result[name] = value;
    }
    for (final name in ['seed', 'churn-seconds', 'ramp-ms']) {
      final value = int.tryParse(parsed[name] as String);
      if (value == null || value < 0) {
        throw FormatException('--$name must be nonnegative.');
      }
      result[name] = value;
    }
    for (final name in ['active', 'idle', 'closed']) {
      final value = double.tryParse(parsed[name] as String);
      if (value == null || !value.isFinite || value < 0 || value > 1) {
        throw FormatException('--$name must be between 0 and 1.');
      }
      result[name] = value;
    }
    if ((result['active'] as double) +
            (result['idle'] as double) +
            (result['closed'] as double) >
        1.000000001) {
      throw const FormatException('--active + --idle + --closed must not exceed 1.');
    }
    final devices = (parsed['devices'] as String).split(':').map(int.tryParse).toList();
    if (devices.isEmpty ||
        devices.length > 2 ||
        devices.any((v) => v == null || v < 1) ||
        devices.first! > devices.last!) {
      throw const FormatException(
        '--devices must be N or MIN:MAX with 1 <= MIN <= MAX.',
      );
    }
    result['devices-min'] = devices.first;
    result['devices-max'] = devices.last;
    if ((result['workers'] as int) > (result['users'] as int)) {
      throw const FormatException('--workers must not exceed --users.');
    }
    final runId =
        parsed['run-id'] as String? ??
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-$pid';
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(runId)) {
      throw const FormatException(
        '--run-id must contain 1-100 letters, digits, hyphens or underscores.',
      );
    }
    result['run-id'] = runId;
    result['directory'] = p.absolute(parsed['data-dir'] as String, runId);
    return ScaleOptions(result);
  }

  final Map<String, dynamic> values;

  int number(String name) => values[name] as int;
  double fraction(String name) => (values[name] as num).toDouble();
  String get target => values['target'] as String;
  String get runId => values['run-id'] as String;
  String get directory => values['directory'] as String;

  int devicesFor(int user) =>
      number('devices-min') +
      Random(
        number('seed') + user * 104729,
      ).nextInt(number('devices-max') - number('devices-min') + 1);

  String stateFor(int user, int device, int epoch) {
    final roll = Random(
      number('seed') + user * 104729 + device * 1009 + epoch * 7919,
    ).nextDouble();
    if (roll < fraction('active')) return 'active';
    if (roll < fraction('active') + fraction('idle')) return 'idle';
    if (roll < fraction('active') + fraction('idle') + fraction('closed')) {
      return 'closed';
    }
    return 'offline';
  }
}
