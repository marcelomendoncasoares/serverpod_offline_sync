import 'dart:async';

import 'package:serverpod_database/serverpod_database.dart';
import 'package:uuid/uuid.dart';

/// Callback invoked after a merge materializes one or more unique conflicts.
///
/// The callback runs after the merge transaction has committed. Throwing from
/// the callback does not roll back or fail the merge.
typedef UniqueConflictCallback =
    FutureOr<void> Function(
      DatabaseSession session,
      UuidValue userId,
      List<UniqueConflictContext> conflicts,
    );

/// Context for a unique conflict that was materialized by rewriting the losing
/// row's visible unique value.
class UniqueConflictContext<T extends TableRow> {
  /// Creates a unique conflict context.
  const UniqueConflictContext({
    required this.row,
    required this.conflictingValues,
    required this.replacementValues,
    required this.existingRow,
  });

  /// The domain row that lost the unique collision and was rewritten.
  final T row;

  /// Columns in the unique index that collided.
  Set<String> get columns => conflictingValues.keys.toSet();

  /// Values [row] tried to claim.
  final Map<String, Object?> conflictingValues;

  /// Values written to keep [row] visible and constraint-safe.
  final Map<String, Object?> replacementValues;

  /// The row that kept the original unique value.
  final T existingRow;
}
