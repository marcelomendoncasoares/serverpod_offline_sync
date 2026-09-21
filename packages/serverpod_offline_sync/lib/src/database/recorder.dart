import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../managers/hlc.dart';
import '../sync/engine.dart';
import '../sync/exceptions.dart';
import 'database.dart';
import 'merge_utils/database_helpers.dart';
import 'merge_utils/foreign_key_graph.dart';
import 'merge_utils/foreign_key_projector.dart';
import 'merge_utils/recorder_context.dart';
import 'merge_utils/types.dart';
import 'merge_utils/unique_resolver.dart';
import 'schema.dart';
import 'unique_index_utils.dart';

part 'merge.dart';

typedef _CrdtSchema = Map<String, (int, Map<String, CrdtSchemaColumn>)>;

/// Process-level CRDT database metadata shared by ephemeral database wrappers.
///
/// A single context is created per `OfflineSyncEngine` (i.e. once per Serverpod
/// instance) and shared by every ephemeral [OfflineSyncDatabase], so the schema is
/// synchronized once per process rather than once per `Session`.
///
/// The cached schema holds database-assigned identifiers and is never
/// invalidated for the lifetime of the context. This assumes the CRDT schema
/// rows stay stable while the process is alive, which holds for a normal server
/// whose database is not reset underneath it. If the schema rows are dropped and
/// re-created with different identifiers while the process lives, a new context
/// must be created.
class OfflineSyncDatabaseContext {
  /// Creates a [OfflineSyncDatabaseContext] for the configured synchronized tables.
  OfflineSyncDatabaseContext({
    required this.syncTables,
    required DatabaseSerializationManager serializationManager,
  }) : _tableDefinitions = serializationManager.getTargetTableDefinitions();

  /// The list of tables to sync with CRDT.
  final List<Table> syncTables;

  final List<TableDefinition> _tableDefinitions;

  _CrdtSchema? _schema;
  Future<_CrdtSchema>? _schemaFuture;
  var _registryChanged = false;

  /// Whether schema reconciliation inserted, updated, or deleted registry rows
  /// during this context's first [initialize].
  @internal
  bool get registryChanged => _registryChanged;

  /// Initializes shared schema rows and caches their generated identifiers.
  Future<void> initialize(DatabaseSession session) async {
    if (_schema != null) return;

    final schemaFuture = _schemaFuture ??= _loadSchema(session);
    try {
      _schema = await schemaFuture;
    } catch (_) {
      if (identical(_schemaFuture, schemaFuture)) {
        _schemaFuture = null;
      }
      rethrow;
    }
  }

  Future<_CrdtSchema> _loadSchema(DatabaseSession session) async {
    final schemaRegistry = CrdtSchemaRegistry(
      session,
      syncTables: syncTables,
      tableDefinitions: _tableDefinitions,
    );
    final (tableRows, columnRows) = await schemaRegistry.syncAndGetSchema();
    _registryChanged = schemaRegistry.registryChanged;

    final columnsByTableId = <int, Map<String, CrdtSchemaColumn>>{};
    for (final column in columnRows) {
      columnsByTableId.putIfAbsent(column.tblId, () => {})[column.name] = column;
    }

    return {
      for (final t in tableRows) t.name: (t.id!, columnsByTableId[t.id!] ?? {}),
    };
  }

  /// CRDT schema ids by table name: `tableName -> (tableId, columnsByName)`.
  @internal
  Map<String, (int, Map<String, CrdtSchemaColumn>)> get schema =>
      _schema ??
      (throw StateError(
        'The CRDT database has not been initialized. Call '
        'OfflineSyncDatabase.initialize() before using CRDT database operations.',
      ));

  /// Returns the local [CrdtSchemaTable] id for [tableName], or null when the
  /// table is not registered for CRDT synchronization.
  @internal
  int? tableIdForName(String tableName) => schema[tableName]?.$1;

  /// Synced tables by table name.
  @internal
  late final Map<String, Table> syncTableByName = {
    for (final t in syncTables) t.tableName: t,
  };

  /// Serverpod table definitions by table name.
  @internal
  late final Map<String, TableDefinition> tableDefinitionsByName = {
    for (final table in _tableDefinitions) table.name: table,
  };

  /// Column definitions by table name and column name.
  @internal
  late final Map<String, Map<String, ColumnDefinition>> columnsByTableAndName = {
    for (final table in tableDefinitionsByName.values)
      table.name: {for (final column in table.columns) column.name: column},
  };

  /// Column names of every synced table, used to space merge metadata lookups.
  @internal
  late final Map<String, Set<String>> syncedTableColumnNamesForMerge = {
    for (final MapEntry(key: k, value: cols) in columnsByTableAndName.entries)
      if (syncTableByName.containsKey(k))
        k: cols.keys.where((columnName) => columnName != 'spaceId').toSet(),
  };

