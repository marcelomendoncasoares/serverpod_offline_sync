// Keeps CRDT scope aligned with integration tests plus the benchmark table.

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

/// [Types] is benchmark-only; the rest mirrors `client_session.dart` sync scope.
List<Table> get benchmarkSyncTables => [
  Address.t,
  City.t,
  Company.t,
  Organization.t,
  Person.t,
  Town.t,
  Types.t,
  Unique.t,
  UniqueUuid.t,
];

Future<void> clearUserTables(DatabaseSession session) async {
  await session.db.unsafeExecute('PRAGMA foreign_keys = OFF');
  final result = await session.db.unsafeQuery('''
    SELECT name
    FROM sqlite_master
    WHERE (type = 'table') AND (name NOT LIKE 'serverpod_%')
''');
  for (final row in result) {
    final tableName = row[0] as String;
    await session.db.unsafeExecute('DELETE FROM "$tableName"');
  }
  await session.db.unsafeExecute('PRAGMA foreign_keys = ON');
}
