import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  Future<OfflineSyncDatabaseSession> writer(
    void Function(Map<UuidValue, UuidValue>) publish, {
    UuidValue? persistentUserId,
  }) async {
    final raw = await createAdditionalTestSession();
    final context = OfflineSyncDatabaseContext(
      syncTables: testSyncTables,
      serializationManager: raw.db.serializationManager,
      onCommittedSpaces: publish,
    );
    final session = OfflineSyncDatabaseSession(
      raw.db,
      syncTables: testSyncTables,
      context: context,
      persistentUserId: persistentUserId,
    );
    await session.db.initialize();
    return session;
  }

  test(
    'Given two declared spaces writable by one user, '
    'when one transaction commits a row in each space, '
    'then one post-commit publication carries both durable revisions.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add);
      final shared = await _grantSpace(session);
      final ids = {testCrdtUserId, shared.uuidSpaceId};
      late int beforeCommit;

      await session.db.transactionForSpaces(testCrdtUserId, ids, (spaces) async {
        for (final id in ids) {
          await spaces.runForSpace(
            id,
            (tx) => Person.db.insertRow(
              session,
              Person(name: id.toString()),
              transaction: tx,
            ),
          );
        }
        beforeCommit = publications.length;
      });
      final durableSpaces = await OfflineSyncSpace.db.find(session);
      final rows = await Person.db.find(session);

      expect(beforeCommit, 0);
      expect(publications, [
        {for (final space in durableSpaces) space.uuidSpaceId: space.revision},
      ]);
      expect(publications.single.keys.toSet(), ids);
      expect(
        rows.map((row) => row.spaceId).toSet(),
        durableSpaces.map((s) => s.id).toSet(),
      );
    },
  );

  test(
    'Given a transaction with writes in two declared spaces, '
    'when its outer callback throws after both writes, '
    'then no domain row or revision publication escapes the rollback.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add);
      final shared = await _grantSpace(session);
      final failure = StateError('rollback both spaces');
      Object? caught;

      try {
        await session.db.transactionForSpaces<void>(
          testCrdtUserId,
          {testCrdtUserId, shared.uuidSpaceId},
          (spaces) async {
            for (final id in [testCrdtUserId, shared.uuidSpaceId]) {
              await spaces.runForSpace(
                id,
                (tx) => Person.db.insertRow(
                  session,
                  Person(name: id.toString()),
                  transaction: tx,
                ),
              );
            }
            throw failure;
          },
        );
      } on Object catch (error) {
        caught = error;
      }
      final rows = await Person.db.find(session);

      expect(caught, same(failure));
      expect(rows, isEmpty);
      expect(publications, isEmpty);
    },
  );

  test(
    'Given a transaction spanning personal and shared spaces, '
    'when its shared scope rolls back and its personal scope commits, '
    'then only the surviving personal revision is published.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add);
      final shared = await _grantSpace(session);
      final failure = StateError('rollback shared scope');
      Object? caught;

      await session.db.transactionForSpaces(
        testCrdtUserId,
        {testCrdtUserId, shared.uuidSpaceId},
        (spaces) async {
          try {
            await spaces.runForSpace<void>(shared.uuidSpaceId, (tx) async {
              await Person.db.insertRow(
                session,
                Person(name: 'discard'),
                transaction: tx,
              );
              throw failure;
            });
          } on Object catch (error) {
            caught = error;
          }
          await spaces.runForSpace(
            testCrdtUserId,
            (tx) => Person.db.insertRow(session, Person(name: 'keep'), transaction: tx),
          );
        },
      );
      final personal = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      final rows = await Person.db.find(session);

      expect(caught, same(failure));
      expect(rows.map((row) => row.name), ['keep']);
      expect(publications, [
        {testCrdtUserId: personal!.revision},
      ]);
    },
  );

  test(
    'Given a persistent transaction with a savepoint before its first write, '
    'when the caller rolls back and returns without another write, '
    'then its discarded revision is not published.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add, persistentUserId: testCrdtUserId);

      await session.db.transaction((tx) async {
        final savepoint = await tx.createSavepoint();
        await Person.db.insertRow(session, Person(name: 'discard'), transaction: tx);
        await savepoint.rollback();
      });
      final rows = await Person.db.find(session);

      expect(rows, isEmpty);
      expect(publications, isEmpty);
    },
  );

  test(
    'Given a persistent transaction that writes before a caller savepoint, '
    'when a later write rolls back and the earlier write commits, '
    'then the earlier surviving revision is published.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add, persistentUserId: testCrdtUserId);

      await session.db.transaction((tx) async {
        await Person.db.insertRow(session, Person(name: 'earlier'), transaction: tx);
        final savepoint = await tx.createSavepoint();
        await Person.db.insertRow(session, Person(name: 'discard'), transaction: tx);
        await savepoint.rollback();
      });
      final space = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      final rows = await Person.db.find(session);

      expect(rows.map((row) => row.name), ['earlier']);
      expect(publications, [
        {testCrdtUserId: space!.revision},
      ]);
    },
  );

  test(
    'Given a persistent transaction with a rolled-back first write, '
    'when a replacement write commits in the same transaction, '
    'then only the replacement durable revision is published.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add, persistentUserId: testCrdtUserId);

      await session.db.transaction((tx) async {
        final savepoint = await tx.createSavepoint();
        await Person.db.insertRow(session, Person(name: 'discard'), transaction: tx);
        await savepoint.rollback();
        await Person.db.insertRow(
          session,
          Person(name: 'replacement'),
          transaction: tx,
        );
      });
      final space = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      final rows = await Person.db.find(session);

      expect(rows.map((row) => row.name), ['replacement']);
      expect(publications, [
        {testCrdtUserId: space!.revision},
      ]);
    },
  );

  test(
    'Given an owned transaction paused after its row write, '
    'when it is released and committed, '
    'then its durable revision is published only after commitment.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add);
      final row = Person(id: const Uuid().v7obj(), name: 'committed');
      final entered = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final pending = session.db.transactionForUser(testCrdtUserId, (tx) async {
        await Person.db.insertRow(session, row, transaction: tx);
        entered.complete();
        await release.future;
      });
      await entered.future;
      final countBeforeCommit = publications.length;

      release.complete();
      await pending;
      final space = await OfflineSyncSpace.db.findFirstRow(
        session,
        where: (t) => t.uuidSpaceId.equals(testCrdtUserId),
      );
      final persisted = await Person.db.findById(session, row.id!);

      expect(countBeforeCommit, 0);
      expect(publications, [
        {testCrdtUserId: space!.revision},
      ]);
      expect(persisted?.name, row.name);
    },
  );

  test(
    'Given an owned transaction that wrote a synchronized row, '
    'when its action fails and rolls back, '
    'then neither the row nor a commit hint escapes.',
    () async {
      final publications = <Map<UuidValue, UuidValue>>[];
      final session = await writer(publications.add);
      final row = Person(id: const Uuid().v7obj(), name: 'rolled back');
      Object? failure;

      try {
        await session.db.transactionForUser(testCrdtUserId, (tx) async {
          await Person.db.insertRow(session, row, transaction: tx);
          throw StateError('injected rollback');
        });
      } on Object catch (error) {
        failure = error;
      }
      final persisted = await Person.db.findById(session, row.id!);

      expect(failure, isA<StateError>());
      expect(persisted, isNull);
      expect(publications, isEmpty);
    },
  );

  test(
    'Given an unavailable hint publisher, '
    'when a synchronized transaction commits, '
    'then publication failure does not turn the durable write into a failure.',
    () async {
      var attempts = 0;
      final session = await writer((_) {
        attempts++;
        throw StateError('unavailable transport');
      });
      final row = Person(id: const Uuid().v7obj(), name: 'still durable');

      await session.db.transactionForUser(
        testCrdtUserId,
        (tx) => Person.db.insertRow(session, row, transaction: tx),
      );
      final persisted = await Person.db.findById(session, row.id!);

      expect(attempts, 1);
      expect(persisted?.name, row.name);
    },
  );
}

Future<OfflineSyncSpace> _grantSpace(OfflineSyncDatabaseSession session) async {
  final space = await OfflineSyncSpace.db.insertRow(
    session,
    OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
  );
  await OfflineSyncSpaceMember.db.insertRow(
    session,
    OfflineSyncSpaceMember(
      spaceId: space.id!,
      userUuid: testCrdtUserId,
      role: OfflineSyncSpaceRole.readWrite,
    ),
  );
  return space;
}
