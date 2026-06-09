import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  final syncTables = [
    Address.t,
    Person.t,
    Town.t,
    Types.t,
    Unique.t,
  ];

  late CrdtDatabaseSession crdtSession;
  late CrdtSync crdtSync;

  setUp(() async {
    crdtSession = CrdtDatabaseSession.wraps(testSession, syncTables: syncTables);
    await crdtSession.db.initialize();

    crdtSync = CrdtSync(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
  });

  group('Given an inserted typed CRDT row', () {
    late Types insertedRow;

    setUp(() async {
      insertedRow = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          return Types.db.insertRow(
            crdtSession,
            Types(
              id: const Uuid().v7obj(),
              aBool: true,
              aDateTime: DateTime.utc(2026, 5, 8, 12, 34, 56),
              aText: 'text',
              anInt: 42,
              anInt64: BigInt.parse('9007199254740993'),
              aReal: 3.14,
              aBlob: [1, 2, 3, 4].toBlob(),
              anEnum: TypesEnum.gamma,
              optionalText: 'optional',
              optionalUuid: const Uuid().v7obj(),
            ),
            transaction: tx,
          );
        },
      );
    });

    test(
      'when pending changes are collected '
      'then the row payload roundtrips with its original Dart type.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              peerNodeId: const Uuid().v7obj(),
              userId: testCrdtUserId,
              nodeCheckpoints: const [],
            )
            .toList();

        final insert = mergeSet.inserts.single;
        expect(insert.uuidRowId, insertedRow.id);
        expect(insert.data, isA<Types>());

        final recoveredData = insert.data as Types;
        expect(recoveredData.aDateTime, insertedRow.aDateTime);
        expect(recoveredData.optionalUuid, insertedRow.optionalUuid);
        expect(recoveredData.anInt64, insertedRow.anInt64);
        expect(recoveredData.anEnum, TypesEnum.gamma);
        expect(recoveredData.aBlob.toBytes(), insertedRow.aBlob.toBytes());
      },
    );
  });

  group('Given inserted CRDT rows and a sync batch size of two', () {
    late CrdtSync batchingCrdtSync;

    setUp(() async {
      batchingCrdtSync = CrdtSync(
        syncTables: syncTables,
        serializationManager: testSession.db.serializationManager,
        syncBatchSize: 2,
      );

      for (var i = 0; i < 3; i++) {
        await crdtSession.db.transactionForUser(
          testCrdtUserId,
          (tx) async {
            await Person.db.insertRow(
              crdtSession,
              Person(id: const Uuid().v7obj(), name: 'person-$i'),
              transaction: tx,
            );
          },
        );
      }
    });

    test(
      'when streaming an outbound sync batch '
      'then pending changes are chunked into merge chunk events.',
      () async {
        final events = await batchingCrdtSync
            .streamOutboundBatch(
              testSession,
              userId: testCrdtUserId,
              peerNodeId: const Uuid().v7obj(),
              nodeCheckpoints: const [],
            )
            .toList();

        final mergeChunks = events.whereType<CrdtSyncMergeChunk>().toList();

        expect(mergeChunks, hasLength(2));
        expect(mergeChunks.map((chunk) => chunk.changes.length), [2, 1]);
        final changes = mergeChunks.expand((chunk) => chunk.changes).toList();
        expect(changes.whereType<CrdtMergeInsert>(), hasLength(3));
        expect(events.last, isA<CrdtSyncEndOfBatch>());
      },
    );
  });

  group('Given an updated typed CRDT row', () {
    late Types row;
    late Types updatedRow;

    setUp(() async {
      row = await crdtSession.db.transactionForUser(testCrdtUserId, (
        tx,
      ) async {
        return Types.db.insertRow(
          crdtSession,
          Types(
            id: const Uuid().v7obj(),
            aBool: true,
            aDateTime: DateTime.utc(2026, 1, 1),
            aText: 'text',
            anInt: 42,
            anInt64: BigInt.from(99),
            aReal: 3.14,
            aBlob: [0, 1, 2].toBlob(),
            anEnum: TypesEnum.alpha,
            optionalText: 'optional',
          ),
          transaction: tx,
        );
      });

      updatedRow = row.copyWith(
        aDateTime: DateTime.utc(2027, 1, 2, 3, 4, 5),
        optionalUuid: const Uuid().v7obj(),
        anInt64: BigInt.parse('12345678901234567890'),
        aBlob: [7, 8, 9].toBlob(),
        anEnum: TypesEnum.beta,
      );

      await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) async {
          await Types.db.updateRow(
            crdtSession,
            updatedRow,
            transaction: tx,
          );
        },
      );
    });

    test(
      'when pending changes are collected '
      'then the field values roundtrip with their original Dart types.',
      () async {
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              peerNodeId: const Uuid().v7obj(),
              userId: testCrdtUserId,
              nodeCheckpoints: const [],
            )
            .toList();

        final updates = {
          for (final update in mergeSet.updates) update.columnName: update,
        };

        final aDateTime = updates[Types.t.aDateTime.columnName]!;
        final optionalUuid = updates[Types.t.optionalUuid.columnName]!;
        final anInt64 = updates[Types.t.anInt64.columnName]!;
        final anEnum = updates[Types.t.anEnum.columnName]!;
        final aBlob = updates[Types.t.aBlob.columnName]!;

        expect(aDateTime.value, updatedRow.aDateTime);
        expect(optionalUuid.value, updatedRow.optionalUuid);
        expect(anInt64.value, updatedRow.anInt64);
        expect(anEnum.value, TypesEnum.beta);
        expect((aBlob.value as ByteData).toBytes(), updatedRow.aBlob.toBytes());
      },
    );
  });

  group('Given an inserted row with an active set-null projection', () {
    late Person attemptedParent;
    late Town child;

    setUp(() async {
      await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
        attemptedParent = await Person.db.insertRow(
          crdtSession,
          Person(id: const Uuid().v7obj(), name: 'sync attempted mayor'),
          transaction: tx,
        );
        child = await Town.db.insertRow(
          crdtSession,
          Town(
            id: const Uuid().v7obj(),
            name: 'sync projected town',
            mayorId: attemptedParent.id,
          ),
          transaction: tx,
        );
      });

      await crdtSession.db.mergeChanges(
        [
          _deleteChange(
            tableName: Person.t.tableName,
            rowId: attemptedParent.id!,
            after: await _rowHlc(attemptedParent.id!),
          ),
        ],
        userId: testCrdtUserId,
      );
    });

    test(
      'when pending changes are collected '
      'then the insert payload carries the attempted foreign key value.',
      () async {
        final visibleChild = await Town.db.findById(crdtSession, child.id!);
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              peerNodeId: const Uuid().v7obj(),
              userId: testCrdtUserId,
              nodeCheckpoints: const [],
            )
            .toList();

        final childInsert = mergeSet.inserts
            .where(
              (insert) =>
                  insert.tableName == Town.t.tableName && insert.uuidRowId == child.id,
            )
            .single;
        final childPayload = childInsert.data as Town;

        expect(visibleChild, isNotNull);
        expect(visibleChild!.mayorId, isNull);
        expect(childPayload.mayorId, attemptedParent.id);
      },
    );
  });

  group('Given an updated row with an active set-null projection', () {
    late Town child;
    late UuidValue missingParentId;

    setUp(() async {
      missingParentId = const Uuid().v7obj();
      child = await crdtSession.db.transactionForUser(
        testCrdtUserId,
        (tx) => Town.db.insertRow(
          crdtSession,
          Town(id: const Uuid().v7obj(), name: 'sync projected update town'),
          transaction: tx,
        ),
      );

      final childHlc = await _rowHlc(child.id!);
      await crdtSession.db.mergeChanges(
        [
          CrdtMergeUpdate(
            tableName: Town.t.tableName,
            uuidRowId: child.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: childHlc.datetime.advance(),
            hlcCounter: 0,
            columnName: Town.t.mayorId.columnName,
            value: missingParentId,
          ),
        ],
        userId: testCrdtUserId,
      );
    });

    test(
      'when pending changes are collected '
      'then the update payload carries the attempted foreign key value.',
      () async {
        final visibleChild = await Town.db.findById(crdtSession, child.id!);
        final mergeSet = await crdtSync
            .collectPendingChanges(
              testSession,
              peerNodeId: const Uuid().v7obj(),
              userId: testCrdtUserId,
              nodeCheckpoints: const [],
            )
            .toList();

        final mayorUpdate = mergeSet.updates
            .where(
              (update) =>
                  update.tableName == Town.t.tableName &&
                  update.uuidRowId == child.id &&
                  update.columnName == Town.t.mayorId.columnName,
            )
            .single;

        expect(visibleChild, isNotNull);
        expect(visibleChild!.mayorId, isNull);
        expect(mayorUpdate.value, missingParentId);
      },
    );
  });

  test(
    'Given a CRDT node without local changes '
    'when synchronization checkpoints are created '
    'then one fresh checkpoint for the local node is included.',
    () async {
      final user = await CrdtUserManager(testSession).getOrCreate(testCrdtUserId);
      final sinceHlc = await crdtSync.createSyncSinceHlc(
        testSession,
        userId: testCrdtUserId,
        peerNodeId: const Uuid().v7obj(),
      );

      expect(sinceHlc.nodeCheckpoints, hasLength(1));
      expect(sinceHlc.nodeCheckpoints.single.nodeId, user.currentNode!.uuidNodeId);
      expect(
        sinceHlc.nodeCheckpoints.single,
        greaterThan(Hlc.zero(sinceHlc.nodeCheckpoints.single.nodeId)),
      );
    },
  );
}

CrdtMergeDelete _deleteChange({
  required String tableName,
  required UuidValue rowId,
  required Hlc after,
}) {
  return CrdtMergeDelete(
    tableName: tableName,
    uuidRowId: rowId,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: after.datetime.advance(),
    hlcCounter: 0,
    clFlag: 2,
    reason: CrdtDataDeletedReason.userDelete,
  );
}

Future<Hlc> _rowHlc(UuidValue rowId) async {
  final crdtRow = await CrdtDataRow.db.findFirstRow(
    testSession,
    where: (t) => t.uuidRowId.equals(rowId),
    include: CrdtDataRow.include(node: CrdtNode.include()),
  );

  return crdtRow!.hlc;
}

extension on List<int> {
  ByteData toBlob() => ByteData.sublistView(Uint8List.fromList(this));
}

extension on ByteData {
  List<int> toBytes() => buffer.asUint8List();
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
}
