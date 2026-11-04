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

/// Per-space durable resume positions, scoped to the authenticated user's peers.
abstract class OfflineSyncSinceRevision extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncSinceRevision._({
    required this.uuidSpaceId,
    required this.nodeCheckpoints,
  });

  factory OfflineSyncSinceRevision({
    required _iss.UuidValue uuidSpaceId,
    required List<_icw2tu00.OfflineSyncNodeCheckpoint> nodeCheckpoints,
  }) = _OfflineSyncSinceRevisionImpl;

  factory OfflineSyncSinceRevision.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return OfflineSyncSinceRevision(
      uuidSpaceId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidSpaceId'],
      ),
      nodeCheckpoints: _icw2tu00.Protocol()
          .deserialize<List<_icw2tu00.OfflineSyncNodeCheckpoint>>(
            jsonSerialization['nodeCheckpoints'],
          ),
    );
  }

  _iss.UuidValue uuidSpaceId;

  List<_icw2tu00.OfflineSyncNodeCheckpoint> nodeCheckpoints;

  /// Returns a shallow copy of this [OfflineSyncSinceRevision]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncSinceRevision copyWith({
    _iss.UuidValue? uuidSpaceId,
    List<_icw2tu00.OfflineSyncNodeCheckpoint>? nodeCheckpoints,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSinceRevision',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSinceRevision',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncSinceRevisionImpl extends OfflineSyncSinceRevision {
  _OfflineSyncSinceRevisionImpl({
    required _iss.UuidValue uuidSpaceId,
    required List<_icw2tu00.OfflineSyncNodeCheckpoint> nodeCheckpoints,
  }) : super._(
         uuidSpaceId: uuidSpaceId,
         nodeCheckpoints: nodeCheckpoints,
       );

  /// Returns a shallow copy of this [OfflineSyncSinceRevision]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSinceRevision copyWith({
    _iss.UuidValue? uuidSpaceId,
    List<_icw2tu00.OfflineSyncNodeCheckpoint>? nodeCheckpoints,
  }) {
    return OfflineSyncSinceRevision(
      uuidSpaceId: uuidSpaceId ?? this.uuidSpaceId,
      nodeCheckpoints:
          nodeCheckpoints ??
          this.nodeCheckpoints.map((e0) => e0.copyWith()).toList(),
    );
  }
}
