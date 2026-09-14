// Production-shaped tombstone space benchmark: many users and a large
// crdt_data_rows table, measuring scoped vs unscoped SELECT cost.

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'benchmark.dart';
import 'tables.dart';

/// Which session executes the measured selects.
enum SpaceMode {
  /// Plain SQLite session without CRDT metadata.
  baseline,

  /// CRDT session with a persistent user (single-user client pattern).
  spaceScoped,

  /// CRDT session without a user space (server admin reads).
  unscoped,
}

/// Timed results for one [SpaceMode], in average microseconds.
typedef SpaceMeasurement = ({double findAllMicros, double findByIdMicros});

/// Measures SELECT cost against a database whose `crdt_data_rows` table holds
/// production-shaped metadata instead of a single user's rows.
///
/// On top of the [rowCount] benchmark rows, the CRDT modes seed [noiseUsers]
/// extra spaces tracking [noiseCrdtRows] unrelated rows spread across every
/// synced table. Random UUIDs keep the noise ownership-conformant while still
/// exercising large CRDT metadata tables.
class TombstoneSpaceBenchmark {
  TombstoneSpaceBenchmark(
    this.name, {
    required this.mode,
    required this.rowCount,
    required this.noiseUsers,
    required this.noiseCrdtRows,
  });

  final String name;
  final SpaceMode mode;
  final int rowCount;
  final int noiseUsers;
  final int noiseCrdtRows;

  static const _clientUrl = 'http://localhost:8081/';
  static const _warmupMillis = 100;
  static const _measurementMillis = 2000;
  static const _findByIdLookupsPerCycle = 100;

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  OfflineSyncDatabaseSession? _offlineSyncSession;
  var _hasOpenSession = false;

  final UuidValue _userId = const Uuid().v7obj();

  List<Types> _seededRows = [];
  List<UuidValue> _sampleIds = [];

  DatabaseSession get _activeSession =>
      mode == SpaceMode.baseline ? _plainSession : _offlineSyncSession!;

  Future<void> _setup() async {
    final dbPath = p.join(
      Directory.systemTemp.path,
      'offline_sync_benchmark_$name.db',
    );
    _dbFile = File(dbPath);
    deleteDatabaseFiles(_dbFile);

    _plainSession = await Client(_clientUrl).createSession(
      _dbFile.path,
      isDebugMode: true,
    );
    _hasOpenSession = true;

    if (mode != SpaceMode.baseline) {
      _offlineSyncSession = OfflineSyncDatabaseSession.wraps(
        _plainSession,
        syncTables: benchmarkSyncTables,
        persistentUserId: mode == SpaceMode.spaceScoped ? _userId : null,
      );
      await _offlineSyncSession!.db.initialize();
    }

    await _seedBenchmarkRows();
    if (mode != SpaceMode.baseline) {
      await _seedCrdtNoise();
    }

    final sampleStep = (rowCount / _findByIdLookupsPerCycle).ceil();
    _sampleIds = [
      for (var i = 0; i < rowCount; i += sampleStep) _seededRows[i].id!,
    ];
  }

  Future<void> _seedBenchmarkRows() async {
    final baseTimestamp = DateTime.now();
    final rows = List.generate(
      rowCount,
      (i) => Types(
        aBool: i.isEven,
        aDateTime: baseTimestamp.add(Duration(seconds: i)),
        aText: 'Text $i',
        anInt: i,
        anInt64: BigInt.from(i),
        aReal: i.toDouble(),
        aBlob: ByteData(0),
        anEnum: null,
        optionalText: null,
        optionalUuid: const Uuid().v7obj(),
      ),
    );

    if (mode == SpaceMode.baseline) {
      _seededRows = await Types.db.insert(_plainSession, rows);
      return;
    }
    _seededRows = await _offlineSyncSession!.db.transactionForUser(_userId, (tx) {
      return Types.db.insert(_offlineSyncSession!, rows, transaction: tx);
    });
  }

