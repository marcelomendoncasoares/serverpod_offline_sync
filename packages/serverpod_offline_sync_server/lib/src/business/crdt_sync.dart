import 'package:serverpod/serverpod.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

/// Extension methods for [Serverpod] to configure the CRDT sync on the server.
extension CrdtSyncInitialize on Serverpod {
  /// Configures the CRDT sync on the server.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization.
  void initializeCrdtSync({required List<Table> syncTables}) {
    CrdtSync.initialize(
      syncTables: syncTables,
      serializationManager: serializationManager,
    );
  }
}

/// The singleton for CRDT-based offline-first synchronization.
///
/// Call `pod.initializeCrdtSync(...)` once during server startup before any
/// sync requests are made.
class CrdtSync {
  /// Creates a new instance of [CrdtSync] singleton.
  CrdtSync._(
    this._syncTables,
    this._serializationManager,
  );

  /// The list of tables to synchronize.
  final List<Table> _syncTables;

  /// The serialization manager for deserialization.
  final DatabaseSerializationManager _serializationManager;

  /// The singleton instance of [CrdtSync].
  static CrdtSync? _instance;

  /// The singleton instance of [CrdtSync]. Throws a [StateError] if the
  /// singleton is not initialized.
  static CrdtSync get instance =>
      _instance ??
      (throw StateError(
        'The CrdtSync has not been initialized. Call pod.initializeCrdtSync(...) '
        'during server startup to configure the CRDT sync.',
      ));

  /// The map of table names to tables for synchronization.
  late final Map<String, Table> _syncTablesByName = {
    for (final t in _syncTables) t.tableName: t,
  };

  /// The map of table names to class names for deserialization.
  late final Map<String, String> _classNamesByTableName = {
    for (final def in _serializationManager.getTargetTableDefinitions())
      if (def.dartName != null) def.name: def.dartName!,
  };

  /// The map of table names to column definitions for value decoding.
  late final Map<String, Map<String, ColumnDefinition>> _columnDefinitionsByTableName =
      {
        for (final def in _serializationManager.getTargetTableDefinitions())
          def.name: {
            for (final column in def.columns) column.name: column,
          },
      };

  /// The hash of the current sync tables for schema validation.
  late final String _currentSyncTablesHash = computeSyncTablesHash(_syncTables);

  /// Configures the endpoint with the given sync tables and serialization manager.
  ///
  /// Must be called during server startup before any sync requests are made.
  /// Will override any previous initialization.
  static void initialize({
    required List<Table> syncTables,
    required DatabaseSerializationManager serializationManager,
  }) {
    _instance = CrdtSync._(syncTables, serializationManager);
  }

  /// Computes a deterministic hash of the sync tables for schema validation.
  ///
  /// The hash is a canonical string built from sorted table names and their
  /// sorted column names, plus foreign key and unique-index constraints. Both
  /// sides must produce the same value for a sync to proceed.
  static String computeSyncTablesHash(List<Table> syncTables) {
    final tableDefinitionsByName = {
      for (final def in instance._serializationManager.getTargetTableDefinitions())
        def.name: def,
    };

    final sortedTables = syncTables.toList()
      ..sort((a, b) => a.tableName.compareTo(b.tableName));

    return sortedTables
        .map((table) {
          final cols = table.columns.map((c) => c.columnName).toList()..sort();
          final definition = tableDefinitionsByName[table.tableName];
          final foreignKeys = _canonicalForeignKeys(definition);
          final uniqueIndexes = _canonicalUniqueIndexes(definition);
          return '${table.tableName}:'
              '${cols.join(',')}|'
              'fk[${foreignKeys.join(';')}]|'
              'uq[${uniqueIndexes.join(';')}]';
        })
        .join(';');
  }

