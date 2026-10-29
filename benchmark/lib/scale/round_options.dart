// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'package:args/args.dart';

import 'options.dart';

final roundParser = ArgParser()
  ..addOption('target', mandatory: true)
  ..addOption('mode', allowed: ['continuous', 'once'], defaultsTo: 'continuous')
  ..addOption('users', defaultsTo: '4')
  ..addOption(
    'active-users',
    help: 'Users writing during exercise; remaining users keep idle streams open.',
  )
  ..addOption('devices', defaultsTo: '2', help: 'Fixed devices per user, at least two.')
  ..addOption('workers', defaultsTo: '4')
  ..addOption('rounds', defaultsTo: '20')
  ..addOption('rows', defaultsTo: '1', help: 'Domain rows written per round.')
  ..addOption('schema', allowed: ['full', 'city'], defaultsTo: 'full')
  ..addOption(
    'workload',
    allowed: ['city', 'person', 'person-linked', 'town', 'town-linked'],
    defaultsTo: 'person',
  )
  ..addOption('write-mode', allowed: ['insert', 'update'], defaultsTo: 'insert')
  ..addOption('schedule', allowed: ['spread', 'burst'], defaultsTo: 'spread')
  ..addOption('idle-seconds', defaultsTo: '60')
  ..addOption('settle-seconds', defaultsTo: '5')
  ..addOption(
    'period-ms',
    defaultsTo: '2000',
    help: 'Scheduled interval per user; lateness is retained.',
  )
  ..addOption('payload-bytes', defaultsTo: '128')
  ..addOption(
    'timeout-seconds',
    defaultsTo: '60',
    help: 'Deadline for a round or syncOnce call.',
  )
  ..addOption('startup-timeout-seconds', defaultsTo: '600')
  ..addOption('setup-concurrency', defaultsTo: '4')
  ..addOption(
    'warmup-workers',
    defaultsTo: '1',
    help:
        'Worker processes opening streams concurrently; separates setup bursts from established capacity.',
  )
  ..addOption('sample-seconds', defaultsTo: '2')
  ..addOption('run-id')
  ..addOption('data-dir', defaultsTo: '.round-benchmark')
  ..addFlag('sync-diagnostics', defaultsTo: true)
  ..addOption(
    'client-profile-user',
    help: 'User index whose continuous rounds record client frame boundaries.',
  )
  ..addFlag('help', abbr: 'h', negatable: false);

class RoundOptions {
  RoundOptions(this.values);

  factory RoundOptions.parse(List<String> args) {
    final parsed = roundParser.parse(args);
    if (parsed.rest.isNotEmpty) {
      throw FormatException('Unexpected arguments: ${parsed.rest}');
    }
    final scale = ScaleOptions.parse([
      for (final name in [
        'target',
        'users',
        'devices',
        'workers',
        'payload-bytes',
        'timeout-seconds',
        'startup-timeout-seconds',
        'setup-concurrency',
        'sample-seconds',
        'run-id',
        'data-dir',
      ])
        if (parsed[name] != null) ...['--$name', parsed[name] as String],
      '--ramp-ms',
      '0',
      if (!(parsed['sync-diagnostics'] as bool)) '--no-sync-diagnostics',
    ]);
    if (scale.number('devices-min') != scale.number('devices-max') ||
        scale.number('devices-min') < 2) {
      throw const FormatException('--devices must be a fixed number of at least two.');
    }
    final values = {
      ...scale.values,
      'mode': parsed['mode'],
      'write-mode': parsed['write-mode'],
      'schema': parsed['schema'],
      'workload': parsed['workload'],
      'schedule': parsed['schedule'],
    };
    for (final name in [
      'rounds',
      'rows',
      'period-ms',
      'idle-seconds',
      'warmup-workers',
    ]) {
      final value = int.tryParse(parsed[name] as String);
      if (value == null || value < 1) {
        throw FormatException('--$name must be positive.');
      }
      values[name] = value;
    }

    final activeText = parsed['active-users'] as String?;
    final active = activeText == null
        ? scale.number('users')
        : int.tryParse(activeText);
    if (active == null || active < 0 || active > scale.number('users')) {
      throw const FormatException('--active-users must be between zero and --users.');
    }
    if (active < scale.number('users') && parsed['mode'] != 'continuous') {
      throw const FormatException('Idle connected users require continuous mode.');
    }
    values['active-users'] = active;

    final settle = int.tryParse(parsed['settle-seconds'] as String);
    if (settle == null || settle < 0) {
      throw const FormatException('--settle-seconds must be non-negative.');
    }
    values['settle-seconds'] = settle;

    final profile = parsed['client-profile-user'] as String?;
    if (profile != null) {
      final user = int.tryParse(profile);
      if (user == null || user < 0 || user >= scale.number('users')) {
        throw const FormatException(
          '--client-profile-user must name an existing user.',
        );
      }
      if (parsed['mode'] != 'continuous') {
        throw const FormatException('--client-profile-user requires continuous mode.');
      }
      values['client-profile-user'] = user;
    }
    if (values['schema'] == 'city' && values['workload'] != 'city') {
      throw const FormatException('The city schema only supports the city workload.');
    }
    return RoundOptions(values);
  }

  final Map<String, dynamic> values;

  ScaleOptions get scale => ScaleOptions(values);
  int number(String name) => values[name] as int;
  bool get updates => values['write-mode'] == 'update';
  bool get continuous => values['mode'] == 'continuous';
  int get activeUsers => number('active-users');
  int get exerciseMicros => activeUsers == 0
      ? number('idle-seconds') * 1000000
      : number('rounds') * number('period-ms') * 1000;

  int userOffsetMicros(int user) => values['schedule'] == 'burst'
      ? 0
      : user * number('period-ms') * 1000 ~/ activeUsers;

  Duration get timeout => Duration(seconds: number('timeout-seconds'));
}
