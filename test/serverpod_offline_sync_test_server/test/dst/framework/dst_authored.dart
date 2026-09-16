import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';
import 'package:serverpod_offline_sync_test_client/serverpod_offline_sync_test_client.dart';

import 'dst_schema.dart';
import 'dst_snapshot.dart';

/// Inputs retained before an ORM call, independently of collection/projection.
/// Full-row passthrough preserves an existing attempted value when the supplied
/// column equals its materialized value; explicit column writes author it.
class DstWriteEvidence {
  DstWriteEvidence(this.before);

  final DstSnapshot before;
  final Map<DstFieldKey, Object?> values = {};
  final Map<DstFieldKey, Hlc?> preservedClocks = {};
  final Map<String, bool> _visibilityChanges = {};

  void visibility(String table, Iterable<UuidValue> ids, {required bool deleted}) {
    for (final id in ids) {
      _visibilityChanges['$table/$id'] = deleted;
    }
  }

  void write(
    String table,
    Map<String, dynamic> data, {
    Set<String>? columns,
    bool insertDefaults = false,
  }) {
    final id = UuidValue.withValidation(data['id'] as String);
    final definition = DstTable.values.singleWhere((value) => value.tableName == table);
    for (final column in definition.definition.columns.map((value) => value.name)) {
      if (column == 'id' || column == 'spaceId' || column == '__className__') continue;
      if (columns != null && !columns.contains(column)) continue;
      final key = (table, id, column);
      final passthrough =
          columns == null &&
          before.projections.containsKey(key) &&
          dstValue(data[column]) == dstValue(before.rows[table]?[id]?.columns[column]);
      final defaults = dstForeignKeys.where(
        (edge) => edge.child.tableName == table && edge.column == column,
      );
      final supplied = insertDefaults && data[column] == null && defaults.isNotEmpty
          ? defaults.single.defaultValue
          : data[column];
      values[key] = passthrough ? before.authoredValue(key) : supplied;
      if (passthrough) preservedClocks[key] = before.fieldHlc(key);
    }
  }

  List<DstViolation> validate(DstSnapshot after) => [
    for (final entry in _visibilityChanges.entries)
      if (after.tombstones[entry.key] == null ||
          after.tombstones[entry.key]!.clFlag <=
              (before.tombstones[entry.key]?.clFlag ?? 1) ||
          after.tombstones[entry.key]!.clFlag.isEven != entry.value ||
          after.tombstones[entry.key]!.hlc <=
              (before.tombstones[entry.key]?.hlc ?? before.rowHlcs[entry.key]!))
        (
          property: 'acceptedVisibility',
          detail:
              '${entry.key} accepted '
              '${entry.value ? 'delete' : 'restore'} without advancing its authored tombstone',
        ),
    for (final entry in values.entries)
      if (after.fieldHlc(entry.key) == null ||
          dstValue(after.authoredValue(entry.key)) != dstValue(entry.value))
        (
          property: 'acceptedWrite',
          detail:
              '${entry.key} accepted ${dstValue(entry.value)} '
              'but retained ${dstValue(after.authoredValue(entry.key))} at ${after.fieldHlc(entry.key)}',
        ),
    for (final entry in preservedClocks.entries)
      if (after.fieldHlc(entry.key) != entry.value)
        (
          property: 'acceptedWrite',
          detail:
              '${entry.key} advanced a projected passthrough '
              'clock from ${entry.value} to ${after.fieldHlc(entry.key)}',
        ),
  ];
}

/// Acknowledged facts captured immediately after accepted local transactions.
/// Callers first validate the concrete authored payload with [DstWriteEvidence].
/// Retention compares LWW fields against this separate history at quiescence;
/// it does not infer author intent from a later export of possibly damaged data.
/// Local FK actions also author child fields/tombstones, so those are retained
/// here. Their exact action semantics are covered by real DB scenarios, not a
/// duplicate general FK/unique planner in this oracle.
class DstAuthoredOracle {
  final Map<DstFieldKey, ({UuidValue space, Hlc hlc, Object? value})> _fields = {};
  final Map<String, ({UuidValue space, Hlc hlc})> _rows = {};
  final Map<String, ({UuidValue space, DstTombstone tombstone})> _tombstones = {};

  void accept(DstSnapshot snapshot, {DstSnapshot? before}) {
    for (final table in snapshot.rows.entries) {
      for (final row in table.value.entries) {
        final rowKey = '${table.key}/${row.key}';
        final rowHlc = snapshot.rowHlcs[rowKey];
        if (rowHlc == null) continue;
        final oldRow = _rows[rowKey];
        if (before?.rowHlcs[rowKey] != rowHlc &&
            (oldRow == null || rowHlc > oldRow.hlc)) {
          _rows[rowKey] = (space: row.value.spaceUuid, hlc: rowHlc);
        }
        for (final column in row.value.columns.keys) {
          if (column == 'id' || column == '__className__') continue;
          final key = (table.key, row.key, column);
          final hlc = snapshot.fieldHlc(key)!;
          final old = _fields[key];
          if (before?.fieldHlc(key) != hlc && (old == null || hlc > old.hlc)) {
            _fields[key] = (
              space: row.value.spaceUuid,
              hlc: hlc,
              value: snapshot.authoredValue(key),
            );
          }
        }
        final tombstone = snapshot.canonicalTombstone(table.key, row.key);
        if (tombstone == null ||
            !tombstone.reason.isSynced ||
            before?.tombstones[rowKey] == tombstone) {
          continue;
        }
        final old = _tombstones[rowKey]?.tombstone;
        if (old == null ||
            tombstone.clFlag > old.clFlag ||
            (tombstone.clFlag == old.clFlag && tombstone.hlc > old.hlc)) {
          _tombstones[rowKey] = (space: row.value.spaceUuid, tombstone: tombstone);
        }
      }
    }
  }

  List<DstViolation> validate(DstSnapshot snapshot, UuidValue space) => [
    for (final table in snapshot.rows.entries)
      for (final row in table.value.entries)
        if (_rows['${table.key}/${row.key}'] case final accepted?) ...[
          if (accepted.space == space && row.value.spaceUuid != space)
            (
              property: 'authoredRetention',
              detail: '${table.key}/${row.key} changed its accepted space',
            ),
          if (accepted.space == space &&
              snapshot.canonicalTombstone(table.key, row.key) !=
                  _tombstones['${table.key}/${row.key}']?.tombstone)
            (
              property: 'authoredRetention',
              detail:
                  '${table.key}/${row.key} changed its accepted visibility facts: '
                  'expected ${_tombstones['${table.key}/${row.key}']?.tombstone}, '
                  'found ${snapshot.canonicalTombstone(table.key, row.key)}',
            ),
        ],
    for (final entry in _rows.entries)
      if (entry.value.space == space &&
          (!snapshot.rowHlcs.containsKey(entry.key) ||
              snapshot.rowSpaces[entry.key] != space))
        (
          property: 'authoredRetention',
          detail: '${entry.key} lost its accepted row identity',
        ),
    for (final entry in _fields.entries)
      if (entry.value.space == space &&
          (snapshot.fieldHlc(entry.key) != entry.value.hlc ||
              dstValue(snapshot.authoredValue(entry.key)) !=
                  dstValue(entry.value.value)))
        (
          property: 'authoredRetention',
          detail:
              '${entry.key} expected '
              '${dstValue(entry.value.value)} at ${entry.value.hlc}, found '
              '${dstValue(snapshot.authoredValue(entry.key))} at ${snapshot.fieldHlc(entry.key)}',
        ),
  ];
}
