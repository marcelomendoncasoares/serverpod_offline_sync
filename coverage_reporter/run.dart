import 'dart:io';

Future<void> main(List<String> args) async {
  final runningInCI = args.contains('--ci');
  final lcovFile = File('coverage/lcov.info');

  if (!lcovFile.existsSync()) {
    stderr.writeln('Error: coverage/lcov.info not found');
    exit(1);
  }

  final coverage = _parseLcov(lcovFile.readAsStringSync());
  final totalLines = coverage['total_lines'] as int;
  final coveredLines = coverage['covered_lines'] as int;
  final percentage = (coveredLines / totalLines * 100).toStringAsFixed(2);

  if (!runningInCI) print('\n${'=' * 60}');
  print('## Test Coverage Report\n');
  print(
    [
      'This report shows the test coverage for the project.',
    ].join(runningInCI ? '' : '\n'),
  );
  if (!runningInCI) print('-' * 60);
  print('');
  print('**Total Coverage: $percentage%**');
  print('');
  print('- Lines covered: $coveredLines / $totalLines');
  print('');

  // Print per-file coverage
  final files = coverage['files'] as Map<String, Map<String, int>>;
  if (files.isNotEmpty) {
    print('### File Coverage\n');
    final sortedFiles = files.entries.toList()
      ..sort((a, b) {
        final aPercent = a.value['covered']! / a.value['total']!;
        final bPercent = b.value['covered']! / b.value['total']!;
        return bPercent.compareTo(aPercent);
      });

    for (final entry in sortedFiles) {
      final fileName = entry.key.split('/').last;
      final covered = entry.value['covered']!;
      final total = entry.value['total']!;
      final filePercentage = (covered / total * 100).toStringAsFixed(1);
      print('- `$fileName`: $filePercentage% ($covered/$total lines)');
    }
  }

  if (!runningInCI) print('\n${'=' * 60}\n');
}

Map<String, dynamic> _parseLcov(String lcovContent) {
  final lines = lcovContent.split('\n');
  var totalLines = 0;
  var coveredLines = 0;
  final files = <String, Map<String, int>>{};

  String? currentFile;
  var currentFileLines = 0;
  var currentFileCovered = 0;

  for (final line in lines) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      currentFileLines = 0;
      currentFileCovered = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        final hits = int.tryParse(parts[1]) ?? 0;
        currentFileLines++;
        if (hits > 0) {
          currentFileCovered++;
        }
      }
    } else if (line == 'end_of_record' && currentFile != null) {
      totalLines += currentFileLines;
      coveredLines += currentFileCovered;
      files[currentFile] = {
        'total': currentFileLines,
        'covered': currentFileCovered,
      };
      currentFile = null;
    }
  }

  return {
    'total_lines': totalLines,
    'covered_lines': coveredLines,
    'files': files,
  };
}
