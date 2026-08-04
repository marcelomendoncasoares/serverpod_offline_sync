// Imported with `show` because the barrel below re-exports overlapping names.
import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'dst_world.dart';

/// A foreign-key edge in the simulated world.
///
/// `uniqueIndexed` marks a column that also carries a unique index, which
/// matters because unique-conflict resolution releases such a column by
/// writing straight to the domain row. See [DstOracle.projectionPurity].
typedef DstForeignKey = ({
  DstTable child,
  String column,
  DstTable parent,
  String action,
  bool uniqueIndexed,
});

/// The foreign-key edges the simulation exercises, one per `onDelete` action.
const dstForeignKeys = <DstForeignKey>[
  (
    child: DstTable.town,
    column: 'cityId',
    parent: DstTable.city,
    action: 'cascade',
    uniqueIndexed: false,
  ),
  (
    child: DstTable.town,
    column: 'mayorId',
    parent: DstTable.person,
    action: 'setNull',
    uniqueIndexed: false,
  ),
  (
    child: DstTable.address,
    column: 'inhabitantId',
    parent: DstTable.person,
    action: 'restrict',
    uniqueIndexed: true,
  ),
];

/// One row as the simulation compares it.
///
/// `visible` is carried rather than filtered out because "hidden here, visible
/// there" is a different defect from "missing here", and a diff that cannot
/// tell them apart is much harder to act on.
typedef DstRow = ({
  UuidValue scopeUuid,
  Map<String, Object?> columns,
  bool visible,
});

/// One foreign-key projection record, resolved to the names it describes.
///
/// `attemptedValue` is the authored fact; `visibleValue` and `overrideReason`
/// are derived from it plus the parent's visibility. Keeping all three lets a
/// single replica be checked against itself.
typedef DstProjection = ({
  String tableName,
  UuidValue rowId,
  String columnName,
  UuidValue? attemptedValue,
  UuidValue? visibleValue,
  CrdtForeignKeyOverrideReason? overrideReason,
});

/// One replica's whole visible database, plus what it is hiding.
///
/// Rows are keyed by `(table, rowId)` - the global identity the engine
/// guarantees - and carry their owning scope as a UUID rather than the local
/// normalized integer, which differs between replicas for the same scope.
class DstSnapshot {
  /// Creates a snapshot. Prefer [capture].
  DstSnapshot({
    required this.rows,
    required this.projections,
    required this.causalLengths,
  });

  /// Captures [replica]'s current state through the ordinary read path.
  ///
  /// Reads are unscoped, which is the package's admin read: no scope isolation
  /// filter, and a row is visible while its owning scope sees it. That is the
  /// view the properties need, because the question is what each replica
  /// believes about every scope it holds.
  static Future<DstSnapshot> capture(DstReplica replica) async {
    final session = replica.session;
    final scopes = await CrdtScope.db.find(session);
    final scopeUuidById = {
      for (final scope in scopes) scope.id!: scope.uuidScopeId,
    };

    final rows = <String, Map<UuidValue, DstRow>>{};

    for (final table in DstTable.values) {
      final allRows = await _find(session, table, includeHidden: true);
      final visibleRows = await _find(session, table, includeHidden: false);
      final visibleIds = {for (final row in visibleRows) row.id!};

      rows[table.tableName] = {
        for (final row in allRows)
          row.id!: (
            scopeUuid: scopeUuidById[_scopeIdOf(row)]!,
            columns: _comparableColumns(row),
            visible: visibleIds.contains(row.id),
          ),
      };
    }

    return DstSnapshot(
      rows: rows,
      projections: await _captureProjections(session),
      causalLengths: await _captureCausalLengths(session),
    );
  }

  /// Every row by table name and row id, visible or not.
  final Map<String, Map<UuidValue, DstRow>> rows;

  /// Every foreign-key projection record held by this replica.
  final List<DstProjection> projections;

  /// Causal-length flag per row, keyed `table/rowId`.
  ///
  /// The flag counts visibility generations: odd is visible, even is deleted.
  /// It is the mechanism behind the claim that add, delete and restore can
  /// only advance and never oscillate.
  final Map<String, int> causalLengths;

  static Future<Map<String, int>> _captureCausalLengths(
    CrdtDatabaseSession session,
  ) async {
    final tombstones = await CrdtDataDeleted.db.find(
      session,
      include: CrdtDataDeleted.include(
        row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
      ),
    );

    return {
      for (final tombstone in tombstones)
        if (tombstone.row?.tbl?.name case final tableName?)
          '$tableName/${tombstone.row!.uuidRowId}': tombstone.clFlag,
    };
  }

