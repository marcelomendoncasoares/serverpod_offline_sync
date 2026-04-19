import 'package:serverpod/serverpod.dart';

/// Extensions for [Database] to upsert rows.
extension DatabaseUpsertExtensions on Database {
  /// Upserts rows in the database.
  ///
  /// This is a combination of [insert] and [update] operations. It will insert
  /// new rows and update existing rows in the database.
  ///
  /// Parameters:
  /// - [rows]: The rows to upsert.
  /// - [columns]: The columns to update.
  /// - [transaction]: The transaction to use. If not provided, a new transaction
  ///   will be created.
  ///
  /// Returns:
  /// - The list of upserted rows.
  Future<List<T>> upsert<T extends TableRow>(
    Iterable<T> rows, {
    Iterable<Column>? columns,
    Transaction? transaction,
  }) async {
    return DatabaseUtil.runInTransactionOrSavepoint(this, transaction, (tx) async {
      final newRows = await insert(
        rows.toList(),
        transaction: tx,
        ignoreConflicts: true,
      );

      final newRowIDs = newRows.map((row) => row.id).toSet();
      final toUpdateRows = rows.where((row) => !newRowIDs.contains(row.id)).toList();

      final updatedRows = await update(
        toUpdateRows,
        columns: columns?.toList(),
        transaction: tx,
      );

      return [...newRows, ...updatedRows];
    });
  }
}
