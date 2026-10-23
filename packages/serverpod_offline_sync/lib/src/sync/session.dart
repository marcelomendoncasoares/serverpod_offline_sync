part of 'engine.dart';

/// One independent sender, one serial merger, and an always-reading control
/// path. No database transaction spans a peer acknowledgement or stream wait.
class _SyncSession {
  _SyncSession(
    this.engine,
    this.session, {
    required this.userId,
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    required this.once,
    required this.onMergeSuccess,
  }) : spaces = OfflineSyncSpaceState(session, userId: userId, mode: mode),
       input = StreamIterator(inbound) {
    output = StreamController<OfflineSyncStreamEvent>(
      onListen: () => unawaited(_run()),
      onCancel: _cancel,
    );
  }

  final OfflineSyncEngine engine;
  final DatabaseSession session;
  final UuidValue userId;
  final bool once;
  final OfflineSyncOnMergeSuccess? onMergeSuccess;
  final OfflineSyncSpaceState spaces;
  final StreamIterator<OfflineSyncStreamEvent> input;
  late final StreamController<OfflineSyncStreamEvent> output;
  final cancellation = OfflineSyncCancellation();
  final received = _ReceivedChanges();
  final subscriptions = <UuidValue, void Function()>{};
  final completion = Completer<void>();
  final settled = Completer<void>();

  Future<void> spaceWork = Future.value();
  Future<void>? sending;
  Future<void>? merging;
  Future<void>? handling;
  OfflineSyncRecoverySubscription? recovery;
  Object? failure;
  StackTrace? failureStack;
  _SentBatch? inFlight;
  List<CrdtMergeChange> incoming = [];
  int nextIncomingId = 1;
  int nextOutgoingId = 1;
  bool inboundBusy = false;
  bool connected = false;
  bool ready = false;
  bool peerReady = false;
  bool dirty = true;
  bool stopped = false;
  bool uploadSent = false;
  bool uploadCommitted = false;
  bool finalRequested = false;
  bool finalApplied = false;
  int pass = 0;
  DateTime? lastCapture;

  Stream<OfflineSyncStreamEvent> get stream => output.stream;

  void _stage(String phase) => OfflineSyncDiagnostics.event('sync.stage', {
    'phase': phase,
  });

  void _emit(OfflineSyncStreamEvent event) {
    if (!stopped && !output.isClosed) output.add(event);
  }

  void _fail(Object error, StackTrace stack) {
    if (completion.isCompleted) return;
    failure = error;
    failureStack = stack;
    completion.complete();
  }

  void _finish() {
    if (!completion.isCompleted) completion.complete();
  }

  Future<void> _cancel() async {
    if (settled.isCompleted) return;
    stopped = true;
    cancellation.cancel();
    _finish();
    // Signal the transaction before joining any pending SQL or protocol work.
    await input.cancel().timeout(const Duration(milliseconds: 200), onTimeout: () {});
    await settled.future;
  }

  Future<void> _run() async {
    try {
      _stage('handshake.localNode');
      final localNode = await OfflineSyncSpaceManager(
        session,
      ).getOrCreateUserNode(userId);
      if (stopped) return;

      _stage('handshake.reconcileSpaces');
      await spaces.reconcile();
      _emit(
        OfflineSyncConnect(
          localNodeId: localNode.uuidNodeId,
          syncTablesHash: engine.currentSyncTablesHash,
          spaces: spaces.localGrants,
        ),
      );
      spaces.markAnnounced();

      // Resume vectors can travel with initialization, before the peer's hello
      // arrives. Follower cache entries never grant access on the server.
      final initialSpaces = spaces.isAuthoritative
          ? spaces.activeSpaceIds
          : (await OfflineSyncSpaceMembership.memberGrants(
              session,
              userId,
            )).map((grant) => grant.uuidSpaceId);
      for (final id in initialSpaces) {
        await _sendCursor(id);
      }
      if (stopped) return;
      if (spaces.isAuthoritative) {
        // Authoritative grants and cursors are already complete. Advertising
        // readiness does not depend on receiving the follower's identity.
        ready = true;
        _emit(OfflineSyncReady());
      }

      _stage('handshake.waitForPeerConnect');
      unawaited(_read());
      await completion.future;
    } on Object catch (error, stack) {
      _fail(error, stack);
    } finally {
      stopped = true;
      cancellation.cancel();
      if (failure != null) {
        await input.cancel().timeout(
          const Duration(milliseconds: 200),
          onTimeout: () {},
        );
      }
      // All callbacks and SQL settle before the caller releases its session.
      _stage('cleanup.join');
      await sending;
      await merging;
      await spaceWork;
      // Join callbacks for the current frame, without waiting for peer EOF.
      await handling;
      await recovery?.close();
      for (final unsubscribe in subscriptions.values) {
        unsubscribe();
      }
      subscriptions.clear();
      incoming.clear();
      inFlight = null;
      received.clear();
      _stage('cleanup');
      if (failure != null && !output.isClosed) {
        output.addError(failure!, failureStack);
      }
      _stage('finished');
      unawaited(output.close());
      settled.complete();
    }
  }