  final _uniqueIndexesByTableName = <String, List<UniqueIndexConflictRelease>>{};

  /// The unique-index conflict release metadata for [tableDefinition].
  ///
  /// Cached per table for the lifetime of this context.
  @internal
  List<UniqueIndexConflictRelease> uniqueIndexesForTable(
    TableDefinition tableDefinition,
  ) {
    return _uniqueIndexesByTableName.putIfAbsent(
      tableDefinition.name,
      () => syncableUniqueIndexesForTable(
        tableDefinition,
        syncTableByName.keys.toSet(),
      ),
    );
  }

  /// Foreign key relationships derived from the schema.
  late final CrdtForeignKeyGraph foreignKeys = CrdtForeignKeyGraph(this);

  /// Whether the given table name is tracked by CRDT.
  @internal
  bool isCrdtTrackedTableName(String tableName) {
    return syncTableByName.containsKey(tableName);
  }

  /// The CRDT schema column for the given table and column names, if any.
  @internal
  CrdtSchemaColumn? schemaColumn(String tableName, String columnName) =>
      schema[tableName]?.$2[columnName];

  /// The CRDT schema column ids for the given table and column names.
  ///
  /// Columns without a CRDT schema entry are omitted from the result.
  @internal
  Map<String, int> schemaColumnIds(
    String tableName,
    Iterable<String> columnNames,
  ) => {
    for (final columnName in columnNames)
      columnName: ?schemaColumn(tableName, columnName)?.id,
  };

  /// The default value declared for the given column, if usable.
  @internal
  Object? defaultValueForColumn(String tableName, String columnName) {
    final column = columnsByTableAndName[tableName]?[columnName];
    if (column == null) return null;
    final defaultValue = column.columnDefault;
    if (defaultValue == null) return null;
    if (column.columnType == ColumnType.uuid) {
      final unquoted = defaultValue.replaceAll("'", '');
      if (unquoted == 'random' || unquoted == 'random_v7') return null;
      return UuidValue.withValidation(unquoted);
    }
    return defaultValue.replaceAll("'", '');
  }
}

/// Persists additional CRDT rows after a mutating ORM operation completes.
///
/// Callbacks receive the underlying database (not the CRDT proxy) and the
/// active transaction. Use that database for follow-up inserts so work is not
/// wrapped again by the proxy.
class CrdtMutationRecorder {
  /// Creates a [CrdtMutationRecorder] instance.
  CrdtMutationRecorder(
    Database db, {
    required OfflineSyncDatabaseContext context,
    required UuidValue? persistentUserId,
  }) : assert(
         db is! OfflineSyncDatabase,
         'The database must be the user database, not the CRDT database. '
         'Passing a CRDT database would cause an infinite recursion.',
       ),
       _db = db,
       _databaseContext = context,
       _context = CrdtRecorderContext(
         db,
         databaseContext: context,
         persistentUserId: persistentUserId,
       );

  final Database _db;
  final OfflineSyncDatabaseContext _databaseContext;
  final CrdtRecorderContext _context;
  late final _foreignKeys = _databaseContext.foreignKeys;
  late final _uniqueResolver = CrdtUniqueConflictResolver(_context);
  late final _foreignKeyProjector = CrdtForeignKeyProjector(
    _context,
    foreignKeys: _foreignKeys,
    uniqueResolver: _uniqueResolver,
  );

  Future<void>? _ensureInitializedFuture;
  var _isInitialized = false;

  DatabaseSession get _session => _context.databaseSession;

  /// Initializes the CRDT recorder.
  ///
  /// Clears this recorder's live space cache, then ensures the shared
  /// [OfflineSyncDatabaseContext] metadata is loaded. The shared schema is loaded only
  /// once per process and is not reloaded here; see [OfflineSyncDatabaseContext] for
  /// the cache lifetime assumptions.
  Future<void> initialize() async {
    _context.spaceManager.clearCache();
    _ensureInitializedFuture = null;
    _isInitialized = false;

    await ensureInitialized();
  }

