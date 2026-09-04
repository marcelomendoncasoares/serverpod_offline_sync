import 'package:clock/clock.dart';
// Imported with `show` because the barrel below re-exports overlapping names.
import 'package:serverpod_database/serverpod_database.dart'
    show DatabaseSession, Transaction;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import '../../integration/test_tools/client_session.dart';
import 'dst_random.dart';

/// The tables every replica registers for synchronization.
///
/// Shared with the integration suites: the registry validates the whole set
/// at `initialize()`, so the two must agree.
final dstSyncTables = testSyncTables;

/// The tables the simulation authors operations against.
///
/// Chosen to cover every foreign-key action the engine accepts on synced
/// tables, plus both unique-index shapes, in one small closed graph:
///
/// - `city` and `person` are roots with no outbound foreign key.
/// - `town.cityId` is `onDelete=Cascade`; `town.mayorId` is `onDelete=SetNull`.
/// - `address.inhabitantId` is `onDelete=NoAction` and carries the
///   foreign-key-only global unique index. Synced tables cannot declare
///   `Restrict`; the registry requires `NoAction`, which has the same effect.
/// - `unique_set_null_child.parentId` is `onDelete=SetNull` and *also* carries
///   that global unique index - the one shape where foreign key repair and
///   unique resolution act on the same column.
/// - `unique.name` is unique per scope.
enum DstTable {
  /// The `city` table: a parent with no outbound foreign key.
  city('city'),

  /// The `person` table: a parent with no outbound foreign key.
  person('person'),

  /// The `town` table: cascade to `city`, set-null to `person`.
  town('town'),

  /// The `address` table: no-action to `person`, unique foreign key column.
  address('address'),

  /// The `unique` table: a per-scope unique name and no foreign key.
  unique('unique'),

  /// The `unique_set_null_child` table: set-null to `person` on a column that
  /// also carries a global unique index.
  ///
  /// Repair frees that value while the parent is hidden, and the parent coming
  /// back makes the attempted value eligible again - on a row that may by then
  /// be tombstoned, and so invisible to unique resolution while still holding
  /// the value in the physical index.
  uniqueSetNullChild('unique_set_null_child');

  const DstTable(this.tableName);

