import 'dart:typed_data';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  final syncTables = [
    Address.t,
    Person.t,
    Types.t,
    Unique.t,
  ];

  late CrdtDatabaseSession crdtSession;

  setUp(() async {
    crdtSession = CrdtDatabaseSession.wraps(testSession, syncTables: syncTables);
    await crdtSession.db.initialize();
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
        final mergeSet = await crdtSession.db.collectPendingChanges(
          otherNodeId: const Uuid().v7obj(),
          userId: testCrdtUserId,
        );

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
        final mergeSet = await crdtSession.db.collectPendingChanges(
          otherNodeId: const Uuid().v7obj(),
          userId: testCrdtUserId,
        );

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
}

extension on List<int> {
  ByteData toBlob() => ByteData.sublistView(Uint8List.fromList(this));
}

extension on ByteData {
  List<int> toBytes() => buffer.asUint8List();
}
