import 'dart:io';
import 'dart:isolate';

import 'package:cli_tools/src/logger/helpers/progress.dart';

Progress? _trackedAnimationInProgress;

Future<T> runWithProgress<T>(String message, Future<T> Function() runner) async {
  _stopAnimationInProgress();
  final progress = Progress(message, stdout);
  _trackedAnimationInProgress = progress;
  final result = await Isolate.run(runner);
  _trackedAnimationInProgress = null;
  progress.complete();
  return result;
}

void _stopAnimationInProgress() {
  if (_trackedAnimationInProgress != null) {
    _trackedAnimationInProgress?.stopAnimation();
    // Since animation modifies the current line we add a new line so that
    // the next print doesn't end up on the same line.
    stdout.write('\n');
  }
  _trackedAnimationInProgress = null;
}
