@TestOn('browser')
library;

import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

const _readTimeout = Duration(seconds: 5);

void main() {
  group('Given a browser client with writable personal and shared spaces,', () {
    late UuidValue userId;
    late OfflineSyncDatabaseSession session;
    late OfflineSyncSpace personalSpace;
    late OfflineSyncSpace sharedSpace;

    setUp(() async {
      userId = const Uuid().v7obj();
      session = await Client('http://localhost:8081/').createSyncSession(
        'transaction-for-spaces-$userId.db',
        persistentUserId: userId,
      );
      await session.db.currentNodeId();

      personalSpace = (await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(userId),
      ))!;
      sharedSpace = await OfflineSyncSpace.db.insertRow(
        session,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
      await OfflineSyncSpaceMember.db.insertRow(
        session,
        OfflineSyncSpaceMember(
          spaceId: sharedSpace.id!,
          userUuid: userId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );
    });

    tearDown(() async {
      await session.close();
    });

    group('when a transaction writes and reads in both declared spaces,', () {
      late Person personal;
      late Person shared;
      late List<Person> personalRead;
      late List<Person> sharedRead;
      late List<Person> committed;
      late List<CrdtDataRow> records;

      setUp(() async {
        await session.db.transactionForSpaces(
          userId,
          {userId, sharedSpace.uuidSpaceId},
          (spaces) async {
            await spaces.runForSpace(userId, (tx) async {
              personal = await Person.db.insertRow(
                session,
                Person(name: 'personal'),
                transaction: tx,
              );
              personalRead = await Person.db
                  .find(
                    session,
                    transaction: tx,
                  )
                  .timeout(_readTimeout);
            });

            await spaces.runForSpace(sharedSpace.uuidSpaceId, (tx) async {
              shared = await Person.db.insertRow(
                session,
                Person(name: 'shared'),
                transaction: tx,
              );
              sharedRead = await Person.db
                  .find(
                    session,
                    transaction: tx,
                  )
                  .timeout(_readTimeout);
            });
          },
        );

        committed = await Person.db.find(session);
        records = await CrdtDataRow.db.find(session);
      });

      test(
        'then membership-wide reads see the uncommitted rows without deadlocking.',
        () {
          expect(personalRead.map((row) => row.id), [personal.id]);
          expect(sharedRead.map((row) => row.id).toSet(), {personal.id, shared.id});
        },
      );

      test('then both rows commit with CRDT records in their acting spaces.', () {
        expect(committed.map((row) => (row.id, row.name)).toSet(), {
          (personal.id, 'personal'),
          (shared.id, 'shared'),
        });
        expect(records.map((row) => (row.uuidRowId, row.spaceId)).toSet(), {
          (personal.id, personalSpace.id),
          (shared.id, sharedSpace.id),
        });
      });
    });

    group('when a nested shared write fails and the personal scope catches it,', () {
      late Exception failure;
      Object? caught;
      late Person before;
      late Person after;
      late List<Person> visible;
      late List<Person> committed;
      late List<CrdtDataRow> records;

      setUp(() async {
        failure = Exception('discard the shared write');
        caught = null;

        await session.db.transactionForSpaces(
          userId,
          {userId, sharedSpace.uuidSpaceId},
          (spaces) => spaces.runForSpace(userId, (tx) async {
            before = await Person.db.insertRow(
              session,
              Person(name: 'before'),
              transaction: tx,
            );

            try {
              await spaces.runForSpace(sharedSpace.uuidSpaceId, (nestedTx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'discarded'),
                  transaction: nestedTx,
                );
                throw failure;
              });
            } on Exception catch (error) {
              if (!identical(error, failure)) rethrow;
              caught = error;
            }

            after = await Person.db.insertRow(
              session,
              Person(name: 'after'),
              transaction: tx,
            );
            visible = await Person.db
                .find(
                  session,
                  transaction: tx,
                )
                .timeout(_readTimeout);
          }),
        );

        committed = await Person.db.find(session);
        records = await CrdtDataRow.db.find(session);
      });

      test('then only the failed scope loses its domain and CRDT writes.', () {
        expect(caught, same(failure));
        expect(visible.map((row) => row.id).toSet(), {before.id, after.id});
        expect(committed.map((row) => row.id).toSet(), {before.id, after.id});
        expect(records.map((row) => row.uuidRowId).toSet(), {before.id, after.id});
      });

      test('then the subsequent write uses the restored personal binding.', () {
        expect(records.map((row) => (row.uuidRowId, row.spaceId)).toSet(), {
          (before.id, personalSpace.id),
          (after.id, personalSpace.id),
        });
      });
    });

    group('when a failure in the second space escapes the transaction callback,', () {
      late Exception failure;
      Object? caught;
      late List<Person> beforeFailure;
      late List<CrdtDataRow> recordsBeforeFailure;
      late List<Person> committed;
      late List<CrdtDataRow> records;

      setUp(() async {
        failure = Exception('abort both spaces');
        caught = null;

        try {
          await session.db.transactionForSpaces(
            userId,
            {userId, sharedSpace.uuidSpaceId},
            (spaces) async {
              await spaces.runForSpace(userId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'personal'),
                  transaction: tx,
                );
              });

              await spaces.runForSpace(sharedSpace.uuidSpaceId, (tx) async {
                await Person.db.insertRow(
                  session,
                  Person(name: 'shared'),
                  transaction: tx,
                );
                beforeFailure = await Person.db
                    .find(
                      session,
                      transaction: tx,
                    )
                    .timeout(_readTimeout);
                recordsBeforeFailure = await CrdtDataRow.db.find(
                  session,
                  transaction: tx,
                );
                throw failure;
              });
            },
          );
        } on Exception catch (error) {
          if (!identical(error, failure)) rethrow;
          caught = error;
        }

        committed = await Person.db.find(session);
        records = await CrdtDataRow.db.find(session);
      });

      test('then the failure escapes after both spaces have written.', () {
        expect(caught, same(failure));
        expect(beforeFailure.map((row) => row.name).toSet(), {'personal', 'shared'});
        expect(recordsBeforeFailure.map((row) => row.spaceId).toSet(), {
          personalSpace.id,
          sharedSpace.id,
        });
      });

      test('then neither space commits domain or CRDT changes.', () {
        expect(committed, isEmpty);
        expect(records, isEmpty);
      });
    });
  });
}
