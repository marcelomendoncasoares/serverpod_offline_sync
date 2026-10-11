import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runner.dart';
import 'package:serverpod_offline_sync_benchmark/scale/worker.dart';

Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--worker') {
    await workerMain();
    return;
  }
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(
      'dart run benchmark/bin/scale.dart --target https://YOUR-API/ [options]\n${scaleParser.usage}',
    );
    return;
  }
  try {
    await runScale(ScaleOptions.parse(args));
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
