import 'package:serverpod_database/serverpod_database.dart' show DatabaseSession;
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

  for (final (rowName, table) in [
    ('the user clock', 'crdt_nodes'),
    ('the space high-water mark', 'offline_sync_spaces'),
  ]) {
    group('Given a caller-owned transaction where storing $rowName fails,', () {
      late Hlc clockBefore;
      late Hlc? spaceClockBefore;

      setUpAll(() async {
        await openApp();
        clockBefore = await persistedUserClock(raw, testCrdtUserId);
        spaceClockBefore = await spaceClock();
        await raw.db.unsafeExecute('''
CREATE TRIGGER reject_clock BEFORE UPDATE OF "lastHlc" ON "$table"
BEGIN
  SELECT RAISE(ABORT, 'rejected clock update');
END;
''');
      });

      group('when the caller catches the failed insert and commits,', () {
        late UuidValue rowId;
        late Object? caught;

        setUpAll(() async {
          rowId = const Uuid().v7obj();
          await raw.db.transaction((tx) async {
            try {
              await Unique.db.insertRow(
                app,
                Unique(id: rowId, name: 'unstored clock'),
                transaction: tx,
              );
              caught = null;
            } on Object catch (error) {
              caught = error;
            }
          });
        });

        test('then the insert fails.', () {
          expect(caught, isNotNull);
        });

        test('then neither the row nor its CRDT metadata is committed.', () async {
          expect(await Unique.db.findById(app, rowId), isNull);
          expect(await factOf(rowId), isNull);
        });

        test('then both clocks keep their committed values.', () async {
          expect(await persistedUserClock(raw, testCrdtUserId), clockBefore);
          expect(await spaceClock(), spaceClockBefore);
        });
      });
    });
  }

  group('Given a caller-owned transaction,', () {
    setUpAll(openApp);

    group('when the caller writes twice and commits,', () {
      late List<UuidValue> rowIds;
      late List<Hlc> factClocks;
      late Hlc persistedClock;
      late Hlc? persistedSpaceClock;

      setUpAll(() async {
        rowIds = [const Uuid().v7obj(), const Uuid().v7obj()];
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
