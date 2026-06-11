// Production-shaped tombstone scope benchmark: many users and a large
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
enum ScopeMode {
  /// Plain SQLite session without CRDT metadata.
  baseline,

  /// CRDT session with a persistent user (single-user client pattern).
  scoped,

  /// CRDT session without a user scope (server admin reads).
  unscoped,
}

/// Timed results for one [ScopeMode], in average microseconds.
typedef ScopeMeasurement = ({double findAllMicros, double findByIdMicros});

/// Measures SELECT cost against a database whose `crdt_data_rows` table holds
/// production-shaped metadata instead of a single user's rows.
///
/// On top of the [rowCount] benchmark rows, the CRDT modes seed [noiseUsers]
/// extra users tracking [noiseCrdtRows] rows spread across every synced
/// table, give 10% of the benchmark rows a second tracking user, and
/// tombstone half of those second trackers. The visibility predicates must
/// keep all [rowCount] rows visible in every mode, so the benchmark doubles
/// as a correctness check that foreign tombstones do not mask shared rows.
class TombstoneScopeBenchmark {
  TombstoneScopeBenchmark(
    this.name, {
    required this.mode,
    required this.rowCount,
    required this.noiseUsers,
    required this.noiseCrdtRows,
  });

  final String name;
  final ScopeMode mode;
  final int rowCount;
  final int noiseUsers;
  final int noiseCrdtRows;

  static const _clientUrl = 'http://localhost:8081/';
  static const _warmupMillis = 100;
  static const _measurementMillis = 2000;
  static const _findByIdLookupsPerCycle = 100;

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  CrdtDatabaseSession? _crdtSession;
  var _hasOpenSession = false;

  final UuidValue _userId = const Uuid().v7obj();

  List<Types> _seededRows = [];
  List<UuidValue> _sampleIds = [];

  DatabaseSession get _activeSession =>
      mode == ScopeMode.baseline ? _plainSession : _crdtSession!;

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

    if (mode != ScopeMode.baseline) {
      _crdtSession = CrdtDatabaseSession.wraps(
        _plainSession,
        syncTables: benchmarkSyncTables,
        persistentUserId: mode == ScopeMode.scoped ? _userId : null,
      );
      await _crdtSession!.db.initialize();
    }

    await _seedBenchmarkRows();
    if (mode != ScopeMode.baseline) {
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

    if (mode == ScopeMode.baseline) {
      _seededRows = await Types.db.insert(_plainSession, rows);
      return;
    }
    _seededRows = await _crdtSession!.db.transactionForUser(_userId, (tx) {
      return Types.db.insert(_crdtSession!, rows, transaction: tx);
    });
  }

  /// Injects CRDT metadata noise with raw SQL, bypassing the recorder: the
  /// noise only needs to be visible to the tombstone predicates, which read
  /// `crdt_data_rows` alone.
  Future<void> _seedCrdtNoise() async {
    final db = _plainSession.db;
    final hiddenVisibility = CrdtDataRowVisibility.userDelete.index;

    final benchUserId =
        (await db.unsafeQuery('SELECT MIN("id") FROM "crdt_users"')).first[0]
            as int;
    final typesTblId =
        (await db.unsafeQuery(
              'SELECT "id" FROM "crdt_schema_tables" '
              "WHERE \"name\" = '${Types.t.tableName}'",
            )).first[0]
            as int;

    await db.unsafeExecute('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < $noiseUsers - 1)
INSERT INTO "crdt_users" ("currentNodeId") SELECT NULL FROM n
''');
    await db.unsafeExecute('''
INSERT INTO "crdt_nodes" ("userId")
SELECT u."id" FROM "crdt_users" u
WHERE NOT EXISTS (SELECT 1 FROM "crdt_nodes" n WHERE n."userId" = u."id")
''');

    // Noise rows for every noise user, spread across all synced tables, with
    // 10% tombstoned. Random UUIDs keep them unrelated to the domain rows.
    await db.unsafeExecute('''
WITH RECURSIVE n(i) AS (SELECT 0 UNION ALL SELECT i + 1 FROM n WHERE i < $noiseCrdtRows - 1),
users(rowidx, uid) AS (
  SELECT ROW_NUMBER() OVER (ORDER BY "id") - 1, "id"
  FROM "crdt_users" WHERE "id" <> $benchUserId
),
tbls(tblidx, tid) AS (
  SELECT ROW_NUMBER() OVER (ORDER BY "id") - 1, "id" FROM "crdt_schema_tables"
)
INSERT INTO "crdt_data_rows"
  ("hlcDatetime", "hlcCounter", "userId", "tblId", "uuidRowId", "nodeId", "visibility")
SELECT 0, 0, u.uid, t.tid, randomblob(16),
       (SELECT nd."id" FROM "crdt_nodes" nd WHERE nd."userId" = u.uid LIMIT 1),
       CASE WHEN n.i % 10 = 0 THEN $hiddenVisibility ELSE 0 END
FROM n
JOIN users u ON u.rowidx = n.i % $noiseUsers
JOIN tbls t ON t.tblidx = n.i % (SELECT COUNT(*) FROM "crdt_schema_tables")
''');

    // Second trackers over 10% of the benchmark rows, half of them
    // tombstoned. The owner's rows stay visible, so foreign tombstones must
    // not mask them in any mode.
    await db.unsafeExecute('''
INSERT INTO "crdt_data_rows"
  ("hlcDatetime", "hlcCounter", "userId", "tblId", "uuidRowId", "nodeId", "visibility")
SELECT 0, 0, u.uid, c."tblId", c."uuidRowId",
       (SELECT nd."id" FROM "crdt_nodes" nd WHERE nd."userId" = u.uid LIMIT 1),
       CASE WHEN c."id" % 2 = 0 THEN $hiddenVisibility ELSE 0 END
FROM "crdt_data_rows" c
JOIN (
  SELECT ROW_NUMBER() OVER (ORDER BY "id") - 1 AS rowidx, "id" AS uid
  FROM "crdt_users" WHERE "id" <> $benchUserId
) u ON u.rowidx = c."id" % $noiseUsers
WHERE c."userId" = $benchUserId AND c."tblId" = $typesTblId AND c."id" % 10 = 0
''');

    await db.unsafeExecute('ANALYZE');
  }

  Future<void> _runFindAll() async {
    final rows = await Types.db.find(_activeSession);
    if (rows.length != rowCount) {
      throw Exception(
        'Scope benchmark ($name) returned ${rows.length} rows '
        'but expected $rowCount.',
      );
    }
  }

  Future<void> _runFindByIdBatch() async {
    for (final id in _sampleIds) {
      final row = await Types.db.findById(_activeSession, id);
      if (row == null) {
        throw Exception('Scope benchmark ($name) could not find row $id.');
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
  Future<ScopeMeasurement> measure() async {
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