  static Future<List<DstProjection>> _captureProjections(
    CrdtDatabaseSession session,
  ) async {
    final records = await CrdtDataForeignKey.db.find(
      session,
      include: CrdtDataForeignKey.include(
        field: CrdtDataField.include(
          row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
          column: CrdtSchemaColumn.include(),
        ),
      ),
    );

    return [
      for (final record in records)
        if (record.field?.row?.tbl?.name case final tableName?)
          if (record.field?.column?.name case final columnName?)
            (
              tableName: tableName,
              rowId: record.field!.row!.uuidRowId,
              columnName: columnName,
              attemptedValue: record.attemptedValue,
              visibleValue: record.visibleValue,
              overrideReason: record.overrideReason,
            ),
    ];
  }

  /// Visible rows only, by table name and row id.
  ///
  /// Computed once: [DstOracle.invariants] reads this several times per call -
  /// once per foreign-key edge - and runs after every merge.
  late final Map<String, Map<UuidValue, DstRow>> visible = {
    for (final entry in rows.entries)
      entry.key: {
        for (final row in entry.value.entries)
          if (row.value.visible) row.key: row.value,
      },
  };

  /// This snapshot restricted to the rows owned by [scopeUuid].
  ///
  /// This is the unit the observer-independence property compares: two replicas
  /// holding different sets of scopes must still agree exactly here.
  Map<String, Map<UuidValue, DstRow>> forScope(UuidValue scopeUuid) {
    return {
      for (final entry in rows.entries)
        entry.key: {
          for (final row in entry.value.entries)
            if (row.value.scopeUuid == scopeUuid) row.key: row.value,
        },
    };
  }

  /// A stable, human-readable rendering of [forScope], for equality and diffs.
  ///
  /// Hidden rows are rendered too, marked `HIDDEN`, so a diff distinguishes a
  /// row that merged but is hidden from one that never arrived.
  String renderScope(UuidValue scopeUuid) {
    final buffer = StringBuffer();
    final byTable = forScope(scopeUuid);
    for (final tableName in byTable.keys.toList()..sort()) {
      final tableRows = byTable[tableName]!;
      for (final rowId
          in tableRows.keys.toList()..sort((a, b) => a.uuid.compareTo(b.uuid))) {
        final row = tableRows[rowId]!;
        final rendered = [
          for (final column in row.columns.keys.toList()..sort())
            '$column=${row.columns[column]}',
        ].join(',');
        final marker = row.visible ? '' : ' HIDDEN';
        buffer.writeln('$tableName/$rowId$marker {$rendered}');
      }
    }
    return buffer.toString();
  }

  /// How many rows are visible, across every table and scope.
  int get visibleRowCount => _countRows(visible: true);

  /// How many rows are present but hidden, across every table and scope.
  int get hiddenRowCount => _countRows(visible: false);

  int _countRows({required bool visible}) => rows.values.fold(
    0,
    (sum, tableRows) =>
        sum + tableRows.values.where((row) => row.visible == visible).length,
  );

  /// Looks up a visible row in any scope.
  DstRow? lookupVisible(DstTable table, UuidValue rowId) {
    final row = rows[table.tableName]?[rowId];
    return row != null && row.visible ? row : null;
  }

  /// Columns compared across replicas.
  ///
  /// `scopeId` is dropped because it is a replica-local normalized integer; the
  /// owning scope travels as a UUID on [DstRow] instead. Relation objects are
  /// dropped because they are never populated without an explicit `include`.
  static Map<String, Object?> _comparableColumns(TableRow<UuidValue?> row) {
    final json = row.toJson() as Map<String, dynamic>;
    return {
      for (final entry in json.entries)
        if (entry.key != 'scopeId' && entry.value is! Map) entry.key: entry.value,
    };
  }

  static int _scopeIdOf(TableRow<UuidValue?> row) {
    final json = row.toJson() as Map<String, dynamic>;
    final scopeId = json['scopeId'] as int?;
    if (scopeId != null) return scopeId;
    throw StateError(
      'Row ${row.table.tableName}/${row.id} has a null scopeId. Rows created '
      'behind the sync layer are invisible to scoped reads and cannot be '
      'compared across replicas.',
    );
  }

