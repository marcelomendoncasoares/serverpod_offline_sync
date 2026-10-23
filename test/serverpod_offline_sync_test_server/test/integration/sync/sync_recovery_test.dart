import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart' as database;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

void main() {
  initTestClientSession(createSessionPerTest: false);

  group('Given eight caught-up streams sharing a database context,', () {
    late _Fixture fixture;
    late _RecoveryObservations observations;
    late List<FramedSyncPeer> peers;
    late int readsBefore;
    late int framesBefore;
    late int capturesBefore;

    setUpAll(() async {
      fixture = await _fixture();
      observations = _RecoveryObservations();
      peers = [];
      for (var device = 0; device < 8; device++) {
        peers.add(
          await FramedSyncPeer.open(
            fixture.node,
            onDiagnostic: observations.record,
          ),
        );
      }
      await observations.waitForScans(1);
      await Future.wait(peers.map((peer) => peer.waitForPass(2)));
      readsBefore = fixture.db.reads;
      framesBefore = peers.fold(0, (sum, peer) => sum + peer.events.length);
      capturesBefore = peers.fold(0, (sum, peer) => sum + peer.stages.length);
    });

    group('when two recovery scans observe no durable changes,', () {
      late int reads;
      late int frames;
      late int captures;

      setUpAll(() async {
        await observations.waitForScans(3);
        reads = fixture.db.reads - readsBefore;
        frames = peers.fold(0, (sum, peer) => sum + peer.events.length) - framesBefore;
        captures =
            peers.fold(0, (sum, peer) => sum + peer.stages.length) - capturesBefore;
        await Future.wait(peers.map((peer) => peer.close()));
      });

      test('then only four set queries run across all eight streams.', () {
        expect(reads, 4);
        expect(observations.starts.skip(1).map((e) => e['subscriptions']), [8, 8]);
        expect(observations.failures, isEmpty);
      });

      test('then the streams emit no frames and capture no snapshots.', () {
        expect(frames, 0);
        expect(captures, 0);
      });
    });
  });

  group('Given a stream whose first recovery version read is held after SQL,', () {
    late _Fixture fixture;
    late FramedSyncPeer peer;
    late OfflineSyncDatabaseSession independentWriter;
    late Unique inserted;

    setUpAll(() async {
      fixture = await _fixture();
      peer = await FramedSyncPeer.open(
        fixture.node,
        onDiagnostic: (event) {
          if (event['name'] == 'sync.recoveryScan' && event['kind'] == 'start') {
            fixture.db.holdNextVersionRead = !fixture.db.entered.isCompleted;
          }
        },
      );
      independentWriter = OfflineSyncDatabaseSession.wraps(
        fixture.raw,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      inserted = Unique(id: const Uuid().v7obj(), name: 'other context');
      addTearDown(() {
        if (!fixture.db.release.isCompleted) fixture.db.release.complete();
      });
      await fixture.db.entered.future.timeout(const Duration(seconds: 5));
    });

    group('when another context commits before that baseline is published,', () {
      late List<UuidValue> received;
      late int wakeups;

      setUpAll(() async {
        await Unique.db.insertRow(independentWriter, inserted);
        fixture.db.release.complete();
        await peer.waitForRow(inserted.id!);
        received = peer.outbound.map((change) => change.uuidRowId).toList();
        wakeups = peer.recoveryWakeups;
        await peer.close();
      });

      test('then recovery delivers the committed row without a local hint.', () {
        expect(received, [inserted.id]);
        expect(wakeups, greaterThan(0));
      });
    });
  });

  group('Given two caught-up streams sharing a local writer context,', () {
    late _Fixture fixture;
    late _RecoveryObservations observations;
    late FramedSyncPeer first;
    late FramedSyncPeer second;
    late Unique inserted;

    setUpAll(() async {
      fixture = await _fixture();
      observations = _RecoveryObservations();
      first = await FramedSyncPeer.open(
        fixture.node,
        onDiagnostic: observations.record,
      );
      second = await FramedSyncPeer.open(fixture.node);
      await observations.waitForScans(1);
      await first.waitForPass(2);
      await second.waitForPass(2);
      inserted = Unique(id: const Uuid().v7obj(), name: 'announced locally');
    });

    group('when a local insertion commits and two recovery scans observe it,', () {
      late int extraCaptures;
      late int extraWakeups;
      late List<UuidValue> firstReceived;
      late List<UuidValue> secondReceived;

      setUpAll(() async {
        await fixture.node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) =>
              Unique.db.insertRow(fixture.node.offlineSync, inserted, transaction: tx),
        );
        await first.waitForRow(inserted.id!);
        await second.waitForRow(inserted.id!);
        await first.waitForPass(3);
        await second.waitForPass(3);
        final captures = first.stages.length + second.stages.length;
        final wakeups = first.recoveryWakeups + second.recoveryWakeups;
        await observations.waitForScans(observations.completed + 2);
        extraCaptures = first.stages.length + second.stages.length - captures;
        extraWakeups = first.recoveryWakeups + second.recoveryWakeups - wakeups;
        firstReceived = first.outbound.map((c) => c.uuidRowId).toList();
        secondReceived = second.outbound.map((c) => c.uuidRowId).toList();
        await first.close();
        await second.close();
      });

      test('then both streams receive the insertion exactly once.', () {
        expect(firstReceived, [inserted.id]);
        expect(secondReceived, [inserted.id]);
      });

      test('then recovery causes no additional captures for that revision.', () {
        expect(extraCaptures, 0);
        expect(extraWakeups, 0);
        expect(observations.failures, isEmpty);
      });
    });
  });

  group('Given a caught-up stream with its next recovery read held after SQL,', () {
    late _Fixture fixture;
    late _RecoveryObservations observations;
    late FramedSyncPeer peer;
    late OfflineSyncDatabaseSession independentWriter;
    late Unique local;
    late Unique external;

    setUpAll(() async {
      fixture = await _fixture();
      observations = _RecoveryObservations();
      peer = await FramedSyncPeer.open(
        fixture.node,
        onDiagnostic: (event) {
          observations.record(event);
          if (event['name'] == 'sync.recoveryScan' &&
              event['kind'] == 'start' &&
              observations.starts.length == 2) {
            fixture.db.holdNextVersionRead = true;
          }
        },
      );
      await observations.waitForScans(1);
      await peer.waitForPass(2);
      independentWriter = OfflineSyncDatabaseSession.wraps(
        fixture.raw,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await independentWriter.db.initialize();
      local = Unique(id: const Uuid().v7obj(), name: 'local revision');
      external = Unique(id: const Uuid().v7obj(), name: 'external revision');
      await fixture.db.entered.future.timeout(const Duration(seconds: 5));
    });

    group('when local and external commits precede publication of that old read,', () {
      late List<UuidValue> received;

      setUpAll(() async {
        await fixture.node.offlineSync.db.transactionForUser(
          testCrdtUserId,
          (tx) => Unique.db.insertRow(fixture.node.offlineSync, local, transaction: tx),
        );
        await peer.waitForRow(local.id!);
        await peer.waitForPass(3);
        await Unique.db.insertRow(independentWriter, external);
        fixture.db.release.complete();
        await peer.waitForRow(external.id!);
        received = peer.outbound.map((c) => c.uuidRowId).toList();
        await peer.close();
      });

      test(
        'then recovery still delivers the external commit without another write.',
        () {
          expect(received, [local.id, external.id]);
          expect(observations.failures, isEmpty);
        },
      );
    });
  });

  group('Given a caught-up stream and a writer with an independent context,', () {
    late _Fixture fixture;
    late FramedSyncPeer peer;
    late _RecoveryObservations observations;
    late OfflineSyncDatabaseSession writer;
    late Unique rejected;
    late CrdtMergeInsert committed;
    late int capturesBefore;

    setUpAll(() async {
      fixture = await _fixture();
      writer = OfflineSyncDatabaseSession.wraps(
        fixture.raw,
        syncTables: testSyncTables,
        persistentUserId: testCrdtUserId,
      );
      await writer.db.initialize();
      await Unique.db.insertRow(
        writer,
        Unique(id: const Uuid().v7obj(), name: 'existing recent fact'),
      );
      observations = _RecoveryObservations();
      peer = await FramedSyncPeer.open(fixture.node, onDiagnostic: observations.record);
      await observations.waitForScans(1);
      await peer.waitForPass(2);
      peer.outbound.clear();
      rejected = Unique(id: const Uuid().v7obj(), name: 'rolled back elsewhere');
      final id = const Uuid().v7obj();
      committed = CrdtMergeInsert(
        uuidSpaceId: testCrdtUserId,
        tableName: Unique.t.tableName,
        uuidRowId: id,
        uuidNodeId: const Uuid().v7obj(),
        hlcDatetime: DateTime.utc(2026, 1, 1),
        hlcCounter: 0,
        data: Unique(id: id, name: 'older remote fact'),
      );
      capturesBefore = peer.stages.length;
    });

    group(
      'when one external transaction rolls back and an older remote fact then commits,',
      () {
        late int capturesAfterRollback;
        late List<UuidValue> received;
        late Unique? rejectedRow;

        setUpAll(() async {
          try {
            await fixture.raw.db.transaction<void>((tx) async {
              await Unique.db.insertRow(writer, rejected, transaction: tx);
              throw const _Rollback();
            });
          } on _Rollback {
            // Deliberate rollback in a caller-owned transaction.
          }
          await observations.waitForScans(2);
          capturesAfterRollback = peer.stages.length;
          await writer.db.mergeChanges([committed], userId: testCrdtUserId);
          await peer.waitForRow(committed.uuidRowId);
          received = peer.outbound.map((change) => change.uuidRowId).toList();
          rejectedRow = await Unique.db.findById(fixture.raw, rejected.id!);
          await peer.close();
        });

        test(
          'then unchanged durable versions cause no capture after the rollback.',
          () {
            expect(capturesAfterRollback, capturesBefore);
            expect(rejectedRow, isNull);
          },
        );

        test(
          'then the later commit wakes the stream despite its old source timestamp.',
          () {
            expect(received, [committed.uuidRowId]);
            expect(observations.failures, isEmpty);
          },
        );
      },
    );
  });

  group('Given a caught-up stream and membership managed outside its context,', () {
    late _Fixture fixture;
    late FramedSyncPeer peer;
    late OfflineSyncSpace shared;
    late _RecoveryObservations observations;

    setUpAll(() async {
      fixture = await _fixture();
      observations = _RecoveryObservations();
      peer = await FramedSyncPeer.open(fixture.node, onDiagnostic: observations.record);
      await observations.waitForScans(1);
      await peer.waitForPass(2);
      shared = await OfflineSyncSpace.db.insertRow(
        fixture.raw,
        OfflineSyncSpace(uuidSpaceId: const Uuid().v7obj()),
      );
    });

    group('when the shared space is granted and then revoked,', () {
      late OfflineSyncSpaceSet granted;
      late OfflineSyncSpaceSet revoked;

      setUpAll(() async {
        await OfflineSyncSpaceMember.db.insertRow(
          fixture.raw,
          OfflineSyncSpaceMember(
            spaceId: shared.id!,
            userUuid: testCrdtUserId,
            role: OfflineSyncSpaceRole.readWrite,
          ),
        );
        granted = await peer.waitForEvent<OfflineSyncSpaceSet>(
          where: (event) =>
              event.spaces.any((grant) => grant.uuidSpaceId == shared.uuidSpaceId),
        );
        await OfflineSyncSpaceMember.db.deleteWhere(
          fixture.raw,
          where: (t) => t.spaceId.equals(shared.id),
        );
        revoked = await peer.waitForEvent<OfflineSyncSpaceSet>(
          where: (event) =>
              !event.spaces.any((grant) => grant.uuidSpaceId == shared.uuidSpaceId),
        );
        await peer.close();
      });

      test('then recovery announces both permission changes.', () {
        expect(
          granted.spaces.map((grant) => grant.uuidSpaceId),
          contains(shared.uuidSpaceId),
        );
        expect(revoked.spaces.map((grant) => grant.uuidSpaceId), [testCrdtUserId]);
        expect(observations.failures, isEmpty);
      });
    });
  });

  group('Given a recovery scan borrowing a stream session after its SQL read,', () {
    late _Fixture fixture;
    late FramedSyncPeer peer;
    late Completer<void> detached;

    setUpAll(() async {
      fixture = await _fixture();
      detached = Completer<void>();
      peer = await FramedSyncPeer.open(
        fixture.node,
        onDiagnostic: (event) {
          if (event['name'] == 'sync.recoveryScan' && event['kind'] == 'start') {
            fixture.db.holdNextVersionRead = true;
          }
          if (event['name'] == 'sync.recoveryDetached') detached.complete();
        },
      );
      addTearDown(() {
        if (!fixture.db.release.isCompleted) fixture.db.release.complete();
      });
      await fixture.db.entered.future.timeout(const Duration(seconds: 5));
    });

    group('when the stream closes before recovery is released,', () {
      late bool completedBeforeRelease;
      late int nextScanSubscribers;

      setUpAll(() async {
        var completed = false;
        final closing = peer.close().then((_) => completed = true);
        await detached.future.timeout(const Duration(seconds: 5));
        completedBeforeRelease = completed;
        fixture.db.release.complete();
        await closing;
        // A new live subscriber creates a fresh recovery interval and owner.
        // Waiting for that scan also proves the closed subscription is gone.
        final observations = _RecoveryObservations();
        final next = await FramedSyncPeer.open(
          fixture.node,
          onDiagnostic: observations.record,
        );
        await observations.waitForScans(1);
        await next.waitForPass(2);
        await next.close();
        nextScanSubscribers = observations.starts.single['subscriptions']! as int;
      });

      test(
        'then closure joins recovery and the next scan has only the new subscriber.',
        () {
          expect(completedBeforeRelease, isFalse);
          expect(nextScanSubscribers, 1);
        },
      );
    });
  });
}

