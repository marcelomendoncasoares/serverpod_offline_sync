part of 'database.dart';

extension _OfflineSyncDatabaseSpace on OfflineSyncDatabase {
  ({
    List<T> rows,
    Set<int> stampedIndexes,
    Set<Object> explicitRowIds,
  })
  _prepareRowsForInsert<T extends TableRow>(
    List<T> rows,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) {
      return (rows: rows, stampedIndexes: const {}, explicitRowIds: const {});
    }

    final space = _requireEffectiveSpace(transaction);
    final effectiveSpaceId = space.id!;
    final databaseRows = <T>[];
    final stampedIndexes = <int>{};
    final explicitRowIds = <Object>{};

    for (final (index, row) in rows.indexed) {
      final rowSpaceId = _readSpaceId(row);
      if (rowSpaceId == null) {
        databaseRows.add(row.copyWithSpaceId(effectiveSpaceId));
        stampedIndexes.add(index);
        continue;
      }

      if (rowSpaceId != effectiveSpaceId) {
        throw StateError(
          'Cannot write ${row.table.tableName} row ${row.id} with spaceId '
          '$rowSpaceId while acting in space $effectiveSpaceId.',
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
    );
  }

  bool _shouldStripReturnedSpaceId<T extends TableRow>(
    T row,
    Transaction transaction,
  ) {
    if (!_recorder.isCrdtTracked<T>(row.table)) return false;

    final rowSpaceId = _readSpaceId(row);
    if (rowSpaceId == null) return true;

    final effectiveSpaceId = _requireEffectiveSpace(transaction).id!;
    if (rowSpaceId != effectiveSpaceId) {
      throw StateError(
        'Cannot write ${row.table.tableName} row ${row.id} with spaceId '
        '$rowSpaceId while acting in space $effectiveSpaceId.',
      );
    }

    return false;
  }

  void _assertNoSpaceIdColumnValues<T extends TableRow>(
    List<ColumnValue> columnValues,
  ) {
    for (final columnValue in columnValues) {
      if (columnValue.column.columnName == 'spaceId') {
        final table = serializationManager.getTableForType(T)?.tableName ?? 'unknown';
        throw StateError(
          'spaceId is immutable and owned by the CRDT sync layer for $table.',
        );
      }
    }
  }

  OfflineSyncSpace _requireEffectiveSpace(Transaction transaction) {
    return _recorder.spaceForQueries(transaction) ??
        (throw StateError(
          'A space ID is required for CRDT writes without a persistent user.',
        ));
  }

  int? _readSpaceId(TableRow row) => (row as dynamic).spaceId as int?;

  void _stripStampedRows<T extends TableRow>(
    List<T> rows,
    ({
      List<T> rows,
      Set<int> stampedIndexes,
      Set<Object> explicitRowIds,
    })
    prepared,
  ) {
    if (rows.length == prepared.rows.length) {
      for (final (index, row) in rows.indexed) {
        if (prepared.stampedIndexes.contains(index)) _stripSpaceId(row);
      }
      return;
    }

    // `ignoreConflicts` dropped rows, so positions no longer align with the
    // input. Keep the value only on rows whose id was caller-provided on an
    // explicit (asserted) input row; everything else is treated as stamped.
    for (final row in rows) {
      final rowId = row.id;
      if (rowId == null || !prepared.explicitRowIds.contains(rowId)) {
        _stripSpaceId(row);
      }
    }
  }

  void _stripSpaceId(TableRow row) {
    (row as dynamic).spaceId = null;
  }

  List<T> _stripSpaceIdFromSpaceScopedRead<T extends TableRow>(
    List<T> rows,
    Include? include,
    Transaction? transaction,
  ) {
    if (rows.isEmpty) return rows;
    if (!_recorder.isCrdtTracked<T>(rows.first.table)) return rows;
    if (_recorder.spaceForQueries(transaction) == null) return rows;

    final hasNestedRows =
        include != null && include.includes.values.any((inc) => inc != null);
    if (!hasNestedRows) {
      // Hot path: delegate-returned rows are package-owned, so the root
      // field is stripped in place with no allocation.
      rows.forEach(_stripSpaceId);
      return rows;
    }

    // Nested models are only reachable through generated fields, which
    // cannot be accessed generically by name, so include graphs pay a
    // serialization round-trip per row to strip recursively.
    return [
      for (final row in rows) _copyWithSpaceIdsStripped(row),
    ];
  }

  T _copyWithSpaceIdsStripped<T extends TableRow>(T row) {
    final json = Map<String, dynamic>.from(row.toJson() as Map);
    _stripSpaceIdsFromJson(json);
    return serializationManager.deserialize<T>(json);
  }

  void _stripSpaceIdsFromJson(Object? value) {
    if (value is Map) {
      if (value.containsKey('spaceId')) {
        value['spaceId'] = null;
      }
      value.values.forEach(_stripSpaceIdsFromJson);
      return;
    }

    if (value is Iterable) {
      value.forEach(_stripSpaceIdsFromJson);
    }
  }
}

/// Extension on [Table] that exposes [spaceEquals] for use in `where`
/// clauses to restrict membership-wide reads to a single space.
extension SpaceUuidFilter on Table {
  /// Expression that narrows a membership-wide read to [spaceUuid].
  ///
  /// Reads are membership-wide and strip the database-local `spaceId`, so a
  /// caller holding several spaces cannot otherwise restrict a query to one space
  /// or tell which space a row came from. The placeholder is resolved to a
  /// filter on the reserved `spaceId` column before the query runs. When the
  /// space UUID is not known locally the filter matches no rows.
  ///
  /// Example:
  /// ```dart
  /// // Returns only persons in the shared space.
  /// final sharedPeople = await Person.db.find(
  ///   session,
  ///   where: (t) => t.spaceEquals(sharedSpaceUuid),
  /// );
  ///
  /// // Combines with other filters.
  /// final aliceInShared = await Person.db.find(
  ///   session,
  ///   where: (t) => t.name.equals('Alice') & t.spaceEquals(sharedSpaceUuid),
  /// );
  /// ```
  Expression spaceEquals(UuidValue spaceUuid) =>
      _offlineSyncSpace.uuidSpaceId.equals(spaceUuid);

  OfflineSyncSpaceTable get _offlineSyncSpace {
    return createRelationTable<OfflineSyncSpaceTable>(
      relationFieldName: '${tableName}_offline_sync_space',
      field: _spaceIdColumn,
      foreignField: OfflineSyncSpace.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          OfflineSyncSpaceTable(tableRelation: foreignTableRelation),
    );
  }

  Column get _spaceIdColumn =>
      offlineSyncSpaceIdColumn ??
      (throw StateError('Table "$tableName" has no spaceId column.'));
}
