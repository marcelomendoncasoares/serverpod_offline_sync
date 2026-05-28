import 'dart:async';

import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';

import '../database/session.dart';
import '../protocol/protocol.dart';

/// A running continuous CRDT sync session.
class CrdtSyncSession {
  CrdtSyncSession._({
    required this.done,
    required Future<void> Function() cancel,
  }) : _cancel = cancel;

  /// Completes when the sync session ends normally or after [cancel].
  final Future<void> done;

  final Future<void> Function() _cancel;

  /// Stops the sync session and closes the transport. This method is idempotent
  /// and can be called multiple times.
  Future<void> cancel() => _cancel();
}

/// High-level client sync helpers built on top of the generated module caller.
class CrdtSyncClient {
  /// Creates a [CrdtSyncClient] for the provided module caller.
  CrdtSyncClient(this._caller);

  final Caller _caller;

  /// Pushes local pending changes for [session] to the remote peer once.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  Future<void> syncOnce(DatabaseSession session) async {
    await _startSyncSession(session, once: true).done;
  }

  /// Keeps synchronizing [session] with the remote peer until cancelled through
  /// [CrdtSyncSession.cancel] or the remote stream closes.
  ///
  /// The [session] must be wrapped in a [CrdtDatabaseSession].
  CrdtSyncSession syncContinuously(DatabaseSession session) =>
      _startSyncSession(session, once: false);

  CrdtSyncSession _startSyncSession(
    DatabaseSession session, {
    required bool once,
  }) {
    // The stream will be closed using [outboundChanges.closeOrSkip].
    // ignore: close_sinks
    final outboundChanges = StreamController<CrdtSyncStreamEvent>();
    final doneCompleter = Completer<void>();

    try {
      final remoteStream = _caller.crdtSync.sync(
        changes: outboundChanges.stream,
        once: once,
      );

      final subscription = session.crdtDb
          .sync(inbound: remoteStream, once: once)
          .listen(
            outboundChanges.addIfNotClosed,
            onDone: doneCompleter.completeOrSkip,
            onError: doneCompleter.completeErrorOrSkip,
            cancelOnError: true,
          );

      return CrdtSyncSession._(
        done: doneCompleter.future.whenComplete(outboundChanges.closeOrSkip),
        cancel: () async {
          await outboundChanges.closeOrSkip();
          await subscription.cancel();
          doneCompleter.completeOrSkip();
        },
      );
    } catch (_) {
      unawaited(outboundChanges.closeOrSkip());
      rethrow;
    }
  }
}

/// Exposes CRDT sync helpers from a generated client.
extension CrdtSyncClientExtension on ServerpodClientShared {
  /// Returns CRDT sync helpers bound to this client.
  CrdtSyncClient get crdt => CrdtSyncClient(Caller(this));
}

extension on StreamController<CrdtSyncStreamEvent> {
  void addIfNotClosed(CrdtSyncStreamEvent event) {
    if (isClosed) return;
    add(event);
  }

  Future<void> closeOrSkip() async {
    if (isClosed) return;
    await close();
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
