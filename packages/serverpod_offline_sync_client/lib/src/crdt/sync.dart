import 'dart:async';
import 'dart:math' show min;

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/recorder.dart';
import '../managers/scope.dart';
import '../protocol/protocol.dart';
import '../utils/case_when.dart' show Case;
import 'exceptions.dart';
import 'extensions.dart';
import 'integrity_violation.dart';
import 'merge.dart';
import 'scope_membership.dart';

/// Callback function for when a merge is successful.
typedef CrdtSyncOnMergeSuccess =
    FutureOr<void> Function(UuidValue scopeUuid, Hlc syncedHlc);

/// How a peer decides which scopes it syncs and which side dictates the cycle.
///
/// Both sides enumerate membership from the same shared `crdt_scope_members`
/// table, so the only thing that varies per role is the cycle direction.
enum CrdtSyncPeerMode {
  /// Dictates the scope set from authoritative membership (the server, or a
  /// designated authoritative peer in a P2P scheme). Announces and cycles its
  /// own [CrdtScopeMembership.memberScopes].
  authoritative,

  /// Adopts the scope set announced by the authoritative peer, materializing
  /// each announced scope locally. Used by client followers.
  follower,

  /// Syncs only the user's personal scope and ignores shared memberships.
  personalOnly,
}

List<UuidValue> _sortedUniqueScopeIds(Iterable<UuidValue> scopeIds) {
  final byUuid = {for (final scopeId in scopeIds) scopeId.uuid: scopeId};
  return byUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
}

List<CrdtScopeGrant> _sortedUniqueGrants(Iterable<CrdtScopeGrant> grants) {
  final byUuid = {for (final grant in grants) grant.uuidScopeId.uuid: grant};
  return byUuid.values.toList()
    ..sort((a, b) => a.uuidScopeId.uuid.compareTo(b.uuidScopeId.uuid));
}

/// Whether the grant list [a] last announced equals the current list [b].
///
/// Both lists are sorted by scope UUID (see [_sortedUniqueGrants]), so a
/// positional comparison of scope and role decides whether a continuous peer
/// needs to re-announce its [CrdtSyncScopeSet] this cycle.
bool _grantsEqual(List<CrdtScopeGrant>? a, List<CrdtScopeGrant> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < b.length; i++) {
    if (a[i].uuidScopeId != b[i].uuidScopeId || a[i].role != b[i].role) {
      return false;
    }
  }
  return true;
}

/// A tuple representing the ownership of a domain row.
typedef DomainRowOwner = ({bool exists, int? scopeId});

/// A cache of domain row owners by table name and row id.
typedef DomainRowOwnerCache = Map<(String, UuidValue), DomainRowOwner>;

/// The shared CRDT synchronization logic used by both client and server nodes.
class CrdtSync {
  /// Creates a new [CrdtSync] instance.
  CrdtSync({
    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The serialization manager to use for deserializing merge changes.
    required DatabaseSerializationManager serializationManager,

    /// Shared CRDT database metadata.
    CrdtDatabaseContext? databaseContext,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = defaultContinuousSyncInterval,
  }) : _syncTables = syncTables,
       _serializationManager = serializationManager,
       _databaseContext =
           databaseContext ??
           CrdtDatabaseContext(
             syncTables: syncTables,
             serializationManager: serializationManager,
           ),
       _syncBatchSize = syncBatchSize,
       _continuousSyncInterval = continuousSyncInterval {
    if (syncBatchSize < 1) {
      throw ArgumentError.value(syncBatchSize, 'syncBatchSize', 'Must be >= 1');
    }
  }

  /// Default maximum number of merge changes sent in one stream message.
  static const defaultSyncBatchSize = 100;

  /// Default delay between continuous sync rounds.
  static const defaultContinuousSyncInterval = Duration(milliseconds: 200);

  final List<Table> _syncTables;
  final DatabaseSerializationManager _serializationManager;
  final CrdtDatabaseContext _databaseContext;
  final int _syncBatchSize;
  final Duration _continuousSyncInterval;

  /// Wraps [database] in a CRDT-aware database using this sync context.
  CrdtDatabase wrapDatabase(
    Database database, {
    UuidValue? persistentUserId,
  }) {
    if (database is CrdtDatabase) return database;
    return CrdtDatabase(
      database,
      syncTables: _syncTables,
      syncBatchSize: _syncBatchSize,
      continuousSyncInterval: _continuousSyncInterval,
      persistentUserId: persistentUserId,
      context: _databaseContext,
    );
  }

  late final Map<String, Table> _syncTablesByName = {
    for (final table in _syncTables) table.tableName: table,
  };

  late final Map<String, String> _classNamesByTableName = {
    for (final definition in _serializationManager.getTargetTableDefinitions())
      if (definition.dartName != null) definition.name: definition.dartName!,
  };

  late final Map<String, Map<String, ColumnDefinition>> _columnDefinitionsByTableName =
      {
        for (final definition in _serializationManager.getTargetTableDefinitions())
          definition.name: {
            for (final column in definition.columns) column.name: column,
          },
      };

  /// The deterministic hash representing the current synchronized schema.
  late final String currentSyncTablesHash = computeSyncTablesHash(
    _syncTables,
    tableDefinitions: _serializationManager.getTargetTableDefinitions(),
  );

  /// Computes a deterministic fixed-size hash of the synchronized schema.
  ///
  /// The [tableDefinitions] is the list of all table definitions in the
  /// database, which must include the definitions for all [syncTables].
  static String computeSyncTablesHash(
    List<Table> syncTables, {
    required List<TableDefinition> tableDefinitions,
  }) {
    final canonicalSignature = _computeCanonicalSyncTablesSignature(
      syncTables,
      tableDefinitions: tableDefinitions,
    );
    // Use two deterministic namespace-based UUIDv5 hashes to keep the payload
    // fixed-size while substantially reducing the practical collision risk.
    const uuid = Uuid();
    return '${uuid.v5(Namespace.url.value, canonicalSignature)}:'
        '${uuid.v5(Namespace.oid.value, canonicalSignature)}';
  }

