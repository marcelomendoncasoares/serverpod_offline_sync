import 'package:clock/clock.dart';
// Imported with `show` because the barrel below re-exports overlapping names.
import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, TableRow, Transaction;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import '../../integration/test_tools/client_session.dart';
import 'dst_authored.dart';
import 'dst_coverage.dart';
import 'dst_random.dart';
import 'dst_rejection.dart';
import 'dst_schema.dart';
import 'dst_snapshot.dart';

export 'dst_schema.dart';

/// The tables every replica registers for synchronization.
///
/// Shared with the integration suites: the registry validates the whole set
/// at `initialize()`, so the two must agree.
final dstSyncTables = testSyncTables;

/// The well-known `company.townId` default from `company.spy.yaml`.
///
/// Set-default repair rewrites a company onto this town. Row ids are globally
/// unique, so the simulation inserts this town in a single space; other spaces
/// exercise the path where the default target is missing.
const dstDefaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

/// One replica in the simulation: an isolated database with its own node
/// identity, clock skew, and set of spaces the adversary delivers to it.
class DstReplica {
  DstReplica._({
    required this.name,
    required this.rawSession,
    required this.session,
    required this.sync,
    required this.spaceUuids,
    required this.nodeUuid,
    required this.clock,
  });

  /// Builds a replica on its own SQLite file.
  ///
  /// [spaceUuids] is the set of spaces this replica participates in. At this
  /// tier "participates in" is a harness concept - it decides which spaces the
  /// adversary collects from and delivers to - which is exactly the subscription
  /// set the observer-independence property varies.
  ///
  /// [nodeUuid] is seeded rather than left to the engine. `OfflineSyncSpaceManager`
  /// mints `CrdtNode()` without an explicit id, which falls back to a
  /// wall-clock v7 UUID, and `Hlc.compareTo` breaks ties on the node UUID - so
  /// leaving it to the engine would make concurrent merge winners
  /// nondeterministic and seeds would not replay.
  static Future<DstReplica> create({
    required String name,
    required List<UuidValue> spaceUuids,
    required UuidValue nodeUuid,
    required Clock clock,
  }) async {
    final rawSession = await createAdditionalTestSession();
    final session = OfflineSyncDatabaseSession.wraps(
      rawSession,
      syncTables: dstSyncTables,
    );
    await session.db.initialize();

    // Seed the replica identity before the engine can mint one. The manager
    // adopts the current node of the first space that already has one
    // (`OfflineSyncSpaceManager._getOrCreateCurrentNode`), so pre-creating the node
    // and attaching it to every space keeps one stable identity per replica -
    // which is the engine's own model of a node.
    final node = await CrdtNode.db.insertRow(
      rawSession,
      CrdtNode(uuidNodeId: nodeUuid),
    );
    for (final spaceUuid in spaceUuids) {
      await OfflineSyncSpace.db.insertRow(
        rawSession,
        OfflineSyncSpace(uuidSpaceId: spaceUuid, currentNodeId: node.id),
      );
    }

    final replica = DstReplica._(
      name: name,
      rawSession: rawSession,
      session: session,
      sync: OfflineSyncEngine(
        syncTables: dstSyncTables,
        serializationManager: rawSession.db.serializationManager,
      ),
      spaceUuids: spaceUuids,
      nodeUuid: nodeUuid,
      clock: clock,
    );

    // Materialize space state through the engine so collection has a space to
    // key by before the replica has authored anything into it.
    await withClock(clock, () async {
      for (final spaceUuid in spaceUuids) {
        await session.db.transactionForUser(spaceUuid, (_) async {});
      }
    });
    await replica._assertSeededNodeIdentity();

    return replica;
  }

  /// Inserts [dstDefaultTownId] into [spaceUuid] so set-default repair has a
  /// legal target in that space.
  ///
  /// Call this once, for one replica and one space. A second insert of the
  /// same id is an ownership collision, not a second default town.
  Future<void> seedDefaultTown(UuidValue spaceUuid) {
    return withReplicaClock(
      () => session.db.transactionForUser(
        spaceUuid,
        (tx) => Town.db.insertRow(
          session,
          Town(id: dstDefaultTownId, name: 'default-town'),
          transaction: tx,
        ),
      ),
    );
  }

