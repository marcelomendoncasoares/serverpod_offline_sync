// Merge benchmark harness — measures the sync merge apply path.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:path/path.dart' as p;
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'benchmark.dart';
import 'conversion.dart';
import 'query_counter.dart';
import 'tables.dart';

enum MergeOperation { insert, update, delete, mixed }

enum FkChainOperation { insert, delete }

enum SetDefaultOperation { originalDeleteOrRestore, defaultDeleteOrRestore }

/// Measurement of a merge scenario, averaged over the timed merge batches.
typedef MergeMeasurement = ({
  double averageMicroseconds,
  double averageQueries,
  double averageRowsRead,
  Map<String, double> averageRowsReadByType,
});

/// The number of changes of each kind in a mixed batch of [changeCount].
({int inserts, int updates, int deletes}) mixedMergeComposition(
  int changeCount,
) {
  final updates = changeCount ~/ 3;
  final deletes = changeCount ~/ 3;
  return (
    inserts: changeCount - updates - deletes,
    updates: updates,
    deletes: deletes,
  );
}

/// Base harness for benchmarks of the merge path ([CrdtDatabase.mergeChanges]).
///
/// Changes are attributed to a single simulated remote node whose HLCs always
/// advance, so every merged change is newer than the local state and is
/// effectively applied (no stale-change short circuits). All database work is
/// routed through a [QueryCountingDatabase] so scenarios also report how many
/// queries each merged batch issues.
abstract class MergeScenarioBenchmark extends AsyncBenchmarkBase {
  MergeScenarioBenchmark(super.name);

  static const _warmupMillis = 100;
  static const _measurementMillis = 2000;

  static const _clientUrl = 'http://localhost:8081/';

  late final File _dbFile;
  late final ClientDatabaseSession _plainSession;
  late final QueryCountingDatabase _countingDb;
  late CrdtDatabaseSession _crdtSession;
  var _hasOpenSession = false;

  final UuidValue _userId = const Uuid().v7obj();

  /// Clock of the simulated remote node the merged changes come from.
  Hlc _remoteHlc = Hlc.now(const Uuid().v7obj());

  int _valueSeq = 0;

  CrdtMergeSet _mergeSet = [];

  int _timedQueries = 0;
  int _timedRowsRead = 0;
  final _timedRowsReadByType = <String, int>{};
  int _timedRuns = 0;

  /// Scenario title used in the results header, e.g. `INSERT`.
  String get resultTitle;

  /// Number of merge changes in each timed batch.
  int get changesPerBatch;

  /// Optional batch composition note printed with the results.
  String? get batchDescription => null;

  /// Builds the next [_mergeSet] (untimed), seeding prerequisite rows if needed.
  Future<void> prepareCycle();

  /// Seeds state once after the session is created, before the first cycle.
  Future<void> onSetup() async {}

  /// Checks that each measured change took effect, outside the timed merge.
  Future<void> validateCycle() async {}

  Hlc _nextRemoteHlc() => _remoteHlc = _remoteHlc.increment();

  int _nextSeq() => _valueSeq++;

  CrdtMergeInsert insertChangeFor(TableRow<UuidValue?> row) {
    final hlc = _nextRemoteHlc();
    return CrdtMergeInsert(
      uuidScopeId: _userId,
      tableName: row.table.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      data: row,
    );
  }

  CrdtMergeUpdate updateChangeFor(
    TableRow<UuidValue?> row,
    String columnName,
    Object? value,
  ) {
    final hlc = _nextRemoteHlc();
    return CrdtMergeUpdate(
      uuidScopeId: _userId,
      tableName: row.table.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      columnName: columnName,
      value: value,
    );
  }

  CrdtMergeDelete deleteChangeFor(TableRow<UuidValue?> row) {
    final hlc = _nextRemoteHlc();
    return CrdtMergeDelete(
      uuidScopeId: _userId,
      tableName: row.table.tableName,
      uuidRowId: row.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      clFlag: 2,
      reason: CrdtDataDeletedReason.userDelete,
    );
  }

