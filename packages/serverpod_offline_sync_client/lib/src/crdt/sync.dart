import 'package:meta/meta.dart';
import 'package:serverpod_client/serverpod_client.dart';
import 'package:serverpod_offline_sync_shared/serverpod_offline_sync_shared.dart';

/// A set of remote CRDT changes to merge into the local database.
@immutable
class CrdtMergeSet {
  /// Creates a [CrdtMergeSet].
  const CrdtMergeSet({
    this.inserts = const [],
    this.updates = const [],
    this.deletes = const [],
  });

  /// Remote row insertions.
  final List<CrdtMergeInsert> inserts;

  /// Remote field updates.
  final List<CrdtMergeUpdate> updates;

  /// Remote tombstone updates.
  final List<CrdtMergeDelete> deletes;

  /// Whether this merge set has no changes.
  bool get isEmpty => inserts.isEmpty && updates.isEmpty && deletes.isEmpty;

  /// All changes in this merge set.
  Iterable<CrdtMergeChange> get changes sync* {
    yield* inserts;
    yield* updates;
    yield* deletes;
  }
}

/// Base class for a remote CRDT change.
@immutable
sealed class CrdtMergeChange extends BaseHlc {
  /// Creates a [CrdtMergeChange].
  CrdtMergeChange({
    required super.hlcDatetime,
    required super.hlcCounter,
    required this.tableName,
    required this.rowId,
    required this.nodeId,
  });

  /// The table receiving the change.
  final String tableName;

  /// The domain row identifier receiving the change.
  final UuidValue rowId;

  /// The remote node that produced the change.
  final UuidValue nodeId;

  /// The HLC for this change.
  Hlc get hlc => Hlc(hlcDatetime, hlcCounter, nodeId);
}

/// A remote row insertion.
@immutable
final class CrdtMergeInsert extends CrdtMergeChange {
  /// Creates a [CrdtMergeInsert].
  CrdtMergeInsert({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.tableName,
    required super.rowId,
    required super.nodeId,
    required this.data,
  });

  /// Full row data keyed by database column name.
  final Map<String, Object?> data;
}

/// A remote field update.
@immutable
final class CrdtMergeUpdate extends CrdtMergeChange {
  /// Creates a [CrdtMergeUpdate].
  CrdtMergeUpdate({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.tableName,
    required super.rowId,
    required super.nodeId,
    required this.columnName,
    required this.value,
  });

  /// The updated database column name.
  final String columnName;

  /// The new value for the column.
  final Object? value;
}

/// A remote tombstone update.
@immutable
final class CrdtMergeDelete extends CrdtMergeChange {
  /// Creates a [CrdtMergeDelete].
  CrdtMergeDelete({
    required super.hlcDatetime,
    required super.hlcCounter,
    required super.tableName,
    required super.rowId,
    required super.nodeId,
    required this.isDeleted,
  });

  /// Whether the row is deleted or restored.
  final bool isDeleted;
}
