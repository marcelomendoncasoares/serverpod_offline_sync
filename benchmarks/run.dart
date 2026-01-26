import 'insert_benchmark.dart';

Future<void> main() async {
  print('Running drift_offline_first benchmarks...\n');
  print('This benchmark measures the performance impact of using CRDT');
  print('synchronization on database operations.\n');

  print('=' * 60);
  print('Insert Performance Benchmark (10,000 rows)');
  print('=' * 60);

  print('\nRunning baseline (without CRDT)...');
  final baselineTime = await runInsertBenchmark(BaselineInsertBenchmark());
  print('  Time: ${baselineTime / 1000}s');

  print('\nRunning with CRDT enabled...');
  final crdtTime = await runInsertBenchmark(CrdtInsertBenchmark());
  print('  Time: ${crdtTime / 1000}s');

  final slowdown = (crdtTime - baselineTime) / baselineTime * 100;
  print('\n📊 Performance Impact:');
  print('  CRDT overhead: ${slowdown.toStringAsFixed(2)}% slower');
  print('  Delay per insert: ${((crdtTime - baselineTime) / 10000).toStringAsFixed(3)}ms');

  print('\n${'=' * 60}');
  print('Storage Overhead Benchmark (10,000 rows)');
  print('=' * 60);

  print('\nMeasuring baseline storage (without CRDT)...');
  final baselineSize = await runStorageBenchmark(BaselineStorageBenchmark());
  print('  Database size: ${(baselineSize / 1024).toStringAsFixed(2)} KB');

  print('\nMeasuring with CRDT enabled...');
  final crdtSize = await runStorageBenchmark(CrdtStorageBenchmark());
  print('  Database size: ${(crdtSize / 1024).toStringAsFixed(2)} KB');

  final overhead = (crdtSize - baselineSize) / baselineSize * 100;
  print('\n📊 Storage Impact:');
  print('  CRDT overhead: ${(crdtSize - baselineSize) / 1024} KB');
  print('  Storage increase: ${overhead.toStringAsFixed(2)}%');

  print('\n${'=' * 60}');
  print('Benchmark complete!');
  print('=' * 60);
}

Future<int> runInsertBenchmark(dynamic benchmark) async {
  await benchmark.setup();
  final stopwatch = Stopwatch()..start();
  await benchmark.run();
  stopwatch.stop();
  await benchmark.teardown();
  return stopwatch.elapsedMilliseconds;
}

Future<int> runStorageBenchmark(dynamic benchmark) async {
  await benchmark.setup();
  final size = benchmark.measure() as int;
  await benchmark.teardown();
  return size;
}
