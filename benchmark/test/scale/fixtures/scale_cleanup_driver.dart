import 'dart:convert';
import 'dart:io';

import 'package:serverpod_offline_sync_benchmark/scale/options.dart';
import 'package:serverpod_offline_sync_benchmark/scale/runner.dart';

/// Runs the real coordinator with workers that complete their protocol phases.
/// HTTP metrics are supplied by the test so server cleanup can fail independently
/// of successful local worker shutdown and exact-verification reports.
Future<void> main(List<String> args) async {
  if (args.length == 1 && args.single == '--worker') {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final phase = (jsonDecode(line) as Map<String, dynamic>)['phase'] as String;
      if (phase == 'verify') {
        stdout.writeln(
          '@benchmark ${jsonEncode({
            'type': 'convergence',
            'ok': true,
            'micros': 1,
            'rounds': 1,
          })}',
        );
      }
      stdout.writeln('@benchmark ${jsonEncode({'type': 'done', 'phase': phase})}');
      if (phase == 'close') return;
    }
    return;
  }

  try {
    await runScale(ScaleOptions.parse(args));
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
