import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';

import '../database/session.dart';
import '../generated/protocol.dart';
import 'engine.dart';

/// Opens the remote half of a CRDT sync stream.
typedef OfflineSyncTransport =
    Stream<OfflineSyncStreamEvent> Function({
      required Stream<OfflineSyncStreamEvent> changes,
      required bool once,
    });

/// A running continuous CRDT sync session.
class OfflineSyncSubscription {
  OfflineSyncSubscription._({
    required this.done,
    required this._cancel,
  });

  /// Completes when the sync session ends normally or after [cancel].
  final Future<void> done;

  final Future<void> Function() _cancel;

  /// Stops the sync session and closes the transport. This method is idempotent
  /// and can be called multiple times.
  Future<void> cancel() => _cancel();
}

/// High-level client sync helpers built on top of a CRDT stream transport.
class OfflineSyncClient {
  /// Creates a [OfflineSyncClient] for the provided [transport].
  OfflineSyncClient(OfflineSyncTransport transport) : _transport = transport;

  final OfflineSyncTransport _transport;

  /// Pushes local pending changes for [session] to the remote peer once.
  ///
  /// The [session] must be wrapped in a [OfflineSyncDatabaseSession].
  Future<void> syncOnce(
    DatabaseSession session, {
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) async {
    await _startSyncSession(session, once: true, onMergeSuccess: onMergeSuccess).done;
  }

  /// Keeps synchronizing [session] with the remote peer until cancelled through
  /// [OfflineSyncSubscription.cancel] or the remote stream closes.
  ///
  /// The [session] must be wrapped in a [OfflineSyncDatabaseSession].
  OfflineSyncSubscription syncContinuously(
    DatabaseSession session, {
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) => _startSyncSession(session, once: false, onMergeSuccess: onMergeSuccess);

  OfflineSyncSubscription _startSyncSession(
    DatabaseSession session, {
    required bool once,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) {
    // The stream will be closed using [outboundChanges.closeOrSkip].
    // ignore: close_sinks
    final outboundChanges = StreamController<OfflineSyncStreamEvent>();
    final doneCompleter = Completer<void>();
    var cancelled = false;

    try {
      final remoteStream = _transport(
        changes: outboundChanges.stream,
        once: once,
      );

      final subscription = session.offlineSyncDb
          .sync(
            inbound: remoteStream,
            once: once,
            onMergeSuccess: onMergeSuccess,
            mode: OfflineSyncPeerMode.follower,
          )
          .listen(
            (event) {
              outboundChanges.addIfNotClosed(event);
              if (once && event is OfflineSyncClose) {
                unawaited(outboundChanges.closeOrSkip());
              }
            },
            onDone: doneCompleter.completeOrSkip,
            onError: doneCompleter.completeErrorOrSkip,
            cancelOnError: true,
          );

      return OfflineSyncSubscription._(
        done: doneCompleter.future.whenComplete(outboundChanges.closeOrSkip),
        cancel: () async {
          if (cancelled) return;
          cancelled = true;

          unawaited(outboundChanges.closeOrSkip());
          if (doneCompleter.isCompleted) return;
          const waitTimeout = Duration(milliseconds: 200);
          // Prefer graceful shutdown: closing outbound lets the server finish
          // and complete [done] via [subscription.onDone].
          await doneCompleter.future.timeout(waitTimeout, onTimeout: () {});
          await subscription.cancel().timeout(waitTimeout, onTimeout: () {});
          doneCompleter.completeOrSkip();
        },
      );
    } catch (_) {
      unawaited(outboundChanges.closeOrSkip());
      rethrow;
    }
  }
}

extension on StreamController<OfflineSyncStreamEvent> {
  void addIfNotClosed(OfflineSyncStreamEvent event) {
    if (isClosed) return;
    add(event);
  }

  Future<void> closeOrSkip() async {
    if (!isClosed) {
      unawaited(close());
    }
    // The done event is only delivered once the stream has a listener. If the
    // method stream never listened (e.g. opening it failed), awaiting [done]
    // would hang forever.
    if (hasListener) {
      await done;
    }
  }
}

extension on Completer<void> {
  void completeOrSkip() {
    if (isCompleted) return;
    complete();
  }

  void completeErrorOrSkip(Object error, StackTrace stackTrace) {
    if (isCompleted) return;
    completeError(error, stackTrace);
  }
}