  Future<void> _withSpaces(Future<void> Function() action) {
    final work = spaceWork.then<void>((_) async {
      if (!stopped) await action();
    });
    spaceWork = work.catchError(_fail);
    return work;
  }

  Future<void> _sendCursor(UuidValue id) async {
    if (spaces.markHandshakeSent(id)) {
      _emit(await engine.createSyncSinceHlc(session, spaceId: id));
    }
  }

  void _subscribe() {
    if (once || stopped) return;
    final active = spaces.activeSpaceIds.toSet();
    recovery ??= engine._databaseContext.watchCommittedState(
      session: session,
      userId: userId,
      spaces: active,
      onChanged: _wake,
    );
    recovery!.updateSpaces(active);
    for (final id in subscriptions.keys.toList()) {
      if (!active.contains(id)) subscriptions.remove(id)!();
    }
    for (final id in active) {
      subscriptions.putIfAbsent(
        id,
        () => engine._databaseContext.onSpaceChanged(id, _wake),
      );
    }
  }

  Future<void> _read() async {
    try {
      while (await input.moveNext()) {
        // On successful finite completion, drain the transport to EOF. Waiting
        // for that EOF before closing output would deadlock the two peers.
        if (completion.isCompleted || stopped) continue;
        handling = _handle(input.current).catchError(_fail);
        await handling;
        handling = null;
      }
      if (completion.isCompleted) return;
      if (once || incoming.isNotEmpty) {
        throw const OfflineSyncStreamClosedException(phase: 'committed sync boundary');
      }
      _finish();
    } on Object catch (error, stack) {
      if (!stopped) _fail(error, stack);
    }
  }

  Never _unexpected(OfflineSyncStreamEvent event, String expected) {
    throw OfflineSyncUnexpectedEventException(expected: expected, received: event);
  }

  Future<void> _handle(OfflineSyncStreamEvent event) async {
    if (!connected && event is! OfflineSyncConnect) {
      _unexpected(event, 'OfflineSyncConnect');
    }
    switch (event) {
      case OfflineSyncConnect():
        if (connected) _unexpected(event, 'one initial Connect');
        engine._validateSyncTablesHash(event.syncTablesHash);
        connected = true;
        OfflineSyncDiagnostics.event('sync.peer', {
          'peerNodeId': event.localNodeId.toString(),
        });
        await _withSpaces(() async {
          await spaces.adoptPeerGrants(event.spaces);
          for (final id in spaces.activeSpaceIds) {
            await _sendCursor(id);
          }
          _subscribe();
        });
        if (stopped) return;
        if (!ready) {
          ready = true;
          if (!once || spaces.isAuthoritative) _emit(OfflineSyncReady());
        }
        _stage('active');
      case OfflineSyncReady():
        if (peerReady || spaces.hasIncompleteActiveHandshake) {
          _unexpected(event, 'complete initial resume vectors followed by one Ready');
        }
        peerReady = true;
        _wake();
      case OfflineSyncSpaceSet():
        await _withSpaces(() async {
          await spaces.adoptPeerGrants(event.spaces);
          for (final id in spaces.activeSpaceIds) {
            await _sendCursor(id);
          }
          _subscribe();
        });
        _wake();
      case OfflineSyncSinceHlc():
        if (spaces.accepts(event.uuidSpaceId)) {
          spaces.recordPeerHandshake(event.uuidSpaceId, event);
          received.clear();
          _wake();
        }
      case OfflineSyncMergeChunk():
        _checkIncoming(event, event.batchId);
        incoming.addAll(event.changes);
      case OfflineSyncEndOfBatch():
        _checkIncoming(event, event.batchId);
        if (event.finalForOnce != once) {
          // A server may send ordinary snapshots before the final once boundary.
          if (event.finalForOnce || spaces.isAuthoritative) {
            _unexpected(event, 'a batch boundary matching this session mode');
          }
        }
        final changes = incoming;
        incoming = [];
        inboundBusy = true;
        merging = _merge(event, changes).catchError(_fail);
      case OfflineSyncCommitted():
        final batch = inFlight;
        if (!peerReady || batch == null || batch.id != event.batchId) {
          _unexpected(event, 'the acknowledgement for the outstanding batch');
        }
        for (final entry in batch.checkpoints.entries) {
          for (final checkpoint in entry.value.values) {
            spaces.advanceCheckpoint(entry.key, checkpoint);
          }
        }
        inFlight = null;
        lastCapture = clock.now();
        OfflineSyncDiagnostics.event('sync.batchCommitted', {'batchId': event.batchId});
        for (final id in batch.sentSpaces) {
          await engine._reportMerge(onMergeSuccess, spaces, id, null);
        }
        if (batch.finalForOnce) {
          if (spaces.isAuthoritative) {
            _finish();
          } else {
            uploadCommitted = true;
            if (finalApplied) _finish();
          }
        }
        _scheduleSend();
      case OfflineSyncClose():
        if (once) _unexpected(event, 'a committed finite batch boundary');
        incoming.clear();
        _finish();
    }
  }

