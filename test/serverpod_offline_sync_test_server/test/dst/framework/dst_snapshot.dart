import 'dart:convert';

// Imported with `show` because the barrel below re-exports overlapping names.
import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'dst_world.dart';

/// One row as the simulation compares it.
///
/// `visible` is carried rather than filtered out because "hidden here, visible
/// there" is a different defect from "missing here", and a diff that cannot
/// tell them apart is much harder to act on.
typedef DstRow = ({
  UuidValue spaceUuid,
  Map<String, Object?> columns,
  bool visible,
});

/// One field of one row, as the projection records name it.
typedef DstFieldKey = (String tableName, UuidValue rowId, String columnName);

/// The authored value a field kept while its domain column shows another.
///
/// The record is sparse by design: the engine writes it only while the
/// materialized domain value differs from the authored one, and deletes it
/// again the moment the two agree. So its absence is a claim in its own right -
/// that the domain column *is* what the user wrote - and both halves are what
/// [DstOracle.projectionPurity] checks.
///
/// `projectionReason` names the terminal projector that chose the domain value.
/// Being diagnostic is what makes it usable here: the engine never reads it
/// back, so it is an independent statement of what the engine believed it was
/// doing, rather than the input to the behaviour under test.
typedef DstProjection = ({
  Object? attemptedValue,
  CrdtProjectionReason projectionReason,
});

/// One replica's whole visible database, plus what it is hiding.
///
/// Rows are keyed by `(table, rowId)` - the global identity the engine
/// guarantees - and carry their owning space as a UUID rather than the local
/// normalized integer, which differs between replicas for the same space.
class DstSnapshot {
  /// Creates a snapshot. Prefer [capture].
  DstSnapshot({
    required this.rows,
    required this.projections,
    required this.causalLengths,
  });

