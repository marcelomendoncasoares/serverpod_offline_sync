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

/// High-level category of a durable CRDT sync integrity violation.
enum CrdtSyncViolationType implements _i1.SerializableModel {
  ownershipCollision,
  missingDomainRow,
  unauthorizedWrite,
  ;

  static CrdtSyncViolationType fromJson(String name) {
    switch (name) {
      case 'ownershipCollision':
        return CrdtSyncViolationType.ownershipCollision;
      case 'missingDomainRow':
        return CrdtSyncViolationType.missingDomainRow;
      case 'unauthorizedWrite':
        return CrdtSyncViolationType.unauthorizedWrite;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "CrdtSyncViolationType"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
