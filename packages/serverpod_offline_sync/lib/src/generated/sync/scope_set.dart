/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'stream_event.dart';

/// Authoritative or informational scope set exchanged at the start of a cycle.
///
/// The server sends the authoritative membership set (with roles). The client
/// sends an empty set; the server never widens access from follower-reported
/// state.
abstract class CrdtSyncScopeSet extends _icw2tu00.CrdtSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  CrdtSyncScopeSet._({required this.scopes});

  factory CrdtSyncScopeSet({required List<_icw2tu00.CrdtScopeGrant> scopes}) =
      _CrdtSyncScopeSetImpl;

  factory CrdtSyncScopeSet.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncScopeSet(
      scopes: _icw2tu00.Protocol().deserialize<List<_icw2tu00.CrdtScopeGrant>>(
        jsonSerialization['scopes'],
      ),
    );
  }

  /// Scopes this peer reports for the next sync cycle, each with the receiving
  /// user's authoritative role.
  List<_icw2tu00.CrdtScopeGrant> scopes;

  /// Returns a shallow copy of this [CrdtSyncScopeSet]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  CrdtSyncScopeSet copyWith({List<_icw2tu00.CrdtScopeGrant>? scopes});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncScopeSet',
      'scopes': scopes.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncScopeSet',
      'scopes': scopes.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _CrdtSyncScopeSetImpl extends CrdtSyncScopeSet {
  _CrdtSyncScopeSetImpl({required List<_icw2tu00.CrdtScopeGrant> scopes})
    : super._(scopes: scopes);

  /// Returns a shallow copy of this [CrdtSyncScopeSet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  CrdtSyncScopeSet copyWith({List<_icw2tu00.CrdtScopeGrant>? scopes}) {
    return CrdtSyncScopeSet(
      scopes: scopes ?? this.scopes.map((e0) => e0.copyWith()).toList(),
    );
  }
}
