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

/// Runs [follower] against an authoritative `once` session over in-memory
/// streams, recording the merge changes each side sent.
///
/// [splice] is sent as an extra [OfflineSyncMergeChunk] before the follower's
/// first [OfflineSyncEndOfBatch]. `serverError` is the error that ended the
/// server session, or null. A follower error is rethrown if the server did not
/// reject the session, so a broken follower cannot look like an empty round.
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
  Object? clientError;
  StackTrace? clientStack;
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
        toServer.addAll(splice);
        addIfOpen(clientToServer, OfflineSyncMergeChunk(changes: splice));
      }
      if (event is OfflineSyncMergeChunk) toServer.addAll(event.changes);
      addIfOpen(clientToServer, event);
    },
    onError: (Object error, StackTrace stack) {
      clientError = error;
      clientStack = stack;
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
    if (serverError == null && clientError != null) {
      Error.throwWithStackTrace(clientError!, clientStack!);
    }
    if (!spliced) throw StateError('The follower never sent the batch to splice.');
    return (toClient: toClient, toServer: toServer, serverError: serverError);
  } finally {
    await clientSubscription.cancel();
    await serverSubscription.cancel();
    if (!clientToServer.isClosed) unawaited(clientToServer.close());
    if (!serverToClient.isClosed) unawaited(serverToClient.close());
  }
}
