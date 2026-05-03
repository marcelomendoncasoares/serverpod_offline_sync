import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';
import 'package:serverpod_serialization/serverpod_serialization.dart';

import '../crdt/sync.dart';
import '../managers/hlc.dart';
import '../managers/user.dart';
import '../protocol/protocol.dart';
import 'database.dart';
import 'schema.dart';
import 'session.dart';

typedef _ReferencingForeignKey = ({
  String childTableName,
  String childColumn,
  String parentColumn,
  ForeignKeyAction action,
});

typedef _UniqueIndexConflictRelease = ({
  List<_UniqueColumnConflictRelease> columns,
});

typedef _UniqueColumnConflictRelease = ({
  String columnName,
  _UniqueConflictReleaseKind kind,
});

typedef _MergeRowKey = (String, UuidValue);
typedef _MergeFieldKey = (String, UuidValue, String);

enum _UniqueConflictReleaseKind {
  setNull,
  textSuffix,
  syntheticUuid,
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
    required this.persistentUserId,
    required this.syncTables,
  }) : assert(
         _db is! CrdtDatabase,
         'The database must be the user database, not the CRDT database. '
         'Passing a CRDT database would cause an infinite recursion.',
       );

  final Database _db;

  late final _session = CrdtDatabaseSession(
    _db,
    syncTables: syncTables,
    persistentUserId: persistentUserId,
  );

  late Map<String, (int, Map<String, CrdtSchemaColumn>)> _schema;

  late final _tableDefinitionsByName = {
    for (final table in _db.serializationManager.getTargetTableDefinitions())
      table.name: table,
  };

  late final Map<String, List<_ReferencingForeignKey>> _foreignKeysByReferencedTable =
      () {
        final result = <String, List<_ReferencingForeignKey>>{};
        for (final table in _tableDefinitionsByName.values) {
          final childTableName = table.name;
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

  final _uniqueIndexesByTableName = <String, List<_UniqueIndexConflictRelease>>{};

  late final Map<String, Map<String, ColumnDefinition>> _columnsByTableAndName = {
    for (final table in _tableDefinitionsByName.values)
      table.name: {for (final column in table.columns) column.name: column},
  };

  /// Initializes the CRDT recorder.
  ///
  /// Safe to call again after the database was wiped (e.g. test `tearDown`)
  /// for in-memory schema ids to match new rows.
  Future<void> initialize() async {
    final session = _db.session;

    if (persistentUserId != null) {
      await CrdtUserManager.getOrCreate(session, persistentUserId!);
    }

    final schemaRegistry = CrdtSchemaRegistry(session, syncTables: syncTables);
    final (tableRows, columnRows) = await schemaRegistry.syncAndGetSchema();

    final columnsByTableId = <int, Map<String, CrdtSchemaColumn>>{};
    for (final column in columnRows) {
      columnsByTableId.putIfAbsent(column.tblId, () => {})[column.name] = column;
    }

    _schema = {
      for (final t in tableRows)
        t.name: (
          t.id!,
          columnsByTableId[t.id!] ?? {},
        ),
    };
  }

  /// Locks the current user row so merges can serialize with other work.
  Future<void> lockCurrentUser(Transaction transaction) async {
    final user = _getEffectiveUser(transaction);
    await CrdtUser.db.findById(
      _session,
      user.id!,
      transaction: transaction,
      lockMode: LockMode.forUpdate,
      lockBehavior: LockBehavior.wait,
    );
  }

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  /// The list of tables to sync with CRDT.
  final List<Table> syncTables;

  late final _syncTablesNames = syncTables.map((t) => t.tableName).toSet();

  /// Whether the given table is tracked by CRDT.
  bool isCrdtTracked<T extends TableRow>([Table? table]) {
    final targetTable = table ?? _db.serializationManager.getTableForType(T);
    if (targetTable == null) return false;
    return _isCrdtTrackedTableName(targetTable.tableName);
  }

  /// Whether the given table name is tracked by CRDT.
  bool _isCrdtTrackedTableName(String tableName) {
    return _syncTablesNames.contains(tableName);
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
      await _markCrdtRowsDeleted(crdtDataRows, false, transaction);
      await _recordUpdatedFields(reinsertedRows, crdtDataRows, null, transaction);
    });
  }

  /// Records CRDT field metadata for updated rows.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
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
      await _recordUpdatedFields(updatedRows, crdtDataRows, columns, transaction);
    });
  }

  /// Merges remote CRDT changes into the current database.
  Future<void> mergeChanges(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    if (mergeSet.isEmpty) return;

    final currentUser = _getEffectiveUser(transaction);
    final remoteNodes = await _findOrCreateNodesForMerge(
      currentUser.id!,
      {
        for (final change in mergeSet.changes) change.nodeId,
      },
      transaction,
    );
    final metadata = await _loadMergeMetadata(mergeSet, transaction);
    final operations = mergeSet.changes.toList()
      ..sort((left, right) => left.hlc.compareTo(right.hlc));

    for (final operation in operations) {
      if (!_isCrdtTrackedTableName(operation.tableName) ||
          !_schema.containsKey(operation.tableName)) {
        continue;
      }

      switch (operation) {
        case CrdtMergeInsert():
          await _applyMergeInsert(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeUpdate():
          await _applyMergeUpdate(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.fields,
            transaction,
          );
        case CrdtMergeDelete():
          await _applyMergeDelete(
            operation,
            remoteNodes,
            metadata.rows,
            metadata.tombstones,
            transaction,
          );
      }
    }

    final maxIncomingHlc = operations.fold<Hlc?>(
      null,
      (current, change) =>
          current == null || change.hlc > current ? change.hlc : current,
    );
    if (maxIncomingHlc != null) {
      final hlcManager = _getHlcManager(transaction);
      if (maxIncomingHlc.nodeId == hlcManager.uuidNodeId) {
        if (maxIncomingHlc > hlcManager.lastHlc) {
          hlcManager.lastHlc = maxIncomingHlc;
        }
      } else {
        hlcManager.merge(maxIncomingHlc);
      }
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

    await record(
      rows.first.table.tableName,
      rows.uuidRowIds,
      _getHlcManager(transaction),
    );
  }

  CrdtDataRow _newCrdtDataRow(
    int tableId,
    UuidValue rowId,
    HlcManager hlcManager,
  ) {
    final hlc = hlcManager.increment();

    return CrdtDataRow(
      userId: hlcManager.normalizedUserId,
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
    Transaction transaction,
  ) async {
    if (updatedRows.isEmpty || crdtDataRows.isEmpty) return;

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final table = updatedRows.first.table;
    final updatedColumnList = (columns ?? table.managedColumns)
        .where((c) => c.columnName != 'id')
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
    for (final row in updatedRows) {
      final crdtDataRow = crdtDataRowByUuid[row.id as UuidValue]!;

      for (final schemaCol in schemaColumns) {
        final hlc = hlcManager.increment();
        final rowPk = crdtDataRow.id!;
        final colPk = schemaCol.id!;
        final existing = fieldByRowAndColumn[(rowPk, colPk)];

        if (existing == null) {
          toInsert.add(
            CrdtDataField(
              rowId: rowPk,
              columnId: colPk,
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
        _session,
        toInsert,
        transaction: transaction,
      );
    }
    if (toUpdate.isNotEmpty) {
      await CrdtDataField.db.update(
        _session,
        toUpdate,
        transaction: transaction,
      );
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
    );
  }

  Future<void> _softDeleteRowsByTable(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction,
    Set<String>? processedRowIds,
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
      final visibleCrdtRows = crdtDataRows
          .where((row) => row.deleted?.isDeleted != true)
          .toList();

      if (visibleCrdtRows.isEmpty) return;
      final visibleRowIds = visibleCrdtRows.map((row) => row.uuidRowId).toSet();

      await _applyForeignKeyDeleteActions(
        tableName,
        visibleRowIds,
        transaction,
        processing,
      );
      await _releaseUniqueConflicts(tableName, visibleRowIds, transaction);
      await _markCrdtRowsDeleted(visibleCrdtRows, true, transaction);
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

  Future<void> _markCrdtRowsDeleted(
    List<CrdtDataRow> crdtDataRows,
    bool isDeleted,
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

      if (existing == null) {
        toInsert.add(
          CrdtDataDeleted(
            rowId: rowPk,
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            isDeleted: isDeleted,
          ),
        );
      } else {
        toUpdate.add(
          existing.copyWith(
            nodeId: hlcManager.normalizedNodeId,
            hlcDatetime: hlc.datetime,
            hlcCounter: hlc.counter,
            isDeleted: isDeleted,
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
  }

  /// Whether the given row is soft-deleted.
  Future<bool> isDeleted<T extends TableRow>(
    T row,
    Transaction transaction,
  ) async {
    if (!isCrdtTracked<T>(row.table)) return false;
    if (row.id is! UuidValue) return false;

    final crdtRows = await _findCrdtRows(
      row.table.tableName,
      {row.id as UuidValue},
      transaction,
    );
    if (crdtRows.isEmpty) return false;

    final tombstone = await CrdtDataDeleted.db.findFirstRow(
      _session,
      where: (t) => t.rowId.equals(crdtRows.single.id),
      transaction: transaction,
    );
    return tombstone?.isDeleted ?? false;
  }

  Future<List<CrdtDataRow>> _findCrdtRows(
    String tableName,
    Set<UuidValue> rowIds,
    Transaction transaction, {
    CrdtDataRowInclude? include,
  }) {
    final (tableId, _) = _schema[tableName]!;
    final userId = _getHlcManager(transaction).normalizedUserId;
    return CrdtDataRow.db.find(
      _session,
      where: (t) =>
          t.userId.equals(userId) & t.tblId.equals(tableId) & t.uuidRowId.inSet(rowIds),
      include: include,
      transaction: transaction,
    );
  }

  Future<Map<UuidValue, CrdtNode>> _findOrCreateNodesForMerge(
    int userId,
    Set<UuidValue> nodeIds,
    Transaction transaction,
  ) async {
    if (nodeIds.isEmpty) return {};

    var nodes = await CrdtNode.db.find(
      _session,
      where: (t) => t.userId.equals(userId) & t.uuidNodeId.inSet(nodeIds),
      transaction: transaction,
    );
    final existingNodeIds = nodes.map((node) => node.uuidNodeId).toSet();
    final missingNodeIds = nodeIds.difference(existingNodeIds);

    if (missingNodeIds.isNotEmpty) {
      await CrdtNode.db.insert(
        _session,
        [
          for (final uuidNodeId in missingNodeIds)
            CrdtNode(
              userId: userId,
              uuidNodeId: uuidNodeId,
            ),
        ],
        transaction: transaction,
        ignoreConflicts: true,
      );

      nodes = await CrdtNode.db.find(
        _session,
        where: (t) => t.userId.equals(userId) & t.uuidNodeId.inSet(nodeIds),
        transaction: transaction,
      );
    }

    return {
      for (final node in nodes) node.uuidNodeId: node,
    };
  }

  Future<
    ({
      Map<_MergeRowKey, CrdtDataRow> rows,
      Map<_MergeFieldKey, CrdtDataField> fields,
      Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    })
  >
  _loadMergeMetadata(
    CrdtMergeSet mergeSet,
    Transaction transaction,
  ) async {
    final rowIdsByTable = <String, Set<UuidValue>>{};
    final columnNamesByTable = <String, Set<String>>{};

    for (final insert in mergeSet.inserts) {
      if (!_isCrdtTrackedTableName(insert.tableName) ||
          !_schema.containsKey(insert.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(insert.tableName, () => {}).add(insert.rowId);
      columnNamesByTable
          .putIfAbsent(insert.tableName, () => {})
          .addAll(
            insert.data.keys.where((columnName) => columnName != 'id'),
          );
    }

    for (final update in mergeSet.updates) {
      if (!_isCrdtTrackedTableName(update.tableName) ||
          !_schema.containsKey(update.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(update.tableName, () => {}).add(update.rowId);
      columnNamesByTable.putIfAbsent(update.tableName, () => {}).add(update.columnName);
    }

    for (final delete in mergeSet.deletes) {
      if (!_isCrdtTrackedTableName(delete.tableName) ||
          !_schema.containsKey(delete.tableName)) {
        continue;
      }
      rowIdsByTable.putIfAbsent(delete.tableName, () => {}).add(delete.rowId);
    }

    final rows = <_MergeRowKey, CrdtDataRow>{};
    final fields = <_MergeFieldKey, CrdtDataField>{};
    final tombstones = <_MergeRowKey, CrdtDataDeleted>{};

    for (final MapEntry(key: tableName, value: rowIds) in rowIdsByTable.entries) {
      final loadedRows = await _findCrdtRows(
        tableName,
        rowIds,
        transaction,
        include: CrdtDataRow.include(
          node: CrdtNode.include(),
          deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
        ),
      );

      for (final row in loadedRows) {
        final rowKey = (tableName, row.uuidRowId);
        rows[rowKey] = row;
        if (row.deleted != null) {
          tombstones[rowKey] = row.deleted!;
        }
      }

      final columnNames = columnNamesByTable[tableName];
      if (columnNames == null || columnNames.isEmpty || loadedRows.isEmpty) continue;

      final rowPks = loadedRows.map((row) => row.id!).toSet();
      final (_, columnsByName) = _schema[tableName]!;
      final columnIds = {
        for (final columnName in columnNames)
          if (columnsByName[columnName] != null) columnsByName[columnName]!.id!,
      };
      if (columnIds.isEmpty) continue;

      final loadedFields = await CrdtDataField.db.find(
        _session,
        where: (t) => t.rowId.inSet(rowPks) & t.columnId.inSet(columnIds),
        include: CrdtDataField.include(
          column: CrdtSchemaColumn.include(),
          node: CrdtNode.include(),
        ),
        transaction: transaction,
      );

      for (final field in loadedFields) {
        final row = loadedRows.firstWhere((loadedRow) => loadedRow.id == field.rowId);
        fields[(tableName, row.uuidRowId, field.column!.name)] = field;
      }
    }

    return (
      rows: rows,
      fields: fields,
      tombstones: tombstones,
    );
  }

  Future<void> _applyMergeInsert(
    CrdtMergeInsert insert,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Transaction transaction,
  ) async {
    final rowKey = (insert.tableName, insert.rowId);
    final incomingHlc = insert.hlc;
    final remoteNode =
        remoteNodes[insert.nodeId] ??
        (throw StateError('Remote node ${insert.nodeId} not found for merge.'));

    final currentRow = rows[rowKey];
    final currentRowHlc = currentRow == null ? null : _rowHlc(currentRow);
    if (currentRowHlc != null && incomingHlc <= currentRowHlc) {
      return;
    }

    final data = _sanitizeMergeRowData(insert.tableName, insert.data);
    final domainUpdates = <String, Object?>{};
    for (final MapEntry(key: columnName, value: value) in data.entries) {
      final currentField = fields[(insert.tableName, insert.rowId, columnName)];
      final currentColumnHlc = currentField == null
          ? currentRowHlc
          : _fieldHlc(currentField);
      if (currentColumnHlc == null || incomingHlc > currentColumnHlc) {
        domainUpdates[columnName] = value;
      }
    }

    final persistedRow = await _upsertMergeRow(
      insert.tableName,
      insert.rowId,
      remoteNode,
      incomingHlc,
      currentRow,
      transaction,
    );
    rows[rowKey] = persistedRow;

    if (domainUpdates.isEmpty) return;

    final rowExists = await _domainRowExists(
      insert.tableName,
      insert.rowId,
      transaction,
    );
    if (rowExists) {
      await _updateDomainRow(
        insert.tableName,
        insert.rowId,
        domainUpdates,
        transaction,
      );
      return;
    }

    await _insertDomainRow(
      insert.tableName,
      {
        'id': insert.rowId,
        ...domainUpdates,
      },
      transaction,
    );
  }

  Future<void> _applyMergeUpdate(
    CrdtMergeUpdate update,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeFieldKey, CrdtDataField> fields,
    Transaction transaction,
  ) async {
    final rowKey = (update.tableName, update.rowId);
    final row = rows[rowKey];
    if (row == null) return;

    final (_, columnsByName) = _schema[update.tableName]!;
    final schemaColumn = columnsByName[update.columnName];
    if (schemaColumn == null) return;

    final incomingHlc = update.hlc;
    final fieldKey = (update.tableName, update.rowId, update.columnName);
    final currentField = fields[fieldKey];
    final currentHlc = currentField == null ? _rowHlc(row) : _fieldHlc(currentField);
    if (incomingHlc <= currentHlc) {
      return;
    }

    await _updateDomainRow(
      update.tableName,
      update.rowId,
      {update.columnName: update.value},
      transaction,
    );

    final remoteNode =
        remoteNodes[update.nodeId] ??
        (throw StateError('Remote node ${update.nodeId} not found for merge.'));
    final persistedField = await _upsertMergeField(
      row,
      schemaColumn,
      remoteNode,
      incomingHlc,
      currentField,
      transaction,
    );
    fields[fieldKey] = persistedField;
  }

  Future<void> _applyMergeDelete(
    CrdtMergeDelete delete,
    Map<UuidValue, CrdtNode> remoteNodes,
    Map<_MergeRowKey, CrdtDataRow> rows,
    Map<_MergeRowKey, CrdtDataDeleted> tombstones,
    Transaction transaction,
  ) async {
    final rowKey = (delete.tableName, delete.rowId);
    final row = rows[rowKey];
    if (row == null) return;

    final incomingHlc = delete.hlc;
    final currentRowHlc = _rowHlc(row);
    final currentTombstone = tombstones[rowKey];
    final currentTombstoneHlc = currentTombstone == null
        ? null
        : _tombstoneHlc(currentTombstone);
    final currentVisibilityHlc =
        currentTombstoneHlc == null || currentRowHlc > currentTombstoneHlc
        ? currentRowHlc
        : currentTombstoneHlc;
    if (incomingHlc <= currentVisibilityHlc) {
      return;
    }

    final remoteNode =
        remoteNodes[delete.nodeId] ??
        (throw StateError('Remote node ${delete.nodeId} not found for merge.'));
    final persistedTombstone = await _upsertMergeTombstone(
      row,
      remoteNode,
      incomingHlc,
      delete.isDeleted,
      currentTombstone,
      transaction,
    );
    tombstones[rowKey] = persistedTombstone;
  }

  Future<CrdtDataRow> _upsertMergeRow(
    String tableName,
    UuidValue rowId,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    CrdtDataRow? currentRow,
    Transaction transaction,
  ) async {
    if (currentRow == null) {
      final (tableId, _) = _schema[tableName]!;
      final insertedRow = await CrdtDataRow.db.insertRow(
        _session,
        CrdtDataRow(
          userId: _getHlcManager(transaction).normalizedUserId,
          tblId: tableId,
          uuidRowId: rowId,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
        ),
        transaction: transaction,
      );
      return insertedRow.copyWith(node: remoteNode);
    }

    final updatedRow = currentRow.copyWith(
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
    );
    await CrdtDataRow.db.update(
      _session,
      [updatedRow],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
    return updatedRow;
  }

  Future<CrdtDataField> _upsertMergeField(
    CrdtDataRow row,
    CrdtSchemaColumn column,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    CrdtDataField? currentField,
    Transaction transaction,
  ) async {
    if (currentField == null) {
      final insertedField = await CrdtDataField.db.insertRow(
        _session,
        CrdtDataField(
          rowId: row.id!,
          columnId: column.id!,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
        ),
        transaction: transaction,
      );
      return insertedField.copyWith(
        row: row,
        column: column,
        node: remoteNode,
      );
    }

    final updatedField = currentField.copyWith(
      row: row,
      column: column,
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
    );
    await CrdtDataField.db.update(
      _session,
      [updatedField],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: transaction,
    );
    return updatedField;
  }

  Future<CrdtDataDeleted> _upsertMergeTombstone(
    CrdtDataRow row,
    CrdtNode remoteNode,
    Hlc incomingHlc,
    bool isDeleted,
    CrdtDataDeleted? currentTombstone,
    Transaction transaction,
  ) async {
    if (currentTombstone == null) {
      final insertedTombstone = await CrdtDataDeleted.db.insertRow(
        _session,
        CrdtDataDeleted(
          rowId: row.id!,
          nodeId: remoteNode.id!,
          hlcDatetime: incomingHlc.datetime,
          hlcCounter: incomingHlc.counter,
          isDeleted: isDeleted,
        ),
        transaction: transaction,
      );
      return insertedTombstone.copyWith(
        row: row,
        node: remoteNode,
      );
    }

    final updatedTombstone = currentTombstone.copyWith(
      row: row,
      nodeId: remoteNode.id,
      node: remoteNode,
      hlcDatetime: incomingHlc.datetime,
      hlcCounter: incomingHlc.counter,
      isDeleted: isDeleted,
    );
    await CrdtDataDeleted.db.update(
      _session,
      [updatedTombstone],
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter, t.isDeleted],
      transaction: transaction,
    );
    return updatedTombstone;
  }

  Map<String, Object?> _sanitizeMergeRowData(
    String tableName,
    Map<String, Object?> data,
  ) {
    final columns = _columnsByTableAndName[tableName];
    if (columns == null) return {};

    return {
      for (final MapEntry(key: columnName, value: value) in data.entries)
        if (columnName != 'id' && columns.containsKey(columnName)) columnName: value,
    };
  }

  Future<bool> _domainRowExists(
    String tableName,
    UuidValue rowId,
    Transaction transaction,
  ) async {
    final result = await _db.unsafeQuery(
      '''
SELECT 1
FROM "${_escapeIdentifier(tableName)}"
WHERE "id" = ${_sqlLiteral(rowId)}
LIMIT 1
''',
      transaction: transaction,
    );
    return result.isNotEmpty;
  }

  Future<void> _insertDomainRow(
    String tableName,
    Map<String, Object?> values,
    Transaction transaction,
  ) async {
    if (values.isEmpty) return;

    final columns = values.keys
        .map((columnName) => '"${_escapeIdentifier(columnName)}"')
        .join(', ');
    final sqlValues = values.values.map(_sqlLiteral).join(', ');

    await _db.unsafeExecute(
      '''
INSERT INTO "${_escapeIdentifier(tableName)}" ($columns)
VALUES ($sqlValues)
''',
      transaction: transaction,
    );
  }

  Future<void> _applyForeignKeyDeleteActions(
    String parentTableName,
    Set<UuidValue> parentIds,
    Transaction transaction,
    Set<String> processing,
  ) async {
    if (parentIds.isEmpty) return;

    final foreignKeys =
        _foreignKeysByReferencedTable[parentTableName] ??
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
            final defaultValue = _defaultValueForColumn(
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
            await _softDeleteRowsByTable(
              reference.childTableName,
              childIds,
              transaction,
              processing,
            );
        }
      }
    }
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
      final columnNames = uniqueIndex.columns
          .map((column) => column.columnName)
          .toList();

      final valuesByRowId = await _readDomainColumnValues(
        tableName,
        rowIds,
        columnNames,
        transaction,
      );
      final updatedRowIds = <UuidValue>{};

      for (final MapEntry(key: rowId, value: values) in valuesByRowId.entries) {
        if (values.values.any((value) => value == null)) continue;

        final updates = <String, Object?>{};
        for (final column in uniqueIndex.columns) {
          updates[column.columnName] = _conflictFreeValue(
            column,
            values[column.columnName],
            tableDefinition.name,
            rowId,
          );
        }

        await _updateDomainRow(tableName, rowId, updates, transaction);
        updatedRowIds.add(rowId);
      }

      if (updatedRowIds.isNotEmpty) {
        await recordFieldsUpdatedByTable(
          tableName,
          updatedRowIds,
          columnNames,
          transaction,
        );
      }
    }
  }

  List<_UniqueIndexConflictRelease> _uniqueIndexesForTable(
    TableDefinition tableDefinition,
  ) {
    return _uniqueIndexesByTableName.putIfAbsent(
      tableDefinition.name,
      () => _syncableUniqueIndexesForTable(tableDefinition),
    );
  }

  Future<Set<UuidValue>> _findVisibleReferencingRowIds({
    required String tableName,
    required String columnName,
    required Object? value,
    required Transaction transaction,
  }) async {
    final (tableId, _) = _schema[tableName]!;
    final userId = _getHlcManager(transaction).normalizedUserId;
    final result = await _db.unsafeQuery(
      '''
SELECT d."id"
FROM "${_escapeIdentifier(tableName)}" d
LEFT JOIN "crdt_data_rows" r
  ON r."userId" = $userId AND r."tblId" = $tableId AND r."uuidRowId" = d."id"
LEFT JOIN "crdt_data_tombstone" tomb
  ON tomb."rowId" = r."id"
WHERE d."${_escapeIdentifier(columnName)}" = ${_sqlLiteral(value)}
  AND (tomb."id" IS NULL OR tomb."isDeleted" = FALSE)
''',
      transaction: transaction,
    );
    return {
      for (final row in result) UuidValueJsonExtension.fromJson(row.first),
    };
  }

  Future<void> _updateDomainRow(
    String tableName,
    UuidValue rowId,
    Map<String, Object?> updates,
    Transaction transaction,
  ) async {
    await _updateDomainRows(tableName, {rowId}, updates, transaction);
  }

  Future<void> _updateDomainRows(
    String tableName,
    Set<UuidValue> rowIds,
    Map<String, Object?> updates,
    Transaction transaction,
  ) async {
    if (rowIds.isEmpty || updates.isEmpty) return;

    final assignments = updates.entries
        .map(
          (entry) => '"${_escapeIdentifier(entry.key)}" = ${_sqlLiteral(entry.value)}',
        )
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

  Object? _conflictFreeValue(
    _UniqueColumnConflictRelease column,
    Object? value,
    String tableName,
    UuidValue conflictingId,
  ) {
    switch (column.kind) {
      case _UniqueConflictReleaseKind.setNull:
        return null;
      case _UniqueConflictReleaseKind.textSuffix:
        if (value is String) {
          return '${value}__deleted__${conflictingId.uuid}';
        }
      case _UniqueConflictReleaseKind.syntheticUuid:
        if (value != null) {
          return _syntheticDeletedUuid(
            tableName,
            column.columnName,
            UuidValueJsonExtension.fromJson(value),
            conflictingId,
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
    final user = _getEffectiveUser(transaction);
    return HlcManager.forUser(user);
  }

  CrdtUser _getEffectiveUser(Transaction transaction) {
    final user = userForTransaction[transaction];
    if (user != null) return user;
    if (persistentUserId == null) {
      throw StateError('No user ID found for transaction or persistent user ID.');
    }
    return CrdtUserManager.getCached(persistentUserId!);
  }
}

Hlc _rowHlc(CrdtDataRow row) => row.toHlcForNode(row.node!.uuidNodeId);

Hlc _fieldHlc(CrdtDataField field) => field.toHlcForNode(field.node!.uuidNodeId);

Hlc _tombstoneHlc(CrdtDataDeleted tombstone) =>
    tombstone.toHlcForNode(tombstone.node!.uuidNodeId);

String _escapeIdentifier(String identifier) => identifier.replaceAll('"', '""');

List<_UniqueIndexConflictRelease> _syncableUniqueIndexesForTable(
  TableDefinition table,
) {
  final uniqueIndexes = table.indexes
      .where(
        (index) =>
            index.isUnique &&
            !index.isPrimary &&
            index.elements.every(
              (element) => element.type == IndexElementDefinitionType.column,
            ),
      )
      .toList();

  final columnsByName = {for (final column in table.columns) column.name: column};
  return [
    for (final index in uniqueIndexes)
      (
        columns: [
          for (final columnName in index.elements.map((element) => element.definition))
            _uniqueConflictReleaseForColumn(
              table,
              columnsByName[columnName],
              columnName,
            ),
        ],
      ),
  ];
}

_UniqueColumnConflictRelease _uniqueConflictReleaseForColumn(
  TableDefinition table,
  ColumnDefinition? column,
  String columnName,
) {
  if (column == null) {
    throw StateError('No column definition found for ${table.name}.$columnName.');
  }

  if (column.isNullable) {
    return (columnName: columnName, kind: _UniqueConflictReleaseKind.setNull);
  }

  if (column.columnType == ColumnType.text) {
    return (columnName: columnName, kind: _UniqueConflictReleaseKind.textSuffix);
  }

  if (column.columnType == ColumnType.uuid && !_isForeignKeyColumn(table, columnName)) {
    return (columnName: columnName, kind: _UniqueConflictReleaseKind.syntheticUuid);
  }

  throw StateError(
    'CRDT soft deletes cannot release unique conflicts for ${table.name}.$columnName. '
    'Only nullable, text, and non-FK UUID unique columns are supported.',
  );
}

bool _isForeignKeyColumn(TableDefinition table, String columnName) {
  return table.foreignKeys.any(
    (fk) => fk.columns.length == 1 && fk.columns.single == columnName,
  );
}

UuidValue _syntheticDeletedUuid(
  String tableName,
  String columnName,
  UuidValue value,
  UuidValue conflictingId,
) {
  return UuidValue.withValidation(
    const Uuid().v5(
      Namespace.oid.value,
      '$tableName.$columnName:${value.uuid}:${conflictingId.uuid}',
    ),
  );
}

String _sqlLiteral(Object? value) => ValueEncoder.instance.convert(value);

String _sqlLiteralList(Iterable<Object?> values) =>
    values.map(ValueEncoder.instance.convert).join(', ');

extension on List<TableRow> {
  Set<UuidValue> get uuidRowIds {
    if (isEmpty) return {};
    if (first.id == null) throw StateError('Row IDs must be non-null.');
    if (first.id is! UuidValue) throw StateError('Row IDs must be UuidValue.');
    return {for (final row in this) row.id as UuidValue};
  }
}
