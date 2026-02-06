import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart';

/// Sets the test executor for the SQLite3 database.
///
/// This is a file-based SQLite3 executor that is used for testing. It follows
/// the same pattern as the `test_descriptor` package to ensure one executor is
/// created for each test. The executor is closed once test ends.
///
/// After setting the test executor, the database can be accessed using the
/// [testExecutor] getter.
void setTestFileExecutor([String fileName = 'test.db']) {
  final databaseFile = file(fileName);
  final sqliteDatabase = sqlite3.open(databaseFile.io.path);
  final executor = NativeDatabase.opened(sqliteDatabase);
  _setTestExecutor(executor);
}

/// The test executor for the SQLite3 database.
///
/// This is a memory-based SQLite3 executor that is used for testing. It follows
/// the same pattern as the `test_descriptor` package to ensure one executor is
/// created for each test. The executor is closed once test ends.
NativeDatabase get testExecutor {
  if (_testExecutor != null) return _testExecutor!;
  final executor = NativeDatabase.memory();
  _setTestExecutor(executor);
  return executor;
}

NativeDatabase? _testExecutor;

void _setTestExecutor(NativeDatabase executor) {
  _testExecutor = executor;

  addTearDown(() async {
    final executor = _testExecutor;
    if (executor == null) return;
    _testExecutor = null;
    await executor.close();
  });
}
