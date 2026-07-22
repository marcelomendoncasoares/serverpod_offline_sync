import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart';
import 'package:serverpod_offline_sync_client/src/crdt/scope_sync.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:test/test.dart';

import '../test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod(
    'Given a database-backed CRDT scope sync session,',
    (sessionBuilder, _) {
      sessionBuilder.build().serverpod.initializeCrdtSync(syncTables: []);

      late Session session;
      setUp(() async {
        session = sessionBuilder.build();
      });

      test(
        'when authoritative and follower sessions reconcile stored membership, '
        'then only the authoritative session announces grants.',
        () async {
          final userUuid = _uuid(30);
          final sharedScopeUuid = await session.crdt.scopes.createFor(userUuid);

          final authoritative = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.authoritative,
            peerNodeId: _uuid(90),
          );

          await authoritative.reconcile();

          final expectedAuthoritativeScopeIds = {sharedScopeUuid, userUuid};
          expect(
            {for (final grant in authoritative.localGrants) grant.uuidScopeId},
            expectedAuthoritativeScopeIds,
          );
          expect(
            authoritative.activeScopeIds.toSet(),
            expectedAuthoritativeScopeIds,
          );

          expect(authoritative.shouldAnnounce, isTrue);
          authoritative.markAnnounced();
          expect(authoritative.shouldAnnounce, isFalse);

          final follower = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.follower,
            peerNodeId: _uuid(91),
          );
          await follower.reconcile();

          expect(follower.localGrants, isEmpty);
          expect(follower.activeScopeIds, isEmpty);
          expect(follower.shouldAnnounce, isTrue);

          follower.markAnnounced();
          expect(follower.shouldAnnounce, isFalse);
        },
      );

      test(
        'when an authoritative session adopts peer-only grants, '
        'then it keeps cycling only its locally resolved scopes.',
        () async {
          final userUuid = _uuid(31);
          final peerOnlyScopeUuid = _uuid(11);
          final localSharedScopeUuid = await session.crdt.scopes.createFor(userUuid);

          final authoritative = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.authoritative,
            peerNodeId: _uuid(92),
          );

          await authoritative.reconcile();
          await authoritative.adoptPeerGrants([_grant(peerOnlyScopeUuid)]);

          final expectedScopeIds = {localSharedScopeUuid, userUuid};
          expect(authoritative.activeScopeIds.toSet(), expectedScopeIds);
          expect(authoritative.accepts(localSharedScopeUuid), isTrue);
          expect(authoritative.accepts(peerOnlyScopeUuid), isFalse);
        },
      );

      test(
        'when membership changes after an authoritative announcement is marked, '
        'then adoption keeps the announced scope set until the next reconcile.',
        () async {
          final userUuid = _uuid(32);

          final authoritative = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.authoritative,
            peerNodeId: _uuid(93),
          );

          await authoritative.reconcile();
          authoritative.markAnnounced();

          final laterSharedScopeUuid = await session.crdt.scopes.createFor(userUuid);

          await authoritative.adoptPeerGrants(const []);

          expect(authoritative.activeScopeIds, [userUuid]);
          expect(authoritative.shouldAnnounce, isFalse);

          await authoritative.reconcile();

          final expectedScopeIds = {laterSharedScopeUuid, userUuid};
          expect(authoritative.activeScopeIds.toSet(), expectedScopeIds);
          expect(authoritative.shouldAnnounce, isTrue);
        },
      );

      test(
        'when a follower adopts announced grants over a stale local cache, '
        'then only the announced memberships remain projected.',
        () async {
          final userUuid = _uuid(33);
          final announcedScopeUuid = _uuid(23);
          final staleScopeUuid = _uuid(13);

          final scope = await CrdtScopeManager(session).getOrCreate(staleScopeUuid);

          await CrdtScopeMember.db.upsertRow(
            session,
            CrdtScopeMember(
              scopeId: scope.id!,
              userUuid: userUuid,
              role: CrdtScopeRole.readWrite,
            ),
            conflictColumns: (t) => [t.scopeId, t.userUuid],
            updateColumns: (t) => [t.role],
          );

          final follower = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.follower,
            peerNodeId: _uuid(94),
          );

          await follower.adoptPeerGrants([
            _grant(userUuid),
            _grant(announcedScopeUuid, role: CrdtScopeRole.readOnly),
          ]);

          final expectedScopeIds = {announcedScopeUuid, userUuid};
          expect(follower.activeScopeIds.toSet(), expectedScopeIds);
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: userUuid,
              scopeUuid: announcedScopeUuid,
            ),
            CrdtScopeRole.readOnly,
          );
          expect(
            await CrdtScopeMembership.roleOf(
              session,
              userUuid: userUuid,
              scopeUuid: staleScopeUuid,
            ),
            isNull,
          );
        },
      );

      test(
        'when a follower handshakes read-only and writable scopes, '
        'then accepts includes all active scopes but checkpoints are sendable only for writable scopes.',
        () async {
          final userUuid = _uuid(34);
          final readOnlyScopeUuid = _uuid(14);
          final readWriteScopeUuid = _uuid(24);
          final unknownScopeUuid = _uuid(44);
          final remoteNodeUuid = _uuid(104);

          final follower = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.follower,
            peerNodeId: _uuid(95),
          );

          await follower.adoptPeerGrants([
            _grant(userUuid),
            _grant(readOnlyScopeUuid, role: CrdtScopeRole.readOnly),
            _grant(readWriteScopeUuid),
          ]);

          follower
            ..recordPeerHandshake(
              userUuid,
              _since(userUuid, _hlc(remoteNodeUuid, minute: 1)),
            )
            ..recordPeerHandshake(
              readOnlyScopeUuid,
              _since(readOnlyScopeUuid, _hlc(remoteNodeUuid, minute: 2)),
            )
            ..recordPeerHandshake(
              readWriteScopeUuid,
              _since(readWriteScopeUuid, _hlc(remoteNodeUuid, minute: 3)),
            );

          final expectedSendableScopeIds = {readWriteScopeUuid, userUuid};
          expect(follower.hasIncompleteActiveHandshake, isFalse);
          expect(follower.accepts(userUuid), isTrue);
          expect(follower.accepts(readOnlyScopeUuid), isTrue);
          expect(follower.accepts(readWriteScopeUuid), isTrue);
          expect(follower.accepts(unknownScopeUuid), isFalse);
          expect(follower.sendableCheckpoints.keys.toSet(), expectedSendableScopeIds);
          expect(follower.sendableCheckpoints[readOnlyScopeUuid], isNull);
        },
      );

      test(
        'when a sent change advances a completed handshake, '
        'then the tracked checkpoint moves to the change HLC.',
        () async {
          final userUuid = _uuid(37);
          final localNodeUuid = _uuid(47);
          final remoteNodeUuid = _uuid(107);

          final authoritative = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.authoritative,
            peerNodeId: _uuid(98),
          );

          final scopeUuid = await session.crdt.scopes.createFor(userUuid);

          await authoritative.reconcile();
          authoritative.recordPeerHandshake(
            scopeUuid,
            _since(scopeUuid, _hlc(remoteNodeUuid, minute: 6)),
          );

          final change = CrdtMergeInsert(
            uuidScopeId: scopeUuid,
            hlcDatetime: DateTime.utc(2026, 7, 2, 12, 7),
            hlcCounter: 1,
            tableName: 'person',
            uuidRowId: _uuid(57),
            uuidNodeId: localNodeUuid,
            data: CrdtNode(uuidNodeId: _uuid(67)),
          );

          authoritative.advanceCheckpoint(scopeUuid, change);

          expect(
            authoritative.checkpointMaxOf(scopeUuid),
            Hlc(DateTime.utc(2026, 7, 2, 12, 7), 1, localNodeUuid),
          );
        },
      );

      test(
        'when an active scope is revoked and later re-announced, '
        'then its checkpoint and sent-handshake state are pruned.',
        () async {
          final userUuid = _uuid(35);
          final retainedScopeUuid = _uuid(15);
          final revokedScopeUuid = _uuid(25);
          final remoteNodeUuid = _uuid(105);

          final follower = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.follower,
            peerNodeId: _uuid(96),
          );

          await follower.adoptPeerGrants([
            _grant(retainedScopeUuid),
            _grant(revokedScopeUuid),
          ]);

          expect(follower.markHandshakeSent(revokedScopeUuid), isTrue);
          expect(follower.markHandshakeSent(revokedScopeUuid), isFalse);

          follower
            ..recordPeerHandshake(
              retainedScopeUuid,
              _since(retainedScopeUuid, _hlc(remoteNodeUuid, minute: 4)),
            )
            ..recordPeerHandshake(
              revokedScopeUuid,
              _since(revokedScopeUuid, _hlc(remoteNodeUuid, minute: 5)),
            );

          await follower.adoptPeerGrants([_grant(retainedScopeUuid)]);

          expect(follower.accepts(retainedScopeUuid), isTrue);
          expect(follower.accepts(revokedScopeUuid), isFalse);
          expect(follower.sendableCheckpoints.keys, [retainedScopeUuid]);
          expect(follower.checkpointMaxOf(revokedScopeUuid), isNull);

          await follower.adoptPeerGrants([
            _grant(retainedScopeUuid),
            _grant(revokedScopeUuid),
          ]);

          expect(follower.markHandshakeSent(revokedScopeUuid), isTrue);
          expect(follower.hasIncompleteActiveHandshake, isTrue);
        },
      );

      test(
        'when a follower adopts duplicated out-of-order grants, '
        'then active scopes are de-duplicated and sorted by UUID.',
        () async {
          final userUuid = _uuid(36);
          final alphaScopeUuid = _uuid(1);
          final betaScopeUuid = _uuid(2);
          final gammaScopeUuid = _uuid(3);

          final follower = CrdtScopeSyncSession(
            session,
            userId: userUuid,
            mode: CrdtSyncPeerMode.follower,
            peerNodeId: _uuid(97),
          );

          await follower.adoptPeerGrants([
            _grant(gammaScopeUuid),
            _grant(betaScopeUuid, role: CrdtScopeRole.readOnly),
            _grant(alphaScopeUuid),
            _grant(betaScopeUuid, role: CrdtScopeRole.readOnly),
            _grant(alphaScopeUuid),
          ]);

          expect(
            follower.activeScopeIds,
            [alphaScopeUuid, betaScopeUuid, gammaScopeUuid],
          );
        },
      );
    },
  );
}

UuidValue _uuid(int value) => UuidValue.fromString(
  '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}',
);

CrdtScopeGrant _grant(
  UuidValue scopeUuid, {
  CrdtScopeRole role = CrdtScopeRole.readWrite,
}) => CrdtScopeGrant(uuidScopeId: scopeUuid, role: role);

CrdtSyncSinceHlc _since(UuidValue scopeUuid, Hlc checkpoint) =>
    CrdtSyncSinceHlc(uuidScopeId: scopeUuid, nodeCheckpoints: [checkpoint]);

Hlc _hlc(UuidValue nodeUuid, {required int minute}) =>
    Hlc(DateTime.utc(2026, 7, 2, 12, minute), 0, nodeUuid);
