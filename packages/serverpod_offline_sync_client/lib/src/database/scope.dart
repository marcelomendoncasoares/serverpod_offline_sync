part of 'database.dart';

extension _CrdtDatabaseScope on CrdtDatabase {
  ({
    List<T> rows,
    Set<int> stampedIndexes,
    Set<Object> explicitRowIds,
    bool isCrdtTracked,
  })
  _prepareRowsForInsert<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return (
        rows: rows,
        stampedIndexes: const {},
        explicitRowIds: const {},
        isCrdtTracked: false,
      );
    }

    final scope = _requireEffectiveScope(transaction);
    final effectiveScopeId = scope.id!;
    final databaseRows = <T>[];
    final stampedIndexes = <int>{};
    final explicitRowIds = <Object>{};

    for (final (index, row) in rows.indexed) {
      final rowScopeId = _readScopeId(row);
      if (rowScopeId == null) {
        databaseRows.add(_copyWithScopeId(row, effectiveScopeId));
        stampedIndexes.add(index);
        continue;
      }

      if (rowScopeId != effectiveScopeId) {
        throw StateError(
          'Cannot write ${row.table.tableName} row ${row.id} with scopeId '
          '$rowScopeId while acting in scope $effectiveScopeId.',
        );
      }

      databaseRows.add(row);
      final rowId = row.id;
      if (rowId != null) explicitRowIds.add(rowId as Object);
    }

    return (
      rows: databaseRows,
      stampedIndexes: stampedIndexes,
      explicitRowIds: explicitRowIds,
      isCrdtTracked: true,
    );
  }

  bool _shouldStripReturnedScopeId<T extends TableRow>(
    T row,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(row.table)) return false;

    final rowScopeId = _readScopeId(row);
    if (rowScopeId == null) return true;

    final effectiveScopeId = _requireEffectiveScope(transaction).id!;
    if (rowScopeId != effectiveScopeId) {
      throw StateError(
        'Cannot write ${row.table.tableName} row ${row.id} with scopeId '
        '$rowScopeId while acting in scope $effectiveScopeId.',
      );
    }

    return false;
  }

  void _assertNoScopeIdColumnValues<T extends TableRow>(
    List<ColumnValue> columnValues,
  ) {
    for (final columnValue in columnValues) {
      if (columnValue.column.columnName == 'scopeId') {
        final table = serializationManager.getTableForType(T)?.tableName ?? 'unknown';
        throw StateError(
          'scopeId is immutable and owned by the CRDT sync layer for $table.',
        );
      }
    }
  }

  CrdtScope _requireEffectiveScope(Transaction transaction) {
    return _recorder.scopeForQueries(transaction) ??
        (throw StateError(
          'A scope ID is required for CRDT writes without a persistent user.',
        ));
  }

  int? _readScopeId(TableRow row) => (row as dynamic).scopeId as int?;

  T _copyWithScopeId<T extends TableRow>(T row, int scopeId) {
    return (row as dynamic).copyWith(scopeId: scopeId) as T;
  }

  void _stripStampedRows<T extends TableRow>(
    List<T> rows,
    ({
      List<T> rows,
      Set<int> stampedIndexes,
      Set<Object> explicitRowIds,
      bool isCrdtTracked,
    })
    prepared,
  ) {
    if (rows.length == prepared.rows.length) {
      for (final (index, row) in rows.indexed) {
        if (prepared.stampedIndexes.contains(index)) _stripScopeId(row);
      }
      return;
    }

    // `ignoreConflicts` dropped rows, so positions no longer align with the
    // input. Keep the value only on rows whose id was caller-provided on an
    // explicit (asserted) input row; everything else is treated as stamped.
    for (final row in rows) {
      final rowId = row.id;
      if (rowId == null || !prepared.explicitRowIds.contains(rowId)) {
        _stripScopeId(row);
      }
    }
  }

  void _stripScopeId(TableRow row) {
    (row as dynamic).scopeId = null;
  }

  List<T> _stripScopeIdFromScopedRead<T extends TableRow>(
    List<T> rows,
    Include? include,
    Transaction? transaction,
  ) {
    if (rows.isEmpty) return rows;
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) return rows;
    if (_recorder.scopeForQueries(transaction) == null) return rows;

    final hasNestedRows =
        include != null && include.includes.values.any((inc) => inc != null);
    if (!hasNestedRows) {
      // Hot path: delegate-returned rows are package-owned, so the root
      // field is stripped in place with no allocation.
      rows.forEach(_stripScopeId);
      return rows;
    }

    // Nested models are only reachable through generated fields, which
    // cannot be accessed generically by name, so include graphs pay a
    // serialization round-trip per row to strip recursively.
    return [
      for (final row in rows) _copyWithScopeIdsStripped(row),
    ];
  }

  T _copyWithScopeIdsStripped<T extends TableRow>(T row) {
    final json = Map<String, dynamic>.from(row.toJson() as Map);
    _stripScopeIdsFromJson(json);
    return serializationManager.deserialize<T>(json);
  }

  void _stripScopeIdsFromJson(Object? value) {
    if (value is Map) {
      if (value.containsKey('scopeId')) {
        value['scopeId'] = null;
      }
      value.values.forEach(_stripScopeIdsFromJson);
      return;
    }

    if (value is Iterable) {
      value.forEach(_stripScopeIdsFromJson);
    }
  }
}

/// Extension on [Table] that exposes [scopeEquals] for use in `where`
/// clauses to restrict membership-wide reads to a single scope.
extension ScopeUuidFilter on Table {
  /// Expression that narrows a membership-wide read to [scopeUuid].
  ///
  /// Reads are membership-wide and strip the database-local `scopeId`, so a
  /// caller holding several scopes cannot otherwise restrict a query to one scope
  /// or tell which scope a row came from. The placeholder is resolved to a
  /// filter on the reserved `scopeId` column before the query runs. When the
  /// scope UUID is not known locally the filter matches no rows.
  ///
  /// Example:
  /// ```dart
  /// // Returns only persons in the shared scope.
  /// final sharedPeople = await Person.db.find(
  ///   session,
  ///   where: (t) => t.scopeEquals(sharedScopeUuid),
  /// );
  ///
  /// // Combines with other filters.
  /// final aliceInShared = await Person.db.find(
  ///   session,
  ///   where: (t) => t.name.equals('Alice') & t.scopeEquals(sharedScopeUuid),
  /// );
  /// ```
  Expression scopeEquals(UuidValue scopeUuid) =>
      _crdtScope.uuidScopeId.equals(scopeUuid);

  CrdtScopeTable get _crdtScope {
    return createRelationTable<CrdtScopeTable>(
      relationFieldName: '${tableName}_crdt_scope',
      field: _scopeIdColumn,
      foreignField: CrdtScope.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          CrdtScopeTable(tableRelation: foreignTableRelation),
    );
  }

  Column get _scopeIdColumn => columns.singleWhere(
    (column) => column.columnName == 'scopeId' && column is ColumnInt,
    orElse: () => throw StateError('Table "$tableName" has no scopeId column.'),
  );
}
