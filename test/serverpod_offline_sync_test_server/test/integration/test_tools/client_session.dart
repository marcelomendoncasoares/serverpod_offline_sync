import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

const _clientUrl = 'http://localhost:8081/';

late Client _testClient;
late ClientDatabaseSession _testSession;
late CrdtDatabaseSession _crdtSession;
late Directory _tempDir;
late UuidValue _testCrdtUserId;
late bool _withPersistentUser;

/// A fresh [ClientDatabaseSession] for each test that is automatically closed
/// and removed once no longer needed.
ClientDatabaseSession get testSession => _testSession;

/// A fresh [CrdtDatabaseSession] for each test that is automatically closed
/// and removed once no longer needed.
CrdtDatabaseSession get session => _crdtSession;

/// The test CRDT user ID.
UuidValue get testCrdtUserId => _testCrdtUserId;

/// Initialize one [ClientDatabaseSession] for each test whole file to avoid a
/// slower operation of creating one file per test. The isolation is ensured by
/// a cleanup of all tables after each test. This means that tests do not need
/// a [tearDown].
///
/// When [withPersistentUser] is true, [testCrdtUserId] is passed as
/// [CrdtDatabaseSession]'s `persistentUserId` so mutations can use plain
/// [Database.transaction] instead of [CrdtDatabase.transactionForUser] (client
/// mode).
void initTestClientSession({bool withPersistentUser = false}) {
  _withPersistentUser = withPersistentUser;

  setUpAll(() async {
    _tempDir = await Directory.systemTemp.createTemp('offline_first_');
    _testClient = Client(_clientUrl);
    _testSession = await _testClient.createSession(
      p.join(_tempDir.path, 'test.db'),
      isDebugMode: true,
    );

    _testCrdtUserId = const Uuid().v7obj();
    await _initialize();
  });

  tearDown(() async {
    await _testSession.clearUserTables();
    await _initialize();
  });

  tearDownAll(() async {
    await _testSession.close();
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
  });
}

Future<void> _initialize() async {
  _crdtSession = CrdtDatabaseSession.wraps(
    testSession,
    syncTables: [
      Address.t,
      City.t,
      Company.t,
      Organization.t,
      Person.t,
      Town.t,
      Unique.t,
      UniqueUuid.t,
    ],
    persistentUserId: _withPersistentUser ? _testCrdtUserId : null,
  );

  await _crdtSession.db.initialize();
}

extension ClearDatabaseTables on DatabaseSession {
  /// Clears all user tables from the database for tests teardown.
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
