import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
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
import 'cancellation.dart';
import 'diagnostics.dart';
import 'exceptions.dart';
import 'integrity_violation.dart';
import 'space_state.dart';

export 'space_state.dart' show OfflineSyncPeerMode;

part 'session.dart';

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

    /// Optional throttle between continuous sync rounds.
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

  /// Continuous sync responds immediately unless a throttle is configured.
  static const defaultContinuousSyncInterval = Duration.zero;

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
  /// Changes are captured in one consistent transaction, including domain
  /// payloads, then emitted in insert, update, and delete order. The transaction
  /// is released before yielding, so consumer backpressure or consumer writes
  /// cannot keep the snapshot (or SQLite's write lock) open.
  ///
  /// Consume this stream outside application transactions, using a session
  /// without an ambient transaction. Collection opens its own transaction to
  /// capture committed data; it does not join a caller's transaction.
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

    // Resolve stable space identities before opening the snapshot. A wrapped
    // database may initialize its CRDT registry on this first query, which can
    // itself need a write transaction.
    final spaces = await OfflineSyncSpace.db.find(
      session,
      where: (t) => t.uuidSpaceId.inSet(checkpointsBySpaceUuid.keys.toSet()),
    );
    if (spaces.isEmpty) return;

    final spaceUuidById = {
      for (final space in spaces) space.id!: space.uuidSpaceId,
    };
    final checkpointsBySpaceId = {
      for (final space in spaces)
        space.id!: checkpointsBySpaceUuid[space.uuidSpaceId] ?? const <Hlc>[],
    };

    try {
      final changes = await session.db.transaction(
        (transaction) => _streamPendingChanges(
          session,
          spaceUuidById,
          checkpointsBySpaceId,
          transaction,
        ).toList(),
        settings: const TransactionSettings(
          isolationLevel: IsolationLevel.repeatableRead,
        ),
      );

      for (final change in changes) {
        yield change;
      }
    } on PendingOutboundIntegrityViolation catch (violation) {
      await _recordAndThrowIntegrityViolation(session, violation);
    }
  }

  /// Creates the [OfflineSyncSinceHlc] checkpoint for a space handshake.
  ///
  /// [OfflineSyncSinceHlc.nodeCheckpoints] reflects the latest change this
  /// database has from each node in the space, tagged with the source node id.
  /// Local nodes, including other users' clocks, are reported as complete.
  Future<OfflineSyncSinceHlc> createSyncSinceHlc(
    DatabaseSession session, {
    required UuidValue spaceId,
  }) async {
    final space = await OfflineSyncSpaceManager(session).getOrCreate(spaceId);

    final spaceNodes = await OfflineSyncSpaceNode.db.find(
      session,
      where: (t) => t.spaceId.equals(space.id),
      include: OfflineSyncSpaceNode.include(node: CrdtNode.include()),
    );

    final checkpoints = <UuidValue, Hlc>{};
    for (final spaceNode in spaceNodes) {
      final node = spaceNode.node!;
      final nodeId = node.uuidNodeId;
      if (node.localUserUuid != null) {
        // This database authored every fact of a local clock. Cover committed
        // logical ticks as well as wall time, so peers never echo them back.
        checkpoints[nodeId] = Hlc.now(nodeId).maxBetween(node.lastHlc);
        continue;
      }
      final received = spaceNode.lastReceivedHlc;
      // Older inbound bookkeeping could store a relayed author's clock under
      // its direct peer. It proves no per-author progress for that peer.
      final checkpoint = received?.nodeId == nodeId ? received! : Hlc.zero(nodeId);
      checkpoints[nodeId] = checkpoint.maxBetween(checkpoints[nodeId]);
    }

    return OfflineSyncSinceHlc(
      uuidSpaceId: spaceId,
      nodeCheckpoints: checkpoints.values.toList(),
    );
  }

  /// Merges a remote [mergeSet] and atomically records its per-author progress.
  ///
  /// Inbound merge applies each remote change as [userId] in [spaceId], then
  /// materializes foreign-key projection into domain tables via
  /// [OfflineSyncDatabase.mergeChanges].
  ///
  /// Throws if the merge fails. The sync stream should be closed so the next
  /// attempt resumes from the last persisted checkpoint.
  ///
  /// Returns the greatest HLC synced in the batch, or `null` if the batch is
  /// empty.
  @visibleForTesting
  Future<Hlc?> mergeInboundBatch(
    DatabaseSession session, {
    required UuidValue userId,
    required UuidValue spaceId,
    required CrdtMergeSet mergeSet,
    OfflineSyncCancellation? cancellation,
    bool requireWriteAccess = false,
  }) async {
    if (mergeSet.isEmpty) return null;
    final maxSyncedHlc = mergeSet.maxHlc;
    final offlineSyncDb = _openOfflineSyncDatabase(session);
    await offlineSyncDb.mergeChanges(
      mergeSet,
      userId: userId,
      spaceId: spaceId,
      cancellation: cancellation,
      requireWriteAccess: requireWriteAccess,
    );
    return maxSyncedHlc;
  }

  /// Synchronizes independent numbered batches over one bidirectional stream.
  ///
  /// Receivers acknowledge only committed batches. A finite session completes
  /// after the follower's selected upload and a server snapshot taken after that
  /// upload commits have both been acknowledged. Continuous sessions remain
  /// silent until changes or membership updates need to be sent.
  Stream<OfflineSyncStreamEvent> sync(
    DatabaseSession session, {
    required UuidValue userId,
    required Stream<OfflineSyncStreamEvent> inbound,
    required OfflineSyncPeerMode mode,
    bool once = false,
    OfflineSyncOnMergeSuccess? onMergeSuccess,
  }) => _SyncSession(
    this,
    session,
    userId: userId,
    inbound: inbound,
    mode: mode,
    once: once,
    onMergeSuccess: onMergeSuccess,
  ).stream;

  /// Reports a successful merge for [spaceId] to [onMergeSuccess], combining the
  /// space's checkpoint high-water mark with the [receivedHlc] just merged.
  Future<void> _reportMerge(
    OfflineSyncOnMergeSuccess? onMergeSuccess,
    OfflineSyncSpaceState spaces,
    UuidValue spaceId,
    Hlc? receivedHlc,
  ) async {
    final checkpointMax = spaces.checkpointMaxOf(spaceId);
    if (checkpointMax == null) {
      OfflineSyncDiagnostics.event('sync.mergeReportSkipped', {
        'reason': 'noCheckpoint',
        'spaceId': spaceId.toString(),
      });
      return;
    }
    OfflineSyncDiagnostics.event('sync.mergeReportStart');
    await onMergeSuccess?.call(spaceId, checkpointMax.maxBetween(receivedHlc));
    OfflineSyncDiagnostics.event('sync.mergeReportEnd');
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
    Transaction transaction,
  ) async* {
    // Cache ownership within this collection's consistent snapshot.
    final ownerCache = DomainRowOwnerCache();
    yield* _streamInserts(
      session,
      spaceUuidById,
      checkpointsBySpaceId,
      ownerCache,
      transaction,
    );
    yield* _streamUpdates(
      session,
      spaceUuidById,
      checkpointsBySpaceId,
      ownerCache,
      transaction,
    );
    yield* _streamDeletes(
      session,
      spaceUuidById,
      checkpointsBySpaceId,
      ownerCache,
      transaction,
    );
  }

  Stream<CrdtMergeInsert> _streamInserts(
    DatabaseSession session,
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
    DomainRowOwnerCache ownerCache,
    Transaction transaction,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      transaction: transaction,
      where: (t) => _rowHlcAfterFilter(t, checkpointsBySpaceId),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    final attemptedValueFieldsByRowId = await _loadAttemptedValueFields(
      session,
      rows,
      transaction,
    );
    final domainRows = await _loadOutboundRows(session, rows, transaction);

    for (final row in rows) {
      final tableName = row.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final table = _syncTablesByName[tableName]!;
      final dartName = _classNamesByTableName[tableName];
      if (dartName == null) continue;

      final spaceId = row.spaceId;
      final spaceUuid = spaceUuidById[spaceId]!;

      final columns = domainRows[(tableName, spaceId, row.uuidRowId)];
      final owner = columns == null
          ? await _readDomainRowOwner(
              session,
              tableName,
              row.uuidRowId,
              ownerCache,
              transaction,
            )
          : (exists: true, spaceId: spaceId);
      ownerCache[(tableName, row.uuidRowId)] = owner;
      if (!owner.exists) {
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
      if (owner.spaceId != spaceId) {
        _throwPendingIntegrityViolation(
          crdtDataRowId: row.id,
          type: OfflineSyncViolationType.ownershipCollision,
          operation: OfflineSyncViolationOperation.outboundInsert,
          tableName: tableName,
          rowId: row.uuidRowId,
          ownerSpaceId: owner.spaceId,
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
        data: _decodeOutboundRow(
          session,
          table,
          dartName,
          columns!,
          attemptedValueFieldsByRowId[row.id!],
        ),
      );
    }
  }

  Stream<CrdtMergeUpdate> _streamUpdates(
    DatabaseSession session,
    Map<int, UuidValue> spaceUuidById,
    Map<int, List<Hlc>> checkpointsBySpaceId,
    DomainRowOwnerCache ownerCache,
    Transaction transaction,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      transaction: transaction,
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
        transaction,
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
    Transaction transaction,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      transaction: transaction,
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
        transaction,
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

  /// Loads outbound payloads in bounded batches within the metadata snapshot.
  /// Grouping by table and owning space preserves the original ownership filter.
  Future<Map<(String, int, UuidValue), Map<String, dynamic>>> _loadOutboundRows(
    DatabaseSession session,
    List<CrdtDataRow> rows,
    Transaction transaction,
  ) async {
    final groups = <(String, int), Set<UuidValue>>{};
    for (final row in rows) {
      final tableName = row.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName) ||
          !_classNamesByTableName.containsKey(tableName)) {
        continue;
      }
      groups.putIfAbsent((tableName, row.spaceId), () => {}).add(row.uuidRowId);
    }

    final payloads = <(String, int, UuidValue), Map<String, dynamic>>{};
    for (final entry in groups.entries) {
      final (tableName, spaceId) = entry.key;
      final table = _syncTablesByName[tableName]!;
      final columns = table.columns
          .map(
            (column) =>
                '${_outboundColumnExpression(session, column)} AS "${column.columnName.escapeIdentifier()}"',
          )
          .join(', ');
      final ids = entry.value.toList();
      const batchSize = 100;
      for (var start = 0; start < ids.length; start += batchSize) {
        final batch = ids.skip(start).take(batchSize).map((id) => id.sqlLiteral());
        final result = await session.db.unsafeQuery(
          'SELECT $columns FROM "${tableName.escapeIdentifier()}" '
          'WHERE "id" IN (${batch.join(', ')}) AND "spaceId" = ${spaceId.sqlLiteral()}',
          transaction: transaction,
        );
        for (final row in result) {
          final columns = row.toColumnMap();
          final id = _serializationManager.deserialize<UuidValue>(columns['id']);
          payloads[(tableName, spaceId, id)] = columns;
        }
      }
    }
    return payloads;
  }

  /// Decodes a domain row for outbound insert sync.
  ///
  /// Takes the materialized row from the domain table, then swaps any columns
  /// with an active [CrdtDataAttemptedValue] back to the authored value before
  /// deserializing. The domain table and projected columns are only known at
  /// runtime, so a generated repository cannot express this query. Keeping one
  /// targeted SQL projection also avoids fetching and serializing unrelated
  /// columns. This is the inverse of inbound FK materialization: the wire payload
  /// carries attempted facts, not locally projected visible values.
  Object _decodeOutboundRow(
    DatabaseSession session,
    Table table,
    String dartName,
    Map<String, dynamic> rawColumns,
    List<CrdtDataField>? attemptedValueFields,
  ) {
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
    return session.db.serializationManager.deserialize<Object>({
      ...columnMap,
      '__className__': dartName,
    });
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
    Transaction transaction,
  ) async {
    if (attempted != null) {
      final owner = await _readDomainRowOwner(
        session,
        tableName,
        rowId,
        ownerCache,
        transaction,
      );
      if (!owner.exists || owner.spaceId != spaceId) {
        return (exists: owner.exists, ownerSpaceId: owner.spaceId, value: null);
      }
      return (
        exists: true,
        ownerSpaceId: spaceId,
        value: attempted.value,
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
      transaction: transaction,
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

    final owner = await _readDomainRowOwner(
      session,
      tableName,
      rowId,
      ownerCache,
      transaction,
    );
    return (exists: owner.exists, ownerSpaceId: owner.spaceId, value: null);
  }

  Future<DomainRowOwner> _readDomainRowOwner(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    DomainRowOwnerCache ownerCache,
    Transaction transaction,
  ) async {
    final cached = ownerCache[(tableName, rowId)];
    if (cached != null) return cached;

    final encodedRowId = rowId.sqlLiteral();
    final escapedTableName = tableName.escapeIdentifier();
    final result = await session.db.unsafeQuery(
      'SELECT "spaceId" FROM "$escapedTableName" '
      'WHERE "id" = $encodedRowId '
      'LIMIT 1',
      transaction: transaction,
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
    Transaction transaction,
  ) async {
    final rowIds = {for (final row in rows) ?row.id};
    if (rowIds.isEmpty) return {};

    final fields = await CrdtDataField.db.find(
      session,
      transaction: transaction,
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

/// Exact facts received successfully on this stream, awaiting outbound scan.
/// Eviction only restores redundant traffic; it never implies peer progress.
class _ReceivedChanges {
  static const _maxEntries = 256;
  static const _maxCharacters = 128 * 1024;

  final _encoded = <String>{};
  var _characters = 0;

  void addAll(Iterable<String> changes) {
    for (final change in changes) {
      if (change.length > _maxCharacters || !_encoded.add(change)) continue;
      _characters += change.length;
      while (_encoded.length > _maxEntries || _characters > _maxCharacters) {
        final oldest = _encoded.first;
        _encoded.remove(oldest);
        _characters -= oldest.length;
      }
    }
  }

  bool remove(CrdtMergeChange change) {
    if (_encoded.isEmpty) return false;
    // Insert payloads can change while retaining their original insert HLC.
    // Match the complete payload, never just the row identity and clock.
    final encoded = jsonEncode(change);
    if (!_encoded.remove(encoded)) return false;
    _characters -= encoded.length;
    return true;
  }

  void clear() {
    _encoded.clear();
    _characters = 0;
  }
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
      this[field.column!.name] = attempted.value;
    }
  }
}
