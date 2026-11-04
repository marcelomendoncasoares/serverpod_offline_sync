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

    Stream<DatabaseResult> notifications(Iterable<String> tables) =>
        _delegate.unsafeWatch('SELECT 1', triggerOnTables: tables, throttle: null);

    final stream = tracked.isEmpty || dialect != DatabaseDialect.sqlite
        ? query(throttle: throttle)
        : _watchNativeQueries(
            effects: _watchEffects,
            dependencies: tracked,
            domainChanges: notifications({
              ...dependencies,
              CrdtSchemaTable.t.tableName,
            }),
            metadataChanges: notifications({
              CrdtDataRow.t.tableName,
              CrdtDataDeleted.t.tableName,
            }),
            membershipChanges: _watchMembership(),
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

  Stream<String>? _watchMembership() {
    final userId = _recorder.persistentUserId;
    if (userId == null) return null;
    final space = OfflineSyncSpace.t;
    final member = OfflineSyncSpaceMember.t;
    return _delegate
        .unsafeWatch(
          'SELECT ${space.id} AS visible_space FROM "${space.tableName}" '
          'WHERE ${space.uuidSpaceId.equals(userId)} '
          'UNION SELECT ${member.spaceId} FROM "${member.tableName}" '
          'WHERE ${member.userUuid.equals(userId)} ORDER BY visible_space',
          triggerOnTables: {space.tableName, member.tableName},
          throttle: null,
        )
        .map((rows) => rows.map((row) => row.first).join(','))
        .distinct();
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

/// Serializes reads woken exclusively by native SQLite watch streams.
/// Metadata is filtered before scheduling; invalidations during reads or pauses
/// remain dirty. Each successful query acknowledges its start-time versions.
Stream<T> _watchNativeQueries<T>({
  required NativeWatchEffects effects,
  required Set<String> dependencies,
  required Stream<DatabaseResult> domainChanges,
  required Stream<DatabaseResult> metadataChanges,
  required Stream<String>? membershipChanges,
  required Future<T> Function() query,
  required Duration? throttle,
}) {
  // The subscription owns the controller's lifetime.
  // ignore: close_sinks
  late StreamController<T> controller;
  final subscriptions = <StreamSubscription<dynamic>>[];
  final ready = <bool>[false, false, if (membershipChanges != null) false];
  Timer? timer;
  final sinceQuery = Stopwatch();
  NativeWatchSnapshot? acknowledged;
  var dirty = false;
  var running = false;
  var cancelled = false;
  var openSources = ready.length;

  void finishIfDone() {
    if (openSources == 0 &&
        !cancelled &&
        !running &&
        timer == null &&
        (!dirty || !ready.every((value) => value))) {
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
        !ready.every((value) => value)) {
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
      final snapshot = effects.capture(dependencies);
      try {
        final result = await query();
        acknowledged = snapshot;
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

  void listen(Stream<dynamic> source, int index, {bool metadata = false}) {
    subscriptions.add(
      source.listen(
        (_) {
          final initial = !ready[index];
          ready[index] = true;
          if (initial || !metadata || effects.shouldQuery(dependencies, acknowledged)) {
            dirty = true;
          }
          schedule();
        },
        onError: controller.addError,
        onDone: sourceDone,
      ),
    );
  }

  controller = StreamController<T>(
    onListen: () {
      listen(domainChanges, 0);
      listen(metadataChanges, 1, metadata: true);
      if (membershipChanges != null) listen(membershipChanges, 2);
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
