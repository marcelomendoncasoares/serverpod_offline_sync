import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given a user with a row in both its personal and writable shared space,', () {
    late OfflineSyncDatabaseSession scenario;
    late OfflineSyncSpace sharedSpace;
    late Person personal;
    late Person shared;

    setUpAll(() async {
      scenario = OfflineSyncDatabaseSession.wraps(
        await createAdditionalTestSession(),
        syncTables: testSyncTables,
      );
      await scenario.db.initialize();

      sharedSpace = await OfflineSyncSpace.db.insertRow(
        scenario,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
      await OfflineSyncSpaceMember.db.insertRow(
        scenario,
        OfflineSyncSpaceMember(
          spaceId: sharedSpace.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );

      personal = await scenario.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          scenario,
          Person(name: 'personal'),
          transaction: tx,
        ),
      );
      shared = await scenario.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(
          scenario,
          Person(name: 'shared'),
          transaction: tx,
        ),
        spaceId: sharedSpace.uuidSpaceId,
      );
    });

    group(
      'when only the personal space is declared for a multi-space transaction,',
      () {
        late List<Person> visible;
        Object? scopeError;
        var sharedCallbackRan = false;

        setUpAll(() async {
          await scenario.db.transactionForSpaces(testCrdtUserId, {testCrdtUserId}, (
            spaces,
          ) async {
            await spaces.runForSpace(testCrdtUserId, (tx) async {
              try {
                await spaces.runForSpace(sharedSpace.uuidSpaceId, (_) async {
                  sharedCallbackRan = true;
                });
              } catch (error) {
                if (error is! ArgumentError) rethrow;
                scopeError = error;
              }

              visible = await Person.db.find(scenario, transaction: tx);
            });
          });
        });

        test('then reads still include the authorized undeclared shared space.', () {
          expect(visible.map((row) => row.id).toSet(), {personal.id, shared.id});
        });

        test(
          'then acting in the undeclared space is rejected before its callback.',
          () {
            expect(scopeError, isA<ArgumentError>());
            expect(sharedCallbackRan, isFalse);
          },
        );
      },
    );
  });
}
