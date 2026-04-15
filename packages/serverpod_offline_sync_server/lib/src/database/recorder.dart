import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../hlc/manager.dart';
import 'database.dart';
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
  }) : assert(
         _db is! CrdtDatabase,
         'The database must be the user database, not the CRDT database. '
         'Passing a CRDT database would cause an infinite recursion.',
       );

  final Database _db;

  late final _session = CrdtDatabaseSession(_db);

  /// The user ID to use for all CRDT operations. This should only be used for
  /// databases operating on the client side, where all data is for the same user.
  /// Otherwise, the user ID must be passed through the transaction.
  final UuidValue? persistentUserId;

  /// Insert the CRDT metadata for the inserted rows.
  Future<void> afterInsert<T extends TableRow>(
    List<T> insertedRows,
    Transaction transaction,
  ) async {
    if (insertedRows.isEmpty) return;

    final tableId = await insertedRows.first.table.getId(_session);
    final hlcManager = await _getHlcManager(transaction);

    final newCrdtRows = insertedRows.map((row) async {
      final hlc = hlcManager.increment();

      return CrdtDataRow(
        userId: hlcManager.normalizedUserId,
        tblId: tableId,
        rowId: row.id as UuidValue,
        nodeId: hlcManager.normalizedNodeId,
        workerId: hlcManager.workerId,
        datetime: hlc.datetime,
        counter: hlc.counter,
      );
    });

    await CrdtDataRow.db.insert(
      _session,
      await newCrdtRows.wait,
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

    final existingCrdtFields = await CrdtDataField.db.find(
      _session,
      where: (t) => t.row.rowId.inSet(updatedRows.uuidRowIds),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(),
        column: CrdtSchemaColumn.include(),
      ),
    );

    final existingCrdtRowIds = existingCrdtFields.map((f) => f.row!.rowId).toSet();
    if (existingCrdtRowIds.length != updatedRows.length) {
      final missingRowIds = updatedRows.uuidRowIds.difference(existingCrdtRowIds);
      throw StateError(
        'Missing CRDT rows for ${missingRowIds.length} updated rows:\n'
        '${missingRowIds.map((id) => '  - $id').join('\n')}',
      );
    }

    final hlcManager = await _getHlcManager(transaction);
    final updatedColumns = columns ?? updatedRows.first.table.columns;

    final modifiedCrdtFields = <CrdtDataField>[];
    for (final row in updatedRows) {
      final existingFields = existingCrdtFields
          .where((field) => field.row!.rowId == row.id as UuidValue)
          .toList();

      for (final column in updatedColumns) {
        final existingField = existingFields.firstWhere(
          (field) => field.column!.name == column.columnName,
        );
        final hlc = hlcManager.increment();

        modifiedCrdtFields.add(
          CrdtDataField(
            rowId: existingField.rowId,
            columnId: existingField.columnId,
            nodeId: hlcManager.normalizedNodeId,
            workerId: hlcManager.workerId,
            datetime: hlc.datetime,
            counter: hlc.counter,
          ),
        );
      }
    }

    // TODO: Combine both statements into upsert when it's available.
    await CrdtDataField.db.insert(
      _session,
      modifiedCrdtFields,
      transaction: transaction,
      ignoreConflicts: true,
    );

    // TODO: Update only non-inserted fields.
    await CrdtDataField.db.update(
      _session,
      modifiedCrdtFields,
      transaction: transaction,
    );
  }

  /// Physical deletes on the delegate DB (non-UUID tables). No CRDT tombstone.
  Future<void> afterDelete<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {}

  /// Sets `CrdtDataDeleted.isDeleted` for domain rows (UUID PK) instead of removing rows.
  ///
  /// Expects a matching [CrdtDataRow] per domain row (`rowId` = domain id).
  Future<void> markDomainRowsDeleted(
    List<TableRow> rows,
    Transaction transaction,
  ) async {
    if (rows.isEmpty) return;

    final byUuid = <UuidValue, TableRow>{};
    for (final row in rows) {
      if (row.id == null) throw StateError('Row id must be non-null.');
      final id = row.id;
      if (id is! UuidValue) {
        throw StateError('markDomainRowsDeleted expects UuidValue ids.');
      }
      byUuid[id] = row;
    }

    final crdtRows = await CrdtDataRow.db.find(
      _session,
      where: (t) => t.rowId.inSet(byUuid.keys.toSet()),
      transaction: transaction,
    );
    if (crdtRows.length != byUuid.length) {
      final found = crdtRows.map((r) => r.rowId).toSet();
      final missing = byUuid.keys.toSet().difference(found);
      throw StateError(
        'Missing CRDT rows for ${missing.length} deleted domain rows:\n'
        '${missing.map((id) => '  - $id').join('\n')}',
      );
    }

    final crdtIds = {for (final r in crdtRows) r.id!};
    final existingTombs = await CrdtDataDeleted.db.find(
      _session,
      where: (t) => t.rowId.inSet(crdtIds),
      transaction: transaction,
    );
    final tombByCrdtRowPk = {for (final t in existingTombs) t.rowId: t};

    final hlcManager = await _getHlcManager(transaction);
    final toInsert = <CrdtDataDeleted>[];
    final toUpdate = <CrdtDataDeleted>[];

    for (final crdtRow in crdtRows) {
      final pk = crdtRow.id!;
      final hlc = hlcManager.increment();
      final existing = tombByCrdtRowPk[pk];
      if (existing != null) {
        toUpdate.add(
          existing.copyWith(
            isDeleted: true,
            workerId: hlcManager.workerId,
            datetime: hlc.datetime,
            counter: hlc.counter,
            nodeId: hlcManager.normalizedNodeId,
          ),
        );
      } else {
        toInsert.add(
          CrdtDataDeleted(
            rowId: pk,
            nodeId: hlcManager.normalizedNodeId,
            workerId: hlcManager.workerId,
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

  Future<HlcManager> _getHlcManager(Transaction transaction) async {
    final uuidUserId = await _effectiveUuidUserId(transaction);
    return HlcManager.forUser(_session, uuidUserId);
  }

  Future<UuidValue> _effectiveUuidUserId(Transaction transaction) async {
    final userId = userForTransaction[transaction.hashCode] ?? persistentUserId;
    if (userId == null) {
      throw StateError('No user ID found for transaction or persistent user ID.');
    }
    return userId;
  }
}

extension on Table {
  Future<int> getId(DatabaseSession session) async {
    final tableId = await CrdtSchemaTable.db.findFirstRow(
      session,
      where: (t) => t.name.equals(tableName),
    );
    if (tableId == null || tableId.id == null) {
      throw StateError('Table not found: $tableName');
    }
    return tableId.id!;
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
