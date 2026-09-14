import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../managers/space.dart';
import '../spaces/membership.dart';

/// How a peer decides which spaces it syncs.
enum OfflineSyncPeerMode {
  /// Dictates the space set from authoritative membership.
  authoritative,

  /// Adopts the space set announced by the authoritative peer.
  follower,
}

/// De-duplicates [spaceIds] and sorts them by UUID string so both peers iterate
/// spaces in the same deterministic order.
List<UuidValue> _sortedUniqueSpaceIds(Iterable<UuidValue> spaceIds) =>
    _sortedUniqueByUuid(spaceIds, (spaceId) => spaceId);

/// De-duplicates [grants] by space and sorts them by space UUID string.
List<OfflineSyncSpaceGrant> _sortedUniqueGrants(
  Iterable<OfflineSyncSpaceGrant> grants,
) => _sortedUniqueByUuid(grants, (grant) => grant.uuidSpaceId);

/// De-duplicates [items] and sorts them by the UUID returned by [uuidOf].
List<T> _sortedUniqueByUuid<T>(
  Iterable<T> items,
  UuidValue Function(T) uuidOf,
) {
  final byUuid = {for (final item in items) uuidOf(item).uuid: item};
  return byUuid.values.toList()
    ..sort((a, b) => uuidOf(a).uuid.compareTo(uuidOf(b).uuid));
}

/// Whether the grant list [a] last announced equals the current list [b].
bool _grantsEqual(List<OfflineSyncSpaceGrant>? a, List<OfflineSyncSpaceGrant> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < b.length; i++) {
    if (a[i].uuidSpaceId != b[i].uuidSpaceId || a[i].role != b[i].role) {
      return false;
    }
  }
  return true;
}

/// Owns the space state of one sync session and every space decision its driver
/// (`OfflineSyncEngine.sync`) makes: which spaces are active, their handshake and
/// checkpoint state, membership reconciliation, and per-frame authorization.
///
/// The driver owns the wire (yielding and reading frames, the once/continuous
/// control flow); this owns the spaces. It needs only a [DatabaseSession] and
/// the membership helpers, so it carries no protocol or transport concerns.
class OfflineSyncSpaceState {
  /// Creates a space session for [_userId] acting in [_mode] against [_session].
  ///
  /// [_peerNodeId] is the remote peer's CRDT node, learned from its connect
  /// handshake before this session is constructed.
  OfflineSyncSpaceState(
    this._session, {
    required this._userId,
    required this._mode,
    required this._peerNodeId,
  });

  final DatabaseSession _session;
  final UuidValue _userId;
  final OfflineSyncPeerMode _mode;
  final UuidValue _peerNodeId;

  /// Session-lived space manager. Reused across cycles so its in-memory cache
  /// of already-materialized spaces survives, sparing a follower a per-cycle
  /// `getOrCreate` round-trip for spaces it has already created this session.
  late final OfflineSyncSpaceManager _spaceManager = OfflineSyncSpaceManager(_session);

  /// The grant set this peer last announced (null until the first announcement).
  List<OfflineSyncSpaceGrant>? _announcedGrants;

  /// This peer's current local grants, refreshed by [reconcile].
  List<OfflineSyncSpaceGrant> _localGrants = const [];

  /// The grant set the peer last announced, adopted by [adoptPeerGrants].
  List<OfflineSyncSpaceGrant> _peerGrants = const [];

  /// The spaces cycled this round, sorted, materialized for a follower.
  List<UuidValue> _activeSpaceIds = const [];

  /// UUID strings of [_activeSpaceIds] and of [_peerGrants], for O(1) lookups.
  Set<String> _activeUuids = const {};
  Set<String> _peerUuids = const {};

  /// Active spaces this peer may send local writes for.
  Set<String> _writableUuids = const {};

  /// Spaces for which this peer has already sent its [OfflineSyncSinceHlc].
  final Set<String> _sinceHlcSent = {};

