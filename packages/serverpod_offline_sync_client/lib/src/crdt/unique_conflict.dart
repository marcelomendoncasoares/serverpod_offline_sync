import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

/// Callback invoked after a merge materializes one or more unique conflicts.
///
/// The callback runs after the merge transaction has committed. Throwing from
/// the callback does not roll back or fail the merge.
typedef CrdtUniqueConflictCallback =
    FutureOr<void> Function(
      DatabaseSession session,
      UuidValue userId,
      List<CrdtUniqueConflict> conflicts,
    );

/// A unique conflict that was materialized by rewriting the losing row's
/// visible unique value.
class CrdtUniqueConflict {
  /// Creates a unique conflict payload.
  const CrdtUniqueConflict({
    required this.tableName,
    required this.winningRowId,
    required this.losingRowId,
    required this.columnNames,
    required this.claimedValues,
    required this.releasedValues,
  });

  /// The table containing the conflicting rows.
  final String tableName;

  /// The row that kept the claimed unique value.
  final UuidValue winningRowId;

  /// The row whose visible unique value was rewritten.
  final UuidValue losingRowId;

  /// Unique-indexed columns that participated in the conflict.
  final List<String> columnNames;

  /// Values the losing row claimed before conflict release.
  final Map<String, Object?> claimedValues;

  /// Conflict-free values materialized for the losing row.
  final Map<String, Object?> releasedValues;
}
