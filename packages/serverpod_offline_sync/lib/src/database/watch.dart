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
    final queryWhere = mergeWhereWithVisibility<T>(
      serializationManager,
      where,
      queryInclude,
      whereVisible: (table) {
        if (table.id is! ColumnUuid ||
            !_context.isCrdtTrackedTableName(table.tableName)) {
          return null;
        }
        return _watchVisibility(table);
      },
    );

    final dependencies = _watchDependencies(
      table: serializationManager.getTableForType(T)!,
      where: where,
      orderBy: orderByList ?? [?orderBy],
      include: include,
      extraTables: alsoTriggerOnTables,
    );
    final tracked = dependencies.where(_context.isCrdtTrackedTableName).toSet();
    final untracked = dependencies.difference(tracked);

    // Each invalidation takes one committed snapshot through Serverpod's typed
    // watch, including its included-list loading and deserialization.
    Stream<List<T>> query({Duration? throttle}) => _delegate.watch<T>(
      where: queryWhere,
      limit: limit,
      offset: offset,
      orderBy: orderBy,
      orderByList: orderByList,
      include: queryInclude,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );

    final stream = tracked.isEmpty || dialect != DatabaseDialect.sqlite
        ? query(throttle: throttle)
        : _watchCommittedQueries(
            revisions: visibleTableRevisions(_delegate, tracked),
            otherChanges: untracked.isEmpty
                ? null
                : _delegate.unsafeWatch(
                    'SELECT 1',
                    triggerOnTables: untracked,
                    throttle: null,
                  ),
            query: () => _readOutsideTransaction(() => query().first),
            throttle: throttle,
          );

    return stream.map((rows) {
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

Future<T> _readOutsideTransaction<T>(Future<T> Function() read) {
  // A later invalidation can run in the zone where the subscription began,
  // after Serverpod has cleared its transaction-parent zone reference. Creating
  // a fresh delegate watch there would retain SQLite's expired lock guard.
  // Only the read leaves that zone; timers and subscriber callbacks retain it.
  // Bridge errors explicitly because Futures cannot cross error-zone boundaries.
  final result = Completer<T>();
  unawaited(
    Zone.root.run(() async {
      try {
        result.complete(await read());
      } on Object catch (error, stack) {
        result.completeError(error, stack);
      }
    }),
  );
  return result.future;
}

// Match Serverpod's typed watch dependency traversal, including relation hops
// and expressions beneath included lists. Raw SQL needs explicit extra tables.
Set<String> _watchDependencies({
  required Table table,
  required List<Column> orderBy,
  Expression? where,
  Include? include,
  Iterable<Table>? extraTables,
}) {
  final tables = <String>{};

  void addTable(Table? table) {
    if (table == null) return;
    tables.add(table.tableName);
    final relation = table.tableRelation;
    if (relation == null) return;
    for (final hop in relation.getRelations) {
      tables
        ..add(hop.fieldTable.tableName)
        ..add(hop.foreignTable.tableName);
    }
  }

  void addExpression(Expression? expression) {
    for (final column in expression?.columns ?? <Column>[]) {
      addTable(column.table);
      if (column is ColumnCount) addExpression(column.innerWhere);
    }
  }

  void addColumn(Column? column) {
    final inner = column is Order ? column.column : column;
    addTable(inner?.table);
    if (inner is ColumnCount) addExpression(inner.innerWhere);
  }

  void addInclude(Include? include) {
    if (include == null) return;
    addTable(include.table);
    if (include is IncludeList) {
      addExpression(include.where);
      addColumn(include.orderBy);
      include.orderByList?.forEach(addColumn);
      addInclude(include.include);
    }
    include.includes.values.forEach(addInclude);
  }

  addTable(table);
  addExpression(where);
  orderBy.forEach(addColumn);
  addInclude(include);
  extraTables?.forEach(addTable);
  return tables;
}

/// Combines revision changes and ordinary SQLite notifications before applying
/// the caller's throttle. Reads are serialized; changes during a read or pause
/// are retained for the next execution.
Stream<T> _watchCommittedQueries<T>({
  required Stream<Map<String, int>> revisions,
  required Stream<DatabaseResult>? otherChanges,
  required Future<T> Function() query,
  required Duration? throttle,
}) {
  // The subscription owns the controller's lifetime.
  // ignore: close_sinks
  late StreamController<T> controller;
  final subscriptions = <StreamSubscription<dynamic>>[];
  Timer? timer;
  final sinceQuery = Stopwatch();
  var dirty = false;
  var running = false;
  var cancelled = false;
  var revisionsReady = false;
  var otherReady = otherChanges == null;
  var openSources = otherChanges == null ? 1 : 2;

  void finishIfDone() {
    if (openSources == 0 &&
        !cancelled &&
        !running &&
        timer == null &&
        (!dirty || !revisionsReady || !otherReady)) {
      unawaited(controller.close());
    }
  }

  void sourceDone() {
    openSources--;
    finishIfDone();
  }

  void schedule() {
    if (cancelled ||
        running ||
        controller.isPaused ||
        !dirty ||
        timer != null ||
        !revisionsReady ||
        !otherReady) {
      return;
    }
    final delay = throttle == null || !sinceQuery.isRunning
        ? Duration.zero
        : throttle - sinceQuery.elapsed;
    timer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      timer = null;
      if (cancelled || controller.isPaused) return;
      dirty = false;
      running = true;
      sinceQuery
        ..reset()
        ..start();
      try {
        final result = await query();
        if (!cancelled) controller.add(result);
      } on Object catch (error, stack) {
        if (!cancelled) controller.addError(error, stack);
      } finally {
        running = false;
        schedule();
        finishIfDone();
      }
    });
  }

  void changed(Object? _) {
    dirty = true;
    schedule();
  }

  controller = StreamController<T>(
    onListen: () {
      subscriptions.add(
        revisions.listen(
          (event) {
            revisionsReady = true;
            changed(event);
          },
          onError: controller.addError,
          onDone: sourceDone,
        ),
      );
      if (otherChanges != null) {
        subscriptions.add(
          otherChanges.listen(
            (event) {
              otherReady = true;
              changed(event);
            },
            onError: controller.addError,
            onDone: sourceDone,
          ),
        );
      }
    },
    onPause: () {
      for (final subscription in subscriptions) {
        subscription.pause();
      }
    },
    onResume: () {
      for (final subscription in subscriptions) {
        subscription.resume();
      }
      schedule();
    },
    onCancel: () async {
      cancelled = true;
      timer?.cancel();
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