  void _checkIncoming(OfflineSyncStreamEvent event, int id) {
    if (!peerReady ||
        inboundBusy ||
        id != nextIncomingId ||
        finalApplied ||
        finalRequested) {
      _unexpected(event, 'batch $nextIncomingId with no uncommitted predecessor');
    }
  }

  Future<void> _merge(
    OfflineSyncEndOfBatch boundary,
    List<CrdtMergeChange> changes,
  ) async {
    await OfflineSyncDiagnostics.measure('sync.inboundBatch', () async {
      final groups = <UuidValue, List<CrdtMergeChange>>{};
      for (final change in changes) {
        groups.putIfAbsent(change.uuidSpaceId, () => []).add(change);
      }
      for (final entry in groups.entries) {
        cancellation.throwIfCancelled();
        if (!spaces.accepts(entry.key)) continue;
        final facts = _ReceivedChanges()..addAll(entry.value.map(jsonEncode));
        final hlc = await engine.mergeInboundBatch(
          session,
          userId: userId,
          spaceId: entry.key,
          mergeSet: entry.value,
          cancellation: cancellation,
          requireWriteAccess: spaces.isAuthoritative,
        );
        received.addAll(facts._encoded);
        await engine._reportMerge(onMergeSuccess, spaces, entry.key, hlc);
      }
    }, data: {'batchId': boundary.batchId, 'changes': changes.length});
    cancellation.throwIfCancelled();
    nextIncomingId++;
    inboundBusy = false;
    if (boundary.finalForOnce) {
      if (spaces.isAuthoritative) {
        finalRequested = true;
      } else {
        finalApplied = true;
      }
    }
    _emit(OfflineSyncCommitted(batchId: boundary.batchId));
    // The follower has proof of the upload commit and has itself committed the
    // final download. Flush its acknowledgement and close its sending half;
    // another server confirmation cannot add durability to either boundary.
    if (once && !spaces.isAuthoritative && finalApplied && uploadCommitted) {
      _finish();
    }
    OfflineSyncDiagnostics.event('sync.batchApplied', {
      'batchId': boundary.batchId,
      'changes': changes.length,
    });
    _wake();
  }

  void _wake() {
    dirty = true;
    _scheduleSend();
  }

  bool get _canSend =>
      !stopped &&
      !completion.isCompleted &&
      ready &&
      peerReady &&
      inFlight == null &&
      !(once && !spaces.isAuthoritative && uploadSent);

  void _scheduleSend() {
    if (!_canSend || sending != null || !dirty) return;
    sending = _send().catchError(_fail).whenComplete(() {
      sending = null;
      if (dirty) _scheduleSend();
    });
  }

