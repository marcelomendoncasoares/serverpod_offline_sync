import 'dart:async';

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

/// Callback function for when a merge is successful.
typedef CrdtSyncOnMergeSuccess =
    FutureOr<void> Function(UuidValue scopeUuid, Hlc syncedHlc);

/// Resolves this peer's local scope set for the next sync cycle.
typedef CrdtSyncLocalScopeIdsResolver =
    FutureOr<List<UuidValue>> Function(DatabaseSession session, UuidValue userId);

/// Reconciles the local and peer scope sets into the ordered scopes to cycle.
typedef CrdtSyncOrderedScopeIdsResolver =
    FutureOr<List<UuidValue>> Function(
      DatabaseSession session, {
      required UuidValue userId,
      required List<UuidValue> localScopeIds,
      required List<UuidValue> peerScopeIds,
    });

/// Resolves scope membership and sync-cycle ordering for one peer.
class CrdtSyncScopeResolver {
  /// Creates a resolver from local-set and ordered-set callbacks.
  const CrdtSyncScopeResolver({
    required this.localScopeIds,
    required this.orderedScopeIds,
  });

  /// Personal-scope-only resolver used by low-level sync callers by default.
  factory CrdtSyncScopeResolver.personalOnly() {
    return CrdtSyncScopeResolver(
      localScopeIds: (session, userId) async {
        await CrdtScopeManager(session).getOrCreate(userId);
        return [userId];
      },
      orderedScopeIds:
          (
            session, {
            required userId,
            required localScopeIds,
            required peerScopeIds,
          }) {
            return _sortedUniqueScopeIds(localScopeIds);
          },
    );
  }

  /// Server-authoritative resolver backed by application membership state.
  factory CrdtSyncScopeResolver.authoritative(
    CrdtSyncLocalScopeIdsResolver memberScopeIds,
  ) {
    return CrdtSyncScopeResolver(
      localScopeIds: (session, userId) async {
        return _sortedUniqueScopeIds(await memberScopeIds(session, userId));
      },
      orderedScopeIds:
          (
            session, {
            required userId,
            required localScopeIds,
            required peerScopeIds,
          }) {
            return _sortedUniqueScopeIds(localScopeIds);
          },
    );
  }

  /// Client-side follower resolver that adopts the server's announced scopes.
  factory CrdtSyncScopeResolver.follower() {
    return CrdtSyncScopeResolver(
      localScopeIds: (session, userId) async {
        final manager = CrdtScopeManager(session);
        await manager.getOrCreate(userId);
        return _sortedUniqueScopeIds(await manager.listScopeIds());
      },
      orderedScopeIds:
          (
            session, {
            required userId,
            required localScopeIds,
            required peerScopeIds,
          }) async {
            final manager = CrdtScopeManager(session);
            final scopeIds = _sortedUniqueScopeIds(peerScopeIds);
            for (final scopeId in scopeIds) {
              await manager.getOrCreate(scopeId);
            }
            return scopeIds;
          },
    );
  }

  /// Computes the local scope ids sent in this peer's [CrdtSyncScopeSet].
  final CrdtSyncLocalScopeIdsResolver localScopeIds;

  /// Computes the ordered lockstep scope ids for the current cycle.
  final CrdtSyncOrderedScopeIdsResolver orderedScopeIds;
}

