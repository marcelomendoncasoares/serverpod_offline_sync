/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// Why a domain column currently differs from its authored value.
///
/// Diagnostic-only derived state. Projection decisions never read this enum;
/// the planner recomputes from authored facts and schema, then rewrites the
/// reason with the final domain value. Because it is singular, it records the
/// terminal stage that selected that value.
enum CrdtProjectionReason implements _iss.SerializableModel {
  /// The attempted parent target is hidden or missing and FK projection set
  /// the column to null.
  foreignKeySetNull,

  /// The attempted parent target is hidden or missing and FK projection set
  /// the column to the default value.
  foreignKeySetDefault,

  /// The attempted parent target is hidden or missing and FK projection cannot
  /// repair the value, so the row is hidden while the attempt is preserved.
  foreignKeyMissingParent,

  /// A visible unique-index loser received a deterministic conflict-free value.
  uniqueConflict,

  /// A hidden row was released from a unique index so visible rows can claim it.
  hiddenUniqueRelease;

  static CrdtProjectionReason fromJson(int index) {
    switch (index) {
      case 0:
        return CrdtProjectionReason.foreignKeySetNull;
      case 1:
        return CrdtProjectionReason.foreignKeySetDefault;
      case 2:
        return CrdtProjectionReason.foreignKeyMissingParent;
      case 3:
        return CrdtProjectionReason.uniqueConflict;
      case 4:
        return CrdtProjectionReason.hiddenUniqueRelease;
      default:
        throw ArgumentError(
          'Value "$index" cannot be converted to "CrdtProjectionReason"',
        );
    }
  }

  @override
  int toJson() => index;

  @override
  String toString() => name;
}
