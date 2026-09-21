import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../../../../../benchmark/utils/query_counter.dart';
import '../test_tools/client_session.dart';

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

      setUpAll(() async {
        final queriesBefore = database.queryCount;
        final rowsBefore = database.rowsRead;

        found = await app.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.findById(app, row.id!, transaction: tx),
        );

        queries = database.queryCount - queriesBefore;
        rowsRead = database.rowsRead - rowsBefore;
      });

      test('then the read uses only membership and domain queries.', () {
        expect(found?.name, 'space read');
        expect(queries, 3);
        expect(rowsRead, 2);
      });
    });
  });
}
