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
    '${Directory.systemTemp.path}/offline_sync_upsert_${const Uuid().v4()}',
  );

  setUpAll(() => preparePostgresMigrations(serverDirectory));

  tearDownAll(() async {
    if (serverDirectory.existsSync()) await serverDirectory.delete(recursive: true);
  });

  withServerpod(
    'PostgreSQL upsert default authoring',
    rollbackDatabase: RollbackDatabase.disabled,
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

      setUpAll(() async {
        session = OfflineSyncDatabaseSession.wraps(
          sessionBuilder.build(),
          syncTables: server.syncTables,
        );
        await session.db.initialize();
      });

      group('Given a projected-default child and a child with an available parent,', () {
        late UuidValue space;
        late server.Town parent;
        late server.Town otherParent;
        late server.Town insertParent;
        late server.UniqueSetDefaultChild child;
        late server.UniqueSetDefaultChild skipped;
        late Hlc originalClock;

        const defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

        setUpAll(() async {
          space = const Uuid().v7obj();
          parent = server.Town(id: const Uuid().v7obj(), name: 'parent');
          otherParent = server.Town(id: const Uuid().v7obj(), name: 'other');
          insertParent = server.Town(id: const Uuid().v7obj(), name: 'insert parent');
          child = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'child',
            parentId: parent.id,
          );
          skipped = server.UniqueSetDefaultChild(
            id: const Uuid().v7obj(),
            name: 'skipped',
            parentId: otherParent.id,
          );
          await session.db.transactionForUser(space, (tx) async {
            await server.Town.db.insert(session, [
              parent,
              otherParent,
              insertParent,
              server.Town(id: defaultTownId, name: 'default'),
            ], transaction: tx);
            await server.UniqueSetDefaultChild.db.insert(
              session,
              [child, skipped],
              transaction: tx,
            );
          });
          originalClock = await rowHlc(child.id!, databaseSession: session);
          await session.db.mergeChanges([
            CrdtMergeDelete(
              uuidSpaceId: space,
              tableName: server.Town.t.tableName,
              uuidRowId: parent.id!,
              uuidNodeId: const Uuid().v7obj(),
              hlcDatetime: originalClock.datetime.add(const Duration(milliseconds: 1)),
              hlcCounter: 0,
              clFlag: 2,
              reason: CrdtDataDeletedReason.userDelete,
            ),
          ], spaceId: space);
        });

        group('when a mixed-ID batch skips, updates by name, and inserts rows,', () {
          late List<server.UniqueSetDefaultChild> saved;
          late CrdtDataAttemptedValue? attempt;
          late CrdtDataField? field;
          late server.UniqueSetDefaultChild? restored;
          late server.UniqueSetDefaultChild? unchanged;

          setUpAll(() async {
            saved = await session.db.transactionForUser(
              space,
              (tx) => server.UniqueSetDefaultChild.db.upsert(
                session,
                [
                  server.UniqueSetDefaultChild(
                    name: skipped.name,
                    parentId: otherParent.id,
                  ),
                  server.UniqueSetDefaultChild(
                    id: const Uuid().v7obj(),
                    name: child.name,
                  ),
                  server.UniqueSetDefaultChild(
                    name: 'inserted',
                    parentId: insertParent.id,
                  ),
                ],
                conflictColumns: (t) => [t.spaceId, t.name],
                updateWhere: (t) => t.name.equals(child.name),
                transaction: tx,
              ),
            );
            attempt = await attemptedValue(
              rowId: child.id!,
              columnName: 'parentId',
              databaseSession: session,
            );
            field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(child.id) & t.column.name.equals('parentId'),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );
            unchanged = await server.UniqueSetDefaultChild.db.findById(
              session,
              skipped.id!,
            );
            await session.db.transactionForUser(
              space,
              (tx) => server.Town.db.insertRow(session, parent, transaction: tx),
            );
            restored = await server.UniqueSetDefaultChild.db.findById(
              session,
              child.id!,
            );
          });

          test(
            'then the existing row authors the default despite the different input ID.',
            () {
              expect(
                saved.map((row) => row.name),
                unorderedEquals([child.name, 'inserted']),
              );
              expect(saved.singleWhere((row) => row.name == child.name).id, child.id);
              expect(attempt, isNull);
              expect(field!.hlc, greaterThan(originalClock));
              expect(restored!.parentId, defaultTownId);
            },
          );

          test('then the skipped row retains its parent.', () {
            expect(unchanged!.parentId, otherParent.id);
          });
        });
      });
    },
  );
}
