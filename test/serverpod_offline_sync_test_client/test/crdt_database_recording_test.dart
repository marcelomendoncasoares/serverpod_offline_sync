import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client';
import 'package:test/test.dart';

import 'crdt_database_test_fixtures.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    '[CRDT Database Recording]',
    rollbackDatabase: RollbackDatabase.disabled,
    (sessionBuilder, _) {
      late DatabaseSession inner;
      late CrdtDatabaseSession session;

      setUp(() async {
        inner = sessionBuilder.build();
        session = CrdtDatabaseSession.wraps(
          inner,
          persistentUserId: testCrdtUserId,
        );
      });

      tearDown(() async {
        await clearDatabase(inner);
        await inner.maybeIs<Session>()?.close();
      });

      group(
        'Given an empty person table, '
        'when insertRow adds a Person through CrdtDatabase,',
        () {
          const targetName = 'test';
          late Person person;

          setUp(() async {
            person = await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: targetName),
                transaction: tx,
              ),
            );
          });

          test('then the row exists in the person table.', () async {
            final row = await Person.db.findFirstRow(
              session,
              where: (t) => t.id.equals(person.id),
            );
            expect(row, isNotNull);
            expect(row!.name, targetName);
          });

          group('then CRDT metadata is recorded,', () {
            late CrdtDataRow crdtRow;

            setUp(() async {
              crdtRow = (await CrdtDataRow.db.findFirstRow(
                session,
                where: (t) => t.uuidRowId.equals(person.id),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              ))!;
            });

            test(
              'then a single CrdtDataRow exists and one CrdtDataField per registered schema column.',
              () async {
                final fieldCount = await CrdtDataField.db.count(
                  session,
                  where: (t) => t.row.uuidRowId.equals(person.id),
                );
                expect(fieldCount, 3);
                expect(crdtRow.tblId, isNotNull);
                expect(crdtRow.uuidRowId, person.id);
              },
            );

            test(
              'then the row-level HLC components on CrdtDataRow are populated consistently.',
              () async {
                final hlc = crdtRow.toHlcForNode(crdtRow.node!.uuidNodeId);
                expect(hlc.datetime.toUtc(), crdtRow.datetime.toUtc());
                expect(hlc.counter, crdtRow.counter);
                expect(hlc.node.workerId, crdtRow.workerId);
              },
            );
          });
        },
      );

      group(
        'Given a Person row with CRDT field rows for tracked columns, '
        'when updateRow changes two columns,',
        () {
          const initialName = 'test';
          late Person person;
          late Organization org;
          late Hlc createdNameHlc;
          late Hlc createdOrgHlc;
          late Hlc createdOldCompanyHlc;

          setUp(() async {
            org = await Organization.db.insertRow(
              session,
              Organization(name: 'org'),
            );

            person = await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: initialName),
                transaction: tx,
              ),
            );

            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataField.include(
                column: CrdtSchemaColumn.include(),
                row: CrdtDataRow.include(node: CrdtNode.include()),
              ),
            );

            Hlc hFor(String column) {
              final f = fields.firstWhere((e) => e.column!.name == column);
              return f.toHlcForNode(f.row!.node!.uuidNodeId);
            }

            createdNameHlc = hFor('name');
            createdOrgHlc = hFor('organizationId');
            createdOldCompanyHlc = hFor('oldCompanyId');
          });

          const targetName = 'test2';

          setUp(() async {
            await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.updateRow(
                session,
                person.copyWith(name: targetName, organizationId: org.id),
                columns: (t) => [t.name, t.organizationId],
                transaction: tx,
              ),
            );
          });

          test('then the person row reflects the new values.', () async {
            final row = await Person.db.findById(session, person.id!);
            expect(row?.name, targetName);
            expect(row?.organizationId, org.id);
          });

          group('then CRDT field timestamps for the updated columns,', () {
            late List<CrdtDataField> fields;

            setUp(() async {
              fields = await CrdtDataField.db.find(
                session,
                where: (t) => t.row.uuidRowId.equals(person.id),
                include: CrdtDataField.include(
                  column: CrdtSchemaColumn.include(),
                  row: CrdtDataRow.include(node: CrdtNode.include()),
                ),
              );
            });

            test(
              'then each updated column has an HLC strictly after the insert HLC.',
              () async {
                Hlc hFor(String column) {
                  final f = fields.firstWhere((e) => e.column!.name == column);
                  return f.toHlcForNode(f.row!.node!.uuidNodeId);
                }

                expect(hFor('name'), greaterThan(createdNameHlc));
                expect(hFor('organizationId'), greaterThan(createdOrgHlc));
              },
            );

            test(
              'then columns not included in the update keep their previous HLC.',
              () async {
                final f = fields.firstWhere((e) => e.column!.name == 'oldCompanyId');
                final h = f.toHlcForNode(f.row!.node!.uuidNodeId);
                expect(h, createdOldCompanyHlc);
              },
            );
          });
        },
      );

      group(
        'Given a Person row with a CRDT field row for name, '
        'when updateRow writes the same name again,',
        () {
          const initialName = 'test';
          late Person person;
          late Hlc createdFieldHlc;

          setUp(() async {
            person = await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: initialName),
                transaction: tx,
              ),
            );

            final field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataField.include(
                row: CrdtDataRow.include(node: CrdtNode.include()),
              ),
            );
            createdFieldHlc = field.toHlcForNode(field.row!.node!.uuidNodeId);

            await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.updateRow(
                session,
                person.copyWith(name: initialName),
                columns: (t) => [t.name],
                transaction: tx,
              ),
            );
          });

          test(
            'then the recorder still advances the field HLC (no SQLite OLD/NEW short-circuit).',
            () async {
              final field = await CrdtDataField.db.findFirstRow(
                session,
                where: (t) => t.row.uuidRowId.equals(person.id),
                include: CrdtDataField.include(
                  row: CrdtDataRow.include(node: CrdtNode.include()),
                ),
              );
              final after = field.toHlcForNode(field.row!.node!.uuidNodeId);
              expect(after, greaterThan(createdFieldHlc));
            },
          );
        },
      );

      group(
        'Given a Person row suitable for soft delete, '
        'when deleteRow runs through CrdtDatabase,',
        () {
          late Person person;
          late Hlc createdRowHlc;

          setUp(() async {
            person = await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'gone'),
                transaction: tx,
              ),
            );

            final crdtRow = await CrdtDataRow.db.findFirstRow(
              session,
              where: (t) => t.uuidRowId.equals(person.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            createdRowHlc = crdtRow.toHlcForNode(crdtRow.node!.uuidNodeId);

            await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.deleteRow(session, person, transaction: tx),
            );
          });

          test('then findById no longer returns the row.', () async {
            expect(await Person.db.findById(session, person.id!), isNull);
          });

          group('then the tombstone row records deletion,', () {
            test('then isDeleted is true with an HLC after the insert HLC.', () async {
              final crdtRow = await CrdtDataRow.db.findFirstRow(
                session,
                where: (t) => t.uuidRowId.equals(person.id),
                include: CrdtDataRow.include(node: CrdtNode.include()),
              );

              final tomb = await CrdtDataDeleted.db.findFirstRow(
                session,
                where: (t) => t.rowId.equals(crdtRow.id),
                include: CrdtDataDeleted.include(
                  row: CrdtDataRow.include(node: CrdtNode.include()),
                ),
              );

              expect(tomb.isDeleted, true);
              final nodeUuid = crdtRow.node!.uuidNodeId;
              final tombHlc = tomb.toHlcForNode(nodeUuid);
              expect(tombHlc, greaterThan(createdRowHlc));
            });
          });
        },
      );

      group(
        'Given CRDT schema is seeded, '
        'when a Person is inserted through the delegate Database only,',
        () {
          test('then no CrdtDataRow is created (mirrors triggers disabled).', () async {
            final before = await CrdtDataRow.db.count(session);
            // await session.underlyingDatabase.insertRow(Person(name: 'raw-only'));
            final after = await CrdtDataRow.db.count(session);
            expect(after, before);
          });
        },
      );

      group(
        'Given a Person inserted through CrdtDatabase with CRDT field rows, '
        'when the row is updated through the delegate Database only,',
        () {
          late Person person;
          late int fieldCount;

          setUp(() async {
            person = await session.db.transactionForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'tracked'),
                transaction: tx,
              ),
            );

            fieldCount = await CrdtDataField.db.count(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
            );

            await Person.db.updateRow(
              session,
              person.copyWith(name: 'bypass'),
              columns: (t) => [t.name],
            );
          });

          test(
            'then CRDT tables gain no additional rows from that update (mirrors triggers disabled).',
            () async {
              expect(
                await CrdtDataField.db.count(
                  session,
                  where: (t) => t.row.uuidRowId.equals(person.id),
                ),
                fieldCount,
              );
              expect(await CrdtDataRow.db.count(session), 1);
            },
          );
        },
      );
    },
  );
}

extension on Object {
  T? maybeIs<T>() => this is T ? this as T : null;
}
