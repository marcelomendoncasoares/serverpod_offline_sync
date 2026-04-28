import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

import '../managers/hlc.dart';
import '../managers/user.dart';
import '../protocol/protocol.dart';
import 'database.dart';
import 'schema.dart';
import 'session.dart';

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

  /// Initializes the CRDT recorder.
  ///
  /// Safe to call again after the database was wiped (e.g. test `tearDown`)
  /// for in-memory schema ids to match new rows.
  Future<void> initialize() async {
    final schemaRegistry = CrdtSchemaRegistry(_session, syncTables: syncTables);
    final (tableRows, columnRows) = await schemaRegistry.syncAndGetSchema();
    _schema = {
      for (final t in tableRows)
        t.name: (
          t.id!,
          {for (final c in columnRows.where((c) => c.tblId == t.id)) c.name: c},
        ),
    };
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
    return _syncTablesNames.contains(targetTable.tableName);
  }

  /// Insert the CRDT metadata for the inserted rows.
  Future<void> afterInsert<T extends TableRow>(
    List<T> insertedRows,
    Transaction transaction,
  ) async {
    if (insertedRows.isEmpty) return;
    if (!isCrdtTracked<T>(insertedRows.first.table)) return;

    final (tableId, _) = _schema[insertedRows.first.table.tableName]!;
    final hlcManager = _getHlcManager(transaction);

    final newCrdtRows = insertedRows.map((row) {
      final hlc = hlcManager.increment();

      return CrdtDataRow(
        userId: hlcManager.normalizedUserId,
        tblId: tableId,
        uuidRowId: row.id as UuidValue,
        nodeId: hlcManager.normalizedNodeId,
        datetime: hlc.datetime,
        counter: hlc.counter,
      );
    });

    await CrdtDataRow.db.insert(
      _session,
      newCrdtRows.toList(),
      transaction: transaction,
      ignoreConflicts: true,
    );

    // TODO: Handle re-insertion of previously deleted rows.
    // Can only happen for rows that had the id field not null when inserting.
  }

  /// Insert the CRDT metadata for the updated rows.
  Future<void> afterUpdate<T extends TableRow>(
    List<T> updatedRows,
    List<Column>? columns,
    Transaction transaction,
  ) async {
    if (updatedRows.isEmpty) return;
    if (!isCrdtTracked<T>(updatedRows.first.table)) return;

    final crdtDataRows = await CrdtDataRow.db.find(
      _session,
      where: (t) => t.uuidRowId.inSet(updatedRows.uuidRowIds),
      transaction: transaction,
    );

    if (crdtDataRows.length != updatedRows.length) {
      final found = crdtDataRows.map((e) => e.uuidRowId).toSet();
      final missing = updatedRows.uuidRowIds.difference(found);
      throw StateError(
        'Missing CRDT rows for ${missing.length} updated domain rows:\n'
        '${missing.map((id) => '  - $id').join('\n')}',
      );
    }

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final table = updatedRows.first.table;
    final updatedColumnList = (columns ?? table.managedColumns)
        .where((c) => c.columnName != 'id')
        .toList();

    final existingFields = await CrdtDataField.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      include: CrdtDataField.include(
        column: CrdtSchemaColumn.include(),
      ),
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
      final (_, colMap) = _schema[row.table.tableName]!;

      for (final column in updatedColumnList) {
        final schemaCol = colMap[column.columnName];
        if (schemaCol == null) {
          throw StateError(
            'No CRDT schema column for ${row.table.tableName}.${column.columnName}',
          );
        }

        final hlc = hlcManager.increment();
        final rowPk = crdtDataRow.id!;
        final colPk = schemaCol.id!;
        final existing = fieldByRowAndColumn[(rowPk, colPk)];

        if (existing == null) {
          toInsert.add(
            CrdtDataField(
              rowId: rowPk,
              columnId: colPk,
              nodeId: crdtDataRow.nodeId,
              datetime: hlc.datetime,
              counter: hlc.counter,
            ),
          );
        } else {
          toUpdate.add(
            existing.copyWith(
              nodeId: crdtDataRow.nodeId,
              datetime: hlc.datetime,
              counter: hlc.counter,
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

  // TODO: Must evaluate cascade operations.
  /// Soft-deletes rows by recording a tombstone instead of removing them.
  ///
  /// Expects a matching [CrdtDataRow] per domain row (`uuidRowId` = domain id).
  Future<void> insteadOfDelete<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {
    if (deletedRows.isEmpty) return;
    if (!isCrdtTracked<T>(deletedRows.first.table)) return;
    await _markDomainRowsDeleted<T>(deletedRows, transaction);
  }

  /// Sets `CrdtDataDeleted.isDeleted` for domain rows instead of removing rows.
  ///
  /// Expects a matching [CrdtDataRow] per domain row (`uuidRowId` = domain id).
  Future<void> _markDomainRowsDeleted<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {
    final crdtDataRows = await CrdtDataRow.db.find(
      _session,
      where: (t) => t.uuidRowId.inSet(deletedRows.uuidRowIds),
      transaction: transaction,
    );

    if (crdtDataRows.length != deletedRows.length) {
      final found = crdtDataRows.map((e) => e.uuidRowId).toSet();
      final missing = deletedRows.uuidRowIds.difference(found);
      throw StateError(
        'Missing CRDT rows for ${missing.length} deleted domain rows:\n'
        '${missing.map((id) => '  - $id').join('\n')}',
      );
    }

    final crdtDataRowByUuid = {
      for (final r in crdtDataRows) r.uuidRowId: r,
    };

    final existingTombs = await CrdtDataDeleted.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtDataRows.map((r) => r.id!).toSet()),
      transaction: transaction,
    );
    final tombByCrdtRowPk = {for (final t in existingTombs) t.rowId: t};

    final hlcManager = _getHlcManager(transaction);
    final toInsert = <CrdtDataDeleted>[];
    final toUpdate = <CrdtDataDeleted>[];

    for (final row in deletedRows) {
      final crdtDataRow = crdtDataRowByUuid[row.id as UuidValue]!;
      final rowPk = crdtDataRow.id!;
      final hlc = hlcManager.increment();
      final existing = tombByCrdtRowPk[rowPk];

      if (existing == null) {
        toInsert.add(
          CrdtDataDeleted(
            rowId: rowPk,
            nodeId: hlcManager.normalizedNodeId,
            datetime: hlc.datetime,
            counter: hlc.counter,
            isDeleted: true,
          ),
        );
      } else {
        toUpdate.add(
          existing.copyWith(
            nodeId: hlcManager.normalizedNodeId,
            datetime: hlc.datetime,
            counter: hlc.counter,
            isDeleted: true,
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

extension on List<TableRow> {
  Set<UuidValue> get uuidRowIds {
    if (isEmpty) return {};
    if (first.id == null) throw StateError('Row IDs must be non-null.');
    if (first.id is! UuidValue) throw StateError('Row IDs must be UuidValue.');
    return {for (final row in this) row.id as UuidValue};
  }
}
