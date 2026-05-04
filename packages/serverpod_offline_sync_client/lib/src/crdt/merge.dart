import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

/// Merge metadata extracted from a [CrdtMergeSet].
typedef CrdtMergeMetadataLookup = ({
  Map<String, Set<UuidValue>> rowIdsByTable,
  Map<String, Set<String>> columnNamesByTable,
});

/// CRDT merge helpers built on top of the generated Serverpod models.
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// All merge changes in this set.
  Iterable<CrdtMergeChange> get changes sync* {
    yield* inserts;
    yield* updates;
    yield* deletes;
  }

  /// All merge changes in this set sorted by causal order.
  List<CrdtMergeChange> get causallyOrderedChanges {
    final operations = changes.toList()
      ..sort((left, right) => left.hlc.compareTo(right.hlc));
    return operations;
  }

  /// Collects the row and column metadata needed to load merge state.
  CrdtMergeMetadataLookup collectMetadataLookup({
    required bool Function(String tableName) isTrackedTable,
  }) {
    final rowIdsByTable = <String, Set<UuidValue>>{};
    final columnNamesByTable = <String, Set<String>>{};

    for (final insert in inserts) {
      if (!isTrackedTable(insert.tableName)) continue;
      rowIdsByTable.putIfAbsent(insert.tableName, () => {}).add(insert.uuidRowId);
      columnNamesByTable
          .putIfAbsent(insert.tableName, () => {})
          .addAll(insert.trackedColumnNames);
    }

    for (final update in updates) {
      if (!isTrackedTable(update.tableName)) continue;
      rowIdsByTable.putIfAbsent(update.tableName, () => {}).add(update.uuidRowId);
      columnNamesByTable.putIfAbsent(update.tableName, () => {}).add(update.columnName);
    }

    for (final delete in deletes) {
      if (!isTrackedTable(delete.tableName)) continue;
      rowIdsByTable.putIfAbsent(delete.tableName, () => {}).add(delete.uuidRowId);
    }

    return (
      rowIdsByTable: rowIdsByTable,
      columnNamesByTable: columnNamesByTable,
    );
  }
}

/// Convenience helpers shared by every merge change.
extension CrdtMergeChangeExtension on CrdtMergeChange {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, uuidNodeId);
}

/// Convenience helpers for insert changes.
extension CrdtMergeInsertExtension on CrdtMergeInsert {
  /// The database column payload represented by this change.
  Map<String, Object?> get databaseColumns {
    final payload = switch (data) {
      final TableRow row => row.toJsonForDatabase(),
      final Map<String, dynamic> map => map,
      _ => throw StateError(
        'Unsupported merge insert payload type for $tableName: '
        '${data.runtimeType}. Expected TableRow or Map<String, dynamic>.',
      ),
    };

    return Map<String, Object?>.from(payload as Map<String, dynamic>);
  }

  /// The merge payload column names excluding the primary key.
  Iterable<String> get trackedColumnNames =>
      databaseColumns.keys.where((columnName) => columnName != 'id');
}
