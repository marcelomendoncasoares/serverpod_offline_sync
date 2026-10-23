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

  group('Given a continuous follower held while reading an adopted space cursor,', () {
    late _HoldCursorDatabase gate;
    late _Peer peer;
    late OfflineSyncDatabaseContext context;
    late Completer<void> joining;
    late Completer<int> recoverySubscribers;
    late List<Timer> periodicTimers;
    late UuidValue sharedSpace;

    setUpAll(() async {
      final raw = await createAdditionalTestSession();
      context = OfflineSyncDatabaseContext(
        syncTables: testSyncTables,
        serializationManager: raw.db.serializationManager,
      );
      gate = _HoldCursorDatabase(raw.db, syncTables: testSyncTables, context: context);
      final wrapped = OfflineSyncDatabaseSession(gate, syncTables: testSyncTables);
      await gate.initialize();
      final node = (
        raw: wrapped,
        offlineSync: wrapped,
        sync: OfflineSyncEngine(
          syncTables: testSyncTables,
          serializationManager: raw.db.serializationManager,
          databaseContext: context,
        ),
      );
      joining = Completer<void>();
      recoverySubscribers = Completer<int>();
      periodicTimers = [];
      sharedSpace = const Uuid().v7obj();
      peer = await runZoned(
        () => OfflineSyncDiagnostics.run((event) {
          if (event['name'] == 'sync.peer') gate.holdNextCursor = true;
          if (event['name'] == 'sync.stage' &&
              (event['data']! as Map)['phase'] == 'cleanup.join') {
            joining.complete();
          }
          if (event['name'] == 'sync.recoveryScan' &&
              event['kind'] == 'start' &&
              !recoverySubscribers.isCompleted) {
            recoverySubscribers.complete(
              (event['data']! as Map)['subscriptions'] as int,
            );
          }
        }, () => _Peer.start(node: node, mode: OfflineSyncPeerMode.follower)),
        zoneSpecification: ZoneSpecification(
          createPeriodicTimer: (self, parent, zone, duration, callback) {
            final timer = parent.createPeriodicTimer(zone, duration, callback);
            periodicTimers.add(timer);
            return timer;
          },
        ),
      );
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
        for (final timer in periodicTimers) {
          timer.cancel();
        }
      });
      final hello = await peer.waitFor<OfflineSyncConnect>();
      peer.send(
        OfflineSyncConnect(
          localNodeId: const Uuid().v7obj(),
          syncTablesHash: hello.syncTablesHash,
          spaces: [
            OfflineSyncSpaceGrant(
              uuidSpaceId: testCrdtUserId,
              role: OfflineSyncSpaceRole.readWrite,
            ),
            OfflineSyncSpaceGrant(
              uuidSpaceId: sharedSpace,
              role: OfflineSyncSpaceRole.readWrite,
            ),
          ],
        ),
      );
      await gate.entered.future.timeout(const Duration(seconds: 5));
    });

    group('when output cancellation starts before that cursor read resumes,', () {
      late bool completedBeforeRelease;
      late int remainingTimers;
      late int notifiedListeners;
      late int nextScanSubscribers;
      late List<OfflineSyncReady> readyFrames;

      setUpAll(() async {
        var completed = false;
        final closing = peer.subscription.cancel().then((_) => completed = true);
        await joining.future.timeout(const Duration(seconds: 5));
        completedBeforeRelease = completed;
        gate.release.complete();
        await closing.timeout(const Duration(seconds: 5));
        remainingTimers = periodicTimers.where((timer) => timer.isActive).length;
        readyFrames = peer.events.whereType<OfflineSyncReady>().toList();

        // A real commit after cancellation must find no listener from the peer.
        notifiedListeners = -1;
        await OfflineSyncDiagnostics.run(
          (event) {
            if (event['name'] == 'sync.commitNotification') {
              notifiedListeners = (event['data']! as Map)['listenersNotified'] as int;
            }
          },
          () => gate.transactionForUser(
            testCrdtUserId,
            (tx) => Unique.db.insertRow(
              peer.node.offlineSync,
              Unique(id: const Uuid().v7obj(), name: 'after cancellation'),
              transaction: tx,
            ),
          ),
        );

        // The next live stream must be the only owner of a recovery scan.
        final next = await FramedSyncPeer.open(
          peer.node,
          onDiagnostic: (event) {
            if (event['name'] == 'sync.recoveryScan' &&
                event['kind'] == 'start' &&
                !recoverySubscribers.isCompleted) {
              recoverySubscribers.complete(
                (event['data']! as Map)['subscriptions'] as int,
              );
            }
          },
        );
        nextScanSubscribers = await recoverySubscribers.future.timeout(
          const Duration(seconds: 5),
        );
        await next.close();
      });

      test('then cancellation joins cursor work without announcing readiness.', () {
        expect(completedBeforeRelease, isFalse);
        expect(readyFrames, isEmpty);
      });

      test('then no periodic recovery timer or local commit listener remains.', () {
        expect(remainingTimers, 0);
        expect(notifiedListeners, 0);
      });

      test('then the next recovery scan contains only its live subscriber.', () {
        expect(nextScanSubscribers, 1);
      });
    });
  });

  group('Given a continuous peer held in its committed acknowledgement callback,', () {
    late _Peer peer;
    late Completer<void> entered;
    late Completer<void> release;
    late Completer<void> joining;
    late bool callbackCompleted;
    late List<String> callbackRows;

    setUpAll(() async {
      final node = await syncNode(await createAdditionalTestSession(), testSyncTables);
      await node.offlineSync.db.mergeChanges([
        _insert('acknowledged row'),
      ], userId: testCrdtUserId);
      entered = Completer<void>();
      release = Completer<void>();
      joining = Completer<void>();
      callbackCompleted = false;
      callbackRows = [];
      peer = await OfflineSyncDiagnostics.run(
        (event) {
          if (event['name'] == 'sync.stage' &&
              (event['data']! as Map)['phase'] == 'cleanup.join') {
            joining.complete();
          }
        },
        () => _Peer.open(
          node: node,
          onMergeSuccess: (_, _) async {
            entered.complete();
            await release.future;
            callbackRows = (await Unique.db.find(
              node.raw,
            )).map((row) => row.name).toList();
            callbackCompleted = true;
          },
        ),
      );
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final batch = await peer.waitFor<OfflineSyncEndOfBatch>();
      peer.send(OfflineSyncCommitted(batchId: batch.batchId));
      await entered.future.timeout(const Duration(seconds: 5));
    });

    group('when output cancellation starts before the callback resumes,', () {
      late bool completedBeforeRelease;
      late bool callbackCompletedAtCancellation;
      late List<String> rowsAtCancellation;

      setUpAll(() async {
        var completed = false;
        final closing = peer.subscription.cancel().then((_) => completed = true);
        await joining.future.timeout(const Duration(seconds: 5));
        completedBeforeRelease = completed;
        release.complete();
        await closing.timeout(const Duration(seconds: 5));
        callbackCompletedAtCancellation = callbackCompleted;
        rowsAtCancellation = List.of(callbackRows);
      });

      test('then cancellation joins the callback and its final database read.', () {
        expect(completedBeforeRelease, isFalse);
        expect(callbackCompletedAtCancellation, isTrue);
        expect(rowsAtCancellation, ['acknowledged row']);
      });
    });
  });

  test(
    'Given an authoritative session with its own grants and cursors, '
    'when the follower has not sent its identity yet, '
    'then initialization is already announced as ready.',
    () async {
      final peer = await _Peer.start();

      await peer.waitFor<OfflineSyncReady>();
      final events = List.of(peer.events);

      expect(events, hasLength(3));
      expect(events.first, isA<OfflineSyncConnect>());
      expect(events[1], isA<OfflineSyncSinceHlc>());
      expect(events.last, isA<OfflineSyncReady>());
    },
  );

  test(
    'Given a session awaiting its peer identity, '
    'when a batch boundary arrives first, '
    'then it rejects the invalid frame order.',
    () async {
      final peer = await _Peer.start();

      peer.send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: false));
      final error = await peer.done.future;

      expect(error, isA<OfflineSyncUnexpectedEventException>());
    },
  );

  test(
    'Given a finite follower that knows its server grants but cannot capture yet, '
    'when server readiness allows it to prepare the upload, '
    'then it announces its readiness immediately before that finite batch.',
    () async {
      final initialized = Completer<void>();
      final peer = await OfflineSyncDiagnostics.run((event) {
        if (event['name'] == 'sync.stage' &&
            (event['data']! as Map)['phase'] == 'active' &&
            !initialized.isCompleted) {
          initialized.complete();
        }
      }, () => _Peer.start(once: true, mode: OfflineSyncPeerMode.follower));
      final connect = await peer.waitFor<OfflineSyncConnect>();
      peer
        ..send(connect)
        ..send(OfflineSyncSinceHlc(uuidSpaceId: testCrdtUserId, nodeCheckpoints: []));
      await initialized.future.timeout(const Duration(seconds: 5));
      final before = List.of(peer.events);

      peer.send(OfflineSyncReady());
      final boundary = await peer.waitFor<OfflineSyncEndOfBatch>();
      final after = List.of(peer.events);

      expect(before.whereType<OfflineSyncReady>(), isEmpty);
      expect(after.whereType<OfflineSyncReady>(), hasLength(1));
      expect(after[after.indexOf(boundary) - 1], isA<OfflineSyncReady>());
      expect(boundary.finalForOnce, isTrue);
    },
  );

  test(
    'Given a continuous follower that knows its server grants, '
    'when the server has not announced readiness, '
    'then the follower still announces readiness independently.',
    () async {
      final peer = await _Peer.start(mode: OfflineSyncPeerMode.follower);
      final connect = await peer.waitFor<OfflineSyncConnect>();

      peer
        ..send(connect)
        ..send(OfflineSyncSinceHlc(uuidSpaceId: testCrdtUserId, nodeCheckpoints: []));
      await peer.waitFor<OfflineSyncReady>();
      final events = List.of(peer.events);

      expect(events.whereType<OfflineSyncReady>(), hasLength(1));
      expect(events.whereType<OfflineSyncEndOfBatch>(), isEmpty);
    },
  );

  test(
    'Given a finite session awaiting its peer identity, '
    'when the transport closes without a frame, '
    'then it reports truncation.',
    () async {
      final peer = await _Peer.start(once: true);

      unawaited(peer.input.close());
      final error = await peer.done.future;

      expect(error, isA<OfflineSyncStreamClosedException>());
    },
  );

  test(
    'Given a follower whose finite upload is acknowledged, '
    'when it commits the final download and sends its acknowledgement, '
    'then it completes with both durable boundaries without another server frame.',
    () async {
      final peer = await _Peer.open(once: true, mode: OfflineSyncPeerMode.follower);
      final upload = await peer.waitFor<OfflineSyncEndOfBatch>();
      peer.send(OfflineSyncCommitted(batchId: upload.batchId));
      final downloaded = _insert('final download');

      peer
        ..send(OfflineSyncMergeChunk(batchId: 1, changes: [downloaded]))
        ..send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
      final error = await peer.done.future.timeout(const Duration(seconds: 5));
      final row = await Unique.db.findById(peer.node.raw, downloaded.uuidRowId);
      final cursor = await peer.node.sync.createSyncSinceHlc(
        peer.node.raw,
        spaceId: testCrdtUserId,
      );

      expect(error, isNull);
      expect(row?.name, 'final download');
      expect(
        cursor.nodeCheckpoints.where((h) => h.nodeId == downloaded.uuidNodeId).single,
        downloaded.hlc,
      );
      expect(peer.events.whereType<OfflineSyncCommitted>().single.batchId, 1);
      expect(peer.input.isClosed, isFalse);
    },
  );

  group('Given a finite server preparing its space membership before capture,', () {
    late _HoldMembershipDatabase gate;
    late _Peer peer;

    setUpAll(() async {
      final raw = await createAdditionalTestSession();
      gate = _HoldMembershipDatabase(raw.db, syncTables: testSyncTables);
      final wrapped = OfflineSyncDatabaseSession(gate, syncTables: testSyncTables);
      final node = await syncNode(wrapped, testSyncTables);
      await node.offlineSync.db.mergeChanges([
        _insert('server row'),
      ], userId: testCrdtUserId);
      peer = (await _Peer.open(once: true, node: node))..acknowledgeOutbound = true;
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
      });
      await gate.entered.future.timeout(const Duration(seconds: 5));
    });

    group('when the upload commits while that preparation is held,', () {
      late Object? error;
      late List<OfflineSyncEndOfBatch> boundaries;
      late List<CrdtMergeChange> changes;

      setUpAll(() async {
        peer.send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
        await peer.waitFor<OfflineSyncCommitted>();
        gate.release.complete();
        error = await peer.done.future.timeout(const Duration(seconds: 5));
        boundaries = peer.events.whereType<OfflineSyncEndOfBatch>().toList();
        changes = peer.events
            .whereType<OfflineSyncMergeChunk>()
            .expand((e) => e.changes)
            .toList();
      });

      test(
        'then its first capture satisfies the final boundary without another batch.',
        () {
          expect(error, isNull);
          expect(boundaries, hasLength(1));
          expect(boundaries.single.finalForOnce, isTrue);
          expect(
            (changes.single as CrdtMergeInsert).data,
            isA<Unique>().having((r) => r.name, 'name', 'server row'),
          );
        },
      );
    });
  });

  group('Given a finite server with a complete upload still being applied,', () {
    late _Peer peer;
    late _HoldMembershipDatabase gate;
    late Completer<void> mergeEntered;
    late Completer<void> releaseMerge;
    late Completer<void> captureDeferred;

    setUpAll(() async {
      mergeEntered = Completer<void>();
      releaseMerge = Completer<void>();
      captureDeferred = Completer<void>();
      final raw = await createAdditionalTestSession();
      gate = _HoldMembershipDatabase(raw.db, syncTables: testSyncTables);
      final wrapped = OfflineSyncDatabaseSession(gate, syncTables: testSyncTables);
      final node = await syncNode(wrapped, testSyncTables);
      await node.offlineSync.db.mergeChanges([
        _insert('existing server row'),
      ], userId: testCrdtUserId);
      peer = await OfflineSyncDiagnostics.run(
        (event) {
          if (event['name'] == 'sync.captureDeferredForUpload' &&
              !captureDeferred.isCompleted) {
            captureDeferred.complete();
          }
        },
        () => _Peer.open(
          once: true,
          node: node,
          onMergeSuccess: (_, _) async {
            if (mergeEntered.isCompleted) return;
            mergeEntered.complete();
            await releaseMerge.future;
          },
        ),
      );
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
        if (!releaseMerge.isCompleted) releaseMerge.complete();
      });
      peer.acknowledgeOutbound = true;
      await gate.entered.future.timeout(const Duration(seconds: 5));
      final upload = _insert('uploaded row');
      peer
        ..send(
          OfflineSyncSinceHlc(
            uuidSpaceId: testCrdtUserId,
            nodeCheckpoints: [upload.hlc],
          ),
        )
        ..send(OfflineSyncMergeChunk(batchId: 1, changes: [upload]))
        ..send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
      await mergeEntered.future.timeout(const Duration(seconds: 5));
    });

    group('when capture preparation finishes before that upload is acknowledged,', () {
      late List<OfflineSyncEndOfBatch> beforeUploadCompletion;
      late List<OfflineSyncEndOfBatch> boundaries;
      late List<CrdtMergeChange> changes;
      late List<String> committedNames;
      late Object? error;

      setUpAll(() async {
        gate.release.complete();
        await captureDeferred.future.timeout(const Duration(seconds: 5));
        beforeUploadCompletion = peer.events
            .whereType<OfflineSyncEndOfBatch>()
            .toList();
        releaseMerge.complete();
        error = await peer.done.future.timeout(const Duration(seconds: 5));
        boundaries = peer.events.whereType<OfflineSyncEndOfBatch>().toList();
        changes = peer.events
            .whereType<OfflineSyncMergeChunk>()
            .expand((event) => event.changes)
            .toList();
        committedNames = (await Unique.db.find(
          peer.node.raw,
        )).map((row) => row.name).toList();
      });

      test('then one final download follows the completed upload.', () {
        expect(error, isNull);
        expect(beforeUploadCompletion, isEmpty);
        expect(boundaries, hasLength(1));
        expect(boundaries.single.finalForOnce, isTrue);
        expect(
          (changes.single as CrdtMergeInsert).data,
          isA<Unique>().having((row) => row.name, 'name', 'existing server row'),
        );
      });

      test('then both the upload and existing server row remain durable.', () {
        expect(
          committedNames,
          unorderedEquals(['existing server row', 'uploaded row']),
        );
        expect(peer.events.whereType<OfflineSyncCommitted>().single.batchId, 1);
      });
    });
  });

  test(
    'Given a finite server with existing data and a partial upload, '
    'when the upload has not sent its end marker, '
    'then the server can send existing changes without waiting for the upload.',
    () async {
      final raw = await createAdditionalTestSession();
      final gate = _HoldMembershipDatabase(raw.db, syncTables: testSyncTables);
      final wrapped = OfflineSyncDatabaseSession(gate, syncTables: testSyncTables);
      final node = await syncNode(wrapped, testSyncTables);
      await node.offlineSync.db.mergeChanges([
        _insert('download during upload'),
      ], userId: testCrdtUserId);
      final peer = await _Peer.open(once: true, node: node);
      addTearDown(() {
        if (!gate.release.isCompleted) gate.release.complete();
      });
      await gate.entered.future.timeout(const Duration(seconds: 5));

      peer.send(
        OfflineSyncMergeChunk(batchId: 1, changes: [_insert('partial upload')]),
      );
      gate.release.complete();
      final boundary = await peer.waitFor<OfflineSyncEndOfBatch>();
      final changes = peer.events
          .whereType<OfflineSyncMergeChunk>()
          .expand((event) => event.changes)
          .toList();
      final rows = await Unique.db.find(node.raw);

      expect(boundary.finalForOnce, isFalse);
      expect(
        (changes.single as CrdtMergeInsert).data,
        isA<Unique>().having((row) => row.name, 'name', 'download during upload'),
      );
      expect(rows.map((row) => row.name), ['download during upload']);
      expect(peer.events.whereType<OfflineSyncCommitted>(), isEmpty);
    },
  );

  test(
    'Given a connected peer with a multi-chunk batch, '
    'when its numbered end marker arrives, '
    'then its acknowledgement proves both rows and their cursor are durable.',
    () async {
      final peer = await _Peer.open();
      final first = _insert('first');
      final second = _insert('second').copyWith(
        uuidNodeId: first.uuidNodeId,
        hlcDatetime: first.hlcDatetime.add(const Duration(seconds: 1)),
      );

      peer
        ..send(OfflineSyncMergeChunk(batchId: 1, changes: [first]))
        ..send(OfflineSyncMergeChunk(batchId: 1, changes: [second]))
        ..send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: false));
      await peer.waitFor<OfflineSyncCommitted>();
      final rows = await Unique.db.find(peer.node.raw);
      final cursor = await peer.node.sync.createSyncSinceHlc(
        peer.node.raw,
        spaceId: testCrdtUserId,
      );

      expect(rows.map((r) => r.name), unorderedEquals(['first', 'second']));
      expect(
        cursor.nodeCheckpoints.where((h) => h.nodeId == first.uuidNodeId).single,
        second.hlc,
      );
    },
  );

  test(
    'Given a connected peer with no changes, '
    'when it sends an empty numbered batch, '
    'then it receives an acknowledgement without creating domain rows.',
    () async {
      final peer = await _Peer.open();

      peer.send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: false));
      final ack = await peer.waitFor<OfflineSyncCommitted>();
      final rows = await Unique.db.find(peer.node.raw);

      expect(ack.batchId, 1);
      expect(rows, isEmpty);
    },
  );

  test(
    'Given an established peer expecting its first batch, '
    'when a different batch number is terminated, '
    'then the session rejects it without advancing a cursor.',
    () async {
      final peer = await _Peer.open();

      peer.send(OfflineSyncEndOfBatch(batchId: 2, finalForOnce: false));
      final error = await peer.done.future;
      final nodes = await OfflineSyncSpaceNode.db.find(peer.node.raw);

      expect(error, isA<OfflineSyncUnexpectedEventException>());
      expect(peer.events.whereType<OfflineSyncCommitted>(), isEmpty);
      expect(nodes.where((n) => n.lastReceivedHlc != null), isEmpty);
    },
  );

  test(
    'Given an established peer with no outbound batch, '
    'when it acknowledges a nonexistent batch, '
    'then the session rejects the acknowledgement.',
    () async {
      final peer = await _Peer.open();

      peer.send(OfflineSyncCommitted(batchId: 1));
      final error = await peer.done.future;

      expect(error, isA<OfflineSyncUnexpectedEventException>());
    },
  );

  test(
    'Given a peer that already sent its identity, '
    'when it sends another Connect, '
    'then the session rejects reinitialization.',
    () async {
      final peer = await _Peer.open();

      peer.send(peer.hello);
      final error = await peer.done.future;

      expect(error, isA<OfflineSyncUnexpectedEventException>());
    },
  );

  test(
    'Given an established peer holding a partial batch, '
    'when transport EOF arrives without its end marker, '
    'then the session fails and does not apply the partial row.',
    () async {
      final peer = await _Peer.open();
      final change = _insert('partial');

      peer.send(OfflineSyncMergeChunk(batchId: 1, changes: [change]));
      unawaited(peer.input.close());
      final error = await peer.done.future;
      final row = await Unique.db.findById(peer.node.raw, change.uuidRowId);

      expect(error, isA<OfflineSyncStreamClosedException>());
      expect(row, isNull);
      expect(peer.events.whereType<OfflineSyncCommitted>(), isEmpty);
    },
  );

  group('Given a finite server session and an uploaded insertion,', () {
    late _Peer peer;
    late CrdtMergeInsert insertion;

    setUpAll(() async {
      peer = await _Peer.open(once: true);
      insertion = _insert('uploaded');
    });

    group('when the upload commits and the final download is acknowledged,', () {
      late Unique? committedRow;
      late bool completedBeforeAck;
      late Object? error;
      late List<OfflineSyncStreamEvent> events;

      setUpAll(() async {
        peer
          ..send(OfflineSyncMergeChunk(batchId: 1, changes: [insertion]))
          ..send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
        await peer.waitFor<OfflineSyncCommitted>();
        final boundary = await peer.waitFor<OfflineSyncEndOfBatch>(
          where: (event) => event.finalForOnce,
        );
        committedRow = await Unique.db.findById(peer.node.raw, insertion.uuidRowId);
        completedBeforeAck = peer.done.isCompleted;
        peer.send(OfflineSyncCommitted(batchId: boundary.batchId));
        error = await peer.done.future;
        events = List.of(peer.events);
      });

      test('then the upload is durable before the final download boundary.', () {
        expect(committedRow?.name, 'uploaded');
        expect(
          events.indexWhere((e) => e is OfflineSyncCommitted),
          lessThan(
            events.indexWhere((e) => e is OfflineSyncEndOfBatch && e.finalForOnce),
          ),
        );
      });

      test('then success requires acknowledgement of the final download.', () {
        expect(completedBeforeAck, isFalse);
        expect(error, isNull);
        expect(
          events.whereType<OfflineSyncEndOfBatch>().where((e) => e.finalForOnce),
          hasLength(1),
        );
      });
    });
  });

  test(
    'Given a finite session whose upload already committed, '
    'when the transport closes before the download acknowledgement, '
    'then the call fails while the committed upload remains resumable.',
    () async {
      final peer = await _Peer.open(once: true);
      final insertion = _insert('committed before disconnect');

      peer
        ..send(OfflineSyncMergeChunk(batchId: 1, changes: [insertion]))
        ..send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
      await peer.waitFor<OfflineSyncCommitted>();
      await peer.waitFor<OfflineSyncEndOfBatch>(where: (e) => e.finalForOnce);
      unawaited(peer.input.close());
      final error = await peer.done.future;
      final row = await Unique.db.findById(peer.node.raw, insertion.uuidRowId);
      final cursor = await peer.node.sync.createSyncSinceHlc(
        peer.node.raw,
        spaceId: testCrdtUserId,
      );

      expect(error, isA<OfflineSyncStreamClosedException>());
      expect(
        row?.name,
        insertion.data is Unique ? (insertion.data as Unique).name : null,
      );
      expect(
        cursor.nodeCheckpoints.where((h) => h.nodeId == insertion.uuidNodeId).single,
        insertion.hlc,
      );
    },
  );

  test(
    'Given a finite follower still awaiting its upload acknowledgement, '
    'when the server sends Close, '
    'then the follower rejects premature success.',
    () async {
      final peer = await _Peer.open(once: true, mode: OfflineSyncPeerMode.follower);

      peer.send(OfflineSyncClose());
      final error = await peer.done.future;

      expect(error, isA<OfflineSyncUnexpectedEventException>());
    },
  );

  test(
    'Given a follower that applied its final download without an upload acknowledgement, '
    'when the server requests closure, '
    'then the follower rejects completion because upload durability is unproven.',
    () async {
      final peer = await _Peer.open(once: true, mode: OfflineSyncPeerMode.follower);
      await peer.waitFor<OfflineSyncEndOfBatch>();
      peer.send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: true));
      await peer.waitFor<OfflineSyncCommitted>();
      final completedWithoutUploadAck = peer.done.isCompleted;

      peer.send(OfflineSyncClose());
      final error = await peer.done.future;

      expect(completedWithoutUploadAck, isFalse);
      expect(error, isA<OfflineSyncUnexpectedEventException>());
    },
  );

  test(
    'Given a sender awaiting commitment of its first outbound batch, '
    'when another row commits and an inbound batch arrives, '
    'then inbound acknowledgement proceeds before the next outbound batch.',
    () async {
      final peer = await _Peer.open();
      final first = _insert('outbound first');
      final second = _insert('outbound second');
      await peer.node.offlineSync.db.mergeChanges([first], userId: testCrdtUserId);
      // This node deliberately uses a separate recorder context. An inbound
      // batch requests a capture without a wall-clock polling barrier.
      peer.send(OfflineSyncEndOfBatch(batchId: 1, finalForOnce: false));
      final firstBatch = await peer.waitFor<OfflineSyncEndOfBatch>();
      await peer.node.offlineSync.db.mergeChanges([second], userId: testCrdtUserId);

      peer.send(OfflineSyncEndOfBatch(batchId: 2, finalForOnce: false));
      await peer.waitFor<OfflineSyncCommitted>(where: (e) => e.batchId == 2);
      final batchesBeforeAck = peer.events.whereType<OfflineSyncEndOfBatch>().length;
      peer.send(OfflineSyncCommitted(batchId: firstBatch.batchId));
      final next = await peer.waitFor<OfflineSyncEndOfBatch>(
        where: (e) => e.batchId > firstBatch.batchId,
      );
      final rows = peer.events
          .whereType<OfflineSyncMergeChunk>()
          .where((e) => e.batchId == next.batchId)
          .expand((e) => e.changes)
          .toList();

      expect(batchesBeforeAck, 1);
      expect(rows.map((c) => c.uuidRowId), [second.uuidRowId]);
    },
  );
}

