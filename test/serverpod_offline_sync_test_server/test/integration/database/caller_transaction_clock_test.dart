import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseQueryException, DatabaseSession;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

/// Tracked writes in a caller-owned transaction, which may catch a failed write
/// and still commit. A trigger stands in for a failed clock update.
void main() {
  initTestClientSession(createSessionPerTest: false);

  late DatabaseSession raw;
  late OfflineSyncDatabaseSession app;

  Future<void> openApp() async {
    raw = await createAdditionalTestSession();
    app = OfflineSyncDatabaseSession.wraps(
      raw,
      syncTables: testSyncTables,
      persistentUserId: testCrdtUserId,
    );
    await app.db.initialize();
  }

  Future<Hlc?> spaceClock() async => (await OfflineSyncSpace.db.findFirstRow(
    raw,
    where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
  ))!.lastHlc;

  Future<CrdtDataRow?> factOf(UuidValue rowId) => CrdtDataRow.db.findFirstRow(
    raw,
    where: (t) => t.uuidRowId.equals(rowId),
    include: CrdtDataRow.include(node: CrdtNode.include()),
  );

  Future<void> rejectClockUpdates(String table) => raw.db.unsafeExecute('''
CREATE TRIGGER reject_clock BEFORE UPDATE OF "lastHlc" ON "$table"
BEGIN
  SELECT RAISE(ABORT, 'rejected clock update');
END;
''');

  /// Inserts [rowId] in a caller-owned transaction that catches the insert's
  /// failure and commits, returning the caught error.
  Future<Object?> insertCatchingFailure(UuidValue rowId) async {
    Object? caught;
    await raw.db.transaction((tx) async {
      try {
        await Unique.db.insertRow(
          app,
          Unique(id: rowId, name: 'unstored clock'),
          transaction: tx,
        );
      } on Object catch (error) {
        caught = error;
      }
    });
    return caught;
  }

  group('Given a persistent-user wrapper whose user clock cannot be stored,', () {
    late Hlc clockBefore;
    late Hlc? spaceClockBefore;

    setUpAll(() async {
      await openApp();
      clockBefore = await persistedUserClock(raw, testCrdtUserId);
      spaceClockBefore = await spaceClock();
      await rejectClockUpdates('crdt_nodes');
    });

    group('when a caller-owned transaction catches the failed insert and commits,', () {
      late Object? caught;
      late Unique? row;
      late CrdtDataRow? fact;
      late Hlc clockAfter;
      late Hlc? spaceClockAfter;

      setUpAll(() async {
        final rowId = const Uuid().v7obj();
        caught = await insertCatchingFailure(rowId);

        row = await Unique.db.findById(app, rowId);
        fact = await factOf(rowId);
        clockAfter = await persistedUserClock(raw, testCrdtUserId);
        spaceClockAfter = await spaceClock();
      });

      test('then the insert fails.', () {
        expect(caught, isA<DatabaseQueryException>());
        expect(caught.toString(), contains('rejected clock update'));
      });

      test('then neither the row nor its CRDT metadata is committed.', () {
        expect(row, isNull);
        expect(fact, isNull);
      });

      test('then both clocks keep their committed values.', () {
        expect(clockAfter, clockBefore);
        expect(spaceClockAfter, spaceClockBefore);
      });
    });
  });

  group(
    'Given a persistent-user wrapper whose space high-water mark cannot be stored,',
    () {
      late Hlc clockBefore;
      late Hlc? spaceClockBefore;

      setUpAll(() async {
        await openApp();
        clockBefore = await persistedUserClock(raw, testCrdtUserId);
        spaceClockBefore = await spaceClock();
        await rejectClockUpdates('offline_sync_spaces');
      });

      group(
        'when a caller-owned transaction catches the failed insert and commits,',
        () {
          late Object? caught;
          late Unique? row;
          late CrdtDataRow? fact;
          late Hlc clockAfter;
          late Hlc? spaceClockAfter;

          setUpAll(() async {
            final rowId = const Uuid().v7obj();
            caught = await insertCatchingFailure(rowId);

            row = await Unique.db.findById(app, rowId);
            fact = await factOf(rowId);
            clockAfter = await persistedUserClock(raw, testCrdtUserId);
            spaceClockAfter = await spaceClock();
          });

          test('then the insert fails.', () {
            expect(caught, isA<DatabaseQueryException>());
            expect(caught.toString(), contains('rejected clock update'));
          });

          test('then neither the row nor its CRDT metadata is committed.', () {
            expect(row, isNull);
            expect(fact, isNull);
          });

          test('then both clocks keep their committed values.', () {
            expect(clockAfter, clockBefore);
            expect(spaceClockAfter, spaceClockBefore);
          });
        },
      );
    },
  );

  group('Given a persistent-user wrapper,', () {
    setUpAll(openApp);

    group('when a caller-owned transaction writes twice through it and commits,', () {
      late List<Hlc> factClocks;
      late Hlc persistedClock;
      late Hlc? persistedSpaceClock;

      setUpAll(() async {
        final rowIds = [const Uuid().v7obj(), const Uuid().v7obj()];
        await raw.db.transaction((tx) async {
          for (final (index, rowId) in rowIds.indexed) {
            await Unique.db.insertRow(
              app,
              Unique(id: rowId, name: 'caller write $index'),
              transaction: tx,
            );
          }
        });

        factClocks = [for (final rowId in rowIds) (await factOf(rowId))!.hlc];
        persistedClock = await persistedUserClock(raw, testCrdtUserId);
        persistedSpaceClock = await spaceClock();
      });

      test('then the second write follows the first.', () {
        expect(factClocks[1].compareTo(factClocks[0]), greaterThan(0));
      });

      test('then the stored clocks cover the last write.', () {
        expect(persistedClock, factClocks[1]);
        expect(persistedSpaceClock, factClocks[1]);
      });
    });
  });
}