  /// Captures [replica]'s current state through the ordinary read path.
  ///
  /// Reads are unscoped, which is the package's admin read: no space isolation
  /// filter, and a row is visible while its owning space sees it. That is the
  /// view the properties need, because the question is what each replica
  /// believes about every space it holds.
  static Future<DstSnapshot> capture(DstReplica replica) async {
    final session = replica.session;
    final spaces = await OfflineSyncSpace.db.find(session);
    final spaceUuidById = {
      for (final space in spaces) space.id!: space.uuidSpaceId,
    };

    final rows = <String, Map<UuidValue, DstRow>>{};

    for (final table in DstTable.values) {
      final allRows = await _find(session, table, includeHidden: true);
      final visibleRows = await _find(session, table, includeHidden: false);
      final visibleIds = {for (final row in visibleRows) row.id!};

      rows[table.tableName] = {
        for (final row in allRows)
          row.id!: (
            spaceUuid: spaceUuidById[_spaceIdOf(row)]!,
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

  /// The authored value of every field whose domain column differs from it.
  ///
  /// Sparse: a field with no entry here holds its authored value. See
  /// [DstProjection].
  final Map<DstFieldKey, DstProjection> projections;

  /// Causal-length flag per row, keyed `table/rowId`.
  ///
  /// The flag counts visibility generations: odd is visible, even is deleted.
  /// It is the mechanism behind the claim that add, delete and restore can
  /// only advance and never oscillate.
  final Map<String, int> causalLengths;

  static Future<Map<String, int>> _captureCausalLengths(
    OfflineSyncDatabaseSession session,
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

  static Future<Map<DstFieldKey, DstProjection>> _captureProjections(
    OfflineSyncDatabaseSession session,
  ) async {
    final records = await CrdtDataAttemptedValue.db.find(
      session,
      include: CrdtDataAttemptedValue.include(
        field: CrdtDataField.include(
          row: CrdtDataRow.include(tbl: CrdtSchemaTable.include()),
          column: CrdtSchemaColumn.include(),
        ),
      ),
    );

    return {
      for (final record in records)
        if (record.field?.row?.tbl?.name case final tableName?)
          if (record.field?.column?.name case final columnName?)
            (tableName, record.field!.row!.uuidRowId, columnName): (
              attemptedValue: record.value,
              projectionReason: record.projectionReason,
            ),
    };
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

  /// This snapshot restricted to the rows owned by [spaceUuid].
  ///
  /// This is the unit the observer-independence property compares: two replicas
  /// holding different sets of spaces must still agree exactly here.
  Map<String, Map<UuidValue, DstRow>> forSpace(UuidValue spaceUuid) {
    return {
      for (final entry in rows.entries)
        entry.key: {
          for (final row in entry.value.entries)
            if (row.value.spaceUuid == spaceUuid) row.key: row.value,
        },
    };
  }

  /// A stable, human-readable rendering of [forSpace], for equality and diffs.
  ///
  /// Hidden rows are rendered too, marked `HIDDEN`, so a diff distinguishes a
  /// row that merged but is hidden from one that never arrived.
  String renderSpace(UuidValue spaceUuid) {
    final buffer = StringBuffer();
    final byTable = forSpace(spaceUuid);
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

  /// How many rows are visible, across every table and space.
  int get visibleRowCount => _countRows(visible: true);

  /// How many rows are present but hidden, across every table and space.
  int get hiddenRowCount => _countRows(visible: false);

  int _countRows({required bool visible}) => rows.values.fold(
    0,
    (sum, tableRows) =>
        sum + tableRows.values.where((row) => row.visible == visible).length,
  );

  /// Looks up a visible row in any space.
  DstRow? lookupVisible(DstTable table, UuidValue rowId) {
    final row = rows[table.tableName]?[rowId];
    return row != null && row.visible ? row : null;
  }

  /// Columns compared across replicas.
  ///
  /// `spaceId` is dropped because it is a replica-local normalized integer; the
  /// owning space travels as a UUID on [DstRow] instead. Relation objects are
  /// dropped because they are never populated without an explicit `include`.
  static Map<String, Object?> _comparableColumns(TableRow<UuidValue?> row) {
    final json = row.toJson() as Map<String, dynamic>;
    return {
      for (final entry in json.entries)
        if (entry.key != 'spaceId' && entry.value is! Map) entry.key: entry.value,
    };
  }

  static int _spaceIdOf(TableRow<UuidValue?> row) {
    final json = row.toJson() as Map<String, dynamic>;
    final spaceId = json['spaceId'] as int?;
    if (spaceId != null) return spaceId;
    throw StateError(
      'Row ${row.table.tableName}/${row.id} has a null spaceId. Rows created '
      'behind the sync layer are invisible to space-scoped reads and cannot be '
      'compared across replicas.',
    );
  }

  static Future<List<TableRow<UuidValue?>>> _find(
    OfflineSyncDatabaseSession session,
    DstTable table, {
    required bool includeHidden,
  }) async {
    return table.model.find(session, includeHidden: includeHidden);
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
UuidValue? _foreignKeyValue(Map<String, Object?> columns, String column) =>
    _reference(columns[column]);

/// Parses a stored reference back into the row id it names.
///
/// Snapshot columns come from `TableRow.toJson()`, which renders a `UuidValue`
/// as its string form, while an attempted value decodes back to a `UuidValue`.
/// Both have to reach the same type before either can be matched against a row
/// id or compared with the other.
UuidValue? _reference(Object? value) {
  if (value == null) return null;
  return value is UuidValue ? value : UuidValue.withValidation(value as String);
}

/// The properties every simulation state must satisfy.
///
/// Structural invariants ([foreignKeyClosure], [uniqueClosure],
/// [noCrossSpaceLink]) hold after *every* merge. Agreement properties
/// ([observerIndependence]) hold once the adversary has quiesced, since before
/// that replicas legitimately hold different facts.
class DstOracle {
  /// No visible row links to a row owned by a different space.
  ///
  /// This is the invariant the cross-space design rests on: a foreign key may
  /// only target a row of its own space, so a merged reference into another
  /// space must be repaired (set null / set default) or the child hidden -
  /// never linked. See `docs/row-ownership.md` "Foreign keys stay within a
  /// space".
  static List<DstViolation> noCrossSpaceLink(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    for (final edge in dstForeignKeys) {
      final children = snapshot.visible[edge.child.tableName] ?? const {};
      for (final entry in children.entries) {
        final parentId = _foreignKeyValue(entry.value.columns, edge.column);
        if (parentId == null) continue;
        final parent = snapshot.lookupVisible(edge.parent, parentId);
        if (parent == null) continue;
        if (parent.spaceUuid == entry.value.spaceUuid) continue;
        violations.add((
          property: 'noCrossSpaceLink',
          detail:
              '${edge.child.tableName}/${entry.key} in space '
              '${entry.value.spaceUuid} links ${edge.column}=$parentId owned by '
              'space ${parent.spaceUuid}',
        ));
      }
    }
    return violations;
  }

  /// Every visible foreign key resolves to a visible parent in the same space.
  static List<DstViolation> foreignKeyClosure(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    for (final edge in dstForeignKeys) {
      final children = snapshot.visible[edge.child.tableName] ?? const {};
      for (final entry in children.entries) {
        final parentId = _foreignKeyValue(entry.value.columns, edge.column);
        if (parentId == null) continue;
        final parent = snapshot.lookupVisible(edge.parent, parentId);
        if (parent != null && parent.spaceUuid == entry.value.spaceUuid) {
          continue;
        }
        violations.add((
          property: 'foreignKeyClosure',
          detail:
              'visible ${edge.child.tableName}/${entry.key} references '
              '${edge.parent.tableName}/$parentId which is '
              '${parent == null ? 'missing' : 'owned by another space'} '
              '(${edge.action} edge)',
        ));
      }
    }
    return violations;
  }

  /// No visible unique tuple is claimed twice. NULL in any component releases
  /// a SQL unique tuple; space uses its portable UUID instead of local spaceId.
  static List<DstViolation> uniqueClosure(DstSnapshot snapshot) {
    final violations = <DstViolation>[];
    for (final index in dstUniqueIndexes) {
      final claims = <String, UuidValue>{};
      for (final entry
          in (snapshot.visible[index.table.tableName] ?? const {}).entries) {
        final values = [
          for (final column in index.columns)
            column == 'spaceId'
                ? entry.value.spaceUuid.toJson()
                : entry.value.columns[column],
        ];
        if (values.any((value) => value == null)) continue;
        final key = jsonEncode(values);
        final previous = claims[key];
        if (previous != null) {
          violations.add((
            property: 'uniqueClosure',
            detail:
                '${index.table.tableName}.${index.name} $key held by both $previous and ${entry.key}',
          ));
        } else {
          claims[key] = entry.key;
        }
      }
    }
    return violations;
  }

  /// Replicas holding a space agree about it, whatever else they hold.
  ///
  /// This is the keystone of the cross-space design. If a replica subscribed to
  /// `{A, B}` derives a different visible state for `A` than a replica
  /// subscribed to `{A}`, then visibility became a function of the observer's
  /// subscription set and the merge is no longer a deterministic function of
  /// the facts.
  static List<DstViolation> observerIndependence(
    Map<DstReplica, DstSnapshot> snapshots,
    UuidValue spaceUuid,
  ) {
    final holders = [
      for (final entry in snapshots.entries)
        if (entry.key.spaceUuids.contains(spaceUuid)) entry,
    ];
    if (holders.length < 2) return const [];

    final reference = holders.first;
    final expected = reference.value.renderSpace(spaceUuid);
    final violations = <DstViolation>[];
    for (final holder in holders.skip(1)) {
      final actual = holder.value.renderSpace(spaceUuid);
      if (actual == expected) continue;
      violations.add((
        property: 'observerIndependence',
        detail:
            'space $spaceUuid differs between ${reference.key} (spaces '
            '${reference.key.spaceUuids.length}) and ${holder.key} (spaces '
            '${holder.key.spaceUuids.length})\n'
            '--- ${reference.key} ---\n$expected'
            '--- ${holder.key} ---\n$actual',
      ));
    }
    return violations;
  }

  /// Every foreign-key column agrees with the facts it is derived from.
  ///
  /// The other properties compare replicas against each other, so they only
  /// fail once two replicas have diverged. This one checks a single replica
  /// against itself: the projection is a deterministic function of the merged
  /// facts, so a column that disagrees with those facts is already wrong,
  /// whatever the peers hold. That makes a stale or missing repair fail at the
  /// merge that caused it rather than at some later comparison.
  ///
  /// The population is every foreign-key column of every row, taken from
  /// [dstForeignKeys] and the domain rows rather than from the attempted-value
  /// records. Those records are sparse, so walking them would only ever reach
  /// rows the engine already believes it repaired - and "the repair never ran"
  /// is precisely the state that leaves nothing behind to walk. So both halves
  /// are checked: the field that kept an authored value, and the field that
  /// did not.
  ///
  /// The rules are not conditioned on the child being visible. The fixed point
  /// covers the affected closure, and a hidden row's reference still has to be
  /// repaired, or replicas that hid it by different routes disagree about its
  /// columns. The exception is the actions that repair by hiding or by blocking
  /// rather than by rewriting: a hidden child satisfies `cascade` and
  /// `noAction` on its own, because neither ever touches the column.
  /// A hidden set-default child may also retain its reference when no legal
  /// default exists: there is no repair to apply and no visible child to block
  /// the parent deletion. The referenced physical row must still exist.
  ///
  /// When a projection *is* recorded, the reason must be possible for that
  /// edge's `onDelete` action. A plausible domain value with the wrong reason
  /// is still a defect: the diagnostic is an independent statement of what the
  /// engine believed it was doing.
  ///
  /// The rules are the ones stated in `docs/foreign-key-invariants.md`
  /// ("Merge-Time Action Semantics") and `docs/projection-model.md`
  /// ("Storage ownership").
  static List<DstViolation> projectionPurity(DstSnapshot snapshot) => [
    for (final edge in dstForeignKeys)
      for (final row in (snapshot.rows[edge.child.tableName] ?? const {}).entries)
        ..._fieldPurity(snapshot, edge, row.key, row.value),
  ];

  /// Checks the single foreign-key field [edge] declares on [child].
  static List<DstViolation> _fieldPurity(
    DstSnapshot snapshot,
    DstForeignKey edge,
    UuidValue rowId,
    DstRow child,
  ) {
    final violations = <DstViolation>[];
    final where = '${edge.child.tableName}/$rowId.${edge.column}';
    final domainValue = _foreignKeyValue(child.columns, edge.column);
    final projection = snapshot.projections[(edge.child.tableName, rowId, edge.column)];

    if (projection == null) {
      // Nothing was preserved, so the domain column is the authored value and
      // the edge has to be satisfied by the reference exactly as it stands.
      if (domainValue == null) return violations;
      final target = snapshot.rows[edge.parent.tableName]?[domainValue];
      if (_available(target, child)) return violations;
      // A deleted child cannot block its parent. If its action has no legal
      // repair, retain the original physically valid reference as history.
      if (!child.visible &&
          target != null &&
          target.spaceUuid == child.spaceUuid &&
          !_canRepair(snapshot, edge, child)) {
        return violations;
      }
      violations.add((
        property: 'projectionPurity',
        detail:
            '$where still holds its authored $domainValue on a ${edge.action} '
            'edge whose target is ${_targetState(target)}, so the repair never '
            'ran',
      ));
      return violations;
    }

    final reason = projection.projectionReason;
    final attempted = _reference(projection.attemptedValue);
    final target = attempted == null
        ? null
        : snapshot.rows[edge.parent.tableName]?[attempted];

    if (!_reasonFitsEdge(reason, edge)) {
      violations.add((
        property: 'projectionPurity',
        detail:
            '$where has reason ${reason.name}, which is impossible on a '
            '${edge.action} edge',
      ));
    }

    if (domainValue == attempted) {
      violations.add((
        property: 'projectionPurity',
        detail:
            '$where holds $domainValue equal to the authored value it is '
            'preserving (reason: ${reason.name})',
      ));
    }

    if (reason == CrdtProjectionReason.foreignKeySetNull && domainValue != null) {
      violations.add((
        property: 'projectionPurity',
        detail: '$where is set-null but its domain value is $domainValue',
      ));
    }

    if (reason == CrdtProjectionReason.foreignKeySetDefault &&
        domainValue != edge.defaultValue) {
      violations.add((
        property: 'projectionPurity',
        detail:
            '$where is set-default but its domain value is $domainValue, '
            'not the column default ${edge.defaultValue}',
      ));
    }

    // A foreign-key override exists only because the target is hidden or
    // missing. Unique projection may still release a row whose target is fine.
    if (_isForeignKeyRepair(reason) && _available(target, child)) {
      violations.add((
        property: 'projectionPurity',
        detail:
            '$where keeps a ${reason.name} override while its target '
            '$attempted is visible in the same space',
      ));
    }

    if (reason == CrdtProjectionReason.foreignKeyMissingParent && child.visible) {
      violations.add((
        property: 'projectionPurity',
        detail: '$where is unrepairable but the row is still visible',
      ));
    }

    return violations;
  }

  static bool _canRepair(DstSnapshot snapshot, DstForeignKey edge, DstRow child) =>
      switch (edge.action) {
        'setNull' => edge.nullable,
        'setDefault' =>
          edge.defaultValue == null
              ? edge.nullable
              : _available(
                  snapshot.rows[edge.parent.tableName]?[edge.defaultValue],
                  child,
                ),
        _ => false,
      };

  /// Whether [child] may reference [target]: present, visible, and in the same
  /// space, since a foreign key may never cross a space boundary.
  static bool _available(DstRow? target, DstRow child) =>
      target != null && target.visible && target.spaceUuid == child.spaceUuid;

  /// Why [target] is not available, for a violation message.
  static String _targetState(DstRow? target) {
    if (target == null) return 'missing';
    return target.visible ? 'owned by another space' : 'hidden';
  }

  /// Whether [reason] names a foreign-key repair rather than a unique release.
  static bool _isForeignKeyRepair(CrdtProjectionReason reason) => switch (reason) {
    CrdtProjectionReason.foreignKeySetNull ||
    CrdtProjectionReason.foreignKeySetDefault ||
    CrdtProjectionReason.foreignKeyMissingParent => true,
    CrdtProjectionReason.uniqueConflict ||
    CrdtProjectionReason.hiddenUniqueRelease => false,
  };

  /// Whether [reason] can be the terminal projector on [edge].
  ///
  /// Value-rewriting reasons are tied to the matching `onDelete` action.
  /// `foreignKeyMissingParent` is the unrepairable fallback, so it is legal
  /// on cascade, no-action, and set-default (when the default target is
  /// unavailable). Unique reasons may only appear on a unique foreign-key
  /// column: unique projection can be the terminal stage even after an FK
  /// repair.
  static bool _reasonFitsEdge(CrdtProjectionReason reason, DstForeignKey edge) {
    return switch (reason) {
      CrdtProjectionReason.foreignKeySetNull =>
        edge.action == 'setNull' && edge.nullable,
      CrdtProjectionReason.foreignKeySetDefault => edge.action == 'setDefault',
      CrdtProjectionReason.foreignKeyMissingParent =>
        edge.action == 'cascade' ||
            edge.action == 'noAction' ||
            edge.action == 'setDefault' ||
            (edge.action == 'setNull' && !edge.nullable),
      CrdtProjectionReason.uniqueConflict ||
      CrdtProjectionReason.hiddenUniqueRelease => _isUniqueForeignKey(edge),
    };
  }

  /// Whether [edge] carries a unique index on the foreign-key column itself.
  static bool _isUniqueForeignKey(DstForeignKey edge) => dstUniqueIndexes.any(
    (index) => index.table == edge.child && index.columns.contains(edge.column),
  );

  /// The structural invariants that must hold after every merge.
  static List<DstViolation> invariants(DstSnapshot snapshot) => [
    ...noCrossSpaceLink(snapshot),
    ...foreignKeyClosure(snapshot),
    ...uniqueClosure(snapshot),
    ...projectionPurity(snapshot),
  ];
}
