import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/person.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given CrdtDatabase wrapping the session database',
    (sessionBuilder, _) {
      late Session session;
      late CrdtDatabase crdtDb;

      setUp(() async {
        session = sessionBuilder.build();
        crdtDb = CrdtDatabase(
          session.db,
          persistentUserId: null,
          recorder: (db) => CrdtMutationRecorder(db, persistentUserId: null),
        );
      });

      group('when using integer primary key rows (delegate CRUD)', () {
        late Person person;

        setUp(() async {
          person = await Person.db.insertRow(session, Person(name: 'crud-test'));
        });

        test('then find returns the row', () async {
          final rows = await crdtDb.find<Person>(
            where: Person.t.id.equals(person.id),
          );
          expect(rows, hasLength(1));
          expect(rows.single.name, 'crud-test');
        });

        test('then findById returns the row', () async {
          final one = await crdtDb.findById<Person>(person.id!);
          expect(one?.name, 'crud-test');
        });

        test('then count includes the row', () async {
          final n = await crdtDb.count<Person>(
            where: Person.t.name.equals('crud-test'),
          );
          expect(n, greaterThanOrEqualTo(1));
        });

        test('then deleteRow removes the row physically', () async {
          await crdtDb.deleteRow(person);
          final gone = await crdtDb.findById<Person>(person.id!);
          expect(gone, isNull);
        });

        test('then deleteWhere removes matching rows', () async {
          await Person.db.insertRow(session, Person(name: 'to-remove'));
          await crdtDb.deleteWhere<Person>(
            where: Person.t.name.equals('to-remove'),
          );
          final left = await crdtDb.find<Person>(
            where: Person.t.name.equals('to-remove'),
          );
          expect(left, isEmpty);
        });
      });

      group('when persisting UUID primary key rows with CRDT metadata', () {
        test(
          'then insert/update/delete integrate with crdt_users and crdt_data_rows',
          () {
            // Pending: apply serverpod_offline_sync migrations (or a repair migration)
            // on this test server so CRDT tables exist, then seed CrdtUser +
            // CrdtSchemaTable and assert CrdtDataRow / tombstone behavior.
          },
          skip:
              'Requires CRDT schema on the test SQLite DB (module migrations + '
              'harness table). Run `serverpod create-migration` after adding models.',
        );
      });
    },
  );
}