  /// Streams local CRDT changes that a peer node has not seen yet.
  ///
  /// Changes are emitted in insert, update, then delete order. Domain row and
  /// column payloads are resolved incrementally as each change is yielded.
  ///
  /// Foreign-key columns with an active projection override are sent with their
  /// durable [CrdtDataForeignKey.attemptedValue], not the visible value stored
  /// in the domain table. Peers need the attempted fact to converge; local FK
  /// projection materializes only the safe visible value into domain tables.
  ///
  /// All changes for nodes that are not present in the [nodeCheckpoints] list
  /// are collected and emitted. Passing an empty list will collect all changes.
  Stream<CrdtMergeChange> collectPendingChanges(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
    required List<Hlc> nodeCheckpoints,
  }) async* {
    final crdtUser = await CrdtScopeManager(session).getOrCreate(userId);
    final context = _PendingScopeContext(
      scopeIds: {crdtUser.id!},
      scopeUuidById: {crdtUser.id!: crdtUser.uuidScopeId},
      nodeCheckpoints: nodeCheckpoints,
    );
    try {
      await for (final (_, change) in _streamPendingChanges(session, context)) {
        yield change;
      }
    } on PendingOutboundIntegrityViolation catch (violation) {
      await _recordAndThrowIntegrityViolation(session, violation);
    }
  }

  /// Streams pending changes for every scope in [checkpointsByScopeUuid] in a
  /// single pass, each change tagged with its scope.
  ///
  /// Resolves the scopes' internal ids once and unions their per-node checkpoint
  /// vectors — node ids are unique per scope, so a row's node already pins it to
  /// exactly one scope — then runs the three collection queries bounded to that
  /// scope set (`scopeId IN (…)`). This is three queries for the whole cycle
  /// instead of three per scope, the multi-scope analogue of
  /// [collectPendingChanges]. Per-row ownership and integrity checks resolve
  /// against each row's own scope, so the security checks are unchanged.
  Stream<(UuidValue, CrdtMergeChange)> collectAllPendingChanges(
    DatabaseSession session, {
    required Map<UuidValue, List<Hlc>> checkpointsByScopeUuid,
  }) async* {
    if (checkpointsByScopeUuid.isEmpty) return;

    final scopes = await CrdtScope.db.find(
      session,
      where: (t) => t.uuidScopeId.inSet(checkpointsByScopeUuid.keys.toSet()),
    );
    final context = _PendingScopeContext(
      scopeIds: {for (final scope in scopes) scope.id!},
      scopeUuidById: {for (final scope in scopes) scope.id!: scope.uuidScopeId},
      nodeCheckpoints: [
        for (final checkpoints in checkpointsByScopeUuid.values) ...checkpoints,
      ],
    );

    try {
      yield* _streamPendingChanges(session, context);
    } on PendingOutboundIntegrityViolation catch (violation) {
      await _recordAndThrowIntegrityViolation(session, violation);
    }
  }

  /// Creates the [CrdtSyncSinceHlc] checkpoint for a scope handshake.
  ///
  /// [CrdtSyncSinceHlc.nodeCheckpoints] reflects the latest change this node
  /// has received from each known node, tagged with the source node id.
  Future<CrdtSyncSinceHlc> createSyncSinceHlc(
    DatabaseSession session, {
    required UuidValue userId,
  }) async {
    final crdtUser = await CrdtScopeManager(session).getOrCreate(userId);
    final localNodeId = crdtUser.currentNode!.uuidNodeId;

    final nodes = await CrdtNode.db.find(
      session,
      where: (t) => t.scopeId.equals(crdtUser.id) & t.uuidNodeId.notEquals(localNodeId),
    );

    return CrdtSyncSinceHlc(
      uuidScopeId: userId,
      localNodeId: localNodeId,
      nodeCheckpoints: [
        // The local node is always included to avoid collecting its own changes.
        Hlc.now(localNodeId),
        for (final node in nodes) node.lastReceivedHlc ?? Hlc.zero(node.uuidNodeId),
      ],
    );
  }

  /// Merges a remote [mergeSet] and records the sync checkpoint for [otherNodeId].
  ///
  /// Inbound merge applies each remote change, then materializes foreign-key
  /// projection into domain tables via [CrdtDatabase.mergeChanges].
  ///
  /// Throws if the merge fails. The sync stream should be closed so the next
  /// attempt resumes from the last persisted checkpoint.
  ///
  /// Returns the greatest HLC synced in the batch, or `null` if the batch is
  /// empty.
  Future<Hlc?> mergeInboundBatch(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue otherNodeId,
    required CrdtMergeSet mergeSet,
  }) async {
    if (mergeSet.isEmpty) return null;
    final maxSyncedHlc = mergeSet.maxHlc;
    final crdtDb = _openCrdtDatabase(session);
    await crdtDb.mergeChanges(mergeSet, scopeId: userId);
    if (maxSyncedHlc != null) {
      await crdtDb.recordSyncCheckpoint(otherNodeId, maxSyncedHlc, userId: userId);
    }
    return maxSyncedHlc;
  }

  /// Streams a framed outbound sync batch of merge changes.
  Stream<CrdtSyncStreamEvent> streamOutboundBatch(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
    required List<Hlc> nodeCheckpoints,
  }) async* {
    yield* collectPendingChanges(
          session,
          userId: userId,
          peerNodeId: peerNodeId,
          nodeCheckpoints: nodeCheckpoints,
        )
        .chunked(_syncBatchSize)
        .map(
          (changes) => CrdtSyncMergeChunk(uuidScopeId: userId, changes: changes),
        );
    yield CrdtSyncEndOfBatch();
  }

  /// Runs a symmetric CRDT sync session over a bidirectional event stream.
  ///
  /// Both peers send [CrdtSyncConnect] once and validate the schema hash, then
  /// **establish** the session in lockstep: exchange the [CrdtSyncScopeSet] and
  /// handshake every initially-agreed scope with a synchronous [CrdtSyncSinceHlc]
  /// exchange, so neither peer acts before it knows the agreed set.
  ///
  /// After establishment every cycle is one combined batch: the scope
  /// announcement (only when this peer's grants changed), a [CrdtSyncSinceHlc]
  /// for each newly active scope, and scope-tagged [CrdtSyncMergeChunk]s,
  /// terminated by a single [CrdtSyncEndOfBatch] that is itself omitted when
  /// nothing was sent. The receive phase ([_collectCycleBatch]) demultiplexes the
  /// peer's batch by type and scope until that terminator or — when the peer was
  /// idle — an idle timeout, so two idle peers exchange no frames and each polls
  /// once per idle timeout regardless of scope count.
  ///
  /// When [once] is true the loop runs exactly one combined cycle and then
  /// performs the symmetric [CrdtSyncClose] handshake; because establishment
  /// already handshaked every scope, that single cycle exchanges all pending
  /// changes both ways. Continuous sync loops instead, absorbing membership
  /// changes mid-session: a newly granted scope is announced, adopted, and
  /// established over the following cycles (its data deferred until its
  /// `SinceHlc` round-trips) — the trade for keeping the steady state silent.
  ///
  /// Sent changes advance the corresponding in-memory checkpoints for subsequent
  /// sends within the session. If a batch fails to merge, the exception
  /// propagates and the stream closes; the next attempt resumes from the last
  /// persisted checkpoint on the side that failed to merge.
  Stream<CrdtSyncStreamEvent> sync(
    DatabaseSession session, {
    required UuidValue userId,
    required Stream<CrdtSyncStreamEvent> inbound,
    bool once = false,
    CrdtSyncOnMergeSuccess? onMergeSuccess,
    CrdtSyncPeerMode mode = CrdtSyncPeerMode.personalOnly,
  }) async* {
    final inboundIterator = StreamIterator(
      // Inject a timeout event if the inbound stream is idle for too long, so a
      // cycle can resolve to an empty batch and wait without closing the stream.
      inbound.timeout(
        const Duration(seconds: 1),
        onTimeout: (sink) => sink.add(CrdtSyncIdleTimeout()),
      ),
    );

    // `once` treats a peer that closes mid-handshake as an error (its reads
    // throw); continuous treats it as a clean shutdown (the read returns null).
    Future<T?> readFrame<T extends CrdtSyncStreamEvent>() => once
        ? inboundIterator.moveAndThrowIfNot<T>()
        : inboundIterator.moveOrNullIfClosed<T>();

    var sessionCompleted = false;
    try {
      yield CrdtSyncConnect(syncTablesHash: currentSyncTablesHash);
      final peerConnect = await readFrame<CrdtSyncConnect>();
      if (peerConnect == null) {
        sessionCompleted = true;
        return;
      }
      _validateSyncTablesHash(peerConnect.syncTablesHash);

      final peerNodeIdByScope = <UuidValue, UuidValue>{};
      final checkpointsByScope = <UuidValue, Map<UuidValue, Hlc>>{};
      final sinceHlcSentScopes = <String>{};

      // === Establishment (lockstep): announce the scope set and synchronously
      // handshake the initially-agreed scopes. Doing this before the loop keeps
      // `once` a single bounded round and gives continuous a settled start with
      // no announce/adopt offset. ===
      var announcedGrants = _sortedUniqueGrants(
        await _localScopeGrants(session, userId, mode),
      );
      yield CrdtSyncScopeSet(scopes: announcedGrants);
      final peerScopeSet = await readFrame<CrdtSyncScopeSet>();
      if (peerScopeSet == null) {
        sessionCompleted = true;
        return;
      }
      var peerGrants = _sortedUniqueGrants(peerScopeSet.scopes);
      // Reconcile first so a follower materializes the announced scopes locally,
      // then project their roles into the members cache (projection needs the
      // scope row to exist).
      var activeScopeIds = _sortedUniqueScopeIds(
        await _orderedScopeIds(
          session,
          mode: mode,
          localScopeIds: [for (final g in announcedGrants) g.uuidScopeId],
          peerScopeIds: [for (final g in peerGrants) g.uuidScopeId],
        ),
      );
      if (mode == CrdtSyncPeerMode.follower) {
        await CrdtScopeMembership.projectFollowerMembership(
          session,
          userUuid: userId,
          grants: peerGrants,
        );
      }
      for (final scopeId in activeScopeIds) {
        yield await createSyncSinceHlc(session, userId: scopeId);
        final peerSinceHlc = await readFrame<CrdtSyncSinceHlc>();
        if (peerSinceHlc == null) {
          sessionCompleted = true;
          return;
        }
        _validateScopeFrame(
          frameName: 'CrdtSyncSinceHlc',
          expectedScopeId: scopeId,
          receivedScopeId: peerSinceHlc.uuidScopeId,
        );
        sinceHlcSentScopes.add(scopeId.uuid);
        peerNodeIdByScope[scopeId] = peerSinceHlc.localNodeId;
        checkpointsByScope[scopeId] = {
          for (final checkpoint in peerSinceHlc.nodeCheckpoints)
            checkpoint.nodeId: checkpoint,
        };
      }

      // === Data loop: one combined, idle-silent batch per cycle. `once` runs a
      // single cycle then closes; continuous loops, absorbing membership changes
      // as they are announced. ===
      while (true) {
        final localGrants = _sortedUniqueGrants(
          await _localScopeGrants(session, userId, mode),
        );
        activeScopeIds = _sortedUniqueScopeIds(
          await _orderedScopeIds(
            session,
            mode: mode,
            localScopeIds: [for (final g in localGrants) g.uuidScopeId],
            peerScopeIds: [for (final g in peerGrants) g.uuidScopeId],
          ),
        );
        final activeUuids = {for (final s in activeScopeIds) s.uuid};

        // Drop in-session state for scopes that left the active set, e.g. a
        // membership the authoritative peer revoked.
        sinceHlcSentScopes.removeWhere((uuid) => !activeUuids.contains(uuid));
        peerNodeIdByScope.removeWhere((s, _) => !activeUuids.contains(s.uuid));
        checkpointsByScope.removeWhere((s, _) => !activeUuids.contains(s.uuid));

        // ---- send phase: emit only what changed; track whether anything was
        // sent so the terminating end-of-batch (and idle silence) follow. ----
        var sentFrame = false;
        if (!_grantsEqual(announcedGrants, localGrants)) {
          yield CrdtSyncScopeSet(scopes: localGrants);
          announcedGrants = localGrants;
          sentFrame = true;
        }
        for (final scopeId in activeScopeIds) {
          if (sinceHlcSentScopes.add(scopeId.uuid)) {
            yield await createSyncSinceHlc(session, userId: scopeId);
            sentFrame = true;
          }
        }

        // Collect every handshaked scope's pending changes in one pass. A scope
        // with no peer checkpoint has not completed its handshake both ways, so
        // there is nothing to resume from for it yet.
        final checkpointsByScopeUuid = <UuidValue, List<Hlc>>{
          for (final scopeId in activeScopeIds)
            if (checkpointsByScope[scopeId] != null &&
                peerNodeIdByScope[scopeId] != null)
              scopeId: checkpointsByScope[scopeId]!.values.toList(),
        };
        final pendingByScope = <UuidValue, List<CrdtMergeChange>>{};
        await for (final (scopeId, change) in collectAllPendingChanges(
          session,
          checkpointsByScopeUuid: checkpointsByScopeUuid,
        )) {
          pendingByScope.putIfAbsent(scopeId, () => []).add(change);
        }

        final outboundScopes = <UuidValue>{};
        for (final entry in pendingByScope.entries) {
          final scopeId = entry.key;
          final changes = entry.value;
          final checkpoints = checkpointsByScope[scopeId]!;
          for (var start = 0; start < changes.length; start += _syncBatchSize) {
            final chunk = changes.sublist(
              start,
              min(start + _syncBatchSize, changes.length),
            );
            outboundScopes.add(scopeId);
            for (final change in chunk) {
              checkpoints[change.uuidNodeId] = change.hlc.maxBetween(
                checkpoints[change.uuidNodeId],
              );
            }
            yield CrdtSyncMergeChunk(uuidScopeId: scopeId, changes: chunk);
            sentFrame = true;
          }
        }

        // `once` always terminates so the peer's read returns promptly rather
        // than waiting out the idle timeout.
        if (sentFrame || once) yield CrdtSyncEndOfBatch();

        // ---- receive phase. `once` blocks for the terminator (the peer always
        // sends one); continuous lets an idle peer resolve to an empty batch. ----
        final batch = await _collectCycleBatch(
          inboundIterator,
          allowIdleReturn: !once,
        );
        if (batch == null) {
          sessionCompleted = true;
          return;
        }

        // ---- process phase ----
        if (batch.scopeSet != null) {
          peerGrants = _sortedUniqueGrants(batch.scopeSet!.scopes);
          if (mode == CrdtSyncPeerMode.follower) {
            // Materialize the announced scopes before projecting their roles
            // (projection needs the scope row); the next cycle's reconciliation
            // adopts them as active.
            await _orderedScopeIds(
              session,
              mode: mode,
              localScopeIds: [for (final g in localGrants) g.uuidScopeId],
              peerScopeIds: [for (final g in peerGrants) g.uuidScopeId],
            );
            await CrdtScopeMembership.projectFollowerMembership(
              session,
              userUuid: userId,
              grants: peerGrants,
            );
          }
        }

        // Only honor frames for scopes this peer authorizes: an authoritative
        // peer trusts its own membership, a follower trusts the announced set.
        // This is the wire-side counterpart of the server's membership gate.
        final acceptedUuids = mode == CrdtSyncPeerMode.follower
            ? {for (final g in peerGrants) g.uuidScopeId.uuid}
            : activeUuids;

        for (final entry in batch.sinceHlcs.entries) {
          if (!acceptedUuids.contains(entry.key.uuid)) continue;
          peerNodeIdByScope[entry.key] = entry.value.localNodeId;
          checkpointsByScope[entry.key] = {
            for (final checkpoint in entry.value.nodeCheckpoints)
              checkpoint.nodeId: checkpoint,
          };
        }

        final receivedHlcByScope = <UuidValue, Hlc?>{};
        for (final entry in batch.groups.entries) {
          final scopeId = entry.key;
          final peerNodeId = peerNodeIdByScope[scopeId];
          if (!acceptedUuids.contains(scopeId.uuid) || peerNodeId == null) {
            continue;
          }
          receivedHlcByScope[scopeId] = await mergeInboundBatch(
            session,
            userId: scopeId,
            otherNodeId: peerNodeId,
            mergeSet: entry.value,
          );
        }

        for (final scopeId in {...outboundScopes, ...receivedHlcByScope.keys}) {
          final checkpoints = checkpointsByScope[scopeId];
          if (checkpoints == null || checkpoints.isEmpty) continue;
          await onMergeSuccess?.call(
            scopeId,
            checkpoints.values.max.maxBetween(receivedHlcByScope[scopeId]),
          );
        }

        if (once) {
          yield CrdtSyncClose();
          await readFrame<CrdtSyncClose>();
          sessionCompleted = true;
          // Keep reading until the peer closes its side so the underlying
          // transport reaches "done" instead of being left paused; a paused
          // controller stalls teardown for the transport close timeout, landing
          // on the next round's critical path over a shared connection. The
          // drain runs detached: awaiting it would deadlock the symmetric close,
          // since the peer only closes once our outbound stream does, which
          // happens after this generator returns.
          unawaited(_drainUntilDone(inboundIterator));
          return;
        }

        await Future<void>.delayed(_continuousSyncInterval);
      }
    } finally {
      // Cancelling inbound on normal completion races with WebSocket stream
      // teardown and produces "connection closed" errors on the peer. On normal
      // completion the inbound is instead drained to "done" (see above). Keep
      // forced cancellation for abnormal exits so listener cancellation can
      // unblock.
      if (!sessionCompleted) {
        // Best-effort cleanup, since the transport will close the socket anyway.
        const waitTimeout = Duration(milliseconds: 200);
        await inboundIterator.cancel().timeout(waitTimeout, onTimeout: () {});
      }
    }
  }

  /// Drains [iterator] until the peer closes the stream.
  ///
  /// Used to settle the inbound transport after the `once` close handshake so
  /// its controller reaches "done" with an active listener instead of being
  /// torn down while paused. Trailing events (idle timeouts, late frames) are
  /// discarded; errors are swallowed since the transport is closing anyway.
  static Future<void> _drainUntilDone(
    StreamIterator<CrdtSyncStreamEvent> iterator,
  ) async {
    try {
      while (await iterator.moveNext()) {
        // Discard whatever the peer sends before it closes its side.
      }
    } on Object catch (_) {
      // Best-effort: the transport is shutting down.
    }
  }

  /// Resolves the local scope grants this peer announces in its
  /// [CrdtSyncScopeSet].
  ///
  /// Authoritative peers enumerate [CrdtScopeMembership.memberGrants] (with
  /// roles) from the shared membership table; followers announce every scope
  /// they hold (roles null); personal-only peers announce just their own scope.
  Future<List<CrdtScopeGrant>> _localScopeGrants(
    DatabaseSession session,
    UuidValue userId,
    CrdtSyncPeerMode mode,
  ) async {
    switch (mode) {
      case CrdtSyncPeerMode.authoritative:
        return CrdtScopeMembership.memberGrants(session, userId);
      case CrdtSyncPeerMode.follower:
        final manager = CrdtScopeManager(session);
        await manager.getOrCreate(userId);
        return [
          for (final scopeId in await manager.listScopeIds())
            CrdtScopeGrant(uuidScopeId: scopeId),
        ];
      case CrdtSyncPeerMode.personalOnly:
        await CrdtScopeManager(session).getOrCreate(userId);
        return [CrdtScopeGrant(uuidScopeId: userId)];
    }
  }

  /// Resolves the ordered lockstep scopes cycled this round.
  ///
  /// Authoritative and personal-only peers dictate their own set; followers
  /// adopt the peer's announced set, materializing each scope locally.
  Future<List<UuidValue>> _orderedScopeIds(
    DatabaseSession session, {
    required CrdtSyncPeerMode mode,
    required List<UuidValue> localScopeIds,
    required List<UuidValue> peerScopeIds,
  }) async {
    switch (mode) {
      case CrdtSyncPeerMode.authoritative:
      case CrdtSyncPeerMode.personalOnly:
        return localScopeIds;
      case CrdtSyncPeerMode.follower:
        final manager = CrdtScopeManager(session);
        final scopeIds = _sortedUniqueScopeIds(peerScopeIds);
        for (final scopeId in scopeIds) {
          await manager.getOrCreate(scopeId);
        }
        return scopeIds;
    }
  }

  void _validateScopeFrame({
    required String frameName,
    required UuidValue expectedScopeId,
    required UuidValue receivedScopeId,
  }) {
    if (receivedScopeId == expectedScopeId) return;
    throw CrdtSyncScopeMismatchException(
      frameName: frameName,
      receivedScopeId: receivedScopeId,
      expectedScopeId: expectedScopeId,
    );
  }

  void _validateSyncTablesHash(String syncTablesHash) {
    if (syncTablesHash != currentSyncTablesHash) {
      throw SyncTablesHashMismatchException(
        received: syncTablesHash,
        expected: currentSyncTablesHash,
      );
    }
  }

  CrdtDatabase _openCrdtDatabase(DatabaseSession session) {
    final db = session.db;
    // The wrapper is ephemeral and every operation performed on it lazily
    // ensures initialization, so there is nothing to eagerly initialize here.
    // Calling `initialize()` would re-run the per-session setup.
    return db is CrdtDatabase ? db : wrapDatabase(db);
  }

  Stream<(UuidValue, CrdtMergeChange)> _streamPendingChanges(
    DatabaseSession session,
    _PendingScopeContext context,
  ) async* {
    // Domain ownership is immutable while a collection runs, so read each
    // row's owner at most once across all three streams.
    final ownerCache = DomainRowOwnerCache();
    yield* _streamInserts(session, context, ownerCache);
    yield* _streamUpdates(session, context, ownerCache);
    yield* _streamDeletes(session, context, ownerCache);
  }

  Stream<(UuidValue, CrdtMergeInsert)> _streamInserts(
    DatabaseSession session,
    _PendingScopeContext context,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, context),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    final foreignKeyAttemptFieldsByRowId = await _loadProjectedForeignKeyAttemptFields(
      session,
      rows,
    );

    for (final row in rows) {
      final tableName = row.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final table = _syncTablesByName[tableName]!;
      final dartName = _classNamesByTableName[tableName];
      if (dartName == null) continue;

      final scopeId = row.scopeId;
      final scopeUuid = context.scopeUuidById[scopeId]!;

      final domainRow = await _fetchDomainRow(
        session,
        tableName,
        row.uuidRowId,
        table,
        dartName,
        foreignKeyAttemptFieldsByRowId[row.id!],
        scopeId,
        ownerCache,
      );
      if (!domainRow.exists) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: CrdtSyncViolationType.missingDomainRow,
          operation: CrdtSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerScopeId: null,
          incomingScopeUuid: scopeUuid,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }
      if (domainRow.ownerScopeId != scopeId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerScopeId: domainRow.ownerScopeId,
          incomingScopeUuid: scopeUuid,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }

      yield (
        scopeUuid,
        CrdtMergeInsert(
          hlcDatetime: row.hlcDatetime,
          hlcCounter: row.hlcCounter,
          tableName: tableName,
          uuidRowId: row.uuidRowId,
          uuidNodeId: row.node!.uuidNodeId,
          data: domainRow.row,
        ),
      );
    }
  }

  Stream<(UuidValue, CrdtMergeUpdate)> _streamUpdates(
    DatabaseSession session,
    _PendingScopeContext context,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, context),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
        foreignKey: CrdtDataForeignKey.include(),
      ),
    );

    for (final field in fields) {
      final tableName = field.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;
      if (field.hlcDatetime == field.row!.hlcDatetime &&
          field.hlcCounter == field.row!.hlcCounter &&
          field.nodeId == field.row!.nodeId) {
        continue;
      }

      final scopeId = field.row!.scopeId;
      final scopeUuid = context.scopeUuidById[scopeId]!;
      final columnName = field.column!.name;
      final columnValue = await _fetchOwnedColumnValue(
        session,
        tableName,
        field.row!.uuidRowId,
        columnName,
        field.foreignKey,
        scopeId,
        ownerCache,
      );
      if (!columnValue.exists) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: field.row!.id,
          type: CrdtSyncViolationType.missingDomainRow,
          operation: CrdtSyncViolationOperation.outboundUpdate,
          tableName: tableName,
          rowId: field.row!.uuidRowId,
          ownerScopeId: null,
          incomingScopeUuid: scopeUuid,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }
      if (columnValue.ownerScopeId != scopeId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: field.row!.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundUpdate,
          tableName: tableName,
          rowId: field.row!.uuidRowId,
          ownerScopeId: columnValue.ownerScopeId,
          incomingScopeUuid: scopeUuid,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }

      yield (
        scopeUuid,
        CrdtMergeUpdate(
          hlcDatetime: field.hlcDatetime,
          hlcCounter: field.hlcCounter,
          tableName: tableName,
          uuidRowId: field.row!.uuidRowId,
          uuidNodeId: field.node!.uuidNodeId,
          columnName: columnName,
          value: columnValue.value,
        ),
      );
    }
  }

  Stream<(UuidValue, CrdtMergeDelete)> _streamDeletes(
    DatabaseSession session,
    _PendingScopeContext context,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, context),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    for (final tombstone in tombstones) {
      if (!tombstone.reason.isSynced) continue;

      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final scopeId = tombstone.row!.scopeId;
      final scopeUuid = context.scopeUuidById[scopeId]!;
      final owner = await _readDomainRowOwner(
        session,
        tableName,
        tombstone.row!.uuidRowId,
        ownerCache,
      );
      if (owner.exists && owner.scopeId != scopeId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: tombstone.row!.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundDelete,
          tableName: tableName,
          rowId: tombstone.row!.uuidRowId,
          ownerScopeId: owner.scopeId,
          incomingScopeUuid: scopeUuid,
          uuidNodeId: tombstone.node!.uuidNodeId,
          hlc: tombstone.hlc,
        );
      }

      yield (
        scopeUuid,
        CrdtMergeDelete(
          hlcDatetime: tombstone.hlcDatetime,
          hlcCounter: tombstone.hlcCounter,
          tableName: tableName,
          uuidRowId: tombstone.row!.uuidRowId,
          uuidNodeId: tombstone.node!.uuidNodeId,
          clFlag: tombstone.clFlag,
          reason: tombstone.reason,
        ),
      );
    }
  }

  Expression _rowHlcAfterFilter(
    CrdtDataRowTable t,
    _PendingScopeContext context,
  ) =>
      t.scopeId.inSet(context.scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        context.nodeCheckpoints,
      );

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    _PendingScopeContext context,
  ) =>
      t.row.scopeId.inSet(context.scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        context.nodeCheckpoints,
      );

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    _PendingScopeContext context,
  ) =>
      t.row.scopeId.inSet(context.scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        context.nodeCheckpoints,
      );

  /// Loads a domain row for outbound insert sync.
  ///
  /// Reads the materialized row from the domain table, then swaps any FK columns
  /// with an active override back to [CrdtDataForeignKey.attemptedValue] before
  /// deserializing. This is the inverse of inbound FK materialization: the wire
  /// payload carries attempted facts, not locally projected visible values.
  Future<({bool exists, int? ownerScopeId, dynamic row})> _fetchDomainRow(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    Table table,
    String dartName,
    List<CrdtDataField>? foreignKeyAttemptFields,
    int scopeId,
    DomainRowOwnerCache ownerCache,
  ) async {
    final cols = table.columns
        .map((column) => '"${_escapeIdentifier(column.columnName)}"')
        .join(', ');
    final encodedRowId = ValueEncoder.instance.convert(rowId);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final escapedTableName = _escapeIdentifier(tableName);
    final result = await session.db.unsafeQuery(
      'SELECT $cols FROM "$escapedTableName" '
      'WHERE "id" = $encodedRowId AND "scopeId" = $encodedScopeId '
      'LIMIT 1',
    );
    if (result.isEmpty) {
      final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
      return (exists: owner.exists, ownerScopeId: owner.scopeId, row: null);
    }
    ownerCache[(tableName, rowId)] = (exists: true, scopeId: scopeId);

    final columnMap = result.first.toColumnMap()
      // Domain columns hold visible/materialized FK values; restore attempted
      // values for override columns before building the outbound merge payload.
      ..applyProjectedForeignKeyAttempts(foreignKeyAttemptFields)
      // scopeId is local ownership metadata; it is never emitted on the wire.
      ..remove('scopeId');

    final row = session.db.serializationManager.deserializeByClassName({
      'className': dartName,
      'data': columnMap,
    });
    return (exists: true, ownerScopeId: scopeId, row: row);
  }

  /// Resolves a column value for outbound update sync.
  ///
  /// When [projection] has an active override, returns the attempted value
  /// from [CrdtDataForeignKey.attemptedValue] instead of the materialized
  /// domain column value. Non-FK columns and FK columns without an override
  /// are read directly from the domain table.
  Future<({bool exists, int? ownerScopeId, dynamic value})> _fetchOwnedColumnValue(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    String columnName,
    CrdtDataForeignKey? projection,
    int scopeId,
    DomainRowOwnerCache ownerCache,
  ) async {
    if (projection != null && projection.hasOverride) {
      final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
      if (!owner.exists || owner.scopeId != scopeId) {
        return (exists: owner.exists, ownerScopeId: owner.scopeId, value: null);
      }
      return (
        exists: true,
        ownerScopeId: scopeId,
        value: _decodeColumnValue(tableName, columnName, projection.attemptedValue),
      );
    }

    final encodedValue = ValueEncoder.instance.convert(rowId);
    final encodedScopeId = ValueEncoder.instance.convert(scopeId);
    final escapedTableName = _escapeIdentifier(tableName);
    final result = await session.db.unsafeQuery(
      'SELECT "${_escapeIdentifier(columnName)}" '
      'FROM "$escapedTableName" '
      'WHERE "id" = $encodedValue AND "scopeId" = $encodedScopeId '
      'LIMIT 1',
    );
    if (result.isNotEmpty) {
      ownerCache[(tableName, rowId)] = (exists: true, scopeId: scopeId);
      return (
        exists: true,
        ownerScopeId: scopeId,
        value: _decodeColumnValue(tableName, columnName, result.first[0]),
      );
    }

    final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
    return (exists: owner.exists, ownerScopeId: owner.scopeId, value: null);
  }

  Future<DomainRowOwner> _readDomainRowOwner(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    DomainRowOwnerCache ownerCache,
  ) async {
    final cached = ownerCache[(tableName, rowId)];
    if (cached != null) return cached;

    final encodedValue = ValueEncoder.instance.convert(rowId);
    final escapedTableName = _escapeIdentifier(tableName);
    final result = await session.db.unsafeQuery(
      'SELECT "scopeId" FROM "$escapedTableName" '
      'WHERE "id" = $encodedValue '
      'LIMIT 1',
    );
    final owner = result.isEmpty
        ? (exists: false, scopeId: null)
        : (exists: true, scopeId: result.first[0] as int?);
    ownerCache[(tableName, rowId)] = owner;
    return owner;
  }

  Never _throwPendingIntegrityViolation({
    required int? crdtDataRowId,
    required CrdtSyncViolationType type,
    required CrdtSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required int? ownerScopeId,
    required UuidValue incomingScopeUuid,
    required UuidValue uuidNodeId,
    Hlc? hlc,
  }) {
    throw PendingOutboundIntegrityViolation(
      crdtDataRowId: crdtDataRowId,
      type: type,
      operation: operation,
      tableName: tableName,
      rowId: rowId,
      ownerScopeId: ownerScopeId,
      incomingScopeUuid: incomingScopeUuid,
      uuidNodeId: uuidNodeId,
      hlc: hlc,
    );
  }

  Future<Never> _recordAndThrowIntegrityViolation(
    DatabaseSession session,
    PendingOutboundIntegrityViolation pending,
  ) async {
    final ownerScopeUuid = await _scopeUuidForNormalizedId(
      session,
      pending.ownerScopeId,
    );
    final now = DateTime.now().toUtc();
    final violation = CrdtSyncIntegrityViolation(
      type: pending.type,
      domainTableName: pending.tableName,
      uuidRowId: pending.rowId,
      ownerScopeUuid: ownerScopeUuid,
      incomingScopeUuid: pending.incomingScopeUuid,
      operation: pending.operation,
      uuidNodeId: pending.uuidNodeId,
      crdtDataRowId: pending.crdtDataRowId,
      hlcDatetime: pending.hlc?.datetime,
      hlcCounter: pending.hlc?.counter,
      firstSeenAt: now,
      lastSeenAt: now,
      occurrences: 1,
    );
    final persisted = await recordCrdtSyncIntegrityViolation(
      session,
      violation: violation,
    );
    throw CrdtSyncIntegrityViolationException(persisted);
  }

  Future<UuidValue?> _scopeUuidForNormalizedId(
    DatabaseSession session,
    int? scopeId,
  ) async {
    if (scopeId == null) return null;

    final scope = await CrdtScope.db.findById(session, scopeId);
    return scope?.uuidScopeId;
  }

  /// Loads FK projection metadata for outbound insert sync.
  ///
  /// Returns only fields whose [CrdtDataForeignKey.overrideReason] is non-null,
  /// keyed by CRDT row id. These are the columns whose domain-table value
  /// differs from the durable attempted FK fact.
  Future<Map<int, List<CrdtDataField>>> _loadProjectedForeignKeyAttemptFields(
    DatabaseSession session,
    List<CrdtDataRow> rows,
  ) async {
    final rowIds = {for (final row in rows) ?row.id};
    if (rowIds.isEmpty) return {};

    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => t.rowId.inSet(rowIds) & t.foreignKey.overrideReason.notEquals(null),
      include: CrdtDataField.include(
        column: CrdtSchemaColumn.include(),
        foreignKey: CrdtDataForeignKey.include(),
      ),
    );

    final fieldsByRowId = <int, List<CrdtDataField>>{};
    for (final field in fields) {
      fieldsByRowId.putIfAbsent(field.rowId, () => []).add(field);
    }

    return fieldsByRowId;
  }

  dynamic _decodeColumnValue(String tableName, String columnName, Object? value) {
    if (value == null) return null;

    final definition = _columnDefinitionsByTableName[tableName]?[columnName];
    final dartType = definition?.dartType;
    if (dartType == null) return value;

    final className = _classNameForDartType(dartType);
    return switch (className) {
      'bool' || 'double' || 'int' || 'String' => value,
      _ => _serializationManager.deserializeByClassName({
        'className': className,
        'data': value,
      }),
    };
  }

  String _classNameForDartType(String dartType) {
    final withoutNullable = dartType.endsWith('?')
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
    return withoutNullable.split(':').last;
  }

  String _escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

  static String _computeCanonicalSyncTablesSignature(
    List<Table> syncTables, {
    required List<TableDefinition> tableDefinitions,
  }) {
    final tableDefinitionsByName = {
      for (final definition in tableDefinitions) definition.name: definition,
    };

    final sortedTables = syncTables.toList()
      ..sort((left, right) => left.tableName.compareTo(right.tableName));

    return sortedTables
        .map((table) {
          final definition = tableDefinitionsByName[table.tableName];
          final columns = [
            for (final column in definition?.columns ?? const <ColumnDefinition>[])
              if (column.name != 'scopeId') column.name,
            if (definition == null)
              for (final column in table.columns)
                if (column.columnName != 'scopeId') column.columnName,
          ]..sort();
          final foreignKeys = _canonicalForeignKeys(definition);
          final uniqueIndexes = _canonicalUniqueIndexes(definition);
          return '${table.tableName}:'
              '${columns.join(',')}|'
              'fk[${foreignKeys.join(';')}]|'
              'uq[${uniqueIndexes.join(';')}]';
        })
        .join(';');
  }

  static List<String> _canonicalForeignKeys(TableDefinition? definition) {
    if (definition == null) return const [];
    final entries = <String>[
      for (final fk in definition.foreignKeys)
        // Each foreign key must map all parameters.
        // ignore: no_adjacent_strings_in_list
        '${(fk.columns.toList()..sort()).join(',')}->'
            '${fk.referenceTableSchema}.${fk.referenceTable}'
            '(${(fk.referenceColumns.toList()..sort()).join(',')})'
            '|u:${fk.onUpdate?.toString() ?? '-'}'
            '|d:${fk.onDelete?.toString() ?? '-'}'
            '|m:${fk.matchType?.toString() ?? '-'}',
    ]..sort();

    return entries;
  }

  static List<String> _canonicalUniqueIndexes(TableDefinition? definition) {
    if (definition == null) return const [];

    final entries = <String>[
      for (final index in definition.indexes)
        if (index.isUnique && !index.isPrimary)
          () {
            final sortedElements = [
              for (final element in index.elements)
                '${element.type}:${element.definition}',
            ]..sort();
            return sortedElements.join(',');
          }(),
    ]..sort();

    return entries;
  }
}

