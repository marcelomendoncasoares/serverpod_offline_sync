import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  final syncTables = [server.Person.t, server.Address.t];

  withServerpod(
    'Given a Serverpod with CRDT sync initialized and its database interceptor,',
    databaseInterceptor: offlineSyncDatabaseInterceptor,
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      sessionBuilder.build().serverpod.initializeOfflineSync(
        syncTables: syncTables,
      );

      test(
        'when the CRDT database is resolved from the session, '
        'then the interceptor-wrapped instance is returned.',
        () {
          final session = sessionBuilder.build();

          expect(session.offlineSyncDb, isA<OfflineSyncDatabase>());
        },
      );

      test(
        'when a synced row is written through transactionForUser, '
        'then it is readable from the session it was written with.',
        () async {
          final session = sessionBuilder.build();
          final userId = const Uuid().v7obj();
          final personId = const Uuid().v7obj();

          await session.offlineSyncDb.transactionForUser(userId, (tx) async {
            await server.Person.db.insertRow(
              session,
              server.Person(id: personId, name: 'server-person'),
              transaction: tx,
            );
          });

          final person = await server.Person.db.findById(session, personId);

          expect(person, isNotNull);
          expect(person!.name, 'server-person');
        },
      );
    },
  );

  withServerpod(
    'Given a Serverpod without the CRDT database interceptor,',
    (sessionBuilder, _) {
      sessionBuilder.build().serverpod.initializeOfflineSync(
        syncTables: syncTables,
      );

      test(
        'when the CRDT database is resolved from the session, '
        'then a StateError is thrown.',
        () {
          final session = sessionBuilder.build();

          expect(() => session.offlineSyncDb, throwsStateError);
        },
      );
    },
  );
}
