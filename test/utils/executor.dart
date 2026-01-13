import 'package:drift/native.dart';
import 'package:drift_offline_first/src/setup.dart';
import 'package:test/test.dart';

/// The test executor for the SQLite3 database.
///
/// This is a memory-based SQLite3 executor that is used for testing. It follows
/// the same pattern as the `test_descriptor` package to ensure one executor is
/// created for each test. The executor is closed once test ends.
NativeDatabase get testExecutor {
  if (_testExecutor != null) return _testExecutor!;
  final executor = NativeDatabase.memory(setup: registerHlcFunction);
  _testExecutor = executor;

  addTearDown(() async {
    final executor = _testExecutor!;
    _testExecutor = null;
    await executor.close();
  });

  return executor;
}

NativeDatabase? _testExecutor;