  /// A short label used in failure messages.
  final String name;

  /// The unwrapped session, which collection reads from.
  final DatabaseSession rawSession;

  /// The CRDT-wrapped session the simulation writes and reads through.
  final OfflineSyncDatabaseSession session;

  /// This replica's sync engine, used to collect outbound changes.
  final OfflineSyncEngine sync;

  /// The spaces the adversary exchanges for this replica.
  final List<UuidValue> spaceUuids;

  /// This replica's seeded node identity. Breaks HLC ties, so it is pinned.
  final UuidValue nodeUuid;

  /// This replica's view of time, skewed from the shared simulation clock.
  final Clock clock;

  /// Runs [body] with this replica's clock installed.
  Future<T> withReplicaClock<T>(Future<T> Function() body) => withClock(clock, body);

  /// Fails loudly if the engine did not adopt the seeded node identity.
  ///
  /// Seeding relies on how `OfflineSyncSpaceManager` resolves a current node, which is
  /// an internal detail. If that strategy changes, the simulation would
  /// silently lose determinism and seeds would stop replaying; this turns that
  /// into an immediate, explanatory failure instead.
  Future<void> _assertSeededNodeIdentity() async {
    final nodes = await CrdtNode.db.find(rawSession);
    final adopted = nodes.map((node) => node.uuidNodeId).toSet();
    if (adopted.length == 1 && adopted.single == nodeUuid) return;
    throw StateError(
      'Replica $name did not adopt its seeded node identity $nodeUuid '
      '(found $adopted). OfflineSyncSpaceManager likely changed how it resolves the '
      'current node, so the simulation can no longer pin node identity and '
      'seeds will not replay. Give the engine an injectable node id instead.',
    );
  }

  /// Collects every change this replica holds for [spaceUuid].
  ///
  /// The harness deliberately collects the full history rather than tracking
  /// per-peer checkpoints. Redelivery is a merge the engine must absorb
  /// idempotently, so letting the adversary resend is a property under test
  /// rather than a defect in the harness.
  Future<CrdtMergeSet> collect(UuidValue spaceUuid) async {
    return withReplicaClock(
      () => sync
          .collectPendingChanges(
            rawSession,
            checkpointsBySpaceUuid: {spaceUuid: const []},
          )
          .toList(),
    );
  }

  /// Merges [changes] for [spaceUuid] into this replica.
  Future<void> merge(CrdtMergeSet changes, UuidValue spaceUuid) async {
    if (changes.isEmpty) return;
    await withReplicaClock(
      () => session.db.mergeChanges(changes, spaceId: spaceUuid),
    );
  }

  @override
  String toString() => name;
}

/// The identity of a merge change, used to deduplicate delivery.
///
/// The HLC string carries datetime, counter, and node, so it identifies the
/// authoring event; the remaining parts distinguish the several changes one
/// event can produce for the same row.
String dstChangeKey(CrdtMergeChange change) {
  final base =
      '${change.uuidSpaceId}|${change.tableName}|${change.uuidRowId}'
      '|${change.hlc}';
  return switch (change) {
    CrdtMergeUpdate(:final columnName) => 'U|$base|$columnName',
    CrdtMergeDelete(:final clFlag) => 'D|$base|$clFlag',
    CrdtMergeInsert() => 'I|$base',
  };
}

/// The outcome of applying one generated operation.
enum DstOperationOutcome {
  /// The operation committed.
  applied,

  /// The engine refused the operation by design - a no-action violation, a
  /// required set-null delete, or a restored reference unavailable in space.
  rejected,

  /// There was nothing to act on (for example a delete with no rows yet).
  skipped,
}

/// Generates and applies random operations against a replica.
class DstOperations {
  /// Creates an operation generator bound to [random] and [ids].
  DstOperations(this.random, this.ids);

  /// The simulation's randomness.
  final DstRandom random;

  /// The simulation's seeded identifier source.
  final DstIds ids;

  /// Rejections the engine is expected to produce, recorded per run so a test
  /// can assert the simulation actually exercised the constrained paths.
  final List<String> rejections = [];

