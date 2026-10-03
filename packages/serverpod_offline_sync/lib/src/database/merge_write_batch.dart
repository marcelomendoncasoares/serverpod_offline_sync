part of 'recorder.dart';

/// Owns pending metadata for one merge and the boundaries that make it readable.
/// Context fields advance immediately. Existing field writes wait until an
/// insert, delete, pending insert's next operation, or successful completion.
/// Insert attempts are flushed before another operation touches their row.
class _MergeWriteBatch {
  _MergeWriteBatch({
    required this._session,
    required this._projector,
    required this._context,
    required this._transaction,
  });

  final DatabaseSession _session;
  final CrdtForeignKeyProjector _projector;
  final MergeContext _context;
  final Transaction _transaction;
  final _insertAttempts = _PendingInsertAttempts();
  final _fieldUpdates = <int, CrdtDataField>{};

  /// Successful completion persists all metadata before projection can run.
  /// Failure leaves rollback to the enclosing transaction, without flushing.
  ///
  /// Update callbacks must use the merge context's current clocks and record
  /// changes to existing fields through [recordFieldUpdate].
  Future<void> apply(
    Iterable<CrdtMergeChange> operations,
    Future<void> Function(CrdtMergeChange operation) applyOperation,
  ) async {
    for (final operation in operations) {
      final needsInsertMetadata = _insertAttempts.holds((
        operation.tableName,
        operation.uuidRowId,
      ));

      // Reinserts can advance field clocks immediately. Flush older queued
      // updates first so the final flush cannot overwrite those newer clocks.
      if (operation is! CrdtMergeUpdate || needsInsertMetadata) {
        await _flushFieldUpdates();
      }
      if (needsInsertMetadata) {
        await _flushInsertAttempts();
      }

      await applyOperation(operation);
    }

    await _flushFieldUpdates();
    await _flushInsertAttempts();
  }

  void recordFieldUpdate(CrdtDataField field) {
    _fieldUpdates[field.id!] = field;
  }

  void recordInsertAttempts({
    required String tableName,
    required UuidValue rowId,
    required CrdtNode node,
    required ProjectionAttemptsByField attempts,
  }) {
    _insertAttempts.add(
      tableName: tableName,
      rowId: rowId,
      node: node,
      attempts: attempts,
    );
  }

  Future<void> _flushFieldUpdates() async {
    if (_fieldUpdates.isEmpty) return;

    await CrdtDataField.db.update(
      _session,
      _fieldUpdates.values.toList(),
      columns: (t) => [t.nodeId, t.hlcDatetime, t.hlcCounter],
      transaction: _transaction,
      noReturn: true,
    );
    _fieldUpdates.clear();
  }

  Future<void> _flushInsertAttempts() async {
    for (final group in _insertAttempts.take()) {
      await _projector.recordInsertAttempts(
        group.tableName,
        group.rowIds,
        _transaction,
        group.attempts,
        mergeCache: (fields: _context.fields, node: group.node),
      );
    }
  }
}

/// Field metadata for merged inserts, waiting to be written as one batch.
///
/// Groups rows by table and author: cached field clocks need the node that
/// authored each group.
class _PendingInsertAttempts {
  final Map<(String, int), ({Set<UuidValue> rowIds, CrdtNode node})> _byGroup = {};
  final Map<String, ProjectionAttemptsByField> _attemptsByTable = {};
  final Set<MergeRowKey> _rows = {};

  /// Whether metadata for [rowKey] is still unwritten.
  bool holds(MergeRowKey rowKey) => _rows.contains(rowKey);

  void add({
    required String tableName,
    required UuidValue rowId,
    required CrdtNode node,
    required ProjectionAttemptsByField attempts,
  }) {
    _byGroup
        .putIfAbsent(
          (tableName, node.id!),
          () => (rowIds: <UuidValue>{}, node: node),
        )
        .rowIds
        .add(rowId);
    _rows.add((tableName, rowId));
    if (attempts.isEmpty) return;
    _attemptsByTable
        .putIfAbsent(tableName, () => <MergeFieldKey, ProjectionAttempt>{})
        .addAll(attempts);
  }

  /// Empties the collector and returns what it held.
  List<
    ({
      String tableName,
      Set<UuidValue> rowIds,
      CrdtNode node,
      ProjectionAttemptsByField attempts,
    })
  >
  take() {
    final groups = [
      for (final MapEntry(key: key, value: group) in _byGroup.entries)
        (
          tableName: key.$1,
          rowIds: group.rowIds,
          node: group.node,
          attempts:
              _attemptsByTable[key.$1] ?? const <MergeFieldKey, ProjectionAttempt>{},
        ),
    ];
    _byGroup.clear();
    _attemptsByTable.clear();
    _rows.clear();
    return groups;
  }
}