typedef _Fixture = ({
  SyncNode node,
  database.DatabaseSession raw,
  _CountingDatabase db,
});

Future<_Fixture> _fixture() async {
  final raw = await createAdditionalTestSession();
  final context = OfflineSyncDatabaseContext(
    syncTables: testSyncTables,
    serializationManager: raw.db.serializationManager,
  );
  final db = _CountingDatabase(raw.db, syncTables: testSyncTables, context: context);
  addTearDown(() {
    if (!db.release.isCompleted) db.release.complete();
  });
  final session = OfflineSyncDatabaseSession(db, syncTables: testSyncTables);
  await db.initialize();
  return (
    raw: raw,
    db: db,
    node: (
      raw: session,
      offlineSync: session,
      sync: OfflineSyncEngine(
        syncTables: testSyncTables,
        serializationManager: raw.db.serializationManager,
        databaseContext: context,
      ),
    ),
  );
}

class _RecoveryObservations {
  final starts = <Map<String, Object?>>[];
  final failures = <Map<String, Object?>>[];
  final _waiting = <int, Completer<void>>{};
  int completed = 0;

  void record(Map<String, Object?> event) {
    if (event['name'] == 'sync.recoveryScan') {
      if (event['kind'] == 'start') {
        starts.add(event['data']! as Map<String, Object?>);
      } else if (event['kind'] == 'end') {
        _waiting.remove(++completed)?.complete();
      }
    }
    if (event['name'] == 'sync.recoveryFailed') failures.add(event);
  }

  Future<void> waitForScans(int count) async {
    if (completed >= count) return;
    await (_waiting[count] ??= Completer<void>()).future.timeout(
      const Duration(seconds: 10),
    );
  }
}

class _CountingDatabase extends OfflineSyncDatabase {
  _CountingDatabase(
    super.delegate, {
    required super.syncTables,
    required super.context,
  });

  int reads = 0;
  bool holdNextVersionRead = false;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<T>> find<T extends database.TableRow>({
    database.Expression? where,
    int? limit,
    int? offset,
    database.Column? orderBy,
    List<database.Column>? orderByList,
    bool orderDescending = false,
    database.Transaction? transaction,
    database.Include? include,
    database.LockMode? lockMode,
    database.LockBehavior? lockBehavior,
  }) async {
    if (T == OfflineSyncSpace || T == OfflineSyncSpaceMember) reads++;
    final rows = await super.find<T>(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      orderDescending: orderDescending,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
    if (T == OfflineSyncSpace && holdNextVersionRead && !entered.isCompleted) {
      holdNextVersionRead = false;
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

class _Rollback implements Exception {
  const _Rollback();
}
