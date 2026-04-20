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

      group(
        'Given insertRow inserted a single Person with CRDT metadata on a UUID primary key,',
        () {
          late Person person;

          setUp(() async {
            person = await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.insertRow(Person(name: 'insert-one'), transaction: tx),
            );
          });

          test('then a CrdtDataRow exists for the domain row.', () async {
            expect(person.id, isNotNull);

            final crdtRows = await CrdtDataRow.db.find(
              session,
              where: (t) => t.uuidRowId.equals(person.id),
            );
            expect(crdtRows, hasLength(1));
            expect(crdtRows.single.tblId, isNotNull);
          });
        },
      );

      group(
        'Given insert inserted two Person rows in one batch with CRDT metadata on UUID primary keys,',
        () {
          late List<Person> inserted;

          setUp(() async {
            inserted = await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.insert(
                [
                  Person(name: 'batch-a'),
                  Person(name: 'batch-b'),
                ],
                transaction: tx,
              ),
            );
          });

          test('then each row has a CrdtDataRow.', () async {
            expect(inserted, hasLength(2));

            for (final p in inserted) {
              final n = await CrdtDataRow.db.count(
                session,
                where: (t) => t.uuidRowId.equals(p.id),
              );
              expect(n, 1);
            }
          });
        },
      );

      group('Given a Person row exists for reads through CrdtDatabase,', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'reader'), transaction: tx),
          );
        });

        test('then find returns the row.', () async {
          final rows = await crdtDb.find<Person>(
            where: Person.t.id.equals(person.id),
          );
          expect(rows, hasLength(1));
          expect(rows.single.name, 'reader');
        });

        test('then findById returns the row.', () async {
          final one = await crdtDb.findById<Person>(person.id!);
          expect(one?.name, 'reader');
        });

        test('then findFirstRow returns the row.', () async {
          final one = await crdtDb.findFirstRow<Person>(
            where: Person.t.name.equals('reader'),
          );
          expect(one?.id, person.id);
        });

        test('then count includes the row.', () async {
          final n = await crdtDb.count<Person>(
            where: Person.t.name.equals('reader'),
          );
          expect(n, 1);
        });
      });

      group('Given a Person inserted for single-row soft delete,', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'to-tomb'), transaction: tx),
          );
        });

        group('when deleteRow is applied,', () {
          test(
            'then find no longer returns the row and a tombstone records deletion.',
            () async {
              await crdtDb.transactionForUser(
                testCrdtUserId,
                (tx) => crdtDb.deleteRow(person, transaction: tx),
              );

              expect(await crdtDb.findById<Person>(person.id!), isNull);

              final crdtRow = await CrdtDataRow.db.findFirstRow(
                session,
                where: (t) => t.uuidRowId.equals(person.id),
              );
              expect(crdtRow, isNotNull);

              final tomb = await CrdtDataDeleted.db.findFirstRow(
                session,
                where: (t) => t.rowId.equals(crdtRow!.id),
              );
              expect(tomb?.isDeleted, true);
            },
          );
        });
      });

      group('Given two Person rows share a name for bulk delete,', () {
        setUp(() async {
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
        });

        group('when deleteWhere matches that name,', () {
          test('then both rows are tombstoned and no longer appear in find.', () async {
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
        });
      });

      group('Given two Person rows exist for list delete,', () {
        late Person p1;
        late Person p2;

        setUp(() async {
          p1 = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'list-1'), transaction: tx),
          );
          p2 = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'list-2'), transaction: tx),
          );
        });

        group('when delete is called on a list of those rows,', () {
          test('then neither row is returned by findById.', () async {
            await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) => crdtDb.delete([p1, p2], transaction: tx),
            );

            expect(await crdtDb.findById<Person>(p1.id!), isNull);
            expect(await crdtDb.findById<Person>(p2.id!), isNull);
          });
        });
      });

      group('Given a Person row exists for locking,', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'locked-row'), transaction: tx),
          );
        });

        group('when lockRows runs inside a user transaction,', () {
          test('then it completes without error.', () async {
            await crdtDb.transactionForUser(
              testCrdtUserId,
              (tx) async {
                await crdtDb.lockRows<Person>(
                  where: Person.t.id.equals(person.id),
                  lockMode: LockMode.forUpdate,
                  transaction: tx,
                );
              },
            );
          });
        });
      });

      group('Given a Person exists without CrdtDataField rows for updateRow,', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'before-update'), transaction: tx),
          );
        });

        group('when updateRow changes a column,', () {
          test(
            'then StateError is thrown until CrdtDataField rows exist for updated columns.',
            () async {
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
        });
      });

      group('Given a Person exists without CrdtDataField rows for updateById,', () {
        late Person person;

        setUp(() async {
          person = await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'by-id'), transaction: tx),
          );
        });

        group('when updateById changes a column,', () {
          test(
            'then StateError is thrown until CrdtDataField rows exist for updated columns.',
            () async {
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
        });
      });

      group('Given a Person exists without CrdtDataField rows for updateWhere,', () {
        setUp(() async {
          await crdtDb.transactionForUser(
            testCrdtUserId,
            (tx) => crdtDb.insertRow(Person(name: 'where-target'), transaction: tx),
          );
        });

        group('when updateWhere changes a column,', () {
          test(
            'then StateError is thrown until CrdtDataField rows exist for updated columns.',
            () async {
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
      });
    },
  );
}
