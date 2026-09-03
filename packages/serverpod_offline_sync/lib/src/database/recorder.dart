import 'package:clock/clock.dart';
import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../crdt/exceptions.dart';
import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../crdt/sync.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../managers/hlc.dart';
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
/// A single context is created per `CrdtSync` (i.e. once per Serverpod
/// instance) and shared by every ephemeral [CrdtDatabase], so the schema is
/// synchronized once per process rather than once per `Session`.
///
/// The cached schema holds database-assigned identifiers and is never
/// invalidated for the lifetime of the context. This assumes the CRDT schema
/// rows stay stable while the process is alive, which holds for a normal server
/// whose database is not reset underneath it. If the schema rows are dropped and
/// re-created with different identifiers while the process lives, a new context
/// must be created.
class CrdtDatabaseContext {
  /// Creates a [CrdtDatabaseContext] for the configured synchronized tables.
  CrdtDatabaseContext({
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
        'CrdtDatabase.initialize() before using CRDT database operations.',
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

  /// Column names of every synced table, used to scope merge metadata lookups.
  @internal
  late final Map<String, Set<String>> syncedTableColumnNamesForMerge = {
    for (final MapEntry(key: k, value: cols) in columnsByTableAndName.entries)
      if (syncTableByName.containsKey(k))
        k: cols.keys.where((columnName) => columnName != 'scopeId').toSet(),
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
    required CrdtDatabaseContext context,
    required UuidValue? persistentUserId,
  }) : assert(
         db is! CrdtDatabase,
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
  final CrdtDatabaseContext _databaseContext;
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
  /// Clears this recorder's live scope/HLC caches, then ensures the shared
  /// [CrdtDatabaseContext] metadata is loaded. The shared schema is loaded only
  /// once per process and is not reloaded here; see [CrdtDatabaseContext] for
  /// the cache lifetime assumptions.
  Future<void> initialize() async {
    _context.scopeManager.clearCache();
    _context.clearHlcManagers();
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
      await _rebuildProjectionsForAllScopes();
    }
    if (persistentUserId != null) {
      await _context.scopeManager.getOrCreate(persistentUserId!);
    }
    _isInitialized = true;
  }

  Future<void> _rebuildProjectionsForAllScopes() async {
    final scopes = await CrdtScope.db.find(
      _session,
      include: CrdtScope.include(currentNode: CrdtNode.include()),
    );
    for (final scope in scopes) {
      if (scope.currentNode == null || scope.currentNodeId == null) continue;
      await _db.transaction((tx) async {
        scopeForTransaction[tx] = scope;
        try {
          await _foreignKeyProjector.project(tx);
        } finally {
          scopeForTransaction.remove(tx);
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
  CrdtScope? scopeForQueries(Transaction? transaction) {
    if (transaction != null) {
      final user = scopeForTransaction[transaction];
      if (user != null) return user;
    }
    final userId = persistentUserId;
    if (userId == null) return null;
    return _context.scopeManager.getCached(userId);
  }

  /// Returns the [CrdtScope] for the given user ID, creating it when needed.
  Future<CrdtScope> getOrCreateScope(UuidValue userId) {
    return _context.scopeManager.getOrCreate(userId);
  }

  /// Records the latest acknowledged sync checkpoint for [otherNodeId].
  Future<void> recordSyncCheckpoint(
    UuidValue userId,
    UuidValue otherNodeId,
    Hlc syncedHlc,
  ) async {
    final scope = await _context.scopeManager.getOrCreate(userId);
    await _db.transaction((transaction) async {
      final node = await _context.findOrCreateNode(otherNodeId, transaction);
      final scopeNode = await _context.findOrCreateScopeNode(
        scope.id!,
        node.id!,
        transaction,
      );

      final currentSyncHlc = scopeNode.lastReceivedHlc;
      if (currentSyncHlc != null && currentSyncHlc >= syncedHlc) {
        return;
      }

      await CrdtScopeNode.db.updateRow(
        _session,
        scopeNode.copyWith(lastReceivedHlc: syncedHlc),
        columns: (t) => [t.lastReceivedHlc],
        transaction: transaction,
      );
    });
  }

  /// Recomputes FK/unique projection for currently stored rows.
  ///
  /// Used before upsert so hidden unique claims are released before the
  /// physical write can occupy the same index.
  Future<void> projectCurrent(Transaction transaction) {
    return _foreignKeyProjector.project(transaction);
  }

  /// Plans FK/unique projection for rows that are about to be inserted.
  ///
  /// Releases hidden unique claims first and returns copies whose unique/FK
  /// columns already hold the planned domain values, so the physical write
  /// cannot violate an immediate unique index. Authored values that differ
  /// from the planned domain are returned so they can be stored as attempted
  /// values after the insert.
  Future<({List<T> rows, ProjectionAttemptsByField attempts})> planLocalInserts<T
      extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) {
      return (rows: rows, attempts: const <MergeFieldKey, ProjectionAttempt>{});
    }
    final tableName = rows.first.table.tableName;
    if (!_context.isCrdtTrackedTableName(tableName)) {
      return (rows: rows, attempts: const <MergeFieldKey, ProjectionAttempt>{});
    }
    if (!_foreignKeyProjector.needsProjection(tableName, null)) {
      return (rows: rows, attempts: const <MergeFieldKey, ProjectionAttempt>{});
    }

    final hlcManager = _context.hlcManagerFor(transaction);
    final pendingHlc = hlcManager.peekNext();
    final node = hlcManager.getNode();
    final pending = <PendingProjectionRow>[
      for (final row in rows)
        if (row.id is UuidValue)
          (
            tableName: tableName,
            rowId: row.id as UuidValue,
            authoredValues: _authoredValuesFromRow(row, null),
            rowHlc: pendingHlc,
            node: node,
            hidden: false,
          ),
    ];
    if (pending.isEmpty) {
      return (rows: rows, attempts: const <MergeFieldKey, ProjectionAttempt>{});
    }

    final planned = await _foreignKeyProjector.project(
      transaction,
      pendingInserts: pending,
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
          _withPlannedDomainValues(
            row,
            planned.domain[(tableName, row.id as UuidValue)],
          ),
      ],
      attempts: attempts,
    );
  }

  /// Plans FK/unique projection for rows that are about to be updated.
  Future<List<T>> planLocalUpdates<T extends TableRow>(
    List<T> rows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return rows;
    final tableName = rows.first.table.tableName;
    if (!_context.isCrdtTrackedTableName(tableName)) return rows;
    final columnNames = columns?.map((column) => column.columnName).toSet();
    if (!_foreignKeyProjector.needsProjection(tableName, columnNames)) {
      return rows;
    }

    final authored = {
      for (final row in rows)
        if (row.id is UuidValue)
          for (final MapEntry(key: columnName, value: value)
              in _authoredValuesFromRow(row, columns).entries)
            (tableName, row.id as UuidValue, columnName): canonicalDomainValue(
              value,
            ),
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
    final planned = await _foreignKeyProjector.project(
      transaction,
      authoredOverlays: overlays,
    );
    return [
      for (final row in rows)
        _withPlannedDomainValues(
          row,
          planned.domain[(tableName, row.id as UuidValue)],
        ),
    ];
  }

  Map<String, Object?> _authoredValuesFromRow<T extends TableRow>(
    T row,
    List<Column>? columns,
  ) {
    final json = row.toJsonForDatabase() as Map<String, dynamic>;
    final columnNames = [
      for (final column in (columns ?? row.table.managedColumns))
        if (column.columnName != 'id' && column.columnName != 'scopeId')
          column.columnName,
    ];
    return {
      for (final columnName in columnNames) columnName: json[columnName],
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
    final className = data.remove('__className__') as String?;
    if (className == null) {
      throw StateError(
        'Cannot apply planned domain values: ${row.runtimeType} has no class name.',
      );
    }
    return _session.db.serializationManager.deserializeByClassName({
      'className': className,
      'data': data,
    }) as T;
  }

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
      await _maybeProject(tableName, null, transaction);
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
      final crdtDataRows = await _context.findRequiredCrdtRows(
        tableName,
        rowIds,
        'reinserted',
        transaction,
      );

      await _touchCrdtRows(crdtDataRows, hlcManager, transaction);
      await _context.markCrdtRowsDeleted(
        crdtDataRows,
        false,
        CrdtDataDeletedReason.userReinsert,
        transaction,
      );
      // Every field to skip carries an attempted value: a repaired foreign key
      // and a restored authored value are both subsets of that set, over a
      // subset of its columns.
      final skippedFields = await _foreignKeyProjector.findActiveAttemptedFields(
        tableName: tableName,
        rowIds: rowIds,
        transaction: transaction,
      );
      // Reinsert is a full-row passthrough. Projected unique/FK columns must
      // keep their original claim HLC so restoration can reclaim or lose
      // without authoring a newer unique claim.
      await _recordUpdatedFields(
        reinsertedRows,
        crdtDataRows,
        null,
        transaction,
        skippedFields: skippedFields,
      );
      await _foreignKeyProjector.recordAttemptsForRows(
        tableName,
        rowIds,
        null,
        transaction,
      );
      await _maybeProject(tableName, null, transaction);
    });
  }

  /// Records CRDT field metadata for updated rows.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
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
      await _recordUpdatedFields(
        updatedRows,
        crdtDataRows,
        columns,
        transaction,
        skippedFields: implicitForeignKeyRepairFields,
      );
      final updatedColumnNames = columns?.map((column) => column.columnName).toSet();
      await _foreignKeyProjector.recordAttemptsForRows(
        tableName,
        rowIds,
        updatedColumnNames,
        transaction,
        skippedFields: implicitForeignKeyRepairFields,
      );
      await _maybeProject(
        tableName,
        updatedColumnNames,
        transaction,
      );
    });
  }

  Future<void> _maybeProject(
    String tableName,
    Set<String>? columnNames,
    Transaction transaction,
  ) async {
    if (_foreignKeyProjector.needsProjection(tableName, columnNames)) {
      await _foreignKeyProjector.project(transaction);
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
      scopeId: hlcManager.normalizedScopeId,
      tblId: tableId,
      uuidRowId: rowId,
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  Future<void> _touchCrdtRows(
    List<CrdtDataRow> rows,
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;

    await CrdtDataRow.db.update(
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
    await _maybeProject(tableName, null, transaction);
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
