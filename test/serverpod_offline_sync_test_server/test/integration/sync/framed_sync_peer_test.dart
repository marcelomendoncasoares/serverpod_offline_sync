import 'dart:async';

import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';
import 'package:test/test.dart';

import '../test_tools/client_session.dart';
import '../test_tools/framed_sync_peer.dart';
import '../test_tools/sync_topology.dart';

/// Pins [FramedSyncPeer] to the real follower. One script runs against a fresh
/// authoritative session twice, once with each follower, and the fixture must
/// send the session what the real follower sends, apart from the epoch and the
/// revision bounds it fakes.
void main() {
  initTestClientSession(createSessionPerTest: false);

  group(
    'Given a real follower and the scripted fixture, each facing a fresh authoritative session,',
    () {
      late SyncNode follower;
      late SyncNode followerServer;
      late SyncNode fixtureServer;

      setUpAll(() async {
        follower = await syncNode(await createAdditionalTestSession(), testSyncTables);
        followerServer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
        fixtureServer = await syncNode(
          await createAdditionalTestSession(),
          testSyncTables,
        );
      });

      group(
        'when each completes the handshake, acknowledges one server batch and uploads one row,',
        () {
          late List<String> followerFrames;
          late List<String> fixtureFrames;

          setUpAll(() async {
            final link = _FollowerLink.start(
              server: followerServer,
              follower: follower,
            );
            await link.untilServerRead<OfflineSyncReady>();
            await _insertUnique(followerServer, 'sent by the server');
            await link.untilServerRead<OfflineSyncCommitted>();
            await _insertUnique(follower, 'uploaded by the follower');
            await link.untilServerEmitted<OfflineSyncCommitted>();
            followerFrames = link.sent.map(_shape).toList();
            final upload = [
              for (final chunk in link.sent.whereType<OfflineSyncMergeChunk>())
                ...chunk.changes,
            ];
            await link.close();

            final fixture = await FramedSyncPeer.open(fixtureServer);
            await _insertUnique(fixtureServer, 'sent by the server');
            await fixture.waitForEvent<OfflineSyncEndOfBatch>();
            await fixture.sendBatch(upload);
            fixtureFrames = fixture.sent.map(_shape).toList();
            await fixture.close();
          });

          test(
            'then the fixture sends the session the same frames as the real follower.',
            () {
              expect(fixtureFrames, followerFrames);
            },
          );
        },
      );
    },
  );
}

/// Commits one new [Unique] row named [name] in the test user's space on [node].
Future<void> _insertUnique(SyncNode node, String name) =>
    node.offlineSync.db.transactionForUser(
      testCrdtUserId,
      (tx) => Unique.db.insertRow(
        node.offlineSync,
        Unique(id: const Uuid().v7obj(), name: name),
        transaction: tx,
      ),
    );

/// [frame] as the protocol shapes it, without the epoch and revision values
/// the fixture fakes.
String _shape(OfflineSyncStreamEvent frame) => switch (frame) {
  OfflineSyncConnect() => 'Connect(grants: ${_grants(frame.spaces)})',
  OfflineSyncSpaceSet() => 'SpaceSet(grants: ${_grants(frame.spaces)})',
  OfflineSyncSinceRevision() =>
    'SinceRevision(space: ${frame.uuidSpaceId}, '
        'receipts: ${frame.nodeCheckpoints.length})',
  OfflineSyncReady() => 'Ready',
  OfflineSyncMergeChunk() =>
    'MergeChunk(batch: ${frame.batchId}, changes: ${frame.changes.length})',
  OfflineSyncEndOfBatch() =>
    'EndOfBatch(batch: ${frame.batchId}, final: ${frame.finalForOnce}, '
        'spaces: ${[for (final checkpoint in frame.checkpoints) checkpoint.uuidSpaceId]})',
  OfflineSyncCommitted() => 'Committed(batch: ${frame.batchId})',
  OfflineSyncClose() => 'Close',
};

String _grants(List<OfflineSyncSpaceGrant> grants) =>
    '${[for (final grant in grants) '${grant.uuidSpaceId}:${grant.role.name}']}';

/// A real follower session and a real authoritative session joined by
/// in-memory frames.
class _FollowerLink {
  _FollowerLink._();

  /// The frames the follower sent, in the order the server read them.
  final sent = <OfflineSyncStreamEvent>[];

  /// The frames the server emitted, in order.
  final emitted = <OfflineSyncStreamEvent>[];

  final _toServer = StreamController<OfflineSyncStreamEvent>();
  final _toFollower = StreamController<OfflineSyncStreamEvent>();
  final _changed = StreamController<void>.broadcast();
  final _subscriptions = <StreamSubscription<OfflineSyncStreamEvent>>[];

  static _FollowerLink start({required SyncNode server, required SyncNode follower}) {
    final link = _FollowerLink._();
    link._subscriptions
      ..add(
        follower.sync
            .sync(
              follower.raw,
              userId: testCrdtUserId,
              inbound: link._toFollower.stream,
              mode: OfflineSyncPeerMode.follower,
            )
            .listen(link._toServer.add, onError: link._changed.addError),
      )
      ..add(
        server.sync
            .sync(
              server.raw,
              userId: testCrdtUserId,
              inbound: link._toServer.stream.map((frame) {
                link.sent.add(frame);
                link._changed.add(null);
                return frame;
              }),
              mode: OfflineSyncPeerMode.authoritative,
            )
            .listen((frame) {
              link.emitted.add(frame);
              link._changed.add(null);
              link._toFollower.add(frame);
            }, onError: link._changed.addError),
      );
    addTearDown(link.close);
    return link;
  }

  /// Waits until the server has read a [T] frame from the follower.
  Future<void> untilServerRead<T extends OfflineSyncStreamEvent>() =>
      _until(() => sent.whereType<T>().isNotEmpty);

  /// Waits until the server has emitted a [T] frame.
  Future<void> untilServerEmitted<T extends OfflineSyncStreamEvent>() =>
      _until(() => emitted.whereType<T>().isNotEmpty);

  Future<void> _until(bool Function() reached) async {
    if (reached()) return;
    await _changed.stream
        .firstWhere((_) => reached())
        .timeout(const Duration(seconds: 10));
  }

  /// Stops both sessions.
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    unawaited(_toServer.close());
    unawaited(_toFollower.close());
    if (!_changed.isClosed) await _changed.close();
  }
}
