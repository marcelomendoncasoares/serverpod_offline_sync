import 'dart:io';

import 'conversion.dart';
import 'results.dart';

/// Collects the benchmark output in the same format as the CI output.
String collectBenchmarkOutput(
  List<BenchmarkResults> benchmarkResults,
  int rowCount,
) {
  final buffer = StringBuffer();
  final rowsString = formatter0.format(rowCount);

  buffer
    ..writeln('## Performance Benchmark ($rowsString rows)\n')
    ..write(
      [
        'This benchmark measures the performance impact of using CRDT ',
        'synchronization on database operations.',
      ].join(''),
    );

  final spuriousBenchmarks = benchmarkResults.where(
    (result) => result.baseline.$1 > result.crdt.$1,
  );

  if (spuriousBenchmarks.isNotEmpty) {
    buffer.write(
      [
        '\n> ',
        '❌ Baseline time is greater than CRDT time. This is likely due ',
        'to running with a very low number of rows ($rowsString). This is not ',
        ' a valid benchmark and the time comparison should be ignored.',
      ].join(''),
    );

    for (final result in spuriousBenchmarks) {
      final baselineDelay = result.baseline.$1.toFormattedDuration();
      final crdtDelay = result.crdt.$1.toFormattedDuration();
      buffer.write(
        '\n  - ${result.operation.name.toUpperCase()}: $baselineDelay > $crdtDelay',
      );
    }
  }

  for (final result in benchmarkResults) {
    buffer
      ..write('\n')
      ..write(_formatPerformanceImpact(result, rowCount: rowCount));
  }

  buffer
    ..write('\n')
    ..write(_formatStorageImpact(benchmarkResults.first, rowCount: rowCount))
    ..writeln('\n\n${'-' * 60}')
    ..writeln('✅ Benchmark complete!');

  return buffer.toString();
}

String _formatPerformanceImpact(
  BenchmarkResults benchmarkResults, {
  required int rowCount,
}) {
  final (baselineTime, _) = benchmarkResults.baseline;
  final (crdtTime, _) = benchmarkResults.crdt;

  final runDelayUs = crdtTime - baselineTime;
  final slowdown = runDelayUs / baselineTime * 100;

  final baselineDelay = baselineTime.toFormattedDuration();
  final crdtDelay = crdtTime.toFormattedDuration();
  final runDelay = runDelayUs.toFormattedDuration();
  final runDelayPerOperation = (runDelayUs / rowCount).toFormattedDuration();

  final buffer = StringBuffer()
    ..writeln('```')
    ..writeln(
      '📊 ${benchmarkResults.operation.name.toUpperCase()} performance impact:',
    )
    ..writeln('  Time: $baselineDelay --> $crdtDelay ($runDelay)')
    ..writeln('  CRDT overhead: ${formatter2.format(slowdown)}% slower')
    ..writeln(
      '  Delay per ${benchmarkResults.operation.name}: $runDelayPerOperation',
    )
    ..writeln('```');

  return buffer.toString();
}

String _formatStorageImpact(
  BenchmarkResults benchmarkResults, {
  required int rowCount,
}) {
  final (_, baselineSize) = benchmarkResults.baseline;
  final (_, crdtSize) = benchmarkResults.crdt;

  final storageIncrease = crdtSize - baselineSize;
  final storageIncPercent = storageIncrease / baselineSize * 100;
  final extraStoragePerRow = storageIncrease / rowCount;
  final storageIncreaseVolume = storageIncPercent > 100
      ? '(x${formatter2.format(storageIncPercent / 100)})'
      : '(+${(crdtSize - baselineSize).toFormattedStorageSize()})';

  final buffer = StringBuffer()
    ..writeln('```')
    ..writeln('💽 Storage impact:')
    ..write(
      '  Storage size: ${baselineSize.toFormattedStorageSize()} '
      '--> ${crdtSize.toFormattedStorageSize()} $storageIncreaseVolume\n',
    )
    ..writeln('  CRDT overhead: ${formatter2.format(storageIncPercent)}% increase')
    ..writeln(
      '  Extra storage per row: ${extraStoragePerRow.toFormattedStorageSize()}',
    )
    ..writeln('```');

  return buffer.toString();
}

/// Stores the benchmark output in git notes under the 'benchmarks' namespace.
Future<bool> storeBenchmarkInGitNotes(String output) async {
  try {
    // Get the current commit SHA
    final commitResult = await Process.run(
      'git',
      ['rev-parse', 'HEAD'],
      runInShell: true,
    );

    if (commitResult.exitCode != 0) {
      stderr.writeln('Failed to get current commit SHA: ${commitResult.stderr}');
      return false;
    }

    final commitSha = (commitResult.stdout as String).trim();

    // Store the benchmark output as a git note
    final notesResult = await Process.run(
      'git',
      ['notes', '--ref=benchmarks', 'add', '-f', '-m', output, commitSha],
      runInShell: true,
    );

    if (notesResult.exitCode != 0) {
      stderr.writeln('Failed to add git note: ${notesResult.stderr}');
      return false;
    }

    return true;
  } on Exception catch (e) {
    stderr.writeln('Error storing benchmark in git notes: $e');
    return false;
  }
}
