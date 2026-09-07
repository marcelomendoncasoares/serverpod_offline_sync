import 'package:clock/clock.dart';
// Imported with `show` because the barrel below re-exports overlapping names.
import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Transaction;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import '../../integration/test_tools/client_session.dart';
import 'dst_random.dart';
import 'dst_schema.dart';

export 'dst_schema.dart';

/// The tables every replica registers for synchronization.
///
/// Shared with the integration suites: the registry validates the whole set
/// at `initialize()`, so the two must agree.
final dstSyncTables = testSyncTables;

/// The well-known `company.townId` default from `company.spy.yaml`.
///
/// Set-default repair rewrites a company onto this town. Row ids are globally
/// unique, so the simulation inserts this town in a single scope; other scopes
/// exercise the path where the default target is missing.
const dstDefaultTownId = UuidValue.raw('550e8400-e29b-41d4-a716-446655440000');

/// One replica in the simulation: an isolated database with its own node
/// identity, clock skew, and set of scopes the adversary delivers to it.
class DstReplica {
  DstReplica._({
    required this.name,
    required this.rawSession,
    required this.session,
    required this.sync,
    required this.scopeUuids,
    required this.nodeUuid,
    required this.clock,
  });

  /// Builds a replica on its own SQLite file.
  ///
  /// [scopeUuids] is the set of scopes this replica participates in. At this
  /// tier "participates in" is a harness concept - it decides which scopes the
  /// adversary collects from and delivers to - which is exactly the subscription
  /// set the observer-independence property varies.
  ///
  /// [nodeUuid] is seeded rather than left to the engine. `CrdtScopeManager`
  /// mints `CrdtNode()` without an explicit id, which falls back to a
  /// wall-clock v7 UUID, and `Hlc.compareTo` breaks ties on the node UUID - so
  /// leaving it to the engine would make concurrent merge winners
  /// nondeterministic and seeds would not replay.
  static Future<DstReplica> create({
    required String name,
    required List<UuidValue> scopeUuids,
    required UuidValue nodeUuid,
    required Clock clock,
  }) async {
    final rawSession = await createAdditionalTestSession();
    final session = CrdtDatabaseSession.wraps(
      rawSession,
      syncTables: dstSyncTables,
    );
    await session.db.initialize();

    // Seed the replica identity before the engine can mint one. The manager
    // adopts the current node of the first scope that already has one
    // (`CrdtScopeManager._getOrCreateCurrentNode`), so pre-creating the node
    // and attaching it to every scope keeps one stable identity per replica -
    // which is the engine's own model of a node.
    final node = await CrdtNode.db.insertRow(
      rawSession,
      CrdtNode(uuidNodeId: nodeUuid),
    );
    for (final scopeUuid in scopeUuids) {
      await CrdtScope.db.insertRow(
        rawSession,
        CrdtScope(uuidScopeId: scopeUuid, currentNodeId: node.id),
      );
    }

    final replica = DstReplica._(
      name: name,
      rawSession: rawSession,
      session: session,
      sync: CrdtSync(
        syncTables: dstSyncTables,
        serializationManager: rawSession.db.serializationManager,
      ),
      scopeUuids: scopeUuids,
      nodeUuid: nodeUuid,
      clock: clock,
    );

    // Materialize scope state through the engine so collection has a scope to
    // key by before the replica has authored anything into it.
    await withClock(clock, () async {
      for (final scopeUuid in scopeUuids) {
        await session.db.transactionForUser(scopeUuid, (_) async {});
      }
    });
    await replica._assertSeededNodeIdentity();

    return replica;
  }

