import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/src/sync/space_state.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given a database-backed CRDT space sync session,',
    (sessionBuilder, _) {
      sessionBuilder.build().serverpod.initializeOfflineSync(syncTables: []);

      late Session session;
      setUp(() async {
        session = sessionBuilder.build();
      });

      test(
        'when authoritative and follower sessions reconcile stored membership, '
        'then only the authoritative session announces grants.',
        () async {
          final userUuid = _uuid(30);
          final sharedSpaceUuid = await session.offlineSync.spaces.createFor(userUuid);

          final authoritative = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.authoritative,
            peerNodeId: _uuid(90),
          );

          await authoritative.reconcile();

          final expectedAuthoritativeSpaceIds = {sharedSpaceUuid, userUuid};
          expect(
            {for (final grant in authoritative.localGrants) grant.uuidSpaceId},
            expectedAuthoritativeSpaceIds,
          );
          expect(
            authoritative.activeSpaceIds.toSet(),
            expectedAuthoritativeSpaceIds,
          );

          expect(authoritative.shouldAnnounce, isTrue);
          authoritative.markAnnounced();
          expect(authoritative.shouldAnnounce, isFalse);

          final follower = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.follower,
            peerNodeId: _uuid(91),
          );
          await follower.reconcile();

          expect(follower.localGrants, isEmpty);
          expect(follower.activeSpaceIds, isEmpty);
          expect(follower.shouldAnnounce, isTrue);

          follower.markAnnounced();
          expect(follower.shouldAnnounce, isFalse);
        },
      );

      test(
        'when an authoritative session adopts peer-only grants, '
        'then it keeps cycling only its locally resolved spaces.',
        () async {
          final userUuid = _uuid(31);
          final peerOnlySpaceUuid = _uuid(11);
          final localSharedSpaceUuid = await session.offlineSync.spaces.createFor(
            userUuid,
          );

          final authoritative = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.authoritative,
            peerNodeId: _uuid(92),
          );

          await authoritative.reconcile();
          await authoritative.adoptPeerGrants([_grant(peerOnlySpaceUuid)]);

          final expectedSpaceIds = {localSharedSpaceUuid, userUuid};
          expect(authoritative.activeSpaceIds.toSet(), expectedSpaceIds);
          expect(authoritative.accepts(localSharedSpaceUuid), isTrue);
          expect(authoritative.accepts(peerOnlySpaceUuid), isFalse);
        },
      );

      test(
        'when membership changes after an authoritative announcement is marked, '
        'then adoption keeps the announced space set until the next reconcile.',
        () async {
          final userUuid = _uuid(32);

          final authoritative = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.authoritative,
            peerNodeId: _uuid(93),
          );

          await authoritative.reconcile();
          authoritative.markAnnounced();

          final laterSharedSpaceUuid = await session.offlineSync.spaces.createFor(
            userUuid,
          );

          await authoritative.adoptPeerGrants(const []);

          expect(authoritative.activeSpaceIds, [userUuid]);
          expect(authoritative.shouldAnnounce, isFalse);

          await authoritative.reconcile();

          final expectedSpaceIds = {laterSharedSpaceUuid, userUuid};
          expect(authoritative.activeSpaceIds.toSet(), expectedSpaceIds);
          expect(authoritative.shouldAnnounce, isTrue);
        },
      );

      test(
        'when a follower adopts announced grants over a stale local cache, '
        'then only the announced memberships remain projected.',
        () async {
          final userUuid = _uuid(33);
          final announcedSpaceUuid = _uuid(23);
          final staleSpaceUuid = _uuid(13);

          final space = await OfflineSyncSpaceManager(
            session,
          ).getOrCreate(staleSpaceUuid);

          await OfflineSyncSpaceMember.db.upsertRow(
            session,
            OfflineSyncSpaceMember(
              spaceId: space.id!,
              userUuid: userUuid,
              role: OfflineSyncSpaceRole.readWrite,
            ),
            conflictColumns: (t) => [t.spaceId, t.userUuid],
            updateColumns: (t) => [t.role],
          );

          final follower = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.follower,
            peerNodeId: _uuid(94),
          );

          await follower.adoptPeerGrants([
            _grant(userUuid),
            _grant(announcedSpaceUuid, role: OfflineSyncSpaceRole.readOnly),
          ]);

          final expectedSpaceIds = {announcedSpaceUuid, userUuid};
          expect(follower.activeSpaceIds.toSet(), expectedSpaceIds);
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: userUuid,
              spaceUuid: announcedSpaceUuid,
            ),
            OfflineSyncSpaceRole.readOnly,
          );
          expect(
            await OfflineSyncSpaceMembership.roleOf(
              session,
              userUuid: userUuid,
              spaceUuid: staleSpaceUuid,
            ),
            isNull,
          );
        },
      );

      test(
        'when a follower handshakes read-only and writable spaces, '
        'then accepts includes all active spaces but checkpoints are sendable only for writable spaces.',
        () async {
          final userUuid = _uuid(34);
          final readOnlySpaceUuid = _uuid(14);
          final readWriteSpaceUuid = _uuid(24);
          final unknownSpaceUuid = _uuid(44);
          final remoteNodeUuid = _uuid(104);

          final follower = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.follower,
            peerNodeId: _uuid(95),
          );

          await follower.adoptPeerGrants([
            _grant(userUuid),
            _grant(readOnlySpaceUuid, role: OfflineSyncSpaceRole.readOnly),
            _grant(readWriteSpaceUuid),
          ]);

          follower
            ..recordPeerHandshake(
              userUuid,
              _since(userUuid, _hlc(remoteNodeUuid, minute: 1)),
            )
            ..recordPeerHandshake(
              readOnlySpaceUuid,
              _since(readOnlySpaceUuid, _hlc(remoteNodeUuid, minute: 2)),
            )
            ..recordPeerHandshake(
              readWriteSpaceUuid,
              _since(readWriteSpaceUuid, _hlc(remoteNodeUuid, minute: 3)),
            );

          final expectedSendableSpaceIds = {readWriteSpaceUuid, userUuid};
          expect(follower.hasIncompleteActiveHandshake, isFalse);
          expect(follower.accepts(userUuid), isTrue);
          expect(follower.accepts(readOnlySpaceUuid), isTrue);
          expect(follower.accepts(readWriteSpaceUuid), isTrue);
          expect(follower.accepts(unknownSpaceUuid), isFalse);
          expect(follower.sendableCheckpoints.keys.toSet(), expectedSendableSpaceIds);
          expect(follower.sendableCheckpoints[readOnlySpaceUuid], isNull);
        },
      );

      test(
        'when a sent change advances a completed handshake, '
        'then the tracked checkpoint moves to the change HLC.',
        () async {
          final userUuid = _uuid(37);
          final localNodeUuid = _uuid(47);
          final remoteNodeUuid = _uuid(107);

          final authoritative = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.authoritative,
            peerNodeId: _uuid(98),
          );

          final spaceUuid = await session.offlineSync.spaces.createFor(userUuid);

          await authoritative.reconcile();
          authoritative.recordPeerHandshake(
            spaceUuid,
            _since(spaceUuid, _hlc(remoteNodeUuid, minute: 6)),
          );

          final change = CrdtMergeInsert(
            uuidSpaceId: spaceUuid,
            hlcDatetime: DateTime.utc(2026, 7, 2, 12, 7),
            hlcCounter: 1,
            tableName: 'person',
            uuidRowId: _uuid(57),
            uuidNodeId: localNodeUuid,
            data: CrdtNode(uuidNodeId: _uuid(67)),
          );

          authoritative.advanceCheckpoint(spaceUuid, change);

          expect(
            authoritative.checkpointMaxOf(spaceUuid),
            Hlc(DateTime.utc(2026, 7, 2, 12, 7), 1, localNodeUuid),
          );
        },
      );

      test(
        'when an active space is revoked and later re-announced, '
        'then its checkpoint and sent-handshake state are pruned.',
        () async {
          final userUuid = _uuid(35);
          final retainedSpaceUuid = _uuid(15);
          final revokedSpaceUuid = _uuid(25);
          final remoteNodeUuid = _uuid(105);

          final follower = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.follower,
            peerNodeId: _uuid(96),
          );

          await follower.adoptPeerGrants([
            _grant(retainedSpaceUuid),
            _grant(revokedSpaceUuid),
          ]);

          expect(follower.markHandshakeSent(revokedSpaceUuid), isTrue);
          expect(follower.markHandshakeSent(revokedSpaceUuid), isFalse);

          follower
            ..recordPeerHandshake(
              retainedSpaceUuid,
              _since(retainedSpaceUuid, _hlc(remoteNodeUuid, minute: 4)),
            )
            ..recordPeerHandshake(
              revokedSpaceUuid,
              _since(revokedSpaceUuid, _hlc(remoteNodeUuid, minute: 5)),
            );

          await follower.adoptPeerGrants([_grant(retainedSpaceUuid)]);

          expect(follower.accepts(retainedSpaceUuid), isTrue);
          expect(follower.accepts(revokedSpaceUuid), isFalse);
          expect(follower.sendableCheckpoints.keys, [retainedSpaceUuid]);
          expect(follower.checkpointMaxOf(revokedSpaceUuid), isNull);

          await follower.adoptPeerGrants([
            _grant(retainedSpaceUuid),
            _grant(revokedSpaceUuid),
          ]);

          expect(follower.markHandshakeSent(revokedSpaceUuid), isTrue);
          expect(follower.hasIncompleteActiveHandshake, isTrue);
        },
      );

      test(
        'when a follower adopts duplicated out-of-order grants, '
        'then active spaces are de-duplicated and sorted by UUID.',
        () async {
          final userUuid = _uuid(36);
          final alphaSpaceUuid = _uuid(1);
          final betaSpaceUuid = _uuid(2);
          final gammaSpaceUuid = _uuid(3);

          final follower = OfflineSyncSpaceState(
            session,
            userId: userUuid,
            mode: OfflineSyncPeerMode.follower,
            peerNodeId: _uuid(97),
          );

          await follower.adoptPeerGrants([
            _grant(gammaSpaceUuid),
            _grant(betaSpaceUuid, role: OfflineSyncSpaceRole.readOnly),
            _grant(alphaSpaceUuid),
            _grant(betaSpaceUuid, role: OfflineSyncSpaceRole.readOnly),
            _grant(alphaSpaceUuid),
          ]);

          expect(
            follower.activeSpaceIds,
            [alphaSpaceUuid, betaSpaceUuid, gammaSpaceUuid],
          );
        },
      );
    },
  );
}

UuidValue _uuid(int value) => UuidValue.fromString(
  '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}',
);

OfflineSyncSpaceGrant _grant(
  UuidValue spaceUuid, {
  OfflineSyncSpaceRole role = OfflineSyncSpaceRole.readWrite,
}) => OfflineSyncSpaceGrant(uuidSpaceId: spaceUuid, role: role);

OfflineSyncSinceHlc _since(UuidValue spaceUuid, Hlc checkpoint) =>
    OfflineSyncSinceHlc(uuidSpaceId: spaceUuid, nodeCheckpoints: [checkpoint]);

Hlc _hlc(UuidValue nodeUuid, {required int minute}) =>
    Hlc(DateTime.utc(2026, 7, 2, 12, minute), 0, nodeUuid);
