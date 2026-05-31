import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../managers/user.dart';
import '../protocol/protocol.dart';
import 'exceptions.dart';
import 'merge.dart';

/// Callback function for when a merge is successful.
typedef CrdtSyncOnMergeSuccess = FutureOr<void> Function(Hlc syncedHlc);

/// The shared CRDT synchronization logic used by both client and server nodes.
class CrdtSync {
  /// Creates a new [CrdtSync] instance.
  CrdtSync({
    /// The list of tables to sync with CRDT.
    required List<Table> syncTables,

    /// The serialization manager to use for deserializing merge changes.
    required DatabaseSerializationManager serializationManager,

    /// Maximum number of merge changes sent in one sync stream message.
    int syncBatchSize = defaultSyncBatchSize,

    /// Delay between continuous sync rounds.
    Duration continuousSyncInterval = defaultContinuousSyncInterval,
  }) : _syncTables = syncTables,
       _serializationManager = serializationManager,
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
  final int _syncBatchSize;
  final Duration _continuousSyncInterval;

  static CrdtSync? _instance;

  /// The singleton instance of [CrdtSync]. Throws a [StateError] if it is not
  /// initialized.
  static CrdtSync get instance =>
      _instance ??
      (throw StateError(
        'The CrdtSync has not been initialized. Call pod.initializeCrdtSync(...) '
        'during server startup to configure the CRDT sync.',
      ));

  /// Configures the shared singleton used by server endpoints.
  ///
  /// Use [syncBatchSize] to control the maximum number of merge changes carried
  /// by each [CrdtSyncMergeChunk] stream event.
  ///
  /// The [continuousSyncInterval] controls how long a continuous sync session
  /// waits after completing one sync round before checking for local changes.
  static void initialize({
    required List<Table> syncTables,
    required DatabaseSerializationManager serializationManager,
    int syncBatchSize = defaultSyncBatchSize,
    Duration continuousSyncInterval = defaultContinuousSyncInterval,
  }) {
    _instance = CrdtSync(
      syncTables: syncTables,
      serializationManager: serializationManager,
      syncBatchSize: syncBatchSize,
      continuousSyncInterval: continuousSyncInterval,
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
  /// When [sinceHlc] is provided, it is used instead of peer checkpoint state.
  Stream<CrdtMergeChange> collectPendingChanges(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
    Hlc? sinceHlc,
  }) async* {
    final crdtUser = await CrdtUserManager(session).getOrCreate(userId);
    if (sinceHlc != null) {
      yield* _streamInsertsSinceHlc(session, crdtUser, sinceHlc);
      yield* _streamUpdatesSinceHlc(session, crdtUser, sinceHlc);
      yield* _streamDeletesSinceHlc(session, crdtUser, sinceHlc);
      return;
    }

    final peerNodeRowId = await _getOrCreateNodeRowId(
      session,
      userDbId: crdtUser.id!,
      uuidNodeId: peerNodeId,
    );

    yield* _streamInsertsForPeer(session, crdtUser, peerNodeRowId);
    yield* _streamUpdatesForPeer(session, crdtUser, peerNodeRowId);
    yield* _streamDeletesForPeer(session, crdtUser, peerNodeRowId);
  }

  /// Creates the [CrdtSyncSinceHlc] checkpoint for the post-connect handshake.
  ///
  /// [CrdtSyncSinceHlc.nodeCheckpoints] reflects the latest change this node
  /// has received from each known node, tagged with the source node id.
  Future<CrdtSyncSinceHlc> createSyncSinceHlc(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
  }) async {
    final crdtUser = await CrdtUserManager(session).getOrCreate(userId);
    await _ensureNodesExist(
      session,
      userDbId: crdtUser.id!,
      nodeIds: {peerNodeId},
    );

    final nodes = await CrdtNode.db.find(
      session,
      where: (t) => t.userId.equals(crdtUser.id),
    );

    final checkpoints = <Hlc>[
      for (final node in nodes) node.lastReceivedHlc ?? Hlc.zero(node.uuidNodeId),
    ];

    if (_findCheckpoint(checkpoints, peerNodeId) == null) {
      checkpoints.add(Hlc.zero(peerNodeId));
    }

    return CrdtSyncSinceHlc(nodeCheckpoints: checkpoints);
  }

