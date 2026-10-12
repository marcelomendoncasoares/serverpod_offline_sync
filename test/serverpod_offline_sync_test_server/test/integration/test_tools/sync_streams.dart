import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart'
    show UuidValue;

/// What one `once` session between a follower and the server exchanged.
typedef SyncRound = ({
  List<CrdtMergeChange> toClient,
  List<CrdtMergeChange> toServer,
  Object? serverError,
});

/// Runs a real follower and a real authoritative `once` session over
/// in-memory streams, recording the merge changes each side sent.
///
/// [follower] starts the client side's production sync state machine on the
/// server-to-client stream it receives. [splice] is added to the follower's
/// first batch as an extra [OfflineSyncMergeChunk], right before its first
/// [OfflineSyncEndOfBatch], as a stale or malicious client would send it; it
/// is the only frame a production client would not send.
///
/// The returned `serverError` is the error that ended the authoritative session,
/// or null when it closed cleanly. When the server aborts, the follower fails
/// with a truncated stream; that error is not the one under test.
Future<SyncRound> syncOnceOverStreams({
  required OfflineSyncSession serverSync,
  required Stream<OfflineSyncStreamEvent> Function(
    Stream<OfflineSyncStreamEvent> inbound,
  )
  follower,
  required UuidValue userUuid,
  List<CrdtMergeChange> splice = const [],
  Duration timeout = const Duration(seconds: 10),
}) async {
  final clientToServer = StreamController<OfflineSyncStreamEvent>();
  final serverToClient = StreamController<OfflineSyncStreamEvent>();
  final serverCompletion = Completer<Object?>();
  final clientCompletion = Completer<void>();
  final toClient = <CrdtMergeChange>[];
  final toServer = <CrdtMergeChange>[];
  var spliced = splice.isEmpty;

  void addIfOpen(
    StreamController<OfflineSyncStreamEvent> controller,
    OfflineSyncStreamEvent event,
  ) {
    if (!controller.isClosed) controller.add(event);
  }

  final clientSubscription = follower(serverToClient.stream).listen(
    (event) {
      if (!spliced && event is OfflineSyncEndOfBatch) {
        spliced = true;
        addIfOpen(clientToServer, OfflineSyncMergeChunk(changes: splice));
      }
      if (event is OfflineSyncMergeChunk) toServer.addAll(event.changes);
      addIfOpen(clientToServer, event);
    },
    onError: (Object _) {
      if (!clientCompletion.isCompleted) clientCompletion.complete();
      unawaited(clientToServer.close());
    },
    onDone: () {
      if (!clientCompletion.isCompleted) clientCompletion.complete();
      unawaited(clientToServer.close());
    },
  );

  final serverSubscription = serverSync
      .sync(
        userId: userUuid,
        inbound: clientToServer.stream,
        once: true,
        mode: OfflineSyncPeerMode.authoritative,
      )
      .listen(
        (event) {
          if (event is OfflineSyncMergeChunk) toClient.addAll(event.changes);
          addIfOpen(serverToClient, event);
        },
        onError: (Object error) {
          if (!serverCompletion.isCompleted) serverCompletion.complete(error);
          unawaited(serverToClient.close());
        },
        onDone: () {
          if (!serverCompletion.isCompleted) serverCompletion.complete(null);
          unawaited(serverToClient.close());
        },
      );

  try {
    final serverError = await serverCompletion.future.timeout(timeout);
    await clientCompletion.future.timeout(timeout);
    return (toClient: toClient, toServer: toServer, serverError: serverError);
  } finally {
    await clientSubscription.cancel();
    await serverSubscription.cancel();
    if (!clientToServer.isClosed) unawaited(clientToServer.close());
    if (!serverToClient.isClosed) unawaited(serverToClient.close());
  }
}
