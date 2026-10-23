import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    show Uuid, UuidValue;
import 'package:test/test.dart';

import 'client_session.dart';
import 'sync_topology.dart';

/// A current-protocol peer against the public engine and a real database.
/// Commit acknowledgements and capture diagnostics provide explicit barriers.
class FramedSyncPeer {
  final inbound = StreamController<OfflineSyncStreamEvent>();
  final outbound = <CrdtMergeChange>[];
  final events = <OfflineSyncStreamEvent>[];
  final _eventNotifications = StreamController<OfflineSyncStreamEvent>.broadcast();
  final stages = <String>[];
  int recoveryWakeups = 0;
  int nextBatchId = 1;
  final _rowWaiters = <UuidValue, Completer<void>>{};
  final _acknowledged = <int, Completer<void>>{};
  final _waiting = <int, Completer<void>>{};
  final _done = Completer<void>();
  int _passes = 0;
  bool _closed = false;

  Future<T> waitForEvent<T extends OfflineSyncStreamEvent>({
    bool Function(T)? where,
  }) async {
    bool matches(OfflineSyncStreamEvent event) =>
        event is T && (where?.call(event) ?? true);
    for (final event in events) {
      if (matches(event)) return event as T;
    }
    return await _eventNotifications.stream
            .firstWhere(matches)
            .timeout(
              const Duration(seconds: 10),
            )
        as T;
  }

  Future<void> waitForRow(UuidValue id) async {
    if (outbound.any((change) => change.uuidRowId == id)) return;
    await (_rowWaiters[id] ??= Completer<void>()).future.timeout(
      const Duration(seconds: 5),
    );
  }

  static Future<FramedSyncPeer> open(
    SyncNode node, {
    UuidValue? userId,
    OfflineSyncDiagnosticSink? onDiagnostic,
  }) async {
    final actingUser = userId ?? testCrdtUserId;
    final peer = FramedSyncPeer();
    final handshakes = <UuidValue>{};
    addTearDown(peer.close);
    OfflineSyncDiagnostics.run(
      (event) {
        if (event['name'] == 'sync.recoveryWakeup') peer.recoveryWakeups++;
        if (event['name'] == 'sync.outboundCapture' && event['kind'] == 'start') {
          peer.stages.add('outbound.capture');
        }
        if (event['name'] == 'sync.outboundIdle') {
          peer._passes++;
          peer._waiting.remove(peer._passes)?.complete();
        }
        onDiagnostic?.call(event);
      },
      () => node.sync
          .sync(
            node.raw,
            userId: actingUser,
            inbound: peer.inbound.stream,
            mode: OfflineSyncPeerMode.authoritative,
          )
          .listen(
            (event) {
              peer.events.add(event);
              peer._eventNotifications.add(event);
              if (event is OfflineSyncConnect) {
                peer.inbound.add(
                  OfflineSyncConnect(
                    localNodeId: const Uuid().v7obj(),
                    syncTablesHash: event.syncTablesHash,
                    spaces: const [],
                  ),
                );
              } else if (event is OfflineSyncSinceHlc) {
                if (handshakes.add(event.uuidSpaceId)) {
                  peer.inbound.add(
                    OfflineSyncSinceHlc(
                      uuidSpaceId: event.uuidSpaceId,
                      nodeCheckpoints: [],
                    ),
                  );
                }
              } else if (event is OfflineSyncReady) {
                peer.inbound.add(OfflineSyncReady());
              } else if (event is OfflineSyncSpaceSet) {
                final active = event.spaces.map((g) => g.uuidSpaceId).toSet();
                handshakes.removeWhere((id) => !active.contains(id));
              } else if (event is OfflineSyncMergeChunk) {
                peer.outbound.addAll(event.changes);
                for (final change in event.changes) {
                  peer._rowWaiters.remove(change.uuidRowId)?.complete();
                }
              } else if (event is OfflineSyncEndOfBatch) {
                peer.inbound.add(OfflineSyncCommitted(batchId: event.batchId));
              } else if (event is OfflineSyncCommitted) {
                peer._acknowledged.remove(event.batchId)?.complete();
              }
            },
            onError: (Object error, StackTrace stack) {
              for (final waiting in [
                ...peer._waiting.values,
                ...peer._acknowledged.values,
              ]) {
                waiting.completeError(error, stack);
              }
              peer._waiting.clear();
              peer._acknowledged.clear();
              if (!peer._done.isCompleted) peer._done.completeError(error, stack);
            },
            onDone: () {
              if (!peer._done.isCompleted) peer._done.complete();
            },
          ),
    );
    await peer.waitForPass(1);
    return peer;
  }

  Future<void> waitForPass(int pass) async {
    if (_passes >= pass) return;
    await (_waiting[pass] ??= Completer<void>()).future.timeout(
      const Duration(seconds: 10),
    );
  }

  Future<void> endBatch() async {
    final id = nextBatchId++;
    final acknowledged = _acknowledged[id] = Completer<void>();
    inbound.add(OfflineSyncEndOfBatch(batchId: id, finalForOnce: false));
    await acknowledged.future.timeout(const Duration(seconds: 10));
  }

  Future<List<CrdtMergeChange>> sendBatch(List<CrdtMergeChange> changes) async {
    final nextPass = _passes + 1;
    outbound.clear();
    inbound.add(OfflineSyncMergeChunk(batchId: nextBatchId, changes: changes));
    await endBatch();
    await waitForPass(nextPass);
    return List.of(outbound);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_done.isCompleted) inbound.add(OfflineSyncClose());
    await _done.future.timeout(const Duration(seconds: 10));
    unawaited(inbound.close());
    unawaited(_eventNotifications.close());
  }
}
