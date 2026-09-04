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
  late CrdtDatabaseSession peerSession;

  setUp(() async {
    crdtSync = CrdtSync(
      syncTables: syncTables,
      serializationManager: testSession.db.serializationManager,
    );
    peerSession = CrdtDatabaseSession.wraps(
      await createAdditionalTestSession(),
      syncTables: syncTables,
    );
    await peerSession.db.initialize();
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
    'Given a row inserted and updated on an ordinary column before its changes are collected,',
    () {
      late City originalCity;
      late Town town;

      setUp(() async {
        originalCity = City(id: const Uuid().v7obj(), name: 'original city');
        town = Town(
          id: const Uuid().v7obj(),
          name: 'original name',
          cityId: originalCity.id,
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(session, originalCity, transaction: tx);
          await Town.db.insertRow(session, town, transaction: tx);
          await Town.db.updateRow(
            session,
            town.copyWith(name: 'updated name'),
            columns: (t) => [t.name],
            transaction: tx,
          );
        });
      });

      group('when a peer merges the collected batch,', () {
        setUp(() async {
          await peerSession.db.mergeChanges(
            await collectAuthoredChanges(),
            scopeId: testCrdtUserId,
          );
        });

        test('then the peer sees the updated value.', () async {
          final merged = await Town.db.findById(peerSession, town.id!);

          expect(merged, isNotNull);
          expect(merged!.name, 'updated name');
          expect(merged.cityId, originalCity.id);
        });
      });
    },
  );

  group(
    'Given a row inserted and updated on a foreign key column before its changes are collected,',
    () {
      late City replacementCity;
      late Town town;

      setUp(() async {
        final originalCity = City(id: const Uuid().v7obj(), name: 'original city');
        replacementCity = City(id: const Uuid().v7obj(), name: 'replacement city');
        town = Town(
          id: const Uuid().v7obj(),
          name: 'original name',
          cityId: originalCity.id,
        );

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await City.db.insertRow(session, originalCity, transaction: tx);
          await City.db.insertRow(session, replacementCity, transaction: tx);
          await Town.db.insertRow(session, town, transaction: tx);
          await Town.db.updateRow(
            session,
            town.copyWith(cityId: replacementCity.id),
            columns: (t) => [t.cityId],
            transaction: tx,
          );
        });
      });

      group('when a peer merges the collected batch,', () {
        setUp(() async {
          await peerSession.db.mergeChanges(
            await collectAuthoredChanges(),
            scopeId: testCrdtUserId,
          );
        });

        test('then the peer sees the updated reference.', () async {
          final merged = await Town.db.findById(peerSession, town.id!);

          expect(merged, isNotNull);
          expect(merged!.cityId, replacementCity.id);
          expect(merged.name, 'original name');
        });
      });
    },
  );
}
