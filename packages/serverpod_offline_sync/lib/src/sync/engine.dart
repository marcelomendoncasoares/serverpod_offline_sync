import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../database/database.dart';
import '../database/merge_utils/database_helpers.dart';
import '../database/recorder.dart';
import '../database/unique_index_utils.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../managers/space.dart';
import '../spaces/membership.dart';
import '../utils/case_when.dart' show Case;
import 'exceptions.dart';
import 'integrity_violation.dart';
import 'space_state.dart';

export 'space_state.dart' show OfflineSyncPeerMode;

/// Callback function for when a merge is successful.
typedef OfflineSyncOnMergeSuccess =
    FutureOr<void> Function(UuidValue spaceUuid, Hlc syncedHlc);

/// A tuple representing the ownership of a domain row.
typedef DomainRowOwner = ({bool exists, int? spaceId});

/// A cache of domain row owners by table name and row id.
typedef DomainRowOwnerCache = Map<(String, UuidValue), DomainRowOwner>;

/// The shared CRDT synchronization logic used by both client and server nodes.
class OfflineSyncEngine {
  /// Creates a new [OfflineSyncEngine] instance.
  OfflineSyncEngine({
    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The serialization manager to use for deserializing merge changes.
    required DatabaseSerializationManager serializationManager,

    /// Shared CRDT database metadata.
    OfflineSyncDatabaseContext? databaseContext,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    this._continuousSyncInterval = defaultContinuousSyncInterval,
  }) : _syncTables = syncTables,
       _serializationManager = serializationManager,
       _databaseContext =
           databaseContext ??
           OfflineSyncDatabaseContext(
             syncTables: syncTables,
             serializationManager: serializationManager,
           ),
       _syncBatchSize = syncBatchSize {
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
  final OfflineSyncDatabaseContext _databaseContext;
  final int _syncBatchSize;
  final Duration _continuousSyncInterval;

  /// Wraps [database] in a CRDT-aware database using this sync context.
  OfflineSyncDatabase wrapDatabase(Database database, {UuidValue? persistentUserId}) {
    if (database is OfflineSyncDatabase) return database;
    return OfflineSyncDatabase(
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

  /// Streams pending changes for every space in [checkpointsBySpaceUuid].
  ///
  /// Changes are emitted in insert, update, then delete order. Domain row and
  /// column payloads are resolved incrementally as each change is yielded.
  ///
  /// Foreign-key columns with an active projection override are sent with their
  /// durable [CrdtDataAttemptedValue.value], not the visible value stored
  /// in the domain table. Peers need the attempted fact to converge; local FK
  /// projection materializes only the safe visible value into domain tables.
  ///
  /// Resolves the spaces' internal ids once and keeps their checkpoint vectors
  /// scoped by those internal ids. Node ids are stable per replica and may
  /// appear in multiple spaces, so checkpoint filtering must compare both
  /// `spaceId` and `uuidNodeId`. This still runs one query per change kind for
  /// the whole pass. Per-row ownership and integrity checks resolve against
  /// each row's own space.
  ///
  /// All changes for nodes that are not present in a space's checkpoint list
  /// are collected and emitted. Passing an empty list for a space will collect
  /// all of its changes. Each change carries its [CrdtMergeChange.uuidSpaceId].
  Stream<CrdtMergeChange> collectPendingChanges(
    DatabaseSession session, {
    required Map<UuidValue, List<Hlc>> checkpointsBySpaceUuid,
  }) async* {
    if (checkpointsBySpaceUuid.isEmpty) return;

    final spaces = await OfflineSyncSpace.db.find(
      session,
      where: (t) => t.uuidSpaceId.inSet(checkpointsBySpaceUuid.keys.toSet()),
    );
    final spaceUuidById = {
      for (final space in spaces) space.id!: space.uuidSpaceId,
    };
    final checkpointsBySpaceId = {
      for (final space in spaces)
        space.id!: checkpointsBySpaceUuid[space.uuidSpaceId] ?? const <Hlc>[],
    };

    try {
      await for (final change in _streamPendingChanges(
        session,
        spaceUuidById,
        checkpointsBySpaceId,
      )) {
        yield change;
      }
    } on PendingOutboundIntegrityViolation catch (violation) {
      await _recordAndThrowIntegrityViolation(session, violation);
    }
  }

  /// Creates the [OfflineSyncSinceHlc] checkpoint for a space handshake.
  ///
  /// [OfflineSyncSinceHlc.nodeCheckpoints] reflects the latest change this node
  /// has received from each known node, tagged with the source node id.
  Future<OfflineSyncSinceHlc> createSyncSinceHlc(
    DatabaseSession session, {
    required UuidValue spaceId,
  }) async {
    final space = await OfflineSyncSpaceManager(session).getOrCreate(spaceId);
    final localNodeId = space.currentNode!.uuidNodeId;

    final spaceNodes = await OfflineSyncSpaceNode.db.find(
      session,
      where: (t) =>
          t.spaceId.equals(space.id) & t.nodeId.notEquals(space.currentNodeId),
      include: OfflineSyncSpaceNode.include(node: CrdtNode.include()),
    );

    return OfflineSyncSinceHlc(
      uuidSpaceId: spaceId,
      nodeCheckpoints: [
        // The local node is always included to avoid collecting its own changes.
        Hlc.now(localNodeId),
        for (final spaceNode in spaceNodes)
          spaceNode.lastReceivedHlc ?? Hlc.zero(spaceNode.node!.uuidNodeId),
      ],
    );
  }

  /// Merges a remote [mergeSet] and records the sync checkpoint for [otherNodeId].
  ///
  /// Inbound merge applies each remote change, then materializes foreign-key
  /// projection into domain tables via [OfflineSyncDatabase.mergeChanges].
  ///
  /// Throws if the merge fails. The sync stream should be closed so the next
  /// attempt resumes from the last persisted checkpoint.
  ///
  /// Returns the greatest HLC synced in the batch, or `null` if the batch is
  /// empty.
  Future<Hlc?> _mergeInboundBatch(
    DatabaseSession session, {
    required UuidValue spaceId,
    required UuidValue otherNodeId,
    required CrdtMergeSet mergeSet,
  }) async {
    if (mergeSet.isEmpty) return null;
    final maxSyncedHlc = mergeSet.maxHlc;
    final offlineSyncDb = _openOfflineSyncDatabase(session);
    await offlineSyncDb.mergeChanges(mergeSet, spaceId: spaceId);
    if (maxSyncedHlc != null) {
      await offlineSyncDb.recordSyncCheckpoint(
        otherNodeId,
        maxSyncedHlc,
        userId: spaceId,
      );
    }
    return maxSyncedHlc;
  }

  /// Runs a symmetric CRDT sync session over a bidirectional event stream.
  ///
  /// Both peers exchange [OfflineSyncConnect] and a lockstep [OfflineSyncSpaceSet]
  /// before the data loop. Each cycle sends a combined batch — space
  /// announcement when grants changed, [OfflineSyncSinceHlc] for newly active
  /// spaces, and [OfflineSyncMergeChunk]s — closed by [OfflineSyncEndOfBatch] when
  /// anything was sent. Inbound frames are de-multiplexed by collectNextBatch
  /// until [OfflineSyncEndOfBatch] when this peer sent a batch, or an idle timeout
  /// when both peers had nothing to send.
  ///
  /// When [once] is true the loop may run an extra cycle after handshakes
  /// complete so merge data can flow; then it closes symmetrically. Continuous
  /// mode loops with [_continuousSyncInterval] between idle cycles.
  Stream<OfflineSyncStreamEvent> sync(
    DatabaseSession session, {
    required UuidValue userId,
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) async* {
    // Idle timeouts are a continuous-only affordance: they let an idle cycle
    // settle into an empty batch without closing the stream. A `once` session
    // is strictly lockstep — every batch ends with a [OfflineSyncEndOfBatch] and
    // the session with a [OfflineSyncClose] — so it must wait for those end frames
    // rather than truncate a slow peer's batch on a timeout.
    final inboundIterator = StreamIterator(
      once
          ? inbound
          : inbound.timeout(
              const Duration(seconds: 1),
              onTimeout: (sink) => sink.add(OfflineSyncIdleTimeout()),
            ),
    );

    var sessionCompleted = false;
    try {
      final space = await OfflineSyncSpaceManager(session).getOrCreate(userId);
      final localNodeId = space.currentNode!.uuidNodeId;
      yield OfflineSyncConnect(
        localNodeId: localNodeId,
        syncTablesHash: currentSyncTablesHash,
      );

      final peerConnect = await inboundIterator.moveAndThrowIfNot<OfflineSyncConnect>();
      _validateSyncTablesHash(peerConnect.syncTablesHash);

      final spaces = OfflineSyncSpaceState(
        session,
        userId: userId,
        mode: mode,
        peerNodeId: peerConnect.localNodeId,
      );

      await spaces.reconcile();
      yield OfflineSyncSpaceSet(spaces: spaces.localGrants);
      spaces.markAnnounced();
      final peerSpaceSet = await inboundIterator
          .moveAndThrowIfNot<OfflineSyncSpaceSet>();
      await spaces.adoptPeerGrants(peerSpaceSet.spaces);

      while (true) {
        await spaces.reconcile();

        final hadSendableCheckpoints = spaces.sendableCheckpoints.isNotEmpty;
        var hasChanges = false;
        final outboundSpaces = <UuidValue>{};

        if (spaces.shouldAnnounce) {
          yield OfflineSyncSpaceSet(spaces: spaces.localGrants);
          spaces.markAnnounced();
          hasChanges = true;
        }

        for (final spaceId in spaces.activeSpaceIds) {
          if (!spaces.markHandshakeSent(spaceId)) continue;
          yield await createSyncSinceHlc(session, spaceId: spaceId);
          hasChanges = true;
        }

        final pendingLocalChanges = collectPendingChanges(
          session,
          checkpointsBySpaceUuid: spaces.sendableCheckpoints,
        );

        await for (final changes in pendingLocalChanges.chunked(_syncBatchSize)) {
          hasChanges = true;
          for (final change in changes) {
            spaces.advanceCheckpoint(change.uuidSpaceId, change);
            outboundSpaces.add(change.uuidSpaceId);
          }
          yield OfflineSyncMergeChunk(changes: changes);
        }
        if (hasChanges || once) {
          yield OfflineSyncEndOfBatch();
        }

        final batch = await inboundIterator.collectNextBatch(
          allowCloseBeforeBatch: !once,
        );
        if (batch == null) {
          if (once) {
            yield OfflineSyncClose();
          }
          sessionCompleted = true;
          return;
        }

        await _applyCycleBatch(
          session,
          spaces,
          batch,
          outboundSpaces,
          onMergeSuccess,
        );

        if (once) {
          if (spaces.hasIncompleteActiveHandshake) {
            continue;
          }
          if (!hadSendableCheckpoints && spaces.sendableCheckpoints.isNotEmpty) {
            continue;
          }
          yield OfflineSyncClose();
          await inboundIterator.moveAndThrowIfNot<OfflineSyncClose>();
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

        // Wait for the configured interval before checking for local changes again.
        await Future<void>.delayed(_continuousSyncInterval);
      }
    } on OfflineSyncStreamClosedException {
      // A continuous session ending is normal: the peer closed its outbound
      // (typically a cancel). Whether the stream closed between batches or
      // mid-batch, nothing is left to do — complete gracefully so the `finally`
      // skips the force-cancel that races WebSocket teardown and surfaces
      // spurious "connection closed" errors on the peer. A `once` session has a
      // completion contract (full handshake plus the symmetric Close), so a
      // close before that is a real truncation and must propagate.
      if (once) rethrow;
      sessionCompleted = true;
      return;
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

  Future<void> _applyCycleBatch(
    DatabaseSession session,
    OfflineSyncSpaceState spaces,
    OfflineSyncCycleBatch batch,
    Set<UuidValue> outboundSpaces,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  ) async {
    if (batch.spaceSet != null) {
      await spaces.adoptPeerGrants(batch.spaceSet!.spaces);
    }
    for (final entry in batch.sinceHlcs.entries) {
      if (spaces.accepts(entry.key)) {
        spaces.recordPeerHandshake(entry.key, entry.value);
      }
    }

    final mergedSpaces = <UuidValue>{};
    final changesBySpace = <UuidValue, List<CrdtMergeChange>>{};
    for (final change in batch.changes) {
      changesBySpace.putIfAbsent(change.uuidSpaceId, () => []).add(change);
    }
    for (final entry in changesBySpace.entries) {
      final spaceId = entry.key;
      if (!spaces.accepts(spaceId)) continue;
      mergedSpaces.add(spaceId);
      if (spaces.isAuthoritative) {
        await _assertCanMergeInboundSpace(
          session,
          spaceId: spaceId,
          userId: spaces.userId,
          changes: entry.value,
        );
      }
      final receivedHlc = await _mergeInboundBatch(
        session,
        spaceId: spaceId,
        otherNodeId: spaces.peerNodeId,
        mergeSet: entry.value,
      );
      await _reportMerge(onMergeSuccess, spaces, spaceId, receivedHlc);
    }
    for (final spaceId in outboundSpaces.difference(mergedSpaces)) {
      await _reportMerge(onMergeSuccess, spaces, spaceId, null);
    }
  }

  Future<void> _assertCanMergeInboundSpace(
    DatabaseSession session, {
    required UuidValue spaceId,
    required UuidValue userId,
    required List<CrdtMergeChange> changes,
  }) async {
    if (changes.isEmpty || userId == spaceId) return;

    final role = await OfflineSyncSpaceMembership.roleOf(
      session,
      userUuid: userId,
      spaceUuid: spaceId,
    );
    if (role.canWrite) return;

    final firstChange = changes.first;
    final now = clock.now().toUtc();
    final violation = OfflineSyncIntegrityViolation(
      type: OfflineSyncViolationType.unauthorizedWrite,
      domainTableName: firstChange.tableName,
      uuidRowId: firstChange.uuidRowId,
      ownerSpaceUuid: null,
      incomingSpaceUuid: spaceId,
      operation: _operationForInboundChange(firstChange),
      uuidNodeId: firstChange.uuidNodeId,
      crdtDataRowId: null,
      hlcDatetime: firstChange.hlcDatetime,
      hlcCounter: firstChange.hlcCounter,
      firstSeenAt: now,
      lastSeenAt: now,
      occurrences: 1,
    );
    final persisted = await recordOfflineSyncIntegrityViolation(
      session,
      violation: violation,
    );
    throw OfflineSyncIntegrityViolationException(persisted);
  }

  OfflineSyncViolationOperation _operationForInboundChange(CrdtMergeChange change) {
    return switch (change) {
      CrdtMergeInsert() => OfflineSyncViolationOperation.mergeInsert,
      CrdtMergeUpdate() => OfflineSyncViolationOperation.mergeUpdate,
      CrdtMergeDelete() => OfflineSyncViolationOperation.mergeDelete,
    };
  }

  /// Reports a successful merge for [spaceId] to [onMergeSuccess], combining the
  /// space's checkpoint high-water mark with the [receivedHlc] just merged.
  Future<void> _reportMerge(
    OfflineSyncOnMergeSuccess? onMergeSuccess,
    OfflineSyncSpaceState spaces,
    UuidValue spaceId,
    Hlc? receivedHlc,
  ) async {
    final checkpointMax = spaces.checkpointMaxOf(spaceId);
    if (checkpointMax == null) return;
    await onMergeSuccess?.call(spaceId, checkpointMax.maxBetween(receivedHlc));
  }

  /// Drains [iterator] until the peer closes the stream.
  ///
  /// Used to settle the inbound transport after the `once` close handshake so
  /// its controller reaches "done" with an active listener instead of being
  /// torn down while paused. Trailing events (idle timeouts, late frames) are
  /// discarded; errors are swallowed since the transport is closing anyway.
  static Future<void> _drainUntilDone(
    StreamIterator<OfflineSyncStreamEvent> iterator,
  ) async {
    try {
      while (await iterator.moveNext()) {
        // Discard whatever the peer sends before it closes its side.
      }
    } on Object catch (_) {
      // Best-effort: the transport is shutting down.
    }
  }

  void _validateSyncTablesHash(String syncTablesHash) {
    if (syncTablesHash != currentSyncTablesHash) {
      throw OfflineSyncTablesHashMismatchException(
        received: syncTablesHash,
        expected: currentSyncTablesHash,
      );
    }
  }

  OfflineSyncDatabase _openOfflineSyncDatabase(DatabaseSession session) {
    final db = session.db;
    // The wrapper is ephemeral and every operation performed on it lazily
    // ensures initialization, so there is nothing to eagerly initialize here.
    // Calling `initialize()` would re-run the per-session setup.
    return db is OfflineSyncDatabase ? db : wrapDatabase(db);
  }

  Stream<CrdtMergeChange> _streamPendingChanges(
    DatabaseSession session,
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
  ) async* {
    // Domain ownership is immutable while a collection runs, so read each
    // row's owner at most once across all three streams.
    final ownerCache = DomainRowOwnerCache();
    yield* _streamInserts(session, spaceUuidById, checkpointsBySpaceId, ownerCache);
    yield* _streamUpdates(session, spaceUuidById, checkpointsBySpaceId, ownerCache);
    yield* _streamDeletes(session, spaceUuidById, checkpointsBySpaceId, ownerCache);
  }

  Stream<CrdtMergeInsert> _streamInserts(
    DatabaseSession session,
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, checkpointsBySpaceId),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    final attemptedValueFieldsByRowId = await _loadAttemptedValueFields(
      session,
      rows,
    );

    for (final row in rows) {
      final tableName = row.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final table = _syncTablesByName[tableName]!;
      final dartName = _classNamesByTableName[tableName];
      if (dartName == null) continue;

      final spaceId = row.spaceId;
      final spaceUuid = spaceUuidById[spaceId]!;

      final domainRow = await _fetchDomainRow(
        session,
        tableName,
        row.uuidRowId,
        table,
        dartName,
        attemptedValueFieldsByRowId[row.id!],
        spaceId,
        ownerCache,
      );
      if (!domainRow.exists) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: OfflineSyncViolationType.missingDomainRow,
          operation: OfflineSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerSpaceId: null,
          incomingSpaceUuid: spaceUuid,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }
      if (domainRow.ownerSpaceId != spaceId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: OfflineSyncViolationType.ownershipCollision,
          operation: OfflineSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerSpaceId: domainRow.ownerSpaceId,
          incomingSpaceUuid: spaceUuid,
          uuidNodeId: row.node!.uuidNodeId,
          hlc: row.hlc,
        );
      }

      yield CrdtMergeInsert(
        uuidSpaceId: spaceUuid,
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
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, checkpointsBySpaceId),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
        attemptedValue: CrdtDataAttemptedValue.include(),
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

      final spaceId = field.row!.spaceId;
      final spaceUuid = spaceUuidById[spaceId]!;
      final columnName = field.column!.name;
      final columnValue = await _fetchOwnedColumnValue(
        session,
        tableName,
        field.row!.uuidRowId,
        columnName,
        field.attemptedValue,
        spaceId,
        ownerCache,
      );
      if (!columnValue.exists) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: field.row!.id,
          type: OfflineSyncViolationType.missingDomainRow,
          operation: OfflineSyncViolationOperation.outboundUpdate,
          tableName: tableName,
          rowId: field.row!.uuidRowId,
          ownerSpaceId: null,
          incomingSpaceUuid: spaceUuid,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }
      if (columnValue.ownerSpaceId != spaceId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: field.row!.id,
          type: OfflineSyncViolationType.ownershipCollision,
          operation: OfflineSyncViolationOperation.outboundUpdate,
          tableName: tableName,
          rowId: field.row!.uuidRowId,
          ownerSpaceId: columnValue.ownerSpaceId,
          incomingSpaceUuid: spaceUuid,
          uuidNodeId: field.node!.uuidNodeId,
          hlc: field.hlc,
        );
      }

      yield CrdtMergeUpdate(
        uuidSpaceId: spaceUuid,
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
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
    DomainRowOwnerCache ownerCache,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, checkpointsBySpaceId),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    for (final tombstone in tombstones) {
      if (!tombstone.reason.isSynced) continue;

      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final spaceId = tombstone.row!.spaceId;
      final spaceUuid = spaceUuidById[spaceId]!;
      final owner = await _readDomainRowOwner(
        session,
        tableName,
        tombstone.row!.uuidRowId,
        ownerCache,
      );
      if (owner.exists && owner.spaceId != spaceId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: tombstone.row!.id,
          type: OfflineSyncViolationType.ownershipCollision,
          operation: OfflineSyncViolationOperation.outboundDelete,
          tableName: tableName,
          rowId: tombstone.row!.uuidRowId,
          ownerSpaceId: owner.spaceId,
          incomingSpaceUuid: spaceUuid,
          uuidNodeId: tombstone.node!.uuidNodeId,
          hlc: tombstone.hlc,
        );
      }

      yield CrdtMergeDelete(
        uuidSpaceId: spaceUuid,
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
    Map<int, List<Hlc>> checkpointsBySpaceId,
  ) =>
      t.spaceId.inSet(checkpointsBySpaceId.keys.toSet()) &
      _afterAnySpaceCheckpointFilter(
        t.spaceId,
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        checkpointsBySpaceId,
      );

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    Map<int, List<Hlc>> checkpointsBySpaceId,
  ) =>
      t.row.spaceId.inSet(checkpointsBySpaceId.keys.toSet()) &
      _afterAnySpaceCheckpointFilter(
        t.row.spaceId,
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        checkpointsBySpaceId,
      );

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    Map<int, List<Hlc>> checkpointsBySpaceId,
  ) =>
      t.row.spaceId.inSet(checkpointsBySpaceId.keys.toSet()) &
      _afterAnySpaceCheckpointFilter(
        t.row.spaceId,
        t.node.uuidNodeId,
        t.hlcDatetime,
        t.hlcCounter,
        checkpointsBySpaceId,
      );

  /// Loads a domain row for outbound insert sync.
  ///
  /// Reads the materialized row from the domain table, then swaps any columns
  /// with an active [CrdtDataAttemptedValue] back to the authored value before
  /// deserializing. The domain table and projected columns are only known at
  /// runtime, so a generated repository cannot express this query. Keeping one
  /// targeted SQL projection also avoids fetching and serializing unrelated
  /// columns. This is the inverse of inbound FK materialization: the wire payload
  /// carries attempted facts, not locally projected visible values.
  Future<({bool exists, int? ownerSpaceId, dynamic row})> _fetchDomainRow(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    Table table,
    String dartName,
    List<CrdtDataField>? attemptedValueFields,
    int spaceId,
    DomainRowOwnerCache ownerCache,
  ) async {
    final cols = table.columns
        .map(
          (column) =>
              '${_outboundColumnExpression(session, column)} AS "${column.columnName.escapeIdentifier()}"',
        )
        .join(', ');
    final encodedRowId = rowId.sqlLiteral();
    final encodedSpaceId = spaceId.sqlLiteral();
    final escapedTableName = tableName.escapeIdentifier();
    final result = await session.db.unsafeQuery(
      'SELECT $cols FROM "$escapedTableName" '
      'WHERE "id" = $encodedRowId AND "spaceId" = $encodedSpaceId '
      'LIMIT 1',
    );
    if (result.isEmpty) {
      final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
      return (exists: owner.exists, ownerSpaceId: owner.spaceId, row: null);
    }
    ownerCache[(tableName, rowId)] = (exists: true, spaceId: spaceId);

    final rawColumns = result.first.toColumnMap();
    final columnMap =
        <String, dynamic>{
            for (final column in table.columns)
              column.columnName: _decodeStructuredValue(
                session,
                column,
                rawColumns[column.columnName],
              ),
          }
          // Domain columns hold visible/materialized FK values; restore attempted
          // values for override columns before building the outbound merge payload.
          ..applyAuthoredAttemptedValues(attemptedValueFields)
          // spaceId is local ownership metadata; it is never emitted on the wire.
          ..remove('spaceId');

    // A table definition names its class the way its own package spells it, so
    // a model owned by a shared package reports the unprefixed name while the
    // host protocol answers only to the package-prefixed one. Carrying the name
    // in the payload lets the host fall through to the protocol that owns the
    // model rather than failing on a name it does not know.
    // `Object` rather than `dynamic`: a dynamic target is read as a wrapped
    // dynamic field instead of a model payload.
    final row = session.db.serializationManager.deserialize<Object>({
      ...columnMap,
      '__className__': dartName,
    });
    return (exists: true, ownerSpaceId: spaceId, row: row);
  }

  /// Resolves a column value for outbound update sync.
  ///
  /// When [attempted] is present, returns its authored value instead of the
  /// materialized domain column value. Columns without an attempted row are
  /// read directly from the domain table. Both the table and column are
  /// runtime schema values, so this cannot use a statically typed repository.
  Future<({bool exists, int? ownerSpaceId, dynamic value})> _fetchOwnedColumnValue(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    String columnName,
    CrdtDataAttemptedValue? attempted,
    int spaceId,
    DomainRowOwnerCache ownerCache,
  ) async {
    if (attempted != null) {
      final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
      if (!owner.exists || owner.spaceId != spaceId) {
        return (exists: owner.exists, ownerSpaceId: owner.spaceId, value: null);
      }
      return (
        exists: true,
        ownerSpaceId: spaceId,
        value: canonicalDomainValue(attempted.value),
      );
    }

    final encodedRowId = rowId.sqlLiteral();
    final encodedSpaceId = spaceId.sqlLiteral();
    final escapedTableName = tableName.escapeIdentifier();
    final column = _syncTablesByName[tableName]!.columns.singleWhere(
      (c) => c.columnName == columnName,
    );
    final result = await session.db.unsafeQuery(
      'SELECT ${_outboundColumnExpression(session, column)} '
      'FROM "$escapedTableName" '
      'WHERE "id" = $encodedRowId AND "spaceId" = $encodedSpaceId '
      'LIMIT 1',
    );
    if (result.isNotEmpty) {
      ownerCache[(tableName, rowId)] = (exists: true, spaceId: spaceId);
      return (
        exists: true,
        ownerSpaceId: spaceId,
        value: _decodeColumnValue(
          tableName,
          columnName,
          _decodeStructuredValue(session, column, result.first[0]),
        ),
      );
    }

    final owner = await _readDomainRowOwner(session, tableName, rowId, ownerCache);
    return (exists: owner.exists, ownerSpaceId: owner.spaceId, value: null);
  }

  Future<DomainRowOwner> _readDomainRowOwner(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    DomainRowOwnerCache ownerCache,
  ) async {
    final cached = ownerCache[(tableName, rowId)];
    if (cached != null) return cached;

    final encodedRowId = rowId.sqlLiteral();
    final escapedTableName = tableName.escapeIdentifier();
    final result = await session.db.unsafeQuery(
      'SELECT "spaceId" FROM "$escapedTableName" '
      'WHERE "id" = $encodedRowId '
      'LIMIT 1',
    );
    final owner = result.isEmpty
        ? (exists: false, spaceId: null)
        : (exists: true, spaceId: result.first[0] as int?);
    ownerCache[(tableName, rowId)] = owner;
    return owner;
  }

  Never _throwPendingIntegrityViolation({
    required int? crdtDataRowId,
    required OfflineSyncViolationType type,
    required OfflineSyncViolationOperation operation,
    required String tableName,
    required UuidValue rowId,
    required int? ownerSpaceId,
    required UuidValue incomingSpaceUuid,
    required UuidValue uuidNodeId,
    Hlc? hlc,
  }) {
    throw PendingOutboundIntegrityViolation(
      crdtDataRowId: crdtDataRowId,
      type: type,
      operation: operation,
      tableName: tableName,
      rowId: rowId,
      ownerSpaceId: ownerSpaceId,
      incomingSpaceUuid: incomingSpaceUuid,
      uuidNodeId: uuidNodeId,
      hlc: hlc,
    );
  }

  Future<Never> _recordAndThrowIntegrityViolation(
    DatabaseSession session,
    PendingOutboundIntegrityViolation pending,
  ) async {
    final ownerSpaceUuid = await _spaceUuidForNormalizedId(
      session,
      pending.ownerSpaceId,
    );
    final now = clock.now().toUtc();
    final violation = OfflineSyncIntegrityViolation(
      type: pending.type,
      domainTableName: pending.tableName,
      uuidRowId: pending.rowId,
      ownerSpaceUuid: ownerSpaceUuid,
      incomingSpaceUuid: pending.incomingSpaceUuid,
      operation: pending.operation,
      uuidNodeId: pending.uuidNodeId,
      crdtDataRowId: pending.crdtDataRowId,
      hlcDatetime: pending.hlc?.datetime,
      hlcCounter: pending.hlc?.counter,
      firstSeenAt: now,
      lastSeenAt: now,
      occurrences: 1,
    );
    final persisted = await recordOfflineSyncIntegrityViolation(
      session,
      violation: violation,
    );
    throw OfflineSyncIntegrityViolationException(persisted);
  }

  Future<UuidValue?> _spaceUuidForNormalizedId(
    DatabaseSession session,
    int? spaceId,
  ) async {
    if (spaceId == null) return null;

    final space = await OfflineSyncSpace.db.findById(session, spaceId);
    return space?.uuidSpaceId;
  }

  /// Loads attempted-value metadata for outbound insert sync.
  ///
  /// Returns fields that currently have a [CrdtDataAttemptedValue] row, keyed
  /// by CRDT row id. These are the columns whose domain-table value differs
  /// from the durable authored fact.
  Future<Map<int, List<CrdtDataField>>> _loadAttemptedValueFields(
    DatabaseSession session,
    List<CrdtDataRow> rows,
  ) async {
    final rowIds = {for (final row in rows) ?row.id};
    if (rowIds.isEmpty) return {};

    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => t.rowId.inSet(rowIds) & t.attemptedValue.id.notEquals(null),
      include: CrdtDataField.include(
        column: CrdtSchemaColumn.include(),
        attemptedValue: CrdtDataAttemptedValue.include(),
      ),
    );

    final fieldsByRowId = <int, List<CrdtDataField>>{};
    for (final field in fields) {
      fieldsByRowId.putIfAbsent(field.rowId, () => []).add(field);
    }

    return fieldsByRowId;
  }

  String _outboundColumnExpression(DatabaseSession session, Column column) {
    final identifier = '"${column.columnName.escapeIdentifier()}"';
    if (session.db.dialect == DatabaseDialect.sqlite && column is ColumnStructured) {
      return 'json($identifier)';
    }
    return identifier;
  }

  /// Temporary workaround for raw queries bypassing Serverpod's column-aware
  /// result normalization. [_outboundColumnExpression] converts SQLite JSONB to
  /// JSON text so this method can decode both JSON and JSONB before deserialization.
  ///
  /// TODO: Serverpod needs a public API for adapter-specific, column-aware decoding
  /// of raw query results across supported types and databases. Replace this helper
  /// and [_outboundColumnExpression] with that upstream API when it is available.
  dynamic _decodeStructuredValue(
    DatabaseSession session,
    Column column,
    Object? value,
  ) {
    if (session.db.dialect == DatabaseDialect.sqlite &&
        (column is ColumnStructured || column is ColumnSerializable) &&
        value is String) {
      return jsonDecode(value);
    }
    return value;
  }

  dynamic _decodeColumnValue(
    String tableName,
    String columnName,
    Object? value,
  ) {
    if (value == null) return null;

    final column = _syncTablesByName[tableName]!.columns.singleWhere(
      (column) => column.columnName == columnName,
    );
    return _serializationManager.deserialize<dynamic>(value, column.type);
  }

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
            if (definition != null)
              for (final column in definition.columns)
                if (column.name != 'spaceId')
                  _canonicalColumnIdentity(definition, column)
                else
                  for (final column in table.columns)
                    if (column.columnName != 'spaceId') column.columnName,
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

  static String _canonicalColumnIdentity(
    TableDefinition table,
    ColumnDefinition column,
  ) {
    final releaseKind = crdtUniqueConflictReleaseKindForColumn(table, column);
    return '${column.name}:${column.columnType.name}:${column.dartType}:'
        '${column.isNullable}:${releaseKind?.name ?? '-'}';
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

Expression _afterAnySpaceCheckpointFilter(
  ColumnInt spaceId,
  ColumnUuid uuidNodeId,
  ColumnDateTime hlcDatetime,
  ColumnInt hlcCounter,
  Map<int, List<Hlc>> checkpointsBySpaceId,
) {
  final caseExpression = Case();
  var hasCheckpoint = false;
  for (final MapEntry(key: normalizedSpaceId, value: checkpoints)
      in checkpointsBySpaceId.entries) {
    for (final checkpoint in checkpoints) {
      hasCheckpoint = true;
      caseExpression.when(
        spaceId.equals(normalizedSpaceId) & uuidNodeId.equals(checkpoint.nodeId),
        then:
            (hlcDatetime > checkpoint.datetime) |
            (hlcDatetime.equals(checkpoint.datetime) &
                (hlcCounter > checkpoint.counter)),
      );
    }
  }
  return hasCheckpoint
      ? caseExpression.orElse(Constant.bool(true))
      : Constant.bool(true);
}

extension on Map<String, dynamic> {
  /// Replaces materialized column values with authored values for sync.
  ///
  /// After local projection, the domain table stores the safe visible value
  /// while [CrdtDataAttemptedValue.value] preserves what was actually tried.
  /// Outbound sync must send the attempted value so peers can apply their own
  /// projection from the same fact.
  void applyAuthoredAttemptedValues(List<CrdtDataField>? attemptedValueFields) {
    if (attemptedValueFields == null) return;
    for (final field in attemptedValueFields) {
      final attempted = field.attemptedValue;
      if (attempted == null) continue;
      this[field.column!.name] = canonicalDomainValue(attempted.value);
    }
  }
}