  /// Synchronizes CRDT changes between two nodes for the given authenticated user.
  ///
  /// First validates [syncTablesHash] against the server's configured tables.
  /// If the hashes differ, a [SyncTablesHashMismatchException] is thrown,
  /// telling the older node to migrate its schema first.
  ///
  /// The current node then streams all changes since [lastSyncHlc] to the caller,
  /// followed by a null value as sentinel. The caller should stream its own
  /// changes in the [changes] stream and close with its own null sentinel.
  /// Once the null sentinel is received the server merges all accumulated
  /// client changes atomically.
  Stream<CrdtMergeChange?> syncNodeForUser(
    DatabaseSession session, {
    required UuidValue userId,
    required String syncTablesHash,
    required Hlc lastSyncHlc,
    required Stream<CrdtMergeChange?> changes,
  }) async* {
    if (syncTablesHash != _currentSyncTablesHash) {
      throw SyncTablesHashMismatchException(
        received: syncTablesHash,
        expected: _currentSyncTablesHash,
      );
    }

    final crdtUser = await CrdtUserManager.getOrCreate(session, userId);

    yield* _streamServerChanges(session, crdtUser, lastSyncHlc);

    yield null;

    final mergeInserts = <CrdtMergeInsert>[];
    final mergeUpdates = <CrdtMergeUpdate>[];
    final mergeDeletes = <CrdtMergeDelete>[];
    var receivedStopSentinel = false;

    await for (final change in changes) {
      switch (change) {
        case null:
          receivedStopSentinel = true;
        case final CrdtMergeInsert insert:
          mergeInserts.add(insert);
          continue;
        case final CrdtMergeUpdate update:
          mergeUpdates.add(update);
          continue;
        case final CrdtMergeDelete delete:
          mergeDeletes.add(delete);
          continue;
      }
      break;
    }

    if (!receivedStopSentinel) return;

    final mergeSet = CrdtMergeSet(
      inserts: mergeInserts,
      updates: mergeUpdates,
      deletes: mergeDeletes,
    );

    if (mergeSet.isEmpty) return;

    final crdtDb = CrdtDatabase(session.db, syncTables: _syncTables);
    await crdtDb.initialize();
    await crdtDb.mergeChanges(mergeSet, userId: userId);
  }

  Stream<CrdtMergeChange> _streamServerChanges(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    yield* _streamInserts(session, crdtUser, lastSyncHlc);
    yield* _streamUpdates(session, crdtUser, lastSyncHlc);
    yield* _streamDeletes(session, crdtUser, lastSyncHlc);
  }

  Stream<CrdtMergeInsert> _streamInserts(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final rows = await CrdtDataRow.db.find(
      session,
      where: (t) => _rowHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataRow.include(
        tbl: CrdtSchemaTable.include(),
        node: CrdtNode.include(),
      ),
    );

    for (final row in rows) {
      final tableName = row.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final table = _syncTablesByName[tableName]!;
      final dartName = _classNamesByTableName[tableName];
      if (dartName == null) continue;

      final domainRow = await _fetchDomainRow(
        session,
        tableName,
        row.uuidRowId,
        table,
        dartName,
      );
      if (domainRow == null) continue;

      yield CrdtMergeInsert(
        hlcDatetime: row.hlcDatetime,
        hlcCounter: row.hlcCounter,
        tableName: tableName,
        uuidRowId: row.uuidRowId,
        uuidNodeId: row.node!.uuidNodeId,
        data: domainRow,
      );
    }
  }

  Stream<CrdtMergeUpdate> _streamUpdates(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final fields = await CrdtDataField.db.find(
      session,
      where: (t) => _fieldHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataField.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        column: CrdtSchemaColumn.include(),
        node: CrdtNode.include(),
      ),
    );

