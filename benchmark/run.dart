import 'utils/benchmark.dart';
import 'utils/conversion.dart';
import 'utils/merge.dart';
import 'utils/results.dart';
import 'utils/runner.dart';
import 'utils/space.dart';

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
      'Running ${operation.label} benchmark (baseline)',
      () => TypesTableBenchmark(
        '${operation.label} (baseline)',
        crdtEnabled: false,
        operation: operation,
        rowCount: rowCount,
      ).measure(),
      skipProgress: runningInCI,
    );

    final crdtResult = await runWithProgress(
      'Running ${operation.label} benchmark (CRDT)',
      () => TypesTableBenchmark(
        '${operation.label} (CRDT)',
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
        offlineSync: crdtResult,
      ),
    );
  }

  final spuriousBenchmarks = benchmarkResults.where(
    (result) => result.baseline > result.offlineSync,
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
      final crdtDelay = result.offlineSync.toFormattedDuration();
      print(
        '  - ${result.operation.label.toUpperCase()}: $baselineDelay > $crdtDelay',
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

  // Production-shaped CRDT metadata: many users and a crdt_data_rows table
  // much larger than the queried rows, exercising the scoped and unscoped
  // tombstone predicates.
  const spaceNoiseUsers = 100;
  final spaceNoiseCrdtRows = rowCount * 100;
  final spaceMeasurements = <SpaceMode, SpaceMeasurement>{};
  for (final spaceMode in SpaceMode.values) {
    spaceMeasurements[spaceMode] = await runWithProgress(
      'Running select space benchmark (${spaceMode.name})',
      () => TombstoneSpaceBenchmark(
        'select space (${spaceMode.name})',
        mode: spaceMode,
        rowCount: rowCount,
        noiseUsers: spaceNoiseUsers,
        noiseCrdtRows: spaceNoiseCrdtRows,
      ).measure(),
      skipProgress: runningInCI,
    );
  }
  printSpaceImpact(
    SpaceBenchmarkResults(
      baseline: spaceMeasurements[SpaceMode.baseline]!,
      spaceScoped: spaceMeasurements[SpaceMode.spaceScoped]!,
      unscoped: spaceMeasurements[SpaceMode.unscoped]!,
      noiseUsers: spaceNoiseUsers,
      noiseCrdtRows: spaceNoiseCrdtRows,
    ),
    rowCount: rowCount,
    runningInCI: runningInCI,
  );

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
      offlineSync: crdtStorageResult,
    ),
    rowCount: rowCount,
    runningInCI: runningInCI,
  );

  if (!runningInCI) print('\n${'=' * 60}');
  print('\n## Merge Benchmark ($rowsString changes)\n');
  print(
    [
      'This benchmark measures the time to apply remote CRDT changes to ',
      'the local database through the sync merge path.',
    ].join(runningInCI ? '' : '\n'),
  );
  if (!runningInCI) print('-' * 60);

  final mergeBenchmarks = <MergeScenarioBenchmark>[
    for (final operation in MergeOperation.values)
      TypesMergeBenchmark(
        'merge (${operation.name})',
        operation: operation,
        changeCount: rowCount,
      ),
    UniqueMergeBenchmark('merge (unique conflict)', changeCount: rowCount),
    for (final operation in SetDefaultOperation.values)
      SetDefaultMergeBenchmark(
        'merge (set default ${operation.name})',
        operation: operation,
        pairCount: rowCount < 1 ? 1 : rowCount,
      ),
    for (final operation in FkChainOperation.values)
      FkChainMergeBenchmark(
        'merge (fk chain ${operation.name})',
        operation: operation,
        changeCount: rowCount,
      ),
  ];

  for (final benchmark in mergeBenchmarks) {
    final mergeResult = await runWithProgress(
      'Running ${benchmark.name} benchmark',
      benchmark.measureMerge,
      skipProgress: runningInCI,
    );

    printMergeImpact(
      MergeBenchmarkResults(
        title: benchmark.resultTitle,
        batchDescription: benchmark.batchDescription,
        average: mergeResult.averageMicroseconds,
        averageQueries: mergeResult.averageQueries,
        averageRowsRead: mergeResult.averageRowsRead,
        averageRowsReadByType: mergeResult.averageRowsReadByType,
        changeCount: benchmark.changesPerBatch,
      ),
      runningInCI: runningInCI,
    );
  }

  print('\n${'-' * 60}');
  print('✅ Benchmark complete!\n');
}
