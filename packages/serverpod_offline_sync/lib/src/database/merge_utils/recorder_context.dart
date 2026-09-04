import 'package:meta/meta.dart';
import 'package:serverpod_database/serverpod_database.dart' hide Protocol;
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

  /// Row ids in [tableName] whose [columnName] holds one of [values].
  ///
  /// Unlike [findVisibleReferencingRowIds] this keeps hidden rows: projection
  /// has to see a hidden child before it can decide whether the child comes
  /// back with its parent.
  Future<Set<UuidValue>> findDomainRowIdsWhereColumnIn({
    required String tableName,
    required String columnName,
    required Set<Object?> values,
    required Transaction transaction,
  }) => findDomainRowIdsWhereColumnsIn(
    tableName: tableName,
    valuesByColumn: {columnName: values},
    transaction: transaction,
  );

  /// Row ids of [tableName] owed one of [values] on one of [columnNames].
  ///
  /// A row that does not hold its authored value keeps it in a sparse attempted
  /// value, so this is how a pass finds the rows waiting for a claim or a
  /// parent it is about to free. The comparison literal is built by the same
  /// encoders the write path uses — the dynamic envelope from the protocol, then
  /// the structured-column encoder — which is what keeps it dialect correct:
  /// `jsonb(...)` against SQLite's binary JSONB, a jsonb literal on Postgres.
  Future<Set<UuidValue>> findRowIdsHoldingAttemptedValues({
    required String tableName,
    required Set<String> columnNames,
    required Set<Object?> values,
    required Transaction transaction,
  }) async {
    if (columnNames.isEmpty || values.isEmpty) return const {};

    final (tableId, columns) = schema[tableName]!;
    final columnIds = {
      for (final columnName in columnNames) ?columns[columnName]?.id,
    };
    if (columnIds.isEmpty) return const {};

    final encodedValues = {
      for (final value in values)
        if (value != null)
          ValueEncoder.instance.encodeColumnValue(
            CrdtDataAttemptedValue.t.value,
            Protocol().dynamicFieldToJson(value),
          ),
    };
    if (encodedValues.isEmpty) return const {};

    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    final result = await database.unsafeQuery(
      '''
SELECT DISTINCT r."uuidRowId"
FROM "crdt_data_attempted_value" a
JOIN "crdt_data_fields" f ON f."id" = a."fieldId"
JOIN "crdt_data_rows" r ON r."id" = f."rowId"
WHERE r."scopeId" = $scopeId
  AND r."tblId" = $tableId
  AND f."columnId" IN (${columnIds.join(', ')})
  AND a."value" IN (${encodedValues.join(', ')})
''',
      transaction: transaction,
    );

    return _rowIds(result);
  }

  /// Row ids in [tableName] whose columns hold one of the listed values.
  ///
  /// A composite unique index is matched column by column, so the result is a
  /// superset of the exact tuples. Loading a few extra rows is what a whole
  /// table load did anyway, and the query stays a plain indexed lookup.
  Future<Set<UuidValue>> findDomainRowIdsWhereColumnsIn({
    required String tableName,
    required Map<String, Set<Object?>> valuesByColumn,
    required Transaction transaction,
  }) async {
    if (valuesByColumn.isEmpty) return const {};
    if (valuesByColumn.values.any((values) => values.isEmpty)) return const {};

    final predicates = valuesByColumn.entries
        .map(
          (entry) =>
              '"${entry.key.escapeIdentifier()}" IN (${entry.value.sqlLiteralList()})',
        )
        .join(') AND (');

    final result = await database.unsafeQuery(
      '''
SELECT "id"
FROM "${tableName.escapeIdentifier()}"
WHERE ($predicates)
''',
      transaction: transaction,
    );

    return _rowIds(result);
  }

  Future<Set<UuidValue>> findVisibleDomainRowIdsWhere({
    required String tableName,
    required List<String> predicates,
    required Transaction transaction,
  }) async {
    final result = await database.unsafeQuery(
      '''
SELECT d."id"
${_visibilityJoin(tableName, transaction)}
WHERE (${predicates.join(') AND (')})
  AND ($_rowVisible)
''',
      transaction: transaction,
    );
    return _rowIds(result);
  }

  /// The `FROM` and `JOIN` pairing domain rows of [tableName] with their CRDT
  /// metadata, as the aliases `d` and `r`.
  ///
  /// An untracked row has no metadata, so `r` is null for it; [_rowVisible]
  /// reads that pair as one boolean.
  String _visibilityJoin(String tableName, Transaction transaction) {
    final (tableId, _) = schema[tableName]!;
    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    return '''
FROM "${tableName.escapeIdentifier()}" d
LEFT JOIN "crdt_data_rows" r
  ON r."scopeId" = $scopeId AND r."tblId" = $tableId AND r."uuidRowId" = d."id"''';
  }

  /// Whether the row joined by [_visibilityJoin] is visible in this scope.
  static final _rowVisible =
      'r."id" IS NULL OR r."visibility" <= $crdtRowLastVisibleVisibilityIndex';

  /// Presence of the [value] target in [parentTableName].
  ///
  /// A foreign key can only reference a unique column, so at most one row
  /// answers; a value with no row at all is [ForeignKeyTargetPresence.absent].
  Future<ForeignKeyTargetPresence> lookupForeignKeyTargetPresence({
    required String parentTableName,
    required String parentColumn,
    required UuidValue value,
    required Transaction transaction,
  }) async {
    final presences = await lookupForeignKeyTargetPresences(
      parentTableName: parentTableName,
      parentColumn: parentColumn,
      values: {value},
      transaction: transaction,
    );
    return presences[value] ?? ForeignKeyTargetPresence.absent;
  }

  /// Presence of every [values] target in [parentTableName], by value.
  ///
  /// Resolving a whole merge batch at once is what keeps the single-value form
  /// off the insert path, where it asked once per foreign key of every row.
  /// Values with no row are absent from the result rather than reported.
  Future<Map<UuidValue, ForeignKeyTargetPresence>> lookupForeignKeyTargetPresences({
    required String parentTableName,
    required String parentColumn,
    required Set<UuidValue> values,
    required Transaction transaction,
  }) async {
    if (values.isEmpty) return const {};

    final scopeId = hlcManagerFor(transaction).normalizedScopeId;
    final result = await database.unsafeQuery(
      '''
SELECT d."${parentColumn.escapeIdentifier()}",
  CASE WHEN $_rowVisible THEN 1 ELSE 0 END AS visible
${_visibilityJoin(parentTableName, transaction)}
WHERE (${domainColumnPredicate('scopeId', scopeId)})
  AND (d."${parentColumn.escapeIdentifier()}" IN (${values.sqlLiteralList()}))
''',
      transaction: transaction,
    );

    return {
      for (final row in result)
        UuidValueJsonExtension.fromJson(row.first): (row[1] as num) == 1
            ? ForeignKeyTargetPresence.visible
            : ForeignKeyTargetPresence.hidden,
    };
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

  /// The `id` column of every row of a result whose first column is a row id.
  Set<UuidValue> _rowIds(DatabaseResult result) => {
    for (final row in result) UuidValueJsonExtension.fromJson(row.first),
  };

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