  /// Merges a remote [mergeSet] and records the sync checkpoint for [otherNodeId].
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
    final crdtDb = await _openCrdtDatabase(session);
    await crdtDb.mergeChanges(mergeSet, userId: userId);
    return maxSyncedHlc;
  }

  /// Streams a framed outbound sync batch of merge changes.
  Stream<CrdtSyncStreamEvent> streamOutboundBatch(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
    required Hlc sinceHlc,
  }) async* {
    yield* collectPendingChanges(
          session,
          userId: userId,
          peerNodeId: peerNodeId,
          sinceHlc: sinceHlc,
        )
        .chunked(_syncBatchSize)
        .map(
          (changes) => CrdtSyncMergeChunk(changes: changes),
        );
    yield CrdtSyncEndOfBatch();
  }

  /// Runs a symmetric CRDT sync session over a bidirectional event stream.
  ///
  /// Both peers send [CrdtSyncConnect], read the peer connect frame, then send
  /// and read [CrdtSyncSinceHlc] once. After that, both sides exchange framed
  /// data batches using the peer's per-node checkpoints carried by
  /// [CrdtSyncSinceHlc.nodeCheckpoints].
  ///
  /// If a batch fails to merge, the exception propagates and the stream closes.
  /// The next sync attempt resumes from the last persisted checkpoint on the
  /// side that failed to merge.
  ///
  /// When [once] is true, each peer sends one batch, reads one batch, sends a
  /// [CrdtSyncClose] frame and awaits for the other to send its closing event
  /// to complete the session.
  Stream<CrdtSyncStreamEvent> sync(
    DatabaseSession session, {
    required UuidValue userId,
    required Stream<CrdtSyncStreamEvent> inbound,
    bool once = false,
    CrdtSyncOnMergeSuccess? onMergeSuccess,
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

    var sessionCompleted = false;
    try {
      final crdtUser = await CrdtUserManager(session).getOrCreate(userId);
      final localNodeId = crdtUser.currentNode!.uuidNodeId;

      yield CrdtSyncConnect(
        localNodeId: localNodeId,
        syncTablesHash: currentSyncTablesHash,
      );

      final peerConnect = await inboundIterator.moveAndThrowIfNot<CrdtSyncConnect>();
      final peerNodeId = peerConnect.localNodeId;
      _validateSyncTablesHash(peerConnect.syncTablesHash);

      yield await createSyncSinceHlc(
        session,
        userId: userId,
        peerNodeId: peerNodeId,
      );

      final peerSinceHlc = await inboundIterator.moveAndThrowIfNot<CrdtSyncSinceHlc>();
      final peerLocalCheckpoint = _findCheckpoint(
        peerSinceHlc.nodeCheckpoints,
        localNodeId,
      );
      if (peerLocalCheckpoint == null) {
        throw CrdtSyncMissingSinceHlcException(expectedNodeId: localNodeId);
      }

      await _replacePeerCheckpoints(
        session,
        userDbId: crdtUser.id!,
        peerNodeId: peerNodeId,
        checkpoints: peerSinceHlc.nodeCheckpoints,
      );

      while (true) {
        final pendingLocalChanges = collectPendingChanges(
          session,
          userId: userId,
          peerNodeId: peerNodeId,
        );

        var hasChanges = false;
        Hlc? maxSentHlc;
        final maxSentHlcByNode = <UuidValue, Hlc>{};
        await for (final changes in pendingLocalChanges.chunked(_syncBatchSize)) {
          hasChanges = true;
          for (final change in changes) {
            final hlc = change.hlc;
            maxSentHlc = hlc.maxBetween(maxSentHlc);
            maxSentHlcByNode[change.uuidNodeId] = hlc.maxBetween(
              maxSentHlcByNode[change.uuidNodeId],
            );
          }
          yield CrdtSyncMergeChunk(changes: changes);
        }
        if (hasChanges || once) {
          yield CrdtSyncEndOfBatch();
        }
        if (hasChanges) {
          await _advancePeerCheckpoints(
            session,
            userDbId: crdtUser.id!,
            peerNodeId: peerNodeId,
            maxHlcByNode: maxSentHlcByNode,
          );
        }

        final inboundMergeSet = await inboundIterator.collectNextBatch(
          allowCloseBeforeBatch: !once,
        );
        if (inboundMergeSet == null) {
          sessionCompleted = true;
          return;
        }

        final lastReceivedFromPeer = await mergeInboundBatch(
          session,
          userId: userId,
          otherNodeId: peerNodeId,
          mergeSet: inboundMergeSet,
        );

        if (hasChanges || inboundMergeSet.isNotEmpty) {
          final syncedHlc = (maxSentHlc ?? peerLocalCheckpoint).maxBetween(
            lastReceivedFromPeer,
          );
          await onMergeSuccess?.call(
            syncedHlc,
          );
        }

        if (once) {
          yield CrdtSyncClose();
          await inboundIterator.moveAndThrowIfNot<CrdtSyncClose>();
          sessionCompleted = true;
          return;
        }

        // Wait for the configured interval before checking for local changes again.
        await Future<void>.delayed(_continuousSyncInterval);
      }
    } finally {
      // Cancelling inbound on normal completion races with WebSocket stream
      // teardown and produces "connection closed" errors on the peer. Keep
      // cleanup for abnormal exits so listener cancellation can unblock.
      if (!sessionCompleted) {
        // Best-effort cleanup, since the transport will close the socket anyway.
        const waitTimeout = Duration(milliseconds: 200);
        await inboundIterator.cancel().timeout(waitTimeout, onTimeout: () {});
      }
    }
  }

  void _validateSyncTablesHash(String syncTablesHash) {
    if (syncTablesHash != currentSyncTablesHash) {
      throw SyncTablesHashMismatchException(
        received: syncTablesHash,
        expected: currentSyncTablesHash,
      );
    }
  }

  Future<CrdtDatabase> _openCrdtDatabase(DatabaseSession session) async {
    final db = session.db;
    if (db is CrdtDatabase) {
      return db;
    }

    final crdtDb = CrdtDatabase(db, syncTables: _syncTables);
    await crdtDb.initialize();
    return crdtDb;
  }

  Stream<CrdtMergeInsert> _streamInsertsSinceHlc(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    yield* _toInsertChanges(session, rows);
  }

  Stream<CrdtMergeInsert> _streamInsertsForPeer(
    DatabaseSession session,
    CrdtUser crdtUser,
    int peerNodeRowId,
  ) async* {
    final rowIds = await _pendingInsertRowIdsForPeer(
      session,
      userDbId: crdtUser.id!,
      peerNodeRowId: peerNodeRowId,
    );
    if (rowIds.isEmpty) return;

    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => t.id.inSet(rowIds.toSet()),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    yield* _toInsertChanges(session, rows);
  }

  Stream<CrdtMergeInsert> _toInsertChanges(
    DatabaseSession session,
    List<CrdtDataRow> rows,
  ) async* {
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
      );
      if (domainRow == null) continue;

      yield CrdtMergeInsert(
        hlcDatetime: row.hlcDatetime,
        hlcCounter: row.hlcCounter,
        tableName: tableName,
        uuidRowId: row.uuidRowId,
        uuidNodeId: row.node!.uuidNodeId,
        data: domainRow,
      );
    }
  }

  Stream<CrdtMergeUpdate> _streamUpdatesSinceHlc(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
      ),
    );

    yield* _toUpdateChanges(session, fields);
  }

  Stream<CrdtMergeUpdate> _streamUpdatesForPeer(
    DatabaseSession session,
    CrdtUser crdtUser,
    int peerNodeRowId,
  ) async* {
    final fieldIds = await _pendingUpdateFieldIdsForPeer(
      session,
      userDbId: crdtUser.id!,
      peerNodeRowId: peerNodeRowId,
    );
    if (fieldIds.isEmpty) return;

    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => t.id.inSet(fieldIds.toSet()),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
      ),
    );

    yield* _toUpdateChanges(session, fields);
  }

  Stream<CrdtMergeUpdate> _toUpdateChanges(
    DatabaseSession session,
    List<CrdtDataField> fields,
  ) async* {
    for (final field in fields) {
      final tableName = field.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final columnName = field.column!.name;
      final decodedValue = await _fetchColumnValue(
        session,
        tableName,
        field.row!.uuidRowId,
        columnName,
      );

      yield CrdtMergeUpdate(
        hlcDatetime: field.hlcDatetime,
        hlcCounter: field.hlcCounter,
        tableName: tableName,
        uuidRowId: field.row!.uuidRowId,
        uuidNodeId: field.node!.uuidNodeId,
        columnName: columnName,
        value: decodedValue,
      );
    }
  }

  Stream<CrdtMergeDelete> _streamDeletesSinceHlc(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    yield* _toDeleteChanges(tombstones);
  }

  Stream<CrdtMergeDelete> _streamDeletesForPeer(
    DatabaseSession session,
    CrdtUser crdtUser,
    int peerNodeRowId,
  ) async* {
    final tombstoneIds = await _pendingDeleteTombstoneIdsForPeer(
      session,
      userDbId: crdtUser.id!,
      peerNodeRowId: peerNodeRowId,
    );
    if (tombstoneIds.isEmpty) return;

    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => t.id.inSet(tombstoneIds.toSet()),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    yield* _toDeleteChanges(tombstones);
  }

  Stream<CrdtMergeDelete> _toDeleteChanges(List<CrdtDataDeleted> tombstones) async* {
    for (final tombstone in tombstones) {
      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

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
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Future<void> _ensureNodesExist(
    DatabaseSession session, {
    required int userDbId,
    required Set<UuidValue> nodeIds,
  }) async {
    if (nodeIds.isEmpty) return;

    await session.db.transaction((transaction) async {
      final existing = await CrdtNode.db.find(
        session,
        where: (t) => t.userId.equals(userDbId) & t.uuidNodeId.inSet(nodeIds),
        transaction: transaction,
      );
      final existingIds = existing.map((node) => node.uuidNodeId).toSet();
      final missing = nodeIds.difference(existingIds);
      if (missing.isEmpty) return;

      await CrdtNode.db.insert(
        session,
        [
          for (final uuidNodeId in missing)
            CrdtNode(
              userId: userDbId,
              uuidNodeId: uuidNodeId,
            ),
        ],
        transaction: transaction,
        ignoreConflicts: true,
      );
    });
  }

  Future<int> _getOrCreateNodeRowId(
    DatabaseSession session, {
    required int userDbId,
    required UuidValue uuidNodeId,
  }) async {
    final node = await session.db.transaction((transaction) async {
      var existing = await CrdtNode.db.findFirstRow(
        session,
        where: (t) => t.userId.equals(userDbId) & t.uuidNodeId.equals(uuidNodeId),
        transaction: transaction,
      );
      existing ??= await CrdtNode.db.insertRow(
        session,
        CrdtNode(userId: userDbId, uuidNodeId: uuidNodeId),
        transaction: transaction,
      );
      return existing;
    });

    return node.id!;
  }

  Hlc? _findCheckpoint(List<Hlc> checkpoints, UuidValue nodeId) {
    for (final checkpoint in checkpoints) {
      if (checkpoint.nodeId == nodeId) return checkpoint;
    }
    return null;
  }

  Future<void> _replacePeerCheckpoints(
    DatabaseSession session, {
    required int userDbId,
    required UuidValue peerNodeId,
    required List<Hlc> checkpoints,
  }) async {
    final checkpointByNodeId = <UuidValue, Hlc>{};
    for (final checkpoint in checkpoints) {
      checkpointByNodeId[checkpoint.nodeId] = checkpoint.maxBetween(
        checkpointByNodeId[checkpoint.nodeId],
      );
    }

    final nodeIds = {peerNodeId, ...checkpointByNodeId.keys};
    await _ensureNodesExist(session, userDbId: userDbId, nodeIds: nodeIds);

    await session.db.transaction((transaction) async {
      final nodes = await CrdtNode.db.find(
        session,
        where: (t) => t.userId.equals(userDbId) & t.uuidNodeId.inSet(nodeIds),
        transaction: transaction,
      );
      final nodeDbIds = {for (final node in nodes) node.uuidNodeId: node.id!};
      final peerNodeDbId = nodeDbIds[peerNodeId]!;

      await CrdtPeerCheckpoint.db.deleteWhere(
        session,
        where: (t) => t.userId.equals(userDbId) & t.peerNodeId.equals(peerNodeDbId),
        transaction: transaction,
      );

      if (checkpointByNodeId.isEmpty) return;
      await CrdtPeerCheckpoint.db.insert(
        session,
        [
          for (final MapEntry(key: sourceNodeId, value: hlc)
              in checkpointByNodeId.entries)
            CrdtPeerCheckpoint(
              userId: userDbId,
              peerNodeId: peerNodeDbId,
              sourceNodeId: nodeDbIds[sourceNodeId]!,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
        ],
        transaction: transaction,
      );
    });
  }

  Future<void> _advancePeerCheckpoints(
    DatabaseSession session, {
    required int userDbId,
    required UuidValue peerNodeId,
    required Map<UuidValue, Hlc> maxHlcByNode,
  }) async {
    if (maxHlcByNode.isEmpty) return;

    final nodeIds = {peerNodeId, ...maxHlcByNode.keys};
    await _ensureNodesExist(session, userDbId: userDbId, nodeIds: nodeIds);

    await session.db.transaction((transaction) async {
      final nodes = await CrdtNode.db.find(
        session,
        where: (t) => t.userId.equals(userDbId) & t.uuidNodeId.inSet(nodeIds),
        transaction: transaction,
      );
      final nodeDbIds = {for (final node in nodes) node.uuidNodeId: node.id!};
      final peerNodeDbId = nodeDbIds[peerNodeId]!;

      final sourceNodeDbIds = {
        for (final uuidNodeId in maxHlcByNode.keys) nodeDbIds[uuidNodeId]!,
      };

      final existing = await CrdtPeerCheckpoint.db.find(
        session,
        where: (t) =>
            t.userId.equals(userDbId) &
            t.peerNodeId.equals(peerNodeDbId) &
            t.sourceNodeId.inSet(sourceNodeDbIds),
        transaction: transaction,
      );
      final existingBySourceNodeDbId = {
        for (final row in existing) row.sourceNodeId: row,
      };

      final toInsert = <CrdtPeerCheckpoint>[];
      final toUpdate = <CrdtPeerCheckpoint>[];

      for (final MapEntry(key: sourceNodeUuid, value: maxHlc) in maxHlcByNode.entries) {
        final sourceNodeDbId = nodeDbIds[sourceNodeUuid]!;
        final current = existingBySourceNodeDbId[sourceNodeDbId];
        if (current == null) {
          toInsert.add(
            CrdtPeerCheckpoint(
              userId: userDbId,
              peerNodeId: peerNodeDbId,
              sourceNodeId: sourceNodeDbId,
              hlcDatetime: maxHlc.datetime,
              hlcCounter: maxHlc.counter,
            ),
          );
          continue;
        }

        final isAfter =
            maxHlc.datetime.isAfter(current.hlcDatetime) ||
            (maxHlc.datetime.isAtSameMomentAs(current.hlcDatetime) &&
                maxHlc.counter > current.hlcCounter);
        if (!isAfter) continue;

        toUpdate.add(
          current.copyWith(
            hlcDatetime: maxHlc.datetime,
            hlcCounter: maxHlc.counter,
          ),
        );
      }

      if (toInsert.isNotEmpty) {
        await CrdtPeerCheckpoint.db.insert(
          session,
          toInsert,
          transaction: transaction,
          ignoreConflicts: true,
        );
      }
      if (toUpdate.isNotEmpty) {
        await CrdtPeerCheckpoint.db.update(
          session,
          toUpdate,
          columns: (t) => [t.hlcDatetime, t.hlcCounter],
          transaction: transaction,
        );
      }
    });
  }

  Future<List<int>> _pendingInsertRowIdsForPeer(
    DatabaseSession session, {
    required int userDbId,
    required int peerNodeRowId,
  }) async {
    final encodedUserId = ValueEncoder.instance.convert(userDbId);
    final encodedPeerNodeId = ValueEncoder.instance.convert(peerNodeRowId);
    final result = await session.db.unsafeQuery(
      'SELECT r."id" '
      'FROM "crdt_data_rows" r '
      'LEFT JOIN "crdt_peer_checkpoints" c '
      '  ON c."userId" = r."userId" '
      ' AND c."peerNodeId" = $encodedPeerNodeId '
      ' AND c."sourceNodeId" = r."nodeId" '
      'WHERE r."userId" = $encodedUserId '
      '  AND ('
      '    c."id" IS NULL OR '
      '    r."hlcDatetime" > c."hlcDatetime" OR '
      '    (r."hlcDatetime" = c."hlcDatetime" AND r."hlcCounter" > c."hlcCounter")'
      '  )',
    );
    return _decodeIntColumn(result);
  }

  Future<List<int>> _pendingUpdateFieldIdsForPeer(
    DatabaseSession session, {
    required int userDbId,
    required int peerNodeRowId,
  }) async {
    final encodedUserId = ValueEncoder.instance.convert(userDbId);
    final encodedPeerNodeId = ValueEncoder.instance.convert(peerNodeRowId);
    final result = await session.db.unsafeQuery(
      'SELECT f."id" '
      'FROM "crdt_data_fields" f '
      'JOIN "crdt_data_rows" r ON r."id" = f."rowId" '
      'LEFT JOIN "crdt_peer_checkpoints" c '
      '  ON c."userId" = r."userId" '
      ' AND c."peerNodeId" = $encodedPeerNodeId '
      ' AND c."sourceNodeId" = f."nodeId" '
      'WHERE r."userId" = $encodedUserId '
      '  AND ('
      '    c."id" IS NULL OR '
      '    f."hlcDatetime" > c."hlcDatetime" OR '
      '    (f."hlcDatetime" = c."hlcDatetime" AND f."hlcCounter" > c."hlcCounter")'
      '  )',
    );
    return _decodeIntColumn(result);
  }

  Future<List<int>> _pendingDeleteTombstoneIdsForPeer(
    DatabaseSession session, {
    required int userDbId,
    required int peerNodeRowId,
  }) async {
    final encodedUserId = ValueEncoder.instance.convert(userDbId);
    final encodedPeerNodeId = ValueEncoder.instance.convert(peerNodeRowId);
    final result = await session.db.unsafeQuery(
      'SELECT d."id" '
      'FROM "crdt_data_tombstone" d '
      'JOIN "crdt_data_rows" r ON r."id" = d."rowId" '
      'LEFT JOIN "crdt_peer_checkpoints" c '
      '  ON c."userId" = r."userId" '
      ' AND c."peerNodeId" = $encodedPeerNodeId '
      ' AND c."sourceNodeId" = d."nodeId" '
      'WHERE r."userId" = $encodedUserId '
      '  AND ('
      '    c."id" IS NULL OR '
      '    d."hlcDatetime" > c."hlcDatetime" OR '
      '    (d."hlcDatetime" = c."hlcDatetime" AND d."hlcCounter" > c."hlcCounter")'
      '  )',
    );
    return _decodeIntColumn(result);
  }

  List<int> _decodeIntColumn(List<dynamic> result) {
    final ids = <int>[];
    for (final row in result) {
      final value = row[0];
      ids.add(
        switch (value) {
          final int v => v,
          final BigInt v => v.toInt(),
          _ => throw StateError(
            'Unexpected id value type "${value.runtimeType}" while decoding '
            'pending change ids.',
          ),
        },
      );
    }
    return ids;
  }

  Future<dynamic> _fetchDomainRow(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    Table table,
    String dartName,
  ) async {
    final cols = table.columns.map((column) => '"${column.columnName}"').join(', ');
    final encodedRowId = ValueEncoder.instance.convert(rowId);
    final result = await session.db.unsafeQuery(
      'SELECT $cols FROM "$tableName" WHERE "id" = $encodedRowId',
    );
    if (result.isEmpty) return null;

    final columnMap = result.first.toColumnMap();
    return session.db.serializationManager.deserializeByClassName({
      'className': dartName,
      'data': columnMap,
    });
  }

  Future<dynamic> _fetchColumnValue(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    String columnName,
  ) async {
    final encodedValue = ValueEncoder.instance.convert(rowId);
    final result = await session.db.unsafeQuery(
      'SELECT "$columnName" FROM "$tableName" WHERE "id" = $encodedValue',
    );
    if (result.isEmpty) return null;
    return _decodeColumnValue(tableName, columnName, result.first[0]);
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
              column.name,
            if (definition == null) ...table.columns.map((column) => column.columnName),
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
