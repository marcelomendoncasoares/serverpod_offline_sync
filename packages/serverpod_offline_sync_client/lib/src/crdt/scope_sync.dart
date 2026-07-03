import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../managers/scope.dart';
import '../protocol/protocol.dart';
import 'merge.dart';
import 'roles.dart';
import 'scope_membership.dart';

/// How a peer decides which scopes it syncs.
enum CrdtSyncPeerMode {
  /// Dictates the scope set from authoritative membership.
  authoritative,

  /// Adopts the scope set announced by the authoritative peer.
  follower,
}

/// De-duplicates [scopeIds] and sorts them by UUID string so both peers iterate
/// scopes in the same deterministic order.
List<UuidValue> _sortedUniqueScopeIds(Iterable<UuidValue> scopeIds) {
  final byUuid = {for (final scopeId in scopeIds) scopeId.uuid: scopeId};
  return byUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
}

/// De-duplicates [grants] by scope and sorts them by scope UUID string.
List<CrdtScopeGrant> _sortedUniqueGrants(Iterable<CrdtScopeGrant> grants) {
  final byUuid = {for (final grant in grants) grant.uuidScopeId.uuid: grant};
  return byUuid.values.toList()
    ..sort((a, b) => a.uuidScopeId.uuid.compareTo(b.uuidScopeId.uuid));
}

/// Whether the grant list [a] last announced equals the current list [b].
bool _grantsEqual(List<CrdtScopeGrant>? a, List<CrdtScopeGrant> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < b.length; i++) {
    if (a[i].uuidScopeId != b[i].uuidScopeId || a[i].role != b[i].role) {
      return false;
    }
  }
  return true;
}

/// Owns the scope state of one sync session and every scope decision its driver
/// (`CrdtSync.sync`) makes: which scopes are active, their handshake and
/// checkpoint state, membership reconciliation, and per-frame authorization.
///
/// The driver owns the wire (yielding and reading frames, the once/continuous
/// control flow); this owns the scopes. It needs only a [DatabaseSession] and
/// the membership helpers, so it carries no protocol or transport concerns.
class CrdtScopeSyncSession {
  /// Creates a scope session for [userId] acting in [mode] against [_session].
  ///
  /// [peerNodeId] is the remote peer's CRDT node, learned from its connect
  /// handshake before this session is constructed.
  CrdtScopeSyncSession(
    this._session, {
    required UuidValue userId,
    required CrdtSyncPeerMode mode,
    required UuidValue peerNodeId,
  }) : _userId = userId,
       _mode = mode,
       _peerNodeId = peerNodeId;

  final DatabaseSession _session;
  final UuidValue _userId;
  final CrdtSyncPeerMode _mode;
  final UuidValue _peerNodeId;

  /// Session-lived scope manager. Reused across cycles so its in-memory cache
  /// of already-materialized scopes survives, sparing a follower a per-cycle
  /// `getOrCreate` round-trip for scopes it has already created this session.
  late final CrdtScopeManager _scopeManager = CrdtScopeManager(_session);

  /// The grant set this peer last announced (null until the first announcement).
  List<CrdtScopeGrant>? _announcedGrants;

  /// This peer's current local grants, refreshed by [reconcile].
  List<CrdtScopeGrant> _localGrants = const [];

  /// The grant set the peer last announced, adopted by [adoptPeerGrants].
  List<CrdtScopeGrant> _peerGrants = const [];

  /// The scopes cycled this round, sorted, materialized for a follower.
  List<UuidValue> _activeScopeIds = const [];

  /// UUID strings of [_activeScopeIds] and of [_peerGrants], for O(1) lookups.
  Set<String> _activeUuids = const {};
  Set<String> _peerUuids = const {};

  /// Active scopes this peer may send local writes for.
  Set<String> _writableUuids = const {};

  /// Scopes for which this peer has already sent its [CrdtSyncSinceHlc].
  final Set<String> _sinceHlcSent = {};

