import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

void main() {
  initTestClientSession();

  group(
    'Given a visible row claiming a unique value and a newer remote insert '
    'that claims the same value,',
    () {
      late Unique winner;
      late Unique loser;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        winner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            transaction: tx,
          ),
        );

        loser = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        remoteInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: (await rowHlc(winner.id!)).datetime.advance(),
          hlcCounter: 0,
          data: loser,
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then both rows remain visible and the incoming insert receives a '
          'deterministic conflict-free value.',
          () async {
            final rows = await Unique.db.find(session);

            expect(rows, hasLength(2));
            expect(
              rows.singleWhere((row) => row.id == winner.id).name,
              'shared-name',
            );
            expect(
              rows.singleWhere((row) => row.id == loser.id).name,
              'shared-name__conflict__${loser.id!.uuid}',
            );
          },
        );
      });

      group('when the same losing insert was merged and is replayed,', () {
        late Hlc loserRowHlcAfterFirstMerge;

        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
          loserRowHlcAfterFirstMerge = await rowHlc(loser.id!);

          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the replay does not rewrite the resolved unique values.',
          () async {
            final rows = await Unique.db.find(session);

            expect(
              rows.singleWhere((row) => row.id == winner.id).name,
              'shared-name',
            );
            expect(
              rows.singleWhere((row) => row.id == loser.id).name,
              'shared-name__conflict__${loser.id!.uuid}',
            );
          },
        );

        test('then the replay does not change the CRDT row metadata.', () async {
          expect(await rowHlc(loser.id!), loserRowHlcAfterFirstMerge);
        });
      });
    },
  );

  group(
    'Given a row owned by one scope and a remote insert for another scope '
    'that claims the same unique value,',
    () {
      late Unique owner;
      late Unique incoming;
      late UuidValue otherUserId;

      setUp(() async {
        owner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'global-name'),
            transaction: tx,
          ),
        );
        otherUserId = const Uuid().v7obj();
        incoming = Unique(id: const Uuid().v7obj(), name: 'global-name');

        await session.db.mergeChanges(
          [
            CrdtMergeInsert(
              uuidScopeId: testCrdtUserId,
              tableName: Unique.t.tableName,
              uuidRowId: incoming.id!,
              uuidNodeId: const Uuid().v7obj(),
              hlcDatetime: (await rowHlc(owner.id!)).datetime.advance(),
              hlcCounter: 0,
              data: incoming,
            ),
          ],
          scopeId: otherUserId,
        );
      });

      test(
        'when merging, then both rows keep the per-scope unique value.',
        () async {
          final rows = await Unique.db.find(testSession);

          expect(rows, hasLength(2));
          expect(rows.singleWhere((row) => row.id == owner.id).name, 'global-name');
          expect(rows.singleWhere((row) => row.id == incoming.id).name, 'global-name');
        },
      );
    },
  );

  group(
    'Given a visible row claiming a unique value and an older remote insert '
    'that claims the same value,',
    () {
      late Unique existingLoser;
      late Unique incomingWinner;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        existingLoser = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            transaction: tx,
          ),
        );

        incomingWinner = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        remoteInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: incomingWinner.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: (await rowHlc(existingLoser.id!)).datetime.retreat(),
          hlcCounter: 0,
          data: incomingWinner,
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the older incoming claim keeps the unique value and the '
          'existing visible row is released to a conflict-free value.',
          () async {
            final rows = await Unique.db.find(session);

            expect(rows, hasLength(2));
            expect(
              rows.singleWhere((row) => row.id == incomingWinner.id).name,
              'shared-name',
            );
            expect(
              rows.singleWhere((row) => row.id == existingLoser.id).name,
              'shared-name__conflict__${existingLoser.id!.uuid}',
            );
          },
        );

        test(
          'then the released name is not authored as a field update.',
          () async {
            final crdtRow = await CrdtDataRow.db.findFirstRow(
              session,
              where: (t) => t.uuidRowId.equals(existingLoser.id),
              include: CrdtDataRow.include(node: CrdtNode.include()),
            );
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(existingLoser.id),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(fields.where((field) => field.hlc != crdtRow!.hlc), isEmpty);
          },
        );
      });
    },
  );

  group(
    'Given two visible rows and an older remote update that claims the unique '
    'value of the row with the newer claim,',
    () {
      late Unique updatedWinner;
      late Unique existingLoser;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        updatedWinner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'original-name'),
            transaction: tx,
          ),
        );

        // Guarantees the existing claim HLC is newer than the remote update.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        existingLoser = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            transaction: tx,
          ),
        );

        remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: updatedWinner.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: (await rowHlc(updatedWinner.id!)).datetime.advance(),
          hlcCounter: 0,
          columnName: Unique.t.name.columnName,
          value: 'shared-name',
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteUpdate],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the older incoming claim keeps the unique value and the row '
          'with the newer claim is released to a conflict-free value.',
          () async {
            final rows = await Unique.db.find(session);

            expect(rows, hasLength(2));
            expect(
              rows.singleWhere((row) => row.id == updatedWinner.id).name,
              'shared-name',
            );
            expect(
              rows.singleWhere((row) => row.id == existingLoser.id).name,
              'shared-name__conflict__${existingLoser.id!.uuid}',
            );
          },
        );
      });
    },
  );

  group(
    'Given a visible child claiming a nullable unique foreign key and a newer '
    'remote insert that claims the same parent,',
    () {
      late Person parent;
      late UniqueSetNullChild winner;
      late UniqueSetNullChild loser;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          parent = await Person.db.insertRow(
            session,
            Person(id: const Uuid().v7obj(), name: 'unique claim parent'),
            transaction: tx,
          );
          winner = await UniqueSetNullChild.db.insertRow(
            session,
            UniqueSetNullChild(
              id: const Uuid().v7obj(),
              name: 'first claimer',
              parentId: parent.id,
            ),
            transaction: tx,
          );
        });

        loser = UniqueSetNullChild(
          id: const Uuid().v7obj(),
          name: 'second claimer',
          parentId: parent.id,
        );

        final winnerHlc = await rowHlc(winner.id!);
        final parentHlc = await rowHlc(parent.id!);
        final winnerClaimHlc = winnerHlc.maxBetween(parentHlc);
        remoteInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: UniqueSetNullChild.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: winnerClaimHlc.datetime.advance(),
          hlcCounter: 0,
          data: loser,
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then both children remain visible and the loser is released to a '
          'null unique value.',
          () async {
            final rows = await UniqueSetNullChild.db.find(session);

            expect(rows, hasLength(2));
            expect(
              rows.singleWhere((row) => row.id == winner.id).parentId,
              parent.id,
            );
            expect(
              rows.singleWhere((row) => row.id == loser.id).parentId,
              isNull,
            );
          },
        );
      });
    },
  );

  group(
    'Given two databases and two remote inserts that claim the same unique '
    'value with identical HLCs from different nodes,',
    () {
      late CrdtDatabaseSession singleBatchSession;
      late CrdtDatabaseSession splitBatchSession;
      late Unique olderClaimRow;
      late Unique newerClaimRow;
      late CrdtMergeInsert olderClaimInsert;
      late CrdtMergeInsert newerClaimInsert;

      setUp(() async {
        singleBatchSession = session;
        splitBatchSession = CrdtDatabaseSession.wraps(
          await createAdditionalTestSession(),
          syncTables: [Unique.t],
        );
        await splitBatchSession.db.initialize();

        // The HLC node id is the only tie-break between the two claims.
        final nodeIds = [const Uuid().v7obj(), const Uuid().v7obj()]
          ..sort((left, right) => left.uuid.compareTo(right.uuid));
        final claimDatetime = DateTime.now().toUtc();

        olderClaimRow = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        newerClaimRow = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        olderClaimInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: olderClaimRow.id!,
          uuidNodeId: nodeIds.first,
          hlcDatetime: claimDatetime,
          hlcCounter: 0,
          data: olderClaimRow,
        );
        newerClaimInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: newerClaimRow.id!,
          uuidNodeId: nodeIds.last,
          hlcDatetime: claimDatetime,
          hlcCounter: 0,
          data: newerClaimRow,
        );
      });

      group(
        'when one database merges one batch and the other merges split '
        'batches in reverse arrival order,',
        () {
          setUp(() async {
            await singleBatchSession.db.mergeChanges(
              [newerClaimInsert, olderClaimInsert],
              scopeId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [newerClaimInsert],
              scopeId: testCrdtUserId,
            );
            await splitBatchSession.db.mergeChanges(
              [olderClaimInsert],
              scopeId: testCrdtUserId,
            );
          });

          test(
            'then both databases keep the node-id tie-break winner and '
            'release the loser to the same conflict-free value.',
            () async {
              for (final databaseSession in [
                singleBatchSession,
                splitBatchSession,
              ]) {
                final rows = await Unique.db.find(databaseSession);

                expect(rows, hasLength(2));
                expect(
                  rows.singleWhere((row) => row.id == olderClaimRow.id).name,
                  'shared-name',
                );
                expect(
                  rows.singleWhere((row) => row.id == newerClaimRow.id).name,
                  'shared-name__conflict__${newerClaimRow.id!.uuid}',
                );
              }
            },
          );
        },
      );
    },
  );

  group(
    'Given a visible UniqueUuid row claiming a UUID unique value and a newer '
    'remote insert that claims the same value,',
    () {
      final sharedValue = const Uuid().v7obj();
      late UniqueUuid winner;
      late UniqueUuid loser;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        winner = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => UniqueUuid.db.insertRow(
            session,
            UniqueUuid(id: const Uuid().v7obj(), value: sharedValue),
            transaction: tx,
          ),
        );

        loser = UniqueUuid(id: const Uuid().v7obj(), value: sharedValue);
        remoteInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: UniqueUuid.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: (await rowHlc(winner.id!)).datetime.advance(),
          hlcCounter: 0,
          data: loser,
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then both rows remain visible and the incoming insert receives a '
          'deterministic conflict-free UUID unique value.',
          () async {
            final rows = await UniqueUuid.db.find(session);
            final expectedConflictValue = const Uuid().v5obj(
              Namespace.oid.value,
              '${UniqueUuid.t.tableName}.${UniqueUuid.t.value.columnName}:'
              '${sharedValue.uuid}__conflict__${loser.id!.uuid}',
            );

            expect(rows, hasLength(2));
            expect(
              rows.singleWhere((row) => row.id == winner.id).value,
              sharedValue,
            );
            expect(
              rows.singleWhere((row) => row.id == loser.id).value,
              expectedConflictValue,
            );
          },
        );
      });
    },
  );

  group(
    'Given a unique value previously claimed by a locally deleted row and a '
    'remote insert that claims it,',
    () {
      late Unique deletedRow;
      late Unique incomingRow;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        deletedRow = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(
            session,
            Unique(id: const Uuid().v7obj(), name: 'shared-name'),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.deleteRow(session, deletedRow, transaction: tx),
        );

        incomingRow = Unique(id: const Uuid().v7obj(), name: 'shared-name');
        remoteInsert = CrdtMergeInsert(
          uuidScopeId: testCrdtUserId,
          tableName: Unique.t.tableName,
          uuidRowId: incomingRow.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: (await rowHlc(deletedRow.id!)).datetime.advance(),
          hlcCounter: 0,
          data: incomingRow,
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteInsert],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the hidden claim does not conflict and the incoming row keeps '
          'the unique value.',
          () async {
            final rows = await Unique.db.find(session);

            expect(rows, hasLength(1));
            expect(rows.single.id, incomingRow.id);
            expect(rows.single.name, 'shared-name');
          },
        );

        test(
          'then the hidden row keeps its released unique value.',
          () async {
            final hiddenRow = await Unique.db.findFirstRow(
              session,
              where: (t) => t.id.equals(deletedRow.id) & t.includeHiddenRows,
            );

            expect(hiddenRow, isNotNull);
            expect(
              hiddenRow!.name,
              'shared-name__hidden__${deletedRow.id!.uuid}',
            );
          },
        );
      });
    },
  );
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
