import 'dart:io';

import 'utils/benchmark.dart';
import 'utils/conversion.dart';
import 'utils/git_notes.dart';
import 'utils/results.dart';
import 'utils/runner.dart';

Future<void> main(List<String> args) async {
  final runningInCI = args.contains('--ci');
  final storeInGitNotes = args.contains('--store-in-git-notes');
  final rowCountArg = args.where((arg) => arg.startsWith('--rows=')).firstOrNull;
  final rowCount = rowCountArg == null ? 1000 : int.parse(rowCountArg.substring(7));
  final rowsString = formatter0.format(rowCount);

  if (!runningInCI) print('\n${'=' * 60}');
  print('## Performance Benchmark ($rowsString rows)\n');
  print(
    [
      'This benchmark measures the performance impact of using CRDT ',
      'synchronization on database operations.',
    ].join(runningInCI ? '' : '\n'),
  );
  if (!runningInCI) print('-' * 60);

  final benchmarkResults = <BenchmarkResults>[];

  for (final operation in Operation.values) {
    final baselineResult = await runWithProgress(
      'Running ${operation.name} benchmark (baseline)',
      CrdtBenchmark(
        '${operation.name} (baseline)',
        crdtEnabled: false,
        operation: operation,
        rowCount: rowCount,
      ).report,
      skipProgress: runningInCI,
    );

    final crdtResult = await runWithProgress(
      'Running ${operation.name} benchmark (CRDT)',
      CrdtBenchmark(
        '${operation.name} (CRDT)',
        crdtEnabled: true,
        operation: operation,
        rowCount: rowCount,
      ).report,
      validator: (result) => result.$1 > baselineResult.$1,
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
    (result) => result.baseline.$1 > result.crdt.$1,
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
      final baselineDelay = result.baseline.$1.toFormattedDuration();
      final crdtDelay = result.crdt.$1.toFormattedDuration();
      print('  - ${result.operation.name.toUpperCase()}: $baselineDelay > $crdtDelay');
    }
  }

  for (final result in benchmarkResults) {
    printPerformanceImpact(
      result,
      rowCount: rowCount,
      runningInCI: runningInCI,
    );
  }
  printStorageImpact(
    benchmarkResults.first,
    rowCount: rowCount,
    runningInCI: runningInCI,
  );

  print('\n${'-' * 60}');
  print('✅ Benchmark complete!\n');

  if (storeInGitNotes) {
    print('Storing benchmark results in git notes...');
    final output = collectBenchmarkOutput(benchmarkResults, rowCount);
    final success = await storeBenchmarkInGitNotes(output);
    if (success) {
      print('✅ Benchmark results stored in git notes successfully!');
    } else {
      print('❌ Failed to store benchmark results in git notes.');
      exit(1);
    }
  }
}
