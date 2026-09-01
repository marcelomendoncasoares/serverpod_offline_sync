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

/// Why a foreign key projection override is active.
enum CrdtForeignKeyOverrideReason implements _iss.SerializableModel {
  /// The attempted parent target is hidden or missing and the FK projection
  /// set the column to null.
  setNull,

  /// The attempted parent target is hidden or missing and the FK projection
  /// set the column to the default value.
  setDefault,

  /// The attempted parent target is hidden or missing and the FK projection
  /// cannot repair the value (restrict, no action, cascade, or the column is
  /// non-nullable), so the row is hidden by projection while the attempt is
  /// preserved.
  missingParent;

  static CrdtForeignKeyOverrideReason fromJson(int index) {
    switch (index) {
      case 0:
        return CrdtForeignKeyOverrideReason.setNull;
      case 1:
        return CrdtForeignKeyOverrideReason.setDefault;
      case 2:
        return CrdtForeignKeyOverrideReason.missingParent;
      default:
        throw ArgumentError(
          'Value "$index" cannot be converted to "CrdtForeignKeyOverrideReason"',
        );
    }
  }

  @override
  int toJson() => index;

  @override
  String toString() => name;
}
