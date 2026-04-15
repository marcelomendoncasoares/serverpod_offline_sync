import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/person.dart';
import 'package:test/test.dart';

import 'crdt_database_test_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given CrdtDatabase wrapping the session database',
    (sessionBuilder, _) {
      late Session session;
      late CrdtDatabase crdtDb;

      setUp(() async {
        session = sessionBuilder.build();
        await seedCrdtUserAndPersonSchema(session);
        crdtDb = crdtDatabase(session);
      });

      group('when inserting UUID primary key rows with CRDT metadata', () {
        test('then insertRow creates a CrdtDataRow for the domain row', () async {
          final person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'insert-one'), transaction: tx),
          );
          expect(person.id, isNotNull);

          final crdtRows = await CrdtDataRow.db.find(
            session,
            where: (t) => t.rowId.equals(person.id!),
          );
          expect(crdtRows, hasLength(1));
          expect(crdtRows.single.tblId, isNotNull);
        });

        test('then insert creates CrdtDataRows for each row', () async {
          final inserted = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insert(
              [
                Person(name: 'batch-a'),
                Person(name: 'batch-b'),
              ],
              transaction: tx,
            ),
          );
          expect(inserted, hasLength(2));

          for (final p in inserted) {
            final n = await CrdtDataRow.db.count(
              session,
              where: (t) => t.rowId.equals(p.id!),
            );
            expect(n, 1);
          }
        });
      });

      group('when reading Person rows through CrdtDatabase', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'reader'), transaction: tx),
          );
        });

        test('then find returns the row', () async {
          final rows = await crdtDb.find<Person>(
            where: Person.t.id.equals(person.id!),
          );
          expect(rows, hasLength(1));
          expect(rows.single.name, 'reader');
        });

        test('then findById returns the row', () async {
          final one = await crdtDb.findById<Person>(person.id!);
          expect(one?.name, 'reader');
        });

        test('then findFirstRow returns the row', () async {
          final one = await crdtDb.findFirstRow<Person>(
            where: Person.t.name.equals('reader'),
          );
          expect(one?.id, person.id);
        });

        test('then count includes the row', () async {
          final n = await crdtDb.count<Person>(
            where: Person.t.name.equals('reader'),
          );
          expect(n, 1);
        });
      });

      group('when deleting UUID primary key rows (soft delete + tombstone)', () {
        test('then deleteRow hides the row from find and sets tombstone', () async {
          final person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'to-tomb'), transaction: tx),
          );

          await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.deleteRow(person, transaction: tx),
          );

          expect(await crdtDb.findById<Person>(person.id!), isNull);

          final crdtRow = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.rowId.equals(person.id!),
          );
          expect(crdtRow, isNotNull);

          final tomb = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.rowId.equals(crdtRow!.id!),
          );
          expect(tomb?.isDeleted, true);
        });

        test('then deleteWhere tombstones all matching rows', () async {
          await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insert(
              [
                Person(name: 'bulk-x'),
                Person(name: 'bulk-x'),
              ],
              transaction: tx,
            ),
          );

          final deleted = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.deleteWhere<Person>(
              where: Person.t.name.equals('bulk-x'),
              transaction: tx,
            ),
          );
          expect(deleted, hasLength(2));

          final remaining = await crdtDb.find<Person>(
            where: Person.t.name.equals('bulk-x'),
          );
          expect(remaining, isEmpty);
        });

        test('then delete on a list tombstones each row', () async {
          final p1 = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'list-1'), transaction: tx),
          );
          final p2 = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'list-2'), transaction: tx),
          );

          await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.delete([p1, p2], transaction: tx),
          );

          expect(await crdtDb.findById<Person>(p1.id!), isNull);
          expect(await crdtDb.findById<Person>(p2.id!), isNull);
        });
      });

      group('when locking rows', () {
        test('then lockRows runs without error inside a user transaction', () async {
          final person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'locked-row'), transaction: tx),
          );

          await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) async {
              await crdtDb.lockRows<Person>(
                where: Person.t.id.equals(person.id!),
                lockMode: LockMode.forUpdate,
                transaction: tx,
              );
            },
          );
        });
      });

      group('when updating UUID primary key rows', () {
        test(
          'then updateRow throws until CrdtDataField rows exist for updated columns',
          () async {
            final person = await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.insertRow(Person(name: 'before-update'), transaction: tx),
            );

            await expectLater(
              () => crdtDb.transactionForUser(
                testCrdtUserId,
                (tx) => crdtDb.updateRow(
                  person.copyWith(name: 'after-update'),
                  transaction: tx,
                ),
              ),
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('Missing CRDT rows'),
                ),
              ),
            );
          },
        );

        test(
          'then updateById throws until CrdtDataField rows exist for updated columns',
          () async {
            final person = await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.insertRow(Person(name: 'by-id'), transaction: tx),
            );

            await expectLater(
              () => crdtDb.transactionForUser(
                testCrdtUserId,
                (tx) => crdtDb.updateById<Person>(
                  person.id!,
                  columnValues: [Person.t.updateTable.name('renamed')],
                  transaction: tx,
                ),
              ),
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('Missing CRDT rows'),
                ),
              ),
            );
          },
        );

        test(
          'then updateWhere throws until CrdtDataField rows exist for updated columns',
          () async {
            await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.insertRow(Person(name: 'where-target'), transaction: tx),
            );

            await expectLater(
              () => crdtDb.transactionForUser(
                testCrdtUserId,
                (tx) => crdtDb.updateWhere<Person>(
                  columnValues: [Person.t.updateTable.name('where-renamed')],
                  where: Person.t.name.equals('where-target'),
                  transaction: tx,
                ),
              ),
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('Missing CRDT rows'),
                ),
              ),
            );
          },
        );
      });
    },
  );
}
