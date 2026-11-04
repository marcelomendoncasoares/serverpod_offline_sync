part of 'foreign_key_projector.dart';

/// Loads metadata for one projection read phase in one space and transaction.
/// Field identities are resolved through the scoped rows and registered columns,
/// so equal domain UUIDs in different tables remain distinct.
///
/// Its maps become mutable projection state. Complete loading before applying
/// pending inserts or authored overlays to them.
class _ProjectionReader {
  _ProjectionReader(this._context, this._transaction, this._cache);

  final CrdtRecorderContext _context;
  final Transaction _transaction;
  final CrdtProjectionReadCache? _cache;
  final rows = <MergeRowKey, _ProjectedForeignKeyRow>{};
  final fieldIds = <MergeFieldKey, int>{};
  final attemptedValues = <MergeFieldKey, CrdtDataAttemptedValue>{};
  final fieldHlcs = <MergeFieldKey, Hlc>{};

  /// Whether this space and these tables hold any attempted claims.
  /// A false result lets the closure skip attempted-claim queries, but is
  /// valid only until the next write phase; each projection checks again.
  Future<bool> hasAttemptedClaims(Set<String> tablesToLoad) async {
    final spaceId = _context.spaceIdFor(_transaction);
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
    final cache = _cache;
    if (cache == null || requestedRows.values.any((ids) => ids == null)) {
      return _loadRowsFromDatabase(
        requestedRows: requestedRows,
        columnsByTable: columnsByTable,
      );
    }

    final missing = <String, Set<UuidValue>>{};
    final loaded = <String, Set<UuidValue>>{};
    for (final MapEntry(key: table, value: ids) in requestedRows.entries) {
      final columns = columnsByTable[table] ?? const <String>{};
      for (final id in ids!) {
        final key = (table, id);
        final snapshot = cache._rows[key];
        if (snapshot == null) {
          if (!cache._rows.containsKey(key)) (missing[table] ??= {}).add(id);
          continue;
        }
        if (!snapshot.columns.containsAll(columns)) {
          (missing[table] ??= {}).add(id);
          continue;
        }

        rows[key] = (
          key: key,
          crdtRow: snapshot.row.crdtRow.copyWith(),
          values: {
            for (final column in columns)
              if (snapshot.row.values.containsKey(column))
                column: snapshot.row.values[column],
          },
        );
        fieldIds.addAll({
          for (final entry in snapshot.fieldIds.entries)
            if (columns.contains(entry.key.$3)) entry.key: entry.value,
        });
        fieldHlcs.addAll({
          for (final entry in snapshot.fieldHlcs.entries)
            if (columns.contains(entry.key.$3)) entry.key: entry.value,
        });
        attemptedValues.addAll({
          for (final entry in snapshot.attemptedValues.entries)
            if (columns.contains(entry.key.$3)) entry.key: entry.value.copyWith(),
        });
        (loaded[table] ??= {}).add(id);
      }
    }

    final fetched = await _loadRowsFromDatabase(
      requestedRows: missing,
      columnsByTable: columnsByTable,
    );
    for (final MapEntry(key: table, value: ids) in fetched.entries) {
      (loaded[table] ??= {}).addAll(ids);
    }
    for (final MapEntry(key: table, value: ids) in missing.entries) {
      final columns = columnsByTable[table] ?? const <String>{};
      for (final id in ids) {
        final key = (table, id);
        final row = rows[key];
        if (row == null) {
          cache._rows[key] = null;
          continue;
        }
        final keys = {for (final column in columns) (table, id, column)};
        cache._rows[key] = (
          row: _copyProjectionRow(row),
          columns: Set<String>.of(columns),
          fieldIds: {
            for (final key in keys)
              if (fieldIds.containsKey(key)) key: fieldIds[key]!,
          },
          fieldHlcs: {
            for (final key in keys)
              if (fieldHlcs.containsKey(key)) key: fieldHlcs[key]!,
          },
          attemptedValues: {
            for (final key in keys)
              if (attemptedValues.containsKey(key))
                key: attemptedValues[key]!.copyWith(),
          },
        );
      }
    }
    return loaded;
  }

  Future<Map<String, Set<UuidValue>>> _loadRowsFromDatabase({
    required Map<String, Set<UuidValue>?> requestedRows,
    required Map<String, Set<String>> columnsByTable,
  }) async {
    final tablesById = {
      for (final entry in requestedRows.entries)
        if (entry.value == null || entry.value!.isNotEmpty)
          _context.schema[entry.key]!.$1: entry.key,
    };
    if (tablesById.isEmpty) return {};

    final spaceId = _context.spaceIdFor(_transaction);
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
    required this._cache,
  });

  final CrdtRecorderContext _context;
  final Transaction _transaction;
  final bool _includeAttemptedClaims;
  final CrdtProjectionReadCache? _cache;
  final _byTable = <String, List<Map<String, Set<Object?>>>>{};

  void add(String tableName, Map<String, Set<Object?>> claim) {
    (_byTable[tableName] ??= []).add(claim);
  }

  Future<void> enqueueMatches(
    void Function(String tableName, Iterable<UuidValue> ids) enqueue,
  ) async {
    final requests = <(String, bool), List<Map<String, Set<Object?>>>>{};
    final cacheKeys = <(String, bool), (String, bool, String)>{};
    for (final MapEntry(key: tableName, value: claims) in _byTable.entries) {
      for (final attempted in [false, if (_includeAttemptedClaims) true]) {
        final key = (tableName, attempted);
        final cacheKey = _cache?._claimKey(
          tableName,
          claims,
          attempted: attempted,
        );
        final cached = cacheKey == null ? null : _cache!._claims[cacheKey];
        if (cached != null) {
          enqueue(tableName, cached);
          continue;
        }

        requests[key] = claims;
        if (cacheKey != null) cacheKeys[key] = cacheKey;
      }
    }
    final matches = await _context.findProjectionClaimRows(
      requests: requests,
      transaction: _transaction,
    );
    for (final MapEntry(key: key, value: ids) in matches.entries) {
      final cacheKey = cacheKeys[key];
      if (cacheKey != null) {
        _cache!._claims[cacheKey] = Set<UuidValue>.unmodifiable(ids);
      }
      enqueue(key.$1, ids);
    }
  }
}
