import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

/// A row inserted and then updated before its changes are collected produces a
/// single batch carrying both the insert and the update for that row. Merging
/// that batch must succeed whichever column the update touched.
///
/// Foreign-key columns take a different storage path from ordinary ones: their
/// durable attempted value lives in `crdt_data_foreign_key`, hung off a
/// `crdt_data_field` row, so the insert already materializes field metadata for
/// them. Ordinary columns only get a `crdt_data_field` row once they are
/// updated.
void main() {
  initTestClientSession();

  final syncTables = [City.t, Person.t, Town.t];

  late CrdtSync crdtSync;
  late CrdtDatabaseSession authorSession;
  late CrdtDatabaseSession peerSession;
  late City originalCity;
  late City replacementCity;
  late Town town;

  setUp(() async {
    crdtSync = CrdtSync(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
    authorSession = CrdtDatabaseSession.wraps(
      testSession,
      syncTables: syncTables,
    );
    await authorSession.db.initialize();

    peerSession = CrdtDatabaseSession.wraps(
      await createAdditionalTestSession(),
      syncTables: syncTables,
    );
    await peerSession.db.initialize();

    originalCity = City(id: const Uuid().v7obj(), name: 'original city');
    replacementCity = City(id: const Uuid().v7obj(), name: 'replacement city');
    town = Town(
      id: const Uuid().v7obj(),
      name: 'original name',
      cityId: originalCity.id,
    );
  });

  Future<CrdtMergeSet> collectAuthoredChanges() {
    return crdtSync
        .collectPendingChanges(
          testSession,
          checkpointsByScopeUuid: {testCrdtUserId: const []},
        )
        .toList();
  }

  group(
    'Given a row inserted and updated before its changes are collected,',
    () {
      test(
        'when the update targets an ordinary column, '
        'then the peer merges the batch and sees the updated value.',
        () async {
          await authorSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await City.db.insertRow(
              authorSession,
              originalCity,
              transaction: tx,
            );
            await Town.db.insertRow(authorSession, town, transaction: tx);
            await Town.db.updateRow(
              authorSession,
              town.copyWith(name: 'updated name'),
              columns: (t) => [t.name],
              transaction: tx,
            );
          });

          await peerSession.db.mergeChanges(
            await collectAuthoredChanges(),
            scopeId: testCrdtUserId,
          );

          final merged = await Town.db.findById(peerSession, town.id!);
          expect(merged, isNotNull);
          expect(merged!.name, 'updated name');
          expect(merged.cityId, originalCity.id);
        },
      );

      test(
        'when the update targets a foreign key column, '
        'then the peer merges the batch and sees the updated reference.',
        () async {
          await authorSession.db.transactionForUser(testCrdtUserId, (tx) async {
            await City.db.insertRow(
              authorSession,
              originalCity,
              transaction: tx,
            );
            await City.db.insertRow(
              authorSession,
              replacementCity,
              transaction: tx,
            );
            await Town.db.insertRow(authorSession, town, transaction: tx);
            await Town.db.updateRow(
              authorSession,
              town.copyWith(cityId: replacementCity.id),
              columns: (t) => [t.cityId],
              transaction: tx,
            );
          });

          await peerSession.db.mergeChanges(
            await collectAuthoredChanges(),
            scopeId: testCrdtUserId,
          );

          final merged = await Town.db.findById(peerSession, town.id!);
          expect(merged, isNotNull);
          expect(merged!.cityId, replacementCity.id);
          expect(merged.name, 'original name');
        },
      );
    },
  );
}
