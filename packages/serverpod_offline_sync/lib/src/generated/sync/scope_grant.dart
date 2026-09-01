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

/// A single scope a peer announces in a [CrdtSyncScopeSet].
///
/// Carries the scope UUID and the authoritative [role] the receiving user
/// holds in it. The personal scope is announced with [CrdtScopeRole.readWrite].
abstract class CrdtScopeGrant
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtScopeGrant._({
    required this.uuidScopeId,
    required this.role,
  });

  factory CrdtScopeGrant({
    required _iss.UuidValue uuidScopeId,
    required _icw2tu00.CrdtScopeRole role,
  }) = _CrdtScopeGrantImpl;

  factory CrdtScopeGrant.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtScopeGrant(
      uuidScopeId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidScopeId'],
      ),
      role: _icw2tu00.CrdtScopeRole.fromJson(
        (jsonSerialization['role'] as String),
      ),
    );
  }

  /// Scope UUID being announced.
  _iss.UuidValue uuidScopeId;

  /// Authoritative CRDT access role of the receiving user in this scope.
  _icw2tu00.CrdtScopeRole role;

  /// Returns a shallow copy of this [CrdtScopeGrant]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  CrdtScopeGrant copyWith({
    _iss.UuidValue? uuidScopeId,
    _icw2tu00.CrdtScopeRole? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeGrant',
      'uuidScopeId': uuidScopeId.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtScopeGrant',
      'uuidScopeId': uuidScopeId.toJson(),
      'role': role.toJson(),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtScopeGrantImpl extends CrdtScopeGrant {
  _CrdtScopeGrantImpl({
    required _iss.UuidValue uuidScopeId,
    required _icw2tu00.CrdtScopeRole role,
  }) : super._(
         uuidScopeId: uuidScopeId,
         role: role,
       );

  /// Returns a shallow copy of this [CrdtScopeGrant]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtScopeGrant copyWith({
    _iss.UuidValue? uuidScopeId,
    _icw2tu00.CrdtScopeRole? role,
  }) {
    return CrdtScopeGrant(
      uuidScopeId: uuidScopeId ?? this.uuidScopeId,
      role: role ?? this.role,
    );
  }
}
