import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    as client;
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  final syncTables = [
    client.Address.t,
    client.Person.t,
    client.Types.t,
    client.Unique.t,
  ];

  late CrdtDatabaseSession crdtSession;

  setUp(() async {
    crdtSession = CrdtDatabaseSession.wraps(testSession, syncTables: syncTables);
    await crdtSession.db.initialize();
  });

  group('Given a typed CRDT row', () {
    test(
      'when pending insert changes are collected then the row payload roundtrips with its original field types.',
      () async {
        final otherNodeId = const Uuid().v7obj();
        final insertedRow = await crdtSession.db.transactionForUser(
          testCrdtUserId,
          (tx) async {
            return client.Types.db.insertRow(
              crdtSession,
              client.Types(
                id: const Uuid().v7obj(),
                aBool: true,
                aDateTime: DateTime.utc(2026, 5, 8, 12, 34, 56),
                aText: 'text',
                anInt: 42,
                anInt64: BigInt.parse('9007199254740993'),
                aReal: 3.14,
                aBlob: _bytesToBlob([1, 2, 3, 4]),
                anEnum: client.TypesEnum.gamma,
                optionalText: 'optional',
                optionalUuid: const Uuid().v7obj(),
              ),
              transaction: tx,
            );
          },
        );

        final mergeSet = await crdtSession.db.collectPendingChanges(
          otherNodeId: otherNodeId,
          userId: testCrdtUserId,
        );

        final insert = mergeSet.inserts.single;
        final streamedRow = insert.data as client.Types;

        expect(insert.uuidRowId, insertedRow.id);
        expect(streamedRow.aDateTime, insertedRow.aDateTime);
        expect(streamedRow.optionalUuid, insertedRow.optionalUuid);
        expect(streamedRow.anInt64, insertedRow.anInt64);
        expect(streamedRow.anEnum, client.TypesEnum.gamma);
        expect(_blobToBytes(streamedRow.aBlob), _blobToBytes(insertedRow.aBlob));
      },
    );
  });

  group('Given typed CRDT field updates', () {
    test(
      'when pending update changes are collected then the field values roundtrip with their original Dart types.',
      () async {
        final otherNodeId = const Uuid().v7obj();
        final row = await crdtSession.db.transactionForUser(testCrdtUserId, (
          tx,
        ) async {
          return client.Types.db.insertRow(
            crdtSession,
            client.Types(
              id: const Uuid().v7obj(),
              aBool: true,
              aDateTime: DateTime.utc(2026, 1, 1),
              aText: 'text',
              anInt: 42,
              anInt64: BigInt.from(99),
              aReal: 3.14,
              aBlob: _bytesToBlob([0, 1, 2]),
              anEnum: client.TypesEnum.alpha,
              optionalText: 'optional',
            ),
            transaction: tx,
          );
        });

        final rowMetadata = await CrdtDataRow.db.findFirstRow(
          testSession,
          where: (t) => t.uuidRowId.equals(row.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        final updatedRow = row.copyWith(
          aDateTime: DateTime.utc(2027, 1, 2, 3, 4, 5),
          optionalUuid: const Uuid().v7obj(),
          anInt64: BigInt.parse('12345678901234567890'),
          aBlob: _bytesToBlob([7, 8, 9]),
          anEnum: client.TypesEnum.beta,
        );

        await crdtSession.db.transactionForUser(testCrdtUserId, (tx) async {
          await client.Types.db.updateRow(
            crdtSession,
            updatedRow,
            columns: (t) => [
              t.aDateTime,
              t.optionalUuid,
              t.anInt64,
              t.aBlob,
              t.anEnum,
            ],
            transaction: tx,
          );
        });

        await crdtSession.db.recordSyncCheckpoint(
          otherNodeId,
          rowMetadata!.hlc,
          userId: testCrdtUserId,
        );

        final mergeSet = await crdtSession.db.collectPendingChanges(
          otherNodeId: otherNodeId,
          userId: testCrdtUserId,
        );
        final updates = {
          for (final update in mergeSet.updates) update.columnName: update,
        };

        expect(
          updates[client.Types.t.aDateTime.columnName]!.value,
          updatedRow.aDateTime,
        );
        expect(
          updates[client.Types.t.optionalUuid.columnName]!.value,
          updatedRow.optionalUuid,
        );
        expect(
          updates[client.Types.t.anInt64.columnName]!.value,
          updatedRow.anInt64,
        );
        expect(
          updates[client.Types.t.anEnum.columnName]!.value,
          client.TypesEnum.beta,
        );
        expect(
          _blobToBytes(
            updates[client.Types.t.aBlob.columnName]!.value as ByteData,
          ),
          _blobToBytes(updatedRow.aBlob),
        );
      },
    );
  });
}

ByteData _bytesToBlob(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

List<int> _blobToBytes(ByteData value) => value.buffer.asUint8List();