  /// Seeds [rows] through the merge path so they exist locally with remote
  /// CRDT metadata, like rows previously received from the remote node.
  Future<void> mergeSeedRows(List<TableRow<UuidValue?>> rows) {
    return _crdtSession.db.mergeChanges(
      [for (final row in rows) insertChangeFor(row)],
      scopeId: _userId,
    );
  }

  @override
  Future<void> setup() async {
    _valueSeq = 0;
    _mergeSet = [];
    _timedQueries = 0;
    _timedRowsRead = 0;
    _timedRowsReadByType.clear();
    _timedRuns = 0;
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

    await clearUserTables(_plainSession);
    _countingDb = QueryCountingDatabase(_plainSession.db);
    _crdtSession = CrdtDatabaseSession(
      _countingDb,
      syncTables: benchmarkSyncTables,
    );
    await _crdtSession.db.initialize();

    await onSetup();
  }

  Future<MergeMeasurement> measureMerge() async {
    await setup();
    try {
      await measurePreparedCycles(
        _warmupMillis,
        prepare: prepareCycle,
        run: run,
        validate: validateCycle,
      );
      _timedQueries = 0;
      _timedRowsRead = 0;
      _timedRowsReadByType.clear();
      _timedRuns = 0;
      final averageMicroseconds = await measurePreparedCycles(
        _measurementMillis,
        prepare: prepareCycle,
        run: run,
        validate: validateCycle,
      );
      return (
        averageMicroseconds: averageMicroseconds,
        averageQueries: _timedQueries / _timedRuns,
        averageRowsRead: _timedRowsRead / _timedRuns,
        averageRowsReadByType: {
          for (final entry in _timedRowsReadByType.entries)
            entry.key: entry.value / _timedRuns,
        },
      );
    } finally {
      await teardown();
    }
  }

  @override
  Future<void> run() async {
    final queriesBefore = _countingDb.queryCount;
    final rowsBefore = _countingDb.rowsRead;
    final rowsByTypeBefore = Map.of(_countingDb.rowsReadByType);
    await _crdtSession.db.mergeChanges(_mergeSet, scopeId: _userId);
    _timedQueries += _countingDb.queryCount - queriesBefore;
    _timedRowsRead += _countingDb.rowsRead - rowsBefore;
    for (final entry in _countingDb.rowsReadByType.entries) {
      final count = entry.value - (rowsByTypeBefore[entry.key] ?? 0);
      if (count == 0) continue;
      _timedRowsReadByType.update(
        entry.key,
        (total) => total + count,
        ifAbsent: () => count,
      );
    }
    _timedRuns++;
  }

  @override
  Future<void> teardown() async {
    if (!_hasOpenSession) {
      return;
    }
    await _plainSession.close();
    _hasOpenSession = false;
    deleteDatabaseFiles(_dbFile);
  }
}

/// Benchmarks plain merge operations using the wide [Types] row, like
/// [TypesTableBenchmark] does for local mutations.
class TypesMergeBenchmark extends MergeScenarioBenchmark {
  TypesMergeBenchmark(
    super.name, {
    required this.operation,
    required this.changeCount,
  });

  /// Minimal blob column payload (shared; column stays non-null with zero bytes).
  static final ByteData _emptyBlob = ByteData(0);

  final MergeOperation operation;
  final int changeCount;

  List<Types> _seededRows = [];

  @override
  String get resultTitle => operation.name.toUpperCase();

  @override
  int get changesPerBatch => changeCount;

  @override
  String? get batchDescription {
    if (operation != MergeOperation.mixed) return null;
    final composition = mixedMergeComposition(changeCount);
    return '${formatter0.format(composition.inserts)} inserts + '
        '${formatter0.format(composition.updates)} updates + '
        '${formatter0.format(composition.deletes)} deletes';
  }

  Types _createTypesRow(int i, DateTime baseTimestamp) {
    return Types(
      id: const Uuid().v7obj(),
      aBool: i.isEven,
      aDateTime: baseTimestamp.add(Duration(seconds: i)),
      aText: 'Text $i',
      anInt: i,
      anInt64: BigInt.from(i),
      aReal: i.toDouble(),
      aBlob: _emptyBlob,
      anEnum: null,
      optionalText: null,
      optionalUuid: const Uuid().v7obj(),
    );
  }

