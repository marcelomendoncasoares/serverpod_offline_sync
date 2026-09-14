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

/// Authoritative or informational space set exchanged at the start of a cycle.
///
/// The server sends the authoritative membership set (with roles). The client
/// sends an empty set; the server never widens access from follower-reported
/// state.
abstract class OfflineSyncSpaceSet extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncSpaceSet._({required this.spaces});

  factory OfflineSyncSpaceSet({
    required List<_icw2tu00.OfflineSyncSpaceGrant> spaces,
  }) = _OfflineSyncSpaceSetImpl;

  factory OfflineSyncSpaceSet.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncSpaceSet(
      spaces: _icw2tu00.Protocol()
          .deserialize<List<_icw2tu00.OfflineSyncSpaceGrant>>(
            jsonSerialization['spaces'],
          ),
    );
  }

  /// Spaces this peer reports for the next sync cycle, each with the receiving
  /// user's authoritative role.
  List<_icw2tu00.OfflineSyncSpaceGrant> spaces;

  /// Returns a shallow copy of this [OfflineSyncSpaceSet]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncSpaceSet copyWith({List<_icw2tu00.OfflineSyncSpaceGrant>? spaces});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceSet',
      'spaces': spaces.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSpaceSet',
      'spaces': spaces.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncSpaceSetImpl extends OfflineSyncSpaceSet {
  _OfflineSyncSpaceSetImpl({
    required List<_icw2tu00.OfflineSyncSpaceGrant> spaces,
  }) : super._(spaces: spaces);

  /// Returns a shallow copy of this [OfflineSyncSpaceSet]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSpaceSet copyWith({
    List<_icw2tu00.OfflineSyncSpaceGrant>? spaces,
  }) {
    return OfflineSyncSpaceSet(
      spaces: spaces ?? this.spaces.map((e0) => e0.copyWith()).toList(),
    );
  }
}
