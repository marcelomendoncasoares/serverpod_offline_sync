import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../../crdt/extensions.dart';
import '../../generated/protocol.dart';
import '../../managers/hlc.dart';
import '../../managers/scope.dart';
import '../database.dart';
import '../recorder.dart';
import '../session.dart';
import '../unique_index_utils.dart';
import 'database_helpers.dart';
import 'types.dart';

/// Whether a foreign key target row is absent, visible, or hidden.
@internal
enum ForeignKeyTargetPresence {
  absent,
  visible,
  hidden,
}

/// Shared state and database access for the CRDT recorder and its helpers.
///
/// Owns per-recorder scope/HLC management and the low-level domain and CRDT
/// metadata queries shared by the mutation recorder, the unique conflict
/// resolver, and the foreign key projector.
@internal
class CrdtRecorderContext {
  /// Creates a [CrdtRecorderContext] instance.
  CrdtRecorderContext(
    this.database, {
    required this.databaseContext,
    required this.persistentUserId,
  });

  /// The underlying user database (not the CRDT proxy).
  final Database database;

  /// Process-level CRDT metadata shared across recorders.
  final CrdtDatabaseContext databaseContext;

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  /// A plain session over [database] for metadata queries.
  late final DatabaseSession databaseSession = database.session;

  /// Manages [CrdtScope] rows and their cache.
  late final CrdtScopeManager scopeManager = CrdtScopeManager(databaseSession);

  final Map<UuidValue, HlcManager> _hlcManagers = {};

  /// Clears cached [HlcManager] instances for this recorder session.
  void clearHlcManagers() => _hlcManagers.clear();

  /// CRDT schema ids by table name: `tableName -> (tableId, columnsByName)`.
  Map<String, (int, Map<String, CrdtSchemaColumn>)> get schema =>
      databaseContext.schema;

  /// The list of tables to sync with CRDT.
  List<Table> get syncTables => databaseContext.syncTables;

  /// Returns the local [CrdtSchemaTable] id for [tableName], or null when the
  /// table is not registered for CRDT synchronization.
  int? tableIdForName(String tableName) => databaseContext.tableIdForName(tableName);

  /// Whether the given table name is tracked by CRDT.
  bool isCrdtTrackedTableName(String tableName) =>
      databaseContext.isCrdtTrackedTableName(tableName);

  /// The CRDT schema column for the given table and column names, if any.
  CrdtSchemaColumn? schemaColumn(String tableName, String columnName) =>
      databaseContext.schemaColumn(tableName, columnName);

  /// The CRDT schema column ids for the given table and column names.
  ///
  /// Columns without a CRDT schema entry are omitted from the result.
  Map<String, int> schemaColumnIds(
    String tableName,
    Iterable<String> columnNames,
  ) => databaseContext.schemaColumnIds(tableName, columnNames);

  /// Serverpod table definitions by table name.
  Map<String, TableDefinition> get tableDefinitionsByName =>
      databaseContext.tableDefinitionsByName;

  /// Column definitions by table name and column name.
  Map<String, Map<String, ColumnDefinition>> get columnsByTableAndName =>
      databaseContext.columnsByTableAndName;

  /// Synced tables by table name.
  Map<String, Table> get syncTableByName => databaseContext.syncTableByName;

  /// Column names of every synced table, used to scope merge metadata lookups.
  Map<String, Set<String>> get syncedTableColumnNamesForMerge =>
      databaseContext.syncedTableColumnNamesForMerge;

  /// The default value declared for the given column, if usable.
  Object? defaultValueForColumn(String tableName, String columnName) =>
      databaseContext.defaultValueForColumn(tableName, columnName);