extension on CrdtNodeTable {
  Expression afterAnyCheckpointFilter(
    ColumnUuid uuidNodeId,
    ColumnDateTime hlcDatetime,
    ColumnInt hlcCounter,
    List<Hlc> nodeCheckpoints,
  ) {
    if (nodeCheckpoints.isEmpty) return Constant.bool(true);

    final caseExpression = Case();
    for (final checkpoint in nodeCheckpoints) {
      caseExpression.when(
        uuidNodeId.equals(checkpoint.nodeId),
        then:
            (hlcDatetime > checkpoint.datetime) |
            (hlcDatetime.equals(checkpoint.datetime) &
                (hlcCounter > checkpoint.counter)),
      );
    }
    return caseExpression.orElse(Constant.bool(true));
  }
}

extension on Map<String, dynamic> {
  /// Replaces materialized FK column values with attempted values for sync.
  ///
  /// After local FK projection (for example `SET NULL` or `SET DEFAULT`), the
  /// domain table stores the safe visible value while
  /// [CrdtDataForeignKey.attemptedValue] preserves what was actually tried.
  /// Outbound sync must send the attempted value so peers can apply their own
  /// projection from the same fact.
  void applyProjectedForeignKeyAttempts(List<CrdtDataField>? foreignKeyAttemptFields) {
    if (foreignKeyAttemptFields == null) return;
    for (final field in foreignKeyAttemptFields) {
      final projection = field.foreignKey;
      if (projection == null || !projection.hasOverride) continue;
      this[field.column!.name] = projection.attemptedValue;
    }
  }
}