  final DstAuthoredOracle oracle = DstAuthoredOracle();
  final DstCoverage coverage = DstCoverage();
  final DstCausalLength _causalLength = DstCausalLength();
  final Map<DstReplica, DstSnapshot> _observed = {};

  /// Shared observation boundary for every local commit and delivered merge.
  List<DstViolation> observe(
    DstReplica replica,
    DstSnapshot snapshot, {
    DstSnapshot? before,
  }) {
    coverage.observe(snapshot, before: before ?? _observed[replica]);
    _observed[replica] = snapshot;
    return [
      ...DstOracle.invariants(snapshot),
      ..._causalLength.observe(replica.name, snapshot),
    ];
  }

  final Map<String, int> skippedPaths = {};
  final Map<String, int> unexpectedPaths = {};
  int validationFailures = 0;
  int get unexpected => unexpectedPaths.values.fold(0, (sum, value) => sum + value);
  int get attempted => attemptedPaths.values.fold(0, (sum, value) => sum + value);
  int get committed => appliedPaths.values.fold(0, (sum, value) => sum + value);
  int get skipped => skippedPaths.values.fold(0, (sum, value) => sum + value);

  /// Committed paths, retaining table and action so a sweep exposes omissions.
  final Map<String, int> appliedPaths = {};
  final Map<String, int> attemptedPaths = {};

  /// Applies one randomly chosen operation on [replica] in [spaceUuid].
  Future<DstOperationOutcome> step(
    DstReplica replica,
    UuidValue spaceUuid,
  ) async {
    final table = random.pick(DstTable.values);
    final action = random.weighted({
      DstAction.insert: 5,
      DstAction.update: 3,
      DstAction.delete: 2,
      DstAction.restore: 2,
      DstAction.fullRowUpdate: 2,
      DstAction.upsert: 2,
      DstAction.insertBatch: 2,
      DstAction.updateBatch: 2,
      DstAction.deleteBatch: 1,
      DstAction.swapUnique: 2,
      DstAction.updateWhere: 1,
      DstAction.deleteWhere: 1,
    });
    return apply(replica, spaceUuid, table: table, action: action);
  }

  /// Applies a scripted operation through the same path used by random runs.
  /// This also lets regressions pin a graph transition independently of the
  /// scheduling seed.
  Future<DstOperationOutcome> apply(
    DstReplica replica,
    UuidValue spaceUuid, {
    required DstTable table,
    required DstAction action,
  }) async {
    return perform(
      replica,
      spaceUuid,
      table: table,
      action: action,
      body: (tx, evidence, refusal) =>
          _apply(replica, spaceUuid, table, action, tx, evidence, refusal),
    );
  }