  static Future<List<TableRow<UuidValue?>>> _find(
    CrdtDatabaseSession session,
    DstTable table, {
    required bool includeHidden,
  }) async {
    return switch (table) {
      DstTable.city =>
        includeHidden
            ? City.db.find(session, where: (t) => t.includeHiddenRows)
            : City.db.find(session),
      DstTable.person =>
        includeHidden
            ? Person.db.find(session, where: (t) => t.includeHiddenRows)
            : Person.db.find(session),
      DstTable.town =>
        includeHidden
            ? Town.db.find(session, where: (t) => t.includeHiddenRows)
            : Town.db.find(session),
      DstTable.address =>
        includeHidden
            ? Address.db.find(session, where: (t) => t.includeHiddenRows)
            : Address.db.find(session),
      DstTable.unique =>
        includeHidden
            ? Unique.db.find(session, where: (t) => t.includeHiddenRows)
            : Unique.db.find(session),
    };
  }
}

/// A property violation found by the oracle.
typedef DstViolation = ({String property, String detail});

/// A row's visibility generation only ever advances.
///
/// The causal-length flag is what makes add / delete / restore
/// order-insensitive: each is a step forward, so replicas that see the same
/// events in different orders land on the same generation. A flag that goes
/// backwards means something recomputed it rather than advancing it, and the
/// row can then oscillate. A flag that disappears is the same defect from the
/// other side, since deleted rows are meant to stay in their table.
///
/// Unlike the properties on [DstOracle] this cannot be a function of a single
/// snapshot: "never went backwards" needs two observations, and one snapshot
/// showing generation 3 is indistinguishable from one that regressed to 3 from
/// 5. So the history lives here rather than in the runner, and [observe]
/// reports against the merge that caused a regression.
class DstCausalLength {
  final Map<String, Map<String, int>> _seen = {};

  /// Records [snapshot] for [replicaName] and reports any generation that did
  /// not advance since the previous call for that replica.
  List<DstViolation> observe(String replicaName, DstSnapshot snapshot) {
    final previous = _seen[replicaName] ?? const <String, int>{};
    final violations = <DstViolation>[];

    for (final entry in previous.entries) {
      final current = snapshot.causalLengths[entry.key];
      if (current == null) {
        violations.add((
          property: 'causalLength',
          detail:
              '$replicaName lost the visibility generation of ${entry.key}, '
              'which was ${entry.value}',
        ));
        continue;
      }
      if (current < entry.value) {
        violations.add((
          property: 'causalLength',
          detail:
              '$replicaName moved ${entry.key} backwards from ${entry.value} '
              'to $current',
        ));
      }
    }

    _seen[replicaName] = snapshot.causalLengths;
    return violations;
  }
}

/// Reads a foreign-key column out of a snapshot row.
///
/// Snapshot columns come from `TableRow.toJson()`, which renders a `UuidValue`
/// as its string form, so the value has to be parsed back before it can be
/// matched against a row id.
UuidValue? _foreignKeyValue(Map<String, Object?> columns, String column) {
  final value = columns[column];
  if (value == null) return null;
  return value is UuidValue ? value : UuidValue.withValidation(value as String);
}

/// The properties every simulation state must satisfy.
///
/// Structural invariants ([foreignKeyClosure], [uniqueClosure],
/// [noCrossScopeLink]) hold after *every* merge. Agreement properties
/// ([observerIndependence]) hold once the adversary has quiesced, since before
/// that replicas legitimately hold different facts.
class DstOracle {
  /// No visible row links to a row owned by a different scope.
  ///
  /// This is the invariant the cross-scope design rests on: a foreign key may
  /// only target a row of its own scope, so a merged reference into another
  /// scope must be repaired (set null / set default) or the child hidden -
  /// never linked. See `docs/row-ownership.md` "Foreign keys stay within a
  /// scope".
  static List<DstViolation> noCrossScopeLink(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    for (final edge in dstForeignKeys) {
      final children = snapshot.visible[edge.child.tableName] ?? const {};
      for (final entry in children.entries) {
        final parentId = _foreignKeyValue(entry.value.columns, edge.column);
        if (parentId == null) continue;
        final parent = snapshot.lookupVisible(edge.parent, parentId);
        if (parent == null) continue;
        if (parent.scopeUuid == entry.value.scopeUuid) continue;
        violations.add((
          property: 'noCrossScopeLink',
          detail:
              '${edge.child.tableName}/${entry.key} in scope '
              '${entry.value.scopeUuid} links ${edge.column}=$parentId owned by '
              'scope ${parent.scopeUuid}',
        ));
      }
    }
    return violations;
  }