  List<Types> _createTypesRows(int count) {
    final baseTimestamp = DateTime.now();
    final start = _valueSeq;
    _valueSeq += count;
    return List.generate(
      count,
      (j) => _createTypesRow(start + j, baseTimestamp),
    );
  }

  CrdtMergeUpdate _typesUpdateChangeFor(Types row) {
    final i = _nextSeq();
    final (columnName, value) = switch (i % 3) {
      0 => (Types.t.aText.columnName, 'Updated $i' as Object?),
      1 => (Types.t.anInt.columnName, i as Object?),
      _ => (Types.t.aReal.columnName, i.toDouble() as Object?),
    };
    return updateChangeFor(row, columnName, value);
  }

  Future<List<Types>> _mergeInsertRows(int count) async {
    final rows = _createTypesRows(count);
    await mergeSeedRows(rows);
    return rows;
  }

  @override
  Future<void> onSetup() async {
    if (operation == MergeOperation.update) {
      _seededRows = await _mergeInsertRows(changeCount);
    }
  }

  @override
  Future<void> prepareCycle() async {
    switch (operation) {
      case MergeOperation.insert:
        _mergeSet = [
          for (final row in _createTypesRows(changeCount)) insertChangeFor(row),
        ];
      case MergeOperation.update:
        _mergeSet = [
          for (final row in _seededRows) _typesUpdateChangeFor(row),
        ];
      case MergeOperation.delete:
        final rows = await _mergeInsertRows(changeCount);
        _mergeSet = [for (final row in rows) deleteChangeFor(row)];
      case MergeOperation.mixed:
        final composition = mixedMergeComposition(changeCount);
        final existingRows = await _mergeInsertRows(
          composition.updates + composition.deletes,
        );
        _mergeSet = [
          for (final row in _createTypesRows(composition.inserts)) insertChangeFor(row),
          for (final row in existingRows.take(composition.updates))
            _typesUpdateChangeFor(row),
          for (final row in existingRows.skip(composition.updates))
            deleteChangeFor(row),
        ];
    }
  }
}

/// Benchmarks merging inserts that all collide with existing rows on unique
/// columns, forcing the unique conflict resolver to release every loser.
///
/// Half of the batch collides on a text unique column ([Unique.name], released
/// with a suffix) and half on a UUID unique column ([UniqueUuid.value],
/// released with a synthetic UUID).
class UniqueMergeBenchmark extends MergeScenarioBenchmark {
  UniqueMergeBenchmark(super.name, {required this.changeCount});

  final int changeCount;

  int get _uuidCount => changeCount ~/ 2;
  int get _textCount => changeCount - _uuidCount;

  @override
  String get resultTitle => 'UNIQUE CONFLICT';

  @override
  int get changesPerBatch => changeCount;

  @override
  String get batchDescription =>
      '${formatter0.format(_textCount)} text + '
      '${formatter0.format(_uuidCount)} uuid conflicting inserts';

  @override
  Future<void> prepareCycle() async {
    final textRows = [
      for (var j = 0; j < _textCount; j++)
        Unique(id: const Uuid().v7obj(), name: 'name ${_nextSeq()}'),
    ];
    final uuidRows = [
      for (var j = 0; j < _uuidCount; j++)
        UniqueUuid(id: const Uuid().v7obj(), value: const Uuid().v7obj()),
    ];
    await mergeSeedRows([...textRows, ...uuidRows]);

    // New row ids reusing the seeded unique values: every insert conflicts.
    _mergeSet = [
      for (final row in textRows)
        insertChangeFor(Unique(id: const Uuid().v7obj(), name: row.name)),
      for (final row in uuidRows)
        insertChangeFor(
          UniqueUuid(id: const Uuid().v7obj(), value: row.value),
        ),
    ];
  }
}

