import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given an empty person table, ', () {
    late UuidValue remoteNodeId;
    late Person remotePerson;
    late CrdtMergeInsert remoteInsert;

    setUp(() {
      remoteNodeId = const Uuid().v7obj();
      remotePerson = Person(
        id: const Uuid().v7obj(),
        name: 'remote',
      );

      final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
      remoteInsert = _mergeInsert(remotePerson, hlc);
    });

    group('when merging a remote insert, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          CrdtMergeSet(inserts: [remoteInsert]),
          userId: testCrdtUserId,
        );
      });

      test('then the person row is inserted into the domain table.', () async {
        final row = await Person.db.findById(session, remotePerson.id!);

        expect(row, isNotNull);
        expect(row!.name, remotePerson.name);
      });

      test('then the remote CRDT row metadata is recorded.', () async {
        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(remotePerson.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        expect(crdtRow, isNotNull);
        expect(crdtRow!.node!.uuidNodeId, remoteNodeId);
        expect(crdtRow.toHlcForNode(crdtRow.node!.uuidNodeId), remoteInsert.hlc);
      });
    });

    group('when merging an insert and a newer update for the same row, ', () {
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          rowId: remotePerson.id!,
          nodeId: remoteNodeId,
          hlcDatetime: remoteInsert.hlc.datetime.add(const Duration(milliseconds: 1)),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        await session.db.mergeChanges(
          CrdtMergeSet(
            inserts: [remoteInsert],
            updates: [remoteUpdate],
          ),
          userId: testCrdtUserId,
        );
      });

      test('then the newer field value wins.', () async {
        final row = await Person.db.findById(session, remotePerson.id!);

        expect(row, isNotNull);
        expect(row!.name, remoteUpdate.value);
      });

      test(
        'then the CRDT field metadata is recorded for the updated column.',
        () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(remotePerson.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNotNull);
          expect(field!.node!.uuidNodeId, remoteNodeId);
          expect(field.toHlcForNode(field.node!.uuidNodeId), remoteUpdate.hlc);
        },
      );
    });
  });

  group('Given a person table with an existing row updated locally, ', () {
    late Person person;
    late Hlc localFieldHlc;
    late UuidValue remoteNodeId;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'local'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.updateRow(
          session,
          person.copyWith(name: 'newer local'),
          columns: (t) => [t.name],
          transaction: tx,
        ),
      );

      final field = await CrdtDataField.db.findFirstRow(
        session,
        where: (t) =>
            t.row.uuidRowId.equals(person.id) &
            t.column.name.equals(Person.t.name.columnName),
        include: CrdtDataField.include(node: CrdtNode.include()),
      );

      localFieldHlc = field!.toHlcForNode(field.node!.uuidNodeId);
      remoteNodeId = const Uuid().v7obj();
    });

    group('when merging an older remote update for the same column, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          CrdtMergeSet(
            updates: [
              CrdtMergeUpdate(
                tableName: Person.t.tableName,
                rowId: person.id!,
                nodeId: remoteNodeId,
                hlcDatetime: localFieldHlc.datetime.subtract(
                  const Duration(milliseconds: 1),
                ),
                hlcCounter: localFieldHlc.counter,
                columnName: Person.t.name.columnName,
                value: 'older remote',
              ),
            ],
          ),
          userId: testCrdtUserId,
        );
      });

      test('then the local field value is preserved.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, 'newer local');
      });
    });
  });

  group('Given a person table with an existing row, ', () {
    late Person person;
    late Hlc rowHlc;
    late UuidValue remoteNodeId;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'remote delete'),
          transaction: tx,
        ),
      );

      final crdtRow = await CrdtDataRow.db.findFirstRow(
        session,
        where: (t) => t.uuidRowId.equals(person.id),
        include: CrdtDataRow.include(node: CrdtNode.include()),
      );
      rowHlc = crdtRow!.toHlcForNode(crdtRow.node!.uuidNodeId);
      remoteNodeId = const Uuid().v7obj();
    });

    group('when merging a newer delete, ', () {
      late CrdtMergeDelete remoteDelete;

      setUp(() async {
        remoteDelete = CrdtMergeDelete(
          tableName: Person.t.tableName,
          rowId: person.id!,
          nodeId: remoteNodeId,
          hlcDatetime: rowHlc.datetime.add(const Duration(milliseconds: 1)),
          hlcCounter: 0,
          isDeleted: true,
        );

        await session.db.mergeChanges(
          CrdtMergeSet(deletes: [remoteDelete]),
          userId: testCrdtUserId,
        );
      });

      test('then the row is hidden by the tombstone.', () async {
        expect(await Person.db.findById(session, person.id!), isNull);
        expect(await Person.db.findById(testSession, person.id!), isNotNull);
      });

      test('then the tombstone is recorded as deleted.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isTrue);
        expect(tombstone.toHlcForNode(tombstone.node!.uuidNodeId), remoteDelete.hlc);
      });
    });

    group('when merging a newer restore after a delete, ', () {
      setUp(() async {
        final deleteHlc = Hlc(
          rowHlc.datetime.add(const Duration(milliseconds: 1)),
          0,
          remoteNodeId,
        );
        final restoreHlc = Hlc(
          deleteHlc.datetime.add(const Duration(milliseconds: 1)),
          0,
          remoteNodeId,
        );

        await session.db.mergeChanges(
          CrdtMergeSet(
            deletes: [
              CrdtMergeDelete(
                tableName: Person.t.tableName,
                rowId: person.id!,
                nodeId: remoteNodeId,
                hlcDatetime: deleteHlc.datetime,
                hlcCounter: deleteHlc.counter,
                isDeleted: true,
              ),
              CrdtMergeDelete(
                tableName: Person.t.tableName,
                rowId: person.id!,
                nodeId: remoteNodeId,
                hlcDatetime: restoreHlc.datetime,
                hlcCounter: restoreHlc.counter,
                isDeleted: false,
              ),
            ],
          ),
          userId: testCrdtUserId,
        );
      });

      test('then the row becomes visible again.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, person.name);
      });

      test('then the tombstone is recorded as restored.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isFalse);
      });
    });
  });
}

CrdtMergeInsert _mergeInsert(Person person, Hlc hlc) {
  return CrdtMergeInsert(
    tableName: Person.t.tableName,
    rowId: person.id!,
    nodeId: hlc.nodeId,
    hlcDatetime: hlc.datetime,
    hlcCounter: hlc.counter,
    data: {
      'id': person.id,
      'name': person.name,
      'surname': person.surname,
      'organizationId': person.organizationId,
      'oldCompanyId': person.oldCompanyId,
    },
  );
}
