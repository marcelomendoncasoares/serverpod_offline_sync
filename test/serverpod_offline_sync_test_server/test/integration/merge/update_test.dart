import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeSet;

  group(
    'Given a table with an existing unchanged row and a remote update for one of its columns,',
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
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.advance(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
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
    'Given a table with an existing row updated locally and an older remote update for the same column,',
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
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: remoteNodeId,
          hlcDatetime: localFieldHlc.datetime.retreat(),
          hlcCounter: localFieldHlc.counter,
          columnName: Person.t.name.columnName,
          value: 'older remote',
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
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
    'Given an empty table and a remote update for a non-existing row,',
    () {
      late UuidValue remoteNodeId;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        remoteNodeId = const Uuid().v7obj();

        remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: const Uuid().v7obj(),
          uuidNodeId: remoteNodeId,
          hlcDatetime: DateTime.now().toUtc(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated remotely',
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
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

  group(
    'Given a table with a row hidden by a remote delete and a newer remote update,',
    () {
      late Person person;
      late CrdtMergeDelete remoteDelete;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        person = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(
            session,
            Person(name: 'hidden row'),
            transaction: tx,
          ),
        );

        final crdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(person.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        remoteDelete = CrdtMergeDelete(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: crdtRow!.hlc.datetime.advance(),
          hlcCounter: 0,
          clFlag: 2,
          reason: CrdtDataDeletedReason.userDelete,
        );
        await session.db.mergeChanges(
          [remoteDelete],
          scopeId: testCrdtUserId,
        );

        remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: Person.t.tableName,
          uuidRowId: person.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: remoteDelete.hlc.datetime.advance(),
          hlcCounter: 0,
          columnName: Person.t.name.columnName,
          value: 'updated while hidden',
        );
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            [remoteUpdate],
            scopeId: testCrdtUserId,
          );
        });

        test('then the update does not resurrect the hidden row.', () async {
          expect(await Person.db.findById(session, person.id!), isNull);
        });

        test('then the field value is merged into the hidden row.', () async {
          final hiddenRow = await Person.db.findFirstRow(
            session,
            where: (t) => t.id.equals(person.id) & t.includeHiddenRows,
          );
          final field = await CrdtDataField.db.findFirstRow(
            session,
            where: (t) =>
                t.row.uuidRowId.equals(person.id) &
                t.column.name.equals(Person.t.name.columnName),
            include: CrdtDataField.include(node: CrdtNode.include()),
          );

          expect(hiddenRow, isNotNull);
          expect(hiddenRow!.name, remoteUpdate.value);
          expect(field, isNotNull);
          expect(field!.hlc, remoteUpdate.hlc);
        });
      });

      group('when merging together with a newer remote restore,', () {
        setUp(() async {
          final remoteRestore = CrdtMergeDelete(
            uuidScopeId: testCrdtUserId,
            tableName: Person.t.tableName,
            uuidRowId: person.id!,
            uuidNodeId: const Uuid().v7obj(),
            hlcDatetime: remoteUpdate.hlc.datetime.advance(),
            hlcCounter: 0,
            clFlag: 3,
            reason: CrdtDataDeletedReason.userReinsert,
          );

          await session.db.mergeChanges(
            [remoteUpdate, remoteRestore],
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the restored row becomes visible with the merged update value.',
          () async {
            final row = await Person.db.findById(session, person.id!);

            expect(row, isNotNull);
            expect(row!.name, remoteUpdate.value);
          },
        );
      });
    },
  );

  group(
    'Given a remote update that loses a composite unique conflict,',
    () {
      late UniqueComposite loser;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueComposite.db.insertRow(
            session,
            UniqueComposite(
              id: const Uuid().v7obj(),
              scope: 'left-scope',
              value: 'shared-value',
            ),
            transaction: tx,
          );
          loser = await UniqueComposite.db.insertRow(
            session,
            UniqueComposite(
              id: const Uuid().v7obj(),
              scope: 'right-scope',
              value: 'shared-value',
            ),
            transaction: tx,
          );
        });

        final loserCrdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(loser.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: UniqueComposite.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: loserCrdtRow!.hlc.datetime.advance(),
          hlcCounter: loserCrdtRow.hlc.counter,
          columnName: UniqueComposite.t.scope.columnName,
          value: 'left-scope',
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the losing row receives conflict-free composite unique values.',
          () async {
            final row = await UniqueComposite.db.findById(session, loser.id!);

            expect(row, isNotNull);
            expect(row!.scope, 'left-scope__conflict__${loser.id!.uuid}');
            expect(row.value, 'shared-value__conflict__${loser.id!.uuid}');
          },
        );

        test(
          'then the silently released unique column is not authored as a field update.',
          () async {
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(loser.id),
              include: CrdtDataField.include(
                column: CrdtSchemaColumn.include(),
                node: CrdtNode.include(),
              ),
            );
            final authoredFields = [
              for (final field in fields)
                if (field.hlc == remoteUpdate.hlc) field,
            ];

            expect(authoredFields, hasLength(1));
            expect(
              authoredFields.single.column!.name,
              UniqueComposite.t.scope.columnName,
            );
          },
        );
      });
    },
  );

  group(
    'Given a remote update that loses a composite unique conflict with a stable discriminator,',
    () {
      late UniqueDiscriminator loser;
      late CrdtMergeUpdate remoteUpdate;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueDiscriminator.db.insertRow(
            session,
            UniqueDiscriminator(
              id: const Uuid().v7obj(),
              categoryId: 7,
              name: 'shared-name',
            ),
            transaction: tx,
          );
          loser = await UniqueDiscriminator.db.insertRow(
            session,
            UniqueDiscriminator(
              id: const Uuid().v7obj(),
              categoryId: 7,
              name: 'original-name',
            ),
            transaction: tx,
          );
        });

        final loserCrdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(loser.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: UniqueDiscriminator.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: loserCrdtRow!.hlc.datetime.advance(),
          hlcCounter: loserCrdtRow.hlc.counter,
          columnName: UniqueDiscriminator.t.name.columnName,
          value: 'shared-name',
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the losing row keeps the discriminator and receives a conflict-free name.',
          () async {
            final row = await UniqueDiscriminator.db.findById(session, loser.id!);

            expect(row, isNotNull);
            expect(row!.categoryId, 7);
            expect(row.name, 'shared-name__conflict__${loser.id!.uuid}');
          },
        );

        test(
          'then the stable discriminator does not receive CRDT field metadata.',
          () async {
            final fields = await CrdtDataField.db.find(
              session,
              where: (t) => t.row.uuidRowId.equals(loser.id),
              include: CrdtDataField.include(
                column: CrdtSchemaColumn.include(),
                node: CrdtNode.include(),
              ),
            );

            expect(fields, hasLength(1));
            expect(fields.first.column!.name, UniqueDiscriminator.t.name.columnName);
            expect(fields.first.hlc, remoteUpdate.hlc);
          },
        );
      });
    },
  );

  group(
    'Given a remote update that loses a UUID unique conflict,',
    () {
      final sharedValue = const Uuid().v7obj();
      final originalLoserValue = const Uuid().v7obj();
      late UniqueUuid loser;

      setUp(() async {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await UniqueUuid.db.insertRow(
            session,
            UniqueUuid(id: const Uuid().v7obj(), value: sharedValue),
            transaction: tx,
          );
          loser = await UniqueUuid.db.insertRow(
            session,
            UniqueUuid(id: const Uuid().v7obj(), value: originalLoserValue),
            transaction: tx,
          );
        });

        final loserCrdtRow = await CrdtDataRow.db.findFirstRow(
          session,
          where: (t) => t.uuidRowId.equals(loser.id),
          include: CrdtDataRow.include(node: CrdtNode.include()),
        );

        final remoteUpdate = CrdtMergeUpdate(
          uuidScopeId: testCrdtUserId,
          tableName: UniqueUuid.t.tableName,
          uuidRowId: loser.id!,
          uuidNodeId: const Uuid().v7obj(),
          hlcDatetime: loserCrdtRow!.hlc.datetime.advance(),
          hlcCounter: loserCrdtRow.hlc.counter,
          columnName: UniqueUuid.t.value.columnName,
          value: sharedValue,
        );

        mergeSet = [remoteUpdate];
      });

      group('when merging,', () {
        setUp(() async {
          await session.db.mergeChanges(
            mergeSet,
            scopeId: testCrdtUserId,
          );
        });

        test(
          'then the losing row receives a deterministic conflict-free UUID unique value.',
          () async {
            final row = await UniqueUuid.db.findById(session, loser.id!);
            final expectedConflictValue = const Uuid().v5obj(
              Namespace.oid.value,
              '${UniqueUuid.t.tableName}.${UniqueUuid.t.value.columnName}:'
              '${sharedValue.uuid}__conflict__${loser.id!.uuid}',
            );

            expect(row, isNotNull);
            expect(row!.value, expectedConflictValue);
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
