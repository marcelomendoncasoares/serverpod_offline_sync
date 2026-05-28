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

  /// Streams local CRDT changes since the last sync checkpoint with [otherNodeId].
  ///
  /// Changes are emitted in insert, update, then delete order. Domain row and
  /// column payloads are resolved incrementally as each change is yielded.
  ///
  /// When [sinceHlc] is provided, it is used instead of the stored checkpoint.
  Stream<CrdtMergeChange> collectPendingChanges(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue otherNodeId,
    Hlc? sinceHlc,
  }) async* {
    final crdtUser = await CrdtUserManager(session).getOrCreate(userId);
    final syncCheckpoint =
        sinceHlc ??
        await _syncCheckpointForNode(
          session,
          crdtUser,
          otherNodeId,
        );

    yield* _streamInserts(session, crdtUser, syncCheckpoint);
    yield* _streamUpdates(session, crdtUser, syncCheckpoint);
    yield* _streamDeletes(session, crdtUser, syncCheckpoint);
  }

  /// Creates the [CrdtSyncSinceHlc] checkpoint for the post-connect handshake.
  ///
  /// [CrdtSyncSinceHlc.lastSyncFromPeer] reflects the latest change this node
  /// has received from [peerNodeId], tagged with the peer's node id.
  Future<CrdtSyncSinceHlc> createSyncSinceHlc(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue peerNodeId,
  }) async {
    final crdtUser = await CrdtUserManager(session).getOrCreate(userId);
    final lastSeenHlc = await _syncCheckpointForNode(session, crdtUser, peerNodeId);
    return CrdtSyncSinceHlc(lastSyncFromPeer: lastSeenHlc);
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
    required Hlc sinceHlc,
  }) async* {
    yield* collectPendingChanges(
          session,
          userId: userId,
          otherNodeId: peerNodeId,
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
  /// data batches using (1) the peer's authoritative since HLC for the first
  /// send, and (2) [CrdtSyncSinceHlc.lastSyncFromPeer] for subsequent sends
  /// within the session.
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
      if (peerSinceHlc.lastSyncFromPeer.nodeId != localNodeId) {
        throw CrdtSyncInvalidSinceHlcException(
          receivedNodeId: peerSinceHlc.lastSyncFromPeer.nodeId,
          expectedNodeId: localNodeId,
        );
      }

      var lastSentToPeer = peerSinceHlc.lastSyncFromPeer;

      while (true) {
        final pendingLocalChanges = collectPendingChanges(
          session,
          userId: userId,
          otherNodeId: peerNodeId,
          sinceHlc: lastSentToPeer,
        );

        var hasChanges = false;
        await for (final changes in pendingLocalChanges.chunked(_syncBatchSize)) {
          hasChanges = true;
          lastSentToPeer = lastSentToPeer.maxBetween(changes.maxHlc);
          yield CrdtSyncMergeChunk(changes: changes);
        }
        if (hasChanges || once) {
          yield CrdtSyncEndOfBatch();
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
          await onMergeSuccess?.call(
            lastSentToPeer.maxBetween(lastReceivedFromPeer),
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

  Future<Hlc> _syncCheckpointForNode(
    DatabaseSession session,
    CrdtUser crdtUser,
    UuidValue otherNodeId,
  ) async {
    final otherNode = await CrdtNode.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(crdtUser.id) & t.uuidNodeId.equals(otherNodeId),
    );

    return otherNode?.lastReceivedHlc ?? Hlc.zero(otherNodeId);
  }

  Stream<CrdtMergeInsert> _streamInserts(
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

  Stream<CrdtMergeUpdate> _streamUpdates(
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

  Stream<CrdtMergeDelete> _streamDeletes(
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

    for (final tombstone in tombstones) {
      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      yield CrdtMergeDelete(
        hlcDatetime: tombstone.hlcDatetime,
        hlcCounter: tombstone.hlcCounter,
        tableName: tableName,
        uuidRowId: tombstone.row!.uuidRowId,
        uuidNodeId: tombstone.node!.uuidNodeId,
        isDeleted: tombstone.isDeleted,
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