/// Benchmarks merges over the FK chain model graph, where foreign key
/// invariants force existence checks per change and a foreign key projection
/// pass over the affected tables after the batch.
///
/// Each family is 9 related rows spanning cascade, set-null and restrict
/// `onDelete` actions across three levels:
///
/// root ← cascadeMiddle ← restrictBlocker ← {cascade, set-null} children
///                      ← setNullMiddle ← {cascade, restrict, set-null} children
class FkChainMergeBenchmark extends MergeScenarioBenchmark {
  FkChainMergeBenchmark(
    super.name, {
    required this.operation,
    required int changeCount,
  }) : familyCount = max(1, changeCount ~/ rowsPerFamily);

  /// Rows created by [_createFamily].
  static const rowsPerFamily = 9;

  /// Timed delete changes per family (root and restrict blocker).
  static const _deletesPerFamily = 2;

  final FkChainOperation operation;
  final int familyCount;

  @override
  String get resultTitle => 'FK CHAIN ${operation.name.toUpperCase()}';

  @override
  int get changesPerBatch => switch (operation) {
    FkChainOperation.insert => familyCount * rowsPerFamily,
    FkChainOperation.delete => familyCount * _deletesPerFamily,
  };

  String get _familiesLabel =>
      '${formatter0.format(familyCount)} '
      '${familyCount == 1 ? 'family' : 'families'}';

  @override
  String get batchDescription => switch (operation) {
    FkChainOperation.insert => '$_familiesLabel × $rowsPerFamily related rows',
    FkChainOperation.delete =>
      'root + restrict blocker deletes across '
          '$_familiesLabel of $rowsPerFamily rows',
  };

  /// Creates one family of related rows in dependency order, so parents are
  /// merged before the children referencing them.
  _FkChainFamily _createFamily(int i) {
    final root = FkChainRoot(id: const Uuid().v7obj(), name: 'root $i');
    final cascadeMiddle = FkChainCascadeMiddle(
      id: const Uuid().v7obj(),
      name: 'cascade middle $i',
      rootId: root.id,
    );
    final restrictBlocker = FkChainRestrictBlocker(
      id: const Uuid().v7obj(),
      name: 'restrict blocker $i',
      cascadeMiddleId: cascadeMiddle.id,
    );
    final setNullMiddle = FkChainSetNullMiddle(
      id: const Uuid().v7obj(),
      name: 'set-null middle $i',
      cascadeMiddleId: cascadeMiddle.id,
    );
    final rows = <TableRow<UuidValue?>>[
      root,
      cascadeMiddle,
      restrictBlocker,
      setNullMiddle,
      FkChainMiddleCascadeChild(
        id: const Uuid().v7obj(),
        name: 'middle cascade child $i',
        restrictBlockerId: restrictBlocker.id,
      ),
      FkChainMiddleSetNullChild(
        id: const Uuid().v7obj(),
        name: 'middle set-null child $i',
        restrictBlockerId: restrictBlocker.id,
      ),
      FkChainSetNullCascadeChild(
        id: const Uuid().v7obj(),
        name: 'set-null cascade child $i',
        setNullMiddleId: setNullMiddle.id,
      ),
      FkChainSetNullRestrictChild(
        id: const Uuid().v7obj(),
        name: 'set-null restrict child $i',
        setNullMiddleId: setNullMiddle.id,
      ),
      FkChainSetNullSetNullChild(
        id: const Uuid().v7obj(),
        name: 'set-null set-null child $i',
        setNullMiddleId: setNullMiddle.id,
      ),
    ];
    return (root: root, restrictBlocker: restrictBlocker, rows: rows);
  }

  List<_FkChainFamily> _createFamilies() {
    return List.generate(familyCount, (_) => _createFamily(_nextSeq()));
  }

  @override
  Future<void> prepareCycle() async {
    switch (operation) {
      case FkChainOperation.insert:
        _mergeSet = [
          for (final family in _createFamilies())
            for (final row in family.rows) insertChangeFor(row),
        ];
      case FkChainOperation.delete:
        final families = _createFamilies();
        await mergeSeedRows([
          for (final family in families) ...family.rows,
        ]);

        // Deleting the restrict blocker first unblocks the cascade from the
        // root through the middle tables, projecting the whole family.
        _mergeSet = [
          for (final family in families) ...[
            deleteChangeFor(family.restrictBlocker),
            deleteChangeFor(family.root),
          ],
        ];
    }
  }
}

