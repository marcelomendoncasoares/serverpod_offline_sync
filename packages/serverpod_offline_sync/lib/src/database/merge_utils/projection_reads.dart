part of 'foreign_key_projector.dart';

/// Loads metadata for one projection read phase in one space and transaction.
/// Field identities are resolved through the scoped rows and registered columns,
/// so equal domain UUIDs in different tables remain distinct.
///
/// Its maps become mutable projection state. Complete loading before applying
/// pending inserts or authored overlays to them.
class _ProjectionReader {
  _ProjectionReader(this._context, this._transaction);

  final CrdtRecorderContext _context;
  final Transaction _transaction;
  final rows = <MergeRowKey, _ProjectedForeignKeyRow>{};
  final fieldIds = <MergeFieldKey, int>{};
  final attemptedValues = <MergeFieldKey, CrdtDataAttemptedValue>{};
  final fieldHlcs = <MergeFieldKey, Hlc>{};

  /// Whether this space and these tables hold any attempted claims.
  /// A false result lets the closure skip attempted-claim queries, but is
  /// valid only until the next write phase; each projection checks again.
  Future<bool> hasAttemptedClaims(Set<String> tablesToLoad) async {
    final spaceId = _context.hlcManagerFor(_transaction).normalizedSpaceId;
    return tablesToLoad.isNotEmpty &&
        await CrdtDataAttemptedValue.db.findFirstRow(
              _context.databaseSession,
              where: (t) =>
                  t.field.row.spaceId.equals(spaceId) &
                  t.field.row.tblId.inSet({
                    for (final table in tablesToLoad) _context.schema[table]!.$1,
                  }),
              transaction: _transaction,
            ) !=
            null;
  }

  /// Loads one closure wave, sharing metadata reads across its tables.
  /// A null row-id set requests the whole table during a full rebuild.
  Future<Map<String, Set<UuidValue>>> loadRows({
    required Map<String, Set<UuidValue>?> requestedRows,
    required Map<String, Set<String>> columnsByTable,
  }) async {
    final tablesById = {
      for (final entry in requestedRows.entries)
        if (entry.value == null || entry.value!.isNotEmpty)
          _context.schema[entry.key]!.$1: entry.key,
    };
    if (tablesById.isEmpty) return {};

    final spaceId = _context.hlcManagerFor(_transaction).normalizedSpaceId;
    final crdtRows = await CrdtDataRow.db.find(
      _context.databaseSession,
      where: (t) =>
          t.spaceId.equals(spaceId) &
          tablesById.entries
              .map((entry) {
                final rowIds = requestedRows[entry.value];
                final table = t.tblId.equals(entry.key);
                return rowIds == null ? table : table & t.uuidRowId.inSet(rowIds);
              })
              .reduce((left, right) => left | right),
      include: CrdtDataRow.include(
        node: CrdtNode.include(),
        deleted: CrdtDataDeleted.include(node: CrdtNode.include()),
      ),
      orderBy: (t) => t.uuidRowId,
      transaction: _transaction,
    );
    final metadataByTable = <String, List<CrdtDataRow>>{};
    for (final row in crdtRows) {
      (metadataByTable[tablesById[row.tblId]!] ??= []).add(row);
    }

    final loadedByTable = <String, Set<UuidValue>>{};
    for (final tableName in requestedRows.keys) {
      final tableRows = metadataByTable[tableName];
      if (tableRows == null) continue;
      final loadedIds = {for (final row in tableRows) row.uuidRowId};
      loadedByTable[tableName] = loadedIds;
      final columns = columnsByTable[tableName] ?? const <String>{};
      final valuesByRowId = columns.isEmpty
          ? <UuidValue, Map<String, Object?>>{}
          : await _context.readDomainColumnValues(
              tableName,
              loadedIds,
              columns.toList(),
              _transaction,
            );
      for (final row in tableRows) {
        final key = (tableName, row.uuidRowId);
        rows[key] = (
          key: key,
          crdtRow: row,
          values: Map<String, Object?>.from(valuesByRowId[row.uuidRowId] ?? const {}),
        );
      }
    }

    final columnsById = <int, String>{};
    final fieldRequests = <({Set<int> rows, Set<int> columns})>[];
    for (final tableName in metadataByTable.keys) {
      final columns = _context.schemaColumnIds(
        tableName,
        columnsByTable[tableName] ?? const <String>{},
      );
      if (columns.isEmpty) continue;
      columnsById.addAll({for (final entry in columns.entries) entry.value: entry.key});
      fieldRequests.add((
        rows: {for (final row in metadataByTable[tableName]!) row.id!},
        columns: columns.values.toSet(),
      ));
    }
    if (fieldRequests.isEmpty) return loadedByTable;

    final rowKeysById = {
      for (final row in crdtRows) row.id!: (tablesById[row.tblId]!, row.uuidRowId),
    };
    final fields = await CrdtDataField.db.find(
      _context.databaseSession,
      where: (t) => fieldRequests
          .map((request) {
            return t.rowId.inSet(request.rows) & t.columnId.inSet(request.columns);
          })
          .reduce((left, right) => left | right),
      include: CrdtDataField.include(
        node: CrdtNode.include(),
        attemptedValue: CrdtDataAttemptedValue.include(),
      ),
      transaction: _transaction,
    );
    for (final field in fields) {
      final rowKey = rowKeysById[field.rowId]!;
      final fieldKey = (rowKey.$1, rowKey.$2, columnsById[field.columnId]!);
      fieldIds[fieldKey] = field.id!;
      fieldHlcs[fieldKey] = field.hlc;
      if (field.attemptedValue case final attempted?) {
        attemptedValues[fieldKey] = attempted;
      }
    }
    return loadedByTable;
  }
}

/// Collects the required claim lookups for one closure wave by table.
/// Traversal selects the claims; this collector handles grouped execution.
/// Each composite claim remains independent when the queries are combined.
class _ProjectionClaimReads {
  _ProjectionClaimReads(
    this._context,
    this._transaction, {
    required this._includeAttemptedClaims,
  });

  final CrdtRecorderContext _context;
  final Transaction _transaction;
  final bool _includeAttemptedClaims;
  final _byTable = <String, List<Map<String, Set<Object?>>>>{};

  void add(String tableName, Map<String, Set<Object?>> claim) {
    (_byTable[tableName] ??= []).add(claim);
  }

  Future<void> enqueueMatches(
    void Function(String tableName, Iterable<UuidValue> ids) enqueue,
  ) async {
    for (final MapEntry(key: tableName, value: claims) in _byTable.entries) {
      enqueue(
        tableName,
        await _context.findDomainRowIdsWhereAnyColumnsIn(
          tableName: tableName,
          alternatives: claims,
          transaction: _transaction,
        ),
      );
      if (!_includeAttemptedClaims) continue;

      enqueue(
        tableName,
        await _context.findRowIdsHoldingAnyAttemptedValues(
          tableName: tableName,
          alternatives: [
            for (final claim in claims)
              (
                columnNames: claim.keys.toSet(),
                values: {for (final values in claim.values) ...values},
              ),
          ],
          transaction: _transaction,
        ),
      );
    }
  }
}
