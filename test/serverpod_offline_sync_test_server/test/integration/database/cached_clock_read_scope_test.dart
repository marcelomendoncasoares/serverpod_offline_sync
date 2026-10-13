import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/client_session.dart';
import '../test_tools/crdt_probes.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given an initialized client wrapper with a persistent space,', () {
    late QueryCountingDatabase database;
    late OfflineSyncDatabaseSession app;
    late Unique row;

    setUpAll(() async {
      database = QueryCountingDatabase((await createAdditionalTestSession()).db);
      app = OfflineSyncDatabaseSession(
        database,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await app.db.initialize();

      row = await Unique.db.insertRow(app, Unique(name: 'client read'));
    });

    group('when a plain transaction only reads a row,', () {
      late Unique? found;
      late int queries;
      late int rowsRead;

      setUpAll(() async {
        final queriesBefore = database.queryCount;
        final rowsBefore = database.rowsRead;

        found = await app.db.transaction(
          (tx) => Unique.db.findById(app, row.id!, transaction: tx),
        );

        queries = database.queryCount - queriesBefore;
        rowsRead = database.rowsRead - rowsBefore;
      });

      test('then the read uses only membership and domain queries.', () {
        expect(found?.name, 'client read');
        expect(queries, 3);
        expect(rowsRead, 2);
      });
    });
  });

  group('Given an initialized wrapper with a prepared space,', () {
    late QueryCountingDatabase database;
    late OfflineSyncDatabaseSession app;
    late Unique row;

    setUpAll(() async {
      database = QueryCountingDatabase((await createAdditionalTestSession()).db);
      app = OfflineSyncDatabaseSession(database, syncTables: testSyncTables);
      await app.db.initialize();

      row = await app.db.transactionForUser(
        testCrdtUserId,
        (tx) => Unique.db.insertRow(
          app,
          Unique(name: 'space read'),
          transaction: tx,
        ),
      );
    });

    group('when a space-bound transaction only reads a row,', () {
      late Unique? found;
      late int queries;
      late int rowsRead;
      late Hlc clockBefore;
      late Hlc clockAfter;
      late int metadataBefore;
      late int metadataAfter;

      Future<int> metadataRows() async =>
          await CrdtDataRow.db.count(app) +
          await CrdtDataField.db.count(app) +
          await CrdtDataDeleted.db.count(app);

      setUpAll(() async {
        clockBefore = await persistedUserClock(app, testCrdtUserId);
        metadataBefore = await metadataRows();
        final queriesBefore = database.queryCount;
        final rowsBefore = database.rowsRead;

        found = await app.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.findById(app, row.id!, transaction: tx),
        );

        queries = database.queryCount - queriesBefore;
        rowsRead = database.rowsRead - rowsBefore;
        clockAfter = await persistedUserClock(app, testCrdtUserId);
        metadataAfter = await metadataRows();
      });

      test(
        'then the read adds only the clock and space locks to membership and domain queries.',
        () {
          expect(found?.name, 'space read');
          expect(queries, 5);
          expect(rowsRead, 4);
        },
      );

      test('then the locks neither advance the clock nor record CRDT changes.', () {
        expect(clockAfter, clockBefore);
        expect(metadataAfter, metadataBefore);
      });
    });
  });
}
