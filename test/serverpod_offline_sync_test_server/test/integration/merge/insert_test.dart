import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeSet;

  group('Given an empty table and a remote insert, ', () {
    late UuidValue remoteNodeId;
    late Person remotePerson;
    late CrdtMergeInsert remoteInsert;

    setUp(() {
      remoteNodeId = const Uuid().v7obj();
      remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

      final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
      remoteInsert = CrdtMergeInsert(
        tableName: Person.t.tableName,
        uuidRowId: remotePerson.id!,
        uuidNodeId: hlc.nodeId,
        hlcDatetime: hlc.datetime,
        hlcCounter: hlc.counter,
        data: remotePerson,
      );

      mergeSet = [remoteInsert];
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );
      });

      test('then the remote row is inserted into the domain table.', () async {
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
        expect(crdtRow.hlc, remoteInsert.hlc);
      });
    });
  });

  group(
    'Given an empty table, a remote insert and a newer remote update for the same row, ',
    () {
      late UuidValue remoteNodeId;
      late Person remotePerson;
      late CrdtMergeInsert remoteInsert;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() {
        remoteNodeId = const Uuid().v7obj();
        remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

        final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: hlc.nodeId,
          hlcDatetime: hlc.datetime,
          hlcCounter: hlc.counter,
          data: remotePerson,
        );

        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: remoteInsert.hlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeSet = [remoteInsert, remoteUpdate];
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the newer remote field value wins.', () async {
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
            expect(field.hlc, remoteUpdate.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and a newer insert '
    'with the same row ID but different data, ',
    () {
      late Person person;
      late Hlc localRowHlc;
      late Hlc localFieldHlc;
      late Person remotePerson;
      late UuidValue remoteNodeId;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'original'),
            transaction: tx,
          ),
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'local'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        final field = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(person.id) &
              t.column.name.equals(Person.t.name.columnName),
          include: CrdtDataField.include(
            node: CrdtNode.include(),
            row: CrdtDataRow.include(node: CrdtNode.include()),
          ),
        );

        localRowHlc = field!.row!.hlc;
        localFieldHlc = field.hlc;
        remoteNodeId = const Uuid().v7obj();

        remotePerson = person.copyWith(name: 'remote');
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.advance(),
          hlcCounter: localFieldHlc.counter,
          data: remotePerson,
        );

        mergeSet = [remoteInsert];
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the row field value is updated to the remote value.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, remotePerson.name);
        });

        // We can't update the row original HLC because it would break the causal
        // order of the operations on the node.
        test('then the CRDT row metadata is not updated.', () async {
          final row = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.uuidRowId.equals(person.id),
            include: CrdtDataRow.include(node: CrdtNode.include()),
          );

          expect(row!.hlc, localRowHlc);
        });

        // Since different nodes will have different HLCs for the row, we need to
        // ensure that no future conflict resolution on the node with the older HLC
        // will fallback to the row-level HLC. This is done by forcefully touching
        // all columns of the row with the new HLC.
        test(
          'then each column of the table receives a CRDT field metadata record for the remote HLC.',
          () async {
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(fields.length, Person.t.columns.length - 2); // -2 for id and scopeId
            expect(
              fields.map((f) => f.hlc),
              everyElement(remoteInsert.hlc),
            );
          },
        );

        // For the same reason above, we need to touch the tombstone for the row
        // to ensure that tombstone conflict resolution never falls back to the
        // row-level HLC.
        test(
          'then the initial visible generation metadata is lazily touched.',
          () async {
            final tombstone = await CrdtDataDeleted.db.findFirstRow(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
              include: CrdtDataDeleted.include(node: CrdtNode.include()),
            );

            expect(tombstone, isNotNull);
            expect(tombstone!.isDeleted, isFalse);
            expect(tombstone.clFlag, 1);
            expect(tombstone.reason, CrdtDataDeletedReason.userInsert);
            expect(tombstone.hlc, remoteInsert.hlc);
            expect(tombstone.node!.uuidNodeId, remoteNodeId);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing row updated locally and a remote insert '
    'that is after the insert and before the update for the same row ID but '
    'different data, ',
    () {
      late Person person;
      late Hlc localRowHlc;
      late Hlc localUpdatedFieldHlc;
      late Person remotePerson;
      late UuidValue remoteNodeId;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'original', surname: 'original'),
            transaction: tx,
          ),
        );

        final row = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        localRowHlc = row!.hlc;
        remoteNodeId = const Uuid().v7obj();

        remotePerson = person.copyWith(name: 'remote', surname: 'remote');
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localRowHlc.datetime.advance(),
          hlcCounter: localRowHlc.counter,
          data: remotePerson,
        );

        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.updateRow(
            session,
            person.copyWith(name: 'updated locally'),
            columns: (t) => [t.name],
            transaction: tx,
          ),
        );

        final localNameField = await CrdtDataField.db.findFirstRow(
          session,
          where: (t) =>
              t.row.uuidRowId.equals(person.id) &
              t.column.name.equals(Person.t.name.columnName),
          include: CrdtDataField.include(node: CrdtNode.include()),
        );
        localUpdatedFieldHlc = localNameField!.hlc;

        mergeSet = [remoteInsert];
      });

      group('when merging, ', () {
        late Person mergedPerson;

        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );

          final row = await Person.db.findById(session, person.id!);
          mergedPerson = row!;
        });

        test('then the row field value is updated to the remote value.', () async {
          expect(mergedPerson.surname, remotePerson.surname);
        });

        test('then the local newer column update is preserved.', () async {
          expect(mergedPerson.name, 'updated locally');
        });

        // Local updates that have a newer HLC than the remote insert should still
        // be preserved as in any HLC conflict resolution (last writer wins).
        test(
          'then the CRDT field metadata of the local newer column is not updated.',
          () async {
            final field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(person.id) &
                  t.column.name.equals(Person.t.name.columnName),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(field, isNotNull);
            expect(field!.node!.uuidNodeId, localUpdatedFieldHlc.nodeId);
            expect(field.hlc, localUpdatedFieldHlc);
          },
        );
      });
    },
  );

  group(
    'Given a table with an existing row and an older remote insert for the same row ID, ',
    () {
      late Person person;
      late Hlc localRowHlc;
      late CrdtMergeInsert remoteInsert;

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
        localRowHlc = row!.hlc;

        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: localRowHlc.datetime.retreat(),
          hlcCounter: localRowHlc.counter,
          data: person.copyWith(name: 'older remote'),
        );
        mergeSet = [remoteInsert];
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the local row data is preserved.', () async {
          final row = await Person.db.findById(session, person.id!);

          expect(row, isNotNull);
          expect(row!.name, 'local');
        });

        test('then the CRDT row metadata is not updated.', () async {
          final row = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.uuidRowId.equals(person.id),
            include: CrdtDataRow.include(node: CrdtNode.include()),
          );

          expect(row!.hlc, localRowHlc);
          expect(row.node!.uuidNodeId, localRowHlc.nodeId);
        });

        test(
          'then no CRDT field metadata is recorded for the ignored insert.',
          () async {
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(person.id),
            );

            expect(fields, isEmpty);
          },
        );
      });
    },
  );

  group(
    'Given an empty table and a merge set that lists a newer remote update '
    'before its remote insert, ',
    () {
      late Person remotePerson;
      late CrdtMergeInsert remoteInsert;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() {
        final remoteNodeId = const Uuid().v7obj();
        remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

        final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: hlc.nodeId,
          hlcDatetime: hlc.datetime,
          hlcCounter: hlc.counter,
          data: remotePerson,
        );
        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: remoteInsert.hlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeSet = [remoteUpdate, remoteInsert];
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the operations are applied causally and the row holds the '
          'updated value.',
          () async {
            final row = await Person.db.findById(session, remotePerson.id!);

            expect(row, isNotNull);
            expect(row!.name, remoteUpdate.value);
          },
        );

        test(
          'then the CRDT field metadata records the update HLC.',
          () async {
            final field = await CrdtDataField.db.findFirstRow(
              session,
              where: (t) =>
                  t.row.uuidRowId.equals(remotePerson.id) &
                  t.column.name.equals(Person.t.name.columnName),
              include: CrdtDataField.include(node: CrdtNode.include()),
            );

            expect(field, isNotNull);
            expect(field!.hlc, remoteUpdate.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a remote insert and a newer remote update that were already merged, ',
    () {
      late Person remotePerson;
      late CrdtMergeUpdate remoteUpdate;
      late Hlc rowHlcAfterFirstMerge;
      late List<Hlc> fieldHlcsAfterFirstMerge;

      setUp(() async {
        final remoteNodeId = const Uuid().v7obj();
        remotePerson = Person(id: const Uuid().v7obj(), name: 'remote');

        final hlc = Hlc(DateTime.now().toUtc(), 0, remoteNodeId);
        final remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: hlc.nodeId,
          hlcDatetime: hlc.datetime,
          hlcCounter: hlc.counter,
          data: remotePerson,
        );
        remoteUpdate = CrdtMergeUpdate(
          tableName: Person.t.tableName,
          uuidRowId: remotePerson.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: remoteInsert.hlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );
        mergeSet = [remoteInsert, remoteUpdate];

        await session.db.mergeChanges(
          mergeSet,
          scopeId: testCrdtUserId,
        );

        final row = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(remotePerson.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );
        rowHlcAfterFirstMerge = row!.hlc;

        final fields = await CrdtDataField.db.find(
          session,
          where: (t) => t.row.uuidRowId.equals(remotePerson.id),
          include: CrdtDataField.include(node: CrdtNode.include()),
          orderBy: (t) => t.columnId,
        );
        fieldHlcsAfterFirstMerge = [for (final field in fields) field.hlc];
      });

      group('when the same merge set is replayed, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the row data does not change.', () async {
          final row = await Person.db.findById(session, remotePerson.id!);

          expect(row, isNotNull);
          expect(row!.name, remoteUpdate.value);
        });

        test('then the CRDT row and field metadata do not change.', () async {
          final row = await CrdtDataRow.db.findFirstRow(
            session,
            where: (t) => t.uuidRowId.equals(remotePerson.id),
            include: CrdtDataRow.include(node: CrdtNode.include()),
          );
          final fields = await CrdtDataField.db.find(
            session,
            where: (t) => t.row.uuidRowId.equals(remotePerson.id),
            include: CrdtDataField.include(node: CrdtNode.include()),
            orderBy: (t) => t.columnId,
          );

          expect(row!.hlc, rowHlcAfterFirstMerge);
          expect([for (final field in fields) field.hlc], fieldHlcsAfterFirstMerge);
        });

        test('then no tombstone metadata is created by the replay.', () async {
          final tombstone = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(remotePerson.id),
          );

          expect(tombstone, isNull);
        });
      });
    },
  );

  group(
    'Given a table with a row deleted in generation four and a newer remote insert payload, ',
    () {
      late Person person;
      late CrdtMergeInsert remoteInsert;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'deleted locally'),
            transaction: tx,
          ),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, person, transaction: tx),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, person, transaction: tx),
        );
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.deleteRow(session, person, transaction: tx),
        );

        final clFlag = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        remoteInsert = CrdtMergeInsert(
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: clFlag!.hlc.datetime.advance(),
          hlcCounter: clFlag.hlc.counter,
          data: person.copyWith(name: 'remote payload'),
        );
        mergeSet = [remoteInsert];
      });

      group('when merging, ', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test('then the row stays hidden.', () async {
          expect(await Person.db.findById(session, person.id!), isNull);
        });

        test('then the CRDT CLFlag stays at generation four.', () async {
          final clFlag = await CrdtDataDeleted.db.findFirstRow(
            session,
            where: (t) => t.row.uuidRowId.equals(person.id),
          );

          expect(clFlag, isNotNull);
          expect(clFlag!.clFlag, 4);
          expect(clFlag.reason, CrdtDataDeletedReason.userDelete);
        });
      });
    },
  );

  group(
    'Given an existing same-scope row whose CRDT tracker was lost, '
    'when merging a remote insert for the same row id,',
    () {
      late Person person;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'before recovery'),
            transaction: tx,
          ),
        );

        // Simulate lost metadata: the domain row stays, the tracker goes.
        // This is not expected to happen in practice as only a direct access
        // to the underlying database can corrupt the metadata.
        await CrdtDataRow.db.deleteWhere(
          testSession,
          where: (t) => t.uuidRowId.equals(person.id),
        );

        final remoteNodeId = const Uuid().v7obj();
        final hlc = Hlc.now(remoteNodeId);
        await session.db.mergeChanges(
          [
            CrdtMergeInsert(
              tableName: Person.t.tableName,
              uuidRowId: person.id!,
              uuidNodeId: remoteNodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
              data: Person(id: person.id, name: 'after recovery'),
            ),
          ],
          scopeId: testCrdtUserId,
        );
      });

      test('then the domain row is recovered with the merged values.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, 'after recovery');
      });

      test('then a single CRDT tracker is recreated for the scope.', () async {
        final crdtRows = await CrdtDataRow.db.find(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
        );

        expect(crdtRows, hasLength(1));
      });
    },
  );
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