List<UuidValue> _sortedUniqueScopeIds(Iterable<UuidValue> scopeIds) {
  final byUuid = {for (final scopeId in scopeIds) scopeId.uuid: scopeId};
  return byUuid.values.toList()..sort((a, b) => a.uuid.compareTo(b.uuid));
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
    CrdtScopeMembershipValidator? scopeMembershipValidator,
    CrdtScopeMembershipResolver? scopeMembershipResolver,
  }) {
    if (database is CrdtDatabase) return database;
    return CrdtDatabase(
      database,
      syncTables: _syncTables,
      syncBatchSize: _syncBatchSize,
      continuousSyncInterval: _continuousSyncInterval,
      persistentUserId: persistentUserId,
      scopeMembershipValidator: scopeMembershipValidator,
      scopeMembershipResolver: scopeMembershipResolver,
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
    try {
      await for (final change in _streamPendingChanges(
        session,
        crdtUser,
        nodeCheckpoints,
      )) {
        yield change;
      }
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
  /// Both peers send [CrdtSyncConnect] once and validate the schema hash. Each
  /// cycle then exchanges [CrdtSyncScopeSet], reconciles to an ordered scope
  /// list through [scopeResolver], and runs today's send/receive/merge state
  /// machine once per scope. Sent changes advance the corresponding in-memory
  /// checkpoints for subsequent sends within the session.
  ///
  /// If a batch fails to merge, the exception propagates and the stream closes.
  /// The next sync attempt resumes from the last persisted checkpoint on the
  /// side that failed to merge.
  ///
  /// When [once] is true, each peer runs exactly one full scope cycle, sends a
  /// [CrdtSyncClose] frame and awaits for the other to send its closing event
  /// to complete the session.
  Stream<CrdtSyncStreamEvent> sync(
    DatabaseSession session, {
    required UuidValue userId,
    required Stream<CrdtSyncStreamEvent> inbound,
    bool once = false,
    CrdtSyncOnMergeSuccess? onMergeSuccess,
    CrdtSyncScopeResolver? scopeResolver,
  }) async* {
    final inboundIterator = StreamIterator(
      // Inject a timeout event if the inbound stream is idle for too long to
      // allow returning an empty batch and waiting for a change without closing
      // the stream.
      inbound.timeout(
        const Duration(seconds: 1),
        onTimeout: (sink) => sink.add(CrdtSyncIdleTimeout()),
      ),
    );

    final effectiveScopeResolver =
        scopeResolver ?? CrdtSyncScopeResolver.personalOnly();
    var sessionCompleted = false;
    try {
      yield CrdtSyncConnect(syncTablesHash: currentSyncTablesHash);

      final peerConnect = once
          ? await inboundIterator.moveAndThrowIfNot<CrdtSyncConnect>()
          : await inboundIterator.moveOrNullIfClosed<CrdtSyncConnect>();
      if (peerConnect == null) {
        sessionCompleted = true;
        return;
      }
      _validateSyncTablesHash(peerConnect.syncTablesHash);

      final nodeCheckpointsByScope = <UuidValue, Map<UuidValue, Hlc>>{};
      final peerNodeIdsByScope = <UuidValue, UuidValue>{};
      final handshakedScopeUuids = <String>{};

      while (true) {
        final localScopeIds = _sortedUniqueScopeIds(
          await effectiveScopeResolver.localScopeIds(session, userId),
        );
        yield CrdtSyncScopeSet(scopeIds: localScopeIds);

        final peerScopeSet = once
            ? await inboundIterator.moveAndThrowIfNot<CrdtSyncScopeSet>()
            : await inboundIterator.moveOrNullIfClosed<CrdtSyncScopeSet>();
        if (peerScopeSet == null) {
          sessionCompleted = true;
          return;
        }
        final orderedScopeIds = _sortedUniqueScopeIds(
          await effectiveScopeResolver.orderedScopeIds(
            session,
            userId: userId,
            localScopeIds: localScopeIds,
            peerScopeIds: peerScopeSet.scopeIds,
          ),
        );

        final activeScopeUuids = {
          for (final scopeId in orderedScopeIds) scopeId.uuid,
        };
        nodeCheckpointsByScope.removeWhere(
          (scopeId, _) => !activeScopeUuids.contains(scopeId.uuid),
        );
        peerNodeIdsByScope.removeWhere(
          (scopeId, _) => !activeScopeUuids.contains(scopeId.uuid),
        );
        handshakedScopeUuids.removeWhere(
          (scopeUuid) => !activeScopeUuids.contains(scopeUuid),
        );

        for (final scopeId in orderedScopeIds) {
          final scopeUuid = scopeId.uuid;
          if (!handshakedScopeUuids.contains(scopeUuid)) {
            yield await createSyncSinceHlc(session, userId: scopeId);

            final peerSinceHlc = once
                ? await inboundIterator.moveAndThrowIfNot<CrdtSyncSinceHlc>()
                : await inboundIterator.moveOrNullIfClosed<CrdtSyncSinceHlc>();
            if (peerSinceHlc == null) {
              sessionCompleted = true;
              return;
            }
            _validateScopeFrame(
              frameName: 'CrdtSyncSinceHlc',
              expectedScopeId: scopeId,
              receivedScopeId: peerSinceHlc.uuidScopeId,
            );

            peerNodeIdsByScope[scopeId] = peerSinceHlc.localNodeId;
            nodeCheckpointsByScope[scopeId] = {
              for (final checkpoint in peerSinceHlc.nodeCheckpoints)
                checkpoint.nodeId: checkpoint,
            };
            handshakedScopeUuids.add(scopeUuid);
          }

          final peerNodeId =
              peerNodeIdsByScope[scopeId] ??
              (throw StateError('Missing peer node id for scope $scopeId.'));
          final nodeCheckpoints = nodeCheckpointsByScope.putIfAbsent(
            scopeId,
            () => {},
          );

          final pendingLocalChanges = collectPendingChanges(
            session,
            userId: scopeId,
            peerNodeId: peerNodeId,
            nodeCheckpoints: nodeCheckpoints.values.toList(),
          );

          var hasChanges = false;
          await for (final changes in pendingLocalChanges.chunked(_syncBatchSize)) {
            hasChanges = true;
            for (final change in changes) {
              final lastCheckpoint = nodeCheckpoints[change.uuidNodeId];
              nodeCheckpoints[change.uuidNodeId] = change.hlc.maxBetween(
                lastCheckpoint,
              );
            }
            yield CrdtSyncMergeChunk(
              uuidScopeId: scopeId,
              changes: changes,
            );
          }
          yield CrdtSyncEndOfBatch();

          final inboundMergeSet = await inboundIterator.collectNextBatch(
            allowCloseBeforeBatch: !once,
            expectedScopeId: scopeId,
          );
          if (inboundMergeSet == null) {
            sessionCompleted = true;
            return;
          }

          final lastReceivedFromPeer = await mergeInboundBatch(
            session,
            userId: scopeId,
            otherNodeId: peerNodeId,
            mergeSet: inboundMergeSet,
          );

          if (hasChanges || inboundMergeSet.isNotEmpty) {
            await onMergeSuccess?.call(
              scopeId,
              nodeCheckpoints.values.max.maxBetween(lastReceivedFromPeer),
            );
          }
        }

        if (once) {
          yield CrdtSyncClose();
          await inboundIterator.moveAndThrowIfNot<CrdtSyncClose>();
          sessionCompleted = true;
          // Keep reading until the peer closes its side so the underlying
          // transport subscription reaches "done" instead of being left paused.
          // A paused inbound controller stalls the peer's stream teardown for
          // several seconds (the transport's close timeout), which lands on the
          // critical path of the next sync round over a shared connection.
          //
          // The drain runs detached: awaiting it here would deadlock the
          // symmetric close handshake, since the peer only closes its side once
          // our own outbound stream closes, which happens after this generator
          // returns.
          unawaited(_drainUntilDone(inboundIterator));
          return;
        }

        // Wait once per full scope cycle before checking for local changes again.
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

  Stream<CrdtMergeChange> _streamPendingChanges(
    DatabaseSession session,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
  ) async* {
    // Domain ownership is immutable while a collection runs, so read each
    // row's owner at most once across all three streams.
    final ownerCache = DomainRowOwnerCache();
    yield* _streamInserts(session, crdtUser, nodeCheckpoints, ownerCache);
    yield* _streamUpdates(session, crdtUser, nodeCheckpoints, ownerCache);
    yield* _streamDeletes(session, crdtUser, nodeCheckpoints, ownerCache);
  }

  Stream<CrdtMergeInsert> _streamInserts(
    DatabaseSession session,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, crdtUser, nodeCheckpoints),
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

      final domainRow = await _fetchDomainRow(
        session,
        tableName,
        row.uuidRowId,
        table,
        dartName,
        foreignKeyAttemptFieldsByRowId[row.id!],
        crdtUser.id!,
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
          incomingScopeUuid: crdtUser.uuidScopeId,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }
      if (domainRow.ownerScopeId != crdtUser.id) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerScopeId: domainRow.ownerScopeId,
          incomingScopeUuid: crdtUser.uuidScopeId,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }

      yield CrdtMergeInsert(
        hlcDatetime: row.hlcDatetime,
        hlcCounter: row.hlcCounter,
        tableName: tableName,
        uuidRowId: row.uuidRowId,
        uuidNodeId: row.node!.uuidNodeId,
        data: domainRow.row,
      );
    }
  }

  Stream<CrdtMergeUpdate> _streamUpdates(
    DatabaseSession session,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, crdtUser, nodeCheckpoints),
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

      final columnName = field.column!.name;
      final columnValue = await _fetchOwnedColumnValue(
        session,
        tableName,
        field.row!.uuidRowId,
        columnName,
        field.foreignKey,
        crdtUser.id!,
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
          incomingScopeUuid: crdtUser.uuidScopeId,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }
      if (columnValue.ownerScopeId != crdtUser.id) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: field.row!.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundUpdate,
          tableName: tableName,
          rowId: field.row!.uuidRowId,
          ownerScopeId: columnValue.ownerScopeId,
          incomingScopeUuid: crdtUser.uuidScopeId,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }

      yield CrdtMergeUpdate(
        hlcDatetime: field.hlcDatetime,
        hlcCounter: field.hlcCounter,
        tableName: tableName,
        uuidRowId: field.row!.uuidRowId,
        uuidNodeId: field.node!.uuidNodeId,
        columnName: columnName,
        value: columnValue.value,
      );
    }
  }

  Stream<CrdtMergeDelete> _streamDeletes(
    DatabaseSession session,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, crdtUser, nodeCheckpoints),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    for (final tombstone in tombstones) {
      if (!tombstone.reason.isSynced) continue;

      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;
      final owner = await _readDomainRowOwner(
        session,
        tableName,
        tombstone.row!.uuidRowId,
        ownerCache,
      );
      if (owner.exists && owner.scopeId != crdtUser.id) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: tombstone.row!.id,
          type: CrdtSyncViolationType.ownershipCollision,
          operation: CrdtSyncViolationOperation.outboundDelete,
          tableName: tableName,
          rowId: tombstone.row!.uuidRowId,
          ownerScopeId: owner.scopeId,
          incomingScopeUuid: crdtUser.uuidScopeId,
          uuidNodeId: tombstone.node!.uuidNodeId,
          hlc: tombstone.hlc,
        );
      }

      yield CrdtMergeDelete(
        hlcDatetime: tombstone.hlcDatetime,
        hlcCounter: tombstone.hlcCounter,
        tableName: tableName,
        uuidRowId: tombstone.row!.uuidRowId,
        uuidNodeId: tombstone.node!.uuidNodeId,
        clFlag: tombstone.clFlag,
        reason: tombstone.reason,
      );
    }
  }

  Expression _rowHlcAfterFilter(
    CrdtDataRowTable t,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.scopeId.equals(crdtUser.id) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        nodeCheckpoints,
      );

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.row.scopeId.equals(crdtUser.id) &
      t.node.afterAnyCheckpointFilter(
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        nodeCheckpoints,
      );

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    CrdtScope crdtUser,
    List<Hlc> nodeCheckpoints,
  ) =>
      t.row.scopeId.equals(crdtUser.id) &
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