  /// The peer's node id from its connect handshake.
  UuidValue get peerNodeId => _peerNodeId;

  /// What the peer has seen per scope (advances as we send), seeded from its
  /// [CrdtSyncSinceHlc] — presence means the scope's handshake completed both
  /// ways, so it can stream changes.
  final Map<UuidValue, Map<UuidValue, Hlc>> _checkpointsByScope = {};

  /// The grants this peer should announce this cycle.
  List<CrdtScopeGrant> get localGrants => _localGrants;

  /// The scopes cycled this round (sorted, deterministic on both peers).
  List<UuidValue> get activeScopeIds => _activeScopeIds;

  /// The authenticated user this sync session represents.
  UuidValue get userId => _userId;

  /// Whether this peer is authoritative for scope membership.
  bool get isAuthoritative => _mode == CrdtSyncPeerMode.authoritative;

  /// Whether the local grants changed since the last announcement.
  bool get shouldAnnounce => !_grantsEqual(_announcedGrants, _localGrants);

  /// Records that [localGrants] was just announced, so it is not re-sent until
  /// it changes again.
  void markAnnounced() => _announcedGrants = _localGrants;

  /// Re-resolves local membership, then recomputes the active scope set.
  ///
  /// Used at the top of every data-loop cycle so an authoritative peer picks up
  /// its own membership changes. Establishment instead recomputes from the
  /// *announced* grants (via [adoptPeerGrants]) without re-reading, so a grant
  /// that lands mid-handshake cannot make this peer handshake a different scope
  /// count than it announced.
  Future<void> reconcile() async {
    _localGrants = _sortedUniqueGrants(await _resolveLocalGrants());
    await _recomputeActiveScopes();
    _refreshWritableScopes();
  }

  /// Adopts the peer's announced [peerGrants] and recomputes the active scope
  /// set from the grants already resolved (no membership re-read). A follower
  /// materializes the announced scopes locally and projects their roles into the
  /// members cache (projection needs the scope rows to exist); an authoritative
  /// peer keeps cycling its own membership.
  Future<void> adoptPeerGrants(List<CrdtScopeGrant> peerGrants) async {
    _peerGrants = _sortedUniqueGrants(peerGrants);
    _peerUuids = {for (final g in _peerGrants) g.uuidScopeId.uuid};
    await _recomputeActiveScopes();
    if (_mode == CrdtSyncPeerMode.follower) {
      await CrdtScopeMembership.projectFollowerMembership(
        _session,
        userUuid: _userId,
        grants: _peerGrants,
      );
    }
    _refreshWritableScopes();
  }

  /// Recomputes the active scope set from the current local and peer grants
  /// (materializing a follower's adopted scopes), then prunes in-session state
  /// for scopes that left the set — e.g. a membership the peer revoked.
  Future<void> _recomputeActiveScopes() async {
    _activeScopeIds = _sortedUniqueScopeIds(
      await _resolveOrderedScopeIds(
        localScopeIds: [for (final g in _localGrants) g.uuidScopeId],
        peerScopeIds: [for (final g in _peerGrants) g.uuidScopeId],
      ),
    );
    _activeUuids = {for (final s in _activeScopeIds) s.uuid};
    _sinceHlcSent.removeWhere((uuid) => !_activeUuids.contains(uuid));
    _checkpointsByScope.removeWhere((s, _) => !_activeUuids.contains(s.uuid));
  }

  void _refreshWritableScopes() {
    if (_mode == CrdtSyncPeerMode.authoritative) {
      _writableUuids = _activeUuids;
      return;
    }

    // The peer's announced grants already carry the authoritative roles, so a
    // follower derives writability in memory instead of re-reading the cache
    // it projected from these same grants. The personal scope is always
    // writable; consumers only consult scopes in the active set.
    _writableUuids = {
      _userId.uuid,
      for (final grant in _peerGrants)
        if (grant.role.canWrite) grant.uuidScopeId.uuid,
    };
  }