  Future<void> _send() async {
    while (_canSend && dirty) {
      if (lastCapture != null &&
          !once &&
          engine._continuousSyncInterval > Duration.zero) {
        final delay =
            engine._continuousSyncInterval - clock.now().difference(lastCapture!);
        if (delay > Duration.zero) {
          await Future.any([Future<void>.delayed(delay), completion.future]);
          if (!_canSend) return;
        }
      }
      // Hints received during capture must trigger another pass. ACKs themselves
      // do not mark the database dirty and therefore cause no empty rescans.
      dirty = false;
      await _withSpaces(() async {
        await spaces.reconcile();
        if (spaces.shouldAnnounce) {
          _emit(OfflineSyncSpaceSet(spaces: spaces.localGrants));
          spaces.markAnnounced();
        }
        for (final id in spaces.activeSpaceIds) {
          await _sendCursor(id);
        }
        _subscribe();
      });
      if (!_canSend || (once && spaces.hasIncompleteActiveHandshake)) return;

      // A complete finite upload is already being committed. Its completion
      // wakes the sender with the final boundary, avoiding a snapshot that
      // would immediately need replacing. Partial uploads and continuous
      // sessions still allow both directions to progress independently.
      if (once && spaces.isAuthoritative && inboundBusy) {
        dirty = false;
        OfflineSyncDiagnostics.event('sync.captureDeferredForUpload');
        return;
      }

      // Commits during membership preparation are included by this upcoming
      // snapshot. Only hints received after this point need another capture.
      dirty = false;
      final finalForOnce = once && (!spaces.isAuthoritative || finalRequested);
      lastCapture = clock.now();
      final passId = ++pass;
      final changes = await OfflineSyncDiagnostics.measure(
        'sync.outboundCapture',
        () => engine
            .collectPendingChanges(
              session,
              checkpointsBySpaceUuid: spaces.sendableCheckpoints,
            )
            .toList(),
        data: {'pass': passId},
      );
      if (!_canSend) return;
      final outbound = <CrdtMergeChange>[];
      for (final change in changes) {
        if (!received.remove(change)) outbound.add(change);
      }
      if (outbound.length != changes.length) {
        OfflineSyncDiagnostics.event('sync.echoSuppressed', {
          'changes': changes.length - outbound.length,
        });
      }
      if (outbound.isNotEmpty || finalForOnce) {
        final id = nextOutgoingId++;
        inFlight = _SentBatch(
          id,
          changes,
          outbound.map((c) => c.uuidSpaceId).toSet(),
          finalForOnce: finalForOnce,
        );
        if (once && !spaces.isAuthoritative) {
          uploadSent = true;
          // Announce finite readiness with the prepared upload. Otherwise the
          // server may start an obsolete capture while we are still preparing
          // this batch. Its own Ready already permits our local capture.
          _emit(OfflineSyncReady());
        }
        for (var start = 0; start < outbound.length; start += engine._syncBatchSize) {
          final end = (start + engine._syncBatchSize).clamp(0, outbound.length);
          _emit(
            OfflineSyncMergeChunk(batchId: id, changes: outbound.sublist(start, end)),
          );
        }
        _emit(OfflineSyncEndOfBatch(batchId: id, finalForOnce: finalForOnce));
        OfflineSyncDiagnostics.event('sync.batchSent', {
          'batchId': id,
          'changes': outbound.length,
          'finalForOnce': finalForOnce,
        });
      } else {
        // Only exact received facts were omitted, and the complete consistent
        // snapshot has now been enumerated. No unknown older fact is skipped.
        for (final change in changes) {
          spaces.advanceCheckpoint(change.uuidSpaceId, change.hlc);
        }
      }
      OfflineSyncDiagnostics.event('sync.outboundIdle', {'pass': passId});
    }
  }
}

class _SentBatch {
  _SentBatch(
    this.id,
    Iterable<CrdtMergeChange> changes,
    this.sentSpaces, {
    required this.finalForOnce,
  }) {
    // Capture is complete before this vector is built. Retain only the facts
    // needed after acknowledgement, so consumed frames can release payloads.
    // Echo-suppressed facts belong to the same complete snapshot and are
    // included here too. No checkpoint advances until the peer commits.
    for (final change in changes) {
      final nodes = checkpoints.putIfAbsent(change.uuidSpaceId, () => {});
      nodes[change.uuidNodeId] = change.hlc.maxBetween(nodes[change.uuidNodeId]);
    }
  }

  final int id;
  final checkpoints = <UuidValue, Map<UuidValue, Hlc>>{};
  final Set<UuidValue> sentSpaces;
  final bool finalForOnce;
}
