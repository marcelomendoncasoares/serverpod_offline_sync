import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  final syncTables = [server.Person.t, server.Address.t];

  withServerpod(
    'Given a Serverpod with CRDT sync initialized,',
    (sessionBuilder, _) {
      final session = sessionBuilder.build();
      session.serverpod.initializeCrdtSync(syncTables: syncTables);

      test(
        'when the database interceptor wraps a session database, '
        'then it returns a CRDT-aware database.',
        () {
          final wrapped = crdtDatabaseInterceptor(session, session.db);
          expect(wrapped, isA<CrdtDatabase>());
        },
      );

      test(
        'when the database interceptor wraps an already-wrapped database, '
        'then it returns the same instance.',
        () {
          final wrapped = crdtDatabaseInterceptor(session, session.db);
          final reWrapped = crdtDatabaseInterceptor(session, wrapped);
          expect(identical(reWrapped, wrapped), isTrue);
        },
      );

      test(
        'when resolving the CRDT sync for the pod, '
        'then the configured instance is returned.',
        () {
          expect(crdtSyncForServerpod(session.serverpod), isNotNull);
        },
      );
    },
  );

  withServerpod(
    'Given a Serverpod without CRDT sync initialized,',
    (sessionBuilder, _) {
      final session = sessionBuilder.build();

      test(
        'when the database interceptor wraps a session database, '
        'then it returns the original database unchanged.',
        () {
          final inner = session.db;
          final result = crdtDatabaseInterceptor(session, inner);
          expect(identical(result, inner), isTrue);
        },
      );

      test(
        'when resolving the CRDT sync for the pod, '
        'then a StateError is thrown.',
        () {
          expect(() => crdtSyncForServerpod(session.serverpod), throwsStateError);
        },
      );
    },
  );
}