  /// Injects CRDT metadata noise with raw SQL, bypassing the recorder: the
  /// noise only needs to be visible to the tombstone predicates, which read
  /// `crdt_data_rows` alone.
  Future<void> _seedCrdtNoise() async {
    final db = _plainSession.db;
    final hiddenVisibility = CrdtDataRowVisibility.userDelete.index;

    final benchSpace = await OfflineSyncSpace.db.findFirstRow(
      _plainSession,
      orderBy: (t) => t.id,
    );
    final benchUserId = benchSpace!.id!;
    await db.unsafeExecute('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < $noiseUsers - 1)
INSERT INTO "offline_sync_spaces" ("currentNodeId") SELECT NULL FROM n
''');
    await db.unsafeExecute('''
WITH local_node(id) AS (
  SELECT "currentNodeId" FROM "offline_sync_spaces" WHERE "id" = $benchUserId
)
INSERT INTO "offline_sync_space_nodes" ("spaceId", "nodeId")
SELECT u."id", local_node.id
FROM "offline_sync_spaces" u
CROSS JOIN local_node
WHERE local_node.id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM "offline_sync_space_nodes" sn
    WHERE sn."spaceId" = u."id" AND sn."nodeId" = local_node.id
  )
''');

    // Noise rows for every noise user, spread across all synced tables, with
    // 10% tombstoned. Random UUIDs keep them unrelated to the domain rows.
    await db.unsafeExecute('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < $noiseCrdtRows - 1),
users(rowidx, uid, nodeId) AS (
  SELECT ROW_NUMBER() OVER (ORDER BY s."id") - 1, s."id", sn."nodeId"
  FROM "offline_sync_spaces" s
  JOIN "offline_sync_space_nodes" sn ON sn."spaceId" = s."id"
  WHERE s."id" <> $benchUserId
),
tbls(tblidx, tid) AS (
  SELECT ROW_NUMBER() OVER (ORDER BY "id") - 1, "id" FROM "crdt_schema_tables"
)
INSERT INTO "crdt_data_rows"
  ("hlcDatetime", "hlcCounter", "spaceId", "tblId", "uuidRowId", "nodeId", "visibility")
SELECT 0, 0, u.uid, t.tid, randomblob(16), u.nodeId,
       CASE WHEN n.i % 10 = 0 THEN $hiddenVisibility ELSE 0 END
FROM n
JOIN users u ON u.rowidx = n.i % $noiseUsers
JOIN tbls t ON t.tblidx = n.i % (SELECT COUNT(*) FROM "crdt_schema_tables")
''');

    await db.unsafeExecute('ANALYZE');
  }

  Future<void> _runFindAll() async {
    final rows = await Types.db.find(_activeSession);
    if (rows.length != rowCount) {
      throw Exception(
        'Space benchmark ($name) returned ${rows.length} rows '
        'but expected $rowCount.',
      );
    }
  }

  Future<void> _runFindByIdBatch() async {
    for (final id in _sampleIds) {
      final row = await Types.db.findById(_activeSession, id);
      if (row == null) {
        throw Exception('Space benchmark ($name) could not find row $id.');
      }
    }
  }

  Future<double> _measureQuery(Future<void> Function() run) async {
    Future<void> noPrepare() async {}
    await measurePreparedCycles(_warmupMillis, prepare: noPrepare, run: run);
    return measurePreparedCycles(
      _measurementMillis,
      prepare: noPrepare,
      run: run,
    );
  }

  /// Seeds the database once and measures both query shapes.
  Future<SpaceMeasurement> measure() async {
    await _setup();
    try {
      final findAllMicros = await _measureQuery(_runFindAll);
      final findByIdBatchMicros = await _measureQuery(_runFindByIdBatch);
      return (
        findAllMicros: findAllMicros,
        findByIdMicros: findByIdBatchMicros / _sampleIds.length,
      );
    } finally {
      await _teardown();
    }
  }

  Future<void> _teardown() async {
    if (!_hasOpenSession) return;
    await _plainSession.close();
    _hasOpenSession = false;
    deleteDatabaseFiles(_dbFile);
  }
}
