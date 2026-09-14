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

/// Per-space checkpoint sent by each peer before the first visit to a space.
abstract class OfflineSyncSinceHlc extends _icw2tu00.OfflineSyncStreamEvent
    implements _iss.SerializableModel, _iss.ProtocolSerialization {
  OfflineSyncSinceHlc._({
    required this.uuidSpaceId,
    required this.nodeCheckpoints,
  });

  factory OfflineSyncSinceHlc({
    required _iss.UuidValue uuidSpaceId,
    required List<_icw2tu00.Hlc> nodeCheckpoints,
  }) = _OfflineSyncSinceHlcImpl;

  factory OfflineSyncSinceHlc.fromJson(Map<String, dynamic> jsonSerialization) {
    return OfflineSyncSinceHlc(
      uuidSpaceId: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['uuidSpaceId'],
      ),
      nodeCheckpoints: _icw2tu00.Protocol().deserialize<List<_icw2tu00.Hlc>>(
        jsonSerialization['nodeCheckpoints'],
      ),
    );
  }

  /// Space this checkpoint belongs to.
  _iss.UuidValue uuidSpaceId;

  /// Per-node checkpoints that describe which changes the sender already has.
  ///
  /// Each checkpoint is an [Hlc] whose `nodeId` is the source node being
  /// checkpointed. The receiver uses this list to compute a diff without
  /// relying on a single global HLC, which would miss concurrent changes from
  /// nodes unknown at the time of the previous sync.
  List<_icw2tu00.Hlc> nodeCheckpoints;

  /// Returns a shallow copy of this [OfflineSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @override
  @_iss.useResult
  OfflineSyncSinceHlc copyWith({
    _iss.UuidValue? uuidSpaceId,
    List<_icw2tu00.Hlc>? nodeCheckpoints,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSinceHlc',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'serverpod_offline_sync.OfflineSyncSinceHlc',
      'uuidSpaceId': uuidSpaceId.toJson(),
      'nodeCheckpoints': nodeCheckpoints.toJson(
        valueToJson: (v) =>
            // ignore: unnecessary_type_check
            v is _iss.ProtocolSerialization
            ? (v as _iss.ProtocolSerialization).toJsonForProtocol()
            :
              // ignore: dead_code
              v.toJson(),
      ),
    };
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _OfflineSyncSinceHlcImpl extends OfflineSyncSinceHlc {
  _OfflineSyncSinceHlcImpl({
    required _iss.UuidValue uuidSpaceId,
    required List<_icw2tu00.Hlc> nodeCheckpoints,
  }) : super._(
         uuidSpaceId: uuidSpaceId,
         nodeCheckpoints: nodeCheckpoints,
       );

  /// Returns a shallow copy of this [OfflineSyncSinceHlc]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  OfflineSyncSinceHlc copyWith({
    _iss.UuidValue? uuidSpaceId,
    List<_icw2tu00.Hlc>? nodeCheckpoints,
  }) {
    return OfflineSyncSinceHlc(
      uuidSpaceId: uuidSpaceId ?? this.uuidSpaceId,
      nodeCheckpoints:
          nodeCheckpoints ??
          this.nodeCheckpoints.map((e0) => e0.copyWith()).toList(),
    );
  }
}
