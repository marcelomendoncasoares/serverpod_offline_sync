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
import 'package:serverpod_offline_sync/serverpod_offline_sync.dart'
    as _icw2tu00;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;

/// A single space a peer announces in a [OfflineSyncSpaceSet].
///
/// Carries the space UUID and the authoritative [role] the receiving user
/// holds in it. The personal space is announced with [OfflineSyncSpaceRole.readWrite].
abstract class OfflineSyncSpaceGrant
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncSpaceGrant._({
    required this.uuidSpaceId,
    required this.role,
  });

  factory OfflineSyncSpaceGrant({
    required _iss.UuidValue uuidSpaceId,
    required _icw2tu00.OfflineSyncSpaceRole role,
  }) = _OfflineSyncSpaceGrantImpl;

  factory OfflineSyncSpaceGrant.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncSpaceGrant(
      uuidSpaceId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidSpaceId'],
      ),
      role: _icw2tu00.OfflineSyncSpaceRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  /// Space UUID being announced.
  _iss.UuidValue uuidSpaceId;

  /// Authoritative CRDT access role of the receiving user in this space.
  _icw2tu00.OfflineSyncSpaceRole role;

  /// Returns a shallow copy of this [OfflineSyncSpaceGrant]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  OfflineSyncSpaceGrant copyWith({
    _iss.UuidValue? uuidSpaceId,
    _icw2tu00.OfflineSyncSpaceRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceGrant',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceGrant',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncSpaceGrantImpl extends OfflineSyncSpaceGrant {
  _OfflineSyncSpaceGrantImpl({
    required _iss.UuidValue uuidSpaceId,
    required _icw2tu00.OfflineSyncSpaceRole role,
  }) : super._(
         uuidSpaceId: uuidSpaceId,
         role: role,
       );

  /// Returns a shallow copy of this [OfflineSyncSpaceGrant]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpaceGrant copyWith({
    _iss.UuidValue? uuidSpaceId,
    _icw2tu00.OfflineSyncSpaceRole? role,
  }) {
    return OfflineSyncSpaceGrant(
      uuidSpaceId: uuidSpaceId ?? this.uuidSpaceId,
      role: role ?? this.role,
    );
  }
}