  /// Every visible foreign key resolves to a visible parent in the same scope.
  static List<DstViolation> foreignKeyClosure(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    for (final edge in dstForeignKeys) {
      final children = snapshot.visible[edge.child.tableName] ?? const {};
      for (final entry in children.entries) {
        final parentId = _foreignKeyValue(entry.value.columns, edge.column);
        if (parentId == null) continue;
        final parent = snapshot.lookupVisible(edge.parent, parentId);
        if (parent != null && parent.scopeUuid == entry.value.scopeUuid) {
          continue;
        }
        violations.add((
          property: 'foreignKeyClosure',
          detail:
              'visible ${edge.child.tableName}/${entry.key} references '
              '${edge.parent.tableName}/$parentId which is '
              '${parent == null ? 'missing' : 'owned by another scope'} '
              '(${edge.action} edge)',
        ));
      }
    }
    return violations;
  }

  /// No visible unique index is violated.
  ///
  /// `unique.name` is unique per scope; `address.inhabitantId` carries the
  /// foreign-key-only global unique index.
  static List<DstViolation> uniqueClosure(DstSnapshot snapshot) {
    final violations = <DstViolation>[];

    final namesByScope = <String, UuidValue>{};
    final uniqueRows = snapshot.visible[DstTable.unique.tableName] ?? const {};
    for (final entry in uniqueRows.entries) {
      final key = '${entry.value.scopeUuid}|${entry.value.columns['name']}';
      final existing = namesByScope[key];
      if (existing != null) {
        violations.add((
          property: 'uniqueClosure',
          detail: 'unique.name "$key" held by both $existing and ${entry.key}',
        ));
        continue;
      }
      namesByScope[key] = entry.key;
    }

    final inhabitants = <UuidValue, UuidValue>{};
    final addresses = snapshot.visible[DstTable.address.tableName] ?? const {};
    for (final entry in addresses.entries) {
      final value = _foreignKeyValue(entry.value.columns, 'inhabitantId');
      if (value == null) continue;
      final existing = inhabitants[value];
      if (existing != null) {
        violations.add((
          property: 'uniqueClosure',
          detail:
              'address.inhabitantId $value held by both $existing and '
              '${entry.key}',
        ));
        continue;
      }
      inhabitants[value] = entry.key;
    }

    return violations;
  }

  /// Replicas holding a scope agree about it, whatever else they hold.
  ///
  /// This is the keystone of the cross-scope design. If a replica subscribed to
  /// `{A, B}` derives a different visible state for `A` than a replica
  /// subscribed to `{A}`, then visibility became a function of the observer's
  /// subscription set and the merge is no longer a deterministic function of
  /// the facts.
  static List<DstViolation> observerIndependence(
    Map<DstReplica, DstSnapshot> snapshots,
    UuidValue scopeUuid,
  ) {
    final holders = [
      for (final entry in snapshots.entries)
        if (entry.key.scopeUuids.contains(scopeUuid)) entry,
    ];
    if (holders.length < 2) return const [];

    final reference = holders.first;
    final expected = reference.value.renderScope(scopeUuid);
    final violations = <DstViolation>[];
    for (final holder in holders.skip(1)) {
      final actual = holder.value.renderScope(scopeUuid);
      if (actual == expected) continue;
      violations.add((
        property: 'observerIndependence',
        detail:
            'scope $scopeUuid differs between ${reference.key} (scopes '
            '${reference.key.scopeUuids.length}) and ${holder.key} (scopes '
            '${holder.key.scopeUuids.length})\n'
            '--- ${reference.key} ---\n$expected'
            '--- ${holder.key} ---\n$actual',
      ));
    }
    return violations;
  }

