// A cross-process placement barrier around the ordinary streaming round worker.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/common.dart';
import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_worker.dart';
import 'package:serverpod_offline_sync_benchmark/scale/worker.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

Future<void> main(List<String> args) async {
  final config =
      jsonDecode(await File(args.single).readAsString()) as Map<String, dynamic>;
  final options = RoundOptions.parse([
    '--target',
    config['targets'][0] as String,
    '--run-id',
    config['runId'] as String,
    '--data-dir',
    config['dataDir'] as String,
    '--users',
    '1',
    '--devices',
    '2',
    '--workers',
    '1',
    '--rounds',
    '${config['rounds']}',
    '--period-ms',
    '${config['periodMs']}',
    '--setup-concurrency',
    '1',
    '--timeout-seconds',
    '60',
  ]);
  final secret = requireSecret();
  late final RoundWorker worker;
  void emit(Map<String, dynamic> event) => stdout.writeln(
    '@benchmark ${jsonEncode({'phase': worker.phase, ...event})}',
  );
  worker = RoundWorker(options, 0, emit, secret);
  final commands = StreamIterator(
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
  );
  try {
    final devices = [
      for (var device = 0; device < 2; device++)
        Device(
          ScaleOptions({...options.values, 'target': config['targets'][device]}),
          0,
          device,
          emit,
        ),
    ];
    worker.groups[0] = devices;
    worker.journals[0] = {'person': [], 'city': [], 'town': []};
    final admin = Client(options.scale.target)..authKeyProvider = BenchmarkAuth(secret);
    try {
      await control(admin, {
        'action': 'provision',
        'userId': devices.first.userId.toString(),
      });
    } finally {
      admin.close();
    }
    for (final device in devices) {
      await device.open(secret);
    }
    worker.lag.start();
    worker.phase = 'warmup';
    await worker.warmup();
    emit({'type': 'placementReady', 'userId': devices.first.userId.toString()});
    if (!await commands.moveNext() || commands.current != 'exercise') return;

    worker.phase = 'exercise';
    await worker.exercise();
    worker.phase = 'verify';
    await worker.verify();
    emit({'type': 'crossComplete'});
  } on Object catch (error, stack) {
    emit({'type': 'fatal', 'error': '$error', 'stack': '$stack'});
    exitCode = 1;
  } finally {
    worker.phase = 'close';
    await worker.close();
    await commands.cancel();
  }
}
