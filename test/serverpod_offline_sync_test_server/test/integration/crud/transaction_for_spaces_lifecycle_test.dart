import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession();

  group('Given a space row without prepared replica metadata,', () {
    setUp(() async {
      await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: testCrdtUserId),
      );
    });

    test(
      'when a transaction writes to that space, '
      'then missing metadata is prepared automatically.',
      () async {
        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId},
          (spaces) => spaces.runForSpace(
            testCrdtUserId,
            (tx) => Person.db.insertRow(
              session,
              Person(name: 'personal'),
              transaction: tx,
            ),
          ),
        );

        final space = (await OfflineSyncSpace.db.find(testSession)).single;
        final node = (await CrdtNode.db.find(testSession)).single;
        final association = (await OfflineSyncSpaceNode.db.find(testSession)).single;
        final record = (await CrdtDataRow.db.find(testSession)).single;
        expect(space.currentNodeId, node.id);
        expect(association.nodeId, node.id);
        expect(association.spaceId, space.id);
        expect(record.nodeId, node.id);
        expect(record.spaceId, space.id);
      },
    );
  });

  group('Given a new uninitialized wrapper and an unprepared personal space,', () {
    late OfflineSyncDatabaseSession fresh;

    setUp(() {
      fresh = OfflineSyncDatabaseSession.wraps(testSession, syncTables: testSyncTables);
    });

    test(
      'when transactionForSpaces is called, '
      'then initialization and preparation happen before the callback.',
      () async {
        await fresh.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId},
          (spaces) => spaces.runForSpace(
            testCrdtUserId,
            (tx) => Person.db.insertRow(
              fresh,
              Person(name: 'personal'),
              transaction: tx,
            ),
          ),
        );

        expect(await Person.db.count(testSession), 1);
        expect(await OfflineSyncSpace.db.count(testSession), 1);
        expect(await CrdtNode.db.count(testSession), 1);
      },
    );
  });

  test(
    'Given a captured context from a committed transaction, '
    'when it is used after its callback returns, '
    'then it is rejected before running an action.',
    () async {
      late OfflineSyncSpacesTransaction captured;
      await session.db.transactionForSpaces(testCrdtUserId, {testCrdtUserId}, (
        spaces,
      ) async {
        captured = spaces;
      });
      var callbackRan = false;

      await expectLater(
        captured.runForSpace(testCrdtUserId, (_) async {
          callbackRan = true;
        }),
        throwsStateError,
      );

      expect(callbackRan, isFalse);
    },
  );

  test(
    'Given a captured context from a rolled back transaction, '
    'when it is used after its callback throws, '
    'then it is rejected before running an action.',
    () async {
      late OfflineSyncSpacesTransaction captured;
      final failure = StateError('rollback');
      await expectLater(
        session.db.transactionForSpaces(testCrdtUserId, {testCrdtUserId}, (
          spaces,
        ) async {
          captured = spaces;
          throw failure;
        }),
        throwsA(same(failure)),
      );
      var callbackRan = false;

      await expectLater(
        captured.runForSpace(testCrdtUserId, (_) async {
          callbackRan = true;
        }),
        throwsStateError,
      );

      expect(callbackRan, isFalse);
    },
  );

  test(
    'Given a scope that has written but is still running, '
    'when its enclosing callback returns without awaiting it, '
    'then the transaction fails and its writes roll back.',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      late Future<void> pending;
      final operation = session.db.transactionForSpaces(
        testCrdtUserId,
        {testCrdtUserId},
        (spaces) async {
          pending = spaces.runForSpace<void>(testCrdtUserId, (tx) async {
            await Person.db.insertRow(
              session,
              Person(name: 'discard'),
              transaction: tx,
            );
            entered.complete();
            await release.future;
          });
          // A savepoint finishing after its transaction ended may also fail.
          unawaited(pending.catchError((Object _) {}));
          await entered.future;
        },
      );

      try {
        await expectLater(operation, throwsStateError);
      } finally {
        release.complete();
        await pending.catchError((Object _) {});
      }

      expect(await Person.db.count(testSession), 0);
      expect(await CrdtDataRow.db.count(testSession), 0);
    },
  );

  test(
    'Given a nested scope still running after its parent scope returns, '
    'when the enclosing transaction callback returns, '
    'then it cannot commit the unfinished nested write.',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      late Future<void> pending;
      final operation = session.db.transactionForSpaces(
        testCrdtUserId,
        {testCrdtUserId},
        (spaces) async {
          await spaces.runForSpace(testCrdtUserId, (_) async {
            pending = spaces.runForSpace<void>(testCrdtUserId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'discard'),
                transaction: tx,
              );
              entered.complete();
              await release.future;
            });
            unawaited(pending.catchError((Object _) {}));
            await entered.future;
          });
        },
      );

      try {
        await expectLater(operation, throwsStateError);
      } finally {
        release.complete();
        await pending.catchError((Object _) {});
      }

      expect(await Person.db.count(testSession), 0);
      expect(await CrdtDataRow.db.count(testSession), 0);
    },
  );

  group('Given a user authorized for a personal and a shared space,', () {
    late OfflineSyncSpace shared;
    late OfflineSyncSpaceMember membership;

    setUp(() async {
      shared = await OfflineSyncSpace.db.insertRow(
        testSession,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
      membership = await OfflineSyncSpaceMember.db.insertRow(
        testSession,
        OfflineSyncSpaceMember(
          spaceId: shared.id!,
          userUuid: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      );
    });

    test(
      'when a role is downgraded inside the transaction before a nested scope, '
      'then that scope is rejected and the personal scope can continue.',
      () async {
        var sharedCallbackRan = false;
        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
            await OfflineSyncSpaceMember.db.updateRow(
              session,
              membership.copyWith(role: OfflineSyncSpaceRole.readOnly),
              transaction: tx,
            );
            await expectLater(
              spaces.runForSpace(shared.uuidSpaceId, (_) async {
                sharedCallbackRan = true;
              }),
              throwsA(isA<OfflineSyncSpaceRoleException>()),
            );
            await Person.db.insertRow(
              session,
              Person(name: 'personal'),
              transaction: tx,
            );
          }),
        );

        final row = (await Person.db.find(testSession)).single;
        final space = await OfflineSyncSpace.db.findById(testSession, row.spaceId!);
        expect(sharedCallbackRan, isFalse);
        expect(space!.uuidSpaceId, testCrdtUserId);
      },
    );

    test(
      'when membership is revoked after preparation, '
      'then entering that space uses the transaction and rejects the write.',
      () async {
        var sharedCallbackRan = false;
        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
            await OfflineSyncSpaceMember.db.deleteRow(
              session,
              membership,
              transaction: tx,
            );
            await expectLater(
              spaces.runForSpace(shared.uuidSpaceId, (_) async {
                sharedCallbackRan = true;
              }),
              throwsA(isA<OfflineSyncSpaceMembershipException>()),
            );
          }),
        );

        expect(sharedCallbackRan, isFalse);
        expect(await Person.db.count(testSession), 0);
      },
    );

    test(
      'when membership is revoked then granted again inside the transaction, '
      'then reads reflect each uncommitted membership change.',
      () async {
        await session.db.transactionForUser(
          testCrdtUserId,
          (tx) => Person.db.insertRow(session, Person(name: 'shared'), transaction: tx),
          spaceId: shared.uuidSpaceId,
        );
        late List<Person> withoutMembership;
        late List<Person> withMembership;
        await session.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) => spaces.runForSpace(testCrdtUserId, (tx) async {
            await OfflineSyncSpaceMember.db.deleteRow(
              session,
              membership,
              transaction: tx,
            );
            withoutMembership = await Person.db.find(session, transaction: tx);
            await OfflineSyncSpaceMember.db.insertRow(
              session,
              membership,
              transaction: tx,
            );
            await spaces.runForSpace(shared.uuidSpaceId, (tx) async {
              withMembership = await Person.db.find(session, transaction: tx);
            });
          }),
        );

        expect(withoutMembership, isEmpty);
        expect(withMembership.map((row) => row.name), ['shared']);
      },
    );
  });
}