  /// The peer's node id from its connect handshake.
  UuidValue get peerNodeId => _peerNodeId;

  /// What the peer has seen per space (advances as we send), seeded from its
  /// [OfflineSyncSinceHlc] — presence means the space's handshake completed both
  /// ways, so it can stream changes.
  final Map<UuidValue, Map<UuidValue, Hlc>> _checkpointsBySpace = {};

  /// The grants this peer should announce this cycle.
  List<OfflineSyncSpaceGrant> get localGrants => _localGrants;

  /// The spaces cycled this round (sorted, deterministic on both peers).
  List<UuidValue> get activeSpaceIds => _activeSpaceIds;

  /// The authenticated user this sync session represents.
  UuidValue get userId => _userId;

  /// Whether this peer is authoritative for space membership.
  bool get isAuthoritative => _mode == OfflineSyncPeerMode.authoritative;

  /// Whether the local grants changed since the last announcement.
  bool get shouldAnnounce => !_grantsEqual(_announcedGrants, _localGrants);

  /// Records that [localGrants] was just announced, so it is not re-sent until
  /// it changes again.
  void markAnnounced() => _announcedGrants = _localGrants;

  /// Re-resolves local membership, then recomputes the active space set.
  ///
  /// Used at the top of every data-loop cycle so an authoritative peer picks up
  /// its own membership changes. Establishment instead recomputes from the
  /// *announced* grants (via [adoptPeerGrants]) without re-reading, so a grant
  /// that lands mid-handshake cannot make this peer handshake a different space
  /// count than it announced.
  Future<void> reconcile() async {
    _localGrants = _sortedUniqueGrants(await _resolveLocalGrants());
    await _recomputeActiveSpaces();
    _refreshWritableSpaces();
  }

  /// Adopts the peer's announced [peerGrants] and recomputes the active space
  /// set from the grants already resolved (no membership re-read). A follower
  /// materializes the announced spaces locally and projects their roles into the
  /// members cache (projection needs the space rows to exist); an authoritative
  /// peer keeps cycling its own membership.
  Future<void> adoptPeerGrants(List<OfflineSyncSpaceGrant> peerGrants) async {
    _peerGrants = _sortedUniqueGrants(peerGrants);
    _peerUuids = {for (final g in _peerGrants) g.uuidSpaceId.uuid};
    await _recomputeActiveSpaces();
    if (_mode == OfflineSyncPeerMode.follower) {
      await OfflineSyncSpaceMembership.projectFollowerMembership(
        _session,
        userUuid: _userId,
        grants: _peerGrants,
      );
    }
    _refreshWritableSpaces();
  }

  /// Recomputes the active space set from the current local and peer grants
  /// (materializing a follower's adopted spaces), then prunes in-session state
  /// for spaces that left the set — e.g. a membership the peer revoked.
  Future<void> _recomputeActiveSpaces() async {
    _activeSpaceIds = _sortedUniqueSpaceIds(
      await _resolveOrderedSpaceIds(
        localSpaceIds: [for (final g in _localGrants) g.uuidSpaceId],
        peerSpaceIds: [for (final g in _peerGrants) g.uuidSpaceId],
      ),
    );
    _activeUuids = {for (final s in _activeSpaceIds) s.uuid};
    _sinceHlcSent.removeWhere((uuid) => !_activeUuids.contains(uuid));
    _checkpointsBySpace.removeWhere((s, _) => !_activeUuids.contains(s.uuid));
  }

  void _refreshWritableSpaces() {
    if (_mode == OfflineSyncPeerMode.authoritative) {
      _writableUuids = _activeUuids;
      return;
    }

    // The peer's announced grants already carry the authoritative roles, so a
    // follower derives writability in memory instead of re-reading the cache
    // it projected from these same grants. The personal space is always
    // writable; consumers only consult spaces in the active set.
    _writableUuids = {
      _userId.uuid,
      for (final grant in _peerGrants)
        if (grant.role.canWrite) grant.uuidSpaceId.uuid,
    };
  }

