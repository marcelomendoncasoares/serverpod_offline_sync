import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/round_options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_runner.dart';
import 'package:serverpod_offline_sync_benchmark/scale/round_worker.dart';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--worker') {
    await roundWorkerMain();
    return;
  }
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'Measure established streams or fresh syncOnce calls.\n${roundParser.usage}',
    );
    return;
  }
  try {
    await runRounds(RoundOptions.parse(args));
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
