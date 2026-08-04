import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../crdt/exceptions.dart';
import '../crdt/extensions.dart';
import '../crdt/merge.dart';
import '../generated/protocol.dart';
import '../hlc/hlc.dart';
import '../managers/hlc.dart';
import '../managers/scope.dart';
import 'database.dart';
import 'schema.dart';
import 'session.dart';
import 'unique_index_utils.dart';

part 'merge.dart';
part 'merge_utils/foreign_key_projector.dart';
part 'merge_utils/unique_resolver.dart';

typedef _ReferencingForeignKey = ({
  String childTableName,
  String childColumn,
  String parentColumn,
  ForeignKeyAction action,
});

typedef _ForeignKeyEdge = ({
  String childTableName,
  String childColumn,
  String parentTableName,
  String parentColumn,
  ForeignKeyAction action,
  bool childNullable,
  Object? defaultValue,
});

typedef _ForeignKeyValueKey = (String tableName, String columnName, String value);

typedef _UniqueIndexConflictRelease = ({
  List<String> indexedColumns,
  List<_UniqueColumnConflictRelease> releaseColumns,
  bool scoped,
});

typedef _UniqueColumnConflictRelease = ({
  String columnName,
  CrdtUniqueConflictReleaseKind kind,
});

enum _ForeignKeyTargetPresence {
  absent,
  visible,
  hidden,
}

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

    final columnsByTableId = <int, Map<String, CrdtSchemaColumn>>{};
    for (final column in columnRows) {
      columnsByTableId.putIfAbsent(column.tblId, () => {})[column.name] = column;
    }

    return {
      for (final t in tableRows) t.name: (t.id!, columnsByTableId[t.id!] ?? {}),
    };
  }

  _CrdtSchema get _schemaSnapshot =>
      _schema ??
      (throw StateError(
        'The CRDT database has not been initialized. Call '
        'CrdtDatabase.initialize() before using CRDT database operations.',
      ));

  /// Returns the local [CrdtSchemaTable] id for [tableName], or null when the
  /// table is not registered for CRDT synchronization.
  int? _tableIdForName(String tableName) => _schemaSnapshot[tableName]?.$1;

  late final Map<String, Table> _syncTableByName = {
    for (final t in syncTables) t.tableName: t,
  };

  late final Map<String, TableDefinition> _tableDefinitionsByName = {
    for (final table in _tableDefinitions) table.name: table,
  };

  late final Map<String, Map<String, ColumnDefinition>> _columnsByTableAndName = {
    for (final table in _tableDefinitionsByName.values)
      table.name: {for (final column in table.columns) column.name: column},
  };

  late final Map<String, Set<String>> _syncedTableColumnNamesForMerge = {
    for (final MapEntry(key: k, value: cols) in _columnsByTableAndName.entries)
      if (_syncTableByName.containsKey(k))
        k: cols.keys.where((columnName) => columnName != 'scopeId').toSet(),
  };

  late final Map<String, List<_ReferencingForeignKey>> _foreignKeysByReferencedTable =
      () {
        final result = <String, List<_ReferencingForeignKey>>{};
        for (final table in _tableDefinitionsByName.values) {
          final childTableName = table.name;
          // Untracked children have no CRDT schema rows and cannot be
          // soft-deleted; their physical rows keep referencing the (physically
          // preserved) soft-deleted parent, so no delete action applies.
          // Interim behavior: docs/sync-non-sync-relations.md forbids
          // non-synced -> synced relations outright, but its initialize()
          // validation is not implemented yet.
          if (!_isCrdtTrackedTableName(childTableName)) continue;
          for (final foreignKey in table.foreignKeys) {
            if (foreignKey.columns.length != 1 ||
                foreignKey.referenceColumns.length != 1) {
              throw StateError(
                'Composite foreign keys are not supported for CRDT soft deletes.',
              );
            }

            result.putIfAbsent(foreignKey.referenceTable, () => []).add((
              childTableName: childTableName,
              childColumn: foreignKey.columns.single,
              parentColumn: foreignKey.referenceColumns.single,
              action: foreignKey.onDelete ?? ForeignKeyAction.noAction,
            ));
          }
        }
        return result;
      }();

  late final List<_ForeignKeyEdge> _foreignKeyEdges = [
    for (final table in _tableDefinitionsByName.values)
      if (_isCrdtTrackedTableName(table.name))
        for (final foreignKey in table.foreignKeys)
          if (foreignKey.columns.length == 1 &&
              foreignKey.referenceColumns.length == 1 &&
              _isCrdtTrackedTableName(foreignKey.referenceTable))
            (
              childTableName: table.name,
              childColumn: foreignKey.columns.single,
              parentTableName: foreignKey.referenceTable,
              parentColumn: foreignKey.referenceColumns.single,
              action: foreignKey.onDelete ?? ForeignKeyAction.noAction,
              childNullable:
                  _columnsByTableAndName[table.name]![foreignKey.columns.single]!
                      .isNullable,
              defaultValue: _defaultValueForColumn(
                table.name,
                foreignKey.columns.single,
              ),
            ),
  ];

  late final Map<String, List<_ForeignKeyEdge>> _foreignKeyEdgesByParentTable = {
    for (final tableName in _tableDefinitionsByName.keys)
      tableName: [
        for (final edge in _foreignKeyEdges)
          if (edge.parentTableName == tableName) edge,
      ],
  };

  late final Map<String, List<_ForeignKeyEdge>> _foreignKeyEdgesByChildTable = {
    for (final tableName in _tableDefinitionsByName.keys)
      tableName: [
        for (final edge in _foreignKeyEdges)
          if (edge.childTableName == tableName) edge,
      ],
  };

  final _uniqueIndexesByTableName = <String, List<_UniqueIndexConflictRelease>>{};

  bool _isCrdtTrackedTableName(String tableName) {
    return _syncTableByName.containsKey(tableName);
  }

  Object? _defaultValueForColumn(String tableName, String columnName) {
    final column = _columnsByTableAndName[tableName]?[columnName];
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
    this._db, {
    required CrdtDatabaseContext context,
    required this.persistentUserId,
  }) : _context = context,
       assert(
         _db is! CrdtDatabase,
         'The database must be the user database, not the CRDT database. '
         'Passing a CRDT database would cause an infinite recursion.',
       );

  final Database _db;
  final CrdtDatabaseContext _context;

  /// The raw database session used for CRDT metadata reads and writes.
  late final _session = _db.session;

  late final _scopeManager = CrdtScopeManager(_session);

  final Map<UuidValue, HlcManager> _hlcManagers = {};
  Future<void>? _ensureInitializedFuture;
  var _isInitialized = false;

  _CrdtSchema get _schema => _context._schemaSnapshot;
  Map<String, TableDefinition> get _tableDefinitionsByName =>
      _context._tableDefinitionsByName;

  /// Initializes the CRDT recorder.
  ///
  /// Clears this recorder's live scope/HLC caches, then ensures the shared
  /// [CrdtDatabaseContext] metadata is loaded. The shared schema is loaded only
  /// once per process and is not reloaded here; see [CrdtDatabaseContext] for
  /// the cache lifetime assumptions.
  Future<void> initialize() async {
    _scopeManager.clearCache();
    _hlcManagers.clear();
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
    await _context.initialize(_session);
    if (persistentUserId != null) {
      await _scopeManager.getOrCreate(persistentUserId!);
    }
    _isInitialized = true;
  }

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  /// The list of tables to sync with CRDT.
  List<Table> get syncTables => _context.syncTables;

  Map<String, Table> get _syncTableByName => _context._syncTableByName;

  Map<String, Set<String>> get _syncedTableColumnNamesForMerge =>
      _context._syncedTableColumnNamesForMerge;

  /// Whether the given table is tracked by CRDT.
  bool isCrdtTracked<T extends TableRow>([Table? table]) {
    final targetTable = table ?? _db.serializationManager.getTableForType(T);
    if (targetTable == null) return false;
    return _isCrdtTrackedTableName(targetTable.tableName);
  }

  /// Whether the given table name is tracked by CRDT.
  bool _isCrdtTrackedTableName(String tableName) {
    return _context._isCrdtTrackedTableName(tableName);
  }

  /// Returns the local [CrdtSchemaTable] id for [tableName], or null when the
  /// table is not registered for CRDT synchronization.
  int? tableIdForName(String tableName) => _context._tableIdForName(tableName);

  /// Returns the user scoping CRDT visibility for queries, or null when no
  /// user is associated with [transaction] and no persistent user exists.
  CrdtScope? scopeForQueries(Transaction? transaction) {
    if (transaction != null) {
      final user = scopeForTransaction[transaction];
      if (user != null) return user;
    }
    final userId = persistentUserId;
    if (userId == null) return null;
    return _scopeManager.getCached(userId);
  }

  /// Returns the [CrdtScope] for the given user ID, creating it when needed.
  Future<CrdtScope> getOrCreateScope(UuidValue userId) {
    return _scopeManager.getOrCreate(userId);
  }

  /// Records the latest acknowledged sync checkpoint for [otherNodeId].
  Future<void> recordSyncCheckpoint(
    UuidValue userId,
    UuidValue otherNodeId,
    Hlc syncedHlc,
  ) async {
    final scope = await _scopeManager.getOrCreate(userId);
    await _db.transaction((transaction) async {
      final node = await _findOrCreateNode(otherNodeId, transaction);
      final scopeNode = await _findOrCreateScopeNode(
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

  /// Insert the CRDT metadata for the inserted rows.
  Future<void> afterInsert<T extends TableRow>(
    List<T> insertedRows,
    Transaction transaction,
  ) async {
    await _forTrackedRows(insertedRows, transaction, (
      tableName,
      rowIds,
      hlcManager,
    ) async {
      final (tableId, _) = _schema[tableName]!;

      await CrdtDataRow.db.insert(
        _session,
        [for (final rowId in rowIds) _newCrdtDataRow(tableId, rowId, hlcManager)],
        transaction: transaction,
        ignoreConflicts: true,
      );

      await _recordForeignKeyInsertAttempts(tableName, rowIds, transaction, {});
      if (_tableColumnsMayAffectForeignKeys(tableName, null)) {
        await _projectForeignKeys(transaction);
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
      final crdtDataRows = await _findRequiredCrdtRows(
        tableName,
        rowIds,
        'reinserted',
        transaction,
      );

      await _touchCrdtRows(crdtDataRows, hlcManager, transaction);
      await _markCrdtRowsDeleted(
        crdtDataRows,
        false,
        CrdtDataDeletedReason.userReinsert,
        transaction,
      );
      await _recordUpdatedFields(reinsertedRows, crdtDataRows, null, transaction);
      await _recordForeignKeyAttemptsForRows(
        tableName,
        rowIds,
        null,
        transaction,
      );
      if (_tableColumnsMayAffectForeignKeys(tableName, null)) {
        await _projectForeignKeys(transaction);
      }
    });
  }

  /// Records CRDT field metadata for updated rows.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    await _assertVisibleForeignKeyTargets(updatedRows, columns, transaction);

    await _forTrackedRows(updatedRows, transaction, (
      tableName,
      rowIds,
      _,
    ) async {
      final crdtDataRows = await _findRequiredCrdtRows(
        tableName,
        rowIds,
        'updated',
        transaction,
      );
      final implicitForeignKeyRepairFields = columns == null
          ? await _findImplicitForeignKeyRepairFields(
              tableName: tableName,
              rowIds: rowIds,
              transaction: transaction,
            )
          : const <_MergeFieldKey>{};
      await _recordUpdatedFields(
        updatedRows,
        crdtDataRows,
        columns,
        transaction,
        skippedFields: implicitForeignKeyRepairFields,
      );
      await _recordForeignKeyAttemptsForRows(
        tableName,
        rowIds,
        columns?.map((column) => column.columnName).toSet(),
        transaction,
        skippedFields: implicitForeignKeyRepairFields,
      );
      if (_tableColumnsMayAffectForeignKeys(
        tableName,
        columns?.map((column) => column.columnName).toSet(),
      )) {
        await _projectForeignKeys(transaction);
      }
    });
  }

  Future<void> _assertVisibleForeignKeyTargets<T extends TableRow>(
    List<T> rows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;
    if (!isCrdtTracked<T>(rows.first.table)) return;

    final tableName = rows.first.table.tableName;
    final tableDefinition = _tableDefinitionsByName[tableName];
    if (tableDefinition == null) return;

    final updatedColumnNames = columns?.map((column) => column.columnName).toSet();
    final foreignKeysToCheck = [
      for (final foreignKey in tableDefinition.foreignKeys)
        if (foreignKey.columns.length == 1 &&
            foreignKey.referenceColumns.length == 1 &&
            (updatedColumnNames == null ||
                updatedColumnNames.contains(foreignKey.columns.single)) &&
            _isCrdtTrackedTableName(foreignKey.referenceTable))
          foreignKey,
    ];
    if (foreignKeysToCheck.isEmpty) return;

    final invalid = await _findInvalidForeignKeyReference(
      childTableName: tableName,
      childRowIds: rows.uuidRowIds,
      foreignKeys: foreignKeysToCheck,
      transaction: transaction,
    );
    if (invalid == null) return;

    final foreignKey = foreignKeysToCheck[invalid.foreignKeyIndex];
    throw Exception(
      'Cannot reference deleted row ${foreignKey.referenceTable}.'
      '${foreignKey.referenceColumns.single} = ${invalid.value}.',
    );
  }

  /// Finds the first child row whose foreign key points at a parent row that
  /// is missing or tombstoned, returning the index of the offending foreign
  /// key in [foreignKeys] together with the offending value.
  ///
  /// All [foreignKeys] are checked in a single round-trip via `UNION ALL`.
  /// This avoids serializing the just-updated rows to JSON only to extract a
  /// single column value, and keeps the assertion at one query regardless of
  /// how many foreign key columns are being updated.
  Future<({int foreignKeyIndex, Object value})?> _findInvalidForeignKeyReference({
    required String childTableName,
    required Set<UuidValue> childRowIds,
    required List<ForeignKeyDefinition> foreignKeys,
    required Transaction transaction,
  }) async {
    if (foreignKeys.isEmpty) return null;

    final scopeId = _getHlcManager(transaction).normalizedScopeId;
    final escapedChildTable = _escapeIdentifier(childTableName);
    final whereRowIds = _sqlLiteralList(childRowIds);

    final foreignKeyBranches = foreignKeys.indexed.map((e) {
      final (index, foreignKey) = e;
      final childColumn = _escapeIdentifier(foreignKey.columns.single);
      final parentTable = _escapeIdentifier(foreignKey.referenceTable);
      final parentColumn = _escapeIdentifier(
        foreignKey.referenceColumns.single,
      );
      final (parentTableId, _) = _schema[foreignKey.referenceTable]!;

      return '''
SELECT $index AS fk_idx, c."$childColumn" AS invalid_value
FROM "$escapedChildTable" c
LEFT JOIN "$parentTable" p
  ON p."$parentColumn" = c."$childColumn"
LEFT JOIN "crdt_data_rows" r
  ON r."scopeId" = $scopeId AND r."tblId" = $parentTableId AND r."uuidRowId" = p."id"
WHERE c."id" IN ($whereRowIds)
  AND c."$childColumn" IS NOT NULL
  AND (
    p."id" IS NULL OR
    p."scopeId" <> $scopeId OR
    r."visibility" > $crdtRowLastVisibleVisibilityIndex
  )
''';
    });

    final result = await _db.unsafeQuery(
      '${foreignKeyBranches.join('UNION ALL\n')}LIMIT 1',
      transaction: transaction,
    );
    if (result.isEmpty) return null;

    return (
      foreignKeyIndex: result.first[0] as int,
      value: result.first[1] as Object,
    );
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

    final hlcManager = _getHlcManager(transaction);
    await record(
      rows.first.table.tableName,
      rows.uuidRowIds,
      hlcManager,
    );
    await _persistCurrentNodeHlc(hlcManager, transaction);
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

  Future<List<CrdtDataRow>> _findRequiredCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    String operation,
    Transaction transaction, {
    bool includeDeleted = false,
  }) async {
    final crdtDataRows = await _findCrdtRows(
      tableName,
      rowIds,
      transaction,
      include: includeDeleted
          ? CrdtDataRow.include(deleted: CrdtDataDeleted.include())
          : null,
    );
    if (crdtDataRows.length != rowIds.length) {
      final found = crdtDataRows.map((e) => e.uuidRowId).toSet();
      final missing = rowIds.difference(found);
      throw StateError(
        'Missing CRDT rows for ${missing.length} $operation domain rows:\n'
        '${missing.map((id) => '  - $id').join('\n')}',
      );
    }
    return crdtDataRows;
  }

  Future<void> _touchCrdtRows(
    List<CrdtDataRow> rows,
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;

    await CrdtDataRow.db.update(
      _session,
      [for (final row in rows) _withNextHlc(row, hlcManager)],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
  }

  Future<void> _recordUpdatedFields<T extends TableRow>(
    List<T> updatedRows,
    List<CrdtDataRow> crdtDataRows,
    List<Column>? columns,
    Transaction transaction, {
    Set<_MergeFieldKey> skippedFields = const {},
  }) async {
    if (updatedRows.isEmpty || crdtDataRows.isEmpty) return;

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final table = updatedRows.first.table;
    final updatedColumnList = (columns ?? table.managedColumns)
        .where((c) => c.columnName != 'id' && c.columnName != 'scopeId')
        .toList();
    if (updatedColumnList.isEmpty) return;

    final (_, colMap) = _schema[table.tableName]!;
    final schemaColumns = [
      for (final column in updatedColumnList)
        colMap[column.columnName] ??
            (throw StateError(
              'No CRDT schema column for ${table.tableName}.${column.columnName}',
            )),
    ];
    await _upsertCrdtFieldsForRows(
      table.tableName,
      [
        for (final row in updatedRows) crdtDataRowByUuid[row.id as UuidValue]!,
      ],
      schemaColumns,
      transaction,
      skippedFields: skippedFields,
    );
  }

  Future<void> _upsertCrdtFieldsForRows(
    String tableName,
    List<CrdtDataRow> crdtDataRows,
    List<CrdtSchemaColumn> schemaColumns,
    Transaction transaction, {
    Set<_MergeFieldKey> skippedFields = const {},
  }) async {
    if (crdtDataRows.isEmpty || schemaColumns.isEmpty) return;

    final rowPks = crdtDataRows.map((r) => r.id!).toSet();
    final columnPks = schemaColumns.map((c) => c.id!).toSet();
    final existingFields = await CrdtDataField.db.find(
      _session,
      where: (t) => t.rowId.inSet(rowPks) & t.columnId.inSet(columnPks),
      transaction: transaction,
    );

    final fieldByRowAndColumn = {
      for (final f in existingFields) (f.rowId, f.columnId): f,
    };

    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataField>[];
    final toUpdate = <CrdtDataField>[];

    for (final row in crdtDataRows) {
      for (final schemaCol in schemaColumns) {
        if (skippedFields.contains((tableName, row.uuidRowId, schemaCol.name))) {
          continue;
        }

        final hlc = hlcManager.increment();
        final existing = fieldByRowAndColumn[(row.id!, schemaCol.id!)];
        if (existing == null) {
          toInsert.add(
            CrdtDataField(
              rowId: row.id!,
              columnId: schemaCol.id!,
              nodeId: hlcManager.normalizedNodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        } else {
          toUpdate.add(
            existing.copyWith(
              nodeId: hlcManager.normalizedNodeId,
              hlcDatetime: hlc.datetime,
              hlcCounter: hlc.counter,
            ),
          );
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataField.db.insert(_session, toInsert, transaction: transaction);
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataField.db.update(_session, toUpdate, transaction: transaction);
    }
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
    await _softDeleteRowsByTable(
      deletedRows.first.table.tableName,
      deletedRows.uuidRowIds,
      transaction,
      null,
      CrdtDataDeletedReason.userDelete,
    );
    if (_tableColumnsMayAffectForeignKeys(
      deletedRows.first.table.tableName,
      null,
    )) {
      await _projectForeignKeys(transaction);
    }
  }

  Future<void> _softDeleteRowsByTable(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    Set<String>? processedRowIds,
    CrdtDataDeletedReason reason,
  ) async {
    if (rowIds.isEmpty) return;
    if (!_isCrdtTrackedTableName(tableName)) return;

    final processing = processedRowIds ?? {};
    final unprocessedRowIds = rowIds
        .where((rowId) => processing.add('$tableName:$rowId'))
        .toSet();

    if (unprocessedRowIds.isEmpty) return;

    final crdtDataRows = await _findRequiredCrdtRows(
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

      final cascadeDeletes = await _applyForeignKeyDeleteActions(
        tableName,
        visibleRowIds,
        transaction,
        processing,
      );
      await _releaseUniqueConflicts(tableName, visibleRowIds, transaction);
      await _markCrdtRowsDeleted(visibleCrdtRows, true, reason, transaction);
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

  /// Records field updates by table name and UUID ids.
  Future<void> recordFieldsUpdatedByTable(
    String tableName,
    Set<UuidValue> rowIds,
    List<String> columnNames,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return;
    if (!_isCrdtTrackedTableName(tableName)) return;

    final crdtDataRows = await _findCrdtRows(tableName, rowIds, transaction);
    if (crdtDataRows.isEmpty) return;

    final (_, colMap) = _schema[tableName]!;
    final schemaColumns = [
      for (final columnName in columnNames)
        if (colMap[columnName] != null) colMap[columnName]!,
    ];
    if (schemaColumns.isEmpty) return;

    await _upsertCrdtFieldsForRows(
      tableName,
      crdtDataRows,
      schemaColumns,
      transaction,
    );
  }

  Future<void> _markCrdtRowsDeleted(
    List<CrdtDataRow> crdtDataRows,
    bool isDeleted,
    CrdtDataDeletedReason reason,
    Transaction transaction,
  ) async {
    final existingTombs = await CrdtDataDeleted.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      transaction: transaction,
    );
    final tombByCrdtRowPk = {for (final t in existingTombs) t.rowId: t};

    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataDeleted>[];
    final toUpdate = <CrdtDataDeleted>[];

    for (final row in crdtDataRows) {
      final rowPk = row.id!;
      final hlc = hlcManager.increment();
      final existing = tombByCrdtRowPk[rowPk];
      final clFlag = _nextClFlag(existing, isDeleted);

      if (existing == null) {
        toInsert.add(
          CrdtDataDeleted(
            rowId: rowPk,
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            clFlag: clFlag,
            reason: reason,
          ),
        );
      } else {
        toUpdate.add(
          existing.copyWith(
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            clFlag: clFlag,
            reason: reason,
          ),
        );
      }
    }

    if (toInsert.isNotEmpty) {
      await CrdtDataDeleted.db.insert(
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataDeleted.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
    }

    await _applyRowVisibility(
      crdtDataRows,
      visibility: reason.toVisibility(isDeleted: isDeleted),
      transaction: transaction,
    );
  }

  Future<void> _applyRowVisibility(
    List<CrdtDataRow> rows, {
    required CrdtDataRowVisibility visibility,
    required Transaction transaction,
  }) async {
    final toUpdate = rows
        .where((row) => row.visibility != visibility)
        .map((row) => row.copyWith(visibility: visibility))
        .toList();
    if (toUpdate.isEmpty) return;

    await CrdtDataRow.db.update(
      _session,
      toUpdate,
      columns: (t) => [t.visibility],
      transaction: transaction,
    );
  }

  Future<void> _applyRowVisibilityFromUserTombstone(
    CrdtDataRow row,
    CrdtDataDeleted tombstone,
    Transaction transaction,
  ) async {
    await _applyRowVisibility(
      [row],
      visibility: tombstone.reason.toVisibility(isDeleted: tombstone.isDeleted),
      transaction: transaction,
    );
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

    final crdtRows = await _findCrdtRows(
      table.tableName,
      rowIds,
      transaction,
    );
    return {
      for (final row in crdtRows)
        if (row.isHidden) row.uuidRowId,
    };
  }

  Future<List<CrdtDataRow>> _findCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction, {
    CrdtDataRowInclude? include,
  }) {
    final (tableId, _) = _schema[tableName]!;
    final scopeId = _getHlcManager(transaction).normalizedScopeId;
    return CrdtDataRow.db.find(
      _session,
      where: (t) =>
          t.scopeId.equals(scopeId) &
          t.tblId.equals(tableId) &
          t.uuidRowId.inSet(rowIds),
      include: include,
      transaction: transaction,
    );
  }

  Future<Map<String, Set<UuidValue>>> _applyForeignKeyDeleteActions(
    String parentTableName,
    Set<UuidValue> parentIds,
    Transaction transaction,
    Set<String> processing,
  ) async {
    if (parentIds.isEmpty) return {};

    final cascadeDeletes = <String, Set<UuidValue>>{};
    final foreignKeys =
        _context._foreignKeysByReferencedTable[parentTableName] ??
        const <_ReferencingForeignKey>[];
    for (final reference in foreignKeys) {
      final parentValuesById = reference.parentColumn == 'id'
          ? null
          : await _readDomainColumnValues(
              parentTableName,
              parentIds,
              [reference.parentColumn],
              transaction,
            );

      for (final parentId in parentIds) {
        final referencedValue = reference.parentColumn == 'id'
            ? parentId
            : parentValuesById?[parentId]?[reference.parentColumn];
        final childIds = await _findVisibleReferencingRowIds(
          tableName: reference.childTableName,
          columnName: reference.childColumn,
          value: referencedValue,
          transaction: transaction,
        );
        if (childIds.isEmpty) continue;

        switch (reference.action) {
          case ForeignKeyAction.restrict:
          case ForeignKeyAction.noAction:
            throw Exception(
              'Cannot delete $parentTableName row because '
              '${reference.childTableName}.${reference.childColumn} references it.',
            );
          case ForeignKeyAction.setNull:
            await _updateDomainRows(
              reference.childTableName,
              childIds,
              {reference.childColumn: null},
              transaction,
            );
            await recordFieldsUpdatedByTable(
              reference.childTableName,
              childIds,
              [reference.childColumn],
              transaction,
            );
          case ForeignKeyAction.setDefault:
            final defaultValue = _context._defaultValueForColumn(
              reference.childTableName,
              reference.childColumn,
            );
            if (defaultValue == null) {
              throw StateError(
                'No default value found for '
                '${reference.childTableName}.${reference.childColumn}.',
              );
            }
            await _updateDomainRows(
              reference.childTableName,
              childIds,
              {reference.childColumn: defaultValue},
              transaction,
            );
            await recordFieldsUpdatedByTable(
              reference.childTableName,
              childIds,
              [reference.childColumn],
              transaction,
            );
          case ForeignKeyAction.cascade:
            cascadeDeletes
                .putIfAbsent(reference.childTableName, () => {})
                .addAll(childIds);
        }
      }
    }

    return cascadeDeletes;
  }

  Future<void> _releaseUniqueConflicts(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
  ) async {
    final tableDefinition = _tableDefinitionsByName[tableName];
    if (tableDefinition == null) return;

    final uniqueIndexes = _uniqueIndexesForTable(tableDefinition);
    for (final uniqueIndex in uniqueIndexes) {
      final releaseColumnNames = uniqueIndex.releaseColumnNames.toList();

      final valuesByRowId = await _readDomainColumnValues(
        tableName,
        rowIds,
        uniqueIndex.indexedColumns,
        transaction,
      );
      final updatedRowIds = <UuidValue>{};

      for (final MapEntry(key: rowId, value: values) in valuesByRowId.entries) {
        if (values.values.any((value) => value == null)) continue;

        final updates = <String, Object?>{};
        for (final column in uniqueIndex.releaseColumns) {
          updates[column.columnName] = _conflictFreeValue(
            column,
            values[column.columnName],
            tableDefinition.name,
            rowId,
            'deleted',
          );
        }

        await _updateDomainRows(tableName, {rowId}, updates, transaction);
        updatedRowIds.add(rowId);
      }

      if (updatedRowIds.isNotEmpty) {
        await recordFieldsUpdatedByTable(
          tableName,
          updatedRowIds,
          releaseColumnNames,
          transaction,
        );
      }
    }
  }

  List<_UniqueIndexConflictRelease> _uniqueIndexesForTable(
    TableDefinition tableDefinition,
  ) {
    return _context._uniqueIndexesByTableName.putIfAbsent(
      tableDefinition.name,
      () => _syncableUniqueIndexesForTable(
        tableDefinition,
        _syncTableByName.keys.toSet(),
      ),
    );
  }

  Future<Set<UuidValue>> _findVisibleReferencingRowIds({
    required String tableName,
    required String columnName,
    required Object? value,
    required Transaction transaction,
  }) async {
    return _findVisibleDomainRowIdsWhere(
      tableName: tableName,
      predicates: [_domainColumnPredicate(columnName, value)],
      transaction: transaction,
    );
  }

  // The helpers below operate on arbitrary synced domain tables and constraint
  // columns discovered from TableDefinition at runtime. Generated repositories
  // require a static model type; these bulk SQL shapes also keep projection and
  // fixed-point repair work to one round-trip per affected set.
  Future<Set<UuidValue>> _findVisibleDomainRowIdsWhere({
    required String tableName,
    required List<String> predicates,
    required Transaction transaction,
  }) async {
    final (tableId, _) = _schema[tableName]!;
    final scopeId = _getHlcManager(transaction).normalizedScopeId;
    final result = await _db.unsafeQuery(
      '''
SELECT d."id"
FROM "${_escapeIdentifier(tableName)}" d
LEFT JOIN "crdt_data_rows" r
  ON r."scopeId" = $scopeId AND r."tblId" = $tableId AND r."uuidRowId" = d."id"
WHERE (${predicates.join(') AND (')})
  AND (r."id" IS NULL OR r."visibility" <= $crdtRowLastVisibleVisibilityIndex)
''',
      transaction: transaction,
    );
    return {
      for (final row in result) UuidValueJsonExtension.fromJson(row.first),
    };
  }

  Future<_ForeignKeyTargetPresence> _lookupForeignKeyTargetPresence({
    required String parentTableName,
    required String parentColumn,
    required UuidValue value,
    required Transaction transaction,
  }) async {
    final (tableId, _) = _schema[parentTableName]!;
    final scopeId = _getHlcManager(transaction).normalizedScopeId;
    final result = await _db.unsafeQuery(
      '''
SELECT CASE
  WHEN r."id" IS NULL OR r."visibility" <= $crdtRowLastVisibleVisibilityIndex THEN 1
  ELSE 0
END AS visible
FROM "${_escapeIdentifier(parentTableName)}" d
LEFT JOIN "crdt_data_rows" r
  ON r."scopeId" = $scopeId AND r."tblId" = $tableId AND r."uuidRowId" = d."id"
WHERE (${_domainColumnPredicate('scopeId', scopeId)})
  AND (${_domainColumnPredicate(parentColumn, value)})
LIMIT 1
''',
      transaction: transaction,
    );
    if (result.isEmpty) return _ForeignKeyTargetPresence.absent;
    return (result.first[0] as num) == 1
        ? _ForeignKeyTargetPresence.visible
        : _ForeignKeyTargetPresence.hidden;
  }

  Future<void> _updateDomainRows(
    String tableName,
    Set<UuidValue> rowIds,
    Map<String, Object?> updates,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || updates.isEmpty) return;

    final assignments = updates.entries
        .map((e) => '"${_escapeIdentifier(e.key)}" = ${_sqlLiteral(e.value)}')
        .join(', ');

    await _db.unsafeExecute(
      '''
UPDATE "${_escapeIdentifier(tableName)}"
SET $assignments
WHERE "id" IN (${_sqlLiteralList(rowIds)})
''',
      transaction: transaction,
    );
  }

  Future<Map<UuidValue, Map<String, Object?>>> _readDomainColumnValues(
    String tableName,
    Set<UuidValue> rowIds,
    List<String> columnNames,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return {};

    final columns = [
      '"id"',
      for (final columnName in columnNames) '"${_escapeIdentifier(columnName)}"',
    ].join(', ');

    final result = await _db.unsafeQuery(
      '''
SELECT $columns
FROM "${_escapeIdentifier(tableName)}"
WHERE "id" IN (${_sqlLiteralList(rowIds)})
''',
      transaction: transaction,
    );

    return {
      for (final row in result)
        UuidValueJsonExtension.fromJson(row[0]): {
          for (final (index, columnName) in columnNames.indexed)
            columnName: row[index + 1],
        },
    };
  }

  Object? _conflictFreeValue(
    _UniqueColumnConflictRelease column,
    Object? value,
    String tableName,
    UuidValue conflictingId,
    String releaseSuffix,
  ) {
    switch (column.kind) {
      case CrdtUniqueConflictReleaseKind.setNull:
        return null;
      case CrdtUniqueConflictReleaseKind.textSuffix:
        if (value is String) {
          return '${value}__${releaseSuffix}__${conflictingId.uuid}';
        }
      case CrdtUniqueConflictReleaseKind.syntheticUuid:
        if (value != null) {
          return const Uuid().v5obj(
            Namespace.oid.value,
            '$tableName.${column.columnName}:${value}__${releaseSuffix}__$conflictingId',
          );
        }
    }

    throw StateError(
      'Unexpected value for $tableName.${column.columnName} while making '
      'tombstoned unique value conflict-free: ${value.runtimeType}.',
    );
  }

  CrdtDataRow _withNextHlc(CrdtDataRow row, HlcManager hlcManager) {
    final hlc = hlcManager.increment();
    return row.copyWith(
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  HlcManager _getHlcManager(Transaction transaction) {
    final user = _getEffectiveScope(transaction);
    return _hlcManagers.putIfAbsent(
      user.uuidScopeId,
      () => HlcManager.forScope(user),
    );
  }

  Future<void> _persistCurrentNodeHlc(
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    await CrdtNode.db.updateRow(
      _session,
      hlcManager.getNode(),
      columns: (t) => [t.lastHlc],
      transaction: transaction,
    );
  }

  Future<CrdtNode> _findOrCreateNode(
    UuidValue uuidNodeId,
    Transaction transaction,
  ) async {
    var node = await CrdtNode.db.findFirstRow(
      _session,
      where: (t) => t.uuidNodeId.equals(uuidNodeId),
      transaction: transaction,
    );
    if (node != null) return node;

    await CrdtNode.db.insert(
      _session,
      [CrdtNode(uuidNodeId: uuidNodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    );
    node = await CrdtNode.db.findFirstRow(
      _session,
      where: (t) => t.uuidNodeId.equals(uuidNodeId),
      transaction: transaction,
    );
    return node ?? (throw StateError('Could not create CRDT node "$uuidNodeId".'));
  }

  Future<CrdtScopeNode> _findOrCreateScopeNode(
    int scopeId,
    int nodeId,
    Transaction transaction,
  ) async {
    var scopeNode = await CrdtScopeNode.db.findFirstRow(
      _session,
      where: (t) => t.scopeId.equals(scopeId) & t.nodeId.equals(nodeId),
      transaction: transaction,
    );
    if (scopeNode != null) return scopeNode;

    await CrdtScopeNode.db.insert(
      _session,
      [CrdtScopeNode(scopeId: scopeId, nodeId: nodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    );
    scopeNode = await CrdtScopeNode.db.findFirstRow(
      _session,
      where: (t) => t.scopeId.equals(scopeId) & t.nodeId.equals(nodeId),
      transaction: transaction,
    );
    return scopeNode ??
        (throw StateError(
          'Could not create CRDT scope-node row for scope $scopeId and node $nodeId.',
        ));
  }

  CrdtScope _getEffectiveScope(Transaction transaction) {
    return scopeForQueries(transaction) ??
        (throw StateError(
          'No user ID found for transaction or persistent user ID.',
        ));
  }
}

String _escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

int _nextClFlag(CrdtDataDeleted? current, bool isDeleted) {
  var next = (current?.clFlag ?? 1) + 1;
  if (next.isEven != isDeleted) next++;
  return next;
}

List<_UniqueIndexConflictRelease> _syncableUniqueIndexesForTable(
  TableDefinition table,
  Set<String> syncTableNames,
) {
  final columnsByName = {for (final column in table.columns) column.name: column};
  return [
    for (final index in crdtSyncableUniqueIndexesForTable(table, syncTableNames))
      _uniqueIndexConflictReleaseForIndex(table, columnsByName, index),
  ];
}

_UniqueIndexConflictRelease _uniqueIndexConflictReleaseForIndex(
  TableDefinition table,
  Map<String, ColumnDefinition> columnsByName,
  IndexDefinition index,
) {
  final columnNames = index.elements.map((element) => element.definition).toList();
  final indexedColumns = [
    for (final columnName in columnNames)
      if (columnName != 'scopeId') columnName,
  ];
  final releaseColumns = <_UniqueColumnConflictRelease>[];
  for (final columnName in indexedColumns) {
    final column = columnsByName[columnName];
    if (column == null) {
      throw StateError('No column definition found for ${table.name}.$columnName.');
    }
    final kind = crdtUniqueConflictReleaseKindForColumn(table, column);
    if (kind != null) {
      releaseColumns.add((columnName: columnName, kind: kind));
    }
  }

  return (
    scoped: columnNames.contains('scopeId'),
    indexedColumns: indexedColumns,
    releaseColumns: releaseColumns,
  );
}

String _sqlLiteral(Object? value) => ValueEncoder.instance.convert(value);

String _sqlLiteralList(Iterable<Object?> values) =>
    values.map(ValueEncoder.instance.convert).join(', ');

String _domainColumnPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${_escapeIdentifier(columnName)}" = ${_sqlLiteral(value)}';

String _domainColumnNotPredicate(
  String columnName,
  Object? value, {
  String alias = 'd',
}) => '$alias."${_escapeIdentifier(columnName)}" <> ${_sqlLiteral(value)}';

UuidValue? _uuidValueFromDatabase(Object? value) {
  if (value == null) return null;
  if (value is UuidValue) return value;
  if (value is String) return UuidValue.withValidation(value);
  return UuidValueJsonExtension.fromJson(value);
}

CrdtSchemaColumn? _schemaColumn(
  Map<String, (int, Map<String, CrdtSchemaColumn>)> schema,
  String tableName,
  String columnName,
) => schema[tableName]?.$2[columnName];

Map<String, int> _schemaColumnIds(
  Map<String, (int, Map<String, CrdtSchemaColumn>)> schema,
  String tableName,
  Iterable<String> columnNames,
) => {
  for (final columnName in columnNames)
    columnName: ?_schemaColumn(schema, tableName, columnName)?.id,
};

extension on CrdtDataDeletedReason {
  CrdtDataRowVisibility toVisibility({required bool isDeleted}) {
    if (!isDeleted) {
      return switch (this) {
        CrdtDataDeletedReason.userReinsert => CrdtDataRowVisibility.userReinsert,
        _ => CrdtDataRowVisibility.userInsert,
      };
    }

    return switch (this) {
      CrdtDataDeletedReason.userDelete => CrdtDataRowVisibility.userDelete,
      CrdtDataDeletedReason.userCascadeDelete =>
        CrdtDataRowVisibility.userCascadeDelete,
      _ => CrdtDataRowVisibility.userDelete,
    };
  }
}

extension on List<TableRow> {
  Set<UuidValue> get uuidRowIds {
    if (isEmpty) return {};
    if (first.id == null) throw StateError('Row IDs must be non-null.');
    if (first.id is! UuidValue) throw StateError('Row IDs must be UuidValue.');
    return {for (final row in this) row.id as UuidValue};
  }
}
