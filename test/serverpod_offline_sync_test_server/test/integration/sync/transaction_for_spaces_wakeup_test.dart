// Observe the same local notification subscriptions used by the sync engine.
// ignore_for_file: invalid_use_of_internal_member

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given idle streams for two spaces writable by one user,', () {
    late _SpaceWakeups fixture;
    late FramedSyncPeer personalPeer;
    late FramedSyncPeer sharedPeer;
    late Unique personal;
    late Unique shared;

    setUpAll(() async {
      fixture = await _SpaceWakeups.open(const Uuid().v7obj());
      personalPeer = await FramedSyncPeer.open(fixture.node);
      sharedPeer = await FramedSyncPeer.open(
        fixture.node,
        userId: fixture.sharedSpace,
      );
      personal = Unique(id: const Uuid().v7obj(), name: 'personal commit');
      shared = Unique(id: const Uuid().v7obj(), name: 'shared commit');
    });

    group('when one transaction commits a row in each space,', () {
      late List<UuidValue> beforeCommit;
      late List<UuidValue> notified;
      late Set<UuidValue> sent;
      late int polls;

      setUpAll(() async {
        await fixture.node.offlineSync.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, fixture.sharedSpace},
          (spaces) async {
            await spaces.runForSpace(
              testCrdtUserId,
              (tx) => Unique.db.insertRow(
                fixture.node.offlineSync,
                personal,
                transaction: tx,
              ),
            );
            await spaces.runForSpace(
              fixture.sharedSpace,
              (tx) => Unique.db.insertRow(
                fixture.node.offlineSync,
                shared,
                transaction: tx,
              ),
            );
            beforeCommit = List.of(fixture.notifications);
          },
        );
        notified = List.of(fixture.notifications);
        await personalPeer.waitForRow(personal.id!);
        await sharedPeer.waitForRow(shared.id!);
        sent = [
          ...personalPeer.outbound,
          ...sharedPeer.outbound,
        ].map((change) => change.uuidRowId).toSet();
        polls = personalPeer.idlePolls + sharedPeer.idlePolls;
        await personalPeer.close();
        await sharedPeer.close();
      });

      test('then each space is notified only after the transaction commits.', () {
        expect(beforeCommit, isEmpty);
        expect(notified, unorderedEquals([testCrdtUserId, fixture.sharedSpace]));
      });

      test(
        'then both streams receive their committed rows without recovery polling.',
        () {
          expect(sent, {personal.id, shared.id});
          expect(polls, 0);
        },
      );
    });
  });

  group('Given notifications for two declared writable spaces,', () {
    late _SpaceWakeups fixture;

    setUpAll(() async {
      fixture = await _SpaceWakeups.open(const Uuid().v7obj());
    });

    group('when a shared scope rolls back and the personal scope commits,', () {
      late List<UuidValue> notified;
      late List<String> rows;
      late bool rolledBack;

      setUpAll(() async {
        rolledBack = false;
        await fixture.node.offlineSync.db.transactionForSpaces(
          testCrdtUserId,
          {testCrdtUserId, fixture.sharedSpace},
          (spaces) async {
            try {
              await spaces.runForSpace<void>(fixture.sharedSpace, (tx) async {
                await Unique.db.insertRow(
                  fixture.node.offlineSync,
                  Unique(id: const Uuid().v7obj(), name: 'discard shared'),
                  transaction: tx,
                );
                throw const _Rollback();
              });
            } on _Rollback {
              rolledBack = true;
            }
            await spaces.runForSpace(
              testCrdtUserId,
              (tx) => Unique.db.insertRow(
                fixture.node.offlineSync,
                Unique(id: const Uuid().v7obj(), name: 'keep personal'),
                transaction: tx,
              ),
            );
          },
        );
        notified = List.of(fixture.notifications);
        rows = (await Unique.db.find(fixture.node.raw)).map((row) => row.name).toList();
      });

      test('then only the surviving space wakes and only its row is durable.', () {
        expect(rolledBack, isTrue);
        expect(notified, [testCrdtUserId]);
        expect(rows, ['keep personal']);
      });
    });
  });

  group('Given a transaction writing to two declared writable spaces,', () {
    late _SpaceWakeups fixture;

    setUpAll(() async {
      fixture = await _SpaceWakeups.open(const Uuid().v7obj());
    });

    group('when the outer transaction rolls back after both writes,', () {
      late List<UuidValue> notified;
      late List<Unique> rows;
      late bool rolledBack;

      setUpAll(() async {
        rolledBack = false;
        try {
          await fixture.node.offlineSync.db.transactionForSpaces<void>(
            testCrdtUserId,
            {testCrdtUserId, fixture.sharedSpace},
            (spaces) async {
              for (final space in [testCrdtUserId, fixture.sharedSpace]) {
                await spaces.runForSpace(
                  space,
                  (tx) => Unique.db.insertRow(
                    fixture.node.offlineSync,
                    Unique(id: const Uuid().v7obj(), name: space.toString()),
                    transaction: tx,
                  ),
                );
              }
              throw const _Rollback();
            },
          );
        } on _Rollback {
          rolledBack = true;
        }
        notified = List.of(fixture.notifications);
        rows = await Unique.db.find(fixture.node.raw);
      });

      test('then neither space wakes and neither row is durable.', () {
        expect(rolledBack, isTrue);
        expect(notified, isEmpty);
        expect(rows, isEmpty);
      });
    });
  });
}

class _SpaceWakeups {
  _SpaceWakeups(this.node, this.sharedSpace, this.notifications);

  final SyncNode node;
  final UuidValue sharedSpace;
  final List<UuidValue> notifications;

  static Future<_SpaceWakeups> open(UuidValue sharedSpace) async {
    final raw = await createAdditionalTestSession();
    final context = OfflineSyncDatabaseContext(
      syncTables: testSyncTables,
      serializationManager: raw.db.serializationManager,
    );
    final offlineSync = OfflineSyncDatabaseSession.wraps(
      raw,
      syncTables: testSyncTables,
      context: context,
    );
    await offlineSync.db.initialize();
    final space = await OfflineSyncSpace.db.insertRow(
      raw,
      OfflineSyncSpace(uuidSpaceId: sharedSpace),
    );
    await OfflineSyncSpaceMember.db.insertRow(
      raw,
      OfflineSyncSpaceMember(
        spaceId: space.id!,
        userUuid: testCrdtUserId,
        role: OfflineSyncSpaceRole.readWrite,
      ),
    );
    final notifications = <UuidValue>[];
    for (final id in [testCrdtUserId, sharedSpace]) {
      addTearDown(context.onSpaceChanged(id, () => notifications.add(id)));
    }
    return _SpaceWakeups(
      (
        raw: raw,
        offlineSync: offlineSync,
        sync: OfflineSyncEngine(
          syncTables: testSyncTables,
          serializationManager: raw.db.serializationManager,
          databaseContext: context,
        ),
      ),
      sharedSpace,
      notifications,
    );
  }
}

class _Rollback implements Exception {
  const _Rollback();
}
