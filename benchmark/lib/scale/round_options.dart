// Internal benchmark tooling, not a published library API.
// ignore_for_file: public_member_api_docs, type_annotate_public_apis

import 'package:args/args.dart';

import 'options.dart';

final roundParser = ArgParser()
  ..addOption('target', mandatory: true)
  ..addOption('mode', allowed: ['continuous', 'once'], defaultsTo: 'continuous')
  ..addOption('users', defaultsTo: '4')
  ..addOption('devices', defaultsTo: '2', help: 'Fixed devices per user, at least two.')
  ..addOption('workers', defaultsTo: '4')
  ..addOption('rounds', defaultsTo: '20')
  ..addOption('rows', defaultsTo: '1', help: 'Person rows written per round.')
  ..addOption('write-mode', allowed: ['insert', 'update'], defaultsTo: 'insert')
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
    };
    for (final name in ['rounds', 'rows', 'period-ms']) {
      final value = int.tryParse(parsed[name] as String);
      if (value == null || value < 1) {
        throw FormatException('--$name must be positive.');
      }
      values[name] = value;
    }

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

    return RoundOptions(values);
  }

  final Map<String, dynamic> values;

  ScaleOptions get scale => ScaleOptions(values);
  int number(String name) => values[name] as int;
  bool get updates => values['write-mode'] == 'update';
  bool get continuous => values['mode'] == 'continuous';
  Duration get timeout => Duration(seconds: number('timeout-seconds'));
}
