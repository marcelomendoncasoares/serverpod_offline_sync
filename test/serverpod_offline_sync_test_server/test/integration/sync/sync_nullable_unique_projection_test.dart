import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession();

  for (final hidden in [false, true]) {
    group(
      'Given a ${hidden ? 'deleted' : 'visible'} composite unique loser with a released name,',
      () {
        late SyncNode source;
        late UniqueMixedFk loser;
        late Hlc insertionHlc;
        late CrdtMergeUpdate detach;

        setUp(() async {
          source = (
            raw: testSession,
            offlineSync: session,
            sync: OfflineSyncEngine(
              syncTables: testSyncTables,
              serializationManager: testSession.db.serializationManager,
            ),
          );
          final parent = Person(id: const Uuid().v7obj(), name: 'parent');
          final winner = UniqueMixedFk(
            id: const Uuid().v7obj(),
            name: 'claim',
            parentId: parent.id,
          );
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            await Person.db.insertRow(session, parent, transaction: tx);
            await UniqueMixedFk.db.insertRow(session, winner, transaction: tx);
          });
          loser = UniqueMixedFk(
            id: const Uuid().v7obj(),
            name: 'claim',
            parentId: parent.id,
          );
          final node = const Uuid().v7obj();
          final timestamp = (await rowHlc(winner.id!)).datetime.add(
            const Duration(milliseconds: 1),
          );
          await session.db.mergeChanges(
            [
              CrdtMergeInsert(
                uuidSpaceId: testCrdtUserId,
                tableName: UniqueMixedFk.t.tableName,
                uuidRowId: loser.id!,
                uuidNodeId: node,
                hlcDatetime: timestamp,
                hlcCounter: 0,
                data: loser,
              ),
              if (hidden)
                CrdtMergeDelete(
                  uuidSpaceId: testCrdtUserId,
                  tableName: UniqueMixedFk.t.tableName,
                  uuidRowId: loser.id!,
                  uuidNodeId: node,
                  hlcDatetime: timestamp,
                  hlcCounter: 1,
                  clFlag: 2,
                  reason: CrdtDataDeletedReason.userDelete,
                ),
            ],
            spaceId: testCrdtUserId,
          );
          insertionHlc = await rowHlc(loser.id!);
          final projected = await UniqueMixedFk.db.findById(testSession, loser.id!);
          expect(
            projected!.name,
            'claim__${hidden ? 'hidden' : 'conflict'}__${loser.id!.uuid}',
          );
          detach = CrdtMergeUpdate(
            uuidSpaceId: testCrdtUserId,
            tableName: UniqueMixedFk.t.tableName,
            uuidRowId: loser.id!,
            uuidNodeId: node,
            hlcDatetime: timestamp,
            hlcCounter: 2,
            columnName: UniqueMixedFk.t.parentId.columnName,
            value: null,
          );
        });

        group('when a remote write detaches its parent,', () {
          setUp(() async {
            await session.db.mergeChanges([detach], spaceId: testCrdtUserId);
          });

          test(
            'then the name returns to its authored value without a new clock.',
            () async {
              final row = await UniqueMixedFk.db.findById(testSession, loser.id!);
              expect(row!.name, 'claim');
              expect(row.parentId, isNull);
              expect(
                await attemptedValue(rowId: loser.id!, columnName: 'name'),
                isNull,
              );
              final changes = await source.sync
                  .collectPendingChanges(
                    source.raw,
                    checkpointsBySpaceUuid: {testCrdtUserId: const []},
                  )
                  .toList();
              final insert = changes.inserts.singleWhere(
                (c) => c.uuidRowId == loser.id,
              );
              expect((insert.data as UniqueMixedFk).name, 'claim');
              expect(insert.hlc, insertionHlc);
              expect(
                changes.updates.where(
                  (c) => c.uuidRowId == loser.id && c.columnName == 'name',
                ),
                isEmpty,
              );
            },
          );

          test('then an empty replica reproduces its domain and visibility.', () async {
            final mirror = await syncNode(
              await createAdditionalTestSession(),
              testSyncTables,
            );
            await pushChanges(source, mirror);
            final original = await UniqueMixedFk.db.findById(source.raw, loser.id!);
            final copied = await UniqueMixedFk.db.findById(mirror.raw, loser.id!);
            expect(copied!.name, original!.name);
            expect(copied.parentId, original.parentId);
            for (final node in [source, mirror]) {
              expect(
                await UniqueMixedFk.db.findById(node.offlineSync, loser.id!),
                hidden ? isNull : isNotNull,
              );
              expect(
                await rowHlc(loser.id!, databaseSession: node.offlineSync),
                insertionHlc,
              );
              expect(
                await attemptedValue(
                  rowId: loser.id!,
                  columnName: 'name',
                  databaseSession: node.offlineSync,
                ),
                isNull,
              );
            }
          });
        });
      },
    );
  }
}
