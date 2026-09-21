import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given two personal spaces,', () {
    late UuidValue otherUserId;

    setUp(() {
      otherUserId = const Uuid().v7obj();
    });

    group(
      'when inserting one person in each space inside the same database transaction,',
      () {
        late Person firstPerson;
        late Person otherPerson;

        setUp(() async {
          await session.db.transaction((tx) async {
            firstPerson = await session.db.runForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'first-space-person'),
                transaction: tx,
              ),
              transaction: tx,
            );
            otherPerson = await session.db.runForUser(
              otherUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'other-space-person'),
                transaction: tx,
              ),
              transaction: tx,
            );
          });
        });

        test('then both rows persist.', () async {
          final rows = await Person.db.find(testSession);

          expect(rows.map((row) => row.id).toSet(), {
            firstPerson.id,
            otherPerson.id,
          });
        });

        test('then each row is stamped with its acting space.', () async {
          final storedFirst = await Person.db.findById(testSession, firstPerson.id!);
          final storedOther = await Person.db.findById(testSession, otherPerson.id!);
          final firstSpace = await OfflineSyncSpace.db.findFirstRow(
            session,
            where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
          );
          final otherSpace = await OfflineSyncSpace.db.findFirstRow(
            session,
            where: (t) => t.uuidSpaceId.equals(otherUserId),
          );

          expect(storedFirst!.spaceId, firstSpace!.id);
          expect(storedOther!.spaceId, otherSpace!.id);
        });
      },
    );

    group(
      'when the shared transaction throws after inserting into both spaces,',
      () {
        setUp(() async {
          try {
            await session.db.transaction((tx) async {
              await session.db.runForUser(
                testCrdtUserId,
                (tx) => Person.db.insertRow(
                  session,
                  Person(name: 'first-space-person'),
                  transaction: tx,
                ),
                transaction: tx,
              );
              await session.db.runForUser(
                otherUserId,
                (tx) => Person.db.insertRow(
                  session,
                  Person(name: 'other-space-person'),
                  transaction: tx,
                ),
                transaction: tx,
              );
              throw StateError('force rollback');
            });
          } on StateError {
            // The outer transaction is expected to roll back.
          }
        });

        test('then neither row persists.', () async {
          expect(await Person.db.count(testSession), 0);
        });
      },
    );

    group(
      'when a nested runForUser throws after the outer space already inserted,',
      () {
        late Person outerPerson;

        setUp(() async {
          await session.db.transaction((tx) async {
            outerPerson = await session.db.runForUser(
              testCrdtUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'outer-space-person'),
                transaction: tx,
              ),
              transaction: tx,
            );
            try {
              await session.db.runForUser(
                otherUserId,
                (tx) async {
                  await Person.db.insertRow(
                    session,
                    Person(name: 'nested-space-person'),
                    transaction: tx,
                  );
                  throw StateError('force nested rollback');
                },
                transaction: tx,
              );
            } on StateError {
              // The nested savepoint is expected to roll back.
            }
          });
        });

        test(
          'then only the outer space insert persists.',
          () async {
            final rows = await Person.db.find(testSession);

            expect(rows, hasLength(1));
            expect(rows.single.id, outerPerson.id);
          },
        );
      },
    );

    group(
      'when an outer runForUser inserts around a nested runForUser for the other space,',
      () {
        late Person beforeNested;
        late Person nestedPerson;
        late Person afterNested;

        setUp(() async {
          await session.db.transactionForUser(testCrdtUserId, (tx) async {
            beforeNested = await Person.db.insertRow(
              session,
              Person(name: 'before-nested'),
              transaction: tx,
            );
            nestedPerson = await session.db.runForUser(
              otherUserId,
              (tx) => Person.db.insertRow(
                session,
                Person(name: 'nested-other-space'),
                transaction: tx,
              ),
              transaction: tx,
            );
            afterNested = await Person.db.insertRow(
              session,
              Person(name: 'after-nested'),
              transaction: tx,
            );
          });
        });

        test(
          'then writes after the nested call still belong to the outer space.',
          () async {
            final storedBefore = await Person.db.findById(
              testSession,
              beforeNested.id!,
            );
            final storedNested = await Person.db.findById(
              testSession,
              nestedPerson.id!,
            );
            final storedAfter = await Person.db.findById(
              testSession,
              afterNested.id!,
            );
            final firstSpace = await OfflineSyncSpace.db.findFirstRow(
              session,
              where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
            );
            final otherSpace = await OfflineSyncSpace.db.findFirstRow(
              session,
              where: (t) => t.uuidSpaceId.equals(otherUserId),
            );

            expect(storedBefore!.spaceId, firstSpace!.id);
            expect(storedAfter!.spaceId, firstSpace.id);
            expect(storedNested!.spaceId, otherSpace!.id);
          },
        );
      },
    );
  });

  group('Given a shared space the user is not a member of,', () {
    late UuidValue sharedSpaceId;

    setUp(() async {
      sharedSpaceId = const Uuid().v7obj();
      await OfflineSyncSpace.db.insertRow(
        session,
        OfflineSyncSpace(uuidSpaceId: sharedSpaceId),
      );
    });

    test(
      'when running for that space, '
      'then a membership exception is thrown.',
      () async {
        await expectLater(
          session.db.runForUser(
            testCrdtUserId,
            (tx) => Person.db.insertRow(
              session,
              Person(name: 'ungranted-person'),
              transaction: tx,
            ),
            spaceId: sharedSpaceId,
          ),
          throwsA(isA<OfflineSyncSpaceMembershipException>()),
        );
      },
    );
  });

  group(
    'Given a new shared space granted inside the same database transaction, '
    'when inserting a person in that space,',
    () {
      late UuidValue sharedSpaceId;
      late Person sharedPerson;

      setUp(() async {
        sharedSpaceId = const Uuid().v7obj();
        await session.db.transaction((tx) async {
          final space = await OfflineSyncSpace.db.insertRow(
            session,
            OfflineSyncSpace(uuidSpaceId: sharedSpaceId),
            transaction: tx,
          );
          await OfflineSyncSpaceMember.db.insertRow(
            session,
            OfflineSyncSpaceMember(
              spaceId: space.id!,
              userUuid: testCrdtUserId,
              role: OfflineSyncSpaceRole.readWrite,
            ),
            transaction: tx,
          );
          sharedPerson = await session.db.runForUser(
            testCrdtUserId,
            (tx) => Person.db.insertRow(
              session,
              Person(name: 'same-tx-grant-person'),
              transaction: tx,
            ),
            spaceId: sharedSpaceId,
            transaction: tx,
          );
        });
      });

      test('then the row belongs to the granted space.', () async {
        final stored = await Person.db.findById(testSession, sharedPerson.id!);
        final space = await OfflineSyncSpace.db.findFirstRow(
          session,
          where: (t) => t.uuidSpaceId.equals(sharedSpaceId),
        );

        expect(stored, isNotNull);
        expect(stored!.spaceId, space!.id);
      });
    },
  );
}
