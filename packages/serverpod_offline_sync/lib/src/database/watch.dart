part of 'database.dart';

extension _OfflineSyncDatabaseWatch on OfflineSyncDatabase {
  Stream<List<T>> _watch<T extends TableRow>({
    Expression? where,
    int? limit,
    int? offset,
    Column? orderBy,
    List<Column>? orderByList,
    Include? include,
    Duration? throttle,
    Iterable<Table>? alsoTriggerOnTables,
  }) {
    final queryInclude = copyInclude(include);
    var hasVisibilityPredicate = false;
    final queryWhere = mergeWhereWithVisibility<T>(
      serializationManager,
      where,
      queryInclude,
      whereVisible: (table) {
        if (table.id is! ColumnUuid ||
            !_context.isCrdtTrackedTableName(table.tableName)) {
          return null;
        }
        hasVisibilityPredicate = true;
        return _watchVisibility(table);
      },
    );

    // Build synchronously and let Serverpod own subscription creation. In
    // particular, its watch leaves any ambient SQLite transaction lock zone.
    // Initialize the sync database before watching when schema reconciliation
    // or projection rebuilding is needed. This read-only path resolves schema
    // IDs and membership from committed metadata on each execution.
    return _delegate
        .watch<T>(
          where: queryWhere,
          limit: limit,
          offset: offset,
          orderBy: orderBy,
          orderByList: orderByList,
          include: queryInclude,
          throttle: throttle,
          alsoTriggerOnTables: [
            ...?alsoTriggerOnTables,
            if (hasVisibilityPredicate) ...[
              CrdtDataRow.t,
              CrdtSchemaTable.t,
              if (_recorder.persistentUserId != null) ...[
                OfflineSyncSpace.t,
                OfflineSyncSpaceMember.t,
              ],
            ],
          ],
        )
        .map((rows) {
          if (_recorder.persistentUserId == null ||
              rows.isEmpty ||
              !_recorder.isCrdtTracked<T>(rows.first.table)) {
            return rows;
          }
          if (queryInclude != null &&
              queryInclude.includes.values.any((nested) => nested != null)) {
            return [for (final row in rows) _copyWithSpaceIdsStripped(row)];
          }
          rows.forEach(_stripSpaceId);
          return rows;
        });
  }

  Expression _watchVisibility(Table table) {
    final spaceColumn =
        table.offlineSyncSpaceIdColumn ??
        (throw StateError('Synced table "${table.tableName}" has no spaceId column.'));
    final row = CrdtDataRow.t;
    final schema = CrdtSchemaTable.t;
    final userId = _recorder.persistentUserId;
    Expression? memberSpaces;
    if (userId != null) {
      final space = OfflineSyncSpace.t;
      final member = OfflineSyncSpaceMember.t;
      memberSpaces = Expression(
        '$spaceColumn IN ( '
        'SELECT ${space.id} FROM "${space.tableName}" '
        'WHERE ${space.uuidSpaceId.equals(userId)} '
        'UNION SELECT ${member.spaceId} FROM "${member.tableName}" '
        'WHERE ${member.userUuid.equals(userId)})',
      );
    }

    return crdtRowVisibilityPredicate(
      table,
      tableId: Expression(
        '(SELECT ${schema.id} FROM "${schema.tableName}" '
        'WHERE ${schema.name.equals(table.tableName)})',
      ),
      crdtSpaceFilter: Expression('${row.spaceId} = $spaceColumn'),
      domainSpaceFilter: memberSpaces,
    );
  }
}
