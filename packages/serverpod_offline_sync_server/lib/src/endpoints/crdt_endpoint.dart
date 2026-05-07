import 'package:serverpod/serverpod.dart';
import 'package:serverpod_offline_sync_client/serverpod_offline_sync_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../generated/protocol.dart';

/// Thrown when the [syncTablesHash] sent by a client does not match the server.
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

/// Endpoint for CRDT-based offline-first synchronization.
///
/// Call [configure] once during server startup with the set of tables that
/// participate in sync and the application-level serialization manager (so the
/// endpoint can encode/decode domain rows such as `Person`).
class CrdtEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  static List<Table>? _syncTables;
  static DatabaseSerializationManager? _serializationManager;
  static Map<String, Table>? _syncTablesByName;
  static Map<String, String>? _dartNamesByTableName;

  /// Configures the endpoint with the given sync tables and serialization manager.
  ///
  /// Must be called during server startup before any sync requests are made.
  static void configure({
    required List<Table> syncTables,
    required DatabaseSerializationManager serializationManager,
  }) {
    _syncTables = syncTables;
    _serializationManager = serializationManager;
    _syncTablesByName = {for (final t in syncTables) t.tableName: t};
    _dartNamesByTableName = {
      for (final def in serializationManager.getTargetTableDefinitions())
        if (def.dartName != null) def.name: def.dartName!,
    };
  }

  /// Computes a deterministic hash of the sync tables for schema validation.
  ///
  /// The hash is a canonical string built from sorted table names and their
  /// sorted column names. Both sides must produce the same value for a sync
  /// to proceed.
  static String computeSyncTablesHash(List<Table> syncTables) {
    final sortedTables = syncTables.toList()
      ..sort((a, b) => a.tableName.compareTo(b.tableName));
    return sortedTables.map((table) {
      final cols = table.columns.map((c) => c.columnName).toList()..sort();
      return '${table.tableName}:${cols.join(',')}';
    }).join(';');
  }

  /// Synchronizes CRDT changes between the server and an authenticated client.
  ///
  /// First validates [syncTablesHash] against the server's configured tables.
  /// If the hashes differ, a [SyncTablesHashMismatchException] is thrown,
  /// telling the client to migrate its schema first.
  ///
  /// The server then streams all changes since [lastSyncHlc] to the caller,
  /// followed by a [CrdtMergeSyncStop] sentinel. The caller should stream its
  /// own changes in the [changes] stream and close with its own
  /// [CrdtMergeSyncStop]. Once the stop sentinel is received the server merges
  /// all accumulated client changes atomically.
  Stream<CrdtMergeChange> syncNode(
    Session session, {
    required String syncTablesHash,
    required Hlc lastSyncHlc,
    required Stream<CrdtMergeChange> changes,
  }) async* {
    final syncTables = _syncTables;
    final serializationManager = _serializationManager;
    if (syncTables == null || serializationManager == null) {
      throw StateError(
        'CrdtEndpoint has not been configured. '
        'Call CrdtEndpoint.configure() during server startup.',
      );
    }

    final expectedHash = computeSyncTablesHash(syncTables);
    if (syncTablesHash != expectedHash) {
      throw SyncTablesHashMismatchException(
        received: syncTablesHash,
        expected: expectedHash,
      );
    }

    final authInfo = (await session.authenticated)!;
    final userUuid = UuidValue.withValidation(authInfo.userIdentifier);
    final crdtUser = await CrdtUserManager.getOrCreate(session, userUuid);

    yield* _streamServerChanges(
      session,
      crdtUser,
      lastSyncHlc,
      serializationManager,
    );

    yield _syncStop;

    final mergeInserts = <CrdtMergeInsert>[];
    final mergeUpdates = <CrdtMergeUpdate>[];
    final mergeDeletes = <CrdtMergeDelete>[];

    await for (final change in changes) {
      switch (change) {
        case CrdtMergeSyncStop():
          break;
        case CrdtMergeInsert insert:
          mergeInserts.add(insert);
          continue;
        case CrdtMergeUpdate update:
          mergeUpdates.add(update);
          continue;
        case CrdtMergeDelete delete:
          mergeDeletes.add(delete);
          continue;
      }
      break;
    }

    final mergeSet = CrdtMergeSet(
      inserts: mergeInserts,
      updates: mergeUpdates,
      deletes: mergeDeletes,
    );

    if (mergeSet.isEmpty) return;

    final crdtDb = CrdtDatabase(session.db, syncTables: syncTables);
    await crdtDb.initialize();
    await crdtDb.mergeChanges(mergeSet, userId: userUuid);
  }

  Stream<CrdtMergeChange> _streamServerChanges(
    Session session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
    DatabaseSerializationManager serializationManager,
  ) async* {
    yield* _streamInserts(session, crdtUser, lastSyncHlc, serializationManager);
    yield* _streamUpdates(session, crdtUser, lastSyncHlc);
    yield* _streamDeletes(session, crdtUser, lastSyncHlc);
  }

  Stream<CrdtMergeInsert> _streamInserts(
    Session session,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
    DatabaseSerializationManager serializationManager,
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
      if (!(_syncTablesByName?.containsKey(tableName) ?? false)) continue;

      final table = _syncTablesByName![tableName]!;
      final dartName = _dartNamesByTableName?[tableName];
      if (dartName == null) continue;

      final domainRow = await _fetchDomainRow(
        session,
        tableName,
        row.uuidRowId,
        table,
        dartName,
        serializationManager,
      );
      if (domainRow == null) continue;

      yield CrdtMergeInsert(
        hlcDatetime: row.hlcDatetime,
        hlcCounter: row.hlcCounter,
        tableName: tableName,
        uuidRowId: row.uuidRowId,
        uuidNodeId: row.node!.uuidNodeId,
        data: serializationManager.encodeWithType(domainRow),
      );
    }
  }

  Stream<CrdtMergeUpdate> _streamUpdates(
    Session session,
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
      if (!(_syncTablesByName?.containsKey(tableName) ?? false)) continue;

      final columnName = field.column!.name;
      final rawValue = await _fetchColumnValue(
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
        value: rawValue,
      );
    }
  }

  Stream<CrdtMergeDelete> _streamDeletes(
    Session session,
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
      if (!(_syncTablesByName?.containsKey(tableName) ?? false)) continue;

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
      t.userId.equals(crdtUser.id!) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _fieldHlcAfterFilter(
    CrdtDataFieldTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id!) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Expression _tombstoneHlcAfterFilter(
    CrdtDataDeletedTable t,
    CrdtUser crdtUser,
    Hlc lastSyncHlc,
  ) =>
      t.row.userId.equals(crdtUser.id!) &
      ((t.hlcDatetime > lastSyncHlc.datetime) |
          (t.hlcDatetime.equals(lastSyncHlc.datetime) &
              (t.hlcCounter > lastSyncHlc.counter)));

  Future<dynamic> _fetchDomainRow(
    Session session,
    String tableName,
    UuidValue rowId,
    Table table,
    String dartName,
    DatabaseSerializationManager serializationManager,
  ) async {
    final cols = table.columns.map((c) => '"${c.columnName}"').join(', ');
    final result = await session.db.unsafeQuery(
      'SELECT $cols FROM "$tableName" WHERE "id" = \'${rowId.uuid}\'',
    );
    if (result.isEmpty) return null;

    final columnMap = result.first.toColumnMap();
    return serializationManager.deserializeByClassName({
      'className': dartName,
      'data': columnMap,
    });
  }

  Future<dynamic> _fetchColumnValue(
    Session session,
    String tableName,
    UuidValue rowId,
    String columnName,
  ) async {
    final result = await session.db.unsafeQuery(
      'SELECT "$columnName" FROM "$tableName" WHERE "id" = \'${rowId.uuid}\'',
    );
    if (result.isEmpty) return null;
    return result.first[0];
  }
}

/// A zero-value [UuidValue] used for [CrdtMergeSyncStop] placeholder fields.
final _zeroUuid = UuidValue.withValidation(
  '00000000-0000-0000-0000-000000000000',
);

/// A singleton stop sentinel used to signal the end of a sync stream.
final _syncStop = CrdtMergeSyncStop(
  hlcDatetime: DateTime.utc(0),
  hlcCounter: 0,
  tableName: '',
  uuidRowId: _zeroUuid,
  uuidNodeId: _zeroUuid,
);
