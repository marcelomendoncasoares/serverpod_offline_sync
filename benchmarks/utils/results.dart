import 'benchmark.dart';
import 'conversion.dart';

void printPerformanceImpact(BenchmarkResults benchmarkResults) {
  print('\n📊 ${benchmarkResults.operation.name.toUpperCase()} performance impact:');
  final (baselineTime, _) = benchmarkResults.baseline;
  final (crdtTime, _) = benchmarkResults.crdt;

  final runDelayUs = crdtTime - baselineTime;
  final slowdown = runDelayUs / baselineTime * 100;

  final baselineDelay = baselineTime.toFormattedDuration();
  final crdtDelay = crdtTime.toFormattedDuration();
  final runDelay = runDelayUs.toFormattedDuration();
  final runDelayPerOperation = (runDelayUs / rowCount).toFormattedDuration();

  print('  Time: $baselineDelay --> $crdtDelay ($runDelay)');
  print('  CRDT overhead: ${formatter2.format(slowdown)}% slower');
  print('  Delay per ${benchmarkResults.operation.name}: $runDelayPerOperation');
}

void printStorageImpact(BenchmarkResults benchmarkResults) {
  print('\n💽 Storage impact:');
  final (_, baselineSize) = benchmarkResults.baseline;
  final (_, crdtSize) = benchmarkResults.crdt;

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
}

class BenchmarkResults {
  const BenchmarkResults({
    required this.operation,
    required this.baseline,
    required this.crdt,
  });

  final Operation operation;
  final (double, int) baseline;
  final (double, int) crdt;
}