typedef _FkChainFamily = ({
  FkChainRoot root,
  FkChainRestrictBlocker restrictBlocker,
  List<TableRow<UuidValue?>> rows,
});

/// Measures SET DEFAULT projection with many independent town/company pairs.
/// Compares deleting/restoring an original parent with changing the shared
/// default target, which also requires looking up implicit dependencies.
class SetDefaultMergeBenchmark extends MergeScenarioBenchmark {
  SetDefaultMergeBenchmark(
    super.name, {
    required this.operation,
    required this.pairCount,
  }) {
    if (pairCount < 1) {
      throw ArgumentError.value(pairCount, 'pairCount', 'Must be >= 1');
    }
  }

  static const _defaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

  final SetDefaultOperation operation;
  final int pairCount;
  late List<Town> _towns;
  late List<Company> _companies;
  late Town _defaultTown;
  var _cycle = 0;
  var _visibilityFlag = 1;

  @override
  String get resultTitle =>
      'SET DEFAULT ${switch (operation) {
        SetDefaultOperation.originalDeleteOrRestore => 'ORIGINAL DELETE / RESTORE',
        SetDefaultOperation.defaultDeleteOrRestore => 'DEFAULT DELETE / RESTORE',
      }}';

  @override
  int get changesPerBatch => 1;

  @override
  String get batchDescription =>
      '${formatter0.format(pairCount)} town/company pairs sharing one default';

  @override
  Future<void> onSetup() async {
    _cycle = 0;
    _visibilityFlag = 1;
    _defaultTown = Town(id: _defaultTownId, name: 'default');
    _towns = [
      for (var i = 0; i < pairCount; i++)
        Town(id: const Uuid().v7obj(), name: 'town $i'),
    ];
    _companies = [
      for (var i = 0; i < pairCount; i++)
        Company(id: const Uuid().v7obj(), name: 'company $i', townId: _towns[i].id),
    ];
    await mergeSeedRows([
      _defaultTown,
      ..._towns,
      ..._companies,
    ]);
  }

  bool get _alternate => _cycle.isOdd;

  Town get _changedTown => switch (operation) {
    SetDefaultOperation.originalDeleteOrRestore => _towns.first,
    SetDefaultOperation.defaultDeleteOrRestore => _defaultTown,
  };

  UuidValue get _expectedTownId =>
      operation == SetDefaultOperation.originalDeleteOrRestore && _alternate
      ? _defaultTownId
      : _towns.first.id!;

  @override
  Future<void> prepareCycle() async {
    _cycle++;
    _mergeSet = [_visibilityChange(_changedTown)];
  }

  CrdtMergeDelete _visibilityChange(Town town) {
    final hlc = _nextRemoteHlc();
    // HLC advancement alone cannot supersede a higher visibility flag. Advance
    // both on every delete/restore so no measured cycle becomes a stale no-op.
    return CrdtMergeDelete(
      uuidScopeId: _userId,
      tableName: Town.t.tableName,
      uuidRowId: town.id!,
      uuidNodeId: hlc.nodeId,
      hlcDatetime: hlc.datetime,
      hlcCounter: hlc.counter,
      clFlag: ++_visibilityFlag,
      reason: _alternate
          ? CrdtDataDeletedReason.userDelete
          : CrdtDataDeletedReason.userReinsert,
    );
  }

  @override
  Future<void> validateCycle() async {
    final company = await Company.db.findById(_crdtSession, _companies.first.id!);
    if (company == null || company.townId != _expectedTownId) {
      throw StateError('$name cycle $_cycle did not project the company as expected.');
    }
    final visibleTown = await Town.db.findById(_crdtSession, _changedTown.id!);
    if ((visibleTown == null) != _alternate) {
      throw StateError('$name cycle $_cycle did not apply its visibility change.');
    }
  }
}