  /// Ensures the recorder is ready without clearing live per-session caches.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    final initializeFuture = _ensureInitializedFuture ??= _initializeOnce();
    try {
      await initializeFuture;
    } catch (_) {
      if (identical(_ensureInitializedFuture, initializeFuture)) {
        _ensureInitializedFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initializeOnce() async {
    await _databaseContext.initialize(_session);
    if (_databaseContext.registryChanged) {
      await _rebuildProjectionsForAllSpaces();
    }
    if (persistentUserId != null) {
      await _context.spaceManager.getOrCreate(persistentUserId!);
    }
    _isInitialized = true;
  }

  Future<void> _rebuildProjectionsForAllSpaces() async {
    final spaces = await OfflineSyncSpace.db.find(
      _session,
      include: OfflineSyncSpace.include(currentNode: CrdtNode.include()),
    );
    for (final space in spaces) {
      if (space.currentNode == null || space.currentNodeId == null) continue;
      await _db.transaction((tx) async {
        spaceForTransaction[tx] = space;
        try {
          await _foreignKeyProjector.project(tx);
        } finally {
          spaceForTransaction.remove(tx);
        }
      });
    }
  }

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  UuidValue? get persistentUserId => _context.persistentUserId;

  /// The list of tables to sync with CRDT.
  List<Table> get syncTables => _context.syncTables;

  /// Returns the local [CrdtSchemaTable] id for [tableName], or null when the
  /// table is not registered for CRDT synchronization.
  int? tableIdForName(String tableName) => _context.tableIdForName(tableName);

  /// Whether the given table is tracked by CRDT.
  bool isCrdtTracked<T extends TableRow>([Table? table]) {
    final targetTable = table ?? _db.serializationManager.getTableForType(T);
    if (targetTable == null) return false;
    return _context.isCrdtTrackedTableName(targetTable.tableName);
  }

  /// Returns the user scoping CRDT visibility for queries, or null when no
  /// user is associated with [transaction] and no persistent user exists.
  OfflineSyncSpace? spaceForQueries(Transaction? transaction) {
    if (transaction != null) {
      final user = spaceForTransaction[transaction];
      if (user != null) return user;
    }
    final userId = persistentUserId;
    if (userId == null) return null;
    return _context.spaceManager.getCached(userId);
  }

  /// Returns the [OfflineSyncSpace] for the given user ID, creating it when needed.
  Future<OfflineSyncSpace> getOrCreateSpace(UuidValue userId) {
    return _context.spaceManager.getOrCreate(userId);
  }

  /// Whether a plain transaction can share an already initialized client node.
  bool get hasPersistentSpace => _isInitialized && persistentUserId != null;

  /// Shares the current-node clock within an atomic scope without reading it yet.
  Future<R> withCurrentNodeHlc<R>(
    Transaction transaction,
    TransactionFunction<R> action,
  ) => _context.withCurrentNodeHlc(transaction, action);

  /// Locks the node and refreshes its clock before the first tracked write or merge.
  Future<void> lockAndRefreshCurrentNodeHlc(Transaction transaction) =>
      _context.lockAndRefreshCurrentNodeHlc(transaction);

  /// Records the latest acknowledged sync checkpoint for [otherNodeId].
  Future<void> recordSyncCheckpoint(
    UuidValue userId,
    UuidValue otherNodeId,
    Hlc syncedHlc,
  ) async {
    final space = await _context.spaceManager.getOrCreate(userId);
    await _db.transaction((transaction) async {
      final node = await _context.findOrCreateNode(otherNodeId, transaction);
      final spaceNode = await _context.findOrCreateSpaceNode(
        space.id!,
        node.id!,
        transaction,
      );

      final currentSyncHlc = spaceNode.lastReceivedHlc;
      if (currentSyncHlc != null && currentSyncHlc >= syncedHlc) {
        return;
      }

      await OfflineSyncSpaceNode.db.updateRow(
        _session,
        spaceNode.copyWith(lastReceivedHlc: syncedHlc),
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );
    });
  }

  /// Recomputes FK/unique projection for currently stored rows.
  ///
  /// Used before upsert so hidden unique claims are released before the
  /// physical write can occupy the same index.
  Future<void> projectCurrent(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
  ) {
    return _foreignKeyProjector.project(
      transaction,
      seedTables: {tableName},
      seedRows: {for (final rowId in rowIds) (tableName, rowId)},
    );
  }

  /// Captures the materialized values before an upsert so its accepted writes
  /// can replace old attempted values without authoring unchanged projections.
  Future<({bool projectionUnchanged, Map<MergeRowKey, Map<String, Object?>> domain})>
  prepareLocalUpsert<T extends TableRow>(
    List<T> rows,
    List<Column> conflictColumns,
    List<Column>? updateColumns,
    Transaction transaction,
  ) async {
    final tableName = rows.first.table.tableName;
    final rowIds = {
      for (final row in rows)
        if (row.id case final UuidValue rowId) rowId,
    };
    final targetsPrimaryKey =
        conflictColumns.length == 1 && conflictColumns.single.columnName == 'id';
    const emptyDomain = <MergeRowKey, Map<String, Object?>>{};
    if (targetsPrimaryKey && rowIds.length == rows.length) {
      final stored = await _context.findCrdtRows(tableName, rowIds, transaction);
      if (stored.isEmpty &&
          !_foreignKeys.tablesWithDefaultDependencies.contains(tableName)) {
        // The full pass has no persisted seed or default to load. Classification
        // after the physical upsert still reads metadata again.
        validateAuthoredRows(rows, null);
        return (projectionUnchanged: false, domain: emptyDomain);
      }
      if (stored.length == rowIds.length &&
          await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
            rows,
            transaction,
            inserting: false,
            columns: updateColumns,
          )) {
        validateAuthoredRows(rows, updateColumns);
        return (projectionUnchanged: true, domain: emptyDomain);
      }
    }
    if (!targetsPrimaryKey && _foreignKeyProjector.needsProjection(tableName, null)) {
      final suppliedValues = [for (final row in rows) row.toJsonForDatabase() as Map];
      rowIds.addAll(
        await _context.findDomainRowIdsWhereColumnsIn(
          tableName: tableName,
          valuesByColumn: {
            for (final column in conflictColumns)
              if (column.columnName != 'spaceId')
                column.columnName: {
                  for (final values in suppliedValues)
                    canonicalDomainValue(
                      values[column.columnName],
                      _context.columnsByTableAndName[tableName]?[column.columnName],
                    ),
                },
          },
          transaction: transaction,
        ),
      );
    }
    final projected = await _foreignKeyProjector.project(
      transaction,
      seedTables: {tableName},
      // Other conflict targets can update an existing row with a different id.
      seedRows: {for (final rowId in rowIds) (tableName, rowId)},
    );
    if (_uniqueResolver.hasReservedUniqueColumns(tableName)) {
      final written = updateColumns?.map((column) => column.columnName).toSet();
      for (final row in rows) {
        final supplied = _authoredValuesFromRow(row, null);
        for (final MapEntry(key: column, value: value) in supplied.entries) {
          if (!_uniqueResolver.isReservedValue(tableName, column, value)) continue;
          final before =
              projected.domain[(tableName, row.id)] ??
              projected.domain.entries
                  .where(
                    (entry) =>
                        entry.key.$1 == tableName &&
                        conflictColumns.every(
                          (key) =>
                              key.columnName == 'spaceId' ||
                              (key.columnName == 'id'
                                  ? entry.key.$2 == row.id
                                  : projectionValuesEqual(
                                      entry.value[key.columnName],
                                      supplied[key.columnName],
                                    )),
                        ),
                  )
                  .firstOrNull
                  ?.value;
          if (before != null &&
              ((written != null && !written.contains(column)) ||
                  projectionValuesEqual(before[column], value))) {
            continue;
          }
          // A new claim must fail before the physical upsert can collide with
          // another row's generated value. Unchanged echoes are checked after
          // the write, when we know whether it updated or restored the row.
          _uniqueResolver.validateAuthoredValue(tableName, column, value);
        }
      }
    }
    return (projectionUnchanged: false, domain: projected.domain);
  }

  /// Plans FK/unique projection for rows that are about to be inserted.
  ///
  /// Releases hidden unique claims first and plans foreign key repairs while
  /// preserving submitted unique values for database constraint enforcement.
  /// Authored values that differ from the planned domain are returned so they
  /// can be stored as attempted values after the insert.
  Future<({List<T> rows, ProjectionAttemptsByField attempts})>
  planLocalInserts<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) async {
    const unplanned = <MergeFieldKey, ProjectionAttempt>{};
    final tableName = rows.firstOrNull?.table.tableName;
    if (tableName == null ||
        !_context.isCrdtTrackedTableName(tableName) ||
        !_foreignKeyProjector.needsProjection(tableName, null)) {
      return (rows: rows, attempts: unplanned);
    }

    validateAuthoredRows(rows, null);

    if (await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
      rows,
      transaction,
      inserting: true,
      persisted: false,
    )) {
      return (rows: rows, attempts: unplanned);
    }