/// The scope set and combined checkpoint vector for one pending-change pass.
///
/// A single-scope pass holds one entry; a multi-scope pass
/// ([CrdtSync.collectAllPendingChanges]) unions every active scope's checkpoints
/// and bounds the queries to [scopeIds].
class _PendingScopeContext {
  _PendingScopeContext({
    required this.scopeIds,
    required this.scopeUuidById,
    required this.nodeCheckpoints,
  });

  /// Internal ids of the scopes the pass is bounded to (`scopeId IN (…)`).
  final Set<int> scopeIds;

  /// Maps each scope's internal id to its UUID, for chunk tagging and ownership.
  final Map<int, UuidValue> scopeUuidById;

  /// The unioned per-node checkpoints across every scope in the pass. Node ids
  /// are unique per scope, so the entries never collide.
  final List<Hlc> nodeCheckpoints;
}

/// One continuous-sync cycle's inbound frames, demultiplexed by type and scope.
class _CycleBatch {
  /// The peer's scope announcement for this cycle, if it sent one.
  CrdtSyncScopeSet? scopeSet;

  /// The peer's resume vectors, keyed by scope.
  final Map<UuidValue, CrdtSyncSinceHlc> sinceHlcs = {};

  /// The peer's merge changes for this cycle, grouped by scope.
  final Map<UuidValue, List<CrdtMergeChange>> groups = {};

