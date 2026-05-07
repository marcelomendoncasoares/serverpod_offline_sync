import 'utils/benchmark.dart';
import 'utils/conversion.dart';
import 'utils/results.dart';
import 'utils/runner.dart';

Future<void> main(List<String> args) async {
  final runningInCI = args.contains('--ci');
  String? rowCountArg;
  for (final arg in args) {
    if (arg.startsWith('--rows=')) {
      rowCountArg = arg.substring(7);
    }
  }
  final rowCount = rowCountArg == null ? 1000 : int.parse(rowCountArg);
  final rowsString = formatter0.format(rowCount);

  if (!runningInCI) print('\n${'=' * 60}');
  print('## Performance Benchmark ($rowsString rows)\n');
  print(
    [
      'This benchmark measures the performance impact of using CRDT ',
      'metadata synchronization on database operations.',
    ].join(runningInCI ? '' : '\n'),
  );
  if (!runningInCI) print('-' * 60);

  final benchmarkResults = <BenchmarkResults>[];

  for (final operation in Operation.values) {
    final baselineResult = await runWithProgress(
      'Running ${operation.name} benchmark (baseline)',
      () => TypesTableBenchmark(
        '${operation.name} (baseline)',
        crdtEnabled: false,
        operation: operation,
        rowCount: rowCount,
      ).measure(),
      skipProgress: runningInCI,
    );

    final crdtResult = await runWithProgress(
      'Running ${operation.name} benchmark (CRDT)',
      () => TypesTableBenchmark(
        '${operation.name} (CRDT)',
        crdtEnabled: true,
        operation: operation,
        rowCount: rowCount,
      ).measure(),
      validator: (result) => result > baselineResult,
      skipProgress: runningInCI,
    );

    benchmarkResults.add(
      BenchmarkResults(
        operation: operation,
        baseline: baselineResult,
        crdt: crdtResult,
      ),
    );
  }

  final spuriousBenchmarks = benchmarkResults.where(
    (result) => result.baseline > result.crdt,
  );

  if (spuriousBenchmarks.isNotEmpty) {
    final leadingText = runningInCI ? '\n> ' : '\n';
    print(
      [
        '$leadingText❌ Baseline time is greater than CRDT time. This is likely due ',
        'to running with a very low number of rows ($rowsString). This is not ',
        ' a valid benchmark and the time comparison should be ignored.',
      ].join(runningInCI ? '' : '\n'),
    );

    for (final result in spuriousBenchmarks) {
      final baselineDelay = result.baseline.toFormattedDuration();
      final crdtDelay = result.crdt.toFormattedDuration();
      print(
        '  - ${result.operation.name.toUpperCase()}: $baselineDelay > $crdtDelay',
      );
    }
  }

  for (final result in benchmarkResults) {
    printPerformanceImpact(
      result,
      rowCount: rowCount,
      runningInCI: runningInCI,
    );
  }
  final baselineStorageResult = await runWithProgress(
    'Running storage benchmark (baseline)',
    () => TypesTableStorageBenchmark(
      'storage (baseline)',
      crdtEnabled: false,
      rowCount: rowCount,
    ).reportStorage(),
    skipProgress: runningInCI,
  );
  final crdtStorageResult = await runWithProgress(
    'Running storage benchmark (CRDT)',
    () => TypesTableStorageBenchmark(
      'storage (CRDT)',
      crdtEnabled: true,
      rowCount: rowCount,
    ).reportStorage(),
    skipProgress: runningInCI,
  );
  printStorageImpact(
    StorageBenchmarkResults(
      baseline: baselineStorageResult,
      crdt: crdtStorageResult,
    ),
    rowCount: rowCount,
    runningInCI: runningInCI,
  );

  print('\n${'-' * 60}');
  print('✅ Benchmark complete!\n');
}
