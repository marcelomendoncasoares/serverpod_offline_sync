import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as model;

Future<void> main() async {
  DatabasePoolManager? pool;
  OfflineSyncDatabaseSession? session;
  try {
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final command = jsonDecode(line) as Map<String, dynamic>;
      try {
        switch (command['action']) {
          case 'open':
            final config = PostgresDatabaseConfig(
              host: command['host'] as String,
              port: command['port'] as int,
              user: command['user'] as String,
              password: command['password'] as String,
              name: command['name'] as String,
              isUnixSocket: command['isUnixSocket'] as bool,
              maxConnectionCount: 4,
            );
            pool = DatabaseProvider.forDialect(
              DatabaseDialect.postgres,
            ).createPoolManager(model.Protocol(), null, config);
            await pool.started;
            session = OfflineSyncDatabaseSession.wraps(
              _PeerSession(pool),
              syncTables: model.syncTables,
            );
            await session.db.initialize();
            _reply({'pid': pid});
          case 'read':
            final user = UuidValue.fromString(command['userUuid'] as String);
            final rows = await session!.db.transactionForUser(
              user,
              (tx) => model.Person.db.find(session!, transaction: tx),
            );
            _reply({
              'names': [for (final row in rows) row.name],
            });
          case 'grant':
            final space = UuidValue.fromString(command['spaceUuid'] as String);
            final user = UuidValue.fromString(command['userUuid'] as String);
            final spaceRow = await OfflineSyncSpace.db.findFirstRow(
              session!,
              where: (t) => t.uuidSpaceId.equals(space),
            );
            await OfflineSyncSpaceMember.db.upsert(
              session,
              [
                OfflineSyncSpaceMember(
                  spaceId: spaceRow!.id!,
                  userUuid: user,
                  role: OfflineSyncSpaceRole.readOnly,
                ),
              ],
              conflictColumns: (t) => [t.userUuid, t.spaceId],
              updateColumns: (t) => [t.role],
            );
            _reply({'committed': true});
          case 'revoke':
            final space = UuidValue.fromString(command['spaceUuid'] as String);
            final user = UuidValue.fromString(command['userUuid'] as String);
            await OfflineSyncSpaceMember.db.deleteWhere(
              session!,
              where: (t) => t.userUuid.equals(user) & t.space.uuidSpaceId.equals(space),
            );
            _reply({'committed': true});
          case 'close':
            _reply({'closed': true});
            return;
          default:
            throw StateError('Unknown peer command.');
        }
      } on Object catch (error, stack) {
        _reply({'error': '$error', 'stack': '$stack'});
      }
    }
  } finally {
    await pool?.stop();
  }
}

void _reply(Map<String, Object?> message) => stdout.writeln(jsonEncode(message));

class _PeerSession implements DatabaseSession {
  _PeerSession(DatabasePoolManager pool) {
    db = DatabaseConstructor.create(session: this, poolManager: pool);
  }

  @override
  late final Database db;

  @override
  Transaction? transaction;

  @override
  LogQueryFunction? get logQuery => null;

  @override
  LogWarningFunction? get logWarning => null;
}
