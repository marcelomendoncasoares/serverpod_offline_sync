import 'dart:io';

import 'utils/benchmark.dart';
import 'utils/conversion.dart';
import 'utils/runner.dart';

Future<void> main() async {
  final rowsString = formatter0.format(rowCount);

  print('\n${'=' * 60}');
  print('Performance Benchmark ($rowsString rows)\n');
  print('This benchmark measures the performance impact of using CRDT');
  print('synchronization on database operations.');
  print('-' * 60);

  final baselineBenchmark = CrdtBenchmark('Baseline', crdtEnabled: false);
  final (baselineTime, baselineSize) = await runWithProgress(
    'Running baseline benchmark',
    baselineBenchmark.report,
  );

  final crdtBenchmark = CrdtBenchmark('Crdt', crdtEnabled: true);
  final (crdtTime, crdtSize) = await runWithProgress(
    'Running CRDT benchmark',
    crdtBenchmark.report,
  );

  if (baselineTime > crdtTime) {
    print(
      '''
❌ Baseline time is greater than CRDT time. This is likely due
to running with a very low number of rows ($rowsString). This is not
a valid benchmark and will not be reported.''',
    );
    exit(1);
  }

  print('\n📊 Performance Impact:');
  final baselineSeconds = baselineTime / Duration.microsecondsPerSecond;
  final crdtSeconds = crdtTime / Duration.microsecondsPerSecond;
  final runDelayUs = crdtTime - baselineTime;
  final slowdown = runDelayUs / baselineTime * 100;
  final runDelayMs = runDelayUs / Duration.microsecondsPerMillisecond;
  final averageDelayMs = runDelayMs / rowCount;
  print(
    '  Time: ${formatter2.format(baselineSeconds)} s '
    '--> ${formatter2.format(crdtSeconds)} s '
    '(+${formatter2.format(crdtSeconds - baselineSeconds)} s)',
  );
  print('  CRDT overhead: ${formatter2.format(slowdown)}% slower');
  print('  Delay per insert: ${formatter3.format(averageDelayMs)}ms');

  print('\n💽 Storage Impact:');
  final storageIncrease = crdtSize - baselineSize;
  final storageIncPercent = storageIncrease / baselineSize * 100;
  final extraStoragePerRow = storageIncrease / rowCount;
  final storageIncreaseVolume = storageIncPercent > 100
      ? '(x${formatter2.format(storageIncPercent / 100)})'
      : '(+${(crdtSize - baselineSize).toFormattedStorageSize()})';
  print(
    '  Storage size: ${baselineSize.toFormattedStorageSize()} '
    '--> ${crdtSize.toFormattedStorageSize()} $storageIncreaseVolume',
  );
  print('  CRDT overhead: ${formatter2.format(storageIncPercent)}% increase');
  print('  Storage per row: ${extraStoragePerRow.toFormattedStorageSize()}');

  print('\n${'-' * 60}');
  print('✅ Benchmark complete!');
  print('${'=' * 60}\n');
}
