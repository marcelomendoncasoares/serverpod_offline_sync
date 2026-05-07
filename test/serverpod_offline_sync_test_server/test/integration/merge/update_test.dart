import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeset;

  group(
    'Given a table with an existing unchanged row and a remote update for one of its columns, ',
    () {
      late Person person;
      late Hlc localFieldHlc;
      late UuidValue remoteNodeId;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'local'),
            transaction: tx,
          ),
        );

        final row = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        localFieldHlc = row!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.advance(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeset = CrdtMergeSet(
          inserts: [],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the row field value is updated to the remote value.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, 'updated remotely');
        });

        test('then the CRDT field metadata is inserted to the remote HLC.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNotNull);
          expect(field!.node!.uuidNodeId, remoteNodeId);
          expect(field.hlc, remoteUpdate.hlc);
        });
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and an older remote update for the same column, ',
    () {
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

        localFieldHlc = field!.hlc;
        remoteNodeId = const Uuid().v7obj();

        final remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.retreat(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'older remote',
        );

        mergeset = CrdtMergeSet(
          inserts: [],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the local field value is preserved.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, 'newer local');
        });

        test('then the CRDT field metadata is preserved.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNotNull);
          expect(field!.node!.uuidNodeId, localFieldHlc.nodeId);
          expect(field.hlc, localFieldHlc);
        });
      });
    },
  );

  group(
    'Given an empty table and a remote update for a non-existing row, ',
    () {
      late UuidValue remoteNodeId;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        remoteNodeId = const Uuid().v7obj();

        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: const Uuid().v7obj(),
          uuidNodeId: remoteNodeId,
          hlcDatetime: DateTime.now().toUtc(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeset = CrdtMergeSet(
          inserts: [],
          updates: [remoteUpdate],
          deletes: [],
        );
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeset,
            userId: testCrdtUserId,
          );
        });

        test('then the remote update is ignored.', () async {
          final row = await Person.db.findById(session, remoteUpdate.uuidRowId);

          expect(row, isNull);
        });

        test('then the CRDT field metadata is not inserted.', () async {
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(remoteUpdate.uuidRowId) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(field, isNull);
        });
      });
    },
  );
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