class _Peer {
  _Peer(this.node);

  final SyncNode node;
  final input = StreamController<OfflineSyncStreamEvent>();
  final events = <OfflineSyncStreamEvent>[];
  final done = Completer<Object?>();
  final changed = StreamController<void>.broadcast();
  late final StreamSubscription<OfflineSyncStreamEvent> subscription;
  late final OfflineSyncConnect hello;
  Object? error;
  bool acknowledgeOutbound = false;

  static Future<_Peer> open({
    bool once = false,
    OfflineSyncPeerMode mode = OfflineSyncPeerMode.authoritative,
    SyncNode? node,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) async {
    final peer = await start(
      once: once,
      mode: mode,
      node: node,
      onMergeSuccess: onMergeSuccess,
    );
    await peer.initialize();
    return peer;
  }

  static Future<_Peer> start({
    bool once = false,
    OfflineSyncPeerMode mode = OfflineSyncPeerMode.authoritative,
    SyncNode? node,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) async {
    node ??= await syncNode(await createAdditionalTestSession(), testSyncTables);
    final peer = _Peer(node);
    peer.subscription = node.sync
        .sync(
          node.raw,
          userId: testCrdtUserId,
          inbound: peer.input.stream,
          mode: mode,
          once: once,
          onMergeSuccess: onMergeSuccess,
        )
        .listen(
          (event) {
            peer.events.add(event);
            peer.changed.add(null);
            if (peer.acknowledgeOutbound && event is OfflineSyncEndOfBatch) {
              peer.send(OfflineSyncCommitted(batchId: event.batchId));
            }
          },
          onError: (Object error) => peer.error = error,
          onDone: () => peer.done.complete(peer.error),
        );
    addTearDown(peer.close);
    return peer;
  }

  Future<void> close() async {
    await subscription.cancel();
    if (!input.isClosed) unawaited(input.close());
    await changed.close();
  }

  Future<void> initialize() async {
    final connect = await waitFor<OfflineSyncConnect>();
    hello = OfflineSyncConnect(
      localNodeId: const Uuid().v7obj(),
      syncTablesHash: connect.syncTablesHash,
      spaces: [
        OfflineSyncSpaceGrant(
          uuidSpaceId: testCrdtUserId,
          role: OfflineSyncSpaceRole.readWrite,
        ),
      ],
    );
    send(hello);
    send(OfflineSyncSinceHlc(uuidSpaceId: testCrdtUserId, nodeCheckpoints: []));
    send(OfflineSyncReady());
    await waitFor<OfflineSyncReady>();
  }

  void send(OfflineSyncStreamEvent event) => input.add(event);

  Future<T> waitFor<T extends OfflineSyncStreamEvent>({bool Function(T)? where}) async {
    while (true) {
      final matching = events.whereType<T>().where((e) => where?.call(e) ?? true);
      if (matching.isNotEmpty) return matching.first;
      await changed.stream.first.timeout(const Duration(seconds: 5));
    }
  }
}

CrdtMergeInsert _insert(String name) {
  final id = const Uuid().v7obj();
  return CrdtMergeInsert(
    uuidSpaceId: testCrdtUserId,
    tableName: Unique.t.tableName,
    uuidRowId: id,
    uuidNodeId: const Uuid().v7obj(),
    hlcDatetime: DateTime.utc(2026, 1, 1),
    hlcCounter: 0,
    data: Unique(id: id, name: name),
  );
}

/// Holds a real cursor query after the peer has announced a new shared space.
class _HoldCursorDatabase extends OfflineSyncDatabase {
  _HoldCursorDatabase(
    super.delegate, {
    required super.syncTables,
    required super.context,
  });

  bool holdNextCursor = false;
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
    if (T == OfflineSyncSpaceNode && holdNextCursor) {
      holdNextCursor = false;
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

/// Holds the second real membership read: initialization has completed, but the
/// first outbound snapshot has not started. The query itself has finished.
class _HoldMembershipDatabase extends OfflineSyncDatabase {
  _HoldMembershipDatabase(super.delegate, {required super.syncTables});

  final entered = Completer<void>();
  final release = Completer<void>();
  int reads = 0;

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
    if (T == OfflineSyncSpaceMember && ++reads == 2) {
      entered.complete();
      await release.future;
    }
    return rows;
  }
}