  /// The physical table name, used to key snapshots and merge changes.
  final String tableName;
}

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
    final table = random.weighted({
      DstTable.city: 2,
      DstTable.person: 3,
      DstTable.town: 3,
      DstTable.address: 3,
      DstTable.unique: 2,
      DstTable.uniqueSetNullChild: 3,
    });
    final action = random.weighted({
      _Action.insert: 5,
      _Action.update: 3,
      _Action.delete: 2,
    });

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
    _Action action,
    Transaction tx,
  ) async {
    final session = replica.session;
    return switch (action) {
      _Action.insert => _applyInsert(session, table, tx),
      _Action.update => _applyUpdate(session, table, tx),
      _Action.delete => _applyDelete(session, table, tx),
    };
  }

  /// Inserts one new row, pointing its references at rows this replica can
  /// currently see. A reference with no candidate is left null.
  Future<DstOperationOutcome> _applyInsert(
    DatabaseSession session,
    DstTable table,
    Transaction tx,
  ) async {
    switch (table) {
      case DstTable.city:
        await City.db.insertRow(
          session,
          City(id: _newId(), name: _name('city')),
          transaction: tx,
        );

      case DstTable.person:
        await Person.db.insertRow(
          session,
          Person(id: _newId(), name: _name('person'), surname: _name('sur')),
          transaction: tx,
        );

      case DstTable.town:
        final city = await _pickRow(City.db.find(session, transaction: tx));
        final mayor = await _pickRow(Person.db.find(session, transaction: tx));
        await Town.db.insertRow(
          session,
          Town(
            id: _newId(),
            name: _name('town'),
            cityId: city?.id,
            mayorId: mayor?.id,
          ),
          transaction: tx,
        );

      case DstTable.address:
        final inhabitant = await _pickRow(
          Person.db.find(session, transaction: tx),
        );
        await Address.db.insertRow(
          session,
          Address(
            id: _newId(),
            street: _name('street'),
            inhabitantId: inhabitant?.id,
          ),
          transaction: tx,
        );

      case DstTable.unique:
        await Unique.db.insertRow(
          session,
          // A deliberately small alphabet so concurrent replicas collide.
          Unique(id: _newId(), name: 'name-${random.nextInt(4)}'),
          transaction: tx,
        );

      case DstTable.uniqueSetNullChild:
        final parent = await _pickRow(Person.db.find(session, transaction: tx));
        await UniqueSetNullChild.db.insertRow(
          session,
          UniqueSetNullChild(
            id: _newId(),
            name: _name('unique-child'),
            parentId: parent?.id,
          ),
          transaction: tx,
        );
    }

    return DstOperationOutcome.applied;
  }

  /// Updates one existing row, or skips when the replica has none.
  Future<DstOperationOutcome> _applyUpdate(
    DatabaseSession session,
    DstTable table,
    Transaction tx,
  ) async {
    switch (table) {
      case DstTable.city:
        final row = await _pickRow(City.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await City.db.updateRow(
          session,
          row.copyWith(name: _name('city')),
          columns: (t) => [t.name],
          transaction: tx,
        );

      case DstTable.person:
        final row = await _pickRow(Person.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Person.db.updateRow(
          session,
          row.copyWith(name: _name('person')),
          columns: (t) => [t.name],
          transaction: tx,
        );

      case DstTable.town:
        final row = await _pickRow(Town.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        // Half the updates re-point the cascade edge, so foreign-key
        // projection has moving targets rather than a static graph.
        if (random.chance(0.5)) {
          final city = await _pickRow(City.db.find(session, transaction: tx));
          await Town.db.updateRow(
            session,
            row.copyWith(cityId: city?.id),
            columns: (t) => [t.cityId],
            transaction: tx,
          );
        } else {
          await Town.db.updateRow(
            session,
            row.copyWith(name: _name('town')),
            columns: (t) => [t.name],
            transaction: tx,
          );
        }

      case DstTable.address:
        final row = await _pickRow(Address.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Address.db.updateRow(
          session,
          row.copyWith(street: _name('street')),
          columns: (t) => [t.street],
          transaction: tx,
        );

      case DstTable.unique:
        final row = await _pickRow(Unique.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Unique.db.updateRow(
          session,
          row.copyWith(name: 'name-${random.nextInt(4)}'),
          columns: (t) => [t.name],
          transaction: tx,
        );

      case DstTable.uniqueSetNullChild:
        final row = await _pickRow(
          UniqueSetNullChild.db.find(session, transaction: tx),
        );
        if (row == null) return DstOperationOutcome.skipped;
        // Repointing the unique foreign key is what makes two rows claim one
        // parent; renaming would never exercise the index.
        final parent = await _pickRow(Person.db.find(session, transaction: tx));
        await UniqueSetNullChild.db.updateRow(
          session,
          row.copyWith(parentId: parent?.id),
          columns: (t) => [t.parentId],
          transaction: tx,
        );
    }

    return DstOperationOutcome.applied;
  }

  /// Deletes one existing row, or skips when the replica has none.
  Future<DstOperationOutcome> _applyDelete(
    DatabaseSession session,
    DstTable table,
    Transaction tx,
  ) async {
    switch (table) {
      case DstTable.city:
        final row = await _pickRow(City.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await City.db.deleteRow(session, row, transaction: tx);

      case DstTable.person:
        final row = await _pickRow(Person.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Person.db.deleteRow(session, row, transaction: tx);

      case DstTable.town:
        final row = await _pickRow(Town.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Town.db.deleteRow(session, row, transaction: tx);

      case DstTable.address:
        final row = await _pickRow(Address.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Address.db.deleteRow(session, row, transaction: tx);

      case DstTable.unique:
        final row = await _pickRow(Unique.db.find(session, transaction: tx));
        if (row == null) return DstOperationOutcome.skipped;
        await Unique.db.deleteRow(session, row, transaction: tx);

      case DstTable.uniqueSetNullChild:
        final row = await _pickRow(
          UniqueSetNullChild.db.find(session, transaction: tx),
        );
        if (row == null) return DstOperationOutcome.skipped;
        await UniqueSetNullChild.db.deleteRow(session, row, transaction: tx);
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

enum _Action { insert, update, delete }
