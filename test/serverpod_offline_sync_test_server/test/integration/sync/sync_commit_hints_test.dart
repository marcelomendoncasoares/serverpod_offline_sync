import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  Future<OfflineSyncDatabaseSession> writer(
    void Function(Map<UuidValue, UuidValue>) publish,
  ) async {
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
    );
    await session.db.initialize();
    return session;
  }

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