  /// Whether the peer sent nothing this cycle (it was idle).
  bool get isEmpty => scopeSet == null && sinceHlcs.isEmpty && groups.isEmpty;
}

/// Collects one continuous-sync cycle's inbound frames until the terminating
/// [CrdtSyncEndOfBatch] or an idle timeout.
///
/// Returns the collected [_CycleBatch], an empty batch when the peer was idle
/// (it sent nothing this cycle, only honored if [allowIdleReturn]), or `null`
/// when the inbound stream closed.
///
/// An idle timeout only ends an *empty* cycle: once any frame has been collected
/// the timeout is ignored and collection waits for the explicit terminator, so a
/// peer's frames can never leak across cycle boundaries. With [allowIdleReturn]
/// false (the `once` round, where the peer always sends a terminator) idle
/// timeouts are ignored entirely and collection blocks for the terminator.
Future<_CycleBatch?> _collectCycleBatch(
  StreamIterator<CrdtSyncStreamEvent> inbound, {
  required bool allowIdleReturn,
}) async {
  final batch = _CycleBatch();
  while (await inbound.moveNext()) {
    switch (inbound.current) {
      case final CrdtSyncScopeSet event:
        batch.scopeSet = event;
      case final CrdtSyncSinceHlc event:
        batch.sinceHlcs[event.uuidScopeId] = event;
      case CrdtSyncMergeChunk(:final uuidScopeId, :final changes):
        batch.groups.putIfAbsent(uuidScopeId, () => []).addAll(changes);
      case CrdtSyncEndOfBatch():
        return batch;
      case CrdtSyncIdleTimeout():
        if (allowIdleReturn && batch.isEmpty) return batch;
      case CrdtSyncClose():
        return null;
      case final event:
        throw CrdtSyncUnexpectedEventException(
          expected: 'a sync cycle frame',
          received: event,
        );
    }
  }
  return null;
}
