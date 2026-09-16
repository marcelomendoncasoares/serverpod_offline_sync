import 'package:serverpod_offline_sync_server/serverpod_offline_sync_server.dart';

import 'dst_snapshot.dart';
import 'dst_world.dart';

/// Distinct observed authored transitions and graph shapes, not counts of
/// repeated snapshot appearances. Keys include field/tombstone HLCs so duplicate
/// delivery cannot inflate semantic coverage.
class DstCoverage {
  final Map<String, Set<String>> _events = {};
  final Set<String> tables = {};
  final Set<String> foreignKeys = {};
  final Set<String> uniqueProjectionColumns = {};
  int maxRows = 0;

  void event(String kind, String identity) =>
      _events.putIfAbsent(kind, () => {}).add(identity);

  Map<String, int> get transitions => {
    for (final entry in _events.entries) entry.key: entry.value.length,
  };

  void observe(DstSnapshot after, {DstSnapshot? before}) {
    final rowCount = after.rows.values.fold(0, (sum, rows) => sum + rows.length);
    if (rowCount > maxRows) maxRows = rowCount;
    for (final table in after.rows.entries) {
      if (table.value.isNotEmpty) tables.add(table.key);
      for (final row in table.value.entries) {
        final key = '${table.key}/${row.key}';
        final tombstone = after.tombstones[key];
        if (tombstone == null) continue;
        if (tombstone.clFlag.isOdd && tombstone.clFlag >= 3) {
          event('restore', '$key/${tombstone.hlc}');
        }
        if (tombstone.clFlag.isEven && tombstone.clFlag >= 4) {
          event('redelete', '$key/${tombstone.hlc}');
        }
      }
    }
    for (final edge in dstForeignKeys) {
      for (final row in (after.rows[edge.child.tableName] ?? {}).entries) {
        final key = (edge.child.tableName, row.key, edge.column);
        final value = after.authoredValue(key);
        if (value != null) foreignKeys.add('${edge.child.tableName}.${edge.column}');
        if (before?.rows[edge.child.tableName]?.containsKey(row.key) != true) continue;
        final previous = before!.authoredValue(key);
        if (dstValue(previous) == dstValue(value)) continue;
        final identity = '$key/${after.fieldHlc(key)}';
        if (previous != null && value == null) event('fkDetach', identity);
        if (previous != null && value != null) event('fkRetarget', identity);
      }
    }
    for (final projection in after.projections.entries) {
      event(
        projection.value.projectionReason.name,
        '${projection.key}/${after.fieldHlc(projection.key)}/${dstValue(projection.value.attemptedValue)}',
      );
      if (projection.value.projectionReason == CrdtProjectionReason.uniqueConflict) {
        uniqueProjectionColumns.add('${projection.key.$1}.${projection.key.$3}');
      }
    }
    // The declared person -> company -> town -> mayor cycle, using authored
    // references so a derived unique release cannot erase the graph evidence.
    for (final person in (after.rows['person'] ?? {}).entries) {
      final companyId = after.authoredValue(('person', person.key, 'oldCompanyId'));
      if (companyId == null) continue;
      final company = after.rows['company']?.entries
          .where((row) => row.key.toString() == companyId.toString())
          .firstOrNull;
      if (company == null) continue;
      final townId = after.authoredValue(('company', company.key, 'townId'));
      final town = after.rows['town']?.entries
          .where((row) => row.key.toString() == townId.toString())
          .firstOrNull;
      if (town == null) continue;
      if (after.authoredValue(('town', town.key, 'mayorId')).toString() ==
          person.key.toString()) {
        event('authoredCycle', '${person.key}/${company.key}/${town.key}');
      }
    }
  }

  void observeSwap(
    DstTable table,
    DstSnapshot before,
    DstSnapshot after,
    Set<DstFieldKey> written,
  ) {
    final ids = written.map((key) => key.$2).toSet().toList();
    if (ids.length != 2) return;
    for (final index in dstUniqueIndexes.where((index) => index.table == table)) {
      final columns = index.columns.where((column) => column != 'spaceId');
      if (!columns.every(
        (column) =>
            written.contains((table.tableName, ids[0], column)) &&
            written.contains((table.tableName, ids[1], column)),
      )) {
        continue;
      }
      final left = before.rows[table.tableName]![ids[0]]!.columns;
      final right = before.rows[table.tableName]![ids[1]]!.columns;
      if (columns.every(
        (column) => dstValue(left[column]) == dstValue(right[column]),
      )) {
        continue;
      }
      if (!columns.every(
        (column) =>
            dstValue(after.authoredValue((table.tableName, ids[0], column))) ==
                dstValue(right[column]) &&
            dstValue(after.authoredValue((table.tableName, ids[1], column))) ==
                dstValue(left[column]),
      )) {
        continue;
      }
      event(
        'uniqueSwap',
        '${table.tableName}/${ids.join('/')}/${columns.map((column) => after.fieldHlc((table.tableName, ids[0], column))).join('/')}',
      );
    }
  }

  Map<String, Object> toJson() => {
    'maxRowsPerReplica': maxRows,
    'tables': tables.toList()..sort(),
    'authoredForeignKeys': foreignKeys.toList()..sort(),
    'uniqueProjectionColumns': uniqueProjectionColumns.toList()..sort(),
    'transitions': transitions,
  };
}
