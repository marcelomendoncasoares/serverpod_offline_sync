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
abstract class CrdtSyncScopeSet extends _i1.CrdtSyncStreamEvent
    implements _i2.SerializableModel {
  CrdtSyncScopeSet._({required this.scopes});

  factory CrdtSyncScopeSet({required List<_i5.CrdtScopeGrant> scopes}) =
      _CrdtSyncScopeSetImpl;

  factory CrdtSyncScopeSet.fromJson(Map<String, dynamic> jsonSerialization) {
    return CrdtSyncScopeSet(
      scopes: _i4.Protocol().deserialize<List<_i5.CrdtScopeGrant>>(
        jsonSerialization['scopes'],
      ),
    );
  }

  /// Scopes this peer reports for the next sync cycle, each with the receiving
  /// user's authoritative role.
  List<_i5.CrdtScopeGrant> scopes;

  /// Returns a shallow copy of this [CrdtSyncScopeSet]
  /// with some or all fields replaced by the given arguments.
  @override
  @_i2.useResult
  CrdtSyncScopeSet copyWith({List<_i5.CrdtScopeGrant>? scopes});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.CrdtSyncScopeSet',
      'scopes': scopes.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i2.SerializationManager.encode(this);
  }
}

class _CrdtSyncScopeSetImpl extends CrdtSyncScopeSet {
  _CrdtSyncScopeSetImpl({required List<_i5.CrdtScopeGrant> scopes})
    : super._(scopes: scopes);

  /// Returns a shallow copy of this [CrdtSyncScopeSet]
  /// with some or all fields replaced by the given arguments.
  @_i2.useResult
  @override
  CrdtSyncScopeSet copyWith({List<_i5.CrdtScopeGrant>? scopes}) {
    return CrdtSyncScopeSet(
      scopes: scopes ?? this.scopes.map((e0) => e0.copyWith()).toList(),
    );
  }
}
