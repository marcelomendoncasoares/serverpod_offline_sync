import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  late CrdtMergeSet mergeset;

  group('Given a table with an existing row and a newer remote delete, ', () {
    late Person person;
    late Hlc rowHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteDelete;

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
      rowHlc = crdtRow!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteDelete = CrdtMergeDelete(
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: rowHlc.datetime.advance(),
        hlcCounter: 0,
        isDeleted: true,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteDelete],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
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
        expect(tombstone.hlc, remoteDelete.hlc);
      });
    });
  });

  group('Given a table with a deleted row and a newer remote restore, ', () {
    late Person person;
    late Hlc tombstoneHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteRestore;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'remote delete'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      );
      tombstoneHlc = tombstone!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteRestore = CrdtMergeDelete(
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.advance(),
        hlcCounter: 0,
        isDeleted: false,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteRestore],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
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

  group('Given a table with a restored row and an older remote delete, ', () {
    late Person person;
    late Hlc tombstoneHlc;
    late UuidValue remoteNodeId;
    late CrdtMergeDelete remoteRestore;

    setUp(() async {
      person = await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'restored now'),
          transaction: tx,
        ),
      );

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.deleteRow(session, person, transaction: tx),
      );

      // Restore the row by inserting it again.
      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, person, transaction: tx),
      );

      final tombstone = await CrdtDataDeleted.db.findFirstRow(
        session,
        where: (t) => t.row.uuidRowId.equals(person.id),
        include: CrdtDataDeleted.include(node: CrdtNode.include()),
      );
      tombstoneHlc = tombstone!.hlc;
      remoteNodeId = const Uuid().v7obj();

      remoteRestore = CrdtMergeDelete(
        tableName: Person.t.tableName,
        uuidRowId: person.id!,
        uuidNodeId: remoteNodeId,
        hlcDatetime: tombstoneHlc.datetime.retreat(),
        hlcCounter: 0,
        isDeleted: true,
      );

      mergeset = CrdtMergeSet(
        inserts: [],
        updates: [],
        deletes: [remoteRestore],
      );
    });

    group('when merging, ', () {
      setUp(() async {
        await session.db.mergeChanges(
          mergeset,
          userId: testCrdtUserId,
        );
      });

      test('then the row is still visible.', () async {
        final row = await Person.db.findById(session, person.id!);

        expect(row, isNotNull);
        expect(row!.name, person.name);
      });

      test('then the tombstone is not updated.', () async {
        final tombstone = await CrdtDataDeleted.db.findFirstRow(
          session,
          where: (t) => t.row.uuidRowId.equals(person.id),
          include: CrdtDataDeleted.include(node: CrdtNode.include()),
        );

        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isFalse);
        expect(tombstone.hlc, tombstoneHlc);
      });
    });
  });
}

extension on DateTime {
  DateTime advance() => add(const Duration(milliseconds: 1));
  DateTime retreat() => subtract(const Duration(milliseconds: 1));
}
