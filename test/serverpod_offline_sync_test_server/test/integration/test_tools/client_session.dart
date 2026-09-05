import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

const _clientUrl = 'http://localhost:8081/';

/// The tables every test registers for synchronization.
///
/// This is the generated `database: sync` list so it stays complete: the
/// registry validates the whole set at `initialize()`, and a synced table may
/// not reference a table outside the set.
final testSyncTables = syncTables;

late Client _testClient;
late ClientDatabaseSession _testSession;
late CrdtDatabaseSession _crdtSession;
late Directory _tempDir;
late String _templatePath;
late UuidValue _testCrdtUserId;
var _databaseCount = 0;

/// A fresh [ClientDatabaseSession] for each test that is automatically closed
/// and removed once no longer needed.
ClientDatabaseSession get testSession => _testSession;

/// A fresh [CrdtDatabaseSession] for each test that is automatically closed
/// and removed once no longer needed.
CrdtDatabaseSession get session => _crdtSession;

/// The test CRDT user ID.
UuidValue get testCrdtUserId => _testCrdtUserId;

/// Gives every test its own [ClientDatabaseSession] on its own SQLite file,
/// so tests do not need a [tearDown].
///
/// Migrating and verifying a new database costs well over half a second, so
/// doing that once per test dominates a suite. Clearing a shared database
/// between tests is fast but not a fresh database: `sqlite_sequence`,
/// connection state, and anything the engine caches on the session survive.
/// The template gives both. It is migrated and verified once per file, and
/// each test opens a copy of that file with migrations disabled, which is a
/// few milliseconds.
///
/// When [withPersistentUser] is true, [testCrdtUserId] is passed as
/// [CrdtDatabaseSession]'s `persistentUserId` so mutations can use plain
/// [Database.transaction] instead of [CrdtDatabase.transactionForUser] (client
/// mode).
///
/// Nothing is assigned while this function runs: it only registers callbacks.
/// [withPersistentUser] is captured by them rather than stored in a top-level
/// field, because a runner that separates test registration from test execution
/// does not carry state written during registration into the run.
void initTestClientSession({bool withPersistentUser = false}) {
  setUpAll(() async {
    _tempDir = await Directory.systemTemp.createTemp('offline_first_');
    _testClient = Client(_clientUrl);
    _templatePath = p.join(_tempDir.path, 'template.db');
    final template = await _testClient.createSession(
      _templatePath,
      isDebugMode: true,
    );
    await template.close();
  });

  late String path;
  setUp(() async {
    _testCrdtUserId = const Uuid().v7obj();
    path = await _nextDatabasePath();
    _testSession = await _openDatabase(path);
    _crdtSession = CrdtDatabaseSession.wraps(
      _testSession,
      syncTables: testSyncTables,
      persistentUserId: withPersistentUser ? _testCrdtUserId : null,
    );
    await _crdtSession.db.initialize();
  });

  // Registered here rather than with `addTearDown` in `setUp`, because
  // `addTearDown` callbacks run before every `tearDown`, including the ones a
  // test file registers after calling this function - and those still expect
  // an open session.
  tearDown(() async {
    await _testSession.close();
    await _deleteDatabase(path);
  });

  tearDownAll(() async {
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
  });
}

/// Opens a fresh client database session on a copy of the migrated template,
/// closing it and removing its files when the current test completes.
///
/// The files are deleted rather than left for the directory-wide teardown
/// because a simulation sweep creates several databases per seed, and they
/// would otherwise all stay resident for the whole suite.
Future<ClientDatabaseSession> createAdditionalTestSession() async {
  final path = await _nextDatabasePath();
  final additionalSession = await _openDatabase(path);
  addTearDown(() async {
    await additionalSession.close();
    await _deleteDatabase(path);
  });
  return additionalSession;
}

/// Reserves a database path in the test directory and puts a copy of the
/// template there.
Future<String> _nextDatabasePath() async {
  final path = p.join(_tempDir.path, 'test-${++_databaseCount}.db');
  await _copyDatabase(_templatePath, path);
  return path;
}

/// Opens a copied template. Migrations are skipped: the template has them.
Future<ClientDatabaseSession> _openDatabase(String path) =>
    _testClient.createSession(path, runMigrations: false);

const _databaseFileSuffixes = ['', '-wal', '-shm'];

/// Copies the SQLite database at [from] to [to].
///
/// The template is closed, so its write-ahead log is normally checkpointed and
/// gone. It is copied along if it is still there, because SQLite replays it on
/// open; the shared-memory index is never copied, since it is rebuilt.
Future<void> _copyDatabase(String from, String to) async {
  for (final suffix in const ['', '-wal']) {
    final file = File('$from$suffix');
    if (file.existsSync()) await file.copy('$to$suffix');
  }
}

Future<void> _deleteDatabase(String path) async {
  for (final suffix in _databaseFileSuffixes) {
    final file = File('$path$suffix');
    if (file.existsSync()) await file.delete();
  }
}

extension ClearDatabaseTables on DatabaseSession {
  /// Clears all user tables from the database.
  Future<void> clearUserTables() async {
    await db.unsafeExecute('PRAGMA foreign_keys = OFF');
    final result = await db.unsafeQuery('''
    SELECT name
    FROM sqlite_master
    WHERE (type = 'table') AND (name NOT LIKE 'serverpod_%')
''');

    for (final row in result) {
      final tableName = row[0] as String;
      await db.unsafeExecute('DELETE FROM "$tableName"');
    }

    await db.unsafeExecute('PRAGMA foreign_keys = ON');
  }
}