    for (final field in fields) {
      final tableName = field.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      final columnName = field.column!.name;

      final decodedValue = await _fetchColumnValue(
        session,
        tableName,
        field.row!.uuidRowId,
        columnName,
      );

      yield CrdtMergeUpdate(
        hlcDatetime: field.hlcDatetime,
        hlcCounter: field.hlcCounter,
        tableName: tableName,
        uuidRowId: field.row!.uuidRowId,
        uuidNodeId: field.node!.uuidNodeId,
        columnName: columnName,
        value: decodedValue,
      );
    }
  }

  Stream<CrdtMergeDelete> _streamDeletes(
    DatabaseSession session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) async* {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      where: (t) => _tombstoneHlcAfterFilter(t, crdtUser, lastSyncHlc),
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
        node: CrdtNode.include(),
      ),
    );

    for (final tombstone in tombstones) {
      final tableName = tombstone.row!.tbl!.name;
      if (!_syncTablesByName.containsKey(tableName)) continue;

      yield CrdtMergeDelete(
        hlcDatetime: tombstone.hlcDatetime,
        hlcCounter: tombstone.hlcCounter,
        tableName: tableName,
        uuidRowId: tombstone.row!.uuidRowId,
        uuidNodeId: tombstone.node!.uuidNodeId,
        isDeleted: tombstone.isDeleted,
      );
    }
  }

  Expression _rowHlcAfterFilter(
    CrdtDataRowTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Future<dynamic> _fetchDomainRow(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    Table table,
    String dartName,
  ) async {
    final cols = table.columns.map((c) => '"${c.columnName}"').join(', ');
    final encodedRowId = ValueEncoder.instance.convert(rowId);
    final result = await session.db.unsafeQuery(
      'SELECT $cols FROM "$tableName" WHERE "id" = $encodedRowId',
    );
    if (result.isEmpty) return null;

    final columnMap = result.first.toColumnMap();
    return session.db.serializationManager.deserializeByClassName({
      'className': dartName,
      'data': columnMap,
    });
  }

  Future<dynamic> _fetchColumnValue(
    DatabaseSession session,
    String tableName,
    UuidValue rowId,
    String columnName,
  ) async {
    final encodedValue = ValueEncoder.instance.convert(rowId);
    final result = await session.db.unsafeQuery(
      'SELECT "$columnName" FROM "$tableName" WHERE "id" = $encodedValue',
    );
    if (result.isEmpty) return null;
    return _decodeColumnValue(tableName, columnName, result.first[0]);
  }

  dynamic _decodeColumnValue(
    String tableName,
    String columnName,
    Object? value,
  ) {
    if (value == null) return null;

    final definition = _columnDefinitionsByTableName[tableName]?[columnName];
    final dartType = definition?.dartType;
    if (dartType == null) return value;

    final className = _classNameForDartType(dartType);
    return switch (className) {
      'bool' || 'double' || 'int' || 'String' => value,
      _ => _serializationManager.deserializeByClassName({
        'className': className,
        'data': value,
      }),
    };
  }

  String _classNameForDartType(String dartType) {
    final withoutNullable = dartType.endsWith('?')
        ? dartType.substring(0, dartType.length - 1)
        : dartType;
    return withoutNullable.split(':').last;
  }

  static List<String> _canonicalForeignKeys(TableDefinition? definition) {
    if (definition == null) return const [];
    final entries = <String>[
      for (final fk in definition.foreignKeys)
        // Each foreign key must map all parameters.
        // ignore: no_adjacent_strings_in_list
        '${(fk.columns.toList()..sort()).join(',')}->'
            '${fk.referenceTableSchema}.${fk.referenceTable}'
            '(${(fk.referenceColumns.toList()..sort()).join(',')})'
            '|u:${fk.onUpdate?.toString() ?? '-'}'
            '|d:${fk.onDelete?.toString() ?? '-'}'
            '|m:${fk.matchType?.toString() ?? '-'}',
    ]..sort();

    return entries;
  }

  static List<String> _canonicalUniqueIndexes(TableDefinition? definition) {
    if (definition == null) return const [];

    final entries = <String>[
      for (final index in definition.indexes)
        if (index.isUnique && !(index.isPrimary))
          () {
            final elements = index.elements;
            final sortedElements = [
              for (final element in elements) '${element.type}:${element.definition}',
            ]..sort();
            return sortedElements.join(',');
          }(),
    ]..sort();

    return entries;
  }
}

/// Thrown when the sync tables hash sent by a client does not match the server.
///
/// This means the client and server are at different schema versions. The
/// older side must migrate before a sync can proceed.
class SyncTablesHashMismatchException implements Exception {
  /// Creates a new [SyncTablesHashMismatchException].
  SyncTablesHashMismatchException({
    required this.received,
    required this.expected,
  });

  /// The hash received from the remote peer.
  final String received;

  /// The hash computed locally from the configured sync tables.
  final String expected;

  @override
  String toString() =>
      'SyncTablesHashMismatchException: schema hash mismatch. '
      'Received "$received", expected "$expected". '
      'Ensure both sides are on the same schema version before syncing.';
}
