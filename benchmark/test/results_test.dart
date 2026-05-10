import 'dart:async';

import 'package:test/test.dart';

import '../utils/benchmark.dart';
import '../utils/results.dart';

void main() {
  test(
    'Given benchmark operations when iterating values then SELECT is the first section.',
    () {
      expect(Operation.values.first, Operation.select);
    },
  );

  test(
    'Given SELECT benchmark results when printing performance impact then output reports selected rows.',
    () {
      final output = _capturePrintOutput(() {
        printPerformanceImpact(
          const BenchmarkResults(
            operation: Operation.select,
            baseline: 1000,
            crdt: 2000,
          ),
          rowCount: 10,
        );
      });

      expect(output, contains('📊 SELECT performance impact:'));
      expect(output, contains('Delay per selected row:'));
    },
  );
}

String _capturePrintOutput(void Function() callback) {
  final lines = <String>[];

  runZoned(
    callback,
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, line) => lines.add(line),
    ),
  );

  return lines.join('\n');
}
