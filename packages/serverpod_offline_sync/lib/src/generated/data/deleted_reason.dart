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
import 'package:serverpod_serialization/serverpod_serialization.dart' as _i1;

/// Why a synced user tombstone changed row visibility.
enum CrdtDataDeletedReason implements _i1.SerializableModel {
  userInsert,
  userReinsert,
  userDelete,
  userCascadeDelete,
  uniqueLoser,
  ;

  static CrdtDataDeletedReason fromJson(int index) {
    switch (index) {
      case 0:
        return CrdtDataDeletedReason.userInsert;
      case 1:
        return CrdtDataDeletedReason.userReinsert;
      case 2:
        return CrdtDataDeletedReason.userDelete;
      case 3:
        return CrdtDataDeletedReason.userCascadeDelete;
      case 4:
        return CrdtDataDeletedReason.uniqueLoser;
      default:
        throw ArgumentError(
          'Value "$index" cannot be converted to "CrdtDataDeletedReason"',
        );
    }
  }

  @override
  int toJson() => index;

  @override
  String toString() => name;
}