    final hlcManager = _context.hlcManagerFor(transaction);
    final pendingHlc = hlcManager.peekNext();
    final node = hlcManager.getNode();
    // A row with no id yet takes a database-generated one, so there is nothing
    // to plan against: no stored row can be contesting a claim it cannot name.
    final pending = <PendingProjectionRow>[
      for (final row in rows)
        if (row.id case final UuidValue rowId)
          (
            tableName: tableName,
            rowId: rowId,
            authoredValues: _authoredValuesFromRow(row, null),
            rowHlc: pendingHlc,
            node: node,
            hidden: false,
          ),
    ];
    if (pending.isEmpty) return (rows: rows, attempts: unplanned);

    final planned = await _foreignKeyProjector.project(
      transaction,
      pendingInserts: pending,
      localWrite: true,
      seedTables: {tableName},
      seedRows: {for (final row in pending) (tableName, row.rowId)},
    );
    final attempts = <MergeFieldKey, ProjectionAttempt>{};
    for (final pendingRow in pending) {
      final plannedDomain =
          planned.domain[(pendingRow.tableName, pendingRow.rowId)] ??
          pendingRow.authoredValues;
      for (final MapEntry(key: columnName, value: authored)
          in pendingRow.authoredValues.entries) {
        if (projectionValuesEqual(plannedDomain[columnName], authored)) continue;
        final fieldKey = (pendingRow.tableName, pendingRow.rowId, columnName);
        final reason = planned.reasons[fieldKey];
        // No reason means projection did not choose this value. The planner
        // also returns the stored row for an id the insert will not create
        // (`ignoreConflicts`), and that difference is not an authored attempt.
        if (reason == null) continue;
        attempts[fieldKey] = (value: authored, reason: reason);
      }
    }
    return (
      rows: [
        for (final row in rows)
          if (row.id case final UuidValue rowId)
            _withPlannedDomainValues(row, planned.domain[(tableName, rowId)])
          else
            row,
      ],
      attempts: attempts,
    );
  }

  /// Plans FK/unique projection for rows that are about to be updated.
  Future<({List<T> rows, bool projectionUnchanged})>
  planLocalUpdates<T extends TableRow>(
    List<T> rows,
    List<Column>? columns,
    Transaction transaction, {
    bool restoring = false,
  }) async {
    if (rows.isEmpty) return (rows: rows, projectionUnchanged: true);
    final tableName = rows.first.table.tableName;
    if (!_context.isCrdtTrackedTableName(tableName)) {
      return (rows: rows, projectionUnchanged: true);
    }
    final columnNames = columns?.map((column) => column.columnName).toSet();
    if (!_foreignKeyProjector.needsProjection(tableName, columnNames)) {
      return (rows: rows, projectionUnchanged: true);
    }

    if (await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
      rows,
      transaction,
      inserting: false,
      columns: columns,
    )) {
      return (rows: rows, projectionUnchanged: true);
    }

    final authored = {
      for (final row in rows)
        if (row.id is UuidValue)
          for (final MapEntry(key: columnName, value: value) in _authoredValuesFromRow(
            row,
            columns,
          ).entries)
            (tableName, row.id as UuidValue, columnName): value,
    };
    var overlays = authored;
    if (columns == null) {
      final currentDomain = await _readPlannedDomainValues(
        tableName,
        {
          for (final row in rows)
            if (row.id is UuidValue) row.id as UuidValue,
        },
        {for (final fieldKey in authored.keys) fieldKey.$3},
        transaction,
      );
      overlays = {
        for (final MapEntry(key: fieldKey, value: value) in authored.entries)
          if (!projectionValuesEqual(
            currentDomain[fieldKey.$2]?[fieldKey.$3],
            value,
          ))
            fieldKey: value,
      };
    }
    _uniqueResolver.validateAuthoredFields(overlays);
    final planned = await _foreignKeyProjector.project(
      transaction,
      authoredOverlays: overlays,
      localWrite: true,
      restoringRows: {
        if (restoring)
          for (final row in rows) (tableName, row.id as UuidValue),
      },
      seedTables: {tableName},
      seedRows: {
        for (final row in rows)
          if (row.id case final UuidValue rowId) (tableName, rowId),
      },
    );
    return (
      projectionUnchanged: false,
      rows: [
        for (final row in rows)
          _withPlannedDomainValues(
            row,
            planned.domain[(tableName, row.id as UuidValue)],
          ),
      ],
    );
  }

  /// Validates unprojected ORM writes, or projected inserts with their attempts.
  void validateAuthoredRows<T extends TableRow>(
    List<T> rows,
    List<Column>? columns, {
    ProjectionAttemptsByField attempts = const {},
  }) {
    if (rows.isEmpty) return;
    final tableName = rows.first.table.tableName;
    if (!_uniqueResolver.hasReservedUniqueColumns(tableName)) return;
    for (final row in rows) {
      for (final MapEntry(key: columnName, value: value) in _authoredValuesFromRow(
        row,
        columns,
      ).entries) {
        final key = (tableName, row.id, columnName);
        _uniqueResolver.validateAuthoredValue(
          tableName,
          columnName,
          attempts.containsKey(key) ? attempts[key]!.value : value,
        );
      }
    }
  }

  Map<String, Object?> _authoredValuesFromRow<T extends TableRow>(
    T row,
    List<Column>? columns,
  ) {
    final json = row.toJsonForDatabase() as Map<String, dynamic>;
    final columnNames = [
      for (final column in (columns ?? row.table.managedColumns))
        if (column.columnName != 'id' && column.columnName != 'spaceId')
          column.columnName,
    ];
    return {
      for (final columnName in columnNames)
        columnName: canonicalDomainValue(
          json[columnName],
          _context.columnsByTableAndName[row.table.tableName]?[columnName],
        ),
    };
  }

  T _withPlannedDomainValues<T extends TableRow>(
    T row,
    Map<String, Object?>? planned,
  ) {
    if (planned == null || planned.isEmpty) return row;
    // Merge inserts are typed as [TableRow], and generated models are often a
    // private `_*Impl` subclass. Read `__className__` from the payload so
    // explicit nulls (e.g. a missing-parent FK) are applied.
    final data = Map<String, dynamic>.from(row.toJson() as Map);
    for (final column in row.table.crdtSyncableColumns) {
      if (planned.containsKey(column.columnName)) {
        data[column.fieldName] = planned[column.columnName];
      }
    }
    // Ask the serialization manager for the name it resolves this row by. A
    // model from a shared package writes its own unprefixed `__className__`,
    // while the host protocol only answers to the prefixed form.
    final className =
        _session.db.serializationManager.getClassNameForObject(row) ??
        data['__className__'] as String?;
    data.remove('__className__');
    if (className == null) {
      throw StateError(
        'Cannot apply planned domain values: ${row.runtimeType} has no class name.',
      );
    }
    return _session.db.serializationManager.deserializeByClassName({
          'className': className,
          'data': data,
        })
        as T;
  }

  /// Supplies fixed UUID FK defaults before building a local upsert. SQLite's
  /// upsert builder cannot emit DEFAULT inside VALUES. Resolve the same schema
  /// default that an insert would use, leaving other fields to the ORM.
  List<T> withForeignKeyInsertDefaults<T extends TableRow>(List<T> rows) => [
    for (final row in rows)
      _withPlannedDomainValues(row, {
        for (final edge
            in _foreignKeys.edgesByChildTable[row.table.tableName] ??
                const <ForeignKeyEdge>[])
          if ((row.toJsonForDatabase() as Map)[edge.childColumn] == null)
            if (_context.defaultValueForColumn(
                  row.table.tableName,
                  edge.childColumn,
                )
                case final UuidValue value)
              edge.childColumn: value,
      }),
  ];

  Future<Map<UuidValue, Map<String, Object?>>> _readPlannedDomainValues(
    String tableName,
    Set<UuidValue> rowIds,
    Set<String> columnNames,
    Transaction transaction,
  ) {
    if (rowIds.isEmpty || columnNames.isEmpty) {
      return Future.value(const {});
    }
    return _context.readDomainColumnValues(
      tableName,
      rowIds,
      columnNames.toList(),
      transaction,
    );
  }

  /// Insert the CRDT metadata for the inserted rows.
  Future<void> afterInsert<T extends TableRow>(
    List<T> insertedRows,
    Transaction transaction, {
    ProjectionAttemptsByField attempts = const {},
  }) async {
    validateAuthoredRows(insertedRows, null, attempts: attempts);
    await _forTrackedRows(insertedRows, transaction, (
      tableName,
      rowIds,
      hlcManager,
    ) async {
      final (tableId, _) = _context.schema[tableName]!;

      await CrdtDataRow.db.insert(
        _session,
        [for (final rowId in rowIds) _newCrdtDataRow(tableId, rowId, hlcManager)],
        transaction: transaction,
        ignoreConflicts: true,
      );

      await _foreignKeyProjector.recordInsertAttempts(
        tableName,
        rowIds,
        transaction,
        attempts,
      );
      if (_foreignKeyProjector.needsProjection(tableName, null) &&
          !await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
            insertedRows,
            transaction,
            inserting: true,
          )) {
        await _maybeProject(tableName, rowIds, null, transaction);
      }
    });
  }

  /// Records a row insertion that reused an existing tombstoned domain row.
  Future<void> afterReinsert<T extends TableRow>(
    List<T> reinsertedRows,
    Transaction transaction,
  ) async {
    await _forTrackedRows(reinsertedRows, transaction, (
      tableName,
      rowIds,
      hlcManager,
    ) async {
      final crdtDataRows = await _touchCrdtRows(
        await _context.findRequiredCrdtRows(
          tableName,
          rowIds,
          'reinserted',
          transaction,
        ),
        hlcManager,
        transaction,
      );
      // A reinsert authors the complete row at its new insertion timestamp.
      // Retain attempted values while projecting, but discard their old ages.
      await _context.resetReinsertedFieldClocks(crdtDataRows, transaction);
      await _context.markCrdtRowsDeleted(
        crdtDataRows,
        false,
        CrdtDataDeletedReason.userReinsert,
        transaction,
      );
      await _maybeProject(tableName, rowIds, null, transaction);
      // Only projected fields need a metadata row to hold their authored value.
      // All other fields now inherit the insertion timestamp implicitly.
      await CrdtDataField.db.deleteWhere(
        _session,
        where: (t) =>
            t.rowId.inSet(crdtDataRows.map((row) => row.id!).toSet()) &
            t.attemptedValue.id.equals(null),
        transaction: transaction,
        noReturn: true,
      );
    });
  }

  /// Records CRDT field metadata for updated rows.
  ///
  /// [authoredColumnValues] marks a write that reached the domain without a
  /// planning pass, which is the set-based `updateWhere`. Every accepted column
  /// value it carries is authored, so it overlays the attempted value a
  /// projection is holding for the same field. Without the overlay the pass
  /// below would read that stale attempt as the authored value and restore it
  /// over the write.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction, {
    bool projectionUnchanged = false,
    bool authoredColumnValues = false,
    Map<MergeRowKey, Map<String, Object?>> domainBeforeUpsert = const {},
    List<TableRow> upsertRows = const [],
  }) async {
    await _foreignKeyProjector.assertVisibleTargets(updatedRows, columns, transaction);

    await _forTrackedRows(updatedRows, transaction, (
      tableName,
      rowIds,
      _,
    ) async {
      final crdtDataRows = await _context.findRequiredCrdtRows(
        tableName,
        rowIds,
        'updated',
        transaction,
      );
      final implicitForeignKeyRepairFields = columns == null
          ? await _foreignKeyProjector.findImplicitRepairFields(
              tableName: tableName,
              rowIds: rowIds,
              transaction: transaction,
            )
          : const <MergeFieldKey>{};
      final upsertInputs = upsertRows.isEmpty || implicitForeignKeyRepairFields.isEmpty
          ? const <MergeRowKey, Map<String, Object?>>{}
          : {
              for (final row in upsertRows)
                if (row.id case final UuidValue rowId)
                  (row.table.tableName, rowId):
                      row.toJsonForDatabase() as Map<String, dynamic>,
            };
      // Insert defaults must not author over an echoed null that is holding
      // a projected FK claim.
      bool echoesProjectedNull(UuidValue rowId, String columnName) {
        if (!implicitForeignKeyRepairFields.contains((tableName, rowId, columnName))) {
          return false;
        }
        final input = upsertInputs[(tableName, rowId)];
        return input != null &&
            input[columnName] == null &&
            domainBeforeUpsert[(tableName, rowId)]?[columnName] == null;
      }

      // Explicit columns author even an unchanged null; full-row passthrough
      // keeps the claim behind an unchanged displayed alternative.
      final authoredOverlays = <MergeFieldKey, Object?>{
        if (authoredColumnValues)
          for (final row in updatedRows)
            for (final MapEntry(key: columnName, value: value)
                in _authoredValuesFromRow(row, columns).entries)
              (tableName, row.id as UuidValue, columnName): value
        else
          // Only rows returned by the physical upsert were accepted by its
          // `updateWhere` predicate.
          for (final row in updatedRows)
            if (domainBeforeUpsert.containsKey((tableName, row.id)))
              for (final MapEntry(key: columnName, value: value)
                  in _authoredValuesFromRow(row, columns).entries)
                if ((domainBeforeUpsert[(tableName, row.id)]?.containsKey(columnName) ??
                        false) &&
                    (columns != null ||
                        (!projectionValuesEqual(
                              domainBeforeUpsert[(tableName, row.id)]![columnName],
                              value,
                            ) &&
                            !echoesProjectedNull(row.id as UuidValue, columnName))))
                  (tableName, row.id as UuidValue, columnName): value,
      };
      _uniqueResolver.validateAuthoredFields(authoredOverlays);
      await _recordUpdatedFields(
        updatedRows,
        crdtDataRows,
        columns,
        transaction,
        skippedFields: implicitForeignKeyRepairFields.difference(
          authoredOverlays.keys.toSet(),
        ),
      );
      if (projectionUnchanged &&
          await _foreignKeyProjector.canLeaveLocalProjectionUnchanged(
            updatedRows,
            transaction,
            inserting: false,
            columns: columns,
          )) {
        return;
      }
      final updatedColumnNames = columns?.map((column) => column.columnName).toSet();
      await _maybeProject(
        tableName,
        rowIds,
        updatedColumnNames,
        transaction,
        authoredOverlays: authoredOverlays,
      );
    });
  }

  Future<void> _maybeProject(
    String tableName,
    Set<UuidValue> rowIds,
    Set<String>? columnNames,
    Transaction transaction, {
    Map<MergeFieldKey, Object?> authoredOverlays = const {},
  }) async {
    if (_foreignKeyProjector.needsProjection(tableName, columnNames)) {
      await _foreignKeyProjector.project(
        transaction,
        seedTables: {tableName},
        seedRows: {for (final rowId in rowIds) (tableName, rowId)},
        authoredOverlays: authoredOverlays,
      );
    }
  }

  Future<void> _forTrackedRows<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
    Future<void> Function(
      String tableName,
      Set<UuidValue> rowIds,
      HlcManager hlcManager,
    )
    record,
  ) async {
    if (rows.isEmpty) return;
    if (!isCrdtTracked<T>(rows.first.table)) return;

    final hlcManager = _context.hlcManagerFor(transaction);
    await record(
      rows.first.table.tableName,
      rows.uuidRowIds,
      hlcManager,
    );
    await _context.persistCurrentNodeHlc(hlcManager, transaction);
  }

  CrdtDataRow _newCrdtDataRow(
    int tableId,
    UuidValue rowId,
    HlcManager hlcManager,
  ) {
    final hlc = hlcManager.increment();

    return CrdtDataRow(
      spaceId: hlcManager.normalizedSpaceId,
      tblId: tableId,
      uuidRowId: rowId,
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  Future<List<CrdtDataRow>> _touchCrdtRows(
    List<CrdtDataRow> rows,
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return [];

    return CrdtDataRow.db.update(
      _session,
      [for (final row in rows) _context.withNextHlc(row, hlcManager)],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
  }

  Future<void> _recordUpdatedFields<T extends TableRow>(
    List<T> updatedRows,
    List<CrdtDataRow> crdtDataRows,
    List<Column>? columns,
    Transaction transaction, {
    Set<MergeFieldKey> skippedFields = const {},
  }) async {
    if (updatedRows.isEmpty || crdtDataRows.isEmpty) return;

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final table = updatedRows.first.table;
    final updatedColumnList = (columns ?? table.managedColumns).crdtSyncableColumns
        .toList();
    if (updatedColumnList.isEmpty) return;

    final (_, colMap) = _context.schema[table.tableName]!;
    final schemaColumns = [
      for (final column in updatedColumnList)
        colMap[column.columnName] ??
            (throw StateError(
              'No CRDT schema column for ${table.tableName}.${column.columnName}',
            )),
    ];
    await _context.upsertCrdtFieldsForRows(
      table.tableName,
      [
        for (final row in updatedRows) crdtDataRowByUuid[row.id as UuidValue]!,
      ],
      schemaColumns,
      transaction,
      skippedFields: skippedFields,
    );
  }

  /// Soft-deletes rows by recording a tombstone instead of removing them.
  ///
  /// Expects a matching [CrdtDataRow] per domain row (`uuidRowId` = domain id).
  Future<void> insteadOfDelete<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {
    if (deletedRows.isEmpty) return;
    if (!isCrdtTracked<T>(deletedRows.first.table)) return;
    final tableName = deletedRows.first.table.tableName;
    await _softDeleteRowsByTable(
      tableName,
      deletedRows.uuidRowIds,
      transaction,
      null,
      CrdtDataDeletedReason.userDelete,
    );
    await _maybeProject(
      tableName,
      deletedRows.uuidRowIds,
      null,
      transaction,
    );
    await _context.persistCurrentNodeHlc(
      _context.hlcManagerFor(transaction),
      transaction,
    );
  }

  Future<void> _softDeleteRowsByTable(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    Set<String>? processedRowIds,
    CrdtDataDeletedReason reason,
  ) async {
    if (rowIds.isEmpty) return;
    if (!_context.isCrdtTrackedTableName(tableName)) return;

    final processing = processedRowIds ?? {};
    final unprocessedRowIds = rowIds
        .where((rowId) => processing.add('$tableName:$rowId'))
        .toSet();

    if (unprocessedRowIds.isEmpty) return;

    final crdtDataRows = await _context.findRequiredCrdtRows(
      tableName,
      unprocessedRowIds,
      'deleted',
      transaction,
      includeDeleted: true,
    );

    try {
      final visibleCrdtRows = crdtDataRows.where((row) => !row.isHidden).toList();

      if (visibleCrdtRows.isEmpty) return;
      final visibleRowIds = visibleCrdtRows.map((row) => row.uuidRowId).toSet();

      final cascadeDeletes = await _foreignKeyProjector.applyDeleteActions(
        tableName,
        visibleRowIds,
        transaction,
        processing,
      );
      await _context.markCrdtRowsDeleted(visibleCrdtRows, true, reason, transaction);
      for (final MapEntry(key: childTableName, value: childIds)
          in cascadeDeletes.entries) {
        await _softDeleteRowsByTable(
          childTableName,
          childIds,
          transaction,
          processing,
          CrdtDataDeletedReason.userCascadeDelete,
        );
      }
    } finally {
      for (final rowId in unprocessedRowIds) {
        processing.remove('$tableName:$rowId');
      }
    }
  }

  /// IDs of the given rows that are soft-deleted.
  Future<Set<UuidValue>> deletedRowIds<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) async {
    final rowIds = {
      for (final row in rows)
        if (row.id is UuidValue) row.id as UuidValue,
    };
    if (rowIds.isEmpty) return {};

    final table = rows.first.table;
    if (!isCrdtTracked<T>(table)) return {};

    final crdtRows = await _context.findCrdtRows(
      table.tableName,
      rowIds,
      transaction,
    );
    return {
      for (final row in crdtRows)
        if (row.isHidden) row.uuidRowId,
    };
  }
}
