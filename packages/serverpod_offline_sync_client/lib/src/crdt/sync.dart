import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

import '../protocol/protocol.dart';

/// CRDT merge helpers built on top of the generated Serverpod models.
extension CrdtMergeSetExtension on CrdtMergeSet {
  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// All merge changes in this set.
  Iterable<Object> get changes sync* {
    yield* inserts;
    yield* updates;
    yield* deletes;
  }
}

/// Convenience helpers for insert changes.
extension CrdtMergeInsertExtension on CrdtMergeInsert {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// Convenience helpers for update changes.
extension CrdtMergeUpdateExtension on CrdtMergeUpdate {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// Convenience helpers for delete changes.
extension CrdtMergeDeleteExtension on CrdtMergeDelete {
  /// The HLC represented by this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// Convenience helpers shared by all merge changes.
extension CrdtMergeChangeExtension on Object {
  /// The affected table name.
  String get mergeTableName => switch (this) {
    CrdtMergeInsert(:final tableName) => tableName,
    CrdtMergeUpdate(:final tableName) => tableName,
    CrdtMergeDelete(:final tableName) => tableName,
    _ => throw StateError('Unsupported merge change type: $runtimeType'),
  };

  /// The affected row identifier.
  UuidValue get mergeRowId => switch (this) {
    CrdtMergeInsert(:final rowId) => rowId,
    CrdtMergeUpdate(:final rowId) => rowId,
    CrdtMergeDelete(:final rowId) => rowId,
    _ => throw StateError('Unsupported merge change type: $runtimeType'),
  };

  /// The originating node identifier.
  UuidValue get mergeNodeId => switch (this) {
    CrdtMergeInsert(:final nodeId) => nodeId,
    CrdtMergeUpdate(:final nodeId) => nodeId,
    CrdtMergeDelete(:final nodeId) => nodeId,
    _ => throw StateError('Unsupported merge change type: $runtimeType'),
  };

  /// The HLC represented by this change.
  Hlc get mergeHlc => switch (this) {
    CrdtMergeInsert() => (this as CrdtMergeInsert).hlc,
    CrdtMergeUpdate() => (this as CrdtMergeUpdate).hlc,
    CrdtMergeDelete() => (this as CrdtMergeDelete).hlc,
    _ => throw StateError('Unsupported merge change type: $runtimeType'),
  };
}
