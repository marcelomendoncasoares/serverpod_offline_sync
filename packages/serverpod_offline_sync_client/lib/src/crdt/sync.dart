import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_database/serverpod_database.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

/// Typed view over any merge change entry in a [CrdtMergeSet].
typedef CrdtMergeChange = ({
  String tableName,
  UuidValue uuidRowId,
  UuidValue nodeId,
  Hlc hlc,
  CrdtMergeInsert? insert,
  CrdtMergeUpdate? update,
  CrdtMergeDelete? delete,
});

/// CRDT merge helpers built on top of the generated Serverpod models.
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// All merge changes in this set.
  Iterable<CrdtMergeChange> get changes sync* {
    for (final insert in inserts) {
      yield (
        tableName: insert.tableName,
        uuidRowId: insert.uuidRowId,
        nodeId: insert.nodeId,
        hlc: insert.hlc,
        insert: insert,
        update: null,
        delete: null,
      );
    }
    for (final update in updates) {
      yield (
        tableName: update.tableName,
        uuidRowId: update.uuidRowId,
        nodeId: update.nodeId,
        hlc: update.hlc,
        insert: null,
        update: update,
        delete: null,
      );
    }
    for (final delete in deletes) {
      yield (
        tableName: delete.tableName,
        uuidRowId: delete.uuidRowId,
        nodeId: delete.nodeId,
        hlc: delete.hlc,
        insert: null,
        update: null,
        delete: delete,
      );
    }
  }
}

/// Convenience helpers for insert changes.
extension CrdtMergeInsertExtension on CrdtMergeInsert {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);

  /// The database column payload represented by this change.
  Map<String, Object?> get databaseColumns => switch (data) {
    TableRow() => Map<String, Object?>.from(
      (data as TableRow).toJsonForDatabase() as Map<String, dynamic>,
    ),
    Map() => Map<String, Object?>.from(data as Map),
    _ => throw StateError(
      'Unsupported merge insert payload type for $tableName: ${data.runtimeType}.',
    ),
  };

  /// The merge payload column names excluding the primary key.
  Iterable<String> get trackedColumnNames =>
      databaseColumns.keys.where((columnName) => columnName != 'id');
}

/// Convenience helpers for update changes.
extension CrdtMergeUpdateExtension on CrdtMergeUpdate {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);

  /// The decoded value represented by this change.
  Object? get value => data;
}

/// Convenience helpers for delete changes.
extension CrdtMergeDeleteExtension on CrdtMergeDelete {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// Merge metadata extracted from a [CrdtMergeSet].
typedef CrdtMergeMetadataLookup = ({
  Map<String, Set<UuidValue>> rowIdsByTable,
  Map<String, Set<String>> columnNamesByTable,
});

/// Helpers for collecting merge metadata from a [CrdtMergeSet].
extension CrdtMergeLookupExtension on CrdtMergeSet {
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
