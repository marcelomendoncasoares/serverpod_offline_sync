import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../hlc/manager.dart';
import 'database.dart';
import 'session.dart';
import 'transaction.dart';

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
      where: (t) => t.row.rowId.inSet(
        updatedRows.map((row) => row.id as UuidValue).toSet(),
      ),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(),
        column: CrdtSchemaColumn.include(),
      ),
    );

    /// Map of row ID to normalized row ID.
    final existingCrdtRowIds = <UuidValue, int>{
      for (final field in existingCrdtFields) field.row!.rowId: field.row!.id!,
    };

    if (existingCrdtRowIds.length != updatedRows.length) {
      final updatedRowIds = updatedRows.map((row) => row.id as UuidValue).toSet();
      final missingRowIds = updatedRowIds.difference(existingCrdtRowIds.keys.toSet());
      // TODO: Insert non-tracked fields for missing rows with Hlc.zero.
      // The HLC will be updated in order soon below.

      // Update the map with the previously missing and newly inserted row IDs.
      // existingCrdtRowIds.updateAll()
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

  /// Delete the CRDT metadata for the deleted rows.
  Future<void> afterDelete<T extends TableRow>(
    List<T> deletedRows,
    Transaction transaction,
  ) async {
    // Foreign keys use ON DELETE NO ACTION: callers must delete dependent
    // `CrdtDataField` rows before `CrdtDataRow` / `CrdtSchemaColumn` rows.
    // Successful deletes therefore do not require extra CRDT rows here.
  }

  Future<HlcManager> _getHlcManager(Transaction transaction) async {
    final uuidUserId = await _effectiveUuidUserId(transaction);
    return HlcManager.forUser(_session, uuidUserId);
  }

  Future<UuidValue> _effectiveUuidUserId(Transaction transaction) async {
    UuidValue? userId;
    if (transaction is CrdtTransaction) {
      userId = transaction.userId;
    }

    userId ??= persistentUserId;
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