  Future<List<CrdtDataRow>> findCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction, {
    CrdtDataRowInclude? include,
  }) {
    final (tableId, _) = schema[tableName]!;
    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    return CrdtDataRow.db.find(
      databaseSession,
      where: (t) =>
          t.scopeId.equals(scopeId) &
          t.tblId.equals(tableId) &
          t.uuidRowId.inSet(rowIds),
      include: include,
      transaction: transaction,
    );
  }

  Future<List<CrdtDataRow>> findRequiredCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    String operation,
    Transaction transaction, {
    bool includeDeleted = false,
  }) async {
    final crdtDataRows = await findCrdtRows(
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

  Future<void> upsertCrdtFieldsForRows(
    String tableName,
    List<CrdtDataRow> crdtDataRows,
    List<CrdtSchemaColumn> schemaColumns,
    Transaction transaction, {
    Set<MergeFieldKey> skippedFields = const {},
  }) async {
    if (crdtDataRows.isEmpty || schemaColumns.isEmpty) return;

    final rowPks = crdtDataRows.map((r) => r.id!).toSet();
    final columnPks = schemaColumns.map((c) => c.id!).toSet();
    final existingFields = await CrdtDataField.db.find(
      databaseSession,
      where: (t) => t.rowId.inSet(rowPks) & t.columnId.inSet(columnPks),
      transaction: transaction,
    );

    final fieldByRowAndColumn = {
      for (final f in existingFields) (f.rowId, f.columnId): f,
    };

    final hlcManager = hlcManagerFor(transaction);
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
      await CrdtDataField.db.insert(
        databaseSession,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataField.db.update(
        databaseSession,
        toUpdate,
        transaction: transaction,
      );
    }
  }

  Future<void> recordFieldsUpdatedByTable(
    String tableName,
    Set<UuidValue> rowIds,
    List<String> columnNames,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return;
    if (!isCrdtTrackedTableName(tableName)) return;

    final crdtDataRows = await findCrdtRows(tableName, rowIds, transaction);
    if (crdtDataRows.isEmpty) return;

    final (_, colMap) = schema[tableName]!;
    final schemaColumns = [
      for (final columnName in columnNames)
        if (colMap[columnName] != null) colMap[columnName]!,
    ];
    if (schemaColumns.isEmpty) return;

    await upsertCrdtFieldsForRows(
      tableName,
      crdtDataRows,
      schemaColumns,
      transaction,
    );
  }

  Future<void> markCrdtRowsDeleted(
    List<CrdtDataRow> crdtDataRows,
    // Preserved verbatim from the recorder; positional bool matches tombstone API.
    // ignore: avoid_positional_boolean_parameters
    bool isDeleted,
    CrdtDataDeletedReason reason,
    Transaction transaction,
  ) async {
    final existingTombs = await CrdtDataDeleted.db.find(
      databaseSession,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      transaction: transaction,
    );
    final tombByCrdtRowPk = {for (final t in existingTombs) t.rowId: t};

    final hlcManager = hlcManagerFor(transaction);
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
        databaseSession,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataDeleted.db.update(
        databaseSession,
        toUpdate,
        transaction: transaction,
      );
    }

    await applyRowVisibility(
      crdtDataRows,
      visibility: reason.toVisibility(isDeleted: isDeleted),
      transaction: transaction,
    );
  }

  Future<void> applyRowVisibility(
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
      databaseSession,
      toUpdate,
      columns: (t) => [t.visibility],
      transaction: transaction,
    );
  }

  Future<void> applyRowVisibilityFromUserTombstone(
    CrdtDataRow row,
    CrdtDataDeleted tombstone,
    Transaction transaction,
  ) async {
    await applyRowVisibility(
      [row],
      visibility: tombstone.reason.toVisibility(isDeleted: tombstone.isDeleted),
      transaction: transaction,
    );
  }

  Future<Set<UuidValue>> findVisibleReferencingRowIds({
    required String tableName,
    required String columnName,
    required Object? value,
    required Transaction transaction,
  }) async {
    return findVisibleDomainRowIdsWhere(
      tableName: tableName,
      predicates: [domainColumnPredicate(columnName, value)],
      transaction: transaction,
    );
  }

  Future<Set<UuidValue>> findVisibleDomainRowIdsWhere({
    required String tableName,
    required List<String> predicates,
    required Transaction transaction,
  }) async {
    final (tableId, _) = schema[tableName]!;
    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    final result = await database.unsafeQuery(
      '''
SELECT d."id"
FROM "${tableName.escapeIdentifier()}" d
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

  Future<ForeignKeyTargetPresence> lookupForeignKeyTargetPresence({
    required String parentTableName,
    required String parentColumn,
    required UuidValue value,
    required Transaction transaction,
  }) async {
    final (tableId, _) = schema[parentTableName]!;
    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    final result = await database.unsafeQuery(
      '''
SELECT CASE
  WHEN r."id" IS NULL OR r."visibility" <= $crdtRowLastVisibleVisibilityIndex THEN 1
  ELSE 0
END AS visible
FROM "${parentTableName.escapeIdentifier()}" d
LEFT JOIN "crdt_data_rows" r
  ON r."scopeId" = $scopeId AND r."tblId" = $tableId AND r."uuidRowId" = d."id"
WHERE (${domainColumnPredicate('scopeId', scopeId)})
  AND (${domainColumnPredicate(parentColumn, value)})
LIMIT 1
''',
      transaction: transaction,
    );
    if (result.isEmpty) return ForeignKeyTargetPresence.absent;
    return (result.first[0] as num) == 1
        ? ForeignKeyTargetPresence.visible
        : ForeignKeyTargetPresence.hidden;
  }

  Future<void> updateDomainRows(
    String tableName,
    Set<UuidValue> rowIds,
    Map<String, Object?> updates,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || updates.isEmpty) return;

    final assignments = updates.entries
        .map((e) => '"${e.key.escapeIdentifier()}" = ${e.value.sqlLiteral()}')
        .join(', ');

    await database.unsafeExecute(
      '''
UPDATE "${tableName.escapeIdentifier()}"
SET $assignments
WHERE "id" IN (${rowIds.sqlLiteralList()})
''',
      transaction: transaction,
    );
  }

  Future<Map<UuidValue, Map<String, Object?>>> readDomainColumnValues(
    String tableName,
    Set<UuidValue> rowIds,
    List<String> columnNames,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || columnNames.isEmpty) return {};

    final columns = [
      '"id"',
      for (final columnName in columnNames) '"${columnName.escapeIdentifier()}"',
    ].join(', ');

    final result = await database.unsafeQuery(
      '''
SELECT $columns
FROM "${tableName.escapeIdentifier()}"
WHERE "id" IN (${rowIds.sqlLiteralList()})
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

  Object? conflictFreeValue(
    UniqueColumnConflictRelease column,
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

  CrdtDataRow withNextHlc(CrdtDataRow row, HlcManager hlcManager) {
    final hlc = hlcManager.increment();
    return row.copyWith(
      nodeId: hlcManager.normalizedNodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
    );
  }

  HlcManager hlcManagerFor(Transaction transaction) {
    final user = effectiveScopeFor(transaction);
    return _hlcManagers.putIfAbsent(
      user.uuidScopeId,
      () => HlcManager.forScope(user),
    );
  }

  Future<void> persistCurrentNodeHlc(
    HlcManager hlcManager,
    Transaction transaction,
  ) async {
    await CrdtNode.db.updateRow(
      databaseSession,
      hlcManager.getNode(),
      columns: (t) => [t.lastHlc],
      transaction: transaction,
    );
  }

  Future<T> _findOrCreate<T>({
    required Future<T?> Function() find,
    required Future<void> Function() insert,
    required String label,
  }) async {
    final existing = await find();
    if (existing != null) return existing;

    await insert();
    final created = await find();
    return created ?? (throw StateError('Could not create $label.'));
  }

  Future<CrdtNode> findOrCreateNode(
    UuidValue uuidNodeId,
    Transaction transaction,
  ) => _findOrCreate(
    find: () => CrdtNode.db.findFirstRow(
      databaseSession,
      where: (t) => t.uuidNodeId.equals(uuidNodeId),
      transaction: transaction,
    ),
    insert: () => CrdtNode.db.insert(
      databaseSession,
      [CrdtNode(uuidNodeId: uuidNodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    ),
    label: 'CRDT node "$uuidNodeId"',
  );

  Future<CrdtScopeNode> findOrCreateScopeNode(
    int scopeId,
    int nodeId,
    Transaction transaction,
  ) => _findOrCreate(
    find: () => CrdtScopeNode.db.findFirstRow(
      databaseSession,
      where: (t) => t.scopeId.equals(scopeId) & t.nodeId.equals(nodeId),
      transaction: transaction,
    ),
    insert: () => CrdtScopeNode.db.insert(
      databaseSession,
      [CrdtScopeNode(scopeId: scopeId, nodeId: nodeId)],
      transaction: transaction,
      ignoreConflicts: true,
    ),
    label: 'CRDT scope-node row for scope $scopeId and node $nodeId',
  );

  CrdtScope effectiveScopeFor(Transaction transaction) {
    final scope = scopeForTransaction[transaction];
    if (scope != null) return scope;
    final userId = persistentUserId;
    if (userId == null) {
      throw StateError('No user ID found for transaction or persistent user ID.');
    }
    return scopeManager.getCached(userId);
  }

  Future<({int foreignKeyIndex, Object value})?> findInvalidForeignKeyReference({
    required String childTableName,
    required Set<UuidValue> childRowIds,
    required List<ForeignKeyDefinition> foreignKeys,
    required Transaction transaction,
  }) async {
    if (foreignKeys.isEmpty) return null;

    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    final escapedChildTable = childTableName.escapeIdentifier();
    final whereRowIds = childRowIds.sqlLiteralList();

    final foreignKeyBranches = foreignKeys.indexed.map((e) {
      final (index, foreignKey) = e;
      final childColumn = foreignKey.columns.single.escapeIdentifier();
      final parentTable = foreignKey.referenceTable.escapeIdentifier();
      final parentColumn = foreignKey.referenceColumns.single.escapeIdentifier();
      final (parentTableId, _) = schema[foreignKey.referenceTable]!;

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

    final result = await database.unsafeQuery(
      '${foreignKeyBranches.join('UNION ALL\n')}LIMIT 1',
      transaction: transaction,
    );
    if (result.isEmpty) return null;

    return (
      foreignKeyIndex: result.first[0] as int,
      value: result.first[1] as Object,
    );
  }

  /// The unique-index conflict release metadata for [tableDefinition].
  List<UniqueIndexConflictRelease> uniqueIndexesForTable(
    TableDefinition tableDefinition,
  ) => databaseContext.uniqueIndexesForTable(tableDefinition);
}

int _nextClFlag(CrdtDataDeleted? current, bool isDeleted) {
  var next = (current?.clFlag ?? 1) + 1;
  if (next.isEven != isDeleted) next++;
  return next;
}
