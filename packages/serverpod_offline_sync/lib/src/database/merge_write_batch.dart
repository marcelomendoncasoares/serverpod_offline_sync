part of 'recorder.dart';

/// Owns pending metadata for one merge and the boundaries that make it readable.
/// Context fields advance immediately. Writes wait until another operation
/// needs them or the merge completes. Fresh insert groups can span updates to
/// unrelated, persisted rows because their domain values are projected later.
/// Insert attempts are flushed before another operation touches their row.
class _MergeWriteBatch {
  _MergeWriteBatch({
    required this._session,
    required this._projector,
    required this._rows,
    required this._fields,
    required this._transaction,
  });

  final DatabaseSession _session;
  final CrdtForeignKeyProjector _projector;
  final Map<MergeRowKey, CrdtDataRow> _rows;
  final Map<MergeFieldKey, CrdtDataField> _fields;
  final Transaction _transaction;
  final _insertAttempts = _PendingInsertAttempts();
  final _fieldUpdates = <int, CrdtDataField>{};
  final _insertedRows = <MergeRowKey, CrdtDataRow>{};

  /// Successful completion persists all metadata before projection can run.
  /// Failure leaves rollback to the enclosing transaction, without flushing.
  ///
  /// Update callbacks must use the merge context's current clocks and record
  /// changes to existing fields through [recordFieldUpdate].
  Future<void> apply(
    Iterable<CrdtMergeChange> operations,
    Future<void> Function(CrdtMergeChange operation) applyOperation, {
    required bool Function(CrdtMergeInsert insert) canBatchInsert,
    required Future<void> Function(List<CrdtMergeInsert> inserts) applyInserts,
  }) async {
    final ordered = operations.toList();
    for (var index = 0; index < ordered.length; index++) {
      final operation = ordered[index];
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

      if (operation is CrdtMergeInsert && canBatchInsert(operation)) {
        final inserts = [operation];
        final identities = {(operation.tableName, operation.uuidRowId)};
        while (index + 1 < ordered.length) {
          final next = ordered[index + 1];
          if (next is CrdtMergeUpdate) {
            final key = (next.tableName, next.uuidRowId);
            if (identities.contains(key) ||
                !_rows.containsKey(key) ||
                _insertAttempts.holds(key)) {
              break;
            }

            // Existing-row updates advance metadata and authored overlays;
            // domain values wait until final projection. They cannot change
            // these fresh inserts' parent presence or precomputed plan.
            // A pending row's own edits still require its insert to finish.
            await applyOperation(next);
            index++;
            continue;
          }
          if (next is! CrdtMergeInsert ||
              !canBatchInsert(next) ||
              !identities.add((next.tableName, next.uuidRowId))) {
            break;
          }
          inserts.add(next);
          index++;
        }
        await applyInserts(inserts);
      } else {
        await applyOperation(operation);
      }
    }

    await _flushFieldUpdates();
    await _flushInsertAttempts();
  }

  void recordFieldUpdate(CrdtDataField field) {
    _fieldUpdates[field.id!] = field;
  }

  /// Domain rows are already visible. Trackers wait until an operation needs
  /// their generated identifiers or the merge reaches its projection pass.
  void recordRowInsert(String tableName, CrdtDataRow row) {
    final key = (tableName, row.uuidRowId);
    _rows[key] = row;
    _insertedRows[key] = row;
  }

  Future<void> flushInsertedRows() async {
    if (_insertedRows.isEmpty) return;

    final inserted = await CrdtDataRow.db.insert(
      _session,
      _insertedRows.values.toList(),
      transaction: _transaction,
    );
    final byIdentity = {
      for (final row in inserted) (row.tblId, row.uuidRowId): row,
    };
    for (final MapEntry(key: key, value: pending) in _insertedRows.entries) {
      final persisted = byIdentity[(pending.tblId, pending.uuidRowId)];
      if (persisted == null) {
        throw DatabaseUnexpectedResultException(
          'A merged row tracker was not inserted.',
        );
      }
      _rows[key] = persisted.copyWith(node: pending.node);
    }
    _insertedRows.clear();
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
    await flushInsertedRows();
    for (final group in _insertAttempts.take()) {
      await _projector.recordInsertAttempts(
        group.tableName,
        group.rowIds,
        _transaction,
        group.attempts,
        mergeCache: (fields: _fields, node: group.node),
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
