// Pretty-printing benchmark comparison output.

import 'benchmark.dart';
import 'conversion.dart';

void printPerformanceImpact(
  BenchmarkResults benchmarkResults, {
  required int rowCount,
  bool runningInCI = false,
}) {
  print(
    '${runningInCI ? '```' : ''}'
    '\n📊 ${benchmarkResults.operation.name.toUpperCase()} performance impact:',
  );
  final baselineTime = benchmarkResults.baseline;
  final crdtTime = benchmarkResults.crdt;

  final runDelayUs = crdtTime - baselineTime;
  final slowdown = runDelayUs / baselineTime * 100;

  final baselineDelay = baselineTime.toFormattedDuration();
  final crdtDelay = crdtTime.toFormattedDuration();
  final runDelay = runDelayUs.toFormattedDuration();
  final runDelayPerOperation = (runDelayUs / rowCount).toFormattedDuration();

  print('  Time: $baselineDelay --> $crdtDelay ($runDelay)');
  print('  CRDT overhead: ${formatter2.format(slowdown)}% slower');
  print(
    '  Delay per ${benchmarkResults.operation.name}: $runDelayPerOperation',
  );
  if (runningInCI) print('```');
}

void printStorageImpact(
  StorageBenchmarkResults benchmarkResults, {
  required int rowCount,
  bool runningInCI = false,
}) {
  final stages = [
    _StorageStageComparison(
      title: 'INSERT only',
      baselineSize: benchmarkResults.baseline.sizeFor(StorageStage.insert),
      crdtSize: benchmarkResults.crdt.sizeFor(StorageStage.insert),
      baselineIncrement: benchmarkResults.baseline.sizeFor(StorageStage.insert),
      crdtIncrement: benchmarkResults.crdt.sizeFor(StorageStage.insert),
      unitCount: rowCount,
      unitLabel: 'inserted row',
    ),
    _StorageStageComparison(
      title: 'INSERT + UPDATE',
      baselineSize: benchmarkResults.baseline.sizeFor(StorageStage.update),
      crdtSize: benchmarkResults.crdt.sizeFor(StorageStage.update),
      baselineIncrement:
          benchmarkResults.baseline.sizeFor(StorageStage.update) -
          benchmarkResults.baseline.previousSizeFor(StorageStage.update),
      crdtIncrement:
          benchmarkResults.crdt.sizeFor(StorageStage.update) -
          benchmarkResults.crdt.previousSizeFor(StorageStage.update),
      unitCount: rowCount * TypesTableBenchmark.updatedColumnsPerRow,
      unitLabel: 'updated column',
    ),
    _StorageStageComparison(
      title: 'INSERT + UPDATE + DELETE',
      baselineSize: benchmarkResults.baseline.sizeFor(StorageStage.delete),
      crdtSize: benchmarkResults.crdt.sizeFor(StorageStage.delete),
      baselineIncrement:
          benchmarkResults.baseline.sizeFor(StorageStage.delete) -
          benchmarkResults.baseline.previousSizeFor(StorageStage.delete),
      crdtIncrement:
          benchmarkResults.crdt.sizeFor(StorageStage.delete) -
          benchmarkResults.crdt.previousSizeFor(StorageStage.delete),
      unitCount: rowCount,
      unitLabel: 'deleted row',
    ),
  ];

  print('${runningInCI ? '```' : ''}\n💽 Storage impact (base footprint removed):');
  print(
    '  Base database size: '
    '${benchmarkResults.baseline.baseDatabaseSize.toFormattedStorageSize()} '
    '--> ${benchmarkResults.crdt.baseDatabaseSize.toFormattedStorageSize()}',
  );

  for (final stage in stages) {
    print('  ${stage.title}:');
    print(
      '    Net storage: ${stage.baselineSize.toFormattedStorageSize()} '
      '--> ${stage.crdtSize.toFormattedStorageSize()} '
      '(${_formatSignedStorage(stage.extraBytes)})',
    );
    print(
      '    CRDT overhead: ${_formatPercentageIncrease(stage.overheadPercent)}',
    );
    print(
      '    Extra storage per ${stage.unitLabel}: '
      '${_formatSignedStorage(stage.extraBytesPerUnit)}',
    );
  }

  print(
    '  Storage overhead range: '
    '${_formatPercentageValue(stages.first.overheadPercent)}% '
    '--> ${_formatPercentageValue(stages.last.overheadPercent)}%',
  );
  if (runningInCI) print('```');
}

class BenchmarkResults {
  const BenchmarkResults({
    required this.operation,
    required this.baseline,
    required this.crdt,
  });

  final Operation operation;
  final double baseline;
  final double crdt;
}

class StorageBenchmarkResults {
  const StorageBenchmarkResults({
    required this.baseline,
    required this.crdt,
  });

  final StorageBenchmarkRun baseline;
  final StorageBenchmarkRun crdt;
}

class _StorageStageComparison {
  const _StorageStageComparison({
    required this.title,
    required this.baselineSize,
    required this.crdtSize,
    required this.baselineIncrement,
    required this.crdtIncrement,
    required this.unitCount,
    required this.unitLabel,
  });

  final String title;
  final int baselineSize;
  final int crdtSize;
  final int baselineIncrement;
  final int crdtIncrement;
  final int unitCount;
  final String unitLabel;

  int get extraBytes => crdtSize - baselineSize;
  double? get overheadPercent =>
      baselineSize == 0 ? null : extraBytes / baselineSize * 100;
  double get extraBytesPerUnit => (crdtIncrement - baselineIncrement) / unitCount;
}

String _formatSignedStorage(num size) {
  if (size == 0) {
    return '0 B';
  }

  final prefix = size > 0 ? '+' : '-';
  return '$prefix${size.abs().toFormattedStorageSize()}';
}

String _formatPercentageIncrease(double? percent) {
  if (percent == null) {
    return 'n/a (baseline storage is zero)';
  }

  return '${formatter2.format(percent)}% increase';
}

String _formatPercentageValue(double? percent) {
  if (percent == null) {
    return 'n/a';
  }

  return formatter2.format(percent);
}
