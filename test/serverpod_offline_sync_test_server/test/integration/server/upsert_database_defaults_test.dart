import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_server/src/generated/protocol.dart'
    as server;
import 'package:test/test.dart';

import '../test_tools/crdt_probes.dart';
import '../test_tools/postgres_migrations.dart';
import '../test_tools/serverpod_test_tools.dart';

void main() {
  final serverDirectory = Directory(
    '${Directory.systemTemp.path}/os_upsert_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    '[PostgreSQL database upsert defaults]',
    serverDirectory: serverDirectory,
    configOverride: (config) => config.copyWith(
      database: PostgresDatabaseConfig.embedded(
        dataPath: '${serverDirectory.path}/postgres',
        name: 'serverpod_test',
        maxConnectionCount: 6,
      ),
    ),
    (sessionBuilder, _) {
      late OfflineSyncDatabaseSession session;

      setUp(() async {
        session = OfflineSyncDatabaseSession.wraps(
          sessionBuilder.build(),
          syncTables: server.syncTables,
        );
        await session.db.initialize();
      });

      group('Given a default town and a child referencing another town,', () {
        const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

        late UuidValue userId;
        late server.Town otherTown;
        late server.UniqueSetDefaultChild existing;
        late Hlc originalClock;

        setUp(() async {
          userId = const Uuid().v7obj();
          otherTown = server.Town(id: const Uuid().v7obj(), name: 'other');
          existing = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'existing',
            parentId: otherTown.id,
          );

          await session.db.transactionForUser(userId, (tx) async {
            await server.Town.db.insert(session, [
              server.Town(id: defaultTownId, name: 'default'),
              otherTown,
            ], transaction: tx);
            await server.UniqueSetDefaultChild.db.insertRow(
              session,
              existing,
              transaction: tx,
            );
          });

          originalClock = await rowHlc(existing.id!, databaseSession: session);
        });

        group(
          'when a no-return batch updates the child and inserts a defaulted child,',
          () {
            late List<server.UniqueSetDefaultChild> returned;
            late List<server.UniqueSetDefaultChild> stored;
            late CrdtDataRow? insertedMetadata;
            late server.UniqueSetDefaultChild input;

            setUp(() async {
              input = server.UniqueSetDefaultChild(name: 'new defaulted child');

              returned = await session.db.transactionForUser(
                userId,
                (tx) => server.UniqueSetDefaultChild.db.upsert(
                  session,
                  [existing.copyWith(name: 'updated'), input],
                  conflictColumns: (t) => [t.id],
                  noReturn: true,
                  transaction: tx,
                ),
              );

              stored = await session.db.transactionForUser(
                userId,
                (tx) => server.UniqueSetDefaultChild.db.find(
                  session,
                  orderBy: (t) => t.name,
                  transaction: tx,
                ),
              );
              insertedMetadata = await CrdtDataRow.db.findFirstRow(
                session,
                where: (t) => t.uuidRowId.equals(stored.first.id),
              );
            });

            test(
              'then the generated row persists the default and receives CRDT metadata.',
              () {
                expect(returned, isEmpty);
                expect(stored.map((row) => (row.name, row.parentId)), [
                  ('new defaulted child', defaultTownId),
                  ('updated', otherTown.id),
                ]);
                expect(stored.first.id, isNotNull);
                expect(insertedMetadata, isNotNull);
              },
            );

            test('then the caller retains its omitted ID and foreign key.', () {
              expect(input.id, isNull);
              expect(input.parentId, isNull);
              expect(input.spaceId, isNull);
            });
          },
        );

        group('when a name-only upsert omits the defaulted foreign key,', () {
          late server.UniqueSetDefaultChild? stored;
          late CrdtDataField? parentField;

          setUp(() async {
            await session.db.transactionForUser(
              userId,
              (tx) => server.UniqueSetDefaultChild.db.upsertRow(
                session,
                server.UniqueSetDefaultChild(id: existing.id, name: 'renamed'),
                conflictColumns: (t) => [t.id],
                updateColumns: (t) => [t.name],
                transaction: tx,
              ),
            );

            stored = await server.UniqueSetDefaultChild.db.findById(
              session,
              existing.id!,
            );
            parentField = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(existing.id) &
                  t.column.name.equals('parentId'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );
          });

          test(
            'then the existing reference and its authored clock stay unchanged.',
            () {
              expect((stored!.name, stored!.parentId), ('renamed', otherTown.id));
              expect(parentField?.hlc ?? originalClock, originalClock);
            },
          );
        });

        group('when a full-row upsert omits the defaulted foreign key,', () {
          late server.UniqueSetDefaultChild? stored;
          late CrdtDataField? parentField;
          late CrdtDataAttemptedValue? attempt;

          setUp(() async {
            await session.db.transactionForUser(
              userId,
              (tx) => server.UniqueSetDefaultChild.db.upsertRow(
                session,
                server.UniqueSetDefaultChild(id: existing.id, name: 'defaulted'),
                conflictColumns: (t) => [t.id],
                transaction: tx,
              ),
            );

            stored = await server.UniqueSetDefaultChild.db.findById(
              session,
              existing.id!,
            );
            parentField = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(existing.id) &
                  t.column.name.equals('parentId'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );
            attempt = await attemptedValue(
              rowId: existing.id!,
              columnName: 'parentId',
              databaseSession: session,
            );
          });

          test('then the database default becomes the authored reference.', () {
            expect((stored!.name, stored!.parentId), ('defaulted', defaultTownId));
            expect(parentField!.hlc, greaterThan(originalClock));
            expect(attempt, isNull);
          });
        });

        group('and a second child holds the default-town reference,', () {
          late server.UniqueSetDefaultChild defaulted;

          setUp(() async {
            defaulted = await session.db.transactionForUser(
              userId,
              (tx) => server.UniqueSetDefaultChild.db.insertRow(
                session,
                server.UniqueSetDefaultChild(name: 'default holder'),
                transaction: tx,
              ),
            );
          });

          group(
            'when an upsert uses an omitted foreign key as its conflict target,',
            () {
              late server.UniqueSetDefaultChild? returned;
              late List<server.UniqueSetDefaultChild> stored;

              setUp(() async {
                returned = await session.db.transactionForUser(
                  userId,
                  (tx) => server.UniqueSetDefaultChild.db.upsertRow(
                    session,
                    server.UniqueSetDefaultChild(
                      id: const Uuid().v7obj(),
                      name: 'matched by default',
                    ),
                    conflictColumns: (t) => [t.parentId],
                    transaction: tx,
                  ),
                );

                stored = await session.db.transactionForUser(
                  userId,
                  (tx) =>
                      server.UniqueSetDefaultChild.db.find(session, transaction: tx),
                );
              });

              test(
                'then it updates the default holder without inserting another child.',
                () {
                  expect(returned!.id, defaulted.id);
                  expect(returned!.parentId, defaultTownId);
                  expect(
                    stored.map((row) => (row.id, row.name, row.parentId)),
                    unorderedEquals([
                      (existing.id, existing.name, otherTown.id),
                      (defaulted.id, 'matched by default', defaultTownId),
                    ]),
                  );
                },
              );
            },
          );
        });
      });
    },
  );
}