  /// Every foreign-key projection agrees with the facts it is derived from.
  ///
  /// The other properties compare replicas against each other, so they only
  /// fail once two replicas have diverged. This one checks a single replica
  /// against itself: the projection is a deterministic function of the merged
  /// facts, so a record that disagrees with those facts is already wrong,
  /// whatever the peers hold. That makes a stale or missing repair fail at the
  /// merge that caused it rather than at some later comparison.
  ///
  /// The rules are the ones stated in `docs/foreign-key-invariants.md`
  /// ("Projection Metadata" and "Merge-Time Action Semantics"). Note they are
  /// not conditioned on the child being visible: the fixed point covers the
  /// affected closure, and a hidden row's reference still has to be repaired,
  /// or replicas that hid it by different routes disagree about its columns.
  ///
  /// On a column that also carries a unique index, one state is unreadable and
  /// only that state is skipped. Unique-conflict resolution releases such a
  /// column by writing null straight into the domain row without recording an
  /// override, so `domain null / attempted X / no override` is byte-identical
  /// to a foreign-key repair that never ran. Every other state of that column
  /// is still checked, so the column does not fall out of coverage wholesale.
  ///
  /// That ambiguity is the same gap behind the unique-release defects: the
  /// resolver overwrites the authored value instead of shadowing it, so nothing
  /// is left to derive from. Giving unique columns the attempted/visible split
  /// that foreign keys already have would make even that state checkable.
  static List<DstViolation> projectionPurity(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    final edgesByColumn = {
      for (final edge in dstForeignKeys)
        '${edge.child.tableName}.${edge.column}': edge,
    };

    for (final projection in snapshot.projections) {
      final edge = edgesByColumn['${projection.tableName}.${projection.columnName}'];
      if (edge == null) continue;

      final child = snapshot.rows[projection.tableName]?[projection.rowId];
      if (child == null) continue;

      // The one unreadable state; see the class docs.
      if (edge.uniqueIndexed &&
          projection.overrideReason == null &&
          _foreignKeyValue(child.columns, projection.columnName) == null) {
        continue;
      }

      final where =
          '${projection.tableName}/${projection.rowId}.${projection.columnName}';
      final reason = projection.overrideReason;
      final domainValue = _foreignKeyValue(child.columns, projection.columnName);
      final attempted = projection.attemptedValue;
      final parent = attempted == null
          ? null
          : snapshot.rows[edge.parent.tableName]?[attempted];
      final parentAvailable =
          parent != null && parent.visible && parent.scopeUuid == child.scopeUuid;

      // The domain row carries attemptedValue when no override is active, and
      // visibleValue when one is.
      final expected = reason == null ? attempted : projection.visibleValue;
      if (domainValue != expected) {
        violations.add((
          property: 'projectionPurity',
          detail:
              '$where holds $domainValue but its projection says $expected '
              '(reason: ${reason?.name ?? 'none'})',
        ));
      }

      if (reason == CrdtForeignKeyOverrideReason.setNull &&
          projection.visibleValue != null) {
        violations.add((
          property: 'projectionPurity',
          detail:
              '$where is set-null but its visible value is '
              '${projection.visibleValue}',
        ));
      }

      // An override exists only because the target is hidden or missing, so a
      // live target means the override should have been recomputed away.
      if (reason != null && parentAvailable) {
        violations.add((
          property: 'projectionPurity',
          detail:
              '$where keeps a ${reason.name} override while its target '
              '$attempted is visible in the same scope',
        ));
      }

      // The mirror image: with no override the target must be available, or
      // the edge must have repaired the row some other way. Which of those
      // applies depends on the action, because only the value-rewriting
      // actions record an override at all:
      //
      // - set null / set default rewrite the column, so a dead target without
      //   an override means the repair never ran;
      // - cascade hides the child instead of touching the column, so no
      //   override is expected - but the child must actually be hidden;
      // - restrict makes the parent delete lose, so the target should still
      //   be visible.
      if (reason == null && attempted != null && !parentAvailable) {
        final state = parent == null
            ? 'missing'
            : parent.visible
            ? 'owned by another scope'
            : 'hidden';
        final unrepaired = switch (edge.action) {
          'cascade' => child.visible,
          _ => true,
        };
        if (unrepaired) {
          violations.add((
            property: 'projectionPurity',
            detail:
                '$where has no override on a ${edge.action} edge but its '
                'target $attempted is $state'
                '${edge.action == 'cascade' ? ' and the row is still visible' : ''}',
          ));
        }
      }

      if (reason == CrdtForeignKeyOverrideReason.missingParent && child.visible) {
        violations.add((
          property: 'projectionPurity',
          detail: '$where is unrepairable but the row is still visible',
        ));
      }
    }

    return violations;
  }

  /// The structural invariants that must hold after every merge.
  static List<DstViolation> invariants(DstSnapshot snapshot) => [
    ...noCrossScopeLink(snapshot),
    ...foreignKeyClosure(snapshot),
    ...uniqueClosure(snapshot),
    ...projectionPurity(snapshot),
  ];
}