  /// Marks that this peer is sending its [OfflineSyncSinceHlc] for [spaceId],
  /// returning whether the space was newly handshaked (so the driver sends one).
  bool markHandshakeSent(UuidValue spaceId) => _sinceHlcSent.add(spaceId.uuid);

  /// Records the peer's resume vector for [spaceId] from its [sinceHlc],
  /// completing the space's handshake from this peer's side.
  void recordPeerHandshake(UuidValue spaceId, OfflineSyncSinceHlc sinceHlc) {
    _checkpointsBySpace[spaceId] = {
      for (final checkpoint in sinceHlc.nodeCheckpoints) checkpoint.nodeId: checkpoint,
    };
  }

  /// Checkpoints for writable spaces whose handshake completed both ways, keyed
  /// by space — the input to a pending-change collection pass.
  Map<UuidValue, List<Hlc>> get sendableCheckpoints => {
    for (final spaceId in _activeSpaceIds)
      if (_checkpointsBySpace[spaceId] != null && _writableUuids.contains(spaceId.uuid))
        spaceId: _checkpointsBySpace[spaceId]!.values.toList(),
  };

  /// Whether any active space still lacks the peer handshake state.
  bool get hasIncompleteActiveHandshake => _activeSpaceIds.any(
    (spaceId) => _checkpointsBySpace[spaceId] == null,
  );

  /// Advances the in-session checkpoint for [spaceId] past a just-sent [change],
  /// so the next collection does not resend it.
  void advanceCheckpoint(UuidValue spaceId, CrdtMergeChange change) {
    final checkpoints = _checkpointsBySpace[spaceId];
    if (checkpoints == null) return;
    checkpoints[change.uuidNodeId] = change.hlc.maxBetween(
      checkpoints[change.uuidNodeId],
    );
  }

  /// Whether this peer authorizes acting in [spaceId]: an authoritative peer
  /// trusts its own membership, a follower trusts the peer's announced set. This
  /// is the wire-side counterpart of the server's membership gate.
  bool accepts(UuidValue spaceId) =>
      (_mode == OfflineSyncPeerMode.follower ? _peerUuids : _activeUuids).contains(
        spaceId.uuid,
      );

  /// The greatest checkpoint HLC tracked for [spaceId], or null if none.
  Hlc? checkpointMaxOf(UuidValue spaceId) {
    final checkpoints = _checkpointsBySpace[spaceId];
    if (checkpoints == null || checkpoints.isEmpty) return null;
    return checkpoints.values.max;
  }

  /// Resolves the local grants this peer announces in its [OfflineSyncSpaceSet].
  ///
  /// Authoritative peers enumerate [OfflineSyncSpaceMembership.memberGrants].
  /// Followers send an empty set because the authoritative peer never widens
  /// access from follower-reported space state.
  Future<List<OfflineSyncSpaceGrant>> _resolveLocalGrants() async {
    switch (_mode) {
      case OfflineSyncPeerMode.authoritative:
        return OfflineSyncSpaceMembership.memberGrants(_session, _userId);
      case OfflineSyncPeerMode.follower:
        await _spaceManager.getOrCreate(_userId);
        return const [];
    }
  }

  /// Resolves the ordered lockstep spaces cycled this round.
  ///
  /// Authoritative peers dictate their own set; followers adopt the peer's
  /// announced set, materializing each space locally.
  Future<List<UuidValue>> _resolveOrderedSpaceIds({
    required List<UuidValue> localSpaceIds,
    required List<UuidValue> peerSpaceIds,
  }) async {
    switch (_mode) {
      case OfflineSyncPeerMode.authoritative:
        return localSpaceIds;
      case OfflineSyncPeerMode.follower:
        final spaceIds = _sortedUniqueSpaceIds(peerSpaceIds);
        for (final spaceId in spaceIds) {
          await _spaceManager.getOrCreate(spaceId);
        }
        return spaceIds;
    }
  }
}
