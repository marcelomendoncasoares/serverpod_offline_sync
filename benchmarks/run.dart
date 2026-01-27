import 'utils/benchmark.dart';
import 'utils/conversion.dart';
import 'utils/results.dart';
import 'utils/runner.dart';

Future<void> main() async {
  final rowsString = formatter0.format(rowCount);

  print('\n${'=' * 60}');
  print('Performance Benchmark ($rowsString rows)\n');
  print('This benchmark measures the performance impact of using CRDT');
  print('synchronization on database operations.');
  print('-' * 60);

  final benchmarkResults = <BenchmarkResults>[];

  for (final operation in Operation.values) {
    final baselineResult = await runWithProgress(
      'Running ${operation.name} benchmark (baseline)',
      CrdtBenchmark(
        '${operation.name} (baseline)',
        crdtEnabled: false,
        operation: operation,
      ).report,
    );

    final crdtResult = await runWithProgress(
      'Running ${operation.name} benchmark (CRDT)',
      CrdtBenchmark(
        '${operation.name} (CRDT)',
        crdtEnabled: true,
        operation: operation,
      ).report,
      validator: (result) => result.$1 > baselineResult.$1,
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
    (result) => result.baseline.$1 > result.crdt.$1,
  );

  if (spuriousBenchmarks.isNotEmpty) {
    print(
      '''
\n❌ Baseline time is greater than CRDT time. This is likely due
to running with a very low number of rows ($rowsString). This is not
a valid benchmark and the time comparison should be ignored.''',
    );

    for (final result in spuriousBenchmarks) {
      final baselineDelay = result.baseline.$1.toFormattedDuration();
      final crdtDelay = result.crdt.$1.toFormattedDuration();
      print('  - ${result.operation.name.toUpperCase()}: $baselineDelay > $crdtDelay');
    }
  }

  benchmarkResults.forEach(printPerformanceImpact);
  printStorageImpact(benchmarkResults.first);

  print('\n${'-' * 60}');
  print('✅ Benchmark complete!');
  print('${'=' * 60}\n');
}
