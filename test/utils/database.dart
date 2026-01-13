import 'package:test/test.dart';

import 'executor.dart';
import 'tables.dart';

export 'tables.dart' show TodoDb;

/// The test database for the SQLite3 database.
///
/// This is a memory-based SQLite3 database that is used for testing. It follows
/// the same pattern as the `test_descriptor` package to ensure one database is
/// created for each test. The database is closed once test ends.
TodoDb get database {
  if (_database != null) return _database!;

  final database = TodoDb(testExecutor);
  _database = database;

  addTearDown(() async {
    final database = _database!;
    _database = null;
    await database.close();
  });

  return database;
}

TodoDb? _database;
