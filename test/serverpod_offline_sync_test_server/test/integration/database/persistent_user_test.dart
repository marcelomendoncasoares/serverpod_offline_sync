import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  group(
    'Given an empty local database configured with a persistent CRDT user id, '
    'when a Person is inserted without a transaction ',
    () {
      late Person person;

      setUp(() async {
        person = await Person.db.insertRow(
          session,
          Person(name: 'local-only'),
        );
      });

      test('then the row is persisted.', () async {
        final loaded = await Person.db.findById(session, person.id!);
        expect(loaded?.name, 'local-only');
      });

      test('then the CRDT scope exists.', () async {
        final crdtScope = await CrdtScope.db.findFirstRow(
          session,
          where: (t) => t.uuidScopeId.equals(testCrdtUserId),
          include: CrdtScope.include(currentNode: CrdtNode.include()),
        );
        expect(crdtScope, isNotNull);
      });

      test('then the CRDT metadata is written.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
        );
        expect(crdtRow, isNotNull);
      });
    },
  );
}