  /// Runs a concrete populated-workload operation through the same authoring,
  /// refusal and rollback boundary as random operations.
  Future<DstOperationOutcome> perform(
    DstReplica replica,
    UuidValue spaceUuid, {
    required DstTable table,
    required DstAction action,
    required Future<DstOperationOutcome> Function(
      Transaction,
      DstWriteEvidence,
      DstRejection,
    )
    body,
  }) async {
    final path = '${table.tableName}.${action.name}';
    attemptedPaths.update(path, (count) => count + 1, ifAbsent: () => 1);
    final before = await DstSnapshot.capture(replica);
    final evidence = DstWriteEvidence(before);
    final refusal = DstRejection(before, spaceUuid);
    final progressBefore = await _spaceProgress(replica);
    var recorded = false;
    var committed = false;
    var checked = false;
    try {
      final outcome = await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          spaceUuid,
          (tx) => body(tx, evidence, refusal),
        ),
      );
      if (outcome == DstOperationOutcome.applied) {
        appliedPaths.update(path, (count) => count + 1, ifAbsent: () => 1);
        recorded = true;
        committed = true;
        final after = await DstSnapshot.capture(replica);
        final blockers = refusal.deleteReasons(definiteOnly: true).toList();
        if (blockers.isNotEmpty) {
          throw StateError('Blocked $path unexpectedly committed: $blockers');
        }
        final violations = [
          ...evidence.validate(after),
          ...observe(replica, after, before: before),
        ];
        if (violations.isNotEmpty) {
          throw StateError(
            '$path: $violations\nBefore:\n${before.renderSpace(spaceUuid)}\nInputs: ${evidence.values}\nAfter:\n${after.renderSpace(spaceUuid)}',
          );
        }
        oracle.accept(after, before: before);
        if (action == DstAction.swapUnique) {
          coverage.observeSwap(table, before, after, evidence.values.keys.toSet());
        }
        checked = true;
      }
      if (outcome == DstOperationOutcome.skipped) {
        skippedPaths.update(path, (count) => count + 1, ifAbsent: () => 1);
        recorded = true;
      }
      return outcome;
    } on Exception catch (exception) {
      final message = exception.toString();
      if (refusal.accepts(message, evidence)) {
        final after = await DstSnapshot.capture(replica);
        final progressAfter = await _spaceProgress(replica);
        if (_rollbackState(before, replica) != _rollbackState(after, replica) ||
            progressBefore != progressAfter) {
          throw StateError(
            'Rejected $path left domain or authored progress: $message\n'
            'Before: ${_rollbackState(before, replica)}\n'
            'After: ${_rollbackState(after, replica)}\n'
            'Scope progress before: $progressBefore\nAfter: $progressAfter',
          );
        }
        rejections.add(message);
        recorded = true;
        coverage.event('constrainedRejection', '$path/${rejections.length}');
        return DstOperationOutcome.rejected;
      }
      // Errors from the database cross an isolate boundary and arrive with no
      // engine frames, so the phase and target are attached here or they are
      // lost.
      throw StateError(
        'Local ${action.name} on ${table.tableName} at ${replica.name} '
        'failed: $exception',
      );
    } finally {
      if (!recorded) {
        unexpectedPaths.update(path, (count) => count + 1, ifAbsent: () => 1);
      }
      if (committed && !checked) validationFailures++;
    }
  }

  Future<DstOperationOutcome> _apply(
    DstReplica replica,
    UuidValue spaceUuid,
    DstTable table,
    DstAction action,
    Transaction tx,
    DstWriteEvidence evidence,
    DstRejection refusal,
  ) async {
    final session = replica.session;
    void intend(
      TableRow<UuidValue?> row, {
      Set<String>? columns,
      bool insertDefaults = false,
    }) => evidence.write(
      table.tableName,
      row.toJson() as Map<String, dynamic>,
      columns: columns,
      insertDefaults: insertDefaults,
    );
    final model = table.model;
    final visible = await model.find(session, transaction: tx, spaceUuid: spaceUuid);

    if (action == DstAction.restore) {
      final all = await model.find(
        session,
        transaction: tx,
        includeHidden: true,
        spaceUuid: spaceUuid,
      );
      final visibleIds = visible.map((row) => row.id).toSet();
      final hidden = all.where((row) => !visibleIds.contains(row.id)).toList();
      final row = random.pickOrNull(hidden);
      if (row == null) return DstOperationOutcome.skipped;
      // Reuse the identity and pass the materialized row through. The engine
      // must recover any authored unique/FK claim retained behind projection.
      intend(row);
      evidence.visibility(table.tableName, [row.id!], deleted: false);
      await model.insert(session, row, tx);
      return DstOperationOutcome.applied;
    }

    if (action == DstAction.insert || action == DstAction.insertBatch) {
      final rows = <TableRow<UuidValue?>>[];
      final count = action == DstAction.insertBatch ? 2 : 1;
      for (var index = 0; index < count; index++) {
        final row = await _generatedRow(
          session,
          table,
          tx,
          spaceUuid,
          insertDefaults: true,
        );
        if (row == null) return DstOperationOutcome.skipped;
        rows.add(row);
      }
      for (final row in rows) {
        intend(row, insertDefaults: true);
      }
      if (action == DstAction.insertBatch) {
        await model.insertBatch(session, rows, tx);
      } else {
        await model.insert(session, rows.single, tx);
      }
      return DstOperationOutcome.applied;
    }

    if (action == DstAction.upsert) {
      final all = await model.find(
        session,
        transaction: tx,
        includeHidden: true,
        spaceUuid: spaceUuid,
      );
      final existing = random.pickOrNull(all);
      final row = await _generatedRow(
        session,
        table,
        tx,
        spaceUuid,
        existing: existing,
        insertDefaults:
            existing == null ||
            evidence.before.rows[table.tableName]![existing.id]!.visible,
      );
      if (row == null) return DstOperationOutcome.skipped;
      intend(
        row,
        insertDefaults:
            existing == null ||
            evidence.before.rows[table.tableName]![existing.id]!.visible,
      );
      if (existing != null &&
          !evidence.before.rows[table.tableName]![existing.id]!.visible) {
        evidence.visibility(table.tableName, [row.id!], deleted: false);
      }
      await model.upsert(session, row, tx);
      return DstOperationOutcome.applied;
    }

    if (visible.isEmpty) return DstOperationOutcome.skipped;
    final first = random.pick(visible);
    if (action == DstAction.delete) {
      refusal.delete(table, [first.id!]);
      evidence.visibility(table.tableName, [first.id!], deleted: true);
      await model.delete(session, first, tx);
      return DstOperationOutcome.applied;
    }

    final rest = visible.where((row) => row.id != first.id).toList();
    final second = random.pickOrNull(rest);
    final selected = [first, ?second];
    if (action == DstAction.deleteBatch) {
      refusal.delete(table, selected.map((row) => row.id!));
      evidence.visibility(
        table.tableName,
        selected.map((row) => row.id!),
        deleted: true,
      );
      await model.deleteBatch(session, selected, tx);
      return DstOperationOutcome.applied;
    }
    if (action == DstAction.deleteWhere) {
      refusal.delete(table, selected.map((row) => row.id!));
      evidence.visibility(
        table.tableName,
        selected.map((row) => row.id!),
        deleted: true,
      );
      await model.deleteWhere(session, selected.map((row) => row.id!).toSet(), tx);
      return DstOperationOutcome.applied;
    }

    if (action == DstAction.swapUnique) {
      if (second == null) return DstOperationOutcome.skipped;
      final indexes = dstUniqueIndexes.where((index) => index.table == table).toList();
      final index = random.pickOrNull(indexes);
      if (index == null) return DstOperationOutcome.skipped;
      final columns = index.columns.where((column) => column != 'spaceId').toSet();
      final left = first.toJson() as Map<String, dynamic>;
      final right = second.toJson() as Map<String, dynamic>;
      final swappedLeft = {
        ...left,
        for (final column in columns) column: right[column],
      };
      final swappedRight = {
        ...right,
        for (final column in columns) column: left[column],
      };
      intend(model.fromJson(swappedLeft), columns: columns);
      intend(model.fromJson(swappedRight), columns: columns);
      await model.updateBatch(
        session,
        [model.fromJson(swappedLeft), model.fromJson(swappedRight)],
        columns,
        tx,
      );
      return DstOperationOutcome.applied;
    }

    final columns = _columns(table);
    if (action == DstAction.fullRowUpdate) {
      // A full model from a read often passes repaired fields back unchanged.
      // Change an unrelated field where one exists to probe that distinction.
      final unrelated = columns
          .where(
            (column) =>
                !dstForeignKeys.any(
                  (edge) => edge.child == table && edge.column == column,
                ) &&
                !dstUniqueIndexes.any(
                  (index) => index.table == table && index.columns.contains(column),
                ),
          )
          .toList();
      final changed = unrelated.isEmpty ? <String>{} : {random.pick(unrelated)};
      final row = await _generatedRow(
        session,
        table,
        tx,
        spaceUuid,
        existing: first,
        columns: changed,
      );
      if (row == null) return DstOperationOutcome.skipped;
      intend(row);
      await model.update(session, row, null, tx);
      return DstOperationOutcome.applied;
    }

    final changed = {random.pick(columns)};
    final updatedFirst = await _generatedRow(
      session,
      table,
      tx,
      spaceUuid,
      existing: first,
      columns: changed,
    );
    if (updatedFirst == null) return DstOperationOutcome.skipped;
    if (action == DstAction.updateWhere) {
      final data = updatedFirst.toJson() as Map<String, dynamic>;
      for (final row in selected) {
        evidence.write(table.tableName, {
          ...row.toJson() as Map<String, dynamic>,
          for (final column in changed) column: data[column],
        }, columns: changed);
      }
      await model.updateWhere(session, selected.map((row) => row.id!).toSet(), {
        for (final column in changed) column: data[column],
      }, tx);
    } else if (action == DstAction.updateBatch) {
      final updated = [updatedFirst];
      if (second != null) {
        final row = await _generatedRow(
          session,
          table,
          tx,
          spaceUuid,
          existing: second,
          columns: changed,
        );
        if (row == null) return DstOperationOutcome.skipped;
        updated.add(row);
      }
      for (final row in updated) {
        intend(row, columns: changed);
      }
      await model.updateBatch(session, updated, changed, tx);
    } else {
      intend(updatedFirst, columns: changed);
      await model.update(session, updatedFirst, changed, tx);
    }
    return DstOperationOutcome.applied;
  }

  List<String> _columns(DstTable table) => table.definition.columns
      .where((column) => column.name != 'id' && column.name != 'spaceId')
      .map((column) => column.name)
      .toList();

  Future<TableRow<UuidValue?>?> _generatedRow(
    DatabaseSession session,
    DstTable table,
    Transaction tx,
    UuidValue spaceUuid, {
    TableRow<UuidValue?>? existing,
    Set<String>? columns,
    bool insertDefaults = false,
  }) async {
    final data = existing == null
        ? <String, dynamic>{'id': _newId().toJson()}
        : existing.toJson() as Map<String, dynamic>;
    final changed =
        columns ??
        (existing == null ? _columns(table).toSet() : {random.pick(_columns(table))});
    for (final column in table.definition.columns.where(
      (column) => changed.contains(column.name),
    )) {
      final edges = dstForeignKeys.where(
        (edge) => edge.child == table && edge.column == column.name,
      );
      if (edges.isNotEmpty) {
        final edge = edges.single;
        final parents = await edge.parent.model.find(
          session,
          transaction: tx,
          spaceUuid: spaceUuid,
        );
        final parent = random.pickOrNull(parents);
        if (parent == null && !edge.nullable) return null;
        var value = edge.nullable && random.chance(0.25)
            ? null
            : (parent?.toJson() as Map<String, dynamic>?)?[edge.parentColumn];
        // An omitted persisted default is an actual insert reference. Keep
        // exercising defaults when legal, but do not generate cross-space or
        // missing default targets and call those valid operations.
        if (insertDefaults &&
            value == null &&
            edge.defaultValue != null &&
            !parents.any((row) => row.id == edge.defaultValue)) {
          if (parent == null) return null;
          value = (parent.toJson() as Map<String, dynamic>)[edge.parentColumn];
        }
        data[column.name] = value;
      } else if ((column.dartType ?? '').startsWith('String')) {
        final unique = dstUniqueIndexes.any(
          (index) => index.table == table && index.columns.contains(column.name),
        );
        data[column.name] = unique ? 'claim-${random.nextInt(4)}' : _name(column.name);
      } else if ((column.dartType ?? '').startsWith('UuidValue')) {
        data[column.name] = dstUniqueValues[random.nextInt(dstUniqueValues.length)]
            .toJson();
      } else if ((column.dartType ?? '').startsWith('int')) {
        data[column.name] = column.isNullable && random.chance(0.25)
            ? null
            : random.nextInt(4);
      } else {
        throw StateError('No generated value for ${table.tableName}.${column.name}');
      }
    }
    return table.model.fromJson(data);
  }

  UuidValue _newId() => ids.next();

  String _name(String prefix) => '$prefix-${random.nextInt(1000)}';

  static String _rollbackState(DstSnapshot snapshot, DstReplica replica) => [
    for (final space in replica.spaceUuids) snapshot.renderSpace(space),
    snapshot.renderRawMetadata(),
  ].join('\n');

  static Future<String> _spaceProgress(DstReplica replica) async {
    final nodes = await OfflineSyncSpaceNode.db.find(replica.rawSession);
    final values = nodes.map((node) => node.toJson().toString()).toList()..sort();
    return values.join('\n');
  }
}

enum DstAction {
  insert,
  update,
  delete,
  restore,
  fullRowUpdate,
  upsert,
  insertBatch,
  updateBatch,
  deleteBatch,
  swapUnique,
  updateWhere,
  deleteWhere,
}
