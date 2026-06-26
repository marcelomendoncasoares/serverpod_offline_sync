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
import 'scope_sync.dart';

export 'scope_sync.dart' show CrdtSyncPeerMode;

/// Callback function for when a merge is successful.
typedef CrdtSyncOnMergeSuccess =
    FutureOr<void> Function(UuidValue scopeUuid, Hlc syncedHlc);

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
  CrdtDatabase wrapDatabase(Database database, {UuidValue? persistentUserId}) {
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
    final scopeUuidById = {crdtUser.id!: crdtUser.uuidScopeId};
    try {
      await for (final (_, change) in _streamPendingChanges(
        session,
        scopeUuidById,
        nodeCheckpoints,
      )) {
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
    final scopeUuidById = {
      for (final scope in scopes) scope.id!: scope.uuidScopeId,
    };
    final nodeCheckpoints = [
      for (final checkpoints in checkpointsByScopeUuid.values) ...checkpoints,
    ];

    try {
      yield* _streamPendingChanges(session, scopeUuidById, nodeCheckpoints);
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
  /// nothing was sent. The receive phase (`collectCycleBatch`) demultiplexes the
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
    final scopes = CrdtScopeSyncSession(session, userId: userId, mode: mode);

    var sessionCompleted = false;
    try {
      yield CrdtSyncConnect(syncTablesHash: currentSyncTablesHash);
      final peerConnect = await inboundIterator.nextFrame<CrdtSyncConnect>(
        throwIfClosed: once,
      );
      if (peerConnect == null) {
        sessionCompleted = true;
        return;
      }
      _validateSyncTablesHash(peerConnect.syncTablesHash);

      // === Establishment: exchange the scope set in lockstep so a follower
      // learns the agreed set before the loop's send phase (otherwise it would
      // act before knowing its scopes). Active scopes are recomputed from the
      // grants just exchanged, not a fresh read, so both peers agree on the
      // set even if a membership change lands mid-handshake. ===
      await scopes.reconcile();
      yield CrdtSyncScopeSet(scopes: scopes.localGrants);
      scopes.markAnnounced();
      final peerScopeSet = await inboundIterator.nextFrame<CrdtSyncScopeSet>(
        throwIfClosed: once,
      );
      if (peerScopeSet == null) {
        sessionCompleted = true;
        return;
      }
      await scopes.adoptPeerGrants(peerScopeSet.scopes);

      // `once` must also handshake every scope synchronously, so its single data
      // cycle below already has each scope's checkpoint. Continuous handshakes
      // lazily in the loop (one combined batch), so it skips this.
      if (once) {
        for (final scopeId in scopes.activeScopeIds) {
          yield await createSyncSinceHlc(session, userId: scopeId);
          scopes.markHandshakeSent(scopeId);
          final peerSinceHlc = await inboundIterator
              .nextFrame<CrdtSyncSinceHlc>(throwIfClosed: once);
          if (peerSinceHlc == null) {
            sessionCompleted = true;
            return;
          }
          _validateScopeFrame(
            frameName: 'CrdtSyncSinceHlc',
            expectedScopeId: scopeId,
            receivedScopeId: peerSinceHlc.uuidScopeId,
          );
          scopes.recordPeerHandshake(scopeId, peerSinceHlc);
        }
      }

      // === Data loop: one combined, idle-silent batch per cycle. `once` runs a
      // single cycle then closes; continuous loops, handshaking newly active
      // scopes and absorbing membership changes as they are announced. ===
      while (true) {
        await scopes.reconcile();

        // ---- send phase: emit only what changed; track whether anything was
        // sent so the terminating end-of-batch (and idle silence) follow. ----
        var sentFrame = false;
        if (scopes.shouldAnnounce) {
          yield CrdtSyncScopeSet(scopes: scopes.localGrants);
          scopes.markAnnounced();
          sentFrame = true;
        }
        for (final scopeId in scopes.activeScopeIds) {
          if (scopes.markHandshakeSent(scopeId)) {
            yield await createSyncSinceHlc(session, userId: scopeId);
            sentFrame = true;
          }
        }
        final outboundScopes = <UuidValue>{};
        await for (final (scopeId, chunk) in _outboundChunks(session, scopes)) {
          outboundScopes.add(scopeId);
          yield CrdtSyncMergeChunk(uuidScopeId: scopeId, changes: chunk);
          sentFrame = true;
        }

        // `once` always terminates so the peer's read returns promptly rather
        // than waiting out the idle timeout.
        if (sentFrame || once) yield CrdtSyncEndOfBatch();

        // ---- receive phase. `once` blocks for the terminator (the peer always
        // sends one); continuous lets an idle peer resolve to an empty batch. ----
        final batch = await inboundIterator.collectCycleBatch(
          allowIdleReturn: !once,
        );
        if (batch == null) {
          sessionCompleted = true;
          return;
        }

        // ---- process phase: adopt announcements, record handshakes, and merge
        // each scope's group — but only for scopes this peer authorizes. ----
        if (batch.scopeSet != null) {
          await scopes.adoptPeerGrants(batch.scopeSet!.scopes);
        }
        for (final entry in batch.sinceHlcs.entries) {
          if (scopes.accepts(entry.key)) {
            scopes.recordPeerHandshake(entry.key, entry.value);
          }
        }
        final mergedScopes = <UuidValue>{};
        for (final entry in batch.groups.entries) {
          final scopeId = entry.key;
          final peerNodeId = scopes.peerNodeIdOf(scopeId);
          if (!scopes.accepts(scopeId) || peerNodeId == null) continue;
          mergedScopes.add(scopeId);
          final receivedHlc = await mergeInboundBatch(
            session,
            userId: scopeId,
            otherNodeId: peerNodeId,
            mergeSet: entry.value,
          );
          await _reportMerge(onMergeSuccess, scopes, scopeId, receivedHlc);
        }
        // Scopes we sent but the peer was silent on still merged this cycle.
        for (final scopeId in outboundScopes.difference(mergedScopes)) {
          await _reportMerge(onMergeSuccess, scopes, scopeId, null);
        }

        if (once) {
          yield CrdtSyncClose();
          await inboundIterator.nextFrame<CrdtSyncClose>(throwIfClosed: true);
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

  /// Streams this cycle's outbound merge changes as `(scope, chunk)` pairs.
  ///
  /// Collects every handshaked scope's pending changes in one pass
  /// ([collectAllPendingChanges] over [CrdtScopeSyncSession.sendableCheckpoints]),
  /// slices each scope's changes into [_syncBatchSize] chunks, and advances the
  /// scope's in-session checkpoint past each chunk so the next cycle does not
  /// resend it.
  Stream<(UuidValue, List<CrdtMergeChange>)> _outboundChunks(
    DatabaseSession session,
    CrdtScopeSyncSession scopes,
  ) async* {
    final pendingByScope = <UuidValue, List<CrdtMergeChange>>{};
    await for (final (scopeId, change) in collectAllPendingChanges(
      session,
      checkpointsByScopeUuid: scopes.sendableCheckpoints,
    )) {
      pendingByScope.putIfAbsent(scopeId, () => []).add(change);
    }

    for (final entry in pendingByScope.entries) {
      final scopeId = entry.key;
      final changes = entry.value;
      for (var start = 0; start < changes.length; start += _syncBatchSize) {
        final chunk = changes.sublist(
          start,
          min(start + _syncBatchSize, changes.length),
        );
        for (final change in chunk) {
          scopes.advanceCheckpoint(scopeId, change);
        }
        yield (scopeId, chunk);
      }
    }
  }

  /// Reports a successful merge for [scopeId] to [onMergeSuccess], combining the
  /// scope's checkpoint high-water mark with the [receivedHlc] just merged.
  Future<void> _reportMerge(
    CrdtSyncOnMergeSuccess? onMergeSuccess,
    CrdtScopeSyncSession scopes,
    UuidValue scopeId,
    Hlc? receivedHlc,
  ) async {
    final checkpointMax = scopes.checkpointMaxOf(scopeId);
    if (checkpointMax == null) return;
    await onMergeSuccess?.call(scopeId, checkpointMax.maxBetween(receivedHlc));
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
    Map<int, UuidValue> scopeUuidById,
    List<Hlc> nodeCheckpoints,
  ) async* {
    // Domain ownership is immutable while a collection runs, so read each
    // row's owner at most once across all three streams.
    final ownerCache = DomainRowOwnerCache();
    yield* _streamInserts(session, scopeUuidById, nodeCheckpoints, ownerCache);
    yield* _streamUpdates(session, scopeUuidById, nodeCheckpoints, ownerCache);
    yield* _streamDeletes(session, scopeUuidById, nodeCheckpoints, ownerCache);
  }

  Stream<(UuidValue, CrdtMergeInsert)> _streamInserts(
    DatabaseSession session,
    Map<int, UuidValue> scopeUuidById,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final scopeIds = scopeUuidById.keys.toSet();
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, scopeIds, nodeCheckpoints),
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
      final scopeUuid = scopeUuidById[scopeId]!;

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
    Map<int, UuidValue> scopeUuidById,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final scopeIds = scopeUuidById.keys.toSet();
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, scopeIds, nodeCheckpoints),
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
      final scopeUuid = scopeUuidById[scopeId]!;
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
    Map<int, UuidValue> scopeUuidById,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final scopeIds = scopeUuidById.keys.toSet();
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, scopeIds, nodeCheckpoints),
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
      final scopeUuid = scopeUuidById[scopeId]!;
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
    Set<int> scopeIds,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.scopeId.inSet(scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        nodeCheckpoints,
      );

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    Set<int> scopeIds,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.row.scopeId.inSet(scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        nodeCheckpoints,
      );

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    Set<int> scopeIds,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.row.scopeId.inSet(scopeIds) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        nodeCheckpoints,
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
