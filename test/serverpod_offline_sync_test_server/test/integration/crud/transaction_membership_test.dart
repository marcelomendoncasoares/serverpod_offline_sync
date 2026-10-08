import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(withPersistentUser: true);

  group('Given a persistent user without membership in a populated shared space,', () {
    late Person sharedPerson;
    late OfflineSyncSpaceMember membership;

    setUp(() async {
      final ownerId = const Uuid().v7obj();
      sharedPerson = await session.db.transactionForUser(
        ownerId,
        (tx) => Person.db.insertRow(
          session,
          Person(name: 'shared'),
          transaction: tx,
        ),
      );
      final sharedSpace = await OfflineSyncSpace.db.findFirstRow(
        testSession,
        where: (t) => t.uuidSpaceId.equals(ownerId),
      );
      membership = OfflineSyncSpaceMember(
        spaceId: sharedSpace!.id!,
        userUuid: testCrdtUserId,
        role: OfflineSyncSpaceRole.readWrite,
      );
    });

    test(
      'when granting, revoking, and restoring membership within one transaction, '
      'then each read reflects the preceding uncommitted change.',
      () async {
        late List<Person> beforeGrant;
        late Person? afterGrant;
        late Person? afterRevocation;
        late int afterRestoration;

        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          beforeGrant = await Person.db.find(session, transaction: tx);
          final insertedMembership = await OfflineSyncSpaceMember.db.insertRow(
            session,
            membership,
            transaction: tx,
          );
          afterGrant = await Person.db.findById(
            session,
            sharedPerson.id!,
            transaction: tx,
          );

          await OfflineSyncSpaceMember.db.deleteRow(
            session,
            insertedMembership,
            transaction: tx,
          );
          afterRevocation = await Person.db.findFirstRow(session, transaction: tx);

          await OfflineSyncSpaceMember.db.insertRow(
            session,
            membership,
            transaction: tx,
          );
          afterRestoration = await Person.db.count(session, transaction: tx);
        });

        expect(beforeGrant, isEmpty);
        expect(afterGrant?.id, sharedPerson.id);
        expect(afterRevocation, isNull);
        expect(afterRestoration, 1);
      },
    );

    group('when a membership grant is read and then rolled back,', () {
      late List<Person> insideTransaction;
      late List<Person> afterRollback;
      late List<OfflineSyncSpaceMember> persistedMemberships;
      Object? failure;

      setUp(() async {
        failure = null;

        try {
          await session.db.transactionForUser<void>(testCrdtUserId, (tx) async {
            await OfflineSyncSpaceMember.db.insertRow(
              session,
              membership,
              transaction: tx,
            );
            insideTransaction = await Person.db.find(session, transaction: tx);

            throw StateError('Roll back the membership grant');
          });
        } on Object catch (error) {
          failure = error;
        }

        afterRollback = await Person.db.find(session);
        persistedMemberships = await OfflineSyncSpaceMember.db.find(testSession);
      });

      test('then the row was visible inside the transaction.', () {
        expect(insideTransaction.map((row) => row.id), [sharedPerson.id]);
      });

      test('then the rolled-back grant leaves no membership or visible row.', () {
        expect(
          failure,
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Roll back the membership grant',
          ),
        );
        expect(persistedMemberships, isEmpty);
        expect(afterRollback, isEmpty);
      });
    });

    test(
      'when membership is committed and revoked between transactions, '
      'then later transactions pick up each change.',
      () async {
        final beforeGrant = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.find(session, transaction: tx),
        );

        final insertedMembership = await OfflineSyncSpaceMember.db.insertRow(
          testSession,
          membership,
        );
        final afterGrant = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.find(session, transaction: tx),
        );

        await OfflineSyncSpaceMember.db.deleteRow(testSession, insertedMembership);
        final afterRevocation = await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.find(session, transaction: tx),
        );

        expect(beforeGrant, isEmpty);
        expect(afterGrant.map((row) => row.id), [sharedPerson.id]);
        expect(afterRevocation, isEmpty);
      },
    );
  });
}