  /// Marks that this peer is sending its [CrdtSyncSinceHlc] for [scopeId],
  /// returning whether the scope was newly handshaked (so the driver sends one).
  bool markHandshakeSent(UuidValue scopeId) => _sinceHlcSent.add(scopeId.uuid);

  /// Records the peer's resume vector for [scopeId] from its [sinceHlc],
  /// completing the scope's handshake from this peer's side.
  void recordPeerHandshake(UuidValue scopeId, CrdtSyncSinceHlc sinceHlc) {
    _checkpointsByScope[scopeId] = {
      for (final checkpoint in sinceHlc.nodeCheckpoints) checkpoint.nodeId: checkpoint,
    };
  }

  /// Checkpoints for writable scopes whose handshake completed both ways, keyed
  /// by scope — the input to a pending-change collection pass.
  Map<UuidValue, List<Hlc>> get sendableCheckpoints => {
    for (final scopeId in _activeScopeIds)
      if (_checkpointsByScope[scopeId] != null && _writableUuids.contains(scopeId.uuid))
        scopeId: _checkpointsByScope[scopeId]!.values.toList(),
  };

  /// Whether any active scope still lacks the peer handshake state.
  bool get hasIncompleteActiveHandshake => _activeScopeIds.any(
    (scopeId) => _checkpointsByScope[scopeId] == null,
  );

  /// Advances the in-session checkpoint for [scopeId] past a just-sent [change],
  /// so the next collection does not resend it.
  void advanceCheckpoint(UuidValue scopeId, CrdtMergeChange change) {
    final checkpoints = _checkpointsByScope[scopeId];
    if (checkpoints == null) return;
    checkpoints[change.uuidNodeId] = change.hlc.maxBetween(
      checkpoints[change.uuidNodeId],
    );
  }

  /// Whether this peer authorizes acting in [scopeId]: an authoritative peer
  /// trusts its own membership, a follower trusts the peer's announced set. This
  /// is the wire-side counterpart of the server's membership gate.
  bool accepts(UuidValue scopeId) =>
      (_mode == CrdtSyncPeerMode.follower ? _peerUuids : _activeUuids).contains(
        scopeId.uuid,
      );

  /// The greatest checkpoint HLC tracked for [scopeId], or null if none.
  Hlc? checkpointMaxOf(UuidValue scopeId) {
    final checkpoints = _checkpointsByScope[scopeId];
    if (checkpoints == null || checkpoints.isEmpty) return null;
    return checkpoints.values.max;
  }

  /// Resolves the local grants this peer announces in its [CrdtSyncScopeSet].
  ///
  /// Authoritative peers enumerate [CrdtScopeMembership.memberGrants].
  /// Followers send an empty set because the authoritative peer never widens
  /// access from follower-reported scope state.
  Future<List<CrdtScopeGrant>> _resolveLocalGrants() async {
    switch (_mode) {
      case CrdtSyncPeerMode.authoritative:
        return CrdtScopeMembership.memberGrants(_session, _userId);
      case CrdtSyncPeerMode.follower:
        await _scopeManager.getOrCreate(_userId);
        return const [];
    }
  }

  /// Resolves the ordered lockstep scopes cycled this round.
  ///
  /// Authoritative peers dictate their own set; followers adopt the peer's
  /// announced set, materializing each scope locally.
  Future<List<UuidValue>> _resolveOrderedScopeIds({
    required List<UuidValue> localScopeIds,
    required List<UuidValue> peerScopeIds,
  }) async {
    switch (_mode) {
      case CrdtSyncPeerMode.authoritative:
        return localScopeIds;
      case CrdtSyncPeerMode.follower:
        final scopeIds = _sortedUniqueScopeIds(peerScopeIds);
        for (final scopeId in scopeIds) {
          await _scopeManager.getOrCreate(scopeId);
        }
        return scopeIds;
    }
  }
}