  /// Inserts [dstDefaultTownId] into [scopeUuid] so set-default repair has a
  /// legal target in that scope.
  ///
  /// Call this once, for one replica and one scope. A second insert of the
  /// same id is an ownership collision, not a second default town.
  Future<void> seedDefaultTown(UuidValue scopeUuid) {
    return withReplicaClock(
      () => session.db.transactionForUser(
        scopeUuid,
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
  final CrdtDatabaseSession session;

  /// This replica's sync engine, used to collect outbound changes.
  final CrdtSync sync;

  /// The scopes the adversary exchanges for this replica.
  final List<UuidValue> scopeUuids;

  /// This replica's seeded node identity. Breaks HLC ties, so it is pinned.
  final UuidValue nodeUuid;

  /// This replica's view of time, skewed from the shared simulation clock.
  final Clock clock;

  /// Runs [body] with this replica's clock installed.
  Future<T> withReplicaClock<T>(Future<T> Function() body) => withClock(clock, body);

  /// Fails loudly if the engine did not adopt the seeded node identity.
  ///
  /// Seeding relies on how `CrdtScopeManager` resolves a current node, which is
  /// an internal detail. If that strategy changes, the simulation would
  /// silently lose determinism and seeds would stop replaying; this turns that
  /// into an immediate, explanatory failure instead.
  Future<void> _assertSeededNodeIdentity() async {
    final nodes = await CrdtNode.db.find(rawSession);
    final adopted = nodes.map((node) => node.uuidNodeId).toSet();
    if (adopted.length == 1 && adopted.single == nodeUuid) return;
    throw StateError(
      'Replica $name did not adopt its seeded node identity $nodeUuid '
      '(found $adopted). CrdtScopeManager likely changed how it resolves the '
      'current node, so the simulation can no longer pin node identity and '
      'seeds will not replay. Give the engine an injectable node id instead.',
    );
  }

  /// Collects every change this replica holds for [scopeUuid].
  ///
  /// The harness deliberately collects the full history rather than tracking
  /// per-peer checkpoints. Redelivery is a merge the engine must absorb
  /// idempotently, so letting the adversary resend is a property under test
  /// rather than a defect in the harness.
  Future<CrdtMergeSet> collect(UuidValue scopeUuid) async {
    return withReplicaClock(
      () => sync
          .collectPendingChanges(
            rawSession,
            checkpointsByScopeUuid: {scopeUuid: const []},
          )
          .toList(),
    );
  }

  /// Merges [changes] for [scopeUuid] into this replica.
  Future<void> merge(CrdtMergeSet changes, UuidValue scopeUuid) async {
    if (changes.isEmpty) return;
    await withReplicaClock(
      () => session.db.mergeChanges(changes, scopeId: scopeUuid),
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
      '${change.uuidScopeId}|${change.tableName}|${change.uuidRowId}'
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
  /// unique conflict, or a reference to a row that is not visible in scope.
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

  /// Applies one randomly chosen operation on [replica] in [scopeUuid].
  Future<DstOperationOutcome> step(
    DstReplica replica,
    UuidValue scopeUuid,
  ) async {
    final table = random.pick(DstTable.values);
    final action = random.weighted({
      DstAction.insert: 5,
      DstAction.update: 3,
      DstAction.delete: 2,
    });
    return apply(replica, scopeUuid, table: table, action: action);
  }

  /// Applies a scripted operation through the same path used by random runs.
  /// This also lets regressions pin a graph transition independently of the
  /// scheduling seed.
  Future<DstOperationOutcome> apply(
    DstReplica replica,
    UuidValue scopeUuid, {
    required DstTable table,
    required DstAction action,
  }) async {
    try {
      return await replica.withReplicaClock(
        () => replica.session.db.transactionForUser(
          scopeUuid,
          (tx) => _apply(replica, table, action, tx),
        ),
      );
    } on Exception catch (exception) {
      final message = exception.toString();
      if (_isExpectedRejection(message)) {
        rejections.add(message);
        return DstOperationOutcome.rejected;
      }
      // Errors from the database cross an isolate boundary and arrive with no
      // engine frames, so the phase and target are attached here or they are
      // lost.
      throw StateError(
        'Local ${action.name} on ${table.tableName} at ${replica.name} '
        'failed: $exception',
      );
    }
  }

  Future<DstOperationOutcome> _apply(
    DstReplica replica,
    DstTable table,
    DstAction action,
    Transaction tx,
  ) async {
    final session = replica.session;
    final model = table.model;
    final existing = action == DstAction.insert
        ? null
        : await _pickRow(model.find(session, transaction: tx));
    if (action != DstAction.insert && existing == null) {
      return DstOperationOutcome.skipped;
    }
    if (action == DstAction.delete) {
      await model.delete(session, existing!, tx);
      return DstOperationOutcome.applied;
    }

    final data = existing == null
        ? <String, dynamic>{'id': _newId().toJson()}
        : existing.toJson() as Map<String, dynamic>;
    final columns = table.definition.columns
        .where((column) => column.name != 'id' && column.name != 'scopeId')
        .toList();
    final changed = existing == null ? columns : [random.pick(columns)];
    for (final column in changed) {
      final edges = dstForeignKeys.where(
        (edge) => edge.child == table && edge.column == column.name,
      );
      if (edges.isNotEmpty) {
        final edge = edges.single;
        final parent = await _pickRow(edge.parent.model.find(session, transaction: tx));
        if (parent == null && !edge.nullable) return DstOperationOutcome.skipped;
        data[column.name] = edge.nullable && random.chance(0.25)
            ? null
            : (parent?.toJson() as Map<String, dynamic>?)?[edge.parentColumn];
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
    final row = model.fromJson(data);
    if (existing == null) {
      await model.insert(session, row, tx);
    } else {
      await model.update(
        session,
        row,
        changed.map((column) => column.name).toSet(),
        tx,
      );
    }
    return DstOperationOutcome.applied;
  }

  Future<T?> _pickRow<T>(Future<List<T>> rows) async => random.pickOrNull(await rows);

  UuidValue _newId() => ids.next();

  String _name(String prefix) => '$prefix-${random.nextInt(1000)}';

  /// Whether [message] is a refusal the engine makes by design.
  ///
  /// The list is deliberately narrow. An unrecognized failure is rethrown so a
  /// real defect surfaces as a failing seed instead of being absorbed as an
  /// expected rejection.
  static bool _isExpectedRejection(String message) {
    const expected = [
      // `_assertVisibleForeignKeyTargets`: the target is tombstoned, missing,
      // or owned by another scope - the three are one branch by design.
      'Cannot reference deleted row',
      // A local `onDelete=NoAction` parent delete with a visible child still
      // referencing it.
      'Cannot delete',
      // Constraint rejections surfaced by the database itself.
      'UNIQUE constraint failed',
      'FOREIGN KEY constraint failed',
    ];
    return expected.any(message.contains);
  }
}

enum DstAction { insert, update, delete }
